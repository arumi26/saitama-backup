# SYNO Finance Audit — 2026-07-20

## Protocol Overview
- **Name:** SYNO Finance (Synonym Finance)
- **GitHub:** https://github.com/SynonymFinance/smart-contracts-public
- **Repo:** `SynonymFinance/smart-contracts-public` (submodule-based: wormhole-solidity-sdk, upgradeable-wormhole-solidity-sdk, solmate)
- **Architecture:** Hub-Spoke model on Avalanche (Hub) + OP Goerli/Goerli/Mumbai (Spokes)
- **Cross-chain:** Wormhole Tunnel + CCTP
- **Lending:** Compound V2 fork + custom price oracle + liquidation
- **Status:** Repository mostly stale (last commit May 2025), GitHub org has no active members, no open issues/PRs

## Bugs Found

### Bug 1: WormholeTunnel RefundRecipient Manipulation (HIGH)
- **File:** `evm/src/contracts/wormhole/WormholeTunnel.sol`
- **Lines:** 303-389 (`receiveWormholeMessages`)
- **Shape:** When a cross-chain message execution fails, the tunnel constructs a refund message using `message.source.refundRecipient` from the attacker-controlled original payload without validation.
- **Impact:** Attacker can redirect ETH/Token refunds from the tunnel contract to arbitrary address.
- **PoC:** `/tmp/syno-poc/test/RefundRecipientPoC.sol` (passes: `test_refund_recipient_can_be_arbitrary`)

### Bug 2: Optimistic Finality Phantom Liability (MEDIUM-HIGH)
- **File:** `evm/src/libraries/logic/optimisticFinality/HubOptimisticFinalityLogic.sol`
- **Lines:** 179-252 (`handleFinalizeCreditMessage`)
- **Shape:** When `handleFinalizeCreditMessage` processes a finalize credit for a credit that was never created (`createdAt == 0`), it sets status to `REFUNDABLE` instead of reverting. Creates a phantom liability.
- **Impact:** Potential fund loss if admin manually resolves the "refundable" credit. State corruption in cross-chain balance tracking.
- **PoC:** `/tmp/syno-poc/test/FinalizeCreditBugPoC.sol` (passes: `test_finalize_nonexistent_credit_creates_refundable_liability`)

## Why SYNO Was Decommissioned
- **No active bounty program:** No Immunefi/Hats/Cantina/Sherlock program found
- **Stale repository:** Last commit May 2025, no open issues or PRs
- **Inactive org:** GitHub org `SynonymFinance` has no public active members
- **Conclusion:** Audit effort not worth it without a bounty program to submit to

## Key Contracts Reviewed
| Contract | Path | Status |
|----------|------|--------|
| WormholeTunnel | `evm/src/contracts/wormhole/WormholeTunnel.sol` | Full read |
| Hub | `evm/src/contracts/lendingHub/Hub.sol` | Lines 1-400 |
| Spoke | `evm/src/contracts/lendingSpoke/Spoke.sol` | Lines 1-400 |
| Liquidator | `evm/src/contracts/Liquidator.sol` | Full read |
| LiquidatorFlashLoan | `evm/src/contracts/LiquidatorFlashLoan.sol` | Full read |
| AssetRegistry | `evm/src/contracts/lendingHub/AssetRegistry.sol` | Full read |
| SynonymPriceOracle | `evm/src/contracts/priceOracle/SynonymPriceOracle.sol` | Full read |
| HubPriceUtilities | `evm/src/contracts/lendingHub/HubPriceUtilities.sol` | Full read |
| HubAccountingLogic | `evm/src/libraries/logic/accounting/HubAccountingLogic.sol` | Full read |
| SpokeAccountingLogic | `evm/src/libraries/logic/accounting/SpokeAccountingLogic.sol` | Full read |
| ValidationLogic | `evm/src/libraries/logic/ValidationLogic.sol` | Full read |
| HubOptimisticFinalityLogic | `evm/src/libraries/logic/optimisticFinality/HubOptimisticFinalityLogic.sol` | Full read |
| SpokeOptimisticFinalityLogic | `evm/src/libraries/logic/optimisticFinality/SpokeOptimisticFinalityLogic.sol` | Lines 1-400, 501-583 |
| HubInterestUtilities | `evm/src/contracts/lendingHub/HubInterestUtilities.sol` | Full read |
| LiquidationCalculator | `evm/src/contracts/liquidationCalculator/LiquidationCalculator.sol` | Full read |
| HubSpokeStructs | `evm/src/contracts/HubSpokeStructs.sol` | Full read |

## Attack Patterns Checked
- ✅ Reentrancy (CEI violation, cross-contract)
- ✅ Access control (missing modifiers, role-based)
- ✅ Cross-chain message validation (Wormhole replay, refundRecipient)
- ✅ Optimistic finality (credit lifecycle, phantom liability)
- ✅ Oracle manipulation (price interval, stale feeds)
- ✅ Liquidation accounting (portion limits, fee calculation)
- ✅ Token behavior (fee-on-transfer, rebase)
- ✅ Proxy/upgrade patterns
- ✅ Signature issues (nonce, EIP-712)
