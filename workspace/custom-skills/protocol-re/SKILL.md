---
skill: protocol-re
title: "Protocol & Format RE"
category: "Security · Reverse Engineering"
load_when: "Thick clients/games/IoT/custom binary protocols or formats."
pack: SUPERAGENT V10
bughunt: true
---
# Protocol & Format RE

## Where it pays
Custom parsers are under-tested → memory & logic bugs; unlocks fuzzing.

## Signals
Custom TCP/UDP protocols; magic bytes; length/checksum fields.

## Methodology
1. Capture + diff messages to map fields.
2. Formalize with Kaitai/010 template; rebuild client.
3. Cross-check client binary (static-re).
4. Feed grammar into fuzzing.

## Validation gate
Reconstructed client interoperates; malformed inputs reach the parser.

## Impact & chains
parser → fuzzing → crashes → exploit-dev; auth handshake → bypass.

**→ next: `../exploit-dev/fuzzing.md`.**
