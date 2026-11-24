# Arcadia Finance v2 — Multi-Repo Margin Lending Audit (Aug 2026)

**Target:** Arcadia Finance v2 (margin lending with multi-asset collateral accounts)
**Repos:** accounts-v2 (87 files, 15K LOC), lending-v2 (18 files, 4.5K LOC), asset-managers (50 files, 6.8K LOC)
**Result:** 0 exploitable findings. 1 Low/Info (CowSwapper approveToken access control — failed 7-Question Gate).
**Time:** ~3 hours deep audit across all 3 repos.

## Architecture
- **Accounts-v2:** AccountV1-V4 (proxy, upgradeable), Registry (L1/L2), Asset Modules (Aerodrome, UniswapV3/V4, Slipstream, Stargate), Oracle Modules (Chainlink, RedStone), Factory (CREATE2)
- **Lending-v2:** LendingPool (ERC4626 debt tokens, tranche-based), Liquidator L1/L2 (Dutch auction), Tranche (senior/junior)
- **Asset-managers:** Rebalancer (CL position rebalancing via flashAction), Compounder (fee compounding), CowSwapper (CoW Protocol swap via flash loans), MerklOperator, RouterTrampoline (arbitrary router call wrapper)

## Key Techniques

### 1. `slither.config.json` filter_paths — What the team EXCLUDED from their own scanning
```json
{ "filter_paths": "src/actions|AccountV2.sol|AccountV1.sol|SpotToMarginMigrator|Creditor" }
```
This tells you which contracts the team considers "done" vs "needs watching." The excluded paths are the ones they're confident in — the included paths are where they expect issues. Cross-reference your audit priority against this list.

### 2. Recent git commit analysis for overflow fix patterns
```bash
git log --oneline -5  # Look for "fix", "overflow", "cap", "saturat"
```
Arcadia had a recent commit: "Cap reward and fee per-liquidity deltas to uint128" — this tells you:
- The team is actively fixing overflow issues in staking/derived AM modules
- The fix pattern (cap at type(uint128).max before downcast) shows their approach
- Check if the fix is COMPLETE — are there other unbounded accumulators that weren't capped?

### 3. Submodule initialization for multi-repo audits
```bash
git clone --depth 1 <repo>
cd <repo>
git submodule update --init --recursive --depth 1
```
Multi-repo protocols (like Arcadia) have cross-dependencies via submodules. Without init, `lib/` directories are empty and you can't compile or read dependency source (e.g., solmate FixedPointMathLib for `mulDivUp` behavior verification).

### 4. `mulDivUp` division-by-zero check
When auditing solmate's `FixedPointMathLib.mulDivUp(x, y, denominator)`:
```solidity
assembly {
    if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
        revert(0, 0)  // reverts if denominator == 0
    }
}
```
- `mulDivUp(0, x, 0)` → reverts (denominator is 0)
- `mulDivUp(0, x, nonzero)` → returns 0 (safe)
- `mulDivUp(nonzero, x, 0)` → reverts
Always trace whether `denominator` can ever be 0 at call site. For LiquidatorL2._calculateTotalShare: `assetAmounts[i]` comes from stored auction data (set at initiation when balances > 0), so it's always nonzero. Safe.

### 5. SPA false-positive detection (already documented as pitfall #45, confirmed this session)
ExtraFi app.extrafi.io returns 200 for ALL paths with identical byte count (2840 bytes). Quick detection:
```bash
for p in / /.env /admin /actuator /graphql; do
  size=$(curl -s -m 8 "https://$TARGET$p" | wc -c)
  echo "$p → $size bytes"
done
```
If all identical → SPA fallback, move on.

