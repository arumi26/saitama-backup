---
skill: session
title: "Session Management"
category: "Security · Auth"
load_when: "After any login; audit session lifecycle."
pack: SUPERAGENT V10
bughunt: true
---
# Session Management

## Where it pays
Session theft/persistence = ATO.

## Signals
Cookie flags; session id; logout/reset behavior; tokens in URLs.

## Methodology
1. Flags (Secure/HttpOnly/SameSite/Domain).
2. Fixation (id change on login?).
3. Rotation on priv/password change.
4. Invalidation after logout/reset (replay old).
5. Predictable/short tokens; URL leakage.

## Validation gate
A session that should be dead still works, or fixation/theft grants access.

## Impact & chains
**ATO**, persistent post-termination access (chains with soft-delete IDOR).

**→ next on hit: `../phases/04-chain.md`.**
