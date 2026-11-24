---
skill: file-upload
title: "File Upload"
category: "Security · Web Exploitation"
load_when: "Any upload feature (avatar/doc/import/attachment)."
pack: SUPERAGENT V10
bughunt: true
---
# File Upload

## Where it pays
Direct path to RCE (webshell) or stored XSS; also SSRF/overwrite.

## Attack-surface signals
avatar/document/import/logo/resume uploads.

## Methodology
1. Learn restriction; defeat each layer.
2. Ext tricks .php.jpg/.phtml/.pHp; magic-byte vs Content-Type; polyglots.
3. SVG→XSS; HTML inline→XSS; XML→XXE.
4. Filename traversal; Content-Disposition control.

## Payloads
```
shell.php.jpg
<svg xmlns=... onload=alert(document.domain)/>
GIF89a;<?php system($_GET['c']);?>
```
More: `../payloads/file-upload.txt`.

## Root causes
Client-only validation · ext blocklist · trusting Content-Type · serving from exec path · unsanitized filename.

## Bypasses
Case/alt ext · magic-byte spoof · nullbyte · race upload+rename · zip-slip.

## Validation gate
Webshell runs a benign command; SVG/HTML executes JS same-origin.

## Impact & chains
**RCE** via webshell · stored XSS → ATO · overwrite · zip-slip traversal.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
