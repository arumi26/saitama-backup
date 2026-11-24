# Report

The report is the deliverable. A perfect bug with a vague report gets triaged as informational.

## Structure

1. **Title** — `IDOR on /api/v2/invoices/{id} exposes other tenants' billing PDFs`. Class, asset,
   impact. No "possible", no "maybe".
2. **Severity** — CVSS 3.1 vector, score, and one line per metric. If the program uses its own
   scale, still give the vector.
3. **Summary** — root cause in two sentences: what check is missing, where.
4. **Steps** — numbered, copy-pasteable. Account A, account B, request, response. Every request as
   a fenced `http` block with the full path, headers that matter, and body.
5. **Evidence** — response excerpts with the sensitive field highlighted, callback log lines with
   timestamps, and a screenshot only where the UI is the proof.
6. **Impact** — what an attacker does with it, in business terms: "any authenticated user reads any
   tenant's invoices, including amounts and addresses".
7. **Remediation** — fix at the layer that is wrong: authorization check on the object, not a
   filter on the list endpoint.
8. **Notes** — versions, accounts used, anything that could affect reproduction.

## Tone

Past tense for what you did, present for what the code does. No "as you can see", no "I hope", no
self-deprecation, no apology for the severity.

## CVSS discipline

Argue each metric:

```
AV:N  internet-facing endpoint
AC:L  no special conditions, one request
PR:L  any authenticated user
UI:N  no victim interaction
S:C   crosses tenant boundary
C:H   full invoice contents
I:N
A:N
```

`S:C` is the one triagers argue. Justify it with the boundary crossed, not with "it feels serious".

## Common rejections, pre-empted

| Rejection | Pre-emption |
| --- | --- |
| "Works as intended" | quote the docs or the UI that promises otherwise |
| "Duplicate" | name the original and the delta |
| "Needs user interaction" | prove it, then score `UI:R` honestly |
| "No impact" | convert to a concrete data or money statement |
| "Out of scope" | paste the policy line that includes the asset |
| "Self-XSS" | show a second account or a stored path |

## Evidence hygiene

Redact your own tokens to a prefix. Keep the victim's PII to the minimum that proves the bug. Log
timestamps in UTC. Zip the raw proxy history if the program allows attachments.

## After submission

Answer triage within a day. If disputed, restate the reproduction, do not restate the impact. If
fixed, retest and confirm before the program asks.
