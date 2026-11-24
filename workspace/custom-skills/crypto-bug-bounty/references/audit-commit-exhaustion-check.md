# Audit-Commit Exhaustion Check & Fresh-Target Triage

The single highest-leverage move when a target ships with an `audits/` directory: prove
whether there's any *unaudited surface* left before spending a minute reading code.

## The 2-minute exhaustion check

```bash
# 1. Extract the audit's reviewed commit + scope
pdftotext -layout audits/<Firm>-<target>-review.pdf out.txt
grep -iE "COMMIT|BRANCH|SCOPE|src/" out.txt | head -30      # find "COMMIT <hash>" + file list

# 2. Fetch the exact reviewed tree (even if not in local history)
git fetch origin <audit-commit-hash>

# 3. Compute the unaudited delta
git diff --stat <audit-commit-hash> HEAD -- src/            # source changed SINCE audit
git log --oneline <audit-commit-hash>..HEAD                 # commits since audit
```

**Interpretation:**
- **Empty `src/` diff → target is fully audited → EXHAUSTED. Do not audit.** The only new
  commit being `chore: add <firm> review` (which just drops the PDF) is the classic tell.
- A recent `Merge pull request #NN from org/v2`, a "v2" label, or a new subdirectory is
  **NOT** proof of unaudited code. Check whether those files are inside the audit's reviewed
  commit AND scope list. New-looking code committed *before* the audit hash is already covered.
- If the audit lists N findings **all "Unresolved"**, the team already knows every shallow +
  medium bug. Anything you'd surface from the same commit is a public duplicate.
- Map each of YOUR prior findings against the report's finding titles. Overlap = drop it.

Only two things survive this check as worth auditing:
1. `src/` files changed strictly *after* the audit commit hash.
2. Files explicitly listed as OUT of the audit's scope.

### Non-empty diff is NOT automatically unaudited — check DIRECTION first
A non-empty `git diff <audit-commit>..HEAD -- src/` does NOT mean new code. Many repos
commit the audit's *remediation PRs* on top of the reviewed snapshot, so the diff is
**pure fix** — already reviewed by the auditor. A fat-looking diff is the trap; establish
BOTH facts below before reading a single line of code:

1. **Is the bundled PDF the final report or a draft?**
   ```bash
   grep -cE "Fixed in PR|Acknowledged|Fix verified" out.txt
   ```
   If remediation markers are present, the PDF is the **post-remediation final report** — the
   auditor already re-reviewed every fix. A "Fix verified" count ≈ finding count means the
   engagement is closed. (`Acknowledged` markers = accepted-by-design, not bugs.)

2. **Is the scope commit the PRE-fix or POST-fix snapshot?** Prove it with a known fix from
   the report. Pick a finding whose fix is a one-token change, then grep BOTH trees:
   ```bash
   git show <scope-commit>:src/<path>.sol | grep -n "<fixed-token>"
   git show HEAD:src/<path>.sol          | grep -n "<fixed-token>"
   ```
   Whichever tree still holds the BUGGY form is the pre-fix snapshot. Also compare dates:
   `git show -s --format="%ci %h %s" <scope-commit> HEAD` — a scope commit *older* than the
   shipped tag with fixes on top = pre-fix snapshot.

**If the diff is remediation-only (scope commit = pre-fix, PDF = final report with all
findings addressed), the shipped code is FULLY AUDITED → EXHAUSTED.** Do not audit it.

## Session case study: 3F Grunt (grunt-v1.3.0) — EXHAUSTED (remediation-only delta)
- Bundled `audits/Cantina_3F_Grunt_Audit_2026-09.pdf`, scope = **entire `src/`** at commit
  `9ae1b3cf`. But `9ae1b3cf` (2026-07-17) is a **pre-remediation snapshot**, not the shipped
  tree; the shipped tag `90e02c5` (2026-09-03, v1.3.0) is dated *after* the audit.
- `git diff --stat 9ae1b3cf HEAD -- src/` = **1416 lines across 29 files** — looks like a fat
  unaudited surface. It is entirely the auditor's own fix set (PR 208–220).
- **Direction proof:** finding 3.3.14's fix was `>=` → `>` in `Retargetter.sol`'s per-module
  post-check. `9ae1b3cf` still had `moduleLtvAfter >= moduleLtvsBefore[i]` (buggy); HEAD had
  `>`. → scope commit = pre-fix, HEAD = post-fix.
- **Remediation census:** `grep -E "^3F: (Fixed|Acknowledged)"` → 27 Fixed + 12 Acknowledged;
  `grep -c "Fix verified"` → 33. Every one of the 43 findings (1 Med, 17 Low, 25 Info) is
  either fixed-and-verified or explicitly acknowledged as intended. All v1.3.0 delta files
  (LibBorrowOffers, BorrowOffersRegistry, Retargetter, LibStorage, PositionManagerBase,
  MidasFund) are inside the audited scope.
- **Test suite:** `forge test` = **2466 passed, 0 failed**, 1 skipped. Mature + green.
- Verdict: **NO-GO.** No report. The only theoretical surface left is incidental changes in
  the remediation diff not tied to a specific finding — high effort, low hit-rate; not worth it.

## Session case study: Flex (flexmeow/flex-contracts) — EXHAUSTED
- Latest commit `ac0835f chore: add zc review` = **PDF-only, zero source change** since the
  audited commit `b96c12a`. `git diff --stat b96c12a HEAD -- src/` was empty.
- Zero Cool review (Aug 11 2026): **12 findings — 1 High, 7 Medium, 4 Low, all Unresolved.**
  Scope covered every `src/` file including the "new v2" `Lender.sol` / `LenderFactory.sol`.
- Prior-session findings collided: F3 permissionless re-kick == audit M-03; F1 oracle
  staleness overlapped M-01/M-06. All public duplicates. Verdict: nothing left to find.

## Fresh-target triage disqualifiers (run before cloning, all cheap curl)
Tight DeFiLlama filter (`tvl 0.5–50M`, EVM chain, `listedAt <120d`, has github, bug-rich
category) typically yields only 3-4 hits. Kill the dead ones fast:

| Signal | Check | Verdict |
|---|---|---|
| Main repo is a fork | `curl .../repos/<org>/<repo> \| grep '"fork"'` → `true` + `parent` | Skip — someone else's code (BTCD = fork of IPOR-Labs/ipor-fusion) |
| No Solidity/Vyper repo in org | list org repos, inspect `language` fields | Skip — not EVM (Surge Credit = Bitcoin/Taproot/MPC, all C++/Rust/TS/Go) |
| Honeypot flagged in memory/prior session | recall | Skip without re-checking (Ledgity) |
| Has fresh `audits/` review | commit-hash exhaustion check above | Usually EXHAUSTED (Flex) |

When the DeFiLlama well runs dry, don't keep widening the filter blindly. Pivot to
live-contest platforms (Cantina/Sherlock/Code4rena JSON, see `live-contest-discovery.md`)
for a guaranteed in-scope + paying target, or ask the user for a target they already have on
radar. A user-supplied target beats blind DeFiLlama scanning.
