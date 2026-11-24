---
skill: regex-redos
title: "ReDoS (Regular Expression DoS)"
category: "Security · Web"
load_when: "redos, regex dos, regular expression dos, catastrophic backtracking, evil regex, regex denial of service"
pack: SUPERAGENT V10
bughunt: true
---

# ReDoS (Regular Expression DoS)

## Where it pays
A vulnerable regex fed a crafted string causes catastrophic backtracking → one request pins a CPU core and can take the service down. Cheap, remote DoS.

## Attack-surface signals
Server-side regex on user input: email/URL validators, search, input sanitizers, log parsers, WAF rules; patterns with nested quantifiers like `(a+)+$`.

## Methodology
1. Find regex-validated inputs. 2. Spot evil patterns: nested/overlapping quantifiers `(a+)+`, `(a|a)*`, `(.*a){x}`. 3. Send a long non-matching tail that forces backtracking. 4. Measure response time vs input length (exponential = vuln). 5. Keep probes short/non-destructive.

## Payloads / probes
```
aaaaaaaaaaaaaaaaaaaaaaaa!      (against (a+)+$)
input: 'a'*50 + '!'
email: 'a'*40 + '@' + 'a'*40 (against vulnerable email regex)
```

## Root causes
Regex with exponential/polynomial backtracking applied to attacker-controlled, unbounded input.

## Validation gate
Show response time growing super-linearly with input length (clear exponential blowup), without a destructive flood.

## Impact & chains
Remote DoS / resource exhaustion. Chains with business-logic (lock a scarce resource) and rate-limit gaps.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "redos, regex dos, regular expression dos, catastrophic backtracking, evil regex, regex denial of service"
```

→ Report with `../reporting/writeup.md` (CWE-1333); validate with `../reporting/validation-gate.md`.
