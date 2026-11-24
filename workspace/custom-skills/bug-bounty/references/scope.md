# Scope

Scope is the contract. Parse it into a machine-checkable list before the first probe.

## Extract

- **In scope**: exact hosts, wildcards (`*.acme.com` — one label or all labels? the policy usually
  says), mobile apps (bundle id, APK link), API hosts, IP ranges, source repos.
- **Out of scope**: staging, status pages, third-party SaaS, `/blog`, marketing subdomains, DoS,
  automated scanners without rate limiting, social engineering, physical.
- **Rules**: request rate, required header (`X-Bug-Bounty: handle`), accounts allowed, whether
  `subfinder`-style enumeration is permitted.
- **Rewards & disclosure**: severity floor for payout, disclosure window, safe-harbor language.

## Wildcard semantics

`*.acme.com` in HackerOne terms covers one label (`api.acme.com`) and usually not
`a.b.acme.com`. A host that resolves to a third-party CDN is in scope only if the program says so.
CNAME to `acme.github.io` is a takeover candidate, not automatically in scope.

## Build the asset file

`state/scope.txt`, one host per line, plus `state/exclude.txt`. Filter every tool's output through
both before touching anything:

```bash
grep -F -f state/scope.txt all_hosts.txt | grep -v -F -f state/exclude.txt > live.txt
```

Regex for wildcards? Keep them literal and review the diff by hand for the first run.

## Request hygiene

Send the program header if required. Set a real UA. Rate limit to the stated value, or 5 rps if
none is given. Log every request you send (`-v` or a proxy) so a later "what did you touch" question
has an answer.

## Judgment calls

| Situation | Move |
| --- | --- |
| Host is out of scope but reachable from an in-scope app | report as "in-scope app depends on X"; usually accepted |
| Asset in scope, but the bug is in a third-party widget | test, report, note the vendor |
| Program silent on a new host you found | test lightly, disclose it in the report |
| Auth needed and self-signup is closed | ask the program for a test account before deep testing |
| Two programs claim the same asset | the older program wins; check both policies |
