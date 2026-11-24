# app.monad.xyz Recon Case Study — July 30, 2026

## Target
- URL: https://app.monad.xyz/
- Type: Monad L1 ecosystem portal (app hub, staking, vaults, rewards)
- Tech: Next.js (App Router, i18n: en/zh/ko) on Vercel, Cloudflare for some assets
- Deploy ID: dpl_CrkbJs6P8aBzazDio91kbtGANdnT
- Sent‑ID: dpl_CrkbJs6P8aBzazDio91kbtGANdnT

## Key Findings

### 1. API Rate‑Limited (429) — Hidden API Behind Rate Limit
Several `/api/*` paths returned **429 (Too Many Requests)** instead of 404 — meaning **real API routes exist behind rate limiting**. This is a HIGH‑VALUE signal.
Endpoints returning 429:
- /api/health
- /api/status
- /api/admin
- /api/graphql
- /api/trpc
- /api/rpc

All other paths returned 404 (Next.js error page) or 307 (redirect). Rate limited = real route.

### 2. Sentry DSN Leaked in HTML Meta Tags
Full Sentry configuration exposed in `<meta>` tags on every page:
- `sentry-public_key=74ab7ac8d0ec35a4ffc5e544d6fe2015`
- `sentry-release=216705e0225668f038cb7219b9b6dc4c9957dd81`
- `sentry-environment=vercel-production`
- `sentry-org_id=4508965485674496`
- `sentry-trace_id` (dynamic per page load)

This is a common Next.js + Sentry pattern. The public key is designed to be client‑visible, but it can be used to:
- Send fake error events to pollute their Sentry dashboard
- Read public project details (rate limits, release info)
- Explore whether the Sentry API allows reading error data (usually needs auth, but worth checking)

### 3. CSP `unsafe-eval` + Broad connect-src
CSP allows `script-src 'unsafe-eval'` — XSS gadget possible if input reaches eval().
connect-src lists **30+ external API domains** — each is a potential attack target:
- `proxy-mn.gmonads.com` — Monad proxy (HIGH)
- `*.monadinfra.com` — Monad infra (HIGH)
- `*.fun.xyz` — Nad.fun launchpad (HIGH)
- `auth.privy.io` — Wallet auth provider (MEDIUM)
- `*.moonpay.com` — Fiat onramp (MEDIUM)
- `*.coinbase.com` — Coinbase wallet (MEDIUM)
- `*.quiknode.pro` — RPC nodes (INFO)
- `*.drpc.org` — RPC provider (INFO)

### 4. Auth Provider: Privy (auth.privy.io)
App uses Privy for wallet‑based authentication (like WalletConnect but with more features).
- Privy CSP reveals broad infrastructure: `*.rpc.privy.systems`, Google Analytics, hCaptcha
- Auth flow: wallet connect → sign message → Privy issues token → app uses token for API calls
- Attack surface: JWT/token manipulation, signature replay, session fixation

### 5. Sitemap Routes Discovered
```
/                     → Main page (app hub)
/app-hub              → All apps directory
/rewards              → Rewards page
/agents               → AI agents page
/app-hub/{slug}       → Individual app pages (kuru, metamask_money_account, nad_fun, etc.)
```

### 6. App Ecosystem (from RSC payload)
Full app list with external links:
- Perpl (perpl.xyz) — onchain perps
- Nad.fun (nad.fun) — launchpad
- BONAD (bonad.fun) — meme launchpad
- Kuru — trading hub
- Uniswap — DEX
- Aave — lending
- Euler — lending super app
- Morpho — lending network
- Curvance — lending
- Neverland — self‑repaying loans
- Gearbox — leverage
- TownSquare — lending market
- Clober — CEX on DEX
- FastLane — liquid staking
- 20+ other apps

Each app link is a potential sub‑target for bug bounty.

### 7. Missing security.txt
`/.well-known/security.txt` returned 404 (Next.js error page). No formal responsible disclosure contact found.

### 8. Next.js Build IDs (Turbopack)
- DPL ID (Vercel): `dpl_CrkbJs6P8aBzazDio91kbtGANdnT`
- Unlike classic Next.js, Turbopack uses randomized chunk names (e.g., `0hd0m.fnon~so.js`) instead of predictable `[name]-[hash].js` patterns
- RSC payload embedded in `self.__next_f.push()` calls — extract route + component data

## MCP Integration: PayBox

### Discovery
The PayBox MCP endpoint at `https://api.paybox.sh/mcp` was successfully connected using an OAuth 2.1 Bearer token.

### OAuth Flow
1. GET `https://api.paybox.sh/.well-known/oauth-protected-resource` → returns resource + authorization_servers
2. GET `https://api.paybox.sh/.well-known/oauth-authorization-server` → returns:
   - authorization_endpoint: `https://api.paybox.sh/oauth/authorize`
   - token_endpoint: `https://api.paybox.sh/oauth/token`
   - registration_endpoint: `https://api.paybox.sh/oauth/register`
   - response_types: `code`
   - grant_types: `authorization_code`, `refresh_token`
   - code_challenge_methods: `S256` (PKCE)
   - scopes: `mcp`, `offline_access`

### MCP Connection Requirements
- Must send `Accept: application/json, text/event-stream` (both!) or get 406
- Must send `Authorization: Bearer <token>` header
- Protocol version: `2025-06-18` (server returns this even if client sends `2024-11-05`)
- Server: `rmcp` v1.7.0

### MCP Tools (17 discovered)
Full tool list with input schemas extracted. Key tools:
- `list_credentials` — show granted wallets/cards/secrets
- `get_portfolio` — check balances across chains
- `request_swap` — swap tokens cross-chain
- `request_transfer` — send tokens to address
- `request_wallet_sign` — sign messages/transactions
- `request_payment` — virtual card payment
- `discover_services` — x402 service marketplace
- `pay_x402` — pay x402 payment requests
- `verify_solana_balance` — verify Solana tx on-chain

### PayBox Bounty Surface
PayBox is a MoonPay product that lets AI agents control crypto wallets. Key attack vectors:
- OAuth token theft/replay
- Scope escalation (from `mcp` to admin)
- MCP tool injection (can a malicious tool be added?)
- Wallet signing bypass (skip passkey approval)
- Virtual card fraud (request_payment + claim_payment_credentials)
- x402 payment proof forgery
- Cross‑chain swap manipulation

## Next Steps
1. Rate‑limit bypass on `/api/*` endpoints (rotate IP, X-Forwarded-For, delay)
2. Recon `proxy-mn.gmonads.com` — Monad proxy server
3. Sentry DSN: try reading error data via Sentry API
4. `/rewards` page — check for auth flow + API key handling
5. `/agents` page — AI agent page, potential API endpoints
6. PayBox MCP: check bounty program status on Immunefi/HackerOne
