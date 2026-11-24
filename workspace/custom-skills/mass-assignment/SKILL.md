---
skill: mass-assignment
title: "Mass Assignment & Excessive Data Exposure"
category: "Security · API"
load_when: "Any create/update endpoint + any JSON response (API3)."
pack: SUPERAGENT V10
bughunt: true
---
# Mass Assignment & Excessive Data Exposure

## Where it pays
Priv-esc with one extra field; PII leak from over-sharing responses.

## Signals
POST/PUT/PATCH bodies; fat JSON responses with internal fields.

## Methodology
1. Add fields UI never sends: role=admin, isVerified=true, userId=other.
2. Confirm persisted.
3. Read raw JSON for passwordHash/ssn/tokens/other-user fields.

## Validation gate
Show the privileged field persisted, or sensitive fields returned.

## Impact & chains
role=admin → **priv-esc** · userId swap → cross-tenant write · exposed token → **ATO**.

**→ next on hit: `../phases/04-chain.md`.**
