
# ON-CHAIN INDEXER / SHADOW-LEDGER AUDIT

An indexer is a **shadow ledger**. Every real finding is one of two things:

1. **Divergence** — the shadow ledger disagrees with canonical chain state (wrong ID, wrong amount, phantom row, zombie row, dropped action).
2. **Indexer-owned surface** — a security bug in code the indexer itself owns (webhook dispatch/SSRF, API query layer, unbounded work per tick).

Frame the whole audit that way and the bug classes below fall out naturally. Do **not** audit the indexer like a contract: there is no reentrancy, no oracle, no flash loan. The bugs are ID allocation, cursor boundaries, dedup, and cascade parity.

---

## STEP 0 — MAP BEFORE YOU READ (do this in one batch)

```
1. search_files(target='files', pattern='*.ts|*.py|*.go|*.js')   -> file inventory
2. Read the DB SCHEMA first (db/schema.ts, models.py, migrations/)
   -> this IS the shadow ledger contract. It tells you every table that
      mirrors a chain table, every UNIQUE constraint, and every FK.
3. Read the INGESTION layer second (stream.ts / poller.ts / indexer.ts)
   -> cursor semantics, dedup key, pagination. Highest-severity bugs live here.
4. Read the WEBHOOK/OUTBOUND layer third -> SSRF, retry, disable.
5. Only then read handlers/ action-by-action.
```

Reading handlers first is the common mistake: it is the slowest path and the lowest yield. Schema + ingestion + webhooks carry the Criticals.

**Budget discipline (learned the hard way):** batch 4-6 independent reads per turn, read each file **once**, and reserve your last few tool iterations for writing the findings. Re-reading identical content trips Hermes' `idempotent_no_progress_warning` and can exhaust the tool-call budget before a single finding is reported. If you catch yourself re-issuing a read you already made, stop and move to the next file.

---

## BUG CLASS 1 — SYNTHETIC PK vs THE CONTRACT'S `availablePrimaryKey`

**The root cause of most indexer drift.**

Chain actions frequently do **not** carry the primary key the contract assigned (Antelope `createjob` / `regplugin` / `submit` emit no `id`). So the indexer invents one with `MAX(id)+1`. Meanwhile the contract's own allocator is almost always:

```
availablePrimaryKey = (table empty) ? 0 : max_id + 1
```

The idiomatic-looking bug:

```ts
const result = db.prepare('SELECT MAX(id) as max_id FROM feedback_disputes').get();
const id = (result.max_id || 0) + 1;      // BUG: FIRST row gets id 1
```

`MAX(id)` on an empty table returns **NULL**, not 0 — so `(null || 0) + 1 = 1`, while the chain assigned `0`. Every row is now off by one **forever**: a later `resolve(dispute_id=0)` finds nothing, and `resolve(1)` mutates the *wrong* dispute's feedback.

```ts
const id = result.max_id === null ? 0 : result.max_id + 1;   // CORRECT: mirrors availablePrimaryKey
```

**Grep patterns**
```bash
rg -n "MAX\(id\)|max_id" src/
rg -n "max_id \|\| 0\) \+ 1|\.max_id \|\| 0" src/     # the off-by-one signature
rg -n "\+ 1;" src/handlers/ -B3 | rg "MAX\(id\)"
```
For every hit, go read the contract's `availablePrimaryKey` equivalent and confirm the empty-table case matches. One character, permanent drift.

---

## BUG CLASS 2 — ASYNC ID CORRECTION MUST BE COLLISION-SAFE AND IDEMPOTENT

Synthetic IDs are usually fixed up after the synchronous transaction commits, via an async RPC lookup that finds the real on-chain row. Three failure modes:

1. **Collision.** `UPDATE jobs SET id = :real WHERE id = :temp` raises `SqliteError: UNIQUE constraint failed` when `real` is already occupied by another (also-mis-IDed) row. Needs a two-phase/swap inside one transaction, not a bare UPDATE.
2. **Orphaned children.** The correction must rewrite FK references too, in the same transaction:
   ```ts
   db.transaction(() => {
     db.prepare('UPDATE feedback_disputes SET feedback_id = ? WHERE feedback_id = ?').run(real, temp);
     db.prepare('UPDATE feedback SET id = ? WHERE id = ?').run(real, temp);
   })();
   ```
   Miss the child rewrite -> every dispute points at a dead ID.
