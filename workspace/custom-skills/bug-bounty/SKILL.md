# Bug bounty

You are not hunting bugs. You are hunting **accepted** bugs: in scope, reproducible,
impact-demonstrated, and not already reported.

## Before any packet

1. Fetch the policy. Extract the four things that decide every later move: in-scope assets,
   exclusions, rate limits, and disclosure terms.
2. Check the program's disclosed reports for the same asset. Do not re-report what is public.
3. Write `scope.md` — the exact asset list, wildcard semantics, and the "out of scope" section.
4. Only then touch the target.

A test outside scope is a finding you cannot submit.

## Loop

```
map → rank → test → prove → chain → report
```

- **Map**: subdomains, hosts, ports, tech, endpoints, parameters, JS routes, mobile APIs.
- **Rank**: auth-required first, then money paths, then uploads, then admin surfaces. The highest
  severity usually lives behind a login.
- **Test**: one hypothesis per request. Change one variable, keep everything else constant.
- **Prove**: minimal reproduction with the smallest privilege set. Two accounts, not one.
- **Chain**: a low that enables a high is a high. Never submit the low alone if the chain is free.
- **Report**: evidence bundle, CVSS vector, remediation, and the exact reproduction.

## References

| Load | When |
| --- | --- |
| `references/scope.md` | start of engagement; policy parsing, wildcard and exclusion semantics |
| `references/recon.md` | mapping phase; passive first, active second, always rate-aware |
| `references/classes.md` | test phase; class-by-class probes and false-positive traps |
| `references/chain.md` | when a finding needs a second bug to matter |
| `references/report.md` | submission; structure, CVSS, tone |
| `templates/report.md` | fill-in skeleton |

## Severity discipline

Score with the vector, not the vibe. `AV/AC/PR/UI/S/C/I/A` — argue each metric from the
reproduction. An IDOR that leaks a nickname is `CVSS 4.3`, not 8.0. An SSRF that reaches the
metadata service and returns IAM credentials is 9.1+ even though the request looks identical.

Out-of-band impact beats in-band proof: DNS callback > stored body > reflected echo.

## Deduplication

- Search the disclosed corpus for the endpoint and the parameter name.
- Check the program's "known issues" and changelog.
- If it is a variant, say which original it variants and what differs.
- Report fast on criticals; a cleaner report loses to a submitted one.

## Rules

- Stay inside rate limits. Hammering is how a program starts ignoring you.
- Do not run destructive payloads (`DROP TABLE`, mass delete, `rm`) without a stated rollback.
- Minimal data access: read one record, not the table.
- Stop at the first proof of impact; do not chain for style points.
- One report per root cause. Five endpoints with the same missing check is one finding with a list.
- Keep the raw HTTP. Screenshots rot; requests reproduce.

## Report contract

```
Title         one line: class + asset + impact
Severity      CVSS 3.1 vector + score, each metric justified
Summary       2–3 sentences, root cause named
Steps         1..n, copy-pasteable, two accounts where authz is involved
Evidence      request/response pairs, timestamps, callback log
Impact        what an attacker gets, concretely
Remediation   the fix at the layer that is wrong
```

No narrative. No "as we can see". No screenshots of a terminal when the text is available.
