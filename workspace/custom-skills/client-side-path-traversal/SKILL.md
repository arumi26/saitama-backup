---
skill: client-side-path-traversal
title: "Client-Side Path Traversal (CSPT)"
category: "Security · Web"
load_when: "client side path traversal, cspt, frontend path traversal, api path manipulation, fetch path traversal, ../ in api call"
pack: SUPERAGENT V10
bughunt: true
---

# Client-Side Path Traversal (CSPT)

## Where it pays
When the frontend builds an API URL from user input, `../` can redirect the authenticated request to a different endpoint — turning a read into a CSRF-able write or a sensitive call.

## Attack-surface signals
SPAs that construct `fetch('/api/'+userInput)` paths, slug/id in the URL used for API calls, download/preview features taking a client-supplied path.

## Methodology
1. Find where client input becomes part of an API path. 2. Inject `../` to traverse to another endpoint. 3. Combine with a gadget (an endpoint that acts on the traversed path) → CSPT→CSRF or sensitive-action. 4. Confirm the request hits the unintended endpoint.

## Payloads / probes
```
/api/user/../admin/delete
#/profile/..%2f..%2fapi%2fsettings
fetch('/api/items/'+ '../../account/email')
```

## Root causes
Frontend concatenates untrusted input into an API path without normalization; backend honors the traversed path.

## Validation gate
Show the authenticated client request reaching an unintended endpoint (and, ideally, a resulting state change).

## Impact & chains
CSPT→CSRF, sensitive action, data access. Chains with web/csrf and web/idor.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "client side path traversal, cspt, frontend path traversal, api path manipulation, fetch path traversal, ../ in api call"
```

→ Report with `../reporting/writeup.md` (CWE-22); validate with `../reporting/validation-gate.md`.