3. **No-op safety.** Must short-circuit on `realId != null && realId !== tempId`. Without it you re-run pointless writes and can re-trigger the collision above.

Also check the correction queue itself: is it drained? bounded? does it survive a restart? Corrections queued in an in-memory array and lost on crash leave the ledger permanently wrong with no repair path.

---

## BUG CLASS 3 — INGESTION CURSOR SEMANTICS (the silent-drop class)

### 3a. `after=<block>` is INCLUSIVE on Hyperion
`/v2/history/get_actions?after=N` returns actions **at** block N, not only after it. Every poll therefore refetches the boundary block. Without dedup you double-process the whole boundary — double-counting feedback, re-registering plugins, inflating deposits.

The dedup key is `global_sequence`, and it must be compared against the **running** max inside the drain, not the poll-start snapshot:

```ts
if (seq !== 0 && seq <= maxSeq) continue;   // maxSeq updated as we go
```

Using the poll-start snapshot re-emits actions that reappear within the same drain (endpoint failover mid-drain, or new tip rows shifting the skip window between page fetches). Note `seq === 0` is always emitted — it cannot be deduped.

### 3b. A block with more actions than the page size stalls the poller forever
`limit=100` + `skip` paging is required, but the naive drain restarts at `skip 0` every poll. If a single block holds more than (page-cap x 100) actions, the drain can never reach past the cap and **every action after the cap is silently dropped forever**.

Correct shape:
- Page with `skip = startSkip + page * 100`.
- **Persist the skip cursor across polls** while still inside the same boundary block.
- Reset skip to 0 once you either reach the tip (short page) or advance into a later block.
- Persist the seq/block cursor **after every page**, so a crash mid-drain does not rewind.
- Bound work per tick (a `MAX_PAGES_PER_POLL`), and make sure the bound is escapable — that is exactly what the persisted skip is for.

### 3c. Per-contract cursors, not one global cursor
One global block cursor across N contracts skips actions when contracts have actions at different heights. Expect `contract_cursors(contract, last_block_num)` and per-contract start blocks. New contracts added later must be **seeded from the global cursor**, not from 0, or an upgrade replays genesis.

---

## BUG CLASS 4 — SEED-THEN-POLL DUPLICATION (INSERT OR REPLACE CLOBBERS STATE)

A common design has two ingestion paths that cover the same actions: a `syncFromChain` seeder and a live poller/stream. On replay the same action arrives twice.

`INSERT OR REPLACE` is **wrong** here — SQLite implements it as DELETE + INSERT, so every column not in the statement resets to its default. For a registration handler that silently wipes ownership and accumulated state:

```ts
// BUG: INSERT OR REPLACE would clobber owner/total_jobs/claim_deposit/deposit_payer
//      on action replay (seed-then-poll covers the same register action)
INSERT INTO agents (account, owner, name, ...) VALUES (?, NULL, ?, ...)
  ON CONFLICT(account) DO UPDATE SET
    name = excluded.name,
    description = excluded.description,
    active = 1;              -- refresh metadata ONLY; preserve agent state
```

And for append-style tables (feedback, disputes) use `INSERT OR IGNORE` and **check the result**:

```ts
const changes = stmt.run(...);
if (changes.changes === 0) { console.log('duplicate, skipping'); return; }
```

Grep: `rg -n "INSERT OR REPLACE" src/` — every hit is a candidate clobber.

---

## BUG CLASS 5 — CASCADE PARITY WITH CONTRACT ADMIN OPS

Chain admin ops (`removeagent`, `rmfeedback`) cascade-delete on-chain. The indexer must mirror the **entire** cascade or it keeps zombie rows and phantom aggregates:

```ts
db.transaction(() => {
  db.prepare('DELETE FROM agent_plugins  WHERE agent = ?').run(agent);
  db.prepare('DELETE FROM plugin_results WHERE agent = ?').run(agent);
  db.prepare('DELETE FROM agent_scores   WHERE agent = ?').run(agent);
  db.prepare('DELETE FROM agents         WHERE account = ?').run(agent);
})();
```

The subtle one: when the contract **removes the aggregate row** rather than zeroing it (last feedback for an agent removed -> the `agent_scores` row disappears), mirroring with a recompute leaves a phantom row with `avg_score = 0`. Check the count and DELETE when it hits zero:

