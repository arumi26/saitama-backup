# 2026 Fresh Target Hunting — Immunefi Programs Launched in 2026

## Method: Find New Programs (Low Competition, High Novel-Bug Chance)

```bash
# Immunefi doesn't have a public "launched this month" feed.
# Workaround: scrape /bug-bounty/ list, filter by "Live Since" date in 2026.
# Or search Google: site:immunefi.com/bug-bounty "Live Since" "2026"
```

## Validated 2026 Programs (as of July 17, 2026)

| Protocol | Max Bounty | Live Since | Chain | Lang | KYC | Audits | Status |
|----------|-----------|------------|-------|------|-----|--------|--------|
| **GMTrade** | $100K | **Jul 6, 2026** | Solana | **Rust** | **NO** | 1 (Zenith, Mar 2026) | ⭐⭐⭐⭐⭐ |
| **Enzyme Onyx** | $200K | Sep 2025 | ETH/Arb/Base | Solidity | **NO** | 1 (ChainSecurity, Sep 2025) | ⭐⭐⭐⭐ |
| **Royco** | $250K | Feb 17, 2026 | ETH/Arb/Base/Avax | Solidity | Yes | 1 (Feb 2026) | ⭐⭐⭐ |
| **RootstockLabs** | $200K | Feb 10, 2026 | Rootstock (BTC L2) | Mixed | Yes | Feb 2026 | ⭐⭐ |
| 1inch Smart Contracts | $500K | Jun 11, 2026 | Ethereum | Solidity | Yes | **Many (mature)** | ⭐ |
| NUVA | $40K | May 17, 2026 | ? | ? | Yes | ? | ⭐ |
| KAST | $50K | Apr 19, 2026 | ? | ? | Yes | ? | ⭐ |
| Parallel | $250K | Oct 2, 2025 | Multi | Solidity | Yes | Multiple | ⭐⭐ |

## GMTrade Deep Dive — PRIORITY #1

**Why:** 11 days old, GMX V2 fork on Solana (Rust), only 1 audit, NO KYC, $100K max bounty.

**Repo:** `https://github.com/gmsol-labs/gmx-solana` (audit at `gmsol-labs/gmx-solana-audits`)

**Architecture (from Immunefi):**
- On-chain programs + off-chain keepers
- Price/risk oracles
- Market operations: deposits, perp positions, swaps
- LPs earn order fees + borrowing fees
- Traders earn via price impacts + funding fees (balance open interest)
- Price impact mitigates manipulation; adaptive funding balances OI

**Known Issues (from README):**
- Check `gmx-solana/README.md#known-issues`

**Attack Surface:**
1. Oracle: keeper-submitted prices → validation logic
2. Market pool: `reservedAmounts` vs `poolAmounts` bounds (GMX V1 pattern)
3. Funding rate formula at >100% utilization
4. Keeper incentives / gas griefing
5. Position opening/closing flow (2-step: user tx + keeper execution)
6. Price impact calculation — can it be gamed?

**PoC Environment:** Solana local validator + Anchor test framework (not Foundry).

---

## Enzyme Onyx Deep Dive — PRIORITY #2

**Why:** Tokenization vault (Shares + FeeHandler + ValuationHandler + ERC7540 queues), NO KYC, 1 audit, admin-controlled `_untrackedPositionsValue`.

**Repo:** `https://github.com/enzymefinance/protocol-onyx` (Foundry, Solidity 0.8.28)

**Core Contracts:**
| Contract | Role | Key Risk |
|----------|------|----------|
| `Shares.sol` | ERC4626 share token, authTransfer for handlers | `authTransfer` onlyDepositHandler/onlyRedeemHandler |
| `FeeHandler.sol` | Management/performance/entrance/exit fees | `settleDynamicFeesGivenPositionsValue` called by ValuationHandler |
| `ValuationHandler.sol` | Aggregates tracked (PositionTracker) + untracked (admin input) value | **`_untrackedPositionsValue` admin-controlled = price manipulation** |
| `SyncDepositHandler.sol` | Instant deposit, share price from ValuationHandler | Share price staleness check (`maxSharePriceStaleness`) |
| `ERC7540LikeDepositQueue.sol` | Async deposit queue, executeDepositRequests mints shares | Fee settlement on execute, share price at execution time |
| `ERC7540LikeRedeemQueue.sol` | Async redeem queue, executeRedeemRequests burns shares | Exit fee settlement, withdrawAssetTo from Shares |

**Critical Finding Pattern:**
```solidity
// ValuationHandler.sol:231-237
function __updateShareValue(int256 _untrackedPositionsValue) internal returns (uint256 netShareValue_) {
    // ...
    int256 trackedPositionsValue;
    for (uint256 i; i < positionTrackers.length; i++) {
        trackedPositionsValue += IPositionTracker(positionTrackers[i]).getPositionValue();
    }
    uint256 totalPositionsValue = (trackedPositionsValue + _untrackedPositionsValue).toUint256();
    // _untrackedPositionsValue is ADMIN INPUT — no validation, no TWAP, no oracle
    // If admin compromised or malicious → share price manipulation → deposit/redemption theft
}
```

**Audit:** ChainSecurity, Sep 2025. Check if `_untrackedPositionsValue` manipulation was covered.

---

