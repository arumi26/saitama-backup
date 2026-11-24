---
skill: validation-gate
title: "The 7-Question Validation Gate"
category: "Security · Reporting"
load_when: "Phase 06 — the 7-Gate before any report."
pack: SUPERAGENT V10
bughunt: true
---
# The 7-Question Validation Gate

## Where it pays
Kills weak findings before wasted reporting; protects your signal/reputation.

## Signals
Any candidate finding.

## Methodology
All must pass: 1 reproducible from clean state · 2 in scope/not excluded · 3 not a duplicate (memory+public) · 4 real impact (not 200-no-data/self-only) · 5 attacker can do it NOW · 6 severity+CWE set · 7 evidence clean/redacted.

## Validation gate
All 7 green → report; any fail → fix or drop.

## Impact & chains
gates everything that gets submitted.

**→ next: `../phases/07-report.md`.**
