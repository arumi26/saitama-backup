# Shodan Dorks for Bug Bounty Recon

Use only after confirming an active bounty/VDP and its exact in-scope assets. Shodan results are reconnaissance leads, not findings. Validate target ownership before interacting with any host.

## Syntax Corrections

| Incorrect / noisy | Correct / preferred |
|---|---|
| `org:"http://target.com"` | `org:"Target Company Name"` |
| Find assets by domain using `org:` | `hostname:"target.com"` |
| `http.status:"200"` | `http.status:200` |
| `net:"104.16.100.52/32"` | `net:104.16.100.52/32` |
| `http://ssl.cert.subject.cn:"http://domain.com"` | `ssl.cert.subject.cn:"domain.com"` |
| `asn:"AS13335"` | `asn:AS13335` |
| `ip:"203.0.113.10"` | `ip:203.0.113.10` |

`org:` expects the organization name recorded for the IP, not a URL. For domain attribution, start with `hostname:`, `ssl.cert.subject.cn:`, and `ssl:`.

## Target Attribution

```text
hostname:"target.com"
ssl.cert.subject.cn:"target.com"
ssl:"target.com"
org:"Target Company"
asn:AS12345
net:203.0.113.0/24
ip:203.0.113.10
```

## HTTP Filters

```text
http.status:200
http.title:"Dashboard"
http.html:"target"
http.component:"WordPress"
http.component_category:"cms"
http.waf:"Cloudflare"
http.favicon.hash:123456789
http.html_hash:123456789
http.securitytxt:"security@target.com"
```

## Service Filters

```text
product:"Elasticsearch"
product:"Kibana"
port:9200
port:9200 "X-elastic-product"
port:5601 "kbn-name"
port:27017 "MongoDB"
port:6379 "Redis"
port:8080 "Tomcat"
```

## TLS Filters

```text
ssl.cert.subject.cn:"*.target.com"
ssl.cert.issuer.cn:"Let's Encrypt"
ssl.alpn:"h2"
ssl.version:"TLSv1.2"
```

## Raw Header and Body Searches

```text
"Set-Cookie: PHPSESSID"
"Set-Cookie: phpMyAdmin"
"Set-Cookie: lang="
"Set-Cookie: mongo-express"
"Set-Cookie: _gitlab_session"
"Set-Cookie: webvpn"
"Set-Cookie:webvpnlogin=1"
"Set-Cookie:webvpnLang=en"
"Set-Cookie: user_id="
"X-elastic-product: Elasticsearch"
"kbn-name: kibana"
"x-drupal-cache"
"X-Magento-Cache-Debug"
"WWW-Authenticate"
"access-control-allow-origin"
```

## High-Signal Combinations

```text
hostname:"target.com" http.status:200
hostname:"target.com" port:8080
hostname:"target.com" port:9200 "X-elastic-product"
hostname:"target.com" port:5601 "kbn-name"
hostname:"target.com" "WWW-Authenticate"
hostname:"target.com" "access-control-allow-origin"
ssl:"target.com" -hostname:"target.com"
org:"Target Company" port:22
org:"Target Company" port:3389
org:"Target Company" port:9200
org:"Target Company" product:"Jenkins"
org:"Target Company" http.title:"Grafana"
org:"Target Company" http.title:"phpMyAdmin"
```

`ssl:"target.com" -hostname:"target.com"` is useful for discovering certificates that mention the target while the indexed hostname does not, which may reveal staging, origin, or shadow assets. Attribution must still be verified.

## Favicon Hash

Shodan's favicon search uses a signed 32-bit MurmurHash3 value derived from the favicon content encoded in the expected format. Search it with:

```text
http.favicon.hash:-123456789
```

Treat matching favicons only as an ownership lead: unrelated deployments may reuse the same product or template favicon.

## Workflow

1. Confirm the program, safe harbor, and exact scope.
2. Build attribution queries from `hostname`, `ssl`, `org`, ASN, and netblocks.
3. Add service, port, title, component, or raw-header filters.
4. Export and deduplicate hosts/IPs.
5. Resolve current DNS and verify ownership; exclude shared CDN/cloud infrastructure that cannot be attributed.
6. Probe only in-scope systems under the program rules.
7. Manually validate every signal and demonstrate impact before reporting.

## False-Positive Controls

- `Access-Control-Allow-Origin` alone is not a CORS vulnerability.
- A Kibana, Elasticsearch, Grafana, Jenkins, phpMyAdmin, or VPN banner is not proof of unauthenticated access.
- Cookies and product headers identify technology; they do not establish exploitability.
- Shared CDN IPs and large cloud ASNs can contain assets owned by unrelated organizations.
- Historical Shodan data may no longer reflect the live service.
- A scanner result without a reproducible impact is not reportable.
