---
skill: clickjacking
title: "Clickjacking / UI Redress"
category: "Security · Web"
load_when: "clickjacking, ui redress, iframe, x-frame-options, frame-busting, csp frame-ancestors, drag-drop"
pack: SUPERAGENT V10
bughunt: true
---

# Clickjacking / UI Redress

## Where it pays
Framing a sensitive action and tricking a victim into clicking it. Low-to-medium, but pays when it reaches a state-changing action (delete account, transfer, grant).

## Attack-surface signals
Pages without `X-Frame-Options` / `CSP: frame-ancestors` that contain one-click sensitive actions (settings, OAuth consent, money, admin).

## Methodology
1. Check framing headers on sensitive pages (XFO / frame-ancestors). 2. Build a PoC that iframes the page with opacity + a decoy button over the real action. 3. Confirm the click lands on the real target. 4. Chain: drag-and-drop data theft, or clickjack an OAuth 'authorize'.

## Payloads / probes
```
<style>iframe{opacity:.0001;position:absolute;z-index:2}</style>
<div>Click to win</div><iframe src=https://target/settings/delete></iframe>
```

## Root causes
Missing/weak framing protection on state-changing pages; relying on SameSite alone.

## Validation gate
Show the victim clicking a decoy and triggering the real sensitive action in your PoC. A framed static page is not impact.

## Impact & chains
Forced sensitive actions, OAuth consent hijack, account deletion. Chains with csrf and oauth.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "clickjacking, ui redress, iframe, x-frame-options, frame-busting, csp frame-ancestors, drag-drop"
```

→ Report with `../reporting/writeup.md` (CWE-1021); validate with `../reporting/validation-gate.md`.
