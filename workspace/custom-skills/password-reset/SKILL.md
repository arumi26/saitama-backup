---
skill: password-reset
title: "Password Reset"
category: "Security · Auth"
load_when: "Any forgot-password/reset/recovery flow."
pack: SUPERAGENT V10
bughunt: true
---
# Password Reset

## Where it pays
Direct, often unauthenticated path to ATO.

## Signals
Reset link building; token entropy; email/userId in request.

## Methodology
1. Host-header poisoning (link uses your Host?).
2. Token predictable/reusable/no-expiry/not-single-use.
3. Leak via referer; email-change race.
4. No invalidation; tamper email/userId; IDOR on reset.

## Validation gate
Take over an account you don't own via the reset flow (your test victim).

## Impact & chains
**ATO**, sometimes mass; chains with email-change IDOR + MFA bypass.

**→ next on hit: `../phases/04-chain.md`.**
