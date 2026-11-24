# Self-Hosted Bug Bounty Program Hunting

## Why Hunt Self-Hosted Programs
- **Less competition** — fewer hunters than HackerOne/Bugcrowd
- **Faster response** — direct security team, no triage queue
- **Better payouts** — relationships = bigger bounties
- **More bugs** — less mature security, fewer eyes

## Where to Find Self-Hosted Programs

### GitHub Repos
```bash
# karemelsqary/self-hosted-bug-bounty-programs
curl -s 'https://api.github.com/repos/karemelsqary/self-hosted-bug-bounty-programs/contents/self-hosted-bug-bounty-programs.md' | \
  jq -r '.content' | base64 -d

# lissy93/bug-bounties (3000+ programs)
curl -s 'https://api.github.com/repos/lissy93/bug-bounties/contents/independent-programs.yml' | \
  jq -r '.content' | base64 -d
```

### Top Self-Hosted Programs (July 2026)
| Program | Max Bounty | Contact |
|---------|------------|---------|
| Google VRP | $100K+ | security@google.com |
| Kraken | $100K+ | bugbounty@kraken.com |
| Telegram | $100K | security@telegram.org |
| Samsung Mobile | $20K | mobile.security@samsung.com |
| Proton | $10K | security@proton.me |
| Zoho Corp | $3K | security@zohocorp.com |
| atmail.com | $5K | security@atmail.com |
| aurasell.ai | $1K | security@aurasell.ai |

## Target Scoring (go if >= 6/10)
- Self-hosted program: +2
- Fast response (< 48h): +2
- Good bounty range ($1K+): +2
- Less competition (not on HackerOne): +1
- Complex auth (OAuth2, SSO): +1
- API endpoints exposed: +1

## Recon Workflow for Self-Hosted Programs

### 1. Check security.txt
```bash
curl -s "https://TARGET/.well-known/security.txt"
```

### 2. Check bug bounty page
```bash
curl -s "https://TARGET/bug-bounty" | grep -E "(scope|bounty|reward|severity|submission|email|contact)"
```

### 3. Check for exposed API keys in JS
```bash
curl -s https://TARGET | grep -E "(api_key|apiKey|API_KEY|secret|SECRET|token|TOKEN|auth|AUTH)"
```

### 4. Check hidden pages
```bash
# Check sitemap for hidden pages
curl -s "https://TARGET/sitemap.xml" | grep -oP '<loc>[^<]+</loc>' | grep -i "hidden\|test\|internal\|admin"
```

## PostHog API Key Exposure Pattern

### What to look for
PostHog project API keys are often exposed in client-side JavaScript:
```javascript
posthog.init('phc_XXXXXXXXXXXXXXXXXXXXXXXX', {
    api_host: 'https://us.i.posthog.com',
    ...
});
```

### Impact
- **Event injection** — Can send fake analytics events
- **Feature flag enumeration** — Can query `/decide/` endpoint
- **Project config disclosure** — Session recording, autocapture settings

### PoC — Send Fake Event
```bash
curl -X POST "https://us.i.posthog.com/capture/" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_XXXXXXXXXXXXXXXXXXXXXXXX",
    "event": "fake_event",
    "properties": {"distinct_id": "attacker"}
  }'
```

### PoC — Get Feature Flags
```bash
curl -X POST "https://us.i.posthog.com/decide/" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "phc_XXXXXXXXXXXXXXXXXXXXXXXX",
    "distinct_id": "attacker"
  }'
```

### Severity
- **Low** — Can only send events, not read data
- **Medium** — If feature flags reveal sensitive config
- **Report as** — Sensitive Data Exposure (CWE-200)

## Hidden Pages Discovery

### Common hidden page patterns
```
/hidden-pages/*
/form-test
/internal/*
/admin/*
/dashboard/*
/test/*
/dev/*
/staging/*
```

### Check sitemap
```bash
curl -s "https://TARGET/sitemap.xml" | grep -oP '<loc>[^<]+</loc>'
```

### Check robots.txt
```bash
curl -s "https://TARGET/robots.txt"
```

## Bug Bounty Report Submission

### User preference (Nanwasa)
- **Format:** Plain text, copy-paste ready
- **Delivery:** Direct in chat (not as file for small reports)
- **Language:** English for reports, Indonesian for explanation

### Report template
```
Subject: Bug Bounty Report — [VULNERABILITY TITLE]

Dear [TARGET] Security Team,

## Summary
[1-2 sentence description]

## Vulnerability Details
**Type:** [CWE]
**Severity:** [Low/Medium/High/Critical]
**Affected System:** [URL/endpoint]

### Description
[Detailed description]

### Exposed Key/Data
[Exact data found]

### PoC
[Command to reproduce]

## Impact
[What an attacker can do]

## Recommended Fix
[How to fix]

## Timeline
- [DATE]: Discovered
- [DATE]: Submitted

Best regards,
Security Researcher
```

## Pitfalls
- **PostHog keys are project keys, not personal keys** — Can only send events, not read data. Don't overstate impact.
- **Hidden pages may not contain sensitive data** — Check content before reporting.
- **Self-hosted programs may have slower response times** — Some take 30+ days to respond.
- **Check exclusions before submitting** — Many programs exclude informational findings.
