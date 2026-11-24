# Web / App / API

Server-side playbook. Companion to `mobile.md` (client) and `vuln-classes.md` (per-class
detection). Read this before touching an API surface, read the class file when a hypothesis forms.

## Priority order

Rank by payout-per-hour and by how often triage accepts it, not by how interesting the bug is.

1. **Authorization boundaries** — object ownership, tenant isolation, role checks, admin paths,
   GraphQL field-level authz, bulk endpoints that skip per-object checks.
2. **Business logic** — price and quantity handling, coupon/credit arithmetic, state machines
   (refund before capture, cancel after ship), limits applied on the client only.
3. **Authentication and session** — reset token scope, MFA bypass, session fixation, JWT `alg`/`kid`
   handling, OAuth redirect and state validation.
4. **Injection** — SQLi, NoSQLi, template, command, header, SSRF via URL parsers and webhooks.
5. **File handling** — upload type/extension confusion, path traversal, archive extraction, image
   parsers.
6. **Race conditions** — anything with a balance, quota, or one-time token. See below.

## Authorization testing

- Enumerate every object reference and try another tenant's identifier, not just `id+1`.
- Test the *edge* of the role matrix: support, billing, read-only admin, invited guest.
- Check both directions: lower role reading higher data, and higher role acting on lower data.
- On GraphQL, introspect the schema, then test field-level authz inside a query the frontend never
  sends. Nested resolvers are the usual gap.
- A 200 with empty body is not proof of denial; check body diff and side effects.

## Business logic

- Drive the workflow out of order: capture without authorize, refund twice, ship then cancel.
- Split quantities across parallel requests so per-request caps never trigger.
- Send negative, zero, fractional, and over-precision values; check server-side rounding.
- Reuse one-time tokens (coupon, invite, reset) concurrently and sequentially.
- Replace computed fields with server-trusted ones where the client sends both.

## API version drift

- Compare `/v1` and `/v2` for the same endpoint: authz often tightens in the new version while the
  old stays reachable.
- Check mobile-only, partner, and internal prefixes; old SDKs keep deprecated shapes alive.
- Compare response fields across versions; the old one may still return secrets or internal ids.

## Race conditions

- Identify the invariant first ("balance never below zero", "one coupon per account").
- Send N parallel requests at the same instant (`xargs -P`, Turbo Intruder, or a short asyncio
  script); then read state back.
- Prove the violation, not just the duplicate response. Two 200s mean nothing without two rows.
- If a lock exists, test adjacent endpoints that touch the same row.

## Evidence rules

- Capture the full request and response pair with headers; redact only cookies and keys.
- For authz, show both identities and the same object id in one artifact.
- For logic, show before-state, the out-of-order call, and after-state.
- For races, keep the script that fires them and the observed final state.

## Pre-submission

Run `final-checklist.md` Web2 section. Confirm the surface is in scope, that the same bug is not in
the disclosed list, and that impact names the asset owner's loss, not "an attacker could".
