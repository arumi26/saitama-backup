# Google Dorking Cheatsheet — Web Bug Bounty

Categorized dorks for surfacing exposed files, panels, APIs, and secrets on an
**in-scope** target. Dorking is the *second* step — recon first (subdomains, live
hosts, URL harvest) so you know what surface to dork and which hostnames exist.

## Order of operations

```bash
# 1. Subdomains → dork surface
subfinder -d TARGET.com -silent > subs.txt
httpx -l subs.txt -sc -title -tech-detect -o live.txt

# 2. Historical + crawled URLs (params, old endpoints)
gau TARGET.com > urls.txt
katana -u https://TARGET.com -d 3 -jc -o crawl.txt

# 3. THEN dork (site: against confirmed hostnames — not blind)
```

Dorking a hostname that isn't confirmed live wastes queries. Harvest first, then
dork `site:` scoped to the real hosts.

## Dorks by category

| Category | Dork |
|---|---|
| **Exposed files** | `site:TARGET.com filetype:env` |
| | `site:TARGET.com filetype:sql OR filetype:bak OR filetype:old` |
| | `site:TARGET.com ext:log OR ext:txt "password"` |
| | `site:TARGET.com filetype:json OR filetype:xml OR filetype:yml` |
| **Panels / listings** | `site:TARGET.com inurl:admin OR inurl:login OR inurl:dashboard` |
| | `site:TARGET.com intitle:"index of"` |
| | `site:TARGET.com intitle:"index of" ".env"` |
| **API / dev / staging** | `site:TARGET.com inurl:api OR inurl:swagger OR inurl:graphql` |
| | `site:TARGET.com inurl:dev OR inurl:staging OR inurl:test` |
| | `site:TARGET.com inurl:api-docs OR inurl:openapi.json` |
| **Secrets in JS / HTML** | `site:TARGET.com "api_key" OR "secret" OR "token"` |
| | `site:TARGET.com "client_secret" OR "private_key"` |
| **Params (injection surface)** | `site:TARGET.com inurl:?id= OR inurl:?file= OR inurl:?url=` |
| | `site:TARGET.com inurl:?redirect= OR inurl:?next=` |
| **GitHub leak** | `site:github.com "TARGET" "api_key" OR "client_secret"` |
| | `site:github.com "TARGET" "password" OR "token"` |
| **Paste sites** | `site:pastebin.com "TARGET" "key"` |

## Provider regex patterns (validate hits found in any source)

| Provider | Pattern |
|---|---|
| AWS Access Key | `AKIA[0-9A-Z]{16}` |
| Stripe Live | `sk_live_[0-9a-zA-Z]{24}` |
| Google API | `AIza[0-9A-Za-z-_]{35}` |
| GitHub PAT | `ghp_[0-9a-zA-Z]{36}` |
| Slack | `xox[baprs]-[0-9a-zA-Z]{10,48}` |
| RSA key | `-----BEGIN RSA PRIVATE KEY-----` |

## Automated scanner

`~/dork_scanner.py` runs a dork list + fetches each hit + regex-matches the
provider patterns above, writing `api_key_leaks.json` / `.csv`.

**Requires** (env vars, not hardcoded):
```bash
export GOOGLE_API_KEY='xxx'   # from Google Cloud Console
export GOOGLE_SE_ID='xxx'     # CX from https://programmablesearchengine.google.com/
                              #   → "Search the entire web" enabled
```
Without both set the script exits early with a reminder — set them once and it
runs unattended. Google Custom Search free tier = 100 queries/day.

## Validation before reporting (mandatory)

A "leak" is only real if all three hold:
1. **Key is live** — test against the provider API (`curl -s https://api.stripe.com/v1/balance -u sk_live_xxx:`, `gh api user -H "Authorization: token ghp_xxx"`, etc.)
2. **Belongs to the target** — not a vendor/integrator key, not a test/example key
3. **In scope** — the bounty program covers the service the key accesses

A version banner or an `index of` listing alone is NOT submittable.

## Pitfalls

- **SPA false positives** — React/Vue SPAs return 200 with identical HTML for `/.env`, `/.git/HEAD`. Compare response sizes across paths; identical body = SPA fallback, not a leak.
- **Kill signal** — 30+ dorks / 10 minutes with 0 results → target has no exposed creds yet; move on.
- **Expired paste keys** — always verify liveness before reporting.
- **Scope** — dork only hosts the program actually authorizes; a leak on an out-of-scope hostname is not a finding.
