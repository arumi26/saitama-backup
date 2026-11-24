# Orbit Protocol Audit — Blast L2 Lending (July 2026)

## Target Summary
- **Protocol:** Orbit Protocol (Compound v2 fork on Blast L2)
- **Chains:** Blast L2
- **TVL:** ~$498K (Blast Lending)
- **Category:** Lending
- **Audit Status:** NO AUDIT FOUND
- **GitHub:** `orbit-protocol/contracts` (public)
- **Bounty:** Immunefi (Critical max ~$100K)

## Key Vulnerabilities Found (7 Total)

| ID | Title | Severity | Contract | Bounty Est. |
|----|-------|----------|----------|-------------|
| ORB-01 | Blast Native Yield Theft | CRITICAL | `OToken` / `OTokenV2` / `OEtherV2` | $50K-$100K |
| ORB-02 | Oracle Price Staleness | CRITICAL | `PythOracleProxy` / `RedstoneOracleProxy` / `SpaceStation` | $50K-$100K |
| ORB-03 | No Timelock on Admin Functions | CRITICAL | `SpaceStationUpgradable` / `SpaceStation` | $100K+ |
| ORB-04 | Interest Rate Model Owner Manipulation | HIGH | `BaseJumpRateModelV2` / `JumpRateModelV2` | $25K-$50K |
| ORB-05 | Liquidation Uses Stale Exchange Rate | MEDIUM | `SpaceStation` | $10K-$25K |
| ORB-06 | Missing Price Freshness in Liquidation | MEDIUM | `SpaceStation` | $10K-$25K |
| ORB-07 | COMP Speed Manipulation | LOW | `SpaceStation` | $1K-$5K |

---

## Detailed Findings

### ORB-01: Blast Native Yield Theft
**Root Cause:** Protocol configures USDB and WETH markets with `YieldMode.CLAIMABLE` but **never implements yield claiming/distribution**. Native Blast yield (~4% APY on USDB, ~3-4% on WETH) accumulates in oToken contracts indefinitely.

```solidity
// VULNERABLE: OToken.sol initialize()
BlastContract.configureClaimableYield();
BlastContract.configureClaimableGas();
WETHBlast.configure(YieldMode.CLAIMABLE);
USDBBlast.configure(YieldMode.CLAIMABLE);
```

**Impact:** Suppliers receive 0% of Blast native yield. Yield accumulates in oToken contracts and can be claimed by:
- Admin via `_blastClaimYieldAll()`
- Anyone via `BlastContract.claimYield()` on oToken addresses

**Fix Options:**
1. **Switch to AUTOMATIC mode** (recommended): Auto-compounds to suppliers
   ```solidity
   BlastContract.configureAutomaticYield();
   WETHBlast.configure(YieldMode.AUTOMATIC);
   USDBBlast.configure(YieldMode.AUTOMATIC);
   ```
2. **Keep CLAIMABLE + implement distribution:** Add `claimBlastYield()` called by keeper, distribute pro-rata

---

### ORB-02: Oracle Price Staleness
**Root Cause:** 
- RedstoneOracleProxy: `priceInvalidAfterSeconds = 86400` (24 HOURS!)
- PythOracleProxy: `priceInvalidAfterSeconds = 60` but **no staleness check in Comptroller**
- No validation in `liquidateCalculateSeizeTokens()`, `liquidateBorrowAllowed()`, `borrowAllowed()`

```solidity
// RedstoneOracleProxy - 24 HOUR STALENESS!
uint private priceInvalidAfterSeconds = 86400;

// SpaceStation.liquidateCalculateSeizeTokens() - NO STALENESS CHECK
uint priceBorrowedMantissa = oracle.getUnderlyingPrice(OToken(oTokenBorrowed));
uint priceCollateralMantissa = oracle.getUnderlyingPrice(OToken(oTokenCollateral));
```

**Impact:** Prices can be stale for days before used in liquidations/borrowing. Attacker can manipulate stale prices or wait for natural drift to trigger bad liquidations.

**Fix:** Add staleness checks in Comptroller before using oracle prices.

---

### ORB-03: No Timelock on Admin Functions
**Root Cause:** ALL critical admin functions executable instantly by single admin key:

```solidity
// SpaceStation.sol - NO TIMELOCK
_setPriceOracle()      // Change oracle to malicious one
_setCloseFactor()      // Change liquidation close factor
_setCollateralFactor() // Change collateral factors
_setLiquidationIncentive()
_setReserveFactor()
_setInterestRateModel() // Swap to malicious IRM
_reduceReserves()       // Drain protocol reserves
_supportMarket()        // Add malicious market
_setMarketBorrowCaps()
_setPauseGuardian()
_become()               // Upgrade to malicious implementation
```

