# ExtraFi Bug Bounty Recon — Full Case Study

## Target: Extra Finance (extrafi.io)
- **Chains:** Optimism & Base
- **Type:** Lending + Leveraged Yield Farming on Velodrome/Aerodrome
- **Two repos:**
  - `ExtraFi/extra-contracts` — custom lending + farming (4.5K LOC, audited BlockSec + PeckShield v1.0)
  - `ExtraFi/xlend-contracts` — Aave V3 fork + ERC-4337 account abstraction (15.6K LOC, 0 stars, updated Nov 2025, LIKELY UNAUDITED)
- **Bounty Program:** ❌ NONE — no Immunefi, H1, Bugcrowd, Sherlock, or Cantina. Security contact: contact@extrafi.io
- **Subdomains:** extrafi.io (301→app), app.extrafi.io (React SPA), api.extrafi.io (404), docs.extrafi.io (GitBook), preview.extrafi.io (Express), rpc.extrafi.io (521 dead)

## Part 1: Credit Inflation in LendingPool.repay() (extra-contracts)

### Discovery: GitHub Issues + BUG_FIXES_AND_MODIFICATIONS.md

```bash
curl -s "https://api.github.com/repos/ExtraFi/extra-contracts/issues?state=open" | jq '.[].title'
```

Found: `[SECURITY DISCLOSURE] Critical Credit Inflation Bug Found` (Issue #5, OPEN)

Also check `BUG_FIXES_AND_MODIFICATIONS.md` in repo root — documents 5+ known bugs with mainnet mitigations.

### Bug: Credit inflated by input amount instead of actual repaid debt (CEI Violation)

**Root cause:** Checks-Effects-Interactions violation. Credit is updated BEFORE the amount is capped to the actual debt position.

```solidity
// VULNERABLE (mainnet code):
uint256 credit = credits[debtPosition.reserveId][_msgSender()];
credits[debtPosition.reserveId][_msgSender()] = credit.add(amount);  // EFFECTS: Credit FIRST, uncapped

if (amount > debtPosition.borrowed) {
    amount = debtPosition.borrowed;  // CHECKS: Cap AFTER credit update
}

reserve.totalBorrows = reserve.totalBorrows.sub(amount);
debtPosition.borrowed = debtPosition.borrowed.sub(amount);

// INTERACTIONS: transfer from vault
IERC20(reserve.underlyingTokenAddress).safeTransferFrom(_msgSender(), reserve.eTokenAddress, amount);
```

**Exploit scenario:** `repay(amount=1000 ETH)` when `debt=1 ETH` → credit += 1000 ETH (full), amount capped to 1 ETH, vault pays 1 ETH, gets 1000 ETH credit.

**On-chain verification:** `cast call 0xBB505c54... "nextDebtPositionId()(uint256)"` returns 247. `borrowingWhiteList[VaultPositionManager] = false` — no vaults currently whitelisted on Base. Bug is real but gated behind whitelist.

### Access Control Context

- `repay()` requires `borrowingWhiteList[msg.sender]` = true (onlyOwner sets per-vault)
- Only individual vault contracts (not VaultFactory, not VeloPositionManager) are whitelisted
- Verified on-chain: vaults 1-5 are whitelisted, FLASHLOAN_LIQUIDATE contracts are NOT
- `permissionLessLiquidationEnabled = false` on VeloPositionManager

### Fix (in repo, not on mainnet)

Move cap BEFORE credit update. Mainnet contracts are non-upgradable; mitigation is operational.

### All 5 Known Bugs from BUG_FIXES_AND_MODIFICATIONS.md

| Bug | Impact | Mainnet Mitigation | Exploitable? |
|-----|--------|-------------------|-------------|
| eToken inflation | First depositor drains pool | Batched init + burn 10K eTokens to dead | ❌ Mitigated |
| Credit logic in repay() | Unlimited credit after single repay | Only whitelisted vaults can call | ❌ Access controlled |
| StakingRewards endTime | Rewards calc fails | Multisig (3 signers) | ❌ Owner-only |
| Reward claim blocking | One bad token blocks all claims | Team verifies tokens | ❌ Owner-only |
| lastUpdateTimestamp | First borrower overcharged interest | Team borrows small amount at creation | ❌ Mitigated |

**Key lesson:** All mitigations are operational (multisig, batched tx, manual). If team misses a step on a NEW pool listing, bugs become exploitable.

## Part 2: XLend Oracle Adapter Analysis (xlend-contracts)

### Architecture

XLend = Aave V3 fork (commit b74526a) deployed on Optimism + Base. Custom additions:
- `DefaultReserveInterestRateStrategyV2` — custom interest rate model
- `VeloTwapPriceAdapter` — 30-min TWAP from VeloPool + Chainlink base
- `VeloPriceAdapter` — SPOT price from VeloPool `getAmountOut()` + Chainlink base
- `ExtraXAccountFactory` — ERC-4337 account abstraction (Coinbase + Safe)
- `CoinbaseAccountCreatorLegacy.sol` — deprecated version still in repo

### Critical Finding: VeloPriceAdapter Uses Spot Price (LATENT RISK)

```solidity
// VeloPriceAdapter.sol — SPOT price, flash-loan manipulable
int256 xRate = VELO_POOL.getAmountOut(10 ** targetDecimals, TARGET_ASSET).toInt256();
```

- Comment says "display only, do not use for liquidations"
- BUT it implements `latestAnswer()` which `AaveOracle.getAssetPrice()` calls directly
- If registered as oracle source for ANY reserve → flash loan price manipulation → bad debt

### On-Chain Verification: Oracle Source Audit (NEW TECHNIQUE)

**This is the critical technique:** Don't trust code comments — verify on-chain which oracle source is actually registered.

```bash
# 1. Get AaveOracle address from deployed-contracts.json
AAVE_ORACLE=0x1bc889345C912d5462b71e019F9dCcbA33d83db4  # Optimism
# AAVE_ORACLE=0xe4f11109EeE64a9a6BEB5D3BCf4a5d9c70054DEc  # Base

# 2. For EACH reserve, get its oracle source
cast call $AAVE_ORACLE "getSourceOfAsset(address)(address)" $RESERVE_TOKEN --rpc-url $RPC

# 3. For each source, identify the type:
#    - description() → "DAI / USD" = Chainlink direct
#    - VELO_POOL() returns non-zero = VeloPriceAdapter or VeloTwapPriceAdapter
#    - BASE_AGGREGATOR() returns non-zero = Velo adapter (uses Chainlink base)
```

### On-Chain Results (Aug 2026)

**Optimism (8 reserves):** ALL use Chainlink direct feeds. Descriptions: "DAI / USD", "ETH / USD", "OP / USD", etc. No Velo adapters registered.

**Base (5 reserves):** ALL use Chainlink (capped feeds). Descriptions: "Capped USDC/USD", "ETH / USD", "cbBTC / USD". No Velo adapters registered.

**Verdict:** VeloPriceAdapter and VeloTwapPriceAdapter exist in the repo but are NOT deployed as oracle sources. Latent risk only. If ExtraFi lists EXTRA token (or any low-liquidity token) using VeloPriceAdapter → flash loan exploitable.

### Deployed Addresses (from contracts-and-pools-info repo)

```
Optimism:
  LendingPool: 0xBB505c54D71E9e599cB8435b4F0cEEc05fC71cbD
  VaultFactory: 0x155620A2E6A9392c754B73296d9655061525729B
  VeloPositionManager: 0xf9cFB8a62f50e10AdDE5Aa888B44cF01C5957055
  AaveOracle (XLend): 0x1bc889345C912d5462b71e019F9dCcbA33d83db4
  Pool (XLend): 0x345D2827f36621b02B783f7D5004B4a2fec00186
  ExtraXAccountFactory: 0x90cF2763CC710B9Ce215584A89c77F70bbb96B44

Base:
  AaveOracle (XLend): 0xe4f11109EeE64a9a6BEB5D3BCf4a5d9c70054DEc
  Pool (XLend): 0x09b11746DFD1b5a8325e30943F8B3D5000922E03
  ExtraXAccountFactory: 0x2623e7518cf2bFC71786EdC033fa5a5474b3ff89
```

Source: `https://raw.githubusercontent.com/ExtraFi/contracts-and-pools-info/main/xlend-files/deployed-contracts.json`

## Part 3: Web2 Attack Surface

### SPA Fallback False Positive

`app.extrafi.io` returns HTTP 200 for ALL paths — including `/.env`, `/admin`, `/actuator`, `/graphql`. This is a React SPA serving index.html (2840 bytes) for every route. Not exploitable.

**Detection method:** Compare response size across paths. If all paths return the same byte count, it's SPA fallback, not real endpoints.

```bash
for p in / /.env /admin /actuator /api/v1 /graphql; do
  size=$(curl -s -m 8 "https://app.extrafi.io$p" | wc -c)
  echo "  $p → $size bytes"
done
# If all 2840 bytes = SPA fallback, move on
```

### Other Web2 Findings

- ❌ No server-side API — pure client-side SPA, all on-chain
- ❌ S3 bucket (`extra-static.s3.ap-southeast-1.amazonaws.com`) — AccessDenied on listing, .env 403
- ⚠️ `preview.extrafi.io` exposes `X-Powered-By: Express` header (info disclosure, not exploitable)
- ❌ No .git exposure, no env leak, no debug endpoints

## Bounty Assessment

| Criterion | Value |
|-----------|-------|
| Bounty program | ❌ NONE |
| Max bounty | $0 |
| Source code | ✅ Full GitHub |
| Audit coverage | extra-contracts audited, XLend NOT |
| Competition | Low (no bounty = no hunters) |
| Security contact | contact@extrafi.io |

**No bounty program = no payout path.** Even a critical 0-day has no formal channel. Options: (1) contact team directly for informal bounty, (2) monitor for bounty program launch, (3) pivot to targets with active programs.

## Key Lessons

1. **GitHub Issues = vulnerability discovery shortcut.** Check `api.github.com/repos/<ORG>/<REPO>/issues?state=open` before starting a fresh audit.
2. **BUG_FIXES_AND_MODIFICATIONS.md** — Some repos document their own known bugs. Always look for this file.
3. **On-chain oracle source verification is MANDATORY.** Code comments saying "display only" are meaningless if the adapter implements `latestAnswer()` and `AaveOracle.getSourceOfAsset()` returns it as the source. Always `cast call` to verify.
4. **Aave V3 forks with custom oracle adapters** are high-value targets. The fork base is well-audited, but custom additions (oracle adapters, interest rate strategies, account abstraction) are NOT covered by Aave audits.
5. **SPA fallback = false positive.** If all paths return same byte count, it's not real endpoints. Check response size, not just status code.
6. **Multi-repo protocols need per-repo audit scope verification.** ExtraFi has `extra-contracts` (audited) and `xlend-contracts` (likely not). Don't assume one audit covers all repos.
7. **No bounty program ≠ no value.** Contact team directly. Many small protocols pay informally for critical findings.
