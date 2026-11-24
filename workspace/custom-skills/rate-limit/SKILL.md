---
skill: rate-limit
title: "Rate Limiting & Resource Abuse"
category: "Security · API"
load_when: "Login/OTP/reset/invite/coupon and expensive endpoints (API4)."
pack: SUPERAGENT V10
bughunt: true
---
# Rate Limiting & Resource Abuse

## Where it pays
Enables brute (→ATO), enumeration, scraping, flow abuse.

## Signals
No lockout/CAPTCHA on sensitive endpoints; batchable OTP.

## Methodology
1. Rapid-fire; is there a cap?
2. Bypass: rotate X-Forwarded-For, casing, GraphQL batching, new session.
3. OTP/reset brute; expensive ops (bounded, no real DoS).

## Validation gate
Exceed intended limits; ideally show a consequence (code guessed).

## Impact & chains
OTP/password brute → **ATO** · enumeration · coupon/referral → financial.

**→ next on hit: `../phases/04-chain.md`.**
