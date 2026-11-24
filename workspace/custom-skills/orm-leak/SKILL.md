---
skill: orm-leak
title: "ORM Leak / Mass Query Injection"
category: "Security · API"
load_when: "orm leak, orm injection, graphql filter leak, prisma leak, django orm leak, relational filter abuse, nested filter"
pack: SUPERAGENT V10
bughunt: true
---

# ORM Leak / Mass Query Injection

## Where it pays
APIs that pass user filters straight to an ORM (Prisma, Django, Hasura, GraphQL) let attackers craft filters that leak fields/rows they shouldn't see — blind data extraction.

## Attack-surface signals
GraphQL `where`/filter args, REST `?filter[...]`, search with operator syntax, admin-style query params, ORMs exposing relation traversal.

## Methodology
1. Map the filterable fields and operators. 2. Abuse relation traversal to pull related sensitive fields (`user.passwordResetToken`). 3. Boolean/operator blind extraction (`startsWith`,`gt`,`contains`) char-by-char. 4. Leak via ordering/aggregation oracles.

## Payloads / probes
```
?filter[user][resetToken][startsWith]=a
{ users(where:{ resetToken:{ startsWith:"a" }}){ id } }
?orderBy=user.password&... (ordering oracle)
```

## Root causes
User-controlled filters reach the ORM without a field allowlist; relations/sensitive columns queryable; operator-based oracles.

## Validation gate
Show extraction of a field/record you shouldn't access (e.g. another user's token inferred via the filter oracle).

## Impact & chains
Blind data extraction, token/PII theft → ATO. Chains with api/rest-authz, api/graphql, account-takeover.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "orm leak, orm injection, graphql filter leak, prisma leak, django orm leak, relational filter abuse, nested filter"
```

→ Report with `../reporting/writeup.md` (CWE-200); validate with `../reporting/validation-gate.md`.
