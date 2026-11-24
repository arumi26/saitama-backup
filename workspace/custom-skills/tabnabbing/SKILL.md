---
skill: tabnabbing
title: "Reverse Tabnabbing"
category: "Security · Web"
load_when: "tabnabbing, reverse tabnabbing, window.opener, target blank, noopener, opener redirect"
pack: SUPERAGENT V10
bughunt: true
---

# Reverse Tabnabbing

## Where it pays
A link opened with target=_blank (without rel=noopener) lets the new page redirect the *original* tab to a phishing clone — credential theft.

## Attack-surface signals
User-supplied links rendered with `target=_blank` and no `rel=noopener noreferrer`; comments, profiles, markdown that renders links.

## Methodology
1. Find a `target=_blank` link missing `rel=noopener`. 2. From the opened page, use `window.opener.location = phishing`. 3. Victim returns to the original tab → sees a convincing fake login. 4. Confirm the opener redirect works.

## Payloads / probes
```
<a href=https://attacker target=_blank>link</a>
// on attacker page:
if (window.opener) window.opener.location = 'https://phish.clone/login'
```

## Root causes
Links open with window.opener access because rel=noopener is missing.

## Validation gate
Show the original tab being redirected by the opened page (opener access confirmed).

## Impact & chains
Phishing / credential theft via the trusted original tab. Chains with open-redirect.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "tabnabbing, reverse tabnabbing, window.opener, target blank, noopener, opener redirect"
```

→ Report with `../reporting/writeup.md` (CWE-1022); validate with `../reporting/validation-gate.md`.
