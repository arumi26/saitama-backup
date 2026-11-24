# Recon

Passive where possible, active where necessary, always rate-aware.

## Passive

```bash
subfinder -d acme.com -all -silent | anew hosts.txt
curl -s "https://crt.sh/?q=%25.acme.com&output=json" | jq -r '.[].name_value' | sort -u | anew hosts.txt
amass enum -passive -d acme.com -o amass.txt
```

Also: `chaos`, `github-subdomains`, `waybackurls`, `gau`, `urlfinder`, the ASN (`asnmap`) for CIDRs,
Shodan/Censys for exposed services on those CIDRs.

## Active

```bash
httpx -l hosts.txt -silent -td -sc -title -server -o live.txt
naabu -list live.txt -top-ports 1000 -o ports.txt
nuclei -l live.txt -severity critical,high -rl 20 -o nuclei.txt
```

Then per host: `katana -u` for crawl, `ffuf` with a small list for content, `arjun` for parameters.
Retire tools that only produce noise; a list of 400 dead hosts costs more than it gives.

## JavaScript

Fetch every JS bundle. Grep for:

```
api\.|/v[0-9]/|graphql|token|apikey|secret|admin|internal|s3\.|firebase
```

Source maps (`//# sourceMappingURL=`) give back the original tree — `sourcemapper`.
`LinkFinder` and `JSluice` automate extraction; the interesting output is endpoint paths and
hardcoded keys, not regex hits on "password".

## API surface

`kiterunner` for wordlist-aware API discovery, `graphql-cop` for introspection and batching issues.
Swagger at `/swagger.json`, `/openapi.json`, `/api-docs`, `/v2/api-docs`. A spec is a test plan:
every parameter is a hypothesis.

## Rank

| Signal | Why it ranks |
| --- | --- |
| Auth required | more logic, more authz bugs |
| Money/credits/points | business-logic and race bugs |
| Upload | parsing, path, SSRF, stored XSS |
| Admin panel | access control gaps |
| Old stack (jQuery, Rails 4, PHP 5) | known CVEs and weak defaults |
| New host, no DNS history | forgotten, unpatched |

## Cloud

S3 bucket naming permutations, `dig` for dangling CNAMEs (`acme.s3.amazonaws.com` with
`NoSuchBucket` = takeover). Azure blob and GCP storage follow the same pattern with different hosts.
Metadata endpoints are test targets once you have SSRF, not recon.

## Output

`state/live.txt` ranked, `state/params.txt` deduped, `state/js-endpoints.txt`, and a short `notes.md`
of what each interesting host is. Recon ends when the marginal host stops teaching you something.
