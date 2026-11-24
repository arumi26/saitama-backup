---
skill: api-key-leaks
title: "API Key & Secret Leakage"
category: "Security · Recon"
load_when: "api key leaks, secret leak, leaked credentials, hardcoded key, github dork secret, js secret, exposed token"
pack: SUPERAGENT V10
bughunt: true
---

# API Key & Secret Leakage

## Where it pays
Leaked keys/secrets are among the fastest bounty wins — and the most dangerous. Found in JS bundles, repos, source maps, history, and misconfigured files.

## Attack-surface signals
JS bundles & source maps, `.env`/`.git`/`config` exposure, GitHub/Gitlab history, Postman/Swagger, error messages, mobile app strings, CI logs.

## Methodology
1. Mine JS/source maps for key patterns. 2. GitHub dork the org for secrets + check commit history. 3. Probe for exposed `/.env`, `/.git/config`, backups. 4. Validate a found key *minimally* (a read-only, non-destructive call) to prove it's live — never abuse scope. 5. Classify blast radius.

## Payloads / probes
```
# patterns
AKIA[0-9A-Z]{16}            (AWS)
ghp_[0-9A-Za-z]{36}         (GitHub)
sk-[0-9A-Za-z]{20,}         (OpenAI-style)
AIza[0-9A-Za-z_\-]{35}       (Google)
# exposure probes
/.env  /.git/config  /config.json  .js.map
```

## Root causes
Secrets committed to client code/repos; exposed dotfiles; no secret scanning; keys without scope/rotation.

## Validation gate
Prove the key is live with a single minimal, non-destructive call (e.g. a whoami/list), then stop. Document source + scope.

## Impact & chains
Account/cloud compromise, data access, financial loss. Chains with cloud-misconfig and dependency-confusion.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "api key leaks, secret leak, leaked credentials, hardcoded key, github dork secret, js secret, exposed token"
```

→ Report with `../reporting/writeup.md` (CWE-798); validate with `../reporting/validation-gate.md`.
