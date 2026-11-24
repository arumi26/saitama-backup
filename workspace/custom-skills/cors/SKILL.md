---
skill: cors
title: "CORS Misconfiguration"
category: "Security · Web Exploitation"
load_when: "Any API returning sensitive data with CORS headers."
pack: SUPERAGENT V10
bughunt: true
---
# CORS Misconfiguration

## Where it pays
Steal authed JSON (PII/tokens) from any user who visits your page.

## Attack-surface signals
ACAO reflects arbitrary Origin + ACAC true; ACAO null + creds; weak origin regex.

## Methodology
1. Send Origin: evil.com; inspect ACAO/ACAC.
2. Dangerous combos (reflect+creds, null+creds).
3. fetch(...,{credentials:'include'}) PoC that reads+exfils.

## Payloads
```
curl -s -H 'Origin: https://evil.com' -I https://t/api/me | grep -i access-control
```
See `../core/chaining.md`.

## Root causes
Reflecting Origin into ACAO with credentials · trusting null · substring/regex origin checks.

## Bypasses
null origin via sandboxed iframe · subdomain-takeover trusted origin.

## Validation gate
Read victim-specific authed data cross-origin. Reflected ACAO without creds/sensitive data is informational.

## Impact & chains
data/token theft → **ATO**; pairs with takeover + XSS.

**→ next on hit: `../phases/04-chain.md`.**