**Impact:** Single admin key compromise = instant 100% TVL loss.

**Fix:** Deploy `TimelockController` (48h delay), transfer admin to timelock, restrict all admin functions to `onlyTimelock`.

---

### ORB-04: Interest Rate Model Owner Manipulation
**Root Cause:** `BaseJumpRateModelV2` has `owner` that can change:
- `baseRatePerYear` → set to 1000%+ for instant liquidations
- `multiplierPerYear`, `jumpMultiplierPerYear` → force max rates
- `kink` → move to 0% for instant max rate

```solidity
// BaseJumpRateModelV2.sol - owner can change ALL parameters
function setBaseRatePerYear(uint) external onlyOwner { ... }
function setMultiplierPerYear(uint) external onlyOwner { ... }
function setJumpMultiplierPerYear(uint) external onlyOwner { ... }
function setKink(uint) external onlyOwner { ... }
```

**Fix:** Add timelock to IR model, or make parameters immutable at deployment.

---

### ORB-05: Liquidation Uses Stale Exchange Rate
**Root Cause:** `liquidateCalculateSeizeTokens()` uses `exchangeRateStored()` (cached, NO accrue) instead of `exchangeRateCurrent()` (accrues interest first).

```solidity
// SpaceStation.sol:1017 - VULNERABLE
uint exchangeRateMantissa = OToken(oTokenCollateral).exchangeRateStored();

// Should be:
uint exchangeRateMantissa = OToken(oTokenCollateral).exchangeRateCurrent();
```

**Impact:** Liquidator receives fewer collateral tokens than owed. Borrower keeps excess collateral. Protocol accumulates bad debt over time.

---

### ORB-06: Missing Price Freshness in Liquidation
**Root Cause:** `liquidateBorrowAllowed()` only checks `price != 0`, NOT staleness.

```solidity
uint priceBorrowedMantissa = oracle.getUnderlyingPrice(OToken(oTokenBorrowed));
uint priceCollateralMantissa = oracle.getUnderlyingPrice(OToken(oTokenCollateral));
if (priceBorrowedMantissa == 0 || priceCollateralMantissa == 0) {
    return Error.PRICE_ERROR;
}
// NO: require(block.timestamp - oracle.getLastUpdateTime(oToken) <= THRESHOLD)
```

---

### ORB-07: COMP Speed Manipulation
**Root Cause:** `setCompSpeedInternal()` callable by admin without timelock.

---

## Remediation Patterns

### Pattern 1: Blast Yield Distribution
```solidity
// Option A: Switch to AUTOMATIC (recommended)
BlastContract.configureAutomaticYield();
WETHBlast.configure(YieldMode.AUTOMATIC);
USDBBlast.configure(YieldMode.AUTOMATIC);

// Option B: Keep CLAIMABLE + periodic claim+distribute
function claimBlastYield() external {
    uint256 usdbYield = USDBBlast.getClaimableAmount(address(this));
    uint256 wethYield = WETHBlast.getClaimableAmount(address(this));
    if (usdbYield > 0) USDBBlast.claim(address(this), usdbYield);
    if (wethYield > 0) WETHBlast.claim(address(this), wethYield);
    _distributeYieldProRata(usdbYield, wethYield);
}
```

### Pattern 2: TimelockController for ALL Admin Functions
```solidity
// In SpaceStationUpgradable constructor
timelock = new TimelockController(2 days, [], [], msg.sender);
admin = address(timelock);

modifier onlyTimelock() {
    require(msg.sender == address(timelock), "NOT_TIMELOCK");
    _;
}

function _setPriceOracle(PriceOracle newOracle) public onlyTimelock returns (uint) { ... }
function _setCloseFactor(uint newCloseFactorMantissa) external onlyTimelock returns (uint) { ... }
function _setCollateralFactor(OToken oToken, uint newCollateralFactorMantissa) external onlyTimelock returns (uint) { ... }
// ... ALL admin functions
```

### Pattern 3: Oracle Staleness Validation
```solidity
// In SpaceStation
uint256 public constant PRICE_STALENESS_THRESHOLD = 300; // 5 minutes

function _validatePriceFreshness(address oToken) internal view {
    uint256 lastUpdate = oracle.getLastUpdateTime(oToken);
    uint256 threshold = PRICE_STALENESS_THRESHOLD;
    if (priceStalenessThresholds[oToken] > 0) threshold = priceStalenessThresholds[oToken];
    require(block.timestamp - lastUpdate <= threshold, "ORACLE_STALE");
}

function _validateLiquidationPrices(address oTokenBorrowed, address oTokenCollateral) internal view {
    _validatePriceFreshness(oTokenBorrowed);
    _validatePriceFreshness(oTokenCollateral);
}
```

