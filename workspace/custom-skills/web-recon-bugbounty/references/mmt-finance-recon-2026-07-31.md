# MMT Finance Recon Case Study (July 2026)

## Target: Momentum DEX (mmt.finance)
- **Chain**: Sui (Move VM)
- **Infra**: Vercel (Next.js 15 Turbopack) + Cloudflare + Express.js API
- **Bounty**: Immunefi redirect exists (/bug-bounty/mmt/) but page renders __next_error — program may be inactive/paused

## Attack Surface Mapping

### Subdomains Discovered (from JS bundle analysis)
| Subdomain | Tech | Purpose |
|-----------|------|---------|
| www.mmt.finance | Next.js + Vercel | Marketing site |
| app.mmt.finance | Next.js + Vercel (Turbopack, dpl_*) | DEX frontend |
| api.mmt.finance | Express.js + Cloudflare | Public API |
| api-dev.mmt.finance | Express.js (same as prod) | Dev API (identical) |
| docs.mmt.finance | GitBook | Documentation |
| lifi.mmt.finance | Next.js + Vercel | LI.FI bridge integration |
| squid.mmt.finance | Next.js + Vercel | Squid Router bridge |
| wormhole.mmt.finance | Next.js + Vercel (separate DPL) | Wormhole bridge |
| sui-mainnet-blockpi-{1,2,3}.grpc.mmt.finance | gRPC | Sui RPC nodes |

### API Endpoints (from Swagger UI inline spec)
Discovered via `curl -sL https://api.mmt.finance/swagger/swagger-ui-init.js` — the OpenAPI 3.1.0 spec is inlined in the JS, not at a separate JSON endpoint.

9 endpoints, 0 authentication:
- GET /v3 — all V3 pools
- GET /v3/{poolId} — specific pool
- GET /v3/{poolId}/volume — 24h volume
- GET /v3/rewarders-apy/{poolId} — rewarders + APY
- GET /api/tick-liquidity/{poolId} — tick data with pagination
- GET /api/tick-liquidity/{poolId}/range — tick range data
- GET /tokens — all tokens (name, ticker, price, volume, decimals)
- GET /tokens/{coinType} — token by Sui type string
- POST /tokens/batch — batch token lookup

12 schemas exposed including V3PoolWithStats (poolId, reserves, TVL, volume, APY, rewarders)

## Findings

### 1. CORS Misconfiguration (MEDIUM-HIGH)
Both `api.mmt.finance` and `api-dev.mmt.finance` return:
```
access-control-allow-origin: *
access-control-allow-credentials: true
access-control-allow-methods: GET,POST,PUT,DELETE
```
Tested with 5 origins (evil.com, null, subdomain tricks) — all accepted.

### 2. Swagger UI Exposed in Production (MEDIUM)
`/swagger` returns full Swagger UI on BOTH prod and dev. The init JS contains the complete OpenAPI spec inline.

### 3. Internal Metrics Endpoint (LOW-MEDIUM)
`GET /metrics` returns daily swap volume data, database record IDs, and timestamps without auth.

### 4. Sentry DSN Leaked (LOW)
`https://***@o4508203984289792.ingest.us.sentry.io/4510435168878592`
Found in app.mmt.finance JS chunk. Auth-gated for API access. Can submit fake events.

### 5. Dev API Identical to Production (LOW-MEDIUM)
`api-dev.mmt.finance` has identical swagger, endpoints, data, and CORS issues.

### 6. No Rate Limiting (LOW)
20 rapid requests all 200 OK. Batch endpoint accepts arrays without validation.

## Negative Results (Properly Secured)
- S3 bucket `momentum-statics.s3.us-west-1.amazonaws.com` — Access Denied
- `.env`, `.git/config`, `.git/HEAD` — 403 (Cloudflare WAF)
- SSTI/SQLi/NoSQLi on poolId/coinType — no injection sinks
- POST/PUT/DELETE on /metrics — all blocked
- SSRF via coinType — no backend fetch
- Next.js cache poisoning (x-matched-path, x-now-route-matches, x-prerender-revalidate) — not processed
- GraphQL — not implemented
- Open redirect — no redirect endpoints found
- XSS reflection in Next.js app — Cloudflare blocks (403)

## Techniques Used
1. **Vercel DPL ID extraction**: `grep -oP 'dpl_[A-Za-z0-9]+'` from HTML
2. **JS chunk API URL extraction**: grep all chunks for `https?://[a-z0-9.-]+\.mmt\.finance`
3. **Swagger UI init JS extraction**: Full OpenAPI spec parsed from `swagger-ui-init.js`
4. **Cloudflare challenge bypass attempts**: Correct headers (UA, Origin, Referer, sec-ch-ua) — still blocked on /v3
5. **Sui RPC deprecation discovery**: JSON-RPC returns migration message pointing to gRPC/GraphQL
6. **Wormhole subdomain discovery**: `wormhole.mmt.finance` found in JS (not in crt.sh)

## Open Items
- V3 pools endpoint blocked by Cloudflare — need browser/Playwright to get valid poolIds
- Sui smart contract audit pending (Move contracts on-chain)
- Immunefi bounty page status unclear (Next.js error page)
