---
skill: web-cache-deception
title: "Web Cache Deception"
category: "Security · Web"
load_when: "web cache deception, cache deception, path confusion cache, cached private page, .css suffix cache"
pack: SUPERAGENT V10
bughunt: true
---

# Web Cache Deception

## Where it pays
Tricking a cache into storing a victim's *private* page under a static-looking URL, then reading it yourself — leaks personal data/tokens.

## Attack-surface signals
CDN/cache in front of authenticated pages; caches keyed on extension/path; `/account` reachable as `/account/x.css`.

## Methodology
1. Find an authenticated page (`/account`). 2. Append a cacheable suffix the cache stores but the app ignores (`/account/nonexistent.css`). 3. Victim visits the crafted URL → their private response is cached. 4. You fetch the same URL unauthenticated and read their data.

## Payloads / probes
```
https://target/account/profile.css
https://target/settings/x.jpg
https://target/api/me/;.css
https://target/account%0a.css
```

## Root causes
Cache stores responses by extension/path while the origin ignores the suffix; cacheable auth'd responses.

## Validation gate
Show a victim's private response served to you from cache via the crafted static-looking URL.

## Impact & chains
PII/token theft, session data leak. Chains with web/cache-poison and auth/session.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "web cache deception, cache deception, path confusion cache, cached private page, .css suffix cache"
```

→ Report with `../reporting/writeup.md` (CWE-525); validate with `../reporting/validation-gate.md`.
