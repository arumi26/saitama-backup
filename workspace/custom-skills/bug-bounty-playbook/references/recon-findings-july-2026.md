# Recon Findings — July 2026 Bug Bounty Session

## Session Summary
Hunted 3 targets: atmail.com, aurasell.ai, boldcommerce.com
Findings: Low/Informational only — all targets had good security

## Target Assessment

### atmail.com (Independent, $5K max)
- **Tech**: WordPress + Yoast SEO, Cloudflare WAF
- **Security**: GOOD — Cloudflare blocking most attacks
- **Findings**: None (proper security)
- **Lesson**: Cloudflare WAF effectively blocks .env/.git/wp-admin

### aurasell.ai (Independent, $1K max)
- **Tech**: Webflow + AWS + Auth0 + APISIX
- **Security**: GOOD — Auth0 properly protects API
- **Findings**: PostHog key exposure (Low), hidden pages (Info)
- **Lesson**: Auth0 OAuth2 + PKCE is properly configured

### boldcommerce.com (Independent, $5K max)
- **Tech**: SPA + Kong API Gateway + Cloudflare
- **Security**: GOOD — Kong properly routes API
- **Findings**: None (proper security)
- **Lesson**: SPA routing returns same HTML for all paths

## Common Findings

### PostHog Project API Key Exposure (Low)
- **What**: PostHog project API key exposed in HTML/JS
- **Can do**: Send events via `POST /capture/`, get feature flags via `POST /decide/`
- **Cannot do**: Read data (project key, not personal API key)
- **Severity**: Low (analytics pollution, not data exposure)
- **PoC**: `curl -X POST "https://us.i.posthog.com/capture/" -d '{"api_key":"phc_...","event":"fake"}'`

### Webflow Hidden Pages Accessible (Informational)
- **What**: `/hidden-pages/*` paths return 200 OK on Webflow sites
- **Impact**: Information disclosure only (test pages, unused sections)
- **Severity**: Informational
- **Check**: `/hidden-pages/unused-section`, `/hidden-pages/home-new`, `/form-test`

### Kong API Gateway Fingerprinting
- **What**: Kong returns `{"message":"no Route matched with those values","request_id":"..."}` for unmatched routes
- **Use**: Fingerprint API gateway technology
- **Headers**: `x-kong-request-id`, `x-kong-response-latency`

### SPA Frontend Routing (NOT a vulnerability)
- **What**: All routes return same HTML page (200 OK) for SPAs
- **Mistake**: Don't report as "all endpoints accessible" — it's just frontend routing
- **Check**: Response content-type (text/html = SPA, application/json = real API)

### Auth0 OAuth2 Properly Configured
- **What**: Auth0 properly protects API endpoints with OAuth2 + PKCE
- **Token endpoint**: Requires valid credentials (returns "Unauthorized" without)
- **UserInfo endpoint**: Requires valid token (returns "Unauthorized" without)
- **Don't report**: Auth0 endpoints returning 401 is proper behavior

## Key Lessons
1. **Cloudflare WAF is effective** — blocks .env, .git, wp-admin, most attacks
2. **Auth0 OAuth2 is properly configured** — token/userinfo endpoints require valid credentials
3. **Kong API gateway fingerprints** — returns specific JSON for unmatched routes
4. **SPA routing is not a vulnerability** — all routes return same HTML (frontend routing)
5. **PostHog project keys are low severity** — can send events but not read data

## Target Discovery Resources
- `lissy93/bug-bounties` repo — 3,000+ programs, YAML format
- `karemelsqary/self-hosted-bug-bounty-programs` repo — 36 self-hosted programs with contacts
- HackerOne "self-hosted" filter
- Bugcrowd "private" programs
