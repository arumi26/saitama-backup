# Case notes — Antelope / XPR Network Hyperion indexer (`xpr-agents-indexer`)

Session: static audit of `/tmp/xpr/indexer` (TypeScript, Express + better-sqlite3 + ws).
**Status: reconnaissance complete, report not delivered** — the tool-call budget was exhausted
mid-read (see "Process failure" at the bottom). Everything below is *observed code*, with
candidate findings explicitly labelled as unverified. Do not quote these as confirmed bugs
without re-reading the current source.

---

## Target shape

`package.json`: `xpr-agents-indexer` v1.0.0 — "Hyperion Indexer for XPR Network Agent Registry".

```
deps:    better-sqlite3 ^9, cors ^2.8.5, express ^4.18, express-rate-limit ^8.2.1, ws ^8.14
devDeps: @types/*, ts-node ^10.9, typescript ^5, vitest ^4.0.18
scripts: build=tsc, start=node dist/index.js, dev=ts-node, lint=eslint, test=vitest run
```

**`node_modules` was NOT installed** at audit time — every `require('./node_modules/<pkg>/package.json')`
probe returned `n/a`. Consequence: `npx tsc --noEmit` and `npx vitest run` could not be run,
so no build/test claim is possible from that session. Check installation before asserting
anything green.

### Source inventory (16 files)

```
src/index.ts                      entrypoint / wiring
src/stream.ts                     Hyperion WebSocket stream (reconnect, endpoint cycling, 30s ping)
src/poller.ts                     Hyperion v2 get_actions poller (REST fallback)   <- hardened
src/sync.ts                       syncFromChain seeder
src/enrich.ts                     KYC level / eosio::voters system stake enrichment
src/net-guard.ts                  isPrivateAddress() SSRF address classifier
src/webhooks/dispatcher.ts        webhook subscriptions + delivery + retry
src/handlers/agent.ts             agentcore actions
src/handlers/feedback.ts          agentfeed actions
src/handlers/validation.ts        agentvalid actions
src/handlers/escrow.ts            agentescrow actions (largest)
src/handlers/id-correction.ts     pendingCorrections queue + fetchOnChainId()
src/api/routes.ts                 Express routes
src/api/services-query.ts         catalogue ranking/pagination (testable in isolation)
src/api/job-messages-query.ts     job thread ordering (same split)
src/db/schema.ts                  DDL + migrations + updateStats()
```

