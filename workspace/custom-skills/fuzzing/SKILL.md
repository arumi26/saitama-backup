---
skill: fuzzing
title: "Fuzzing"
category: "Security · Exploit Dev"
load_when: "You have a binary/parser/protocol and want crashes."
pack: SUPERAGENT V10
bughunt: true
---
# Fuzzing

## Where it pays
Automated discovery of exploitable crashes.

## Signals
Parsers, file formats, custom protocols.

## Methodology
1. AFL++ coverage-guided / libFuzzer harness + ASan.
2. Seed valid inputs; minimize corpus.
3. Network: boofuzz/AFLNet. API: restler.
4. Triage: dedupe by stack hash; classify via ASan.

## Validation gate
A reproducible crash with a known faulting instruction + attacker-influenced state.

## Impact & chains
crash → memory-corruption → rop → poc.

**→ next: `../exploit-dev/memory-corruption.md`.**
