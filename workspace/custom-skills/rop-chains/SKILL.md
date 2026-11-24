---
skill: rop-chains
title: "ROP Chains"
category: "Security · Exploit Dev"
load_when: "You control stack/return on an NX target."
pack: SUPERAGENT V10
bughunt: true
---
# ROP Chains

## Where it pays
Bypass NX using existing gadgets.

## Signals
NX set; controllable stack.

## Methodology
1. Collect gadgets (ROPgadget/ropper/one_gadget).
2. Leak libc → compute base → return to main.
3. ret2system/execve via pop gadgets; mind alignment.
4. pwntools local→remote.

## Validation gate
A shell/command executes locally then remotely.

## Impact & chains
→ poc (reliable, safe).

**→ next: `../exploit-dev/poc-engineering.md`.**
