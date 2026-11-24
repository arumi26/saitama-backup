# Edel Finance Security Audit Case Study (2026-07-16)

## Target
- Main site: `https://runway.edel.finance/desk`
- API: `https://api.edel.finance`
- Assets: `https://assets.edel.finance`
- Docs: `https://docs.edel.finance`
- Markets: `https://markets.edel.finance` (401)

## Infrastructure
- Frontend: Next.js on Vercel
- API: Fastify on Cloudflare
- Assets: Google Cloud Storage
- Docs: Static site on Vercel

## Findings Summary

### HIGH: CORS Misconfiguration on API
```bash
curl -sI -H "Origin: https://malicious.site" https://api.edel.finance/health | grep access-control
# Result: access-control-allow-origin: https://malicious.site
```
API reflects ANY origin in CORS headers. Allows cross-origin API key theft.

### HIGH: GCS Bucket Public Listing
```bash
curl -s https://assets.edel.finance/ | head -50
```
Exposed:
- `docs/edel-finance-audit-report-2026-03-26.pdf` (7.1MB)
- `docs/2026-01-14-White-paper-Edel-FFG-R2MQ3JKN7.xhtml` (530KB)
- All stock/token branding assets
- Full directory structure

### HIGH: Swagger UI Publicly Accessible
```bash
curl -s https://api.edel.finance/docs | head -20
curl -s https://api.edel.finance/docs/json | head -100
```
Full OpenAPI spec exposed, including:
- All endpoints (`/api/v1/stocks`, `/api/v1/tokens`, `/api/v1/keys`)
- Auth mechanism (`x-api-key` header, `apiKey` query param)
- Three scopes: admin, read, write

### MEDIUM: No Rate Limiting
```bash
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}" "https://api.edel.finance/health"
done
# All return 200
```

### MEDIUM: Information Disclosure
```bash
curl -s https://api.edel.finance/health
# {"status":"ok","uptimeSeconds":1433327,"timestamp":"2026-07-16T13:50:00.007Z"}
```

### MEDIUM: Missing Security Headers
```bash
curl -sI https://runway.edel.finance/desk | grep -iE "(x-frame|content-security|referrer-policy)"
# Returns: EMPTY
```
Missing: CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy

### LOW: Fastify Framework Leaked
```bash
curl -s -X POST -H "Content-Type: application/json" -d 'invalid' "https://api.edel.finance/api/v1/keys"
# {"code":"FST_ERR_CTP_INVALID_JSON_BODY",...}
```

### LOW: Vercel Deployment ID Exposed
```bash
curl -s https://runway.edel.finance/desk | grep -o 'dpl_[A-Za-z0-9]*'
# dpl_GSR8A8G6xm5X1mdKZq8zT6ZwxU59
```

### INFO: Contract Addresses (Public)
```json
{
  "Base": "0xFb31f85A8367210B2e4Ed2360D2dA9Dc2D2Ccc95",
  "Ethereum": "0xbf59dbc154421a7b37f4f2841e11f4ed2a1dee7c",
  "BSC": "0xbf59dbc154421a7b37f4f2841e11f4ed2a1dee7c",
  "Solana": "5g6wVay8NYQ5Tspo4irj9YqSFfQoPDW7apkX352N29PP"
}
```

### INFO: Subdomain Enumeration Results
| Subdomain | Status | Notes |
|-----------|--------|-------|
| api.edel.finance | 404/200 | Cloudflare, Fastify API |
| app.edel.finance | 404 | Vercel, DEPLOYMENT_NOT_FOUND |
| assets.edel.finance | 200 | GCS bucket, public listing |
| docs.edel.finance | 200 | Documentation site |
| markets.edel.finance | 401 | Exists, requires auth |

## Lessons Learned
1. **GCS buckets on `assets.*` subdomains** — Common pattern for static asset hosting
2. **Fastify/NestJS Swagger at `/docs`** — Not `/swagger-ui.html`
3. **CORS on Cloudflare-backed APIs** — May reflect origins if not configured
4. **Vercel security checkpoint** — Blocks curl to JS chunks, first request may be cached
5. **RSC payload in Next.js 13+** — New info leak vector replacing `__NEXT_DATA__`
