---
skill: subdomain
title: "Subdomain Enumeration"
category: "Security · Recon"
load_when: "Phase 01 after OSINT, to expand surface."
pack: SUPERAGENT V10
bughunt: true
---
# Subdomain Enumeration

## Where it pays
Wide surface = more bugs; dev/staging/legacy subs are weaker.

## Signals / sources
Passive sources + brute + permutations; dev/staging/api/admin/legacy names.

## Methodology
1. subfinder+amass → merge.
2. puredns brute + gotator permute.
3. dnsx resolve → httpx probe (title/tech/ip/cname).

## Commands
```bash
subfinder -d t.com -all -silent > p.txt
puredns bruteforce words.txt t.com -r res.txt -w b.txt
cat p.txt b.txt | sort -u | dnsx -a -resp | httpx -title -tech-detect -o live.txt
```

## Validation gate
Confirm hosts are in-scope before probing (killswitch fence).

**→ feeds `../phases/02-surface.md`.**
