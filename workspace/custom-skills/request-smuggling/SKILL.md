---
skill: request-smuggling
title: "HTTP Request Smuggling (Desync)"
category: "Security · Web Exploitation"
load_when: "Chained proxy/CDN + origin; CL/TE handling quirks."
pack: SUPERAGENT V10
bughunt: true
---
# HTTP Request Smuggling (Desync)

## Where it pays
Poison other users' requests, bypass front-end auth, cache-poison. High severity.

## Attack-surface signals
Front-end + back-end CL/TE disagreement; duplicate/obfuscated TE.

## Methodology
1. Detect CL.TE/TE.CL/TE.TE with timing + differential (Burp Smuggler/smuggler.py).
2. Safe time-based probe first.
3. Confirm desync with your OWN paired requests (never harm real users).

## Payloads
```
Transfer-Encoding: chunked + obfuscated duplicate TE header
```
Handle with extra scope care.

## Root causes
Front-end/back-end disagree on message framing (CL vs TE, duplicate headers, bad folding).

## Bypasses
Header obfuscation, whitespace tricks.

## Validation gate
Demonstrate a desync effect safely with your own paired requests.

## Impact & chains
front-end auth bypass · cache poisoning · request hijacking → session theft.

**→ next on hit: `../phases/04-chain.md`.**
