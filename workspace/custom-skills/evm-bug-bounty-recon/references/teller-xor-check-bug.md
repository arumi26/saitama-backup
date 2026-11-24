# Teller Protocol — XOR Status Check Logic Bug

**Date:** 2026-08-11
**Source:** Live session audit of `teller-protocol/teller-protocol-v1`
**Status:** 0 audits, unpatched, $0.5M TVL

## Finding: CollateralFacet.depositCollateral() XOR Status Check

**Contract:** `contracts/market/CollateralFacet.sol`, lines 41-44
**Severity:** CRITICAL — collateral theft via trapped deposits

### Vulnerable Code

```solidity
uint256 status = uint256(LibLoans.loan(loanID).status);
require(
    status ==
        (uint256(LoanStatus.TermsSet) ^ uint256(LoanStatus.Active)) &
            status,
    "Teller: loan not active or set"
);
```

### Bug Math

LoanStatus enum:
- TermsSet = 1 (binary: 01)
- Active = 2 (binary: 10)
- Closed = 3 (binary: 11)
- Liquidated = 4 (binary: 100)

XOR check: `TermsSet(1) ^ Active(2) = 3`

Which statuses pass `status == 3 & status`?
- TermsSet(1): 1 == 3 & 1 = 1 → ✅ PASSES (intended)
- Active(2): 2 == 3 & 2 = 2 → ✅ PASSES (intended)
- Closed(3): 3 == 3 & 3 = 3 → ✅ PASSES (UNINTENDED!)
- Liquidated(4): 4 == 3 & 4 = 0 → ❌ BLOCKED (by accident)

### Exploit Chain

1. Attacker creates loan (borrower = attacker)
2. Attacker repays loan fully → status = Closed, collateral returned
3. Loan is Closed but `depositCollateral()` still works (XOR bug)
4. Victim deposits collateral into "closed" loan
5. Attacker calls `withdrawCollateral()` → gets victim's tokens
6. `withdrawCollateral()` has NO amount check for Closed loans (line 76-85)

### Intended Behavior

```solidity
// Should be:
require(
    status == uint256(LoanStatus.TermsSet) || status == uint256(LoanStatus.Active),
    "Teller: loan not active or set"
);
```

### Remediation

Replace XOR check with explicit OR:
```solidity
require(
    status == uint256(LoanStatus.TermsSet) || status == uint256(LoanStatus.Active),
    "Teller: loan not active or set"
);
```

### Audit Checklist

Whenever you see `a ^ b` in a condition:
1. Trace the actual bit math with all possible enum values
2. Prefer `status == A || status == B` for enum checks
3. XOR+AND is only correct for masked bitmap checks (multiple flags in one uint)
4. Test with Closed(3) and Liquidated(4) — these are the most common unintended passthroughs