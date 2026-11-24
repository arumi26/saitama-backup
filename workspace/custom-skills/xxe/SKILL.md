---
skill: xxe
title: "XXE"
category: "Security · Web Exploitation"
load_when: "Any XML intake — SOAP, SAML, SVG, DOCX/XLSX, RSS, config import."
pack: SUPERAGENT V10
bughunt: true
---
# XXE

## Where it pays
Server file read, SSRF, OOB exfiltration.

## Attack-surface signals
XML Content-Type; XML-based uploads (SVG/DOCX); SOAP.

## Methodology
1. Inject DOCTYPE external entity → read file / hit collaborator.
2. Blind → external DTD OOB exfil.
3. Parameter entities to bypass filters.

## Payloads
```
<!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```
Pairs with `ssrf.md`.

## Root causes
Parser resolves external entities · DTD enabled · XML upload parsed server-side.

## Bypasses
Parameter entities · UTF-16 · nested formats · php://filter base64.

## Validation gate
Retrieve a known file or get OOB from the target.

## Impact & chains
file/secret read → auth/cloud · SSRF → metadata · OOB exfil.

**→ next on hit: `../phases/04-chain.md`.**
