---
skill: xs-leak
title: "XS-Leaks (Cross-Site Leaks)"
category: "Security · Web"
load_when: "xs-leak, cross-site leak, xsleak, timing attack, frame counting, cache probing, cross-origin leak, status code oracle"
pack: SUPERAGENT V10
bughunt: true
---

# XS-Leaks (Cross-Site Leaks)

## Where it pays
Side-channels that leak cross-origin state (are you logged in? is X true for you?) via timing, frame counts, cache, or error events — privacy-impacting.

## Attack-surface signals
Authenticated apps with per-user responses, search that reflects account state, endpoints whose behavior differs by user/permission.

## Methodology
1. Pick an oracle: response timing, `frame.length`, cache timing, status-code via error events, size via Content-Length. 2. Build a cross-origin page that measures the oracle for the victim's session. 3. Infer a boolean (is-admin, has-item, search-hit). 4. Amplify to extract data bit-by-bit.

## Payloads / probes
```
// frame-count oracle
win = open('https://target/search?q=secret'); win.frames.length
// cache-probe + timing
// error-event oracle on <img>/<script> onload/onerror
```

## Root causes
No cross-origin isolation (COOP/COEP/CORP); cacheable per-user responses; observable cross-origin differences.

## Validation gate
Show a reproducible cross-origin inference of victim-specific state (e.g. determine a boolean about the logged-in victim).

## Impact & chains
Privacy leak, deanonymization, data inference. Chains with web/cache-poison and auth/session.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "xs-leak, cross-site leak, xsleak, timing attack, frame counting, cache probing, cross-origin leak, status code oracle"
```

→ Report with `../reporting/writeup.md` (CWE-203); validate with `../reporting/validation-gate.md`.
