# Common Smart Contract Vulnerability Patterns

## 1. Oracle Manipulation

### `latestAnswer()` Without Staleness Check
**Found in:** Exactly Protocol (Auditor.sol:356), Euler Finance (RiskManager.sol:192)
**Severity:** MEDIUM (Chainlink reliable, but deprecated function)
**Pattern:**
```solidity
// VULNERABLE
int256 price = priceFeed.latestAnswer();

// SAFE
(uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();
require(updatedAt > block.timestamp - 3600, "Stale price");
require(answeredInRound >= roundId, "Incomplete round");
```

### TWAP Missing (Single-Block Price)
**Found in:** Gravita Protocol (PriceFeed.sol)
**Severity:** HIGH
**Pattern:** Direct use of `latestAnswer()` without Uniswap V3 TWAP
**Attack:** Flash loan → manipulate spot price → trigger false liquidations

### ETH Oracle Single Point of Failure
**Found in:** Gravita Protocol (PriceFeed.sol:175-178)
**Severity:** HIGH
**Pattern:**
```solidity
function _calcEthIndexedPrice(uint256 _ethAmount) internal view returns (uint256) {
    uint256 ethPrice = fetchPrice(address(0));  // ← Single oracle for ALL ETH-derivative tokens
    return (ethPrice * _ethAmount) / 1 ether;
}
```

## 2. Access Control Issues

### Admin-Only Bugs (Not Permissionless)
**Found in:** Flaunch (Flaunch.sol:225)
**Severity:** CRITICAL (but requires owner key compromise)
**Pattern:**
```solidity
function setMemecoinImplementation(address _newImpl) external onlyOwner {
    memecoinImplementation = _newImpl;  // Global, no version lock
}
```
**Note:** These are real bugs but require owner key compromise. Bounty still valid for Immunefi.

### Permissionless Functions to Check
- `claim()` / `claimFees()` / `claimRewards()`
- `deposit()` / `withdraw()` / `redeem()`
- `swap()` / `flashLoan()`
- `liquidate()` / `seize()`
- `notifyTimeout()` / `notifyStale()`

## 3. Liquidation Logic

### Batch Liquidation Price Reuse
**Found in:** Gravita Protocol (VesselManagerOperations.sol:64,121)
**Severity:** CRITICAL
**Pattern:** Price fetched ONCE for entire batch (up to 25 vessels)
```solidity
vars.price = IPriceFeed(priceFeed).fetchPrice(_asset);  // Fetched once
// Used for ALL 25 vessels...
totals = _getTotalsFromBatchLiquidate_NormalMode(_asset, vars.price, ...);
```

### Health Factor Bypass
- Check if `checkBorrow()` is called AFTER state changes
- Verify collateral factor cannot be manipulated
- Check for self-collateralisation edge cases

## 4. Rounding Errors

### Direction Matters
- `mulDivUp` = rounds UP (favorable to protocol)
- `mulDivDown` = rounds DOWN (favorable to protocol)
- **Protocol-favorable rounding is NOT a bug**
- **User-favorable rounding IS a bug**

### Share Calculation Attacks
- Check `previewDeposit` / `previewMint` / `previewWithdraw` / `previewRedeem`
- Verify rounding direction is consistent
- Look for dust attacks (1 wei manipulation)

## 4b. First-Depositor / Donation Share-Inflation (Aave/Compound-fork eToken vaults)
**Where:** any share-minting vault whose exchange rate reads a *donatable* balance and has
NO virtual shares + NO zero-share mint guard. ExtraFi LendingPool is a live PoC-confirmed example:
```solidity
// ReserveLogic
availableLiquidity = IERC20(underlying).balanceOf(eTokenAddress);   // donatable!
exchangeRate       = totalETokens * 1e18 / totalLiquidity;          // no virtual offset
// LendingPool._deposit
eTokenAmount = amount * exchangeRate / 1e18;                        // no require(!=0), no minShares
```
**Attack:** attacker deposits 1 wei (1 share) → transfers a large `donation` of underlying
straight to the eToken address → `totalLiquidity` jumps, supply stays 1 → victim's deposit
`V * 1 / (1+donation)` floors to **0 shares** → attacker holds 100% of supply and redeems the
whole pool incl. the victim's funds. PoC on real ExtraFi source (forge test, Kali box) confirmed:
victim deposited 100k, received 0 eTokens, attacker net profit == 100k.

