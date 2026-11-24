# SwarmBase DApp Recon Case Study

**Date:** 2026-08-03
**Target:** SwarmBase (swarmbase.io)
**Chain:** opBNB
**Type:** AI Agent Platform + Points/Airdrop Farming

## Project Overview
- **Tagline:** Decentralized swarm intelligence for autonomous AI agents
- **Followers:** 37.6K (Twitter @SwarmBase, verified)
- **Tech Stack:** ethers.js v6.13.4, React SPA, opBNB chain
- **DApp:** smart.swarmbase.io
- **Points System:** core.swarmbase.io/points (SwarmScore on opBNB)
- **Token:** $SWARM (TGE TBD)

## Recon Method
Browser tools failed (CDP connection refused, Snap Chromium broken). Used `curl -sL` to extract HTML shell, then grep for:
- `<meta>` tags → description, title
- `<script src="...">` → tech stack (ethers.js v6.13.4)
- CSS custom properties → color scheme, branding
- Inline text content → points system, badges, check-in mechanic

## Key Findings
1. **Points System:** SwarmScore calculated on-chain via opBNB wallet activity
2. **Badges:** 6 categories (Research, Builder, Creative, Analyst, Monitor, Outreach) — NFT Badge format
3. **Daily Check-in:** Mechanic to earn more points
4. **FCFS Badge Mint:** Early registration matters
5. **Subdomains discovered:**
   - `core.swarmbase.io` — points/badges dashboard
   - `smart.swarmbase.io` — dApp frontend
   - `opbnb-mainnet-rpc.bnbchain.org` — RPC endpoint

## What Couldn't Be Verified
- Contract `0x238a46fFd22be95Dddcc51Ec23FAA0774AC85718` — opBNBScan API down (timeout), explorer has SSL issues
- No source code found on GitHub for the submit contract
- Twitter API (`api.fxtwitter.com`) worked but only returned profile info, no recent tweets about mechanics

## Risk Assessment
- **Early stage:** Points/airdrop farming, no TGE date announced
- **Verified Twitter** with 37.6K followers — non-trivial social proof
- **No rug-pull signs detected** but too early to confirm contract safety
- Submit address may be a registry, not the token contract

## Pattern for Future DApp Recon
1. `curl -sL` + grep for meta/script tags → basic info
2. `api.fxtwitter.com/USERNAME` → Twitter intel
3. Check `core.*` subdomains for static HTML with airdrop info
4. Browser tool is primary for dApp interaction, curl is fallback
5. opBNB contracts: API unreliable, GitHub source preferred
