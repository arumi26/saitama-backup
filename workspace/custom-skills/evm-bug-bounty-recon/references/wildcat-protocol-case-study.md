# Wildcat Protocol Case Study — Unc Collateralized Lending ($359M, NO AUDIT)

## Target
- **Protocol:** Wildcat Protocol
- **TVL:** $359M (DeFiLlama, July 2026)
- **Category:** Uncollateralized Lending
- **Chain:** Ethereum
- **Audits:** 0
- **GitHub:** `wildcat-finance/wildcat-protocol` (public, Solidity)
- **Immunefi:** Listed but bounty amount varies

## Architecture
- **WildcatMarket** — main lending market (deposit, borrow, repay, close)
- **WildcatMarketWithdrawals** — withdrawal queue with batch processing
- **WildcatMarketBase** — shared state, `totalAssets()` = `asset.balanceOf(address(this))`
- **FeeMath** — linear interest calculation, delinquency fees, protocol fees
- **MathUtils** — assembly-optimized math (bipMul, rayMul, satSub, mulDiv)
- **MarketState** — packed struct (isClosed, maxTotalSupply, scaledTotalSupply, scaleFactor, etc.)

## Key Functions
- `deposit(amount)` / `depositUpTo(amount)` — lenders deposit, mint market tokens
- `borrow(amount)` — borrower withdraws up to `borrowableAssets(totalAssets())`
- `repay(amount)` — anyone can repay (tokens counted as borrower repayment)
- `closeMarket()` — controller closes, settles all debts
- `collectFees()` — protocol fee withdrawal
- `queueWithdrawal(amount)` — lenders queue withdrawal (batched, time-locked)
- `executeWithdrawal(account, expiry)` — execute expired withdrawal batch

## Findings (Static Analysis)

### Finding 1: `withdrawableProtocolFees` potential underflow (MEDIUM)
**Location:** `MarketState.sol:109`
```solidity
uint256 totalAvailableAssets = totalAssets - state.normalizedUnclaimedWithdrawals;
```
Checked subtraction. If `totalAssets < normalizedUnclaimedWithdrawals`, reverts → `collectFees()` permanently blocked.

**Why it's mitigated:** `borrowableAssets()` uses `satSub` (saturating subtraction), and `_applyWithdrawalBatchPayment` only adds to `normalizedUnclaimedWithdrawals` from `availableLiquidity` (which already subtracts `normalizedUnclaimedWithdrawals`). So the invariant `normalizedUnclaimedWithdrawals <= totalAssets - accruedProtocolFees` should hold.

**Edge case:** Rounding in `normalizeAmount`/`scaleAmount` (rayMul/rayDiv) could create 1-wei discrepancies over many operations. Accumulated over thousands of withdrawals, could theoretically break the invariant. Not practically exploitable for profit but could DOS `collectFees`.

### Finding 2: `repay()` accepts tokens from anyone (DESIGN, not bug)
Anyone can call `repay(amount)` — tokens are counted as borrower repayment. This is by design (allows third-party repayment). But a malicious actor could grief the borrower by repaying tiny amounts to trigger state updates and gas costs. Not exploitable for profit.

### Finding 3: Interest accrual in `unchecked` block (LOW)
`FeeMath.calculateLinearInterestFromBips` uses `unchecked { return accumulatedInterestRay / SECONDS_IN_365_DAYS; }`. The division is safe (dividing by constant). The multiplication `rate * timeDelta` is checked (reverts on overflow). No exploit path.

## Key Takeaway
Wildcat Protocol has surprisingly clean code for a NO AUDIT protocol. Assembly-optimized math, proper overflow checks, saturating subtraction for critical paths. The `withdrawableProtocolFees` underflow is the most promising finding but needs a concrete rounding scenario to be reportable. Best approach: Foundry PoC with many small withdrawals to accumulate rounding误差.
