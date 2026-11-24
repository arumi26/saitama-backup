---
skill: race-condition
title: "Race Conditions"
category: "Security · Web Exploitation"
load_when: "Any limited/idempotency-sensitive action (redeem/withdraw/vote/coupon)."
pack: SUPERAGENT V10
bughunt: true
---
# Race Conditions

## Where it pays
Double-spend, multi-redeem single-use, bypass one-per-account.

## Attack-surface signals
redeem/withdraw/vote/apply-coupon/submit-once endpoints.

## Methodology
1. Find check-then-act on shared state.
2. Fire parallel requests (single-packet) in a tight window.
3. Observe over-execution.

## Payloads
```
Turbo Intruder single-packet; or async fan-out of 30 identical POSTs
```
Pairs with `business-logic.md`.

## Root causes
Non-atomic check-then-update · missing DB lock/unique constraint · idempotency key not enforced.

## Bypasses
Parallel send · single-packet attack.

## Validation gate
Show the limit broken (coupon applied N times) reproducibly.

## Impact & chains
financial double-spend · quota bypass.

**→ next on hit: `../phases/04-chain.md`.**