### Pattern 4: Liquidation Uses Current Exchange Rate
```solidity
// SpaceStation.liquidateCalculateSeizeTokens()
uint exchangeRateMantissa = OToken(oTokenCollateral)
    .exchangeRateCurrent(); // ACCRUES INTEREST instead of stored rate
```

### Pattern 5: Blast Yield Auto-Compounding (Best)
```solidity
// In OToken/OTokenV2/OEtherV2 initialize()
BlastContract.configureAutomaticYield();
BlastContract.configureAutomaticYieldOnBehalf(address(this));
WETHBlast.configure(YieldMode.AUTOMATIC);
USDBBlast.configure(YieldMode.AUTOMATIC);
```

---

## Attack Scenarios

### Scenario 1: Full Protocol Drain (Admin Key Compromise)
1. Attacker gets admin key
2. `_setPriceOracle(maliciousOracle)` → returns 1000x prices
3. All positions appear massively undercollateralized
4. Liquidators liquidate ALL positions at 1000x real value
5. `_reduceReserves(max)` → drain reserves
6. `_become(maliciousImpl)` → upgrade to rug contract
6. **Result: 100% TVL stolen**

### Scenario 2: Oracle Manipulation + Liquidation
1. Wait for Redstone price to go stale (24h window)
2. Manipulate Redstone feed or wait for natural drift
3. Trigger liquidations at stale prices
4. Liquidators profit, protocol takes bad debt

### Scenario 3: Blast Yield Theft (Ongoing)
1. Suppliers deposit USDB/WETH
2. Blast yield accumulates in oToken contracts (~3-5% APY)
3. Admin calls `_blastClaimYieldAll(admin)` periodically
4. Suppliers lose 100% of native yield permanently

---

## Testing Patterns

### Foundry PoC Structure
```solidity
contract OrbitVulnerabilities is Test {
    MockBlast blast;
    MockOToken oUSDB;
    MockOToken oWETH;
    MockComptroller comptroller;
    MockPriceOracle oracle;
    
    function setUp() public {
        blast = new MockBlast();
        oracle = new MockPriceOracle();
        comptroller = new MockComptroller();
        // ... deploy mocks
    }
    
    function test_ROB01_BlastYieldTheft() public {
        // 1. Alice supplies 100k USDB
        // 2. Simulate 30 days of Blast yield (333 USDB)
        // 3. Blast yield accrues in oUSDB contract
        // 4. Alice balance unchanged - she gets 0% yield
        // 5. Admin claims all yield
    }
    
    function test_ROB02_OracleStaleness() public {
        // 1. Bob borrows against WETH collateral
        // 2. Fast forward 48h - oracle stale
        // 3. WETH price drops 50% but oracle shows old price
        // 4. Liquidation executes at stale price
    }
    
    function test_ROB05_StaleExchangeRate() public {
        // 1. Setup position
        // 2. Fast forward 100 days without transactions
        // 3. Stored exchange rate is 1.00, current is 1.01
        // 4. Liquidation uses 1.00 → liquidator underpaid
    }
}
```

---

## Submission Checklist for Immunefi

- [ ] `AuditReport.md` — Full technical report
- [ ] `poc/OrbitVulnerabilities.t.sol` — Foundry test suite
- [ ] `remediation/*.patch` — 6 patch files
- [ ] `SUBMISSION.md` — Summary with KYC info
- [ ] Verify all PoCs compile and pass: `forge test --match-contract OrbitVulnerabilities -vvvv`

---

## Key Lessons for Future Audits

1. **Blast L2 Specific:** Always check `YieldMode` configuration. CLAIMABLE without distribution = yield theft.
2. **Compound v2 Forks:** Check oracle staleness in Comptroller BEFORE using prices in liquidation/borrow.
3. **Admin Timelock:** Every protocol should have TimelockController. No exceptions.
4. **Interest Rate Models:** Owner-controlled IR models are single-point-of-failure.
5. **Liquidation Precision:** Always use `exchangeRateCurrent()` (accrues) not `exchangeRateStored()` (cached).
6. **Blast Integration:** Verify `configureAutomaticYield()` or implement claim+distribute.
7. **Orbit Protocol Specific:** No audit, Compound v2 fork on Blast, Pyth + Redstone oracles, no timelock.