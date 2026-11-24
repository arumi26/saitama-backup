---
skill: http-parameter-pollution
title: "HTTP Parameter Pollution (HPP)"
category: "Security · Web"
load_when: "http parameter pollution, hpp, duplicate parameter, parameter pollution, array parameter, waf bypass hpp"
pack: SUPERAGENT V10
bughunt: true
---

# HTTP Parameter Pollution (HPP)

## Where it pays
Sending duplicate params exploits parser differences (first vs last vs concat) → WAF bypass, logic bypass, or injection into a second system.

## Attack-surface signals
Any endpoint with params that pass through multiple layers (proxy→app→backend), filters/WAFs, and server-side request building.

## Methodology
1. Duplicate a param (`?id=1&id=2`) and observe which value wins at each layer. 2. Use the discrepancy to bypass a WAF/validation (payload in the ignored copy). 3. Split an injection across copies. 4. Abuse array-style `id[]=` parsing.

## Payloads / probes
```
?id=1&id=2
?q=safe&q=<script>
?role=user&role=admin
?id[]=1&id[]=2
```

## Root causes
Inconsistent duplicate-parameter handling across proxy/framework/backend; concatenation of values.

## Validation gate
Show a concrete bypass or behavior change caused by the duplicate parameter (WAF evaded, auth/logic changed).

## Impact & chains
WAF/filter bypass, auth/logic bypass, injection delivery. Chains with sqli, xss, and business-logic.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "http parameter pollution, hpp, duplicate parameter, parameter pollution, array parameter, waf bypass hpp"
```

→ Report with `../reporting/writeup.md` (CWE-235); validate with `../reporting/validation-gate.md`.
