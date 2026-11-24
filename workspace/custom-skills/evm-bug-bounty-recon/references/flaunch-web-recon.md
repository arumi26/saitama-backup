# Flaunch Web Recon — Subdomain & Infrastructure

**Date:** 2026-07-16
**Target:** flaunch.gg

## Subdomains Discovered

| Subdomain | Status | Server | Notes |
|-----------|--------|--------|-------|
| flaunch.gg | 200 | Vercel | Main app, Next.js SPA |
| app.flaunch.gg | 301 → legacy.flaunch.gg | Cloudflare | Redirects to legacy |
| legacy.flaunch.gg | 200 | Cloudflare | "Flaunch — Withdraw" deprecated portal |
| dev.flaunch.gg | 200 | Vercel | Dev environment, noindex tag |
| docs.flaunch.gg | 200 | - | Documentation |
| metrics.flaunch.gg | 200 | Vercel | Metrics dashboard |

## Key Findings

### legacy.flaunch.gg — Active Withdrawal Portal
- Title: "Flaunch — Withdraw"
- Description: "Withdraw from Groups — deprecated legacy Flaunch site"
- Has ConnectButton + GroupList components
- Old contracts still connected
- **Bug Bounty Value:** $1K-$3K (deprecated but active)

### dev.flaunch.gg — Dev Environment Exposed
- Title: "Flaunch - Launch. Trade. Earn."
- Banner: "Plugins are live. Launch coins with custom earnings mechanics."
- `robots: noindex` but publicly accessible
- Different deployment (dpl_7spdGHwk3PDrZin2qvLr689d1pqD)
- **Bug Bounty Value:** $500-$2K

## Web App Security

### No Traditional Admin Panel
- Next.js SPA (client-side routing)
- No REST API endpoints exposed
- No GraphQL endpoint
- No .env/.git/sourcemap leaks
- Auth via wallet signature (no password login)

### Attack Surface
- JavaScript bundles (check for hardcoded secrets)
- Source maps (if exposed)
- Subdomain takeover potential
- Legacy contract interactions

## Scan Commands Used

```bash
# Subdomain enumeration
curl -sI https://app.flaunch.gg  # → 301 legacy.flaunch.gg
curl -sI https://dev.flaunch.gg  # → 200

# Check for exposed files
curl -s https://dev.flaunch.gg/.env  # → 404
curl -s https://dev.flaunch.gg/package.json  # → 404

# JavaScript bundle analysis
curl -s https://legacy.flaunch.gg/_next/static/chunks/*.js | grep -i "sk-\|api_key\|secret"
```

## Lessons Learned
- Always check subdomains (app, dev, staging, legacy)
- Legacy portals may still have active contract connections
- Dev environments often leak implementation details
- Next.js apps have no traditional REST API to exploit
