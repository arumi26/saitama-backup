---
skill: takeover
title: "Subdomain / Resource Takeover"
category: "Security · Recon"
load_when: "Phase 01 after resolving — clean quick win."
pack: SUPERAGENT V10
bughunt: true
---
# Subdomain / Resource Takeover

## Where it pays
Dangling DNS → unclaimed 3rd-party resource → serve content on the target's domain.

## Signals / sources
CNAMEs to S3/GitHub Pages/Heroku/Azure/Fastly with service 'not found' fingerprints.

## Methodology
1. nuclei takeovers / subjack on resolved subs.
2. Confirm the backend is truly unclaimed (not a transient 404).
3. Prove with a benign token page only if permitted.

## Commands
```bash
nuclei -l resolved.txt -t http/takeovers/
subjack -w subs.txt -ssl -v
```

## Validation gate
Confirm live CNAME + unclaimed backend; serve only a benign proof.

**→ feeds `../phases/02-surface.md`.**