**SEVERITY IS PRECONDITIONED — do not auto-label Critical.** Only works on a **fresh / unseeded
reserve**; a live reserve with real supply makes it uneconomic. Exploit window = "new asset
listing that isn't seeded." Before claiming Critical, establish the precondition is reachable:
  - Is reserve creation permissionless or `onlyOwner`? (ExtraFi `initReserve` = onlyOwner, no seed)
  - Does the team actually seed reserves on listing? If they always seed, it's theoretical.
  - L2 (Optimism) has no public mempool → front-running harder, but attacker can donate-and-wait
    (redeem back if no victim shows → near-zero attacker risk).
Report as **High** with the precondition stated honestly; escalate to Critical ONLY with on-chain
proof an unseeded reserve exists / listings ship unseeded. Killed by: virtual shares (OZ ERC4626
offset), `require(shares != 0)`, a min-liquidity dead-address seed in `initReserve`, or `minSharesOut`.
**Textbook bug — if two audit firms both missed it (grep audit txt `first deposit|inflat|virtual
share|donation` — empty in both PeckShield + BlockSec ExtraFi reports), it's a genuine gap.**

## 5. Reentrancy

### CEI Pattern (Checks-Effects-Interactions)
```solidity
// SAFE
function withdraw(uint amount) external {
    require(balances[msg.sender] >= amount);  // CHECK
    balances[msg.sender] -= amount;           // EFFECT
    token.transfer(msg.sender, amount);       // INTERACTION
}

// VULNERABLE
function withdraw(uint amount) external {
    token.transfer(msg.sender, amount);       // INTERACTION first!
    balances[msg.sender] -= amount;           // EFFECT after
}
```

### ReentrancyGuard Usage
- Check for `nonReentrant` modifier on all entry points
- Verify `nonReentrant` is on ALL entry points, not just some

## 6. Flash Loan Vectors

### Single-Block Price Manipulation
- Check if price is fetched from spot market (manipulable)
- Verify TWAP is used (resistant to single-block manipulation)
- Check if flash loan protection exists (some protocols block flash loans)

### Economic Attacks
- Interest rate manipulation via large deposits/withdrawals
- Liquidation threshold manipulation
- Share dilution attacks

## 7. Cross-Chain Bridge Issues

### Implementation Swap During Bridge
**Found in:** Flaunch (Flaunch.sol:225-228, 400)
**Severity:** CRITICAL
**Pattern:** No per-token implementation version lock
```solidity
// During bridge, implementation can be swapped
function setMemecoinImplementation(address _newImpl) external onlyOwner {
    memecoinImplementation = _newImpl;  // Global change
}

// finalizeBridge uses CURRENT implementation, not locked version
address memecoin_ = LibClone.cloneDeterministic(memecoinImplementation, bytes32(tokenId));
```

### Bridge Window Attacks
- Check if implementation can be changed during bridge window
- Verify per-token version lock exists
- Check for timelock on admin functions

## 8. Compound Fork False Positives

### Market-Exit Borrow-Check Bypass
**Status:** CONFIRMED FALSE POSITIVE in multiple Compound V2/V3 forks, including Orbit Protocol (2026-07-20 analysis).
**Pattern:**
- `redeemAllowedInternal()` returns NO_ERROR for accounts without `accountMembership`
- `transferAllowed()` delegates to `redeemAllowedInternal()`
- Attack claim: "exit market → redeem/transfer bypasses borrow check"
**Why it's NOT a bug:**
- `exitMarket()` requires zero borrow balance (`amountOwed == 0`) before removing membership
- Borrower MUST repay debt before exiting; cannot bypass borrow check through market exit
- Non-member redeem/transfer bypass is by design for accounts with no market activity
**Lesson:** Always trace full `exitMarket()` preconditions before claiming a borrow-check bypass in Compound forks. This pattern appears in Sonne, Exactly, Hundred, CREAM, and Orbit — all false positives when analyzed completely.

### Reward-Index Accounting Edge Cases
**Pattern:** `mintAllowed`/`borrowAllowed` update reward indices after liquidity checks
- Reward distribution before state change can create accounting mismatch
- Impact: typically LOW-MEDIUM (rewards miscount, not direct fund loss)
- Needs concrete PoC to prove exploitable profit

### Exit-Market Token Balance Check
**Pattern:** `exitMarket()` checks `tokensHeld` via `getAccountSnapshot()` and requires zero `amountOwed`
- Some forks skip the `tokensHeld` > 0 check, allowing exit with positive balance
- If found: MEDIUM severity (user can exit market with tokens still in wallet, breaking accounting)
- Verify with Foundry PoC: deposit → borrow → repay → exit → check `accountAssets` state