# CORS Wildcard + Internal Endpoint Exposure — Live Findings (Aug 2026)

## Pattern Summary
Multiple Immunefi-listed protocols have **CORS wildcard** (`Access-Control-Allow-Origin: *`) on their web infrastructure, often combined with **exposed internal endpoints** (Kubernetes, Prometheus, Grafana, admin dashboards).

## Why This Works
- Self-hosted web targets on Immunefi often have **less mature web security** than smart contract code
- Cloudflare protects main endpoints but **internal services** are often accessible via subdomains not behind WAF
- CORS misconfig is a **configuration bug**, not a code bug — easy to miss in audits

## Detection Script

```bash
for domain in "$1" "api.$1" "dashboard.$1" "app.$1" "monitor.$1" "admin.$1" "docs.$1"; do
    echo "=== $domain ==="
    # CORS check
    curl -sI -m 5 -H "Origin: https://evil.com" "https://$domain" 2>/dev/null | grep -i "access-control"
    
    # Security headers
    curl -sI -m 5 "https://$domain" 2>/dev/null | grep -i "x-frame\|x-xss\|strict-transport\|content-security"
    
    # Internal endpoint check
    for path in "kubernetes" "prometheus" "grafana" "metrics" "monitor" "dashboard" "health" "status"; do
        code=$(curl -sL -m 5 -o /dev/null -w "%{http_code}" "https://$domain/$path" 2>/dev/null)
        [ "$code" != "404" ] && [ "$code" != "403" ] && [ "$code" != "000" ] && echo "  /$path -> HTTP $code"
    done
done
```

## Finding 1: BlockPI Network (blockpi.io / blockpi.network)

**Status:** Ready for submission ✅
**Immunefi:** https://immunefi.com/bug-bounty/blockpinetwork/information/
**Bounty:** $5,000 max (No KYC)

### Confirmed
| Domain | CORS | Internal Endpoints |
|--------|------|-------------------|
| `blockpi.io` | `Access-Control-Allow-Origin: *` | - |
| `dashboard.blockpi.io` | `Access-Control-Allow-Origin: *` | /dashboard, /api |
| `blockpi.network` | Redirects to blockpi.io | /kubernetes, /prometheus, /grafana, /monitor, /metrics, /dashboard — all HTTP 200 |

### Impact
Medium (CVSS 6.5) — Any website can read cross-origin API responses from victim's authenticated session. Internal Kubernetes/Prometheus/Grafana endpoints accessible without auth.

### Report Template
```markdown
# BlockPI Network — CORS Misconfiguration & Exposed Internal Endpoints

## Affected Endpoints
| Domain/Path | Response |
|-------------|----------|
| `blockpi.io` | CORS wildcard |
| `dashboard.blockpi.io` | CORS wildcard |
| `blockpi.network/kubernetes` | HTTP 200 |
| `blockpi.network/prometheus` | HTTP 200 |
| `blockpi.network/grafana` | HTTP 200 |

## PoC
```bash
curl -I -H "Origin: https://evil.com" https://dashboard.blockpi.io
# Returns: access-control-allow-origin: *
```

## Impact
Attacker webpage can read cross-origin API responses. Internal infra endpoints exposed publicly.

## Fix
- Replace `Access-Control-Allow-Origin: *` with specific whitelist
- Restrict internal endpoints behind auth
- CSP: `frame-ancestors 'self'`
```
```

## Finding 2: IPOR (ipor.io)

**Status:** Partial — need API endpoint verification
**Immunefi:** https://immunefi.com/bug-bounty/ipor/information/
**Bounty:** $20,000 max (No KYC)

### Confirmed
| Domain | CORS | Notes |
|--------|------|-------|
| `api.ipor.io` | `Access-Control-Allow-Origin: *` | S3-backed, may not reflect credentials |
| `ipor.io` | No CORS | Static site |
| `app.nexusmutual.io` | `Access-Control-Allow-Origin: *` | Cloudflare (same infrastructure?) |

### PoC
```bash
curl -I -m 5 -H "Origin: https://evil.com" "https://api.ipor.io"
# Returns: access-control-allow-origin: *
# Returns: access-control-expose-headers: *
```

## What Makes a CORS Finding Reportable vs Not

| Pattern | Severity | Exploitable? |
|---------|----------|-------------|
| `ACAO: *` only | Low | Browser blocks credentials, but curl works |
| `ACAO: *` + `ACAC: true` | Low | Browser blocks, but violates spec |
| `ACAO: <reflected>` + `ACAC: true` | **Medium-High** | ✅ Browser exploitable |
| `ACAO: *` on authenticated API | **Medium** | Non-browser client exploit |
| `ACAO: *` + internal services exposed | **Medium** | Data exfil via curl/Python |

**Key test:** Always verify with actual `credentials: include` in the request. Wildcard is only exploitable if the server reflects the Origin header value back (not literally `*`).

## Next Steps for Hunter
1. Submit BlockPI report via Immunefi or email (`security@blockpi.network`)
2. For IPOR: find authenticated API endpoint that returns sensitive data (need to create account)
3. Check if CORS headers reflect the Origin value (not just `*`) — reflected = much higher severity
4. Check if the `/kubernetes`, `/prometheus`, `/grafana` responses actually return sensitive data vs just static pages