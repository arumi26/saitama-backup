---
skill: idor
title: "IDOR / BOLA"
category: "Security · Web Exploitation"
load_when: "Any endpoint referencing an object by id/uuid/slug — the #1 class."
pack: SUPERAGENT V10
bughunt: true
---
# IDOR / BOLA

## Where it pays
Direct cross-user data access; chains to ATO/financial/priv-esc. Best on multi-tenant SaaS, fintech, social, dev tools.

## Attack-surface signals
`/api/v*/users/{id}`, `/invoices?id=`, `node(id:)`, `?user_id= ?org_id=`; sequential ints, leaked UUIDs.

## Methodology
1. Two same-priv accounts (A owner, B attacker).
2. Collect A's object ids; replay with B's session, all verbs.
3. Test cross-tenant/org and write/destructive ops.
4. GraphQL: substitute ids in every query/mutation arg.
5. Indirect refs, HPP (?id=mine&id=victim), param variants.

## Payloads
```
GET /api/invoices/12345  (A's id, B's session)
ffuf -u https://t/api/orders/FUZZ -w ids.txt -H 'Authorization: Bearer B' -mc 200
```
More: `../payloads/idor.txt`.

## Root causes
ORM fetch without userId scope · route-level auth, no object check · trusting client org_id · GraphQL resolvers w/o field authz.

## Bypasses
UUIDs leak elsewhere · older /v1 unpatched · nested JSON / HPP / param variants when 403 · ids echoed in Location/errors.

## 🧪 Try it locally (hands-on)
```bash
# 1) Route this intent to the right playbook (proves the router works)
python3 ../../../tools/skill_router.py "idor on the api endpoint"

# 2) Minimal IDOR check against an AUTHORIZED, in-scope target (two test accounts)
#    Expect: B's session should NOT read A's object. 200 with A's data = IDOR.
curl -s -H "Cookie: session=$ATTACKER" "$TARGET/api/invoices/$VICTIM_ID"

# 3) Enumerate sequential IDs with ffuf (respect program rate limits)
seq $((ID-50)) $((ID+50)) > /tmp/ids.txt
ffuf -u "$TARGET/api/orders/FUZZ" -w /tmp/ids.txt -H "Authorization: Bearer $ATTACKER" -mc 200
```
> Only run 2) and 3) against a program that passed the Authorization Gate
> (`python3 ../../../tools/bounty_gate.py`). Steps use your own test accounts.

## Validation gate
Confirm B has no legitimate access and the response holds real victim data / a real state change.

## Impact & chains
email-change IDOR → reset → **ATO**; members IDOR + mass-assign role=OWNER → **tenant takeover**; orders→refund double-IDOR → **financial**.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
