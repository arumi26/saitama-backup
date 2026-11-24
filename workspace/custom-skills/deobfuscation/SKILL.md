---
skill: deobfuscation
title: "Deobfuscation & Anti-Analysis"
category: "Security · Reverse Engineering"
load_when: "Binary packed/obfuscated or fights the debugger."
pack: SUPERAGENT V10
bughunt: true
---
# Deobfuscation & Anti-Analysis

## Where it pays
Reach analyzable code behind packers/anti-debug/encryption.

## Signals
High entropy; ptrace/IsDebuggerPresent; encrypted strings.

## Methodology
1. Neutralize anti-debug/anti-VM (patch/Frida).
2. Unpack to OEP + dump.
3. Script/emulate string decryption (Unicorn).
4. angr/Triton symbolic for hard constraints.

## Validation gate
A cleaner artifact (unpacked dump, decrypted strings, solved input).

## Impact & chains
feeds static/dynamic; solved constraints → keygen/bypass.

**→ next: `../reverse-engineering/firmware.md`.**