### 6. Concentrated liquidity (CL) math audit checklist
For protocols with Uniswap V3/V4/Slipstream CL positions:
- **`_getTargetRatio` unchecked math:** Verify `sqrtPrice > sqrtRatioLower` and `sqrtPrice < sqrtRatioUpper` are guaranteed by caller. Arcadia's CLMath._getTargetRatio uses unchecked subtraction `sqrtPrice - sqrtRatioLower` — safe because function only called when in-range.
- **`sqrtPrice ** 2` overflow:** Check for `require(sqrtPrice <= type(uint128).max)` before squaring. Without it, uint256 overflow possible for extreme sqrtPrice values.
- **Iterative solver convergence:** RebalanceOptimizationMath uses MAX_ITERATIONS=100 and CONVERGENCE_THRESHOLD=1e6. Check: what happens if it doesn't converge? Fallback should be safe (return last amountOut, enforce minLiquidity).
- **`_swapViaRouter` arbitrary external call:** RouterTrampoline.execute calls `router.call(callData)`. Check: (a) who can call rebalance (initiator check), (b) post-swap balance accounting reverts on underflow, (c) Account health check at end of flashAction.

### 7. Well-engineered codebase signals (pivot indicators)
If you see ALL of these, the protocol is likely clean — pivot after 2 hours max:
- Extensive natspec on every function
- `forge-lint` directives throughout (the team uses a linter)
- Fuzz tests with high run counts (`fuzz = { runs = 50, max_test_rejects = 100_000_000 }`)
- `unchecked` blocks with inline justifications ("gas: Only overflows when...")
- Multiple access control modifiers per function
- Formal math derivations in natspec (equations, variable substitutions)
- Recent commits actively fixing overflow issues
- Slither config present and maintained

### 8. Dutch auction liquidation — key checks
- **Price curve bounds:** halfLifeTime (2min-8hr), cutoffTime (1hr-18hr), startPriceMultiplier (1x-3x), minPriceMultiplier (0-0.9x)
- **`_calculateTotalShare` division:** `mulDivUp(bidAmounts[i], assetShares[i], assetAmounts[i])` — verify assetAmounts[i] is never 0 (stored at initiation, 0-balance assets removed from arrays)
- **Sequencer downtime handling:** Check if auction restarts when sequencer goes down mid-auction (`sequencerStartedAt > startTime` → reset startTime)
- **`_getAssetShares` with totalValue==0:** Returns empty shares array → all bids get price=0 → free assets? No, because `_calculateBidPrice` multiplies by startDebt, so price=0 means no debt repaid.

### 9. No bounty program = no payout path
Arcadia had no Immunefi/H1/Bugcrowd/Sherlock program. Even with findings, there's no formal channel. Check:
- Immunefi: `curl -s -m 10 "https://immunefi.com/bounty/<name>/" -o /dev/null -w "%{http_code}"`
- GitHub: search repo root for `SECURITY.md`, audit reports in `artefacts/` directory
- Contact: `security@<protocol>.finance` or Discord
- If no program: report via responsible disclosure and hope for informal bounty, or pivot to targets WITH programs.

## Findings (Failed 7-Question Gate)

### F1: CowSwapper — Missing Access Control on approveToken() + No skim() (Low/Info)
- `approveToken()` is public — anyone can approve VAULT_RELAYER for type(uint256).max
- `isValidSignature()` returns MAGIC_VALUE for ANY order when account==address(0) (not in flash loan)
- No `skim()` function on CowSwapper (unlike Rebalancer, Compounder, YieldClaimer, MerklOperator)
- **Impact:** Stuck tokens could be drained by malicious CoW solver
- **Failed Q2:** Requires unusual user action (sending tokens directly to contract) + CoW solver role
- **Fix:** Add `onlyOwner` to `approveToken()`, add `skim()` function

## Clean Code Observations
- ChainlinkOM: proper staleness (updatedAt > block.timestamp - cutOffTime, updatedAt <= block.timestamp, roundId > 0, answer >= 0)
- LendingPool borrow/repay: credit allowance checked, origination fee accounted, health check via increaseOpenPosition()
- AccountV1/V3 flashAction: reentrancy guard, notDuringAuction, health check at end
- Factory CREATE2: uses tx.origin in salt (intentional, not auth) to prevent front-running
- _processDefault: iterates tranches junior→senior, burns liquidity, locks wiped tranches
