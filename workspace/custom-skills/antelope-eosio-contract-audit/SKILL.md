
# Antelope / EOSIO Contract Audit (AssemblyScript)

Antelope (the EOSIO lineage: EOS, WAX, Telos, **Proton**, **XPR Network**) smart contracts are
written in **AssemblyScript** (`assembly/<name>.contract.ts`), not Solidity. There is no Foundry,
no `forge test`, no EVM bytecode. The test harness is **`@proton/vert`** (a JS chain simulator) run
through **mocha**. If you reach for `forge` you are on the wrong chain — re-read the repo.

Everything here is the non-EVM analogue of `evm-smart-contract-audit`; keep the same discipline
(PoC-first, honest severity, disclosure confirmation) but use the Antelope toolchain below.

## 0. Recon & scope (do first, ~5 min)

```bash
git clone --depth 1 https://github.com/<org>/<repo>.git
cat SECURITY.md            # disclosure policy — READ THIS FIRST (see §6)
find contracts -name "*.contract.ts" -not -path "*/node_modules/*"   # the attack surface
find . -path "*/node_modules" -prune -o -name "*.ts" -print | wc -l  # off-chain surface
```

Typical Antelope monorepo shape (XPR Network `xpr-agents`):
`contracts/<name>/assembly/<name>.contract.ts` + `tests/` + `patches/` · `indexer/` (off-chain) ·
`openclaw/` or `sdk/` (client + agent runner) · `frontend/` · `docs/SECURITY_AUDIT.md`.

**The docs/SECURITY_AUDIT.md is a treasure map, not a blocker.** Mature Antelope projects ship a
long audit log listing every prior finding + its fix commit + the reward paid. Read it to (a) map
what is already covered, (b) find the *freshest* code (the last fix commits — post-audit code is
where undiscovered bugs live), and (c) calibrate severity against what the team actually paid for
the same class. Do NOT re-report a listed finding; hunt its **incomplete fix**.

## 1. Build (contracts import each other — build dependencies first)

```bash
cd contracts/<dep>     && npm install && npm run build    # e.g. agentcore (imported by others)
cd ../<target>         && npm install && npm run build
# output: assembly/target/<name>.contract.wasm  (+ .abi)
```

A contract that imports another (e.g. `agentvalid` imports `agentcore`) will NOT build until the
dependency's `assembly/target/*.wasm` exists. `npm install` per contract is slow — run it in
`terminal(background=True, notify_on_complete=True)` if the dep tree is large. On a disk-tight box,
`go clean -cache` / clear `/tmp` before installing.

## 2. PoC harness — `@proton/vert`

```ts
import { Blockchain, protonAssert, expectToThrow, mintTokens, nameToBigInt } from '@proton/vert';
import { TimePointSec } from '@greymass/eosio';
```

Run a single test / the whole suite:

```bash
npx ts-mocha -p tests/tsconfig.json tests/<file>.test.ts --timeout 60000
npx ts-mocha -p tests/tsconfig.json tests/*.test.ts     --timeout 60000
```

**Always mirror the project's existing test setup verbatim** (copy the `bootstrap()` /
`resetTables()` / `mintTokens` / contract-deploy block from an existing `tests/*.test.ts`) — vert
setup is fiddly and their harness already encodes the right deploy order and auth accounts.
Full runnable template + the exact setup block: `references/proton-vert-harness.md`.

### vert pitfalls that waste hours (both hit this session)

- **Chain time starts at 0 and persists across tests in one run.** If an action requires a nonzero
  timestamp (e.g. `check(challengeRecord.funded_at > 0)` in `resolve`), a test that never advances
  the clock fails for the *wrong* reason. Nudge it in the bootstrap:
  `blockchain.addTime(TimePointSec.from(1000000));`
- **`expectToThrow` corrupts the vert tx context.** Do not call it mid-chain and then keep using the
  same contract handles — the following sends break. Structure a test so the throwing call is the
  LAST step, or isolate it with a fresh `resetTables()` + redeploy.
- `blockchain.resetTables()` in bootstrap; `mintTokens(token, 'XPR', 4, ...)` to fund accounts;
  `nameToBigInt('acct')` to compare `Name` table keys.

## 3. Verify the reviewed source == the DEPLOYED code (mandatory before disclosing)

Antelope contracts are deployed by code-hash. Prove the source you audited is live:

```bash
sha256sum contracts/<name>/assembly/target/<name>.contract.wasm
curl -s -X POST https://api-xprnetwork-main.saltant.io/v1/chain/get_code_hash \
  -d '{"account_name":"<name>"}'
```

Equal hash ⇒ the reviewed commit **is** the on-chain code ⇒ the finding is live and submittable.
Different hash ⇒ you are auditing unshipped code; say so, don't overclaim. (Helper:
`scripts/verify-deployed-hash.sh`.) Note: the wasm hash depends on the build, so build from the
exact commit and don't touch sources in between.

## 4. Antelope bug classes to hunt (highest EV first)

