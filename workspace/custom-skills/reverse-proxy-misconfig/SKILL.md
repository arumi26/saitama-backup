---
skill: reverse-proxy-misconfig
title: "Reverse Proxy Misconfigurations"
category: "Security · Web"
load_when: "reverse proxy misconfig, nginx misconfig, path confusion, proxy bypass, X-Accel, off-by-slash, alias traversal, header smuggling proxy"
pack: SUPERAGENT V10
bughunt: true
---

# Reverse Proxy Misconfigurations

## Where it pays
Nginx/Apache/HAProxy/CDN misconfigs create access-control bypass, internal path exposure, SSRF, and header smuggling — high-value, often-overlooked.

## Attack-surface signals
Reverse proxies in front of apps: `location` blocks, `alias`/`proxy_pass` rules, internal-only paths, trailing-slash handling, header forwarding.

## Methodology
1. Off-by-slash / alias traversal: `/static../` escaping the alias root. 2. Path confusion to reach `/internal` or `/admin` protected only by location match. 3. Header smuggling: inject `X-Forwarded-*`, `X-Accel-Redirect` to pivot/SSRF. 4. Request-line/encoding tricks the proxy and backend parse differently.

## Payloads / probes
```
/static../secret/
/admin%2f..%2f
X-Accel-Redirect: /internal/file
/api/..;/admin
GET //backend@internal/ HTTP/1.1
```

## Root causes
location/alias rules without trailing-slash discipline; trusting client X-Forwarded-*; proxy/backend path-parsing mismatch.

## Validation gate
Show access to a protected/internal path, an SSRF via proxy headers, or exposure of files outside the intended root.

## Impact & chains
Auth bypass, internal exposure, SSRF, smuggling. Chains with web/ssrf, request-smuggling, cloud-misconfig.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "reverse proxy misconfig, nginx misconfig, path confusion, proxy bypass, X-Accel, off-by-slash, alias traversal, header smuggling proxy"
```

→ Report with `../reporting/writeup.md` (CWE-16); validate with `../reporting/validation-gate.md`.
