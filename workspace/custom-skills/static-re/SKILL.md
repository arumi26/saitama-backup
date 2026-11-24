---
skill: static-re
title: "Static RE"
category: "Security · Reverse Engineering"
load_when: "After triage, to map logic & sinks without running."
pack: SUPERAGENT V10
bughunt: true
---
# Static RE

## Where it pays
Map algorithms, checks, and dangerous sinks.

## Signals
Decompiler pseudocode; string xrefs; symbol names.

## Methodology
1. Ghidra/IDA/r2 auto-analyze.
2. Follow entry/exports + string xrefs.
3. Rename vars/functions as you learn.
4. Flag strcpy/gets/sprintf/system/memcpy/format sinks.

## Validation gate
Annotated understanding: where input enters, how validated, where used unsafely.

## Impact & chains
dangerous sink → exploit-dev; recovered endpoints/keys → api/cloud.

**→ next: `../reverse-engineering/dynamic-re.md`.**
