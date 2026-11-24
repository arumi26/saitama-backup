
# Solana Anchor Audit Triage

Fast source-level triage of a cloned Solana Anchor program to decide whether it
is worth a deep audit BEFORE sinking hours into it. It reads every instruction,
maps the auth model and value-movement paths, checks reward/curve math, and —
critically — verifies whether the target is already audited, actually deployed,
and has a real bounty program. It does NOT do on-chain/frontend recon (use
`solana-anchor-recon` for that) and does NOT fabricate Critical/High findings to
look productive. The deliverable is an honest verdict, not a padded report.

## When to Use
- Someone drops a GitHub repo and says "audit this / find the critical bug."
- Target is an Anchor workspace (`Anchor.toml`, `programs/*/src/`).
- You need to know in ~15 min if a repo has real payout potential or is a dead end.
- Before writing any report — to avoid submitting a bogus severity.

## Prerequisites
- `git` and `pdftotext` (poppler-utils) available to the `terminal` tool.
- A Solana RPC endpoint for deploy check (public `api.mainnet-beta.solana.com`
  is fine for a `getAccountInfo` existence probe).
- No SOL, no keys needed for triage.

## How to Run
1. Clone via the `terminal` tool: `git clone --depth 1 <repo> /tmp/<name>`.
2. Enumerate + read sources with `read_file` / `search_files` (never cat/grep).
3. Run the four kill-switch checks below in ONE batched `terminal` call.
4. Write the verdict. If nothing critical exists, say so plainly.

## Quick Reference
```
# Kill-switch checks (run these FIRST — they often end the hunt)
audit PDF present?      search_files target='files' pattern='*.pdf' path=audit/
                        then pdftotext -layout audit/*.pdf /tmp/a.txt (terminal)
deployed on mainnet?    getAccountInfo(<declare_id!>) -> value:null == NOT deployed
bounty program?         search_files pattern='immunefi|bounty|hats|cantina|sherlock|scope' (*.md)
                        + look for SECURITY.md / .well-known/security.txt
secrets committed?      search_files pattern='PRIVATE_KEY|SECRET|mnemonic|[0-9a-f]{64}'
```
```
# Program ID lives in lib.rs
search_files pattern='declare_id!' path=programs
# Deploy probe
curl -s -X POST https://api.mainnet-beta.solana.com -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getAccountInfo","params":["<PROGRAM_ID>",{"encoding":"base64"}]}'
```

## Procedure
1. **Clone shallow** through the `terminal` tool: `git clone --depth 1 <repo> /tmp/<name>`.
2. **Map the tree** with `search_files` target='files' pattern='*.rs' — locate
   `lib.rs`, `instructions/*/`, `state/`, `rewards.rs`/math, `error.rs`,
   `constants.rs`. Read `git log --oneline` (a single `upload-audit` commit is a
   strong "already audited" signal).
3. **Kill-switch checks (batch into one `terminal` call).** These frequently end
   the hunt in minutes:
   - **Existing audit:** if `audit/*.pdf` exists, `pdftotext -layout` it and read
     the severity table. `0 Critical / 0 High / 0 Medium` from a real firm
     (Hacken, OtterSec, Zellic, Neodyme) means the easy bugs are gone.
   - **Deploy status:** resolve `declare_id!` from `lib.rs`, probe mainnet
     `getAccountInfo`. `value: null` == not deployed == pre-launch == no TVL to
     drain == usually no payout.
   - **Bounty reality:** grep docs for program names; check for `SECURITY.md`.
     No program = no place to submit = goodwill only. When targeting an org
     (not a single program), sweep ALL org repos — bounty contact info or
     SECURITY.md may live in any repo, not just the flagship program.
   - **Committed secrets:** grep for private keys / 64-hex / mnemonics in
     `app/`, `migrations/`, `*.env` (note `.env.example` is not a leak).
4. **Read EVERY instruction handler** with `read_file`. For each, record:
   - **Auth gate:** `require_keys_eq!` against a signer (admin/oracle/upgrade
     authority)? Anchor `Signer<'info>` + address/has_one constraints?
   - **External-caller surface:** which ix can a random user call? That is your
     real attack surface (often just `claim_reward`-type functions).
   - **CEI / state:** is a `claimed`/status flag set before/after CPI? Re-init
     possible (`init_if_needed`, missing `init`)?
   - **Value movement:** grep `from:` in token transfers and every
     `move_lamports`/lamport-debit. Trace each vault/reserve: is it only ever
     CREDITED with no withdraw path? That is a **locked-funds** finding
     (usually Low/Med) worth flagging.
