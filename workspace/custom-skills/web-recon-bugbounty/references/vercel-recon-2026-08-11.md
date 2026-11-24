# Vercel.com Recon — August 11, 2026

## Target
- **Domain:** vercel.com
- **Program:** HackerOne Vercel Open Source / Vercel
- **Disclosure:** responsible.disclosure@vercel.com
- **Security page:** https://security.vercel.com/
- **Security.txt:** https://vercel.com/.well-known/security.txt (contact: HackerOne + email)

## Tech Stack
- **Framework:** Next.js (Turbopack — `turbopack-14c-f19uy8sjo.js`)
- **Server:** Vercel (vercel.com) / Cloudflare (auth.vercel.com)
- **Bot protection:** Kasada/DataDome — protects `/signup`, `/oauth/authorize`, `/oauth/device`, `/teams/connect`, `/api/front-domains/checkpoint`, `/functions/sales-email`
- **Deployment ID:** `dpl_CNtJpF5C8YvVMh7cignuHTpwfo9S`
- **ISR cache:** precomputed (x-matched-path contains JWT-like cache keys)
- **DNS TXT services:** Google Workspace, Stripe, OpenAI, Anthropic, Notion, Loom, Whimsical, DoorDash, DocuSign, Carta, Apple, Zoom, Salesforce, A/B testing tools

## Key Subdomains
| Subdomain | Status | Notes |
|-----------|--------|-------|
| vercel.com | 200 | Next.js SPA, Vercel-hosted |
| api.vercel.com | 308 → docs | REST API, auth-protected |
| auth.vercel.com | 200 | Behind Cloudflare, JSON response |
| admin.vercel.com | 302 → SSO | Vercel SSO redirect |
| checkout.vercel.com | 204 | Empty response |
| community.vercel.com | 403 | Blocked |
| assets.vercel.com | 200 | Static assets |
| cdn*.vercel.com | 404 | Not active |
| conf-feature-flags.vercel.com | — | Feature flag service (did not test) |

## Security Posture Assessment

### Strong (no findings)
- **HSTS:** max-age=31536000; includeSubDomains; preload ✓
- **X-Frame-Options:** DENY ✓
- **X-Content-Type-Options:** nosniff ✓
- **Cookies:** Secure, HttpOnly, SameSite=Lax (SSO nonce) ✓
- **TRACE:** blocked ✓
- **API auth:** all endpoints require Bearer token (403 with `missingToken: true`) ✓
- **No .git/.env exposure:** SPA shell returns for all paths, not actual files ✓
- **No open redirects:** all redirect params tested, return 200 ✓
- **No subdomain takeover:** all CDN subs return 404 ✓
- **No host header injection:** Host header not reflected ✓
- **No GraphQL introspection:** /graphql returns 404 ✓
- **No well-known endpoints:** all return 404 ✓
- **No MCP endpoints:** all return 404 ✓

### Weak (informational only)
- **CSP:** `unsafe-eval` + `unsafe-inline` — weak but no XSS found to exploit
- **CORS:** `Access-Control-Allow-Origin: *` on vercel.com and api.vercel.com (no credentials, informational only)
- **X-Powered-By:** `Next.js, Payload` — info disclosure (low)
- **Server:** `Vercel` — info disclosure (low)
- **x-matched-path:** reveals ISR cache structure (informational)
- **Deployment ID:** `dpl_CNtJpF5C8YvVMh7cignuHTpwfo9S` in HTML (informational)

### Multi-Infrastructure Observation
auth.vercel.com is behind Cloudflare while vercel.com is on Vercel's own infra. Different `server:` headers, different CSPs. This is a normal multi-CDN architecture but worth noting for future hunts — the Cloudflare-protected endpoints may have different security behavior.

## Lessons Learned

### 1. Next.js SPA False Positive Trap
Every sensitive path scan returned 200 because the Next.js SPA catches all routes. The `.git/HEAD 200`, `.env 200`, `actuator/health 200` results were all false positives — the response body was just the SPA shell HTML. This is a CRITICAL pitfall that was added to the web-recon-bugbounty skill's Common False Positives section.

### 2. Well-Secured Platform Outcome
Vercel is their own platform — they eat their own dogfood. Their security posture is excellent:
- Proper auth on all API endpoints
- Bot protection on sensitive endpoints
- Strong security headers
- No exposed sensitive paths
- No subdomain takeover surface
- Different infra per service (Cloudflare for auth, Vercel for main)

### 3. What Would Find Bugs Here?
- **Authenticated testing:** IDOR, BOLA, privilege escalation — all require login
- **Race conditions:** on team/project creation, billing, or deployment
- **SSRF:** via webhook URLs, image import, or deployment URL validation
- **CI/CD:** GitHub Actions workflow analysis on vercel/vercel repo
- **Source code audit:** vercel/vercel is partially open-source
- **Business logic:** billing, usage limits, deployment quotas

### 4. Time Investment
~30 minutes of surface recon. No HIGH/CRITICAL findings from unauthenticated surface scan. This is expected for a tier-1 audited platform. Further testing would require authenticated access and deeper source code review.

## Recon Commands Used

```bash
# Headers + security posture
curl -sI -H "Origin: https://evil.com" https://vercel.com/

# DNS TXT (supply chain map)
dig +short TXT vercel.com

# Subdomain enum
curl -s "https://api.hackertarget.com/hostsearch/?q=vercel.com" | cut -d',' -f1 | sort -u

# Sensitive path scan (with body verification!)
curl -s https://vercel.com/.git/HEAD | head -1  # SPA shell = false positive

# CORS test
curl -sI -H "Origin: https://evil.com" https://api.vercel.com/v2/domains/vercel.com

# API auth check
curl -s https://api.vercel.com/v2/user  # returns 403 missingToken

# Security.txt
curl -s https://vercel.com/.well-known/security.txt

# Bot protection analysis (in-page JS)
curl -s https://vercel.com/ | grep -o 'protect.*paths'  # reveals protected endpoints
```