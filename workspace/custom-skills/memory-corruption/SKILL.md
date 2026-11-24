---
skill: memory-corruption
title: "Memory Corruption"
category: "Security · Exploit Dev"
load_when: "You have a crash/primitive and need control."
pack: SUPERAGENT V10
bughunt: true
---
# Memory Corruption

## Where it pays
Turn a crash into controlled execution.

## Signals
overflow/UAF/OOB/type-confusion/format/integer-overflow.

## Methodology
1. Triage primitive; inspect attacker-controlled regions.
2. Offset to RIP (cyclic).
3. Mitigations: NX→ROP, ASLR→leak, canary→leak/avoid, PIE→leak, RELRO→func-ptr/ROP.
4. Finals: ret2libc/one_gadget/GOT/heap.

## Validation gate
Controlled RIP or a controlled write primitive demonstrated.

## Impact & chains
→ rop → poc.

**→ next: `../exploit-dev/rop-chains.md`.**
