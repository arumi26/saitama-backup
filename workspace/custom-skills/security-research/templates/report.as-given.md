# SECURITY REPORT

> Fill-in template — one instance per finding. Every section maps to a gate:
> Root Cause + Attack Path + PoC = VERIFICATION GATE (L2→L3), Scope + Duplicate
> Check = DEDUP gate, Severity = CVSS standard, Evidence = the receipts.
> A section you cannot fill is a gate you have not passed — mark it UNKNOWN
> and go back to work; do not delete the section.

## Title

[Root cause] allows [security impact]

## Summary

[One concise paragraph describing the vulnerability.]

## Root Cause

The issue exists in:

* Component:
* Contract:
* Function:
* File:
* Lines:
* Deployment:

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

* Chain:
* Deployment:
* Commit:
* Compiler:
* Test environment:

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

[Measured result]

## Scope

Program:

[Program]

Component:

[Component]

Chain:

[Chain]

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

[EXACT_DUPLICATE / LIKELY_DUPLICATE / RELATED_BUT_DISTINCT / NEW_ROOT_CAUSE]

## Severity

CVSS:

[Vector]

Score:

[Score]

Rationale:

[Concise justification]

## Evidence

* [Source/code]
* [Transaction/test]
* [Deployment]
* [PoC]
