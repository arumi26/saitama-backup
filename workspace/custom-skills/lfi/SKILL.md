---
skill: lfi
title: "LFI / Path Traversal"
category: "Security · Web Exploitation"
load_when: "Any param naming a file/path/template/page."
pack: SUPERAGENT V10
bughunt: true
---
# LFI / Path Traversal

## Where it pays
Source/secret disclosure and, when includable, RCE.

## Attack-surface signals
download/include/template/lang/theme/avatar params.

## Methodology
1. Traverse ../../etc/passwd, encoded, ....//.
2. PHP wrappers php://filter base64 to exfil source.
3. LFI→RCE: log poisoning, /proc/self/environ, data://.

## Payloads
```
../../../../etc/passwd
php://filter/convert.base64-encode/resource=config.php
/proc/self/environ
```
More: `../payloads/lfi.txt`.

## Root causes
Concatenating input into paths · include($_GET) · no canonicalization/allowlist.

## Bypasses
Encoding layers · nested traversal · absolute paths · wrapper abuse · ext-append bypass.

## Validation gate
Retrieve a known sensitive file/source — a reflected path isn't LFI.

## Impact & chains
secret leak → auth/cloud · wrapper/log poisoning → **RCE**.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
