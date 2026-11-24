---
skill: type-juggling
title: "Type Juggling / Loose Comparison"
category: "Security · Web"
load_when: "type juggling, loose comparison, php type juggling, magic hash, == vs ===, 0e hash collision, json type confusion"
pack: SUPERAGENT V10
bughunt: true
---

# Type Juggling / Loose Comparison

## Where it pays
Loose typing (PHP ==, JS) can bypass auth/signature checks — magic hashes, 0e collisions, array tricks. Small input, big impact (auth bypass).

## Attack-surface signals
PHP apps comparing with ==, password/token checks, HMAC verify with loose compare, JSON APIs that accept arrays where strings expected.

## Methodology
1. Magic hash: find `0e...` hashes that compare equal (`0e123 == 0e456` → true). 2. Array injection: send `param[]=` to make strcmp/compare return null→bypass. 3. JSON: send numbers/bools/arrays where a string is checked. 4. Loose HMAC compare → signature bypass.

## Payloads / probes
```
password=0e462097431906509019562988736854   (magic hash)
param[]=1   (array → strcmp null)
{"admin": true}  vs  "true"
token=0  ==  "0e..."
```

## Root causes
Use of == / loose compare instead of === / hash_equals; comparing user input of unexpected type.

## Validation gate
Show an auth/signature bypass achieved purely via type confusion (logged in / accepted token you shouldn't have).

## Impact & chains
Auth bypass, signature bypass. Chains with auth/jwt and account-takeover.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "type juggling, loose comparison, php type juggling, magic hash, == vs ===, 0e hash collision, json type confusion"
```

→ Report with `../reporting/writeup.md` (CWE-697); validate with `../reporting/validation-gate.md`.
