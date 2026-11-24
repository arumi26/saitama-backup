---
skill: mfa-bypass
title: "MFA / 2FA Bypass"
category: "Security · Auth"
load_when: "Any login enforcing MFA/OTP/2FA."
pack: SUPERAGENT V10
bughunt: true
---
# MFA / 2FA Bypass

## Where it pays
Turns a password leak into full access.

## Signals
Post-MFA endpoints; OTP submit; remember-device cookie.

## Methodology
1. Flow skip (hit post-MFA resource directly).
2. Response tampering (mfa:false).
3. OTP brute / batching; reuse/no-expiry/race.
4. Backup-code; disable-MFA via IDOR; forge trusted-device.

## Validation gate
Reach the authenticated area without a valid second factor.

## Impact & chains
**ATO** (with creds) or standalone bypass.

**→ next on hit: `../phases/04-chain.md`.**
