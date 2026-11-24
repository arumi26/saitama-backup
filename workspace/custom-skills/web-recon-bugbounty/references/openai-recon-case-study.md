# OpenAI Bug Bounty — Passive Recon Case Study (July 2026)

## Target
- **Domains:** *.openai.com, api.openai.com, platform.openai.com, chat.openai.com
- **Bugcrowd:** https://bugcrowd.com/openai (active since 2023-04-11, pay-for-success)
- **PGP Contact:** disclosure@openai.com, key at https://cdn.openai.com/security/disclosure.asc.pub

## crt.sh Failure — Fallback Chain That Worked

crt.sh returned HTTP 000 (complete timeout) after 60s on `https://crt.sh/?q=%25.openai.com&output=json`.

Working fallback sequence:
1. **HackerTarget hostsearch API** — `https://api.hackertarget.com/hostsearch/?q=openai.com` — returned 51 subdomains with IPs
2. **Google DNS-over-HTTPS** — batch-resolve `https://dns.google/resolve?name={sub}.openai.com&type=A` for common sub names (platform, auth, playground, etc.)
3. **Wayback Machine** — `https://web.archive.org/cdx/search/cdx?url=*.openai.com/*&output=json&collapse=urlkey&fl=original&limit=500` — though it returned 429 this time

HackerTarget was the primary win — it returns `subdomain,IP` pairs directly, no JSON parsing required:
```bash
curl -s "https://api.hackertarget.com/hostsearch/?q=openai.com" | cut -d',' -f1 | sort -u
```

## Subdomains Discovered (51+)

### Key categories found:

**Regional API gateways (Cloudflare):**
ae, au, beta, ca, eu, gb, in, jp, kr, sg, gov — all regional API endpoints

**Internal named services (Cloudflare, revealing names):**
- `nori.api.openai.com` + `nori-webhooks.api.openai.com`
- `sevbot.api.openai.com` (severity/incident bot)
- `sonata.api.openai.com`
- `transceiver.api.openai.com`
- `sip.api.openai.com`
- `openhouse.api.openai.com`
- `develocity.api.openai.com`
- `agentgarden.api.openai.com`
- `ci-webhooks.api.openai.com`
- `observability-webhook.api.openai.com`
- `gtm-innovation.api.openai.com`

**Azure-backed infrastructure (NOT behind Cloudflare — potential origin bypass):**
- `*.unified-0.api.openai.com` → 4.150.21.186 (Azure)
- `*.unified-1.api.openai.com` → 20.225.171.111 (Azure)
- `*.unified-2.api.openai.com` → 4.151.241.6 (Azure)
- `edge.unified-164.api.openai.com` → 70.153.151.184
- `responsesapi-cert-publisher.gateway-passthrough.unified-0.api.openai.com` → 13.65.2.22

These bypass Cloudflare entirely — direct Azure IPs. Priority targets for further investigation.

**Non-Cloudflare public subdomains:**
- `alignment.openai.com` → 64.239.109.129 (Google Cloud)
- `community.openai.com` → 184.105.99.79 (Hurricane Electric)
- `developers.openai.com` → 64.239.109.129 (Vercel/Google Cloud)
- `status.openai.com` → 76.76.21.123 (Vercel, powered by incident.io)

## Bugcrowd Scope Extraction Technique

The Bugcrowd program page at `bugcrowd.com/openai` is a React SPA. The scope/brief is embedded in HTML as escaped JSON inside `data-*` attributes.

### Extraction approach:
```python
import re, html, json

raw = open('bugcrowd_openai.html').read()

# Find large data attributes — they contain the full brief JSON
for match in re.finditer(r'data-[a-z-]+="([^"]{2000,})"', raw):
    val = html.unescape(match.group(1))
    if 'scope' in val.lower() or 'target' in val.lower():
        try:
            data = json.loads(val)
            # The 'description' field contains the full HTML brief
            desc = data.get('earlyFetchProps', {}).get('description', '')
            # Strip HTML tags to get plain text
            clean = re.sub(r'<[^>]+>', '\n', desc)
        except:
            pass
```

### API endpoints also discoverable from page_source:
- `/engagements/openai/scope_ranks` — returns `{"scopeRank":3}`
- `/engagements/openai/changelog/{UUID}` — full brief version document
- `/engagements/openai/hall_of_fames.json` — hall of fame submissions
- `/engagements/openai/recently_joined_users.json`

### OpenAI Out-of-Scope items (explicitly stated):
- Model safety issues (jailbreaks, DAN prompts)
- Sandboxed Python code execution (code interpreter)
- Agent Mode sandbox code execution
- Container Tool Sandbox (GPT-5 models, root in gVisor)
- Model content/issues (getting model to say bad things)
- Model hallucinations

