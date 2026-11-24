---
skill: binary-triage
title: "Binary Triage"
category: "Security · Reverse Engineering"
load_when: "Any compiled artifact/firmware needing fast orientation."
pack: SUPERAGENT V10
bughunt: true
---
# Binary Triage

## Where it pays
Fast orientation decides the whole RE strategy.

## Signals
ELF/PE/Mach-O; packed sections; interesting strings.

## Methodology
1. file/rabin2 -I/checksec (type/arch/NX/PIE/canary/RELRO).
2. strings for urls/keys/errors; nm symbols; ldd libs.
3. Packed? → deobfuscation. Firmware? → firmware.
4. String xrefs point to logic.

## Validation gate
A triage note: type, arch, protections, packer?, next step.

## Impact & chains
feeds static/dynamic RE and exploit-dev.

**→ next: `../reverse-engineering/static-re.md`.**