```ts
const remaining = db.prepare('SELECT COUNT(*) c FROM feedback WHERE agent = ?').get(agent);
if (remaining.c === 0) db.prepare('DELETE FROM agent_scores WHERE agent = ?').run(agent);
else updateAgentScore(db, agent);
```

**Audit move:** for every admin/maintenance action name in the handler switch, ask "does the contract cascade or delete here, and does the handler do the same?" Also check for handlers that are a bare `break;` with a comment — some are legitimately no-ops (indexer keeps history), some are simply unimplemented.

---

## BUG CLASS 6 — ARCHIVED FLAG vs HARD DELETE

Contracts periodically purge old rows (`cleanjobs`, `cleanfback`, `cleandisps`) to reclaim RAM/storage. The indexer usually wants to keep history -> it sets `archived = 1` instead of deleting.

Check three things:
1. **Eligibility predicate parity.** The indexer's cleanup WHERE must match the contract's, e.g. `(disputed = 0 OR resolved = 1) AND archived = 0`. A missing clause archives rows the chain kept, or vice-versa.
2. **Caps honoured.** `max_age` / `max_delete` must actually bound the statement (`LIMIT ?`), and the cutoff must be derived consistently (`now - max_age`).
3. **Archived rows excluded from user-facing reads.** Grep the query layer for `archived` — a listing/stat query that forgets `archived = 0` resurrects purged data.

---

## BUG CLASS 7 — ANTELOPE QUANTITY PARSING + INLINE REFUNDS

Antelope transfers carry amounts as **strings**: `"1.0000 XPR"`. `parseFloat` is wrong for money and loses precision on the 4-dp asset. Parse to integer smallest-units:

```ts
const [whole = '0', frac = ''] = quantity.split(' ')[0].split('.');
const amount = parseInt(whole, 10) * 10000 + parseInt(frac.padEnd(4, '0').slice(0, 4), 10);
```

**Inline refunds are the divergence trap.** Contracts commonly refund the excess above a fee via an inline `eosio.token::transfer` back to the sender inside the same action. If the indexer credits the full transfer, the shadow ledger **overstates every deposit**. It must scan `action.inline_traces` for the refund and net it out:

```ts
if (trace.act?.account === 'eosio.token' && trace.act?.data?.to === from
    && trace.act?.data?.memo?.includes('refund')) {
  depositAmount -= parseQuantity(trace.act.data.quantity);
}
if (depositAmount <= 0) return;   // net-zero after refund — do not credit
```

Same pattern applies to challenge funding, validator stake, and escrow funding memos (`claim:agent:owner`, `challenge:ID`, `stake`, `buy:service_id`, `boost:service_id`). Enumerate every memo prefix the contract understands and check the indexer handles each — **an unhandled memo is a silently dropped economic event**.

---

## BUG CLASS 8 — AMBIGUOUS TRACE -> BE CONSERVATIVE, NEVER GUESS

Some contract actions have two possible effects that the emitted trace cannot disambiguate. Canonical example: `verifyclaim` either (a) KYC valid -> ownership untouched, or (b) KYC invalid with `claim_deposit == 0` -> ownership cleared with no refund to observe. Both look identical: no inline transfer.

The correct indexer behaviour is **do not make destructive changes without proof** — log the ambiguity and defer to a full chain sync. If you find a handler that guesses (clears ownership on absence of a refund), that is a divergence bug: legitimate owners get dropped from the ledger.

**Audit move:** flag any handler whose comment says "cannot determine" / "requires chain sync" — then verify the code actually *is* conservative on that path, because the comment is often aspirational while the code still writes.

---

## BUG CLASS 9 — WEBHOOK DISPATCHER IS AN SSRF SINK

Any user-registered callback URL is attacker-controlled egress. Verify the guard:

- **Resolve DNS and classify the address**, not the hostname string. Reject loopback `127/8`, `0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254/16` (**cloud metadata — `169.254.169.254`**), `192.0.0/24`, ULA `fc00::/7`, link-local `fe80::/10`, CGNAT `100.64/10`, multicast, and anything unparseable.
- **Re-check after redirects** (or disable redirects) — otherwise DNS rebinding / an open redirect walks straight past the check.
- **Bounded retries with backoff**, and a failure counter that **disables** the subscription after N consecutive failures (`failure_count` / `MAX_FAILURES`), or a dead endpoint becomes a permanent worker-thread leak.
- Token/HMAC on delivery, and the subscription API itself authenticated + rate-limited.
- Log deliveries to a table so failures are auditable.

