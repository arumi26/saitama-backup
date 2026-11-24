---
skill: js-mining
title: "JavaScript Mining"
category: "Security · Recon"
load_when: "Phase 01/02 for SPAs — richest endpoint source."
pack: SUPERAGENT V10
bughunt: true
---
# JavaScript Mining

## Where it pays
SPAs ship their API map in JS: internal endpoints, role names, sometimes keys.

## Signals / sources
Bundles, source maps (*.map), inline fetch/axios/graphql calls.

## Methodology
1. katana crawl → collect .js.
2. jsluice/LinkFinder for endpoints.
3. grep for secrets; reconstruct from source maps if exposed.

## Commands
```bash
katana -u https://t -jc -d 3 | grep '\.js' | sort -u > js.txt
cat js.txt | xargs -I{} curl -s {} | jsluice urls
```

## Validation gate
Treat recovered endpoints as hypotheses; verify authz before claiming a bug.

**→ feeds `../phases/02-surface.md`.**