## Robin Hood Chain (Outlaw/HOOD) — NEW TARGET CLASS

**Chain ID:** 4663 (T9 keypad: H-O-O-D)
**RPC:** `https://mainnet-hood.rpc.robinhood.com` (may need API key)

**Targets:**
| Protocol | TVL | Type | Fork | Audit |
|----------|-----|------|------|-------|
| **Arcus Perps** | $16.9M | Perp DEX | **dYdX** | **NO** |
| NOXA | $6.4M | Launchpad | Custom | NO |
| SwapHood | $0.6M | Native DEX | Custom | NO |

**Why Fork Chains = High Bug Density:**
- Fork devs modify code → introduce bugs in storage layout, fee logic, access control
- Base, Blast, Mode, Linea, Scroll, Robin Hood, XRPL EVM all exhibit this

**Recon Steps:**
1. Test RPC connectivity
2. Find deployed contract addresses (block explorer if exists)
3. Check if dYdX fork code is public or need to reverse from bytecode
4. Audit: oracle, leverage bounds, liquidation, funding rate, cross-margin

---

## Doppler Finance Lesson — Multi-Repo Protocol Validation

**DeFiLlama TVL: $94.6M (Ethereum + XRPL)** — but **TWO separate codebases on DIFFERENT chains:**

| Repo | Chain | TVL | Audits |
|------|-------|-----|--------|
| `girin-app/contracts` (Venus fork) | XRPL EVM Sidechain | $94.3M (off-chain custodial) | **0** |
| `Doppler-Finance/vault` (custom) | Ethereum Mainnet | $228K | **2 (Certik + Zenith)** |

**The $94.3M "XRPL" TVL is NOT on-chain smart contract TVL** — it's Fireblocks/Ceffu custodial balances reported via API.

**ALWAYS VALIDATE BEFORE DEEP AUDIT:**
1. Check protocol's GitHub org for MULTIPLE repos: `curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=20"`
2. Check protocol's audit page for WHICH repo was audited
3. Find DEPLOYED contract addresses on TARGET CHAIN (Etherscan/Basescan/Arbiscan verified, NOT DeFiLlama adapter)
4. Cross-reference: Does GitHub code match deployed bytecode? `cast code <addr> | diff <local_bytecode>`
5. DeFiLlama "chains" field = all chains protocol operates on, NOT which repo deploys where

---

## Fresh Target Discovery Workflow (2026 Version)

```bash
# 1. DeFiLlama scan → filter: TVL $200K-$15M, 0 audits, juicy category, public GitHub
# 2. Immunefi "Live Since" filter → 2026 programs only
# 3. Cross-reference: Is DeFiLlama target also on Immunefi? (higher confidence)
# 4. GitHub org check → public repos? recent commits? Solidity/Rust?
# 5. Chain check → EVM? Solana? Rust? (match your skillset)
# 6. Audit check → clone repo, find . -iname "*audit*" -o -iname "*security*"
# 7. Deployed addresses → verify on target chain explorer
# 8. Score & prioritize (see target scoring matrix in SKILL.md)

# Fresh 2026 signal: "Live Since" in 2026 + 0-1 audits + public repo = HIGH PRIORITY
```

---

## New Target Classes for 2026

### 1. Solana/Rust Perpetual DEX Forks (GMX V2 → Solana)
- GMTrade (gmsol-labs)
- New audit surface: Rust/Anchor, PDA-based accounts, CPI, keeper networks
- Need separate skill: `solana-bug-bounty-recon` (exists)

### 2. Tokenization Vaults (ERC4626 + ERC7540)
- Enzyme Onyx, other asset management protocols
- Admin-controlled valuation = centralization risk
- Async deposit/redeem queues = fee settlement timing attacks

### 3. Fork Chains (L2/L3 New EVM Chains)
- Robin Hood (Outlaw), XRPL EVM, MegaETH, Monad, Berachain
- dYdX, GMX, Uniswap forks deployed with modifications
- Limited tooling, less researcher attention

### 4. Bitcoin L2 / Rootstock
- RootstockLabs bounty ($200K, Feb 2026)
- EVM-compatible but Bitcoin-secured
- powpeg, HSM firmware, rskj node — different attack surface

### 5. Risk-Tranching / Structured Products
- Royco (senior/junior tranches, Feb 2026)
- Novel math: tranche pricing, first-loss capital, yield split
- Primacy of Impact = broader scope

---

## Quick Validation Checklist for Any New Target

- [ ] DeFiLlama TVL $200K-$15M (sweet spot)
- [ ] 0-1 audits on DeFiLlama
- [ ] Public GitHub repo with Solidity/Rust
- [ ] Recent commits (<3 months)
- [ ] Deployed on target chain (verified on explorer)
- [ ] Immunefi program exists (or direct disclosure)
- [ ] "Live Since" 2025-2026 (fresh)
- [ ] NO KYC or KYC acceptable
- [ ] Category: Lending, Perp, CDP, Vault, Bridge, Options, RWA
- [ ] Code matches deployed bytecode (`cast code <addr>`)
- [ ] Not a saturated bounty (GMX, Aave, Uniswap, 1inch)
- [ ] Not SPV-proof / ZK-proof / multi-sig timelock hardened
- [ ] Permissionless exploit path exists (not admin-only)