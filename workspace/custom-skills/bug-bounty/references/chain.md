# Chaining

A chain turns an accepted-low into an accepted-high. Build it only when the second link is free.

## Shapes that pay

| First link | Second link | Result |
| --- | --- | --- |
| Open redirect on the IdP domain | `redirect_uri` allowlist | OAuth code theft → account takeover |
| SSRF to metadata | IAM credentials | cloud takeover |
| XSS on a subdomain | cookies scoped to `.acme.com` | session theft across hosts |
| Subdomain takeover | CORS trust of `*.acme.com` | authenticated data read |
| IDOR on an export | predictable export path | mass PII |
| Prototype pollution | gadget in the same bundle | RCE |
| Path traversal in an upload | writable webroot | RCE |
| Cache poisoning | reflected XSS in a cached JS file | stored XSS at scale |

## Rules

1. Every link must be independently reproducible. If link 2 only works inside link 1, say so and
   prove link 1 alone first.
2. Do not skip the boring middle: a chain that needs a victim click has `UI:R` and drops a band.
3. Score the chain as a whole, then state the score of each link so the triager sees the delta.
4. If a link is already reported and fixed, say which version you tested.
5. Cap the chain at what you can reproduce twice.

## Anti-patterns

- Two unrelated bugs stapled together ("XSS + missing HSTS").
- A chain whose first link is informational.
- A theoretical escalation with no PoC ("this could lead to RCE if…").
- Re-using the victim's own browser as the only proof of a server-side flaw.

## Write it

```
Link 1  POST /oauth/authorize  redirect_uri accepted with a suffix  → 302 to evil.test
Link 2  code exchanged at /oauth/token without PKCE  →  victim token
Link 3  token used against /api/me  →  email, then password reset
```

Then the CVSS for the composite, and a one-line note on which link the fix should target.