## DNS TXT Records — Third-Party Service Intelligence

Google DoH query for TXT records revealed extensive third-party tools:
```
curl -s "https://dns.google/resolve?name=openai.com&type=TXT"
```

Services enumerated from TXT:
- **Identity/MDM:** Google Workspace (MX+SPF), Microsoft 365, JAMF (device mgmt), Tailscale (VPN)
- **Dev:** Docker, Postman, GitHub, Atlassian, Figma, Linear, Whimsical
- **Marketing/Sales:** HubSpot, Marketo, Oracle Cloud, Canva, Wrike, Miro, Smartsheet
- **Payments:** Stripe, Uber (corporate? domain verification)
- **Comms:** Zoom, Twilio, Notion, Dropbox, Calendly, Airtable, Box
- **Security:** HIBP (Have I Been Pwned), OneTrust (privacy)
- **Cloud:** Google Workspace, Oracle Cloud, Azure DNS

These reveal the supply chain surface — each third-party is potential for:
- SSO/OAuth misconfiguration
- Supply chain compromise
- Social engineering targets
- Subdomain takeover (if any service probeilites a CNAME)

## CORS Findings on api.openai.com

Origin reflection pattern observed — different endpoints have different CORS policies:

| Endpoint | ACAO | Assessment |
|----------|------|------------|
| `/v1/models` (OPTIONS) | `*` (wildcard) | All origins, all methods |
| `/v1/chat/completions` (OPTIONS) | Reflects any Origin | No ACA-Credentials header |
| `/v1/files` (OPTIONS) | Reflects any Origin | No ACA-Credentials header |

**Assessment:** Origin reflection is likely intentional — OpenAI API is designed for browser-based calls with Bearer token auth (API key in header). No ACA-Credentials means cookie-based exfiltration is not possible. The BYO API key auth model mitigates the CORS risk.

**But:** If any OpenAI web property ever passes API keys via cookies or uses session-based auth on these endpoints, this would become exploitable. Worth re-testing with authenticated requests.

Test command:
```bash
curl -s -X OPTIONS "https://api.openai.com/v1/chat/completions" \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: POST" \
  -D - -o /dev/null
```

## HTTP Headers Summary

### api.openai.com custom headers (info disclosure):
- `openai-version: 2020-10-01` — API version
- `openai-processing-ms: 2` — processing time
- `x-openai-proxy-wasm: v0.1` — proxy WASM module version
- `x-request-id: <UUID>` — per-request UUID
- `www-authenticate: Bearer realm="OpenAI API"`

### platform.openai.com (Cloudflare challenge, 403):
- Full COEP/COOP/CORP/permissions-policy headers
- HSTS with preload
- **No CSP visible** — likely injected post-challenge (after browser passes Cloudflare's JS check)

### developers.openai.com (Vercel, 200):
- HSTS: max-age=63072000 (2 years)
- **No CSP, no X-Frame-Options** — most lenient headers of all OpenAI properties

## robots.txt as Authenticated Endpoint Map

platform.openai.com/robots.txt reveals auth-gated feature paths:
```
Disallow: /settings/*
Disallow: /finetune/*
Disallow: /assistants/*
Disallow: /threads/*
Disallow: /batches/*
Disallow: /usage/*
Disallow: /api-keys/*
Disallow: /chat-completions/*
Disallow: /evaluations/*
```

These are not vulnerabilities on their own, but they map the authenticated surface area. Combined with auth bypass or IDOR research, these are the direct paths to test.

## JS File Analysis

### Files analyzed:
- `developers.openai.com` — Astro framework (Vercel), loads `cdn.platform.openai.com/deployments/chatkit/chatkit.js`
- `status.openai.com` — Next.js (Vercel), deploy ID `dpl_J2tBijW4mBTv9Bckq81vjPVe9Jey`, powered by incident.io
- `chatkit.js` (26KB) — no leaked secrets, endpoints, or env vars

**No secrets found** in any accessible JS files. Strong security posture.

## Cloudflare Challenge — JS Bundle Access Limitation

`platform.openai.com` and `chatgpt.com` both return HTTP 403 with a Cloudflare JS challenge page to curl requests. This means:
- Cannot analyze client-side JS bundles via curl
- Cannot see the real CSP header (injected after challenge passes)
- Need a browser with JS execution capability to get past the challenge

The Cloudflare challenge page itself has good security headers (COEP, COOP, permissions-policy) but no CSP — the real CSP is only visible after the browser passes the challenge.