1. **Reactive-guard action-ordering bypass** — THE money bug. A guard (time-lock, state check) that
   is evaluated at action time and keyed on *existing* state can be outrun by reversing the action
   order. Canonical case: `unstake()` refuses while `valactivity` exists (post-validation lock), but
   `validate()` never checks for a pending unstake — so `unstake(90%) → validate()` evades it and
   only `min_stake` stays slashable. Same root cause as the already-paid finding, opposite ordering.
   **Grep the fix commit, then check the mirror-image path.** See §5.
2. **Asymmetric time-locks** — the team patched `unstake()` but not `withdraw()`/`resolve()` to read
   the same table. Whenever you see one function enforce an invariant, grep every sibling that can
   release/exit value and confirm it enforces the *same* invariant.
3. **Cross-contract `notify` auth** — `@action("transfer", notify)` handlers and inline actions.
   Check the notify handler validates `from`/`to`/memo and that inline `sendTokens` can't be spoofed.
   Check `requireAuth(x)` vs `hasAuth(x)` — a money path with `hasAuth` is attacker-invokable.
4. **Contract-RAM sinks (unbounded state)** — a permissionless action that `store()`s a row on the
   contract's own RAM with no per-account/per-job cap. Often "fixed" for one table (`createjob`)
   but left open on a sibling (`submitbid`) → free RAM exhaustion / state bloat.
5. **Unbounded iteration** — `while`/`for` over a table with no `max_delete`/cap; combined with a
   RAM sink it's a DoS.
6. **`availablePrimaryKey` vs synthetic PK** — see `onchain-indexer-audit` for the divergence class
   between a contract's `availablePrimaryKey` and an indexer's synthetic id.
7. **Arithmetic** — AssemblyScript `u64`/`i64`; watch `/ 10000` basis-point math, `checked_*` vs
   bare ops, and division-before-multiplication.

## 5. The reactive-guard bypass, worked (case study: XPR `agentvalid` SLASH-2026-02)

The team's own fix comment is the tell — it documents *one* ordering:

```ts
// SECURITY (XPRA-VALID-SLASH-2026-01): keep the stake at risk through the window ...
const activity = this.valActivityTable.get(account.N);
if (activity != null) {            // <-- only fires when a PRIOR validation exists
  const riskEnd = activity.last_validation_at + config.challenge_window + this.FUNDING_WINDOW;
  check(currentTimeSec() > riskEnd, "Cannot unstake yet: stake stays at risk ...");
}
```

`validate()` writes the row but never checks for a pending unstake → reverse the order:

```
1. unstake(90% of stake)   // no valactivity row -> lock does NOT fire
2. validate(dishonest)     // stake already out of reach; min_stake remains
3. challenge upheld        // resolve() slashes only validator.stake (now min_stake)
4. withdraw() after delay  // 90% released; withdraw() never reads valactivity either
```

Effect: slash drops from `full_stake × slash%` to `min_stake × slash%` (~90% of the penalty
evaporates). Proved with a 3-case vert PoC: (1) validate→unstake is blocked, (2) baseline upheld
challenge slashes 10% of full stake, (3) reordered chain slashes 10% of min_stake and withdraws the
rest. Full test + harness in `references/proton-vert-harness.md`.

**Preferred fix to recommend:** gate `validate()` on having no pending unstake (removes the
reordering primitive) rather than patching each downstream consumer.

## 6. Disclosure policy — CONFIRM BEFORE CLAIMING

Many Antelope projects have **no bug bounty at all**. XPR Network's `SECURITY.md` routes reports to
a **public GitHub issue** and explicitly auto-closes AI-generated / unreproduced submissions. So:
- Read `SECURITY.md` first and state plainly whether it is a paid program or plain responsible
  disclosure. Do not imply a reward that doesn't exist.
- The user drives the actual submission (they send the email / open the issue) — never submit
  yourself, and never exploit on mainnet. See `crypto-bug-bounty` §"Submission Strategy" and
  `report-writing` for the tiered format.
- A credible package: `report.md` + `report.pdf` + the runnable PoC `.test.ts` + `README` +
  `COMMIT` (commit hash **and** the mainnet code-hash match line) + `test-output.txt`.

## Pitfalls

- **Don't reach for Foundry/Solidity tooling.** Antelope = AssemblyScript + `@proton/vert`. Confirm
  the VM from the repo layout before planning the PoC.
- **Don't re-report a finding already in `docs/SECURITY_AUDIT.md`** — hunt its incomplete fix
  instead (that is exactly where SLASH-2026-02 was).
- **Build dependency contracts first** or your target won't compile.
- **Nudge chain time** in bootstrap (see §2) or timestamp-gated actions fail spuriously.
- **Prove the code-hash match** before claiming the bug is live.
- **Report only what a green PoC shows.** A green local PoC proves the *math/logic*, not mainnet
  reachability — but on Antelope with a matching code-hash it is strong.

## Related

- `crypto-bug-bounty` — umbrella workflow, submission strategy, incomplete-fix class.
- `onchain-indexer-audit` — the off-chain indexer half of these monorepos (Antelope/Hyperion).
- `evm-smart-contract-audit` / `solana-smart-contract-audit` / `cosmos-sdk-defi-audit` — sibling
  per-chain umbrellas.
