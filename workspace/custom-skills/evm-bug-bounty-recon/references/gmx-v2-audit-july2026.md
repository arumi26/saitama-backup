# GMX V2 Audit — July 2026

## Target
- Protocol: GMX V2 (gmx-synthetics)
- Chains: Arbitrum, Avalanche (Immunefi scope = Avalanche contracts)
- TVL: ~$179M (DeFiLlama), actual V1 Vault: ~$537K
- Bounty: $5M max (Critical), $25K (High), $10K (Medium)
- Repo: https://github.com/gmx-io/gmx-synthetics

## Contracts Analyzed (2+ hours deep audit)

### SubaccountRouter.sol
- `_handleSubaccountAction` → validates subaccount, increments count, checks expiry
- `validateCreateOrderParams` → checks receiver == account, cancellationReceiver == account
- `_autoTopUpSubaccount` → caps top-up to gas consumed, uses pluginTransfer
- **Verdict:** Secure. Nonce-based replay protection, EIP-712 signatures, maxAllowedCount limits.

### SubaccountUtils.sol
- `handleSubaccountAction` → validateSubaccount + increment + validate count/expiry
- `_validateSubaccountActionCountAndExpiresAt` → checks `block.timestamp > expiresAt` and `count > maxCount`
- **Verdict:** Secure. Proper access control via DataStore key patterns.

### SwapUtils.sol
- `_swap` → fetches oracle prices, calculates price impact, applies fees
- Uses `tokenInPrice.min` / `tokenOutPrice.max` for conservative pricing
- `swapPathMarketFlagKey` prevents duplicate market in path
- Validates pool amount and reserve after swap
- **Verdict:** Secure. Conservative pricing, post-swap validation, no reentrancy path.

### ExecuteWithdrawalUtils.sol
- `executeWithdrawal` → removes withdrawal from store, validates oracle timestamps, calculates output amounts
- Burns market tokens, applies pool deltas, validates reserves and max PnL
- `_swap` called for long/short token swap paths
- **Verdict:** Secure. Proper ordering (burn → validate → transfer), no reentrancy window.

### WithdrawalHandler.sol
- `executeWithdrawal` → `try/catch` pattern: if execution fails, cancels and refunds
- `executeAtomicWithdrawal` → no swap paths allowed, creates and executes in one tx
- **Verdict:** Secure. Graceful failure handling, proper access control.

### RelayUtils.sol
- EIP-712 typed data signing for all relay operations
- `validateSignature` → ECDSA recovery + minified struct hash fallback
- `GMX_SIMULATION_ORIGIN` bypass → only works in `eth_call`/`eth_estimateGas` (tx.origin set by RPC)
- **Verdict:** Secure. Simulation bypass is standard pattern, not exploitable in real tx.

### MultichainUtils.sol
- `recordBridgeIn` → records transfer from bridge provider
- `transferOut` → checks balance, decrements, transfers from vault
- **Verdict:** Secure. Balance check before transfer, proper decrement.

### GlvDepositCalc.sol
- `validateFirstGlvDeposit` → checks receiver == RECEIVER_FOR_FIRST_GLV_DEPOSIT for first deposit
- `getMintAmount` → calculates GLV tokens based on market pool value
- **Verdict:** Secure. Standard proportional mint calculation.

### OrderHandler.sol
- `executeOrder` → `try/catch` pattern with `_handleOrderError`
- Error handling: frozen orders → revert, market orders → cancel+refund, limit orders → freeze
- Frozen order mechanism prevents gaming (user can't deposit into pool to enable their limit order)
- **Verdict:** Secure. Proper error categorization, freeze vs cancel logic.

### ExecuteOrderUtils.sol
- `executeOrder` → removes order from store BEFORE execution
- If execution fails, `_handleOrderError` handles refund/freeze
- Validates market token balance after execution
- **Verdict:** Secure. Pre-removal is safe because error handler covers all cases.

### GovTimelockController.sol
- OpenZeppelin TimelockController with custom name
- Standard proposer/executor/admin role pattern
- **Verdict:** Standard OZ code, well-audited.

## Key Security Features of GMX V2
1. **Solidity ^0.8.0** — built-in overflow protection
2. **ReentrancyGuard** on all entry points
3. **Role-based access control** (RoleStore, onlyController, onlyOrderKeeper, onlySelf)
4. **Feature flags** — every function can be disabled via DataStore keys
5. **EIP-712 signatures** for relay/subaccount operations
6. **Oracle validation** — sequencer check, timestamp validation, price bounds
7. **Post-operation validation** — pool amounts, reserves, max PnL checked AFTER state changes
8. **Gas griefing protection** — execution fee validation, gas limit checks

## Why No Critical Bug Found
- 3+ years live, multiple audits (Zellic, others)
- $5M bounty attracts hundreds of researchers
- Code is exceptionally well-structured with defense-in-depth
- Every external call has pre/post validation
- No single-point-of-failure patterns

## Lesson
After 2+ hours of deep audit on a $5M saturated bounty with no novel findings, the ROI drops below pivoting to smaller targets. Signal: if you're finding "design decisions" instead of "bugs", move on.

## Time Spent
~2.5 hours total (V1 + V2 analysis, Foundry PoC, on-chain state inspection)

## Recommendation
Target smaller protocols ($1-20M TVL, 0-1 audit) for higher expected value per hour.
