# Multi-Target Web Bug Bounty Hunting Workflow

## Session: 2026-07-31 — 7 Targets in One Session

### Targets Tested
| Target | Findings | Severity | Status |
|--------|----------|----------|--------|
| atmail.com | Good security, Cloudflare WAF | None | Pivot |
| aurasell.ai | PostHog key exposure | Low | Submitted ($5) |
| boldcommerce.com | Good security, Kong gateway | None | Pivot |
| zoho.com/crm | Excellent security, OAuth2 | None | Pivot |
| manageengine.com | CORS wildcard | Low | Investigating |
| opencollective.com | GraphQL introspection, API keys | Low-Medium | Paused (bounty paused until Aug 31) |
| blockpi.network | CORS wildcard, internal services | Low-Medium | Report ready |
| telegram.org | Excellent security | None | Pivot |

### Key Findings Pattern
1. **PostHog/Analytics API Key Exposure** — Check HTML source for `posthog.init('phc_...')`. Project key allows event injection + /decide/ config leak.
2. **Hidden Pages in sitemap.xml** — Check `/hidden-pages/*`, `/form-test`, `/internal/*`. Often accessible 200 OK with no auth.
3. **CORS Wildcard (`Access-Control-Allow-Origin: *`)** — Common on marketing sites. NOT exploitable for credential theft (browser blocks wildcard+credentials). Low severity.
4. **Auth0/OAuth2 Flow** — Check `/authorize`, `/oauth/token`, `/userinfo` endpoints. Properly configured = all return 401/302.
5. **GraphQL Introspection** — Check `/graphql` with `{ __schema { types { name } } }`. Full schema exposure = Medium severity.
6. **Internal Services Exposed** — Check CSP headers for internal URLs (hub.nimbly.blockpi.org, ai-assistant.blockpi.org).
7. **Build Paths Leaked** — Check `__NEXT_DATA__` or `__NUXT_DATA__` for `/opt/buildhome/repo/...` paths.

### Tech Stack Fingerprinting Quick Wins
- **Webflow sites** → Check sitemap.xml for hidden pages, form-test endpoints
- **Auth0** → Check client_id in HTML, test /authorize flow
- **Kong API Gateway** → Responses have `x-kong-request-id` header, `{"message":"no Route matched"}` for invalid routes
- **APISIX** → Responses have `x-apisix-*` headers
- **Zoho (ZGS server)** → Check `Server: ZGS` header, CORS often wildcard
- **Nuxt.js** → Check `__NUXT_DATA__` for config exposure
- **Next.js** → Check `__NEXT_DATA__` for runtime config, build ID

### Recon Checklist for SaaS Targets
```
□ Check robots.txt for sensitive paths (/admin/, /api/, /internal/)
□ Check sitemap.xml for hidden pages
□ Check .well-known/security.txt for bug bounty contact
□ Check HTML source for analytics keys (PostHog, Segment, Mixpanel)
□ Check CORS headers with evil origin
□ Check API subdomain (api.target.com) separately from www
□ Check for demo/staging instances (demo.target.com)
□ Check OAuth endpoints (/authorize, /token, /userinfo)
□ Check for exposed tracking IDs (LinkedIn, RE B2B, etc.)
□ Check __NEXT_DATA__ or __NUXT_DATA__ for config exposure
□ Check CSP headers for internal service URLs
□ Check for exposed build paths (/opt/buildhome/repo/...)
```

### Pitfall: CORS Wildcard vs Origin Reflection
- `Access-Control-Allow-Origin: *` = wildcard, NOT exploitable with credentials
- `Access-Control-Allow-Origin: https://evil.com` (reflected) = exploitable
- Always test with `credentials: include` to confirm exploitability
- Wildcard CORS is Low severity, reflected CORS is Medium-High

### Pitfall: Bounty Program Status
- Always check if bounty program is ACTIVE before spending hours
- Open Collective: paused July 1 - Aug 31, 2026
- Check `security.txt` for program status
- Check Immunefi page for program status

### Pitfall: RPC Service vs DeFi Protocol
- RPC services (BlockPI, Alchemy, Infura) don't hold user funds → no fund theft potential
- Target actual DeFi protocols (lending, bridge, DEX) for fund theft bugs
- Use DefiLlama TVL data to identify high-value targets

### Report Format Preference
User prefers **plain text** in chat, not markdown files. For bug bounty reports:
- Paste report content directly in chat
- Include subject line for email submission
- Keep PoC as curl one-liners
- Don't create .md files unless explicitly asked

### Autonomous Decision-Making
User explicitly requested:
- "lu pilih bro jgn nunggu aku" = you choose, don't wait for me
- "cri bug ajA" = just find bugs, any bugs
- "kirim siji aja" = send just the text, not files

When user says these, execute immediately without asking for confirmation.
