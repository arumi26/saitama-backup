---
skill: firmware
title: "Firmware RE"
category: "Security · Reverse Engineering"
load_when: "IoT/router/embedded firmware images in scope."
pack: SUPERAGENT V10
bughunt: true
---
# Firmware RE

## Where it pays
Hardcoded creds/keys, backdoors, web-UI cmdi, service memory bugs.

## Signals
binwalk signatures; squashfs/jffs2; cross-compiled MIPS/ARM binaries.

## Methodology
1. binwalk -e extract filesystem.
2. passwd/shadow, keys, certs; web root cmdi/auth bypass.
3. Emulate (qemu user / FirmAE full-system).
4. Service binaries → static/exploit-dev.

## Validation gate
Default creds login, injected command runs, or a crash — demonstrated.

## Impact & chains
creds/keys → device/cloud; web-UI cmdi → **RCE**; overflow → exploit-dev.

**→ next: `../reverse-engineering/protocol-re.md`.**