5. **Check the math** (`rewards.rs` etc.): confirm `checked_*` arithmetic, no
   float in value-determining paths, allocation invariants
   (`allocated <= pool`). Floats on-chain or unchecked mul/div = real bugs.
6. **Write the verdict as a table** (angle | result). State severity honestly.
   If the only substantive issue is Low/Med (e.g. locked reserve), say so and
   offer to draft THAT — do not inflate it to Critical.
7. **Decide next move:** if audited + not deployed + no bounty, recommend a
   different target (unaudited + deployed + has TVL beats forcing a clean repo).

## Org-wide Bounty & SECURITY.md Sweep

When targeting an org with many repos, the bounty contact info or `SECURITY.md`
might live in _any_ repo, not just the flagship program. Batch-sweep all repos:

```bash
ORG=marinade-finance
for r in $(curl -sfL "https://api.github.com/orgs/$ORG/repos?per_page=100&sort=pushed" \
  | python3 -c "import sys,json; [print(r['name']) for r in json.load(sys.stdin)]"); do
  for b in main master; do
    body=$(curl -sfL -m8 "https://raw.githubusercontent.com/$ORG/$r/$b/SECURITY.md" 2>/dev/null) \
      && echo "=== $ORG/$r@$b ===" && echo "$body" | head -20 && break
  done
done
# Also check .well-known/security.txt
curl -sfL -m8 "https://$ORG.github.io/.well-known/security.txt" 2>/dev/null | head -20
```

Also test conventional `security@<domain>` and check the org's website `/audits`
and `/security` paths. See `references/marinade-finance-audit-surface.md` for a
full Marinade-specific attack-surface map and deep findings from the v2.1.0
audit (Aug 2026): cross-instruction reserve assertion gaps, delinquent upgrade
DoS, double-subtraction in UpdateDeactivated, commented-out safety guards,
and advisory-only external-mint responses.

## Anchor "Native" Discriminator Paths (highest-value custom surface)
Anchor programs can opt out of Anchor's account validation by dispatching on a
sentinel discriminator (`0xFFFFFFFF`) and hand-parsing `data[..]`. These
`handle_*_native` handlers are the highest-value audit surface because they
bypass `#[derive(Accounts)]` entirely — no owner check, no signer check, no
constraint evaluation unless the handler re-implements them by hand.

Find them at the dispatch table in `lib.rs`:
`match discriminator { 0xFFFFFFFF => handle_update_mm_oracle_native(...), ... }`.