---

## BUG CLASS 10 — API QUERY LAYER (where the silent logic bugs live)

Good indexers split ranking/pagination/ordering into `*-query.ts` modules that take a `db`, so they are testable without an HTTP harness. Read those modules — that is where:

- **Limit clamping** is missing or wrong (`MAX_LIMIT`, `DEFAULT_LIMIT`) -> a client asks for 100000 rows and the box OOMs.
- **Featured/sponsored slot logic** injects rows that bypass the organic sort, and can duplicate a row that is also in the organic page.
- **Ordering** is unstable (no tiebreaker) -> page 2 repeats or skips rows.
- **Archived/soft-deleted rows** leak into results (see class 6).
- **N+1 query fan-out** per row -> the endpoint is a DoS amplifier.

Also audit the **derived-stats function** (`updateStats()` and friends): it recomputes aggregates on every action, and its WHERE clauses are where a wrong definition hides. Example: `total_open_jobs` computed as `COUNT(*) WHERE agent = '' OR agent IS NULL` — verify that definition actually matches what "open" means in the contract's state machine (state enum), or the number is meaningless.

---

## QUICK STATIC PASS (run before deep reading)

```bash
# ID allocation (class 1/2)
rg -n "MAX\(id\)|max_id|availablePrimaryKey" src/

# State-clobbering upserts (class 4)
rg -n "INSERT OR REPLACE" src/

# Ingestion boundaries (class 3)
rg -n "after=|skip|limit|global_sequence|reachedTip|MAX_PAGES" src/

# Shell-out / injection surface (an indexer should have ~none)
rg -n "child_process|execSync|exec\(|spawn\(|execFile" src/

# Raw string interpolation into SQL (should be ZERO — all parameterized)
rg -n 'db\.(prepare|exec)\(`[^`]*\$\{' src/

# Outbound egress (class 9)
rg -n "fetch\(|axios|http\.request|isPrivateAddress|lookup\(" src/
```

Zero `child_process` hits and zero interpolated SQL is the expected baseline for an indexer; anything else is a finding.

---

## VERIFY BEFORE YOU CLAIM

- **Deps actually installed?** `node -e "require('./node_modules/express/package.json').version"` or `npm ls --depth=0`. A missing `node_modules` means you **cannot** claim a green build or a passing test suite — say so instead.
- **Build:** `npx tsc --noEmit`. **Tests:** `npx vitest run` / `npm test`.
- A finding is only real when you can name (a) the action/memo that triggers it, (b) the exact DB write that diverges, and (c) the observable wrong value in the API. Otherwise it is a code smell — label it as such.

---

## PITFALLS

- **Do not audit an indexer for contract bugs.** No reentrancy, no oracle, no flash loans. If you find yourself writing those words, you are in the wrong skill — that is `web3-audit`. For the Antelope/EOSIO AssemblyScript **contract** half of an XPR-style monorepo, that is `antelope-eosio-contract-audit` (its own `@proton/vert` harness + deployed code-hash verification).
- **Do not trust code comments.** "Already seeded", "cannot determine", "display only" are frequently stale. Verify the code path the comment describes.
- **Check for handler gaps.** The `default: console.log('Unknown action')` branch is a to-do list of dropped chain events. Diff the contract's full action list against the switch arms.
- **Off-by-one IDs are permanent.** Unlike a transient error, a wrong PK never self-heals — it corrupts every later FK lookup. Rank these highest.
- **Read once, batch reads, reserve budget for the report.** See Step 0.

---

## REFERENCES

- `references/antelope-hyperion-indexer.md` — session-specific detail from an Antelope/XPR Network indexer audit: file inventory, concrete findings per bug class with code, Hyperion v2 API semantics, and the XPR contract action/memo map.
- **Sibling skill:** `antelope-eosio-contract-audit` — the on-chain half of the same monorepos (Antelope/EOSIO `*.contract.ts` contracts, `@proton/vert` PoCs, deployed code-hash verification). These XPR-style repos split contract + indexer; if the finding is in the contract, switch skills.
