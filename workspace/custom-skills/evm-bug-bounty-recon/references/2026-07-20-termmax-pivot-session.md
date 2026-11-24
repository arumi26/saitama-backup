# TermMax Audit Session — July 20, 2026

## Target
- **Protocol:** TermMax (Term Structure Labs)
- **Bounty:** $50K max Critical (10% of affected funds, min $10K)
- **Chain:** Ethereum mainnet
- **TVL:** Not disclosed in session (protocol active since June 2024)
- **GitHub:** https://github.com/term-structure/termmax-contract-v2
- **Immunefi:** https://immunefi.com/bug-bounty/termstructurelabs/
- **Audit:** TermMax audit report added Jan 2, 2026 (6 months ago)
- **Paid reports:** 17 reports resolved

## Why Pivoted

### Signal 1: Known Issue Assurance
The Immunefi bounty page explicitly states:
> "Term Structure Labs commits to providing Known Issue Assurance to bug submissions through their program. This means that Term Structure Labs will either disclose known issues publicly, or at the very least, privately via a self-reported bug submission."

This means any finding the team already knows about will be either:
- Publicly disclosed (duplicate)
- Privately disclosed to self-reporter (no bounty for duplicate)

### Signal 2: Recent Audit
Audit report added to `term-structure/audits` on Jan 2, 2026. The V2 smart contracts are the primary scope (added Sept 2025). A 6-month-old audit on the primary contracts means:
- Core architecture reviewed by external auditors
- Known issues already documented
- Novel critical bugs less likely

### Signal 3: High Report Count
17 paid reports already resolved on Immunefi. This represents hundreds of hours of researcher attention. The low-hanging fruit is already picked.

## Code Analyzed (but not deep-dived)

### Files Read
- `contracts/v2/oracle/adapters/ondo/TermMaxOndoPriceFeedAdapter.sol`
- `contracts/v2/oracle/adapters/ondo/TermMaxOndoPriceFeedAdapterFactory.sol`
- `contracts/v2/oracle/priceFeeds/TermMaxUniswapTWAPPriceFeed.sol` (partial)
- `contracts/v2/TermMaxOrderV2.sol` (lines 1-1418, complete read)
- `contracts/v2/TermMaxMarketV2.sol` (partial)
- `contracts/v2/router/swapAdapters/TerminalVaultAdapter.sol`
- `contracts/v2/router/swapAdapters/ERC4626VaultAdapterV2.sol`
- `contracts/v2/tokens/AbstractGearingTokenV2.sol` (lines 1-695, complete read)
- `contracts/v2/tokens/GearingTokenWithERC20V2.sol` (partial)

### Superficial Findings (not pursued)
1. **Ondo adapter factory** has no `maxUpdateInterval` guard — could allow stale price feeds if Ondo RWA tokens go offline
2. **TWAP price feed** not referenced in V2 contracts — unclear if active in production
3. **Swap callback `afterSwap()`** called before `safeTransferFrom` for tokenIn — potential reentrancy vector if callback is malicious
4. **Redeem/mint path** in `_rebalance()` has subtraction logic that could underflow if `releaseAmount > outputAmt`

**Assessment of these findings:** All appear to be design-level concerns or would require significant attack cost. Without a concrete exploit chain with transfer-flow trace, these are not submission-worthy.

## Key Lesson: Over-Audited Target Recognition

When a target has ALL of these signals, limit time investment to 30 minutes:
1. Known Issue Assurance on bounty page
2. Recent audit (<6 months) on primary scope
3. 15+ paid reports already resolved
4. Protocol age >1 year

Further analysis yields diminishing returns. Pivot to fresher targets.

## Next Target Selected
**40 Acres Finance** — Base/Optimism/Avalanche, $24M TVL, launched March 2026, $50K max Critical (Sherlock), 3 prior audits (Sherlock rounds), public GitHub.
