---
skill: graphql
title: "GraphQL"
category: "Security · API"
load_when: "Any /graphql,/gql,/query, or GraphQL in JS."
pack: SUPERAGENT V10
bughunt: true
---
# GraphQL

## Where it pays
One introspection maps the whole API; resolvers skip authz; batching defeats rate limits.

## Signals
/graphql endpoints; __schema introspection; field suggestions.

## Methodology
1. Introspect (or clairvoyance if off).
2. BOLA/BFLA: substitute ids in every query/mutation; call admin mutations as low-priv.
3. Batching to brute OTP/login.
4. Injection via resolver args; depth/alias DoS (report carefully).

## 🧪 Try it locally (hands-on)
```bash
python3 ../../../tools/skill_router.py "graphql introspection and bola"

# Introspection (if enabled) — maps the whole API
curl -s "$TARGET/graphql" -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}' | jq
# Then substitute other users' IDs into every query/mutation argument.
```
## Validation gate
Show cross-user/privileged data via a query/mutation, or a real rate-limit bypass.

## Impact & chains
mass cross-tenant extraction via node(id:) · mutation priv-esc · OTP brute → **ATO**.

**→ next on hit: `../phases/04-chain.md`.**
