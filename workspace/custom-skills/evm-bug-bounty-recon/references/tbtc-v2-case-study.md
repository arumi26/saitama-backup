# tBTC-v2 Case Study — Permissionless Audit Results

**Date:** 2026-07-16  
**Target:** Threshold tBTC-v2 (threshold-network/tbtc-v2)  
**Chain:** Ethereum (mainnet), cross-chain to Arbitrum/Base/Optimism/Polygon/Starknet  
**TVL:** $500M+ (wrapped BTC)  
**Audits:** Multiple (Trail of Bits, Consensys Diligence, etc.)  

## Architecture

tBTC-v2 is a decentralized Bitcoin bridge using ECDSA wallets (Keep Network). Key components:

- **Bridge.sol** (108KB, 2083 lines) — Core: deposit, sweep, redemption, moving funds, fraud
- **TBTCOptimisticMinting.sol** — Mint TBTC before BTC deposit is swept (3-hour delay)
- **Redemption.sol** — SPV proof-based BTC redemption
- **MovingFunds.sol** — Wallet-to-wallet BTC transfers
- **Fraud.sol** — Permissionless fraud challenges with ETH deposit
- **TBTCVault.sol** — Vault for deposit routing

## Permissionless Functions Scanned (30+)

| Function | Access | Result |
|----------|--------|--------|
| `revealDeposit` | Anyone | Safe (requires real BTC tx) |
| `requestRedemption` | Anyone | Safe (requires Bank balance) |
| `submitFraudChallenge` | Anyone | Safe (requires ETH deposit) |
| `notifyMovingFundsTimeout` | Anyone | Safe (notification only) |
| `notifyMovingFundsBelowDust` | Anyone | Safe (notification only) |
| `notifyFraudChallengeDefeatTimeout` | Anyone | Safe (notification only) |
| `submitRedemptionProof` | Anyone | Safe (SPV proof validation) |
| `submitDepositSweepProof` | SpvMaintainer | Permissioned |
| `submitMovingFundsCommitment` | Wallet member | Permissioned |
| `requestOptimisticMint` | Minter only | Permissioned |
| `finalizeOptimisticMint` | Minter only | Permissioned |
| `cancelOptimisticMint` | Guardian only | Permissioned |

## Why tBTC-v2 is Secure

1. **SPV proofs** — All Bitcoin transaction validation uses Simplified Payment Verification (immutable)
2. **Governance delay** — 24-hour delay for parameter changes
3. **Multi-sig wallets** — ECDSA threshold signatures for BTC custody
4. **Fraud challenges** — Permissionless but requires ETH deposit (spam prevention)
5. **Optimistic minting** — Guardian cancellation window (3 hours)
6. **Redemption watchtower** — External safety check on redemptions
7. **Battle-tested** — tBTC v1 launched 2020, v2 is mature

## Key Lesson

**Well-audited, battle-tested protocols with SPV proofs are NOT good bug bounty targets.** The security model is fundamentally different from DeFi protocols using oracles or spot prices.

**tBTC-v2 vs Flaunch:**
- Flaunch: Uniswap V4 spot price (manipulable), custom hooks, no SPV
- tBTC-v2: Bitcoin SPV proofs (immutable), governance delays, fraud challenges

**Pivot signal:** If a protocol uses Bitcoin SPV proofs or has been audited 3+ times by top firms → move to newer/smaller targets.

## Attack Surface Comparison

| Protocol | Oracle | Access Control | Audit Count | Novel Bug Chance |
|----------|--------|---------------|-------------|-----------------|
| tBTC-v2 | SPV proofs | Multi-sig + governance | 5+ | Very low |
| Flaunch | Uniswap V4 spot | Owner + NFT creator | 0 | High |
| Gravita | Chainlink | Owner + timelock | 1 | Medium |
| Ostium | Custom (manipulable) | Permissionless | 0 | Was high |

## Recommendation

Don't audit tBTC-v2 for bug bounty. The architecture is sound and well-audited. Better targets:
- New protocols (<6 months, <100 GitHub stars)
- Protocols with 0 audits
- Protocols on newer L2s (Base, Scroll, Blast)
- Protocols using spot price oracles (not SPV proofs)
