# Enzyme Onyx Protocol Deep Dive — Case Study

**Date:** 2026-07-17  
**Target:** Enzyme Finance Onyx (tokenization vault protocol)  
**Chain:** Ethereum, Arbitrum, Base, MegaETH, Plume  
**Bounty:** Immunefi — $200K max, **NO KYC**, Live since Sep 2025  
**Audit Status:** 1 audit (ChainSecurity, Sep 2025)  
**Language:** Solidity 0.8.28 (BUSL-1.1)

---

## Protocol Architecture

Onyx is a **tokenization vault framework** — Shares (ERC20) + modular components:
- **Shares.sol** — Core ERC20 with admin-controlled deposit/redeem handlers, fee handler, valuation handler
- **ValuationHandler** — Aggregates `tracked` (IPositionTracker) + `untracked` (admin input) positions; settles fees
- **FeeHandler** — Entrance/exit fees (bps), management fee (IManagementFeeTracker), performance fee (IPerformanceFeeTracker)
- **Deposit/Redeem Handlers** — Sync (instant) + ERC7540-like async queues
- **Position Trackers** — LinearCreditDebtTracker, AccountERC20Tracker, etc.

---

## Critical Findings (2026-07-17 Session)

### ONYX-01: Admin Share Price Manipulation via Negative `_untrackedPositionsValue` — **HIGH**
**File:** `ValuationHandler.sol` lines 229-295

```solidity
function __updateShareValue(int256 _untrackedPositionsValue) internal returns (uint256 netShareValue_) {
    // Line 265: NO validation on _untrackedPositionsValue sign!
    uint256 totalPositionsValue = (trackedPositionsValue + _untrackedPositionsValue).toUint256();
    
    // Line 271: Fees settled on manipulated TVL
    IFeeHandler(feeHandler).settleDynamicFeesGivenPositionsValue({_totalPositionsValue: totalPositionsValue});
    
    // Line 278-280: Share price calculated from manipulated value
    netShareValue_ = ValueHelpersLib.calcValuePerShare({
        _totalValue: totalPositionsValue - totalFeesOwed, _totalSharesAmount: sharesSupply
    });
    
    // Line 286: Stores manipulated price
    $.lastShareValue = netShareValue_.toUint128();
}
```

**Attack:**
1. Admin calls `updateShareValue(-500_000e18)` (negative $500K)
2. `totalPositionsValue` underflows → massive uint256
3. FeeHandler settles fees on inflated TVL → massive fee payouts to recipients
4. Share price inflated → depositors get ~0 shares, redeemers drain vault

**Impact:** Full vault drain via admin key compromise. **Primacy of Impact applies** (admin compromise = user fund loss).

**PoC:** `test_AdminManipulatesSharePrice_NegativeUntrackedValue()` in `OnyxPriceManipulation.t.sol`

---

### ONYX-03: Performance Fee HWM Admin Override — **MEDIUM**
**File:** `ContinuousFlatRatePerformanceFeeTracker.sol` lines 109-125

```solidity
function adjustHighWaterMark(uint256 _hwm, uint256 _timestamp) external onlyAdminOrOwner {
    require(_hwm > 0, "HWM zero");
    require(_timestamp > 0, "Timestamp zero");
    require(_timestamp <= block.timestamp, "Future timestamp");
    // NO check: _hwm can be LOWER than current HWM!
    $.highWaterMark = _hwm.toUint128();
    $.highWaterMarkTimestamp = _timestamp.toUint40();
}
```

**Attack:** Admin sets HWM to `1` with past timestamp → 20% performance fee on ALL subsequent gains.

---

### ONYX-04: ERC7540 Queue Admin Censorship/Reordering — **MEDIUM**
**Files:** `ERC7540LikeDepositQueue.sol` (271-334), `ERC7540LikeRedeemQueue.sol` (180-234)

```solidity
function executeDepositRequests(uint256[] memory _requestIds) external onlyAdminOrOwner {
    // Admin chooses WHICH requests to execute and IN WHAT ORDER
    for (uint256 i; i < _requestIds.length; i++) {
        // Can skip users, execute own requests first at favorable prices
    }
}
```

**Attack:** Admin censors user redeems, executes own at high price, then tanks price for users.

---

### ONYX-02: FeeHandler Management Fee Rounding — **MEDIUM**
**File:** `ContinuousFlatRateManagementFeeTracker.sol` line 109

```solidity
valueDue_ = (_netValue * getRate() * secondsSinceSettlement) / (SECONDS_IN_YEAR * ONE_HUNDRED_PERCENT_BPS);
// Division LAST → truncates down → protocol systematically undercharges fees
```

---

### ONYX-05: SyncDepositHandler Stale Price Check Disabled — **LOW**
```solidity
function setMaxSharePriceStaleness(uint24 _maxStaleness) external onlyAdminOrOwner {
    maxSharePriceStaleness = _maxStaleness; // Can be type(uint24).max = DISABLED
}
```

