# Across Protocol Recon — August 2026

## Target
- **Domain:** across.to
- **Type:** DeFi cross-chain bridge (EVM + Solana)
- **Bug Bounty:** bugs@across.to · up to $1M critical · https://docs.across.to/introduction/bug-bounty
- **Tech:** Next.js (Vercel + Cloudflare), Express/GCP (API), Google IAP (internal)

## Subdomains (37 discovered via HackerTarget + Google DNS)
```
across.to, www.across.to, app.across.to, api.across.to, v1.across.to, v2.across.to
staging.across.to, v2.staging.across.to, app.staging.across.to
docs.across.to, legacy-docs.across.to, exclusive.docs.across.to
forum.across.to, discord.across.to, status.across.to
exchange.across.to, design.across.to, links.across.to
alexandria.across.to, skills.across.to, supply.across.to
mcp.across.to, analytics.across.to
dev.api.across.to, dev.indexer.api.across.to, dev.public.api.across.to
public.api.across.to, indexer.api.across.to, indexer.across.to
stage.auction.api.across.to, stage.integrator.api.across.to
cr.dev.quotes.api.across.to
stickbird.across.to, stickbird-staging.across.to, stickbird-staging-selector.across.to
preview.across.to, preview.testnet.across.to, testnet.across.to
```

## Key Findings

### F1: CORS Reflected Origin on Production API (MEDIUM)
- `api.across.to/deposits` and `public.api.across.to/deposits` reflect arbitrary `Origin` in `ACAO`
- **Critical nuance:** server also sets `CORP: same-origin` + `COEP: require-corp` — but CORS grant overrides CORP in browsers
- `Vary: Origin` header confirms dynamic reflection
- Deposit data exposed: wallet addresses, amounts, chain IDs, tx hashes, fee data
- PoC: `curl -sI -H "Origin: https://evil.com" "https://api.across.to/deposits" | grep access-control`

### F2: CORS Wildcard + OpenAPI on Dev/Prod Indexers (MEDIUM)
- `dev.indexer.api.across.to` and `indexer.api.across.to`: `ACAO: *`, full OpenAPI spec at `/openapi.json`
- 8 endpoints: `/deposits` (no auth), `/deposit`, `/deposit/status`, `/pda-transfers-monitor`, `/gasless-transfers-monitor`, webhook CRUD (Bearer auth)
- Express + GCP backend, Swagger UI at `/docs/`
- Dev environment mirrors production API structure exactly

### F3: Dev/Staging Subdomains Exposed (LOW-MEDIUM)
- 10+ dev/staging subdomains publicly resolvable and accessible
- `staging.across.to` — full marketing page, identical to production
- `cr.dev.quotes.api.across.to` — Cloudflare 525 (SSL origin failure, broken TLS)
- Silent DNS entries for decommissioned services (`stage.auction`, `stage.integrator`)

### F4: Google IAP OAuth Client ID (LOW)
- `stickbird.across.to` → 302 → `accounts.google.com/o/oauth2/v2/auth?client_id=308020036798-...`
- Pattern: when subdomain returns 302 to Google IAP, extract `client_id` + `redirect_uri` params
- Reveals internal tool naming + auth infrastructure

### F5: CSP Report-Only (Not Enforced) (LOW)
- `across.to`, `v2.across.to`, `staging.across.to` all use `Content-Security-Policy-Report-Only`
- `script-src` includes `'unsafe-inline'` and `'unsafe-eval'`
- Contrast: `api.across.to` has strong **enforced** CSP with COEP/COOP/CORP
- Reports go to `umaproject.uriports.com`

## What Was NOT Found
- No `.git`/`.env` exposure (Cloudflare/Vercel block all)
- No open redirects (all redirect to `/` with query params, not external)
- No SQLi, GraphQL, cache poisoning, host header injection
- No API keys in JS bundles (initial scan of across.to main page HTML)
- No TRACE method (Cloudflare blocks with 405)

## Security Headers Comparison
| Header | across.to | api.across.to | v2.across.to |
|--------|-----------|---------------|--------------|
| CSP | Report-Only | Enforced (strong) | Report-Only |
| X-Frame-Options | DENY | SAMEORIGIN | DENY |
| HSTS | 63072000 | 15552000 | 63072000 |
| COEP | ❌ | require-corp | ❌ |
| COOP | ❌ | same-origin | ❌ |
| CORP | ❌ | same-origin | ❌ |
| Referrer-Policy | strict-origin | no-referrer | strict-origin |
| Server | cloudflare | cloudflare | cloudflare |

## Recon Pipeline Notes
- crt.sh was down (timed out) — HackerTarget hostsearch was the primary source (37 subdomains)
- Google DNS-over-HTTPS confirmed live hosts for common sub names
- Vercel subdomains (alexandria, links, skills) resolve to `*.vercel-dns-016.com` CNAMEs
- `supply.across.to` → Google Sites (ghs.googlehosted.com CNAME)
- `forum.across.to` → self-hosted Discourse (184.105.99.75)
- `exchange.across.to` → Vercel with security challenge (403, x-vercel-mitigated: challenge)
- `v1.across.to` → SPA on Vercel (66.33.60.129, 76.76.21.22) — all paths return 200 (SPA fallback)
- `mcp.across.to` → 404 on Google Frontend (mcp endpoint doesn't exist yet)