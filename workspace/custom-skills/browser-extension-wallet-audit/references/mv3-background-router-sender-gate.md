# MV3 background-router sender gate — the seed-leak make-or-break check

The single most important question when auditing an MV3 wallet extension for a
**recovery-phrase / private-key leak** (the highest-paying class): can a privileged
handler that exports secrets be reached from a **content script injected on an
attacker page**, or is it gated to the **extension UI** (`popup.html` / `prompt.html`)?

## The pattern (Glow - Solana Wallet BETA v0.61.0, Luma Labs, Aug 2026)

Layout: `realms/{content,inpage,background}.js` + `pages/{popup,onboarding,prompt}.js`.
Manifest MV3, `permissions:[storage,tabs,alarms,webNavigation]`, **no** `host_permissions`,
**no** `externally_connectable` (good — page can't message background directly),
content_scripts match `https://*/*`, web_accessible_resources = `realms/inpage.js`.

Two distinct message channels — do not conflate them:

1. **dApp channel** (page → content → background), the one a malicious website controls:
   - `inpage.js` defines `window.glow`; dApp calls `window.postMessage({__glow_request})`.
   - `content.js` listens and forwards via **exactly one** method:
     `C4.sendInpageRequest({request, requester:{url:document.location.href,...}})`.
   - background `sI` handler validates the **Chrome-set** `sender.url` / `sender.tab.id`
     (`n.url`, NOT the page-supplied `requester.url`), requires `checkDappConnected`
     for everything except `connect`/`signIn`, then opens `prompt.html` for user approval.
   - Verdict: tight. A dApp can only reach connect/sign-with-prompt. The 30+ other
     privileged methods on the content-script schema are **never invoked from
     page-reachable code** — they're schema definitions, not live entry points.

2. **Extension-UI channel** (`__glow_background_request`): background does
   `runtime.onMessage.addListener((t,e)=>{ if(!t.__glow_background_request) return;
   return qY[t.type](t.payload, e) })`. `qY` includes `getPhraseForAccountDangerously`,
   `getPrivateKey`, `getPhraseAndAccounts`, `importPhrase`, etc.

## The check that decides severity

`getPhraseForAccountDangerously` (alias `kI`) exports the **full seed phrase** and,
unlike `getPrivateKey`/`getPhraseAndAccounts` which take a `password` arg, it calls
`Ir()` = `getTempPassword()` — the **cached unlock password, no re-prompt**. So the
seed is one `qY['getPhraseForAccountDangerously']` call away for anyone who can hit the
router while the wallet is unlocked.

Make-or-break: **does the `qY` router validate `sender`?** In a correct build, either
(a) `content.js` never sends `__glow_background_request` for these types, AND
(b) the router checks `e.url === runtime.getURL("popup.html"/"onboarding.html")` or
`e.origin === chrome-extension://<id>` before running secret-export handlers.
Note Glow's `aI` (getPromptInfo) DOES gate: `if(e.url!==runtime.getURL("prompt.html")) throw`.
If the secret-export handlers have **no equivalent sender gate** and content.js can be
coerced into sending that message type → **critical seed leak**. If content.js only ever
sends `sendInpageRequest` and the router is only reachable from extension pages → safe.

## Repro method (static, no install)
- Grep `content.js` for every `C4.<method>(` actually CALLED (not just schema-defined):
  `grep -oE 'C4\.[A-Za-z]+\(' content.js | sort -u`. If only `sendInpageRequest` →
  page can't reach the privileged router through the content script.
- Grep the router: find `runtime.onMessage.addListener` in background, read whether the
  handler inspects the second arg (`sender`) `.url`/`.origin`/`.tab` before dispatch.
- Compare secret handlers (`getPhrase*`, `getPrivateKey`) password source: literal
  `password` arg (needs re-auth) vs `getTempPassword()`/`Ir()` (cached — silent if
  reachable). Silent + reachable-from-page = critical; silent + UI-only = expected.

## Honest triage
A seed-export handler using cached temp-password is **normal and safe** when it is only
reachable from the extension's own UI (the user already unlocked; the UI showing their
own seed is by design). It becomes a finding ONLY if you can drive that exact handler
from an attacker-controlled context (content script on any page, web_accessible_resource
framed by an attacker, or a missing sender gate on the router). Prove the reachability
before writing "seed leak" — otherwise it's an invalid report.
