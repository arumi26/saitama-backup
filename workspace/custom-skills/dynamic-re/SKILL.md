---
skill: dynamic-re
title: "Dynamic RE"
category: "Security · Reverse Engineering"
load_when: "When static is ambiguous or a runtime check must be defeated."
pack: SUPERAGENT V10
bughunt: true
---
# Dynamic RE

## Where it pays
Observe real behavior and modify it live.

## Signals
gdb/ltrace/strace; Frida hooks.

## Methodology
1. gdb+pwndbg breakpoints; inspect regs/stack.
2. ltrace/strace for real comparisons/syscalls.
3. Frida hook functions; dump decrypted memory; patch returns at runtime.

## Validation gate
Confirm observed behavior reproducibly.

## Impact & chains
dump secret/algorithm → keygen; defeat client check → unlock backend; confirm overflow → exploit-dev.

**→ next: `../reverse-engineering/deobfuscation.md`.**
