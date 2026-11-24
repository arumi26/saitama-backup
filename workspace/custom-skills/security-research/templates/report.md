# SECURITY REPORT — MASTER RECORD (internal)

<!--
ADOPTED 2026-10-03 (imported template, adopted by the operator;
original preserved verbatim as report.as-given.md in this folder).

ROLE OF THIS DOCUMENT: this is the internal master record for ONE finding — the
single source of truth in the target workspace (reports/). It is NOT the
submission text. Submission drafts are derived from this record and re-rendered
per program (human researcher voice, program's own format) — never paste this
template verbatim into a submission.

Every section maps to a gate: Root Cause + Attack Path + PoC = VERIFICATION
gate, Scope + Duplicate Check = DEDUP gate, Severity = program scale, Evidence
= the receipts. A section you cannot fill is a gate you have not passed — mark
it UNKNOWN and go back to work; do not delete the section.
-->

- Finding state: [CANDIDATE / LEAD / REPRODUCED / REACHABILITY_CHECKED / VERIFIED / RANKED / SUBMISSION_READY / SUBMITTED]
- Date:
- Reporter: 0xlab
- Target workspace:

## Title

[Root cause] allows [security impact]

## Summary

[One concise paragraph describing the vulnerability.]

## Root Cause

The issue exists in:

* Component:
* Contract / Module / Class:
* Function:
* File:
* Lines:
* Deployment / Artifact:
* Version / Build:
* Chain: [EVM findings only]
* Compiler: [EVM findings only]

Security invariant:

[What must always be true]

Actual behavior:

[What the implementation allows]

## Attack Path

1. Attacker obtains [capability].
2. Attacker interacts with [entry point].
3. [Relevant operation occurs.]
4. [Security control is bypassed/missing.]
5. [State or asset changes.]
6. [Impact occurs.]

## Proof of Concept

Environment:

* Chain: [EVM only]
* Deployment / Artifact version:
* Commit:
* Compiler: [EVM only]
* Test environment:

Preconditions & reachability:

[Every precondition the PoC relies on, and how each one is reached in
production through public entry points / live state. A precondition that only
exists because the test seeded it does NOT count as reached.]

Fixture seeding: NONE / [list exactly what state the test wrote directly]

Reproduction:

[Minimal reproducible procedure.]

Expected:

[Expected behavior.]

Actual:

[Observed behavior.]

## Impact

Affected component:

[Affected component]

Affected asset/state:

[Asset/state]

Security consequence:

[Concrete consequence]

Demonstrated impact:

[Measured result — demonstrated only; SCALE (TVL/volume/users) is not impact]

## Scope

Program:

[Program]

Component:

[Component]

Chain: [if applicable]

Scope status:

IN_SCOPE / OUT_OF_SCOPE / UNKNOWN

## Duplicate Check

Program disclosures:

[Result]

Repository:

[Result]

Audits:

[Result]

Deployment history:

[Result]

Classification:

[EXACT_DUPLICATE / LIKELY_DUPLICATE / RELATED_BUT_DISTINCT / NEW_ROOT_CAUSE / UNKNOWN]

(UNKNOWN = do not submit yet.)

## Severity

Program severity (the program's own scale/tiers — this is what decides the reward):

[Severity per program scale]

Rationale:

[Concise justification, tied to demonstrated impact]

CVSS (only when the program requires it, e.g. CVSS/VRT programs):

[Vector]

Score:

[Score]

## Remediation

[Suggested fix direction, in the terms the project's own codebase already uses
elsewhere where possible. Optional for submission, expected in this record.]

## Evidence

* [Source/code]
* [Transaction/test]
* [Deployment]
* [PoC]