---

### ONYX-06: LinearCreditDebtTracker Fake Debt Injection — **LOW**
```solidity
function addItem(int128 _totalValue, uint40 _start, uint32 _duration, string _desc) 
    external onlyAdminOrOwner {
    // _start can be in PAST → immediate value change
    // _totalValue can be NEGATIVE → reduces vault TVL artificially
}
```

---

## Attack Scenarios

### Scenario A: Compromised Admin Key (Most Realistic)
1. Attacker gains admin/owner private key
2. `valuationHandler.updateShareValue(-VAULT_TVL)` → price → 0
2. `syncDeposit.deposit(1)` → receives ALL shares
3. `valuationHandler.updateShareValue(+VAULT_TVL)` → price restored
4. Redeem all shares → drains vault

### Scenario B: Malicious Governance Proposal
1. Proposal: "Routine parameter update"
2. Calldata encodes ONYX-01 + ONYX-03 + ONYX-04
3. Passes → executes → vault drained

### Scenario C: Fee Recipient Collusion
1. Admin + management fee recipient collude
2. Set management fee rate to 100%
3. Call `resetLastSettled()` daily
4. All vault value → fee recipient over time

---

## Immunefi Submission Notes

| Finding | Severity | Bounty Range | Primacy of Impact |
|---------|----------|--------------|-------------------|
| ONYX-01 | HIGH | $50K–$100K | ✅ Admin compromise = user fund loss |
| ONYX-03 | MEDIUM | $10K–$25K | ✅ |
| ONYX-04 | MEDIUM | $10K–$25K | ✅ |
| ONYX-02 | MEDIUM | $10K–$25K | ✅ |
| ONYX-05 | LOW | $2K–$5K | ⚠️ Conditional |
| ONYX-06 | LOW | $2K–$5K | ⚠️ Conditional |

**Total Estimated:** $84K–$185K  
**Program:** NO KYC, PoC required, Category 3 Responsible Publication

---

## Files Created (Session Artifacts)

```
/tmp/enzyme-onyx-poc/
├── AuditReport.md                    # Full report with remediation
├── poc/
│   └── OnyxPriceManipulation.t.sol  # Foundry PoC (4 attack vectors)
└── README.md                         # (to create)
```

---

## Key Lessons for Future Audits

1. **Valuation modules with admin input are HIGH risk** — any `adminInput + onchainAggregation = price` pattern
2. **Admin-only ≠ out of scope** — Immunefi Primacy of Impact makes admin compromise in-scope
3. **Fee calculation order matters** — division last = truncation bias
4. **HWM/price admin setters need monotonicity checks** — can only increase, not decrease
5. **Queue execution order must be enforced** — FIFO or user-selectable, not admin-selectable
6. **Async queues (ERC7540) need price timestamp validation** — both deposit and redeem
7. **Linear write-down trackers with admin-controlled start/duration = TVL manipulation**
8. **Always check Immunefi program details first** — KYC, Primacy of Impact, audit exclusions

---

## Remediation Patterns

### ValuationHandler — Input Validation
```solidity
function __updateShareValue(int256 _untrackedPositionsValue) internal returns (uint256 netShareValue_) {
    require(_untrackedPositionsValue >= 0, "Negative untracked not allowed");
    require(totalPositionsValue <= MAX_REASONABLE_TVL, "TVL exceeds maximum");
    // ...
}
```

### Performance Fee HWM — Monotonicity
```solidity
function adjustHighWaterMark(uint256 _hwm, uint256 _timestamp) external onlyAdminOrOwner {
    require(_hwm >= getHighWaterMark(), "HWM cannot decrease");
    require(_timestamp >= block.timestamp - 1 days, "Timestamp too old");
    // ...
}
```

### Fee Calculation — Rounding Up
```solidity
valueDue_ = ((_netValue * getRate() * secondsSinceSettlement) 
    + (SECONDS_IN_YEAR * ONE_HUNDRED_PERCENT_BPS) - 1) 
    / (SECONDS_IN_YEAR * ONE_HUNDRED_PERCENT_BPS);
```

### Queue Execution — FIFO Enforcement
```solidity
function executeDepositRequests(uint256[] memory _requestIds) external onlyAdminOrOwner {
    // Must process in ascending ID order (FIFO)
    for (uint256 i = 1; i <= getDepositLastId(); i++) {
        if (idToRequest[i].controller != address(0)) _executeRequest(i);
    }
}
```

---

## References
- [Enzyme Onyx GitHub](https://github.com/enzymefinance/protocol-onyx)
- [Immunefi Enzyme Onyx Program](https://immunefi.com/bug-bounty/enzyme-onyx/)
- [ChainSecurity Audit (Sep 2025)](https://github.com/enzymefinance/protocol-onyx/tree/main/audits)