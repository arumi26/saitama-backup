# TxFlow Bridge2 M-01 Replay Guard Gap (2026-09)

## Gap Description

The OZ audit (July 2026) marked M-01 (*validator-set-update replay*) as **"Resolved as recommended"** — but the deployed verified source's `updateValidatorSet` **lacks** `checkMessageNotUsed(message)` guard, while sibling functions (`modifyLocker`, `modifyFinalizer`, `emergencyUnlock`) **all call it**.

## Source Evidence

| Function | `checkMessageNotUsed` |
|----------|--------|
| `modifyLocker` | ✅ Ada (L612) |
| `modifyFinalizer` | ✅ Ada |
| `emergencyUnlock` | ✅ Ada |
| `updateValidatorSet` | ❌ **TIDAK ADA** (L466) |

`updateValidatorSet` (L466) calls `updateValidatorSetInner` directly with no replay guard. Message hash is statically derived via `makeMessage(data)` — no timestamp or nonce binding that would naturally prevent replay.

## Exploit Condition

- Attacker captures a valid `updateValidatorSet` signature from any authorized validator.
- Replays the same `updateValidatorSet` call **before dispute period expiry** (7h typical) or **after** (no guard resets `usedMessages`).
- Result: validator set can be updated/replaced with stale signatures — **validator set hijacking**.

## Kill Criteria (Embedded in `evm-bug-bounty-recon` skill)

Before any PoC scaffolding on a new target:

1. `curl -s -o /dev/null -w '%{http_code}' https://<target>/.well-known/security.txt` → not 200
2. `https://immunefi.com/bug-bounty/<project>/` → 404
3. `https://hackerone.com/<project>` / `https://bugcrowd.com/<project>` → 404
4. Google `site:immunefistatus.com <project>` → no result

**If ALL 4 resolve 404/missing → `Verdict: KILL - no public program`.** Do not scaffold PoC. The bug may be real but unreportable.

## Reference

- OZ audit M-01: "Resolved as recommended" (paper fix, not deployed)
- Sibling-guard sweep: when one mutating function lacks `checkMessageNotUsed`, grep the entire contract for all other `makeMessage`/`keccak256(abi.encode(...))` call sites. The one missing the guard is the active bug, and the "resolved" audit finding is a paper fix.
- TxFlow `updateValidatorSet` vs `modifyLocker` guard inconsistency is the canonical example of this gap class.
