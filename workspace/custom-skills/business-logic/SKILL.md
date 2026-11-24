---
skill: business-logic
title: "Business Logic"
category: "Security · Web Exploitation"
load_when: "Any multi-step flow, pricing, quotas, permissions, state machine."
pack: SUPERAGENT V10
bughunt: true
---
# Business Logic

## Where it pays
High-value, low-competition. Payments/permissions/workflows.

## Attack-surface signals
Checkout, coupons, invites, approvals, tenant boundaries, upgrade flows.

## Methodology
1. Model intended flow + invariants.
2. Attack each: price/quantity (negative/zero/overflow/currency), workflow order (skip/replay/out-of-order), quotas, state confusion (refund-after-use), tenant isolation.
3. Combine with race (hunt-race-condition).

## Payloads
```
amount=-100  ·  apply expired invite  ·  replay upgrade webhook
```
See `../web/race-condition.md`.

## Root causes
Non-atomic checks · trusting client amounts/ids · no server-side invariant enforcement.

## Bypasses
Out-of-order requests · parameter tampering · webhook replay.

## Validation gate
Show a concrete gain (money/access/resource) the flow was built to prevent.

## Impact & chains
financial loss · priv-esc · free premium · cross-tenant compromise.

**→ next on hit: `../phases/04-chain.md`.**
