# Real-World Bug Hunting — Yaworski Methodology (2019)

Key techniques from Peter Yaworski's "Real-World Bug Hunting: A Field Guide to Web Hacking" (430 pages, 20 chapters, 50+ real HackerOne/Bugcrowd case studies).

## Core Methodology (Chapter 19: Finding Your Own Bug Bounties)

1. **Reconnaissance first** — subdomain enumeration, GitHub dorking, JS analysis
2. **Test the application** — register accounts, map all features, proxy all traffic
3. **Go further** — automation, chaining, escalation

## Bug Classes by Chapter

| Chapter | Class | Key Technique |
|---------|-------|---------------|
| 2 | Open Redirect | `?redirect=`, `?next=`, interstitial bypass |
| 3 | HTTP Parameter Pollution | Server-side vs client-side HPP |
| 4 | CSRF | GET vs POST, token bypass, content-type tricks |
| 5 | HTML Injection | Character encoding bypass |
| 7 | XSS | Stored, reflected, DOM, blind |
| 8 | Template Injection | SSTI (Jinja2, Smarty, AngularJS), CSTI |
| 9 | SQL Injection | Blind, time-based, error-based |
| 10 | SSRF | Cloud metadata (169.254.169.254), internal port scan, DNS |
| 11 | XXE | File read, OOB via DTD, .docx/.xlsx/.gpx files |
| 12 | RCE | Shell commands, function execution, ImageMagick |
| 14 | Subdomain Takeover | CNAME to unclaimed services |
| 15 | Race Condition | Background jobs, limit bypass, TOCTOU |
| 16 | IDOR | Integer IDs, UUIDs, leaked IDs |
| 17 | OAuth | redirect_uri, state bypass, token theft |
| 18 | Logic/Config | Privilege bypass, 2FA bypass, S3 permissions |

## Key Case Studies (applicable to DeFi/Web3)

1. **Shopify Partners Race Condition ($15,250)** — Email verification TOCTOU → account takeover
2. **HackerOne Payments Race Condition ($1,000)** — Background job PayPal dup
3. **Twitter Mopub IDOR ($5,040)** — API key leak via POST response
4. **Google XXE ($10,000)** — XML upload to Toolbar gallery
5. **Facebook XXE ($6,300)** — .docx file with malicious DTD
6. **Uber Jinja2 SSTI** — Flask template injection
7. **Binary.com IDOR ($300)** — iFrame parameter manipulation

## Application to DeFi Targets

- **Race conditions** → Staking limits, claim windows, withdrawal timers
- **IDOR** → Wallet-based endpoints where wallet address IS the ID
- **SSRF** → Webhook endpoints, price feed URLs, RPC endpoints
- **CSRF** → POST endpoints without signature verification
- **Subdomain takeover** → Dead CNAMEs from old deployments

## Live Session Results — Across.to (2026-08-11)

Applied all 18 chapters to across.to (DeFi bridge, $37B volume, $1M max bounty):

| Chapter | Result |
|---------|--------|
| 2-18 | ALL NOT VULNERABLE — Vercel + Cloudflare + proper validation |
| Findings | CORS: * on 4 domains, CSP report-only, testnet public, legacy v1 |

**Key lessons:**
- Battle-tested protocols (Across, Lido, Aave, Uniswap) rarely yield web exploits
- CORS: * is the most common finding on Vercel-hosted APIs
- CSP report-only is common for Next.js apps (allows unsafe-eval/inline)
- `.well-known/security.txt` scanning is the fastest way to find email-submission programs
- The book's methodology works best on SaaS/web apps, not DeFi smart contract protocols

## Yaworski's Reporting Rules (Chapter 20)

1. Read the policy first
2. Include details, then include more
3. Reconfirm the vulnerability
4. Your reputation matters
5. Show respect for the company
6. Appeal bounty rewards if warranted