---
skill: dom-clobbering
title: "DOM Clobbering"
category: "Security · Web"
load_when: "dom clobbering, clobbering, named element, html injection, getElementById override, window property override"
pack: SUPERAGENT V10
bughunt: true
---

# DOM Clobbering

## Where it pays
When you can inject HTML (but scripts are sanitized), named elements can clobber JS variables/DOM APIs → bypass logic or escalate to XSS.

## Attack-surface signals
HTML injection sinks where <script> is blocked but `id`/`name` attributes survive (sanitizers like DOMPurify default); code reading `window.x` / `document.x`.

## Methodology
1. Find an HTML-injection sink that keeps `id`/`name`. 2. Clobber a variable the app reads (`<a id=config>`, `<form name=x>`). 3. Point a sink (script src, redirect, innerHTML) at attacker value. 4. Chain to XSS or logic bypass.

## Payloads / probes
```
<a id=config href="javascript:alert(1)"></a>
<form name=x><input name=y></form>   // window.x.y
<a id=x><a id=x name=y href=evil>   // array clobber
```

## Root causes
Code trusts global DOM properties that can be shadowed by named HTML elements; sanitizer allows id/name.

## Validation gate
Show a clobbered variable changing app behavior (sink pointed at attacker value) or resulting XSS.

## Impact & chains
Logic bypass, XSS (via clobbered sink), redirect. Chains with web/xss and prototype-pollution.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "dom clobbering, clobbering, named element, html injection, getElementById override, window property override"
```

→ Report with `../reporting/writeup.md` (CWE-79); validate with `../reporting/validation-gate.md`.
