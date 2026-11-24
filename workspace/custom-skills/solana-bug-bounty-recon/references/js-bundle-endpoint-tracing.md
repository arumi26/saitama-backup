# JS Bundle Endpoint Tracing — Finding Hidden Microservice APIs

Technique for extracting the full endpoint list of hidden internal services from a minified Next.js bundle, when endpoints are constructed dynamically as `fetch("".concat(baseVar, "/path"))` rather than as string literals.

## Why This Matters

Static grep for `/api/xxx` misses **microservice endpoints** where the base URL is a variable. Popi hides its entire referral microservice this way:

```
Static grep finds:  /api/auth/nonce, /api/launches, /api/rpc  (5 total)
Dynamic trace finds: PLUS /api/referral/dashboard, /balance, /bind, /claim,
                     /my-ref-code, /my-referees  (11 total)
```

## Extraction Regex

```bash
grep -oE 'fetch\("\s*"\.concat\([a-zA-Z_]+,"[^"]+"' bundle.js
```

Every hit shows a `baseVar` + `/path` pair. Then trace the variable definition by walking backward:

```python
import re
content = open('bundle.js', encoding='utf-8', errors='replace').read()

# Find all endpoint uses
uses = list(re.finditer(r'fetch\("\s*"\.concat\(([a-zA-Z_]+),"([^"]+)"', content))
# For each unique base var, walk back to find its declaration
base_vars = set(m.group(1) for m in uses)
for var in base_vars:
    # Find nearest enclosing declaration
    idx = uses[0].start()
    # Search backward for something like: let VAR = "..."  or  VAR = "/api/..."
    for m in re.finditer(rf'\b{var}\s*=\s*"(/[^"]+)"', content[:idx]):
        print(f"{var} = {m.group(1)}")
```

## Once Base URL Found — Standard Probe Checklist

For each endpoint under the base (e.g. `{base}/dashboard`, `{base}/balance`, `{base}/bind`, `{base}/claim`):

1. **HTTP methods**: try GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD. Note which return 405 vs 400/401 — 405 confirms method not allowed, 401 confirms endpoint exists.
2. **Auth**: probe unauthenticated first. Look for `{"error":"not signed in"}` (401), `bad_origin_or_proxy` (403), `malformed_siws_message` (401) — error progression reveals the auth chain.
3. **IDOR**: for GET endpoints with `?wallet=` param, test another user's wallet. If server returns their data based only on query param (no session cross-check) = IDOR.
4. **Field enumeration**: send `{}` first, then progressively add fields as error messages hint them (`{"error":"supply referrer_wallet or ref_code"}` tells you the exact field names).
5. **CSRF header theater**: if you see `X-App-CSRF`, `X-App-Action`, etc. required by browser code, test if server actually enforces them. Usually cosmetic when real auth is SIWS or bearer token.

## Popi Reference — Referral Microservice Discovered

Base: `r = "/api/referral"` (in `layout-*.js`)

```
GET  /api/referral/dashboard?wallet={wallet}      → 401 not signed in (auth OK)
GET  /api/referral/balance?wallet={wallet}        → 401 not signed in (auth OK)
GET  /api/referral/my-referees                    → 401 not signed in (auth OK)
POST /api/referral/my-ref-code   {wallet, siws_message, siws_signature}
POST /api/referral/bind          {referee_wallet, referrer_wallet OR ref_code, siws_message, siws_signature}
                                 headers: X-Popi-Bind: 1, X-Popi-CSRF: <cookie>
POST /api/referral/claim         {wallet, siws_message, siws_signature}
```

Error flow for `/bind` (attacker perspective, no valid SIWS):
1. `{}` → 403 `bad_origin_or_proxy` (WAF-like check)
2. `{referee_wallet, siws_message:"x", siws_signature:"y"}` → 400 `supply referrer_wallet or ref_code`
3. `{referee_wallet, referrer_wallet, siws_message:"x", siws_signature:"y"}` → 401 `malformed_siws_message`
4. Self-referral (referee == referrer) → 400 `referrer not registered` (referrer wallet must have already created a ref_code)

Self-referral is blocked at the "referrer_not_registered" step, not by an explicit self-referral check. Whether it's exploitable depends on: (a) is there any state where a wallet exists with a ref_code AND you can bind yourself as referee to it? (b) does binding trigger any bonus / drain-vector immediately vs on later action?
