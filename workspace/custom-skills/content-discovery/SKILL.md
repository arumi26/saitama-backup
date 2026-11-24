---
skill: content-discovery
title: "Content & Param Discovery"
category: "Security · Recon"
load_when: "Phase 01/03 per host, for hidden functionality."
pack: SUPERAGENT V10
bughunt: true
---
# Content & Param Discovery

## Where it pays
Hidden endpoints (/admin,/debug,/api/v1,backups,.git) and undocumented params hide unpatched logic.

## Signals / sources
Sensitive files: .git/ .env .DS_Store *.bak swagger/openapi /actuator *.map.

## Methodology
1. ffuf/feroxbuster dirs+exts.
2. arjun/x8 hidden params.
3. Confirm what each 200 actually does.

## Commands
```bash
ffuf -u https://t/FUZZ -w raft.txt -mc 200,204,301,302,401,403
arjun -u https://t/api/user -m GET,POST
```

## Validation gate
A 200 isn't a finding; exposed sensitive content/function is.

**→ feeds `../phases/02-surface.md`.**
