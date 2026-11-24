# Bug Bounty Hunting Workflow — July 2026 Session

## Session Summary
Created comprehensive bug bounty hunting setup based on Reddit hunter methodology (60+ bugs, 4 months, $$$$ bounties).

## Files Created
- `~/bugbounty-hunting/CLAUDE.md` — Strict rules, scope whitelist, compaction survival block
- `~/bugbounty-hunting/HUNTING_WORKFLOW.md` — Step-by-step workflow (recon → test → report → submit)
- `~/bugbounty-hunting/MCP_CONFIG.md` — MCP setup (Burp, Nuclei, ffuf, SQLMap, XSStrike, SSRFMap)
- `~/bugbounty-hunting/TRACKING_TEMPLATE.md` — Metrics tracking (bugs, payouts, success rates)
- `~/bugbounty-hunting/TARGET_LIST.md` — Fresh target list (July 2026)
- `~/bugbounty-hunting/QUICK_START.md` — Quick start guide with daily/weekly/monthly workflow

## Key Learnings

### 1. Compaction Survival Block
After compact, re-read immediately:
```
CURRENT TARGET: [PROGRAM NAME]
CURRENT GOAL: [e.g., "Find IDOR in /api/users"]
SCOPE: [e.g., "*.target.com"]
FINDINGS SO FAR: [e.g., "2 IDORs, 1 auth bypass"]
NEXT STEPS: [e.g., "Test billing endpoints"]
BUG CLASSES TESTED: [e.g., "IDOR, auth bypass"]
BUG CLASSES TO TEST: [e.g., "SQLi, XSS, business logic"]
```

### 2. Bug Class Priority Order (8-week cycle)
```
Week 1: IDOR (highest success rate for LLM)
Week 2: Auth bypass (role manipulation, token issues)
Week 3: Business logic (billing, pricing, quantity)
Week 4: Exposed secrets (API keys, credentials, .env)
Week 5: SQLi (with SQLMap MCP)
Week 6: XSS (with XSStrike MCP)
Week 7: SSRF escalation (with SSRFMap MCP)
Week 8: Multi-class chaining (combine findings)
```

### 3. Self-Hosted Program Strategy
Why hunt self-hosted:
- Less competition (fewer hunters)
- Faster response (direct security team)
- Better payouts (relationships = bigger bounties)
- More bugs (less mature security)

Where to find:
- `lissy93/bug-bounties` repo — 3,000+ programs, YAML format
- `karemelsqary/self-hosted-bug-bounty-programs` repo — 36 self-hosted programs with contacts
- HackerOne "self-hosted" filter
- Bugcrowd "private" programs

### 4. Anti-Patterns to Avoid
1. Don't test without scope confirmation
2. Don't write reports without PoC
3. Don't submit false positives (damages reputation)
4. Don't ignore existing reports (check for duplicates)
5. Don't spend hours on one endpoint (pivot after 30 min)
6. Don't accept "system is too secure" (always pivot)

### 5. Expected Earnings
```
Month 1: $2,000-$5,000 (5-7 bugs)
Month 2: $5,000-$10,000 (10-15 bugs)
Month 3: $10,000-$20,000 (15-25 bugs)
Month 6: $20,000-$50,000 (30-50 bugs)
Year 1: $50,000-$100,000+ (60-100+ bugs)
```

## MCPs for Bug Bounty
- **Burp Suite MCP** — Proxy traffic analysis
- **Nuclei MCP** — Template-based scanning
- **ffuf MCP** — Fuzzing endpoints
- **SQLMap MCP** — SQLi automation
- **XSStrike MCP** — XSS detection
- **SSRFMap MCP** — SSRF chaining

## Hunting Workflow
1. **Morning**: Check new programs, review disclosed reports, start target
2. **Afternoon**: Deep testing, write PoCs, submit reports
3. **Evening**: Review submissions, update metrics, plan next day

## Daily Workflow
```
Morning (9 AM - 12 PM):
1. Check for new bug bounty programs
2. Review disclosed reports for patterns
3. Start new target or continue existing

Afternoon (1 PM - 5 PM):
4. Deep testing on high-priority targets
5. Write PoCs for confirmed findings
6. Submit reports

Evening (6 PM - 9 PM):
7. Review submissions and responses
8. Update metrics and tracking
9. Plan next day's targets
```

## Success Formula
```
Consistency + Focus + Learning = Success
```

## Key Insight
> "Every system has bugs. I just prove it."
