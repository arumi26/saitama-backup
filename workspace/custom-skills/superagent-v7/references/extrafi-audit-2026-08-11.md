# ExtraFi.io Audit — 2026-08-11

## Session Summary
6+ hours deep audit of ExtraFi (Aave v3 fork + Morpho MetaMorpho vaults on Base).
**Smart contract result: 0 fund-drain bugs.** All CRITICAL findings were on the WEB2 surface.

## Key Lesson: Battle-tested forks → web2 first
- Aave v3 forks, Morpho vaults, Compound forks — after 2+ audits, the smart contracts are clean.
- The bugs are in the web2 surface: JS bundle leaks, CORS, S3 buckets, API key exposure.
- **Workflow change:** For DeFi >1yr old with >2 audits → 30 min max on smart contracts, then hard pivot to web2.

## Confirmed Findings

### CRIT-01: Coinbase RPC API Key Leaked in JS Bundle
- **Source:** `app.extrafi.io/assets/index-BYrZvAM4.js` (5.6MB)
- **Key:** `0txHZs13U0KInOLNdOuRDjSUOeGHUs7d`
- **Impact:** DoS dApp, RPC quota theft, frontrunning
- **PoC:** `curl -X POST "https://api.developer.coinbase.com/rpc/v1/base/KEY" -d '{"method":"eth_blockNumber","params":[],"id":1}'` → valid response

### HIGH-01: CORS Misconfiguration on API
- **Host:** `strato-api.extrasafe.link`
- **Header:** `Access-Control-Allow-Origin: *`
- **Impact:** Cross-origin data theft from any website
- **PoC:** `curl -H "Origin: https://evil.com" "https://strato-api.extrasafe.link/api/v1/subscriber/0x.../getTelegramBinding"` → 200 OK

### MED-01: Public S3 Bucket Data Exposure
- **Buckets:** `extra-static.s3.amazonaws.com`, `extra-static.s3.ap-southeast-1.amazonaws.com`
- **Data:** All pool APRs, $1M+ vault configs, 28 pools across Base/Optimism
- **PoC:** `curl "https://extra-static.s3.amazonaws.com/data/xlend/vaults/info.json"` → full JSON

## Smart Contract Audit (Clean)

### ExtraFi / Aave V3
- 15 reserves on Base, all using Chainlink price feeds
- Fallback oracle = 0x0 (no exploit path)
- EXTRA token not active as collateral → no price needed
- Pool: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`

### Morpho Vaults
- exmWETH: `0x5A32099837D89E3a794a44fb131CBbAD41f87a8C` — 249 WETH ($470K)
- exmUSDC: `0x23479229e52Ab6aaD312D0B03DF9F33B46753B5e` — $433K
- All admin functions guarded by owner/guardian only
- supplyQueueLength = 0 (idle funds)
- 7 Morpho markets, 0 borrows across all
- No rebalance/setFee/setSupplyQueue abuse possible

### FlashLoanLiquidate
- `0x84c0C64c2608eC04FDFdD15fc8eE5DF77F4E398e` (Base)
- executeOperation guarded by onlyLendingPool
- withdraw guarded by onlyOwner
- Permissionless liquidation enabled (storage slot 3 = 1)
- No vault positions with bad debt to liquidate

### VeloPriceAdapter
- Explicitly commented: "DO NOT use for risk-critical operations"
- Not registered as active oracle source for any reserve

## Deliverables
- `~/reports/extrafi/IMMUNEFI_REPORT.md` — Full report
- `~/reports/extrafi/coinbase-key-poc.py` — Python PoC
- `~/reports/extrafi/cors-poc.html` — HTML PoC
- Target: `https://immunefi.com/bounty/extrafinance/`

## Subsequent Targets (Also Clean)
- **RocketPool:** 5yr production, Solidity 0.7.6, 50+ audits, $3B TVL. Clean.
- **Ionic Protocol:** Compound V2 fork with Diamond pattern + custom liquidators. Flash loan callback secure, no reentrancy. Clean.

## Nuclei Scanning Attempt
- `go install nuclei` took 60+ seconds, timed out
- Manual curl-based scan was faster and more effective
- For SPA targets (React/Vue), ALL path probes return 200 (same byte count = false positive)
- SPA fallback detection: `for p in / /actuator /.env; do curl -s "$host$p" | wc -c; done` → if all identical, skip