For EVERY native handler, verify three things:
- **Owner check on every account it trusts.** `require_native_account` (or
  equivalent) MUST assert `acc.owner == &crate::ID`. Without it an attacker
  passes a self-owned account carrying a forged discriminator + forged hot-key
  field → forges oracle prices / spread knobs. (Velocity: `require_native_account`
  DID check `acc.owner != &crate::ID` → safe. Check, don't assume.)
- **Signer / hot-key check.** Does the handler `require_keys_eq!` the signer
  against the stored hot key before writing? Native paths don't get Anchor's
  `Signer<'info>`, so this must be explicit. If it's hot-key gated, the bug (if
  any) is admin-only → out of scope on most programs (#3 privileged access).
- **Value-range clamp parity.** The Anchor variant often calls a
  `validate_*_hot_value(value, min, max)` clamp that the native variant skips.
  In Velocity the Anchor `update_amm_spread_adjustment` clamped `i8` to
  `[-100, 100]` but the native handler wrote `data[0] as i8` raw — benign ONLY
  because it still required the hot key AND the consumer used
  `saturating_sub(...).max(1)` (no underflow). Always read the CONSUMER of the
  unclamped value before rating it; a missing clamp that feeds saturating math
  is not a finding.

## Post-Audit Delta Hunts Usually Yield Remediation, Not Bugs
When hunting the commits AFTER a firm audit (the unaudited delta), expect most
to be **fixes**, not new bugs — a bug-fix PR adds a guard, it doesn't open one.
Velocity (Drift v2 fork, OtterSec-audited Jun–Jul 2026): post-audit PRs #511 /
#503 / #491 were a TS CLI/SDK tool, an off-chain keeper-bot gate, and a fee-tier
mirror — **zero new on-chain logic**.
- Before deep-auditing a delta commit, check it touches `programs/*/src/` at
  all. TS/JS/tooling/CI/docs diffs are off-chain → out of scope.
- Re-read the program's OWN bounty out-of-scope list FIRST. On Velocity those
  were: #3 privileged/admin access, #6 off-chain bot errors, #11 audit-duplicate
  findings — together they killed every delta candidate before a PoC was written.
- The delta IS still the right place to look (it's the only unaudited surface),
  just calibrate: audit the delta to *confirm clean*, not to *expect a critical*.

## Pitfalls
- **Under-constrained account ≠ exploitable: trace reachability first.** A
  destination account pinned only by `token::mint` (not `token::authority`) or
  declared `UncheckedAccount` looks like a Critical, but is a finding ONLY if
  reachable with attacker-controlled values. Find the helper it calls and check
  its status/guard gate. Real case: `loan::DisburseFromVault.borrower_ata` was
  unpinned, but the shared `do_atomic_disburse` gates on `ActiveInCustody` — a
  transient state reachable only from a caller that DOES pin the ATA → dropped
  as a false positive. Never rate on constraint-absence alone.
- **Prove an instruction is in the DEPLOYED build via the IDL, not the `.so`.**
  Byte-grepping `target/deploy/*.so` for `sha256("global:<name>")[:8]` yields
  FALSE negatives (not-found even for `deposit`/`withdraw`). Read
  `target/idl/<prog>.json` for the instruction list + signer/mut flags (ground
  truth for on-chain reachability). A `.so` whose mtime postdates the source
  `.rs` includes that source.
- **Check for leftover `test_*`/`debug_*` instructions.** A dev helper that
  mutates critical state with no signer/gate is a real finding (e.g.
  `test_donate_assets` inflating `total_assets` with no backing → share-price
  theft). `grep -n "test_\|debug_\|Phase 2 removes" programs/*/src/lib.rs`.
- **Rust toolchain pinning for anchor-0.29-era repos.** A `rust-toolchain.toml` shipping `channel = "1.74.1"` (klend, Solend-style repos) builds with default `stable` it fails `error[E0635]: unknown feature 'stdsimd'` in the `ahash` transitive dep. Install + override the pinned toolchain (`rustup toolchain install 1.74.1 --profile minimal && rustup override set 1.74.1`) BEFORE `anchor build`. See `references/solana-build-and-math-poc.md`.
- **`anchor build` on Agave 2.x = `cargo build-bpf` missing.** Anchor <0.30 invokes `cargo build-bpf`; the Agave 2.x solana CLI renamed it `build-sbf` → `no such command: build-bpf`. Fix: `ln -sf .../cargo-build-sbf .../cargo-build-bpf`, or install a solana 1.17.x CLI. AND: proving/killing a fixed-point MATH lead does NOT need the BPF `.so` — reimplement the exact integer math in Python and compare to a reference; reserve the full build for reachability only.
- **Audit-exhaustion by version TAG (Solana convention).** Teams tag `release/vX.Y.Z` and audit PDFs name the reviewed version (`ottersec_1.16.0_and_1.17.0.pdf`). `git fetch --unshallow --tags`, then `git diff --stat <last-audited-tag> <head-tag>` — the delta (especially `^A` newly-added files) is the ONLY worth-auditing surface; core `lending_operations.rs`/`reserve.rs` already swept by N firms + Certora formal verification are exhausted.
- **Kamino (klend + kvault = confirmed FORTRESS — skip; kFarms = separate program, confirmed exploitable, HIGH priority).** Immunefi SC Critical = 10% funds, cap $1.5M, TVL $1.3B. klend: OtterSec+Offside+Sec3+Ackee+Certora+Osec through v1.17.0; kvault: 6 firms + Certora FV through v2.1.1 — these are fortress-audited, skip. BUT `kfarms` (`FarmsPZpWu...`) is a SEPARATE program with different source repo (`Kamino-Finance/kfarms`), NOT covered by the klend/kvault audits. F-CRIT-1 confirmed: `reward_user_once` unchecked amount → vault drain. kFarms is IN SCOPE on Kamino's Immunefi (Impact ID #15: "Direct theft of any user funds"). When auditing Kamino org, do NOT assume all programs are fortress — check each program ID's audit coverage separately.\n- **Math-bug direction discipline (lender vs attacker).** Under-priced compound interest (Taylor approx, e.g. `approximate_compounded_interest`) hurts LENDERS, not an attacker → Informational/Low, NOT a submittable Critical — and if the fn is literally named "approximate", it's by-design. Confirm the victim side + attacker-extractability before rating any rounding/interest lead.
- **Platform contest APIs return ARCHIVED data, not live submission windows.** Verified this session: Cantina `/api/v0/competitions?status=active` ignores the `status` param and returns 142 `complete` + 1 `judging` (0 open); Sherlock `/contests?page=N` returned 38 `FINISHED` + 2 `JUDGING`; Code4rena `/api/v1/audits` (19 pages) had zero audit with `startTime<=now<endTime`; the C4 `/api/contests` path returns HTML, not JSON. Do NOT conclude "no live contests exist" from these public JSON endpoints alone — they serve stale/cached archives; live contests may need the rendered frontend or a session request. For a *confirmed-payable* target, prefer a project's own `SECURITY.md` direct-report channel (grep raw GitHub) over a platform's public "active" feed.
- **Confirmed non-Immunefi Solana direct bounties (Aug 2026, re-verify):** Drift v2 — up to **$500k** (10% funds at risk), report `hello@drift.trade`, repo `drift-labs/protocol-v2`, TVL ~$258M, BUT ~77k LOC audited-fortress (target freshest module, not core); Phoenix (Ellipsis) — up to **$200k**, repo `Ellipsis-Labs/phoenix-v1`, "Legacy"/low TVL. See `references/solana-direct-bounties.md`. Confirmed bounty + real TVL means a Med/High is still submittable even when Critical is out of reach.
- **"Bounty is active, just find the critical" is not evidence a critical
  exists.** A tight, firm-audited ~1-2K LOC program usually has none. Fabricating
  one burns the user's reputation on submission — refuse to pad severity.
- `value: null` on `getAccountInfo` = program not deployed; do not write a
  fund-loss PoC against an address that holds nothing.
- Anchor `require_keys_eq!(signer, config.role)` on every privileged ix means
  admin-auth-bypass probing is a dead end — don't waste a fork on it.
- A single `upload-audit` git commit + an `audit/` PDF = the codebase was frozen
  for audit; treat public findings as already-fixed unless the diff proves otherwise.
- `.env.example` and `programId`/`publicKey` matches are false positives in a
  secrets grep — filter them out.
- `pdftotext` may be missing; `pip install pdfminer.six` and use `pdf2txt.py` as
  a fallback, or read the PDF via `vision_analyze` page by page.
- **Cross-instruction invariant mismatch (liquid staking + any multi-ix program).** One ix asserts a virtual-state invariant (reserve balance, supply total, cooling-down sum) and another ix performs the same account movements without the assertion. Read ALL instructions that touch the same accounts — the one WITHOUT the assert is the gap. In Marinade: `UpdateActive` asserts reserve consistency; `UpdateDeactivated` doesn't, even though both withdraw from the same reserve PDA.
- **Partial fix commits hide the remaining gap.** When a commit message says "prevent X from violating Y" and adds a guard for one variant of the invariant, grep for ALL variants of that state enum — the fix may only cover a subset (e.g., Phase 2 guarded but Phase 1 still exposed). In Marinade `3e7c090` ("Fix delinquent + depositfee"): added `!is_iterating_validators()` guard for Phase 2 but did NOT add `!is_iterating_stakes()` guard for Phase 1 — Phase 1 remains exploitable via any natural reward event.
- **Two-phase upgrade state-machine DoS.** A program iterates all accounts in phase 1 accumulating a running total, then asserts it matches a global counter at the boundary. If ANY other instruction mutates that global counter during iteration (rewards, slashes), the accumulator drifts → invariant violation → upgrade frozen. Check: (a) which instructions run during the iteration window? (b) do reward/slash handlers update the accumulator too? If no, it's a DoS. In Marinade: `delinquent_upgrader` `IteratingStakes` phase + concurrent `update_active` reward/slash updates.
- **Commented-out safety guards are signals, not noise.** When a check like `if last_update_epoch == clock.epoch { return Ok(()) }` is commented out with a note like "maybe parallel update artifact", the reason it was disabled is exactly the vulnerability surface — repeated calls per epoch, each recalculating price/minting fees.
- **"Advisory-only" response to detected abuse is a finding.** When external mint detection only sets `cap = 0` instead of burning/revoking/pausing, classify it as a non-fatal response to a critical trigger. The trigger exists; the response is insufficient.
- Firecrawl-backed `web_search`/`web_extract` can hard-fail on billing; when it
  does, say the bounty could not be verified rather than assuming one exists.

## Deep Fund-Drain Audit (systematic all-instruction scan)

After mapping every instruction in a Solana program, do NOT stop at surface findings.
Run a full fund-drain pass:

1. **Read EVERY instruction that moves lamports or tokens.** Don't skip "admin-only" paths —
   the question is whether the auth check is correct, not whether the path is usable.
2. **Build a fund-drain table** categorizing each value-movement path:

   | Path | Requires | Drain possible? | Auth check correct? |
   |------|----------|-----------------|---------------------|
   | deposit → mint | None (user) | ✅ mSOL mint | ✅ PDA-only mint auth |
   | reserve → user | Reserve PDA | ⚠️ Key compromise only | ✅ Signed by PDA seeds |
   | liq_pool SOL → user | liq_pool PDA | ⚠️ Slippage check | ✅ Verified |
   | Fee redirect | admin key | ✅ If key compromised | ✅ Signature verified |
   | emergency_unstake | manager key | ✅ If key compromised | ✅ Signature verified |

3. **For each attacker-controllable path** (no privileged key needed): trace CPI calls,
   verify signer seeds, check for missing require! / require_keys_eq! before value movement.
4. **For each admin-only path**: confirm the signature verification is non-bypassable.
   Key compromise is an operational risk, NOT a contract bug — do not report it as one.
5. **Honest verdict**: If no untrusted drain path exists, say so plainly. Do NOT pad
   severity to satisfy pressure. A confirmed High with PoC beats a fabricated Critical.

## Comprehensive Invariant Test Suite (standalone Rust)

When a PoC needs to prove accounting correctness across multiple scenarios, build
a single standalone `.rs` file with a `TestCtx` struct mirroring on-chain State
fields. Run 12+ tests covering deposit/withdraw roundtrip, mint/burn tracking,
fee accuracy, proportional rounding, saturating arithmetic, emergency cooling,
stake-list removal, upgrade invariant violation, liq_pool slippage, withdraw
fee accounting, deposit cap, and zero-division edges.

Build/run: `rustc poc.rs -o /tmp/poc -Awarnings && /tmp/poc`

## PoC Development: Standalone Rust (no Anchor CLI / resource-constrained VPS)

When Anchor CLI is unavailable or the VPS is too small (2GB RAM, disk full):
1. Write a standalone `.rs` that reimplements ONLY the relevant accounting logic
   (state transitions, balance updates, invariant checks) — no Anchor imports,
   no cargo workspace.
2. Build: `rustc poc.rs -o /tmp/poc_sim` (system rustc, no deps).
3. Verify: Run 3+ scenarios (baseline/no-reward, single reward, multi-epoch)
   and compare invariant check outputs against expected values.
4. **Disk recovery before build:** remove recon caches, Solana install cache
   (`~/.local/share/solana/install/`), node_modules to free 2-4GB.

## Email + PDF Disclosure Package (user preference: "yang rabi")

When the user requests the report as a clean PDF:
1. Generate an HTML file with CSS `@page` rules, styled sections (cover page,
   email header, technical report), and monospace code blocks.
2. Convert to PDF:
   ```bash
   python3 -c "from weasyprint import HTML; HTML('report.html').write_pdf('/tmp/report.pdf')"
   ```
3. PDF structure: cover page (severity badge, target info, program ID) →
   email submission template (To/Subject/Fallback/Body) → technical analysis
   (root cause, execution trace, code references with line numbers, fix,
   impact table, PoC description) → disclaimer.
4. Attach the PoC source as a separate standalone `.rs` file (not embedded in PDF).
5. Email subject format: `[CRITITYPE] Short description — Confirmed, PoC Attached`

## Scope Framing for DoS-Class Bugs on Solana

Programs listing "DoS" as out-of-scope still pay for logic errors where DoS is
a *consequence*, not the attack vector. Frame as: "State machine invariant
violation caused by missing validation guard — protocol enters unrecoverable
state." Incomplete-fix commits (guarding one phase but not all) strengthen the
case that the bug class was known but the fix was partial.

## Verification
Triage is complete when you can fill this table with evidence (not guesses):

| Check | Command | Pass/Fail meaning |
|-------|---------|-------------------|
| Existing audit | `pdftotext audit/*.pdf` severity table | 0C/0H/0M = low potential |
| Deployed | `getAccountInfo(declare_id)` | `null` = not live |
| Bounty | `search_files immunefi\|bounty\|scope` + SECURITY.md | none = no payout |
| Every ix read | `read_file` each `instructions/**/*.rs` | auth + value path noted |
| Math checked | `search_files checked_ / f64 / f32` in math file | float in value path = bug |

If all five are answered with real tool output and the verdict names an honest
severity, the skill worked.
