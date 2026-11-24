# Impact-Gate Triage: "Real Bug, Zero Impact" False Positives

The most seductive false positive is a **genuine** logic flaw whose exploitation path is
independently blocked. A flawed validation check is only a vulnerability if the
value-extraction path it "guards" is also reachable by an attacker. Always trace from the
bad check to the function that actually MOVES funds, and confirm that function isn't gated
to the legitimate owner.

## Case study: Teller v1 CollateralFacet XOR check (DEBUNKED, do not re-report)

`teller-protocol/teller-protocol-v1` @ `develop`, `contracts/market/CollateralFacet.sol`.

```solidity
// depositCollateral(loanID, amount) — permissionless, any loanID
uint256 status = uint256(LibLoans.loan(loanID).status);
require(
    status == (uint256(LoanStatus.TermsSet) ^ uint256(LoanStatus.Active)) & status,
    "Teller: loan not active or set"
);
```

Enum (verified from `contracts/storage/market.sol`):
`enum LoanStatus { NonExistent=0, TermsSet=1, Active=2, Closed=3, Liquidated=4 }`

The check reduces to `status == (1 ^ 2) & status` = `status == 3 & status`. Truth table:

| status | `3 & status == status`? | intended pass? |
|--------|-------------------------|----------------|
| 0 NonExistent | ✅ passes | ❌ (bug) |
| 1 TermsSet | ✅ | ✅ |
| 2 Active | ✅ | ✅ |
| 3 Closed | ✅ passes | ❌ (bug) |
| 4 Liquidated | ❌ blocked | ❌ |

So the bug is **real**: `Closed(3)` and `NonExistent(0)` wrongly pass the deposit gate.

**Why impact is ZERO (the gate that kills it):**
```solidity
function withdrawCollateral(uint256 amount, uint256 loanID) external ... {
    require(msg.sender == LibLoans.loan(loanID).borrower, "Teller: not borrower"); // <-- OWNER-ONLY
    ...
    if (status == LoanStatus.Active) { /* ratio check */ }  // skipped for non-Active
    LibCollateral.withdraw(loanID, amount, loan.borrower);   // <-- always to borrower
}
```
- Withdraw is gated to `loan.borrower`. An attacker cannot pull collateral a victim
  deposited into someone else's closed loan.
- The only "exploit" is a borrower depositing to their OWN closed loan and withdrawing it
  back = moving their own money. No loss to protocol or other users.
- No realistic incentive for a victim to deposit into a stranger's closed loan.

Net: a deposit sanity-check bug with no fund-loss path. Submitting it as "collateral theft
CRITICAL" gets triager-rejected and hurts reputation.

## Verification workflow (repeat for every "validation bug")
1. Read the actual source (raw GitHub), not memory or a prior-session report.
2. Verify enum/const ordering from source — never assume `Closed` etc. maps to a value.
3. Compute the check's real truth table (a quick Python script beats eyeballing bitmasks).
4. Find the function that MOVES funds out. Read its independent guards (owner check,
   ratio check, allowance). If those block the attacker, impact is zero.
5. Only then decide severity. PoC-first still applies for anything you'd actually submit.

## Prior-session report hygiene
A finished PDF/`report.md` on disk is a *self-report*, not verified truth. Before telling
the user any inventory item is submittable, re-read current source + re-run its PoC THIS
session. In one pass: the Teller XOR PDF (claimed CRITICAL) collapsed on re-trace, while
PerpBond/iAERO's Foundry PoC re-ran 2/2 green (`forge test --match-path
test/DistributorYieldTheftPOC.t.sol` — Path A insolvency + Path B share-cycling drain) and
stayed genuinely submittable via email `iaero@proton.me` (git-author contact; no formal
bounty program, informal disclosure).
