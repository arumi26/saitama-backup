---
skill: latex-injection
title: "LaTeX Injection"
category: "Security · Web"
load_when: "latex injection, latex rce, pdf generation injection, input, write18, tex injection, overleaf injection"
pack: SUPERAGENT V10
bughunt: true
---

# LaTeX Injection

## Where it pays
Apps that render user input into LaTeX (PDF generators, math rendering) can be abused for file read, SSRF, or RCE via TeX primitives.

## Attack-surface signals
'Export to PDF', invoice/report generators, math/formula rendering, résumé builders — anything compiling TeX from input.

## Methodology
1. Confirm LaTeX rendering of input. 2. File read: `\input{/etc/passwd}`, `\lstinputlisting{...}`. 3. Write/exec via `\write18{cmd}` when shell-escape is on. 4. SSRF via `\url`/package fetches. 5. Fingerprint the engine (pdflatex/xelatex).

## Payloads / probes
```
\input{/etc/passwd}
\lstinputlisting{/etc/passwd}
\immediate\write18{id}
\href{run:/path}{x}
```

## Root causes
User input compiled as LaTeX; shell-escape (`-shell-escape`/`write18`) enabled; no sandbox on the TeX engine.

## Validation gate
Show file disclosure in the output PDF or command execution via write18.

## Impact & chains
File read, SSRF, RCE. Chains with web/ssrf and command-injection.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "latex injection, latex rce, pdf generation injection, input, write18, tex injection, overleaf injection"
```

→ Report with `../reporting/writeup.md` (CWE-94); validate with `../reporting/validation-gate.md`.
