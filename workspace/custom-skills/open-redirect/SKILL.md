---
skill: open-redirect
title: "Open Redirect"
category: "Security · Web Exploitation"
load_when: "Any redirect param (next/redirect/url/return/callback)."
pack: SUPERAGENT V10
bughunt: true
---
# Open Redirect

## Where it pays
Low alone; powerful connector: OAuth token theft, filter/SSRF bypass, phishing.

## Attack-surface signals
next=/redirect=/url=/return=/continue=; OAuth redirect_uri; SAML RelayState.

## Methodology
1. Set to //evil.com, https:evil.com, /\evil.com, @evil.com.
2. Bypass naive checks.
3. Check OAuth/SSO usage.

## Payloads
```
?next=//evil.com
?return=https://target.com@evil.com
```
See `../auth/oauth.md`.

## Root causes
Redirect to user URL without allowlist · weak host parsing.

## Bypasses
//, /%2f/, target.com.evil.com, @-userinfo, CRLF, backslash.

## Validation gate
Browser lands on your external domain.

## Impact & chains
OAuth redirect_uri=open-redirect → code/token to attacker → **ATO**; SSRF filter bypass.

**→ next on hit: `../phases/04-chain.md`.**
