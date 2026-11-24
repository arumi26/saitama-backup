---
skill: csrf
title: "CSRF"
category: "Security · Web Exploitation"
load_when: "Cookie-authed state-changing request without strong anti-CSRF."
pack: SUPERAGENT V10
bughunt: true
---
# CSRF

## Where it pays
Account modification, fund transfer, settings takeover when protection is weak.

## Attack-surface signals
State-changing POST using only cookie auth; weak SameSite; JSON endpoints accepting form content-type.

## Methodology
1. Find cookie-only state changes.
2. Check token/SameSite/origin/custom-header defenses.
3. Remove/alter/swap token; empty token?
4. Build auto-submit PoC; test content-type switch to dodge preflight.

## Payloads
```
<form action=https://t/account/email method=POST><input name=email value=attacker@evil></form><script>document.forms[0].submit()</script>
```
See `../payloads/` and `../core/chaining.md`.

## Root causes
No/predictable token · token not session-bound · SameSite=None w/o token · GET state change · JSON accepts form.

## Bypasses
Method override · content-type switch · token leak via referer · SameSite top-level nav.

## Validation gate
Action executes cross-site against a logged-in victim, no interaction beyond visiting your page.

## Impact & chains
email change + reset → **ATO**; combine with reflected XSS to steal a present token.

**→ next on hit: `../phases/04-chain.md`.**
