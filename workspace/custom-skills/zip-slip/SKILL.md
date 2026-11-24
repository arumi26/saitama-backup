---
skill: zip-slip
title: "Zip Slip / Path Traversal in Archives"
category: "Security · Web"
load_when: "zip slip, archive traversal, tar slip, zip extraction, path traversal upload, ../ in zip, symlink archive"
pack: SUPERAGENT V10
bughunt: true
---

# Zip Slip / Path Traversal in Archives

## Where it pays
Apps that extract user-uploaded archives can be tricked into writing files outside the target dir — overwrite configs, drop a webshell → RCE.

## Attack-surface signals
Upload + unzip/untar features: import, themes/plugins, backup restore, avatar/zip upload, CI artifacts.

## Methodology
1. Craft an archive with entries like `../../../../var/www/html/shell.php`. 2. Upload; check if extraction writes outside the intended folder. 3. Overwrite a known path (cron, authorized_keys, webroot). 4. Symlink entries for read primitives.

## Payloads / probes
```
zip entry name: ../../../../etc/cron.d/x
tar entry: ../../../var/www/html/shell.php
symlink entry → /etc/passwd
```

## Root causes
Extractor joins archive entry names to a base path without canonicalizing/validating (no `..` rejection).

## Validation gate
Show a file written outside the extraction directory (ideally a benign marker), proving arbitrary write → RCE potential.

## Impact & chains
Arbitrary file write → RCE, config overwrite, SSH key drop. Chains with file-upload and command-injection.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "zip slip, archive traversal, tar slip, zip extraction, path traversal upload, ../ in zip, symlink archive"
```

→ Report with `../reporting/writeup.md` (CWE-22); validate with `../reporting/validation-gate.md`.