The `*-query.ts` split out of `routes.ts` (with the comment "Kept out of routes.ts so the
ranking rules … can be unit-tested against a real database without an HTTP harness") is the
pattern worth replicating in other indexers.

---

## Schema = the shadow ledger (from `src/db/schema.ts`)

Mirrored chain tables: `agents`, `agent_scores`, `feedback`, `feedback_disputes`, `validators`,
`validations`, `validation_challenges`, `plugins`, `agent_plugins`, `plugin_results`, `jobs`,
`services`, `service_inputs`, `job_messages`, `job_evidence`, `milestones`, `escrow_disputes`,
`arbitrators`, `bids`, `events`, `stats`.

Infra tables: `stream_cursor` (global, single row), `contract_cursors` (per-contract),
`processed_actions(dedup_key TEXT PRIMARY KEY)`, `webhook_subscriptions`,
`webhook_deliveries`.

Notable constraints / migrations:
- `CREATE UNIQUE INDEX idx_feedback_dedup ON feedback(agent, reviewer, timestamp)` — the
  natural-key dedup for seed-then-poll replay.
- Migration list adds `archived INTEGER DEFAULT 0` to jobs, milestones, feedback,
  feedback_disputes, validations, validation_challenges, escrow_disputes, plugin_results —
  i.e. chain-purge is mirrored as soft-archive, not DELETE.
- `ALTER TABLE bids ADD COLUMN state INTEGER NOT NULL DEFAULT 0` with the documented enum
  `0=pending 1=selected 2=lost 3=withdrawn` — bid lifecycle kept as state, not hard-delete, so
  the winning proposal text stays queryable.
- `ALTER TABLE agents ADD COLUMN kyc_level / system_stake / enriched_at` (enrichment).
- `ALTER TABLE services ADD COLUMN boost_paid / featured_until` (paid featured placement).
- `processed_actions` is migrated by probing `SELECT dedup_key FROM processed_actions LIMIT 0`
  and recreating the table on failure — treats the dedup cache as ephemeral (acceptable, but
  note it means the dedup window is not durable across that migration).

### Candidate finding: `updateStats()` "open jobs" definition

```sql
UPDATE stats SET value = (SELECT COUNT(*) FROM jobs WHERE agent = '' OR agent IS NULL)
  WHERE key = 'total_open_jobs';
```

An unfilled job having `agent = ''` is an inference about the contract's state machine, and
`jobs.state` (an enum) already exists. If "open" is really a state value, this stat is wrong.
**Unverified** — needs the contract's job state enum to confirm. Same class of check applies to
`total_jobs` (`SUM(agents.total_jobs)`) and `network_earnings` (`SUM(amount) WHERE state IN (6,8)`
— hardcoded state magic numbers; confirm 6/8 against the contract).

---

## Verified-hardened code (do NOT re-report these)

These already carry the fix, with in-code audit comments. A future session that greps and flags
them wastes its budget:

1. **`handlers/feedback.ts` → `handleDispute()`** — correct `availablePrimaryKey` mirror:
   ```ts
   // SECURITY (audit round 2, codex #14): the id MUST mirror the contract's
   // `availablePrimaryKey`, which is 0 for an empty table and max+1 otherwise. The
   // old `(max_id || 0) + 1` made the FIRST dispute id 1, so it was off by one
   // against the chain forever — `resolve` for chain dispute 0 found nothing, and
   // resolve for chain dispute 1 marked the FIRST dispute's feedback resolved (wrong).
   const id = result.max_id === null ? 0 : result.max_id + 1;
   ```
2. **`handlers/agent.ts` → `handleRegister()`** — `INSERT ... ON CONFLICT(account) DO UPDATE`
   refreshing only name/description/endpoint/protocol/capabilities/active, explicitly *not*
   clobbering owner/total_jobs/claim_deposit/deposit_payer on replay.
3. **`handlers/agent.ts` → `handleRemoveAgent()` / `handleRmFeedback()`** — full cascade inside
   `db.transaction()`, plus the phantom-aggregate fix (DELETE `agent_scores` when the last
   feedback row is gone rather than recomputing to `avg_score = 0`).
4. **`handlers/agent.ts` → `handleVerifyClaim()`** — conservative on the ambiguous case:
   `claim_deposit === 0 && owner` → logs "cannot determine KYC outcome. Requires chain sync"
   and returns without mutating. This is the correct shape (bug class 8).
5. **`handlers/agent.ts` → `handleAgentCoreTransfer()`** — parses `"1.0000 XPR"` into
   4-dp integer units (`whole*10000 + frac.padEnd(4,'0').slice(0,4)`) and subtracts inline
   refund transfers before crediting; bails on `depositAmount <= 0`.
6. **`poller.ts`** — implements the full correct cursor discipline: inclusive-`after` handling
   with `global_sequence` compared against the **running** `maxSeq`, `MAX_PAGES_PER_POLL = 50`,
   a `contractSkip` map persisted across polls while inside the same boundary block, reset to 0
   on `reachedTip || maxBlock > lastBlock`, and cursor persistence after every page.
7. **`net-guard.ts`** — `isPrivateAddress()` covers `0/8, 10/8, 127/8, 169.254/16` (comment:
   "link-local + cloud metadata"), `172.16–31`, `192.168/16`, `192.0.0/24`, plus IPv6
   ULA/link-local; uses `node:dns/promises` `lookup` + `node:net` `isIP`.

## Candidate findings (unverified — verify before reporting)

1. **`plugin_results` IDs are never corrected.** `handlers/agent.ts` → `handlePluginResult()`
   computes `const id = (result.max_id || 0) + 1;` and inserts, but pushes **no**
   `pendingCorrections` job — unlike `handleRegPlugin` (corrects `plugins`) and
   `handleAddPlugin` (corrects `agent_plugins`). If the contract assigns plugin-result PKs with
   the usual `0`-for-empty allocator, this table drifts permanently with no repair path.
   Cross-check against the chain's `agentplugres` (or equivalent) table.
2. **`(max_id || 0) + 1` still used for temp IDs** in `handleRegPlugin`, `handleAddPlugin`,
   `handlePluginResult` (agent.ts) and `handleSubmit` (feedback.ts). Mitigated by the async
   correction queue for the first two and by `INSERT OR IGNORE` + `changes.changes === 0` dedup
   for `handleSubmit` — but the *temp* value itself collides with chain ID 0 semantics, so any
   consumer reading the row before correction lands sees an off-by-one ID.
3. **No-op ternary in `handlers/validation.ts`** (challenge-funding webhook dispatch):
   ```ts
   dispatcher?.dispatch(
     'validation.challenged',
     challenge ? [from] : [from],     // both branches identical
     ...
   ```
   Almost certainly meant to be `challenge ? [challenge.validator] : [from]`, or similar. Dead
   branch → the account filter on `validation.challenged` webhooks is probably wrong for
   subscribers filtering by validator. Low/medium, but trivially provable.
4. **Unhandled memo prefixes.** Only `claim:` (agent.ts), `stake` / `stake:` and `challenge:`
   (validation.ts) are handled in the files read. Enumerate every memo the contracts accept
   (`buy:<service_id>`, `boost:<service_id>`, escrow funding, validator unstake withdrawals) and
   confirm each is consumed somewhere — an unhandled memo is a silently dropped economic event.
5. **`plugin_results.job_id` defaults to `0`** (`data.job_id || 0`) — confirm the contract does
   not use `0` as a real job id, or unrelated results attach to job 0.

---

## Hyperion v2 API semantics (carry these forward — they are the source of class-3 bugs)

```
GET {endpoint}/v2/history/get_actions?account=<contract>&limit=100&sort=asc&skip=N&after=<block>
```

- `after=<block>` is **INCLUSIVE** — verified against mainnet per the in-repo comment. Page 0 of
  every poll refetches the boundary block; `global_sequence` dedup is what makes that a no-op.
- `global_sequence` is the monotonic dedup key. `0` means "unavailable" and must be emitted
  unconditionally (cannot be deduped).
- Endpoint failover mid-drain can re-deliver rows, and new tip rows shift the `skip` window
  between page fetches — both are why the dedup comparison must use the *running* max.
- WebSocket streaming is unavailable on some testnet endpoints (streaming disabled), hence the
  REST poller as the fallback path. Both paths must share the same dedup semantics or actions
  get double-processed when they overlap.
- `lib_update` messages carry the last-irreversible-block; `irreversible_only` defaults to true.

## XPR contract map (from the handler switches)

| Contract | Actions seen in handlers |
|---|---|
| `agentcore` | register, update, setstatus, incjobs, regplugin, addplugin, rmplugin, toggleplug, verifyplugin, approveclaim, claim, cancelclaim, transfer, release, verifyclaim, pluginres, cleanresults, removeagent |
| `agentfeed` | submit, dispute, resolve, recalc, submitctx, submitwpay, reinstate, settrust, init, setconfig, addprovider, setprovider, rmprovider, rmfeedback, cleanfback, cleandisps, cleanrecalc, cancelrecalc, submitext, verifypay, calcaggtrust |
| `agentvalid` | validator staking (`stake`, `stake:`), challenge funding (`challenge:<id>`), validator unstake withdrawals, slash refunds |
| `agentescrow` | jobs, `services`/`svcinputs` (fixed-price listings), `jobmsgs` (client↔agent thread), milestones, disputes, bids, arbitrators, funding memos (`buy:<id>`, `boost:<id>`) |
| `eosio.token` | transfer (claim deposits, challenge funding, refunds), `eosio::voters` (system stake, via enrich.ts) |

`feedback.ts` routes `init` / `setconfig` / `addprovider` / `setprovider` / `rmprovider` /
`rmfeedback` all to `handleRmFeedback()` — check that each of those admin actions really should
trigger a feedback delete, or whether it is a mis-grouped switch arm.

---

## Process failure to avoid next time

The session burned its entire tool-call budget on reconnaissance and delivered **no findings**.
Two specific causes, both avoidable:

1. **Repeated identical `read_file` calls.** The same files were read multiple times (the
   harness emitted `idempotent_no_progress_warning; count=4`). Re-reading a file you already
   have in context is pure waste and it consumed the budget.
2. **Wrong read order.** Handlers (`escrow.ts` at 1600+ lines, `agent.ts`, `feedback.ts`,
   `validation.ts`) were read before the high-yield trio (schema → poller/stream → webhooks)
   was fully digested. `escrow.ts` alone is the largest file and the lowest-yield-per-line.

**Fix:** one batched pass of 4–6 files per turn, each file read exactly once, in the order
schema → ingestion → webhooks → query layer → handlers. Stop reading and start writing the
report with at least 20% of the budget remaining. An unreported finding is worth zero.
