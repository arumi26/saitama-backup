# Harvest Finance — Solidity 0.5.16 Audit Case Study

## Protocol
- **Name:** Harvest Finance
- **TVL:** ~$13.3M (Ethereum, Base, Arbitrum)
- **Category:** Yield Aggregator
- **Audits:** 1 (old, pre-2021)
- **GitHub:** harvest-finance/harvest (public)
- **Solidity:** 0.5.16 (pre-SafeMath-default era)

## Architecture
- **Vault.sol** — ERC20 shares, deposits/withdrawals, strategy management
- **Controller.sol** — governance-gated operations, hardWorker system
- **FeeRewardForwarder.sol** — Uniswap V2 swaps for fee conversion
- **RewardPool.sol** — Synthetix-style staking rewards
- **Strategies/** — per-protocol yield strategies (Compound, Curve, Idle, Sushi)

## Key Findings (static analysis, no PoC)

### 1. Reentrancy Window in Vault.withdraw() (MEDIUM)
- Line 294: `_burn(msg.sender, numberOfShares)` — state change
- Line 305: `IStrategy(strategy()).withdrawAllToVault()` — external call
- Line 313: `IStrategyV2(strategy()).withdrawToVault(missingShares, ...)` — external call
- Line 328: `IERC20(underlying()).safeTransfer(msg.sender, ...)` — transfer to user

**Analysis:** Burn happens BEFORE external calls (CEI pattern). However, `withdrawToVault` at line 313 is an external call to an untrusted strategy contract. If a malicious strategy is set, it could re-enter `withdraw()` during the `withdrawToVault` call. The shares are already burned, so re-entry would fail on `totalSupply() > 0` check at line 291 if it's the last position. But partial withdrawals could be exploited.

**Mitigation:** Strategy is set via `onlyControllerOrGovernance` (line 202). Governance timelock of 12 hours. Not exploitable without governance key compromise.

### 2. Integer Arithmetic (LOW — Solidity 0.5.16)
- Uses SafeMath throughout (via OpenZeppelin `using SafeMath for uint256`)
- No raw arithmetic found outside SafeMath
- **Conclusion:** NOT vulnerable to overflow despite pre-0.8 Solidity

### 3. Controller.notifyFee() — Open Access (INFORMATIONAL)
- Line 197-203: `notifyFee` is `external` with NO access control
- Anyone can call it, but it requires `safeTransferFrom(msg.sender, ...)` — caller must have approved tokens
- Risk: If a token has a malicious `transferFrom` that returns true without actual transfer, fees could be spoofed
- **Conclusion:** Low risk, requires exotic token

### 4. FeeRewardForwarder — Hardcoded Uniswap Router (INFORMATIONAL)
- Line 54: `address constant public uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)`
- If Uniswap V2 router is compromised, all fee conversions are at risk
- Routes are set by governance, no timelock visible
- **Conclusion:** Standard pattern, not a bug

### 5. Vault Defense Modifier — tx.origin Check (LOW)
- Line 34-42: `defense()` modifier checks `msg.sender == tx.origin` OR not grey-listed
- `tx.origin` check bypasses grey-listing for EOAs — this is intentional (EOAs are safe)
- But: contract-to-contract calls via CREATE2 with fresh addresses bypass grey-list
- **Conclusion:** Known limitation, not exploitable for profit

## Lessons for Bug Hunters
1. **Solidity 0.5.16 doesn't mean automatic overflow bugs** — check if SafeMath is used
2. **Governance timelocks kill most exploit paths** — always check strategy change mechanisms
3. **CEI compliance in old code is surprisingly solid** — Harvest follows it well
4. **1 audit + 4 years live = high duplicate risk** — novel bugs are rare here
5. **Best targets are NEWER protocols with 0 audits**, not battle-tested old code

## References
- GitHub: https://github.com/harvest-finance/harvest
- Audit: https://github.com/harvest-finance/harvest/tree/master/audits
- Vault: contracts/Vault.sol (378 lines)
- Controller: contracts/Controller.sol (205 lines)
