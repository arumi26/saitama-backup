# Dorking

Search operators, by engine. Quote before you filter; every extra operator narrows the result and
widens the chance of a false negative.

## Google

```
site:acme.com -www filetype:pdf "confidential"
site:acme.com intitle:"index of"
site:acme.com inurl:api | inurl:admin | inurl:staging
"@acme.com" -site:acme.com
site:docs.google.com "acme.com"
```

Useful: `filetype:xlsx intext:password`, `related:acme.com`, `cache:` (mostly dead but occasionally
alive), `before:2024-01-01`.

## GitHub

```
org:acme filename:.env
org:acme "BEGIN RSA PRIVATE KEY"
"acme.com" password filename:yml
org:acme path:.github/workflows
```

Then `github-search` extensions and `gitleaks` over clones. A hit in a fork is often more revealing
than the upstream.

## Certificate transparency

```bash
curl -s "https://crt.sh/?q=%25.acme.com&output=json" | jq -r '.[].name_value' | sort -u
```

New subdomains appear in CT before DNS. Watch `*.acme.com` for staging, VPN, and mail hosts.

## Shodan / Censys / FOFA

```
ssl:"acme.com"
org:"Acme B.V."
http.title:"Acme" country:NL
```

Product and version filters beat text: `product:Fortinet port:10443`.

## Social

`site:linkedin.com/in "Acme" "engineer"` for staff and stack hints. Twitter advanced search for
support complaints, which name internal tooling. Telegram via `tgstat` for the local ecosystem.

## Paste / leak indexes

`psbdmp`, `pastebin` search, `haveibeenpwned` domain search, `dehashed` (paid). Treat a breach hit
as a lead, not as proof of a live credential.

## Wayback

```
http://web.archive.org/cdx/search/cdx?url=acme.com/*&output=text&fl=original&collapse=urlkey
```

Old JS, removed endpoints, and former staff pages. Diff a 2021 snapshot against today for
`/careers` technology names.

## Traps

- `site:` with a subdomain misses sibling hosts.
- Google's index lags weeks; a fresh CT entry has no search footprint yet.
- A dork that returns 3M results needs one more operator, not a deeper page crawl.
