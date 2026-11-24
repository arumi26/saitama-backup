# Bug Bounty Reporting Protocol & Scope Disclosure

**Context:** User expects honest scope disclosure and values consistent honesty over inflated claims. User tests work verification with direct questions ("Lu beneran nembus webnya?").

---

## Infrastructure Scan vs Application Penetration

Always distinguish clearly what was ACTUALLY tested:

### Infrastructure Scan (Automated)
- Port scans (nmap, direct curl)
- phpinfo.php / debug endpoints
- DNS enumeration
- Virtual host discovery
- Security header analysis
- MongoDB/Redis/database port checks
- Origin IP discovery (Cloudflare bypass)
- SSL/TLS cipher analysis
- Tech stack fingerprinting

### Application Penetration (Manual)
- 2FA bypass testing
- IDOR enumeration
- SQL injection
- XSS (reflected, stored, DOM-based)
- Auth bypass / session hijacking
- Business logic flaws
- CSRF exploitation
- Account takeover chains

**Rule:** Do NOT claim "penetrated the app" if you only ran infrastructure scans. User WILL verify with direct questions.

---

## Mandatory Duplicate Check

Before writing any bug bounty report, search for public disclosures:

```bash
# 1. GitHub search
site:github.com "target.com" (bugbounty OR vulnerability OR audit OR pentest OR security)

# 2. Google dorking
"target.com" (vulnerability OR exploit OR "bug bounty" OR "security audit")

# 3. Check common repo patterns
- target-bugbounty-audit
- target-security-report  
- target-vulnerability-disclosure
- target-pentest-report
```

### When Public Disclosure Exists

**Immediately disclose duplicate status:**
- Which findings are duplicates (cross-reference with public report)
- Original disclosure date and age (e.g., "90 days old")
- What was in original report but NOT tested in current scan
- Estimated payout impact (duplicates = low/rejected vs new bugs = full payout)

**Decision tree:**
- Disclosure < 30 days → Very likely duplicate/rejected
- Disclosure 30-90 days → Partial credit possible, depends on program
- Disclosure > 90 days + still unfixed → Report as "independent verification", expect discounted payout
- NEW attack vectors not in disclosure → Full credit possible

---

## Case Study: RedStorm (July 2026)

**What was tested (infrastructure scan):**
- ✅ Origin IP bypass (103.10.61.120)
- ✅ phpinfo.php exposed
- ✅ MongoDB port 27017 open
- ✅ Virtual host enumeration (ask.smtapps.net)

**What was NOT tested (blocked by Cloudflare 403):**
- ❌ 2FA bypass testing
- ❌ IDOR researcher profile enumeration
- ❌ SQL injection
- ❌ XSS
- ❌ Business logic flaws

**Duplicate check found:**
- GitHub repo: `Anitaarista/redstorm-bugbounty-audit` (April 19, 2026)
- **3/4 current findings = DUPLICATE** (phpinfo, MongoDB, origin IP)
- High-value bugs in April report (2FA bypass CVSS 9.8, IDOR CVSS 8.6) were NOT tested

**Outcome:**
- Disclosed duplicate status immediately
- Clarified scope limitations (Cloudflare blocks)
- Pivoted to application-level testing recommendation
- Estimated current report value: Rp 200-500K (vs Rp 1.5-2M if new bugs found)

**User reaction:** Verified scope honestly → trust maintained

---

## Scope Limitations & Cloudflare Blocks

When Cloudflare returns 403 on all application endpoints:

**Be honest:**
- "Cloudflare blocked application testing, only infrastructure was scanned"
- "Browser automation failed (Chrome lock error)"
- "Proxy doesn't bypass CAPTCHA challenge"

**Don't fabricate:**
- Never claim to have tested 2FA/IDOR/SQLi if you hit 403s
- Never invent test results or findings
- Never claim "full penetration" when blocked at WAF layer

**Offer alternatives:**
1. Manual browser testing (user does CAPTCHA solve)
2. Residential proxy + CAPTCHA solver API (2Captcha, AntiCaptcha)
3. Acknowledge limitation and pivot to different target
4. Focus on infrastructure bugs that ARE accessible

---

## Report Structure Template

```markdown
## Scope Verification

### ✅ What Was ACTUALLY Tested:
**Infrastructure (automated):**
- Port scan: MongoDB 27017 open
- phpinfo.php: Accessible at origin IP
- Origin IP bypass: 103.10.61.120 (Cloudflare bypass confirmed)
- Virtual hosts: ask.smtapps.net discovered

### ❌ What Was NOT Tested:
**Application Penetration (blocked/skipped):**
- 2FA bypass: NOT tested (Cloudflare 403 on /login)
- IDOR: NOT tested (Cloudflare 403 on /views/{id})
- SQL injection: NOT tested
- XSS: NOT tested

**Reason:** Cloudflare challenge blocks automated testing, browser automation failed

---

## Duplicate Status Check

**Public disclosure found:** 
- Source: GitHub `Anitaarista/redstorm-bugbounty-audit`
- Date: April 19, 2026 (90 days old)

**Duplicate findings:**
- ❌ phpinfo.php exposed → RS-EXP-002 in April report
- ❌ MongoDB 27017 open → RS-EXP-004 in April report
- ❌ Origin IP bypass → RS-EXP-001 in April report

**Potentially NEW:**
- ✅ ask.smtapps.net exposure (not in April report)

**High-value bugs from April report (NOT tested by current scan):**
- 2FA bypass (CVSS 9.8) → Rp 1,000,000+
- IDOR researcher profiles (CVSS 8.6) → Rp 800,000+
- Laravel debug mode (CVSS 7.5) → Rp 300,000+

---

## Estimated Payout

**Current findings (3/4 duplicate):**
- Expected: Rp 200,000 - 500,000
- Risk: May be rejected as duplicate/verification-only

**If NEW bugs found (application-level testing):**
- Potential: Rp 1,500,000 - 2,000,000
- Requires: Bypass Cloudflare + test 2FA/IDOR/SQLi

**Recommendation:** Pivot to application-level testing or choose different target
```

---

## Key Principles

1. **Separate fact from assumption** — "I scanned X" vs "I didn't test Y"
2. **Check duplicates BEFORE writing report** — saves time, maintains credibility
3. **Be honest about blocks** — Cloudflare 403 is a legitimate limitation
4. **Quantify scope** — list what WAS and WASN'T tested explicitly
5. **User values honesty** — consistent truthfulness > inflated claims

User preference (from session): *"Tests my honesty by asking verification questions. Values consistent, honest answers over inflated claims."*
