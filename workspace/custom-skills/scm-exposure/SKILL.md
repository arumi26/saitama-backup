---
skill: scm-exposure
title: "Exposed Source Control (.git/.svn)"
category: "Security · Recon"
load_when: "insecure source code management, .git exposure, exposed git, .svn, source code disclosure, git dumper, repo leak"
pack: SUPERAGENT V10
bughunt: true
---

# Exposed Source Control (.git/.svn)

## Where it pays
An exposed `.git`/`.svn` folder lets you reconstruct the full source — finding secrets, logic, and other bugs. Classic high-value recon win.

## Attack-surface signals
Web roots serving `/.git/`, `/.svn/`, `/.hg/`; `200` on `/.git/HEAD` or `/.git/config`; backup/VCS metadata left in deploy.

## Methodology
1. Probe `/.git/HEAD`, `/.git/config`. 2. If present, dump the repo (git-dumper) and reconstruct source. 3. Mine for secrets, credentials, internal endpoints, and other vulns in the recovered code. 4. Check commit history for removed-but-recoverable secrets.

## Payloads / probes
```
/.git/HEAD
/.git/config
/.svn/wc.db
/.git/logs/HEAD
# then: git-dumper http://target/.git/ out/
```

## Root causes
VCS metadata deployed to the web root; no block on dotfolders; secrets in history.

## Validation gate
Show the exposed repo is dumpable and reveals source/secrets (document a recovered file, redact live secrets).

## Impact & chains
Full source disclosure, secret recovery, further bug discovery. Chains with api-key-leaks and the whole web class.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "insecure source code management, .git exposure, exposed git, .svn, source code disclosure, git dumper, repo leak"
```

→ Report with `../reporting/writeup.md` (CWE-527); validate with `../reporting/validation-gate.md`.
