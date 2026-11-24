---
skill: methodology
title: "Core Methodology"
category: "Security · Bug-Hunt Core"
load_when: "Always — the mental model for every engagement."
pack: SUPERAGENT V10
bughunt: true
---
# Core Methodology

## Everything is misplaced trust
Model zones split by trust boundaries: `[attacker input] → [parser/validator/authz] → [trusted sink]`. At each boundary: what crosses, what validation happens, what does the receiver assume, can I break that assumption? Dangerous sinks: SQL, OS command, HTML render, file path, deserializer, template engine, server-side HTTP client (SSRF), object setter (mass assignment), the authz decision itself.

## Source → sink tracing
Enumerate sources (query/body/header/cookie/filename/webhook/import) → follow to the sink → identify the sanitizer → is it sufficient *for that sink*? Missing/weak sanitizer at a dangerous sink = bug.

## Prioritize
New/acquired assets · auth & account surfaces · payments/permissions logic · admin/internal/staging · old tech/known CVEs · exposed `.git`/`.env` — hunt these first.

## The loop
observe → model expected behavior → hypothesize → minimal test → read the DIFFERENTIAL (status/length/timing/error/reflection) → refine → confirm → assess impact → document.

## Impact-first
Who's affected (self/others/all/admin/infra), what's gained, pre-conditions, what it chains to. A bug is worth what you can demonstrate.

**→ used by every phase; pair with `mindset.md`, `chaining.md`.**
