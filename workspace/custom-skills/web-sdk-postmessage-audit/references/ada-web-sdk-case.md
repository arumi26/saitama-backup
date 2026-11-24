# Worked case — Ada Web SDK v1.0.0 (missing postMessage origin validation)

Non-destructive source audit + local PoC. Target VDP-only (no bounty). Reported to `security@ada.com`.

## Artifact
- `https://api.mobile.ada.com/ada-web-sdk/ada-web-sdk.js` (in-scope: `*.ada.com` per Ada VDP)
- SHA-256 `abb5f9500e6021a2b20ff0668cdd7c5cfa2676d13f81eb6bcea4bf730fabe22a`, version string `1.0.0`
- Discovery: `api.mobile.ada.com/` root 403 via Cloudflare WAF, but `launch-web-sdk.html` returned **200** (Express) — that loader referenced the SDK. One open path on an otherwise-WAF'd host is the entry point.

## Root cause (exact minified path)
```js
window.addEventListener("message", this.onMessage.bind(this));   // no origin check anywhere

onMessage = function (e) {
  var t = e.data;
  switch (t.type) {
    case "REQUEST_MODULE_INITIATION":      this._controller.initiateModule(t.source, t.payload); break;
    case "REQUEST_MODULE_TRANSITION":      this._controller.moduleTransition(t.source, t.payload); break;
    case "ACTION_CONFIGURE_LOCALIZATIONS": this._controller.updateModuleProperties(t.source, {capabilities:{configureLocalizations:t.payload}}); break;
    case "EVENT_RESIZED":                  var n=t.payload; this._controller.setSize(n.width,n.height); break;
    case "EVENT_SCROLL_TOP":               this._controller && this._controller.scrollIntoView(); break;
    case "ACTION_CLOSE_WINDOW":            this._controller.onAssessmentDialogClosing(); break;
    case "ACTION_REDIRECT_TOP":            this.redirectTop(e.origin, t.payload.redirectTo); break;   // ONLY case that checks origin
    case "COMMAND_REDIRECT_TOP":           this.redirectTop(e.origin, t.redirectTo); break;
    case "ACTION_COPY_TO_CLIPBOARD":       navigator.clipboard.writeText(t.payload.content); break;
    case "ACTION_PUBLISH_VALUE":           this.onDataReceived(t.payload);
  }
}

// module ctor — no validation of n.module
xt = function(){ function e(e,t,n){ ... this.moduleUrl = null==n?void 0:n.module; ... } }

// transition — untrusted payload -> module
moduleTransition = function(e,t){ ... new xt(this.config, this.userInteractionMonitor, {module: t.module, ...}) }

// allowlist, used ONLY by redirectTop — correct leading dots
var Le = [".ada.com", ".adahealth.ca", "localhost"];
```
Sink: `Module.url` getter returns `moduleUrl` → assessment iframe `src = module.url`.
Secondary unvalidated handlers (same root cause): clipboard write, `onDataReceived` spoof, forced close/resize.

## PoC result (headless Chromium, cross-origin 8001 → 8000)
```html
<iframe id="ada-web-sdk-assessment-iframe"
        src="http://127.0.0.1:8001/evil.html"
        title="Symptom Assessment" aria-label="Symptom Assessment"></iframe>
```
Attacker server log:
```
"GET /evil.html HTTP/1.1" 200 -              # fetched
"GET /beacon?from=evil-iframe HTTP/1.1"      # executed (beacon fired)
```
Independent read-back via browser tool:
```json
[{"id":"","src":"http://127.0.0.1:8001/attacker.html"},
 {"id":"ada-web-sdk-assessment-iframe","src":"http://127.0.0.1:8001/evil.html","title":"Symptom Assessment"}]
```

## Honest triage
- **Claimed**: cross-origin content injection into a trusted medical widget (UI redressing / phishing); clipboard hijack; forged `onDataReceived`; forced close/resize. **High**, not Critical.
- **NOT claimed**: account takeover. The SDK's own init message (`RESPONSE_MODULE_INITIATION`) carries only public config (`customizationId`, `trackingId`, `origin`, `launch`, `iss`, version) — no token. Verified by grepping every `postMessage(` send.
- **Precondition stated**: requires a cross-origin frame on the embedding page (standard for an embeddable SDK).

## Payout reality (checked first, not after)
Ada's VDP: **requesting a reward violates policy** → no monetary payout. It also lists *"API Token / OAuth secret recoverable in application binaries"* as **out of scope** (a hardcoded basic-auth string found in the APK earlier was therefore dead). Always read the VDP out-of-scope list before building the report.
