# OSINT

The deliverable is a graph with sources, not a paragraph of interesting facts. Every node carries a
URL and a retrieval date; everything else is a rumor.

## Discipline

- Public only. No logins with the subject's credentials, no scanning, unless the brief says otherwise.
- One claim, one source. Two independent sources for anything load-bearing.
- Note what you could **not** confirm. Absence is a finding and belongs in the report.
- Infoboxes lie. Prefer filings, certificates, and DNS over a company's own "about" page.

## Method

```
seed → expand → corroborate → date → graph
```

1. **Seed**: one known identifier — name, domain, handle, address, photo.
2. **Expand**: registries, certificates, DNS, ASN, code hosts, social graph.
3. **Corroborate**: a second source type per node. Same-type echo (a scraped aggregator) is not a
   second source.
4. **Date**: retrieval timestamp per artifact; screenshots rot, save the text.
5. **Graph**: `maltego` or a plain `dot` file. Node type, edge type, confidence.

## References

| Load | When |
| --- | --- |
| `references/dorking.md` | building queries: Google, GitHub, certificate transparency |
| `references/geo-corp.md` | geolocation, corporate registries, people and email patterns |

## Core tooling

```bash
whois acme.com; dig +short MX acme.com; dig +short TXT acme.com
curl -s "https://crt.sh/?q=%25.acme.com&output=json" | jq -r '.[].name_value' | sort -u
curl -s "https://api.hackertarget.com/aslookup/?q=acme.com"
amass intel -org "Acme" -whois
theHarvester -d acme.com -b bing,duckduckgo,crtsh -l 300
```

People: `holehe` for account existence, `sherlock` for handles, breach corpora for email patterns.
Company: OpenCorporates, the local registry (AHU/SSM/Companies House/Delaware), trademark databases.

## Evidence

Save raw HTML, not just the rendered page. `wget --page-requisites` or `curl -s > raw.html`. Hash the
artifact, note the UTC time, and keep the URL that produced it. A claim without the saved response
is a memory.

## Report shape

| Node | Type | Confidence | Source |
| --- | --- | --- | --- |
| `acme-infra.net` | domain | high | crt.sh 2026-10-12 |
| `10.0.0.0/22` | netblock | medium | RIPE, org handle `ACME-NL` |

Then the narrative: what the graph means, what is unconfirmed, what to check next.

## Traps

- Aggregators (RocketReach, ZoomInfo) repeat each other; three copies are one source.
- A certificate on a shared CDN proves hosting, not ownership.
- WHOIS privacy is not anonymity; the registrar's record still has a jurisdiction and date.
- A photo's EXIF is often stripped by the platform — fetch the original.
- Time zones and date formats: `03/04` is ambiguous. Write ISO.
