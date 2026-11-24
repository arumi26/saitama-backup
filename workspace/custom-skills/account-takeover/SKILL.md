---
skill: account-takeover
title: "Account Takeover (ATO)"
category: "Security · Auth"
load_when: "account takeover, ato, account hijack, pre-account takeover, email change, password reset takeover, oauth takeover, session takeover"
pack: SUPERAGENT V10
bughunt: true
---

# Account Takeover (ATO)

## Where it pays
ATO is the crown jewel of bounty impact — demonstrating control of another user's account is almost always Critical/High. It's a *goal* reached by chaining smaller flaws.

## Attack-surface signals
Password reset, email/phone change, OAuth/social login, "magic link", session handling, MFA, account merge/linking, invitation flows, support-side impersonation.

## Methodology (routes to ATO)
1. **Password reset abuse:** host-header poisoning (reset link to your domain), token leakage/reuse, predictable tokens, no-expiry, reset-token in response/referrer. (see auth/password-reset)
2. **Email change without re-auth / no verification** → set victim email, reset, own account.
3. **Pre-account takeover:** register with victim's email before they do (OAuth auto-link), then they sign in via social → shared account.
4. **OAuth:** redirect_uri/state abuse, account-linking confusion, email trust. (see auth/oauth)
5. **IDOR on profile/email/phone endpoints** → change victim's recovery data. (see web/idor)
6. **MFA bypass / response manipulation** on the auth flow. (see auth/mfa-bypass)
7. **JWT forgery / weak session** → mint a victim session. (see auth/jwt, auth/session)
8. **Response manipulation:** change `"success":false`→`true`, status 401→200 on login/OTP.

## Payloads / probes
```
# host-header poisoning on reset
POST /reset  Host: attacker.com   (link emailed points to attacker.com)
# pre-ATO: register victim@target before they OAuth-login
# OTP/response tamper
{"verified":true}   200 vs 403 swap
# recovery IDOR
PATCH /api/users/{VICTIM_ID}  {"email":"me@attacker.com"}
```

## Root causes
Recovery/identity changes not re-authenticated or verified · trusting the Host header · OAuth email auto-linking · object-level authz missing on profile endpoints · client-trusted auth decisions.

## Validation gate
Demonstrate authenticated control of an account you don't own — ideally two test accounts (your "victim" B taken over from attacker A), with victim data redacted.

## Impact & chains
Full account control, data theft, fraud. This skill is the *orchestrator* — it pulls password-reset, oauth, idor, jwt, mfa-bypass, session into one chain (see core/chaining).

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "account takeover via password reset"
python3 ../../../tools/report_builder.py --class oauth --asset "auth.example.com" --impact "Full ATO via reset host-header poisoning"
```

→ Report with `../reporting/writeup.md`; validate with `../reporting/validation-gate.md`.
