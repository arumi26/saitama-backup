---
skill: token-scan
title: "Token / Rug Scanner"
category: "Security · Web3"
load_when: "A token/meme contract to assess for rug/honeypot."
pack: SUPERAGENT V10
bughunt: true
---
# Token / Rug Scanner

## Where it pays
Protects + finds malicious tokens; honeypot & rug detection.

## Signals
Mint authority, LP lock, blacklist/pause, tax, bonding curve, ownership.

## Methodology
1. Check mint authority & owner powers (can they mint/pause/blacklist?).
2. LP locked/burned? renounced?
3. Honeypot sim: can you actually sell?
4. Hidden tax / transfer restrictions; bonding-curve mechanics.

## Validation gate
Demonstrate the malicious capability (unsellable, infinite mint, hidden tax).

## Impact & chains
rug/honeypot classification; protects traders.

**→ next: `../web3/smart-contract-audit.md`.**
