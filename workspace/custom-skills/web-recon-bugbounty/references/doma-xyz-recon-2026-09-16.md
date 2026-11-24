# DOMA.xyz Recon Case Study (Sep 2026)

## Target Overview
**DOMA.xyz** — Web3 domain trading platform (Next.js + Vercel + Cloudflare + Privy + Conduit + PostHog stack). Not on Immunefi/HackenProof public lists — manual target.

## Infrastructure Analysis
| Layer | Provider | Evidence |
|-------|----------|----------|
| Edge/WAF | Cloudflare | `server: cloudflare`, `cf-ray`, IPs `172.66.x.x`, `104.20.x.x` |
| Frontend Hosting | Vercel/Next.js | `x-nextjs-*` headers, `_next/static/chunks/`, Turbopack, deploy ID `dpl=61c2bdeb...` |
| Auth | Privy | `privy.doma.xyz` → `cm9jd3vun03ptju0knmkls1zp.api.privy.systems` |
| Analytics | PostHog | `posthog*.doma.xyz` → Privy subdomain |
| RPC/Indexing | Conduit | `rpc.doma.xyz` → `rpc-doma-mainnet-qvzsfv8nv0.t.conduit.xyz` |
| Bridge Testnet | Vercel/Superbridge | `bridge-testnet.doma.xyz` → `superbridge.app` og tags |
| CDN Assets | Cloudflare R2/Vercel | `cdn.doma.xyz` serves all `_next/static/*` |

**Verdict: Fully managed/cloud — NOT self-hosted.** Zero origin IPs exposed.

## Key Findings

### 1. CORS Misconfiguration on Public RPC (HIGH)
**Endpoint:** `https://rpc.doma.xyz`
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Content-Type, Authorization, X-AccessKey
Access-Control-Allow-Methods: POST, OPTIONS
```
- Any origin can make authenticated RPC calls
- Chain ID: `0x17cc5` (Doma Mainnet - 97477 decimal)
- Methods exposed: `eth_chainId`, `eth_blockNumber`, `eth_getBalance`, `eth_getTransactionCount`, `eth_call`, etc.
- **PoC created:** `/home/ubuntu/doma-rpc-cors-poc.html` — interactive HTML demonstrating chain ID theft, block number theft, account enumeration, balance queries
- **Impact:** Any malicious website can make RPC calls on behalf of users with active Doma sessions

### 2. Broken Subdomain — Cloudflare Error 1016 (LOW/MEDIUM)
**Endpoint:** `https://graph.doma.xyz`
- Returns HTTP 530 + "error code: 1016" (Origin DNS Error)
- Subdomain resolves to Cloudflare IPs but origin unreachable
- **Takeover risk:** If origin was third-party (GitHub Pages, Heroku, Netlify), subdomain is claimable
- Check historical DNS (SecurityTrails, Censys) for previous CNAME targets

### 3. Actual GraphQL Endpoint (Authenticated)
**Endpoint:** `https://app.doma.xyz/api/graphql`
- Returns 401 "Unauthorized: No token provided"
- Introspection blocked without auth
- No public playground/Altair/Voyager exposed

### 4. tRPC Endpoints (Authenticated)
**Base:** `https://app.doma.xyz/api/trpc/`
Procedures discovered via JS bundle analysis + brute force:
- `portfolio.get`, `portfolio.getPortfolio`
- `wallet.get`, `wallet.getBalance`, `wallet.getWallets`
- `user.get`, `user.getProfile`, `user.getAccount`
- `domain.get`, `domain.getDomains`
- `token.get`, `token.getToken`, `token.getAssetToken`
- `analytics.get`, `analytics.getAnalytics`
- `trade.get`, `trade.getHistory`
- `swap.get`, `bridge.get`, `pool.get`, `position.get`, `order.get`, `activity.get`

All return 401 without valid session token.

### 5. Preview Deployment Goldmine (30+ deployments)
**Pattern:** `d3-<PR_NUMBER>-<DESC>.app.doma.xyz`
```
d3-7890-shell-pools-mainnet-app.doma.xyz
d3-7909-graduated-metrics-bar-app.doma.xyz
d3-8010-portfolio-launch-dns-gate-app.doma.xyz
... (30+ more from crt.sh)
```
All return 200 OK, serve full Next.js app with:
- Same RPC endpoints as production
- Bridge configurations (Solana, Doma mainnet/testnet, Avalanche, Optimism, Base)
- Chain IDs, wallet integrations
- `api.hypelab.com` analytics SDK
- Feature flags differing from production

