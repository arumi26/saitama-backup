---
skill: cloud-misconfig
title: "Cloud Misconfiguration"
category: "Security · Cloud/Infra"
load_when: "AWS/GCP/Azure target; after SSRF or when buckets/keys surface."
pack: SUPERAGENT V10
bughunt: true
---
# Cloud Misconfiguration

## Where it pays
Public stores, leaked keys, SSRF→metadata chains = critical.

## Signals
Public buckets; leaked keys; IMDS; over-permissive IAM; exposed datastores.

## Methodology
1. Enumerate buckets (permutations); test read/write/list.
2. Validate leaked key with a benign read (sts get-caller-identity); enumerate perms read-only.
3. Metadata via SSRF (IMDSv1/v2).
4. Over-permissive IAM; exposed ES/Mongo/Redis/snapshots.

## Validation gate
Access that should be private; never modify or mass-exfil.

## Impact & chains
PII/secret exposure, IAM escalation → **infra takeover**.

**→ next: `../web/ssrf.md`, `../phases/04-chain.md`.**
