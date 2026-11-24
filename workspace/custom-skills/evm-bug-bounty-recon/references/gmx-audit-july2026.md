# GMX V1/V2 Audit Findings — July 2026

## Target
- GMX V1 Vault: `0x489ee077994B6658eAfA855C308275EAd8097C4A` (Arbitrum)
- GMX V2: `gmx-io/gmx-synthetics` (GitHub)
- Immunefi bounty: up to $5M (10% of funds at risk, min $50K)

## V1 Findings (OUT OF SCOPE for V2 bounty)

### Pool Insolvency via Leverage Overflow
- `_increaseReservedAmount` has NO check: reservedAmounts <= poolAmounts
- With 100x leverage, attacker can push reservedAmounts > poolAmounts
- On-chain: WBTC pool ~624 WBTC ($10.6M), 39% utilised, max leverage 100x
- Attack: open large position → utilisation >100% → cascade liquidation
- **Explicitly excluded:** "Cases involving risks of losses to the GLP pool"

### Funding Rate Manipulation
- `fundingRate = fundingRateFactor * reserved * intervals / pool`
- At >100% utilisation: rate >100% per interval → drains all positions
- Requires $65K+ capital for flash loan → excluded as "economically impractical"

### 3-Round Chainlink Sampling
- `getPrimaryPrice` samples 3 rounds, returns max for longs
- During price spike, longs open at inflated price
- Excluded: "Exploits due to delays or sizes of price feed updates"

## V2 Findings (IN SCOPE)
- No critical novel bug found
- Code quality: Solidity ^0.8.0, ReentrancyGuard, access control, feature flags
- Oracle: Chainlink primary, with staleness + sequencer checks
- SubaccountRouter: validates receiver, count, expiry, integrationId
- WithdrawalHandler: try/catch with auto-cancel, gas validation

## V2 Contracts in Scope (Avalanche)
WithdrawalVault, WithdrawalUtils, WithdrawalStoreUtils, WithdrawalHandler,
WithdrawalEventUtils, TimestampInitializer, Timelock, SwapUtils,
SwapPricingUtils, SwapOrderUtils, SwapHandler, SubaccountRouter

## Key Takeaway
GMX is heavily audited + $5M bounty = saturated target. Better ROI from smaller protocols ($1-20M TVL, 1 audit, no Immunefi program yet).
