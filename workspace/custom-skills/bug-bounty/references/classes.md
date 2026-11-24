# Classes

One page per class: the probe, the proof, the false positive to avoid.

## IDOR / BOLA

Probe: swap every object id for one from a second account. Try the raw id, a base64/hex variant,
adjacent ids, `uuid` from a public feed, and the same id on a sibling route (`/api/v2/`).

Proof: account B's request returns account A's object, with a field only A should see.

False positive: object is public by design; the id is a slug; caching returns the same body for
everyone with a shared `Vary` miss.

## Broken authz / BFLA

Probe matrix: no cookie, user cookie, admin cookie × every verb × every route. Also method
override (`X-HTTP-Method-Override`), path case (`/Admin`), trailing slash, and `/api/internal/`.

Proof: a 200 with data, or a state change, from the wrong role.

False positive: the route 200s but returns an empty list; the UI-level restriction is client-only.

## SSRF

Probe: `url=`, `image=`, `webhook=`, `import=`, PDF renderers, avatar fetchers. Try
`http://169.254.169.254/latest/meta-data/`, `http://127.0.0.1:PORT/`, `http://[::1]`,
`http://0x7f000001`, and a `302` from your host to the internal target.

Proof: metadata body, internal service banner, or a DNS-only callback for blind SSRF.

False positive: the app echoes the URL without fetching; the fetch is client-side.

## XSS

Probe: reflection in HTML, attribute, JS string, and `href`. Break the context first
(`"><svg onload=alert(1)>`), then worry about the filter.

Proof: execution in the real context (stored: in the victim's session), with the sink named.

False positive: reflection inside `<textarea>` with `&lt;` encoded; DOM XSS that only fires in the
researcher's console through `innerHTML` on a value the server already sanitized.

## SQLi

Probe: `'`, `"`, arithmetic, `AND 1=2`, `ORDER BY n`, and time-based where output is blind.

Proof: a UNION row, a boolean differential reproducible 3×, or a 5 s `SLEEP` vs a 0.2 s baseline.

False positive: WAF blocks produce a generic error page; the differential is caching.

## Race condition

Probe: redeem, transfer, invite, vote, coupon. Send N parallel requests (single-packet attack or
`ffuf -t 40`) where N exceeds the limit.

Proof: balance/credit count exceeds the intended cap, or two successes for a one-shot action.

False positive: sequential requests succeed twice because the limit is per hour, not per second.

## Business logic

Probe: negative quantity, zero price, currency swap, quantity overflow, coupon stacking, refund
before capture, trial restart by email plus-plus (`a+1@x.com`).

Proof: a state where money or entitlement is inconsistent with the rules the app states.

## File upload

Probe: extension (`phtml`, `.phar`, `.svg`, `.html`), content-type, magic bytes, double extension,
`.htaccess`, SVG with `<script>`, zip-slip archive, image parser (ImageTragick, `sharp` CVEs).

Proof: server-side execution, stored XSS via a served upload, or traversal write.

## Open redirect / host header

Probe: `next=`, `return=`, `redirect_uri=`, `Host:`, `X-Forwarded-Host:`. Bypass with `//evil`,
`https:evil`, `@`, and backslashes.

Proof: a redirect to your host from a trusted domain; for host header, a password-reset link
pointing at your host.

## CORS

Probe: `Origin: https://evil.test`. Look for `Access-Control-Allow-Origin` echo plus
`Allow-Credentials: true`. Test `null` origin and a suffix trick (`acme.com.evil.test`).

## Cache poisoning / deception

Probe unkeyed inputs: `X-Forwarded-Host`, `X-Original-URL`, `X-Rewrite-URL`, query params the cache
ignores. Confirm with `X-Cache: HIT` and a second request without the header.

## GraphQL

Introspection, then field-level authz, batching for brute force/race, alias overloading,
`__schema` type confusion, and mutations that trust a client-supplied id.

## Deserialization / template / SSTI

Only after fingerprinting the engine. A `{{7*7}}` that returns 49 is 30 seconds from RCE; a
`__VIEWSTATE` is not.

## Cloud / infra

Dangling CNAME takeover, public bucket listing, permissive IAM through SSRF, exposed `.git`,
`/.env`, `/.DS_Store`, backup zips in `/backup/`.

## Traps

- Self-XSS that needs a paste.
- Missing headers with no demonstrated impact (CSP, HSTS) — usually informational.
- `OPTIONS` 200 as "CORS enabled".
- Rate limit on login with no lockout and no user enumeration.
- `Server` banner disclosure.
