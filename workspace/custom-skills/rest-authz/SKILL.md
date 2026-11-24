---
skill: rest-authz
title: "REST Authorization (BOLA/BFLA)"
category: "Security · API"
load_when: "Any REST API with ids or role-gated functions (API1/API5)."
pack: SUPERAGENT V10
bughunt: true
---
# REST Authorization (BOLA/BFLA)

## Where it pays
Top-2 API classes: cross-tenant data + privileged functions.

## Signals
/api/v*/{id}; /admin/*; method-sensitive routes.

## Methodology
1. A/B accounts + Autorize (A token on B request → expect 403).
2. BOLA: swap ids all verbs.
3. BFLA: low-priv hits admin; swap GET→PUT/DELETE.
4. Header bypass: X-Original-URL, X-Forwarded-*.

## Validation gate
Prove access/action B's privilege should forbid, with before/after state.

## Impact & chains
cross-tenant read/write · vertical priv-esc; combine with mass-assignment.

**→ next on hit: `../phases/04-chain.md`.**
