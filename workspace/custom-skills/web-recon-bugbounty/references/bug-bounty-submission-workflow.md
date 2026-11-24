# Submitting Bug Bounty Findings — Compilation & Submission Workflow

## When to Use
After completing multi-phase audit across a target, you need to compile findings into a single HackerOne/bug bounty submission-ready report.

## Step 1: Gather All Phase Reports

Read all phase reports from `~/bugbounty-hunting/`:
```bash
ls ~/bugbounty-hunting/<target>-phase*.md
# → target-phase1.md, target-phase2.md, ..., target-phase6.md
```

## Step 2: Consolidate Findings Table

Create a master findings table with consistent severity ratings:

| # | Finding | Severity | CVSS | Bounty Est. |
|---|---------|----------|------|-------------|
| 1 | WP-JSON API exposure | MEDIUM | 5.3 | $1,000–$2,500 |
| 2 | SQL Injection | HIGH | 7.8 | $2,500–$5,000 |
| 3 | SEC filings exposed | CRITICAL | 9.1 | $8,000–$12,500 |

## Step 3: Write Unified Report

Format each finding with:
- **Description** — What is the vulnerability?
- **Proof of Concept** — Reproducible curl commands
- **Impact** — What can an attacker do?
- **Remediation** — How to fix it
- **CVSS Score** — Standardized severity rating

## Step 4: Submit to Platform

### HackerOne
1. Go to program page (e.g., `https://hackerone.com/hilton`)
2. Click "Submit report"
3. Fill in: Title, Description, CVSS, Impact
4. Attach PoC as markdown file
5. Request bounty range in description

### Immunefi
1. Go to program page
2. Click "Report bug"
3. Fill in: vulnerability type, impact, reproduction steps
4. Attach PoC video/gif if possible

### Direct Program
1. Find security contact in `.well-known/security.txt`
2. Send encrypted email with report
3. Use PGP key from security.txt

## Step 5: Bounty Negotiation

After submission:
1. **Don't over-explain** in initial submission — let triage team assess impact
2. **Include CVSS score** but be conservative (triagers may adjust)
3. **Mention bounty range** in submission notes if platform allows
4. **Follow up** after 5-7 business days if no response

## PoC Best Practices

1. **Reproducible** — Anyone should be able to run the same curl command
2. **Safe** — Don't actually exploit, just demonstrate the vulnerability
3. **Clear** — Show normal response vs vulnerable response
4. **Professional** — Include target info, date, researcher name

## Common Submission Formats

### HackerOne (single report with multiple findings)
- Title: "SQL Injection + Unauthenticated Access to SEC Filings on [target]"
- Severity: HIGH (highest severity finding determines baseline)
- Description: Combine all findings, prioritize CRITICAL and HIGH

### Separate Reports (when findings are independent)
- Report 1: "SQL Injection on CorpNews search endpoints" (HIGH)
- Report 2: "Unauthenticated access to SEC filings via WP Media API" (CRITICAL)
- Report 3: "WP REST API route exposure" (MEDIUM)

**Rule of thumb:** Submit separate reports for independent vulnerability classes. Submit combined reports for related findings on the same endpoint.

## Common Pitfalls

1. **Don't submit false positives** — always verify HTTP 000 vs WAF block before claiming SQLi
2. **Don't over-report low-severity findings** — WP-JSON route exposure alone is MEDIUM at best
3. **Don't skip CVSS scoring** — triagers may downgrade without standardized severity
4. **Don't combine independent vulns into one report** — each independent class deserves its own report for max bounty
5. **Don't reveal credentials** — if you find a leak, describe impact but don't include the full credential in the report
