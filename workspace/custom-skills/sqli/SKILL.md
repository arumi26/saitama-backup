---
skill: sqli
title: "SQL / NoSQL Injection"
category: "Security · Web Exploitation"
load_when: "Any param reaching a DB query (search/filter/sort/id/login/import)."
pack: SUPERAGENT V10
bughunt: true
---
# SQL / NoSQL Injection

## Where it pays
Full data dump, auth bypass, sometimes RCE.

## Attack-surface signals
Search/filter/sort/id params; login; JSON bodies with operators.

## Methodology
1. Inject ' " ) ; -- ; watch errors/behavior.
2. Boolean + time-based (SLEEP/pg_sleep/WAITFOR).
3. UNION (ORDER BY n → extract).
4. Second-order; NoSQL operators.
5. sqlmap once confirmed (respect limits).

## Payloads
```
' OR 1=1-- -
1' AND SLEEP(5)-- -
' UNION SELECT NULL,version(),NULL-- -
{"$ne": null}
```
More: `../payloads/sqli.txt`.

## Root causes
String-concat queries · no parameterization · ORM raw · trusting sort/filter · NoSQL operators from JSON.

## Bypasses
Comment/case/inline-/**/· CHAR()/hex · WAF keyword split UNI/**/ON · JSON→operator.

## Validation gate
Show real extraction (version/current_user) or a reliable boolean/time oracle — not just an error.

## Impact & chains
dump creds/PII · auth bypass → ATO · stacked/OUTFILE → **RCE** · leaked ids → IDOR.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
