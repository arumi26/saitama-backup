# ExtraFi (extrafi.io) — JS Bundle Deep Dump Reference

## Target
- Protocol: Lending + Leveraged Farming (Base + Optimism)
- App: https://app.extrafi.io (React SPA, Cloudflare)
- Source: github.com/ExtraFi/extra-contracts (527 .sol, OPEN)
- Bug Bounty: immunefi.com/bounty/extrafinance/

## JS Bundle Extraction
- Bundle: /assets/index-BYrZvAM4.js (5.4MB)
- 300+ contract addresses, 69 chain IDs
- Internal RPC: http://13.213.204.241:8545 (AWS Singapore — SG-restricted)
- TheGraph subgraph: a4998f968b8ad324eb3e47ed20c00220
- S3: extra-static.s3.ap-southeast-1.amazonaws.com (list denied)

## Known Bugs (BUG_FIXES_AND_MODIFICATIONS.md)
7 disclosed bugs — all "repo fixed, mainnet mitigated"
Key: verify mitigation conditions haven't changed. Whitelist-only mitigations become critical if permissionless mode enabled.

## Audit Patterns for Lending+Farming Protocols
1. Credit system arithmetic (credits[reserveId][vault])
2. Borrowing whitelist bypass
3. permissionLessLiquidationEnabled flag in VeloPositionManager
4. Frozen reserve check consistency
5. Interest rate rounding direction (intentional in ExtraFi)

## Methodology
- JS bundle window.env: alchemy keys are env vars (not extractable from bundle)
- Auth via third-party (auth.farca.studio)
- No Firebase keys exposed in SPA HTML
- robots.txt allows all, no security.txt