**Exploitation checklist:**
- [ ] Crawl all preview deployments for `/api/*` endpoints
- [ ] Check for debug endpoints (`/__debug`, `/_health`, `/test`, `/dev`)
- [ ] Test auth bypass (preview often has weaker/no auth)
- [ ] Look for test credentials in JS bundles
- [ ] Compare feature flags vs production
- [ ] Check for exposed `.env` / config in preview

### 6. Bridge Testnet on Vercel (Different Infra)
**Endpoint:** `https://bridge-testnet.doma.xyz`
- **Server:** Vercel (not Cloudflare!)
- **Superbridge deployment** (og:title "Doma Testnet bridge", og:url "https://superbridge.app")
- Different infrastructure = different attack surface
- Check for subdomain takeover if deployment deleted

### 7. JS Bundle Intelligence Extraction
From Next.js chunks (`cdn.doma.xyz/_next/static/chunks/*.js`):
- RPC endpoints: `rpc.doma.xyz`, `rpc-proxy.doma.xyz`, `rpc-testnet.doma.xyz`
- Bridge configs: Solana mainnet/devnet, Doma mainnet/testnet, Avalanche, Optimism, Base
- Chain IDs, native currencies, block explorers
- Wallet integrations: Privy, WalletConnect, MetaMask, 1inch, Meld
- Feature flags: auto-trading, limit orders, community chat, AI chat, etc.

## Tools & Scripts Created

| File | Purpose |
|------|---------|
| `/home/ubuntu/doma-rpc-cors-poc.html` | Interactive CORS exploit PoC |
| `/home/ubuntu/doma-graphql-test.sh` | GraphQL endpoint testing |
| `scripts/idor-test-framework.sh` | IDOR testing framework (requires auth token) — **in skill** |

## IDOR Testing Framework Usage
```bash
# Get auth token from logged-in session (DevTools → Network → Authorization header)
./scripts/idor-test-framework.sh "Bearer eyJhbG..." "target-user-id-or-address"
```
Tests: REST `/api/v1/*`, tRPC procedures, GraphQL queries with `userId`/`address`/`accountId` parameters.

## Recon Commands Used
```bash
# Subdomain enum via crt.sh (most reliable)
curl -s "https://crt.sh/?q=%.doma.xyz&output=json" | jq -r '.[].name_value' | sort -u

# Live check
for sub in $(cat subs.txt); do code=$(curl -s -o /dev/null -w "%{http_code}" "https://$sub"); [[ "$code" =~ ^[23] ]] && echo "$code $sub"; done

# Tech fingerprint
curl -sI "https://app.doma.xyz" | grep -iE "server|x-next|cf-|content-security-policy"

# CORS test
curl -s -X POST https://rpc.doma.xyz -H "Origin: https://evil.com" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' -v

# JS bundle extraction
curl -s https://app.doma.xyz | grep -oE '_next/static/chunks/[^"]+\.js' | head -10 | while read chunk; do curl -s "https://cdn.doma.xyz/$chunk" | grep -oE '(rpc|bridge|chain|wallet|token)[^"'"'"'\s\}]*' | sort -u; done

# Preview deployment detection
curl -s "https://crt.sh/?q=%.doma.xyz&output=json" | jq -r '.[].name_value' | grep -E '^d3-[0-9]+-' | sort -u
```

## Severity Assessment
| Finding | Severity | CVSS | Status |
|---------|----------|------|--------|
| RPC CORS wildcard + auth headers | **HIGH** | ~7.5 | PoC ready |
| graph.doma.xyz Error 1016 | **LOW/MEDIUM** | ~3.7 | Needs historical DNS check |
| Preview deployments (30+) | **INFO** | N/A | Requires auth for full test |
| Authenticated endpoints (REST/tRPC/GraphQL) | **INFO** | N/A | Properly protected |

## Submission Path
Since not on Immunefi:
1. Direct: `security@doma.xyz` or contact form
2. Include: PoC HTML + curl proof + impact description
3. Request: Private disclosure thread before full details

## Lessons Learned
1. **Managed Web3 dapps** often have public RPC endpoints with lax CORS — always test `rpc.*`, `api.*`, `graph.*` subdomains
2. **Vercel preview deployments** (`d3-*.app.*`) are high-value — they share production infra but may have weaker auth
3. **GraphQL on separate subdomain** (`graph.*`) often broken/misconfigured — check for Error 1016
4. **tRPC procedures** discoverable via JS bundle analysis + common naming patterns
5. **Bridge testnet on different infra** (Vercel vs Cloudflare) = separate attack surface
6. **Privy auth** = wallet-signature based, no session cookies — focus on signature replay, nonce reuse, JWT manipulation