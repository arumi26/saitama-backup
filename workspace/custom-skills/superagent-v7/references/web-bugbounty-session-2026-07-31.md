# Web Bug Bounty Session — 2026-07-31

Targets hunted: aurasell.ai, manageengine.com, zoho.com/crm, atmail.com, boldcommerce.com

## Findings Summary

### aurasell.ai (Submitted - $5 Low)
- PostHog API key exposed in HTML: `phc_ETxM5Ygs10rUYTlCOm63zycXmB1hTo7v9tmWmSzbfns`
- Can inject fake events via `/capture/` endpoint
- Can get project config via `/decide/` endpoint
- Hidden pages accessible: `/hidden-pages/*`, `/form-test`
- Report submitted to security@aurasell.ai

### manageengine.com (CORS - Low)
- `Access-Control-Allow-Origin: *` on all endpoints
- NOT exploitable with credentials (browser blocks wildcard+creds)
- Desktop Central API documented at `/products/desktop-central/api/`
- Zoho bug bounty: security@zohocorp.com, $3K max Critical

### zoho.com/crm (No findings)
- Excellent security, OAuth2 authentication
- All API endpoints require authentication
- Well-documented API at zohoapis.com/crm/v2/

### atmail.com (No findings)
- Cloudflare WAF blocking most attacks
- WordPress with Yoast SEO, properly secured

### boldcommerce.com (No findings)
- Kong API gateway properly configured
- All API endpoints behind OAuth2

## Tech Stack Fingerprinting

| Stack | Identifying Headers | Notes |
|-------|-------------------|-------|
| Webflow | `x-wf-region`, `surrogate-key` | Check sitemap for hidden pages |
| Auth0 | `x-auth0-requestid`, `x-auth0-l` | Check client_id in HTML |
| Kong | `x-kong-request-id`, `x-kong-response-latency` | `{"message":"no Route matched"}` |
| APISIX | `x-apisix-*` headers | OpenResty-based |
| Zoho (ZGS) | `Server: ZGS`, `nimbus-id` | CORS often wildcard |

## Self-Hosted Program Payouts

| Program | Contact | Max (Critical) |
|---------|---------|----------------|
| Zoho/ManageEngine | security@zohocorp.com | $3,000 |
| Aurasell | security@aurasell.ai | $1,000 |
| Telegram | security@telegram.org | $100,000 |
| Proton | security@proton.me | $10,000 |
| Kraken | bugbounty@kraken.com | $100,000 |

## User Preferences (Bug Bounty)
- Reports in plain text chat, not .md files
- Pick targets without asking (auto-decide)
- Pivot quickly when no findings (don't burn hours)
- Self-hosted programs preferred (less competition)
