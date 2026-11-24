# Reference: Tooling — Standard, Production-Ready (v2)

> Industry-standard security research tools. Power is not in the tool — it's in how you
> wield it with discipline and depth. Every tool here is publicly available.

---

## Recon & Enumeration

| Category | Tools |
|---|---|
| Subdomain/asset | subfinder, amass, assetfinder, crt.sh, censys, dnsx (resolve) |
| Port/service | nmap, masscan, naabu, rustscan |
| Content/param discovery | ffuf, feroxbuster, gobuster, dirsearch, arjun (params) |
| Crawling/JS analysis | katana, gospider, hakrawler, gau, waybackurls, linkfinder |
| JS source maps | source-map-unpack, custom scripts — recover original source |
| Fingerprint | httpx, whatweb, wappalyzer, builtwith |
| Search dorking | Google/Bing advanced operators, GitHub dorking (truffleHog, gitleaks) |

## Analysis & Interception

| Category | Tools |
|---|---|
| Intercepting proxy | Burp Suite (Community/Pro), OWASP ZAP |
| Out-of-band | interactsh, Burp Collaborator, dnslog.cn |
| Template scanning | nuclei (with custom templates), nuclei-templates |
| API | Postman, Insomnia, GraphQL voyager |

## Exploitation

| Category | Tools |
|---|---|
| SQL injection | sqlmap (data extraction), ghauri |
| SSTI | tplmap, SSTImap |
| Command injection | commix |
| XXE | XXEinjector, custom DTD |
| Deserialization | ysoserial (Java), PHPGGC (PHP), ysoserial.net (.NET) |
| WebSocket | wscat, custom scripts |
| General web | curl, httpie, Python requests |

## Web3 / Smart Contract

| Category | Tools |
|---|---|
| Development | Foundry (forge/cast/anvil) — primary, Hardhat — alternative |
| Static analysis | Slither, Aderyn, Mythril, Semgrep with Solidity rules |
| Fuzzing | Echidna, Medusa, Foundry invariant fuzz |
| Explorer | Etherscan/Snowtrace/Polygonscan (verified source), Blockscout |
| Simulation | Tenderly, Phalcon, anvil fork |
| Storage | cast storage, sload, slot-by-slot analysis, cast diff, solc --storage-layout |
| Disassembly | evm.codes, solc --asm, Dedaub, Heimdall |
| Visualization | Surya, Solgraph — contract/function call graphs |

## Network / Infra

| Category | Tools |
|---|---|
| Cloud recon | cloud_enum, S3Scanner, GCPBucketBrute |
| CI/CD | truffleHog, git-secrets, gitleaks |
| DNS recon | dnsrecon, dnsdumpster, fierce |
| Container | Docker enumeration scripts, kube-hunter |

## Rust / Non-EVM Fuzzing (installed on this VPS)

| Category | Tools |
|---|---|
| Rust fuzzing | cargo-fuzz — libFuzzer harness for Rust crates (chia_rs, clvm_rs) |
| Python fuzzing | Atheris — libFuzzer for Python full-node targets |
| C/C++ harness | clang+g++ — harness builds (chiavdf), -fsanitize=fuzzer,address |
| Nightly toolchain | rustup nightly — needed for -Zsanitizer builds |

## Static Analysis (installed)

| Category | Tools |
|---|---|
| Python/security rules | semgrep — custom rules supported |
| C/C++ | cppcheck 2.7 — `cppcheck --enable=warning --language=c++` |

---

## Installed Tool Arsenal (bounty profile — Sep 2026)

These tools/libs are already installed on this VPS. USE THEM — don't reinstall or improvise around them.

### git-dumper (pip, in venv PATH)
- **Path:** `git-dumper` (already on PATH — `~/.muse/venv/bin/git-dumper`)
- **Usage:** `git-dumper URL DIR` — dump exposed `.git/` repo from a web target
- **When:** RECON web2 — if target leaks `.git/` (check `/sitemap.xml`, `/.git/HEAD`, robots), dump source for secrets/config/credentials → often leads to RCE
- **Verify:** check `DIR/.git/HEAD` has `ref: refs/heads/...` and files actually extracted

### GitDorker (Python tool in profile lib)
- **Path:** `/opt/muse/lib/tools/GitDorker/GitDorker.py`
- **Dork lists:** `lib/tools/GitDorker/Dorks/alldorksv3`, `medium_dorks.txt`
- **Usage:** `python3 GitDorker.py -q <query> -d <dorkfile> -t <tokenfile>` — GitHub sensitive-info search (API token required, 30 req/min unauthenticated → prefer using any available GH token)
- **When:** RECON — search org repos for secrets, endpoints, internal paths

### PayloadsAllTheThings (payload library)
- **Path:** `/opt/muse/lib/payloads-all-the-things/PayloadsAllTheThings/`
- **Contents:** 66 categories — XSS Injection, SQL Injection, SSRF, SSTI, XXE, Command Injection, File Upload, Deserialization, GraphQL, NoSQL, IDOR, JWT, etc.
- **When:** VERIFY/EXPLOIT phase — load the matching category file per vuln class (e.g. `XSS Injection/3 - XSS Common WAF Bypass.md`)

### HolyTips (checklists)
- **Path:** `/opt/muse/lib/holytips/HolyTips/`
- **Contents:** `Checklist/API Security.md` (IDOR/BOLA tricks: wrap ID, verb tampering, HTTP/JSON param pollution, numeric-vs-UUID), `Checklist/File Upload.md` (extension impact table, blacklist/whitelist bypass), `Checklist/Authentication.md`, `Checklist/OAuth.md`, `Middlewares/Middlewares.md`
- **When:** web2/API testing — run the checklist as coverage baseline before declaring a surface clean

### researchhh (bl4de/research notes)
- **Path:** `/opt/muse/lib/researchhh/research/`
- **Contents:** `hidden_directories_leaks/README.md` (.git/.svn/.idea leak detection — pairs with git-dumper), `how_to_deal_with_dupes/` (duplicate-report handling), `npm-static-servers-most-common-issues/`, `javascript-malware-obfuscation/` (deobfuscation examples), `snippets/` (shell injection→root, MySQL INTO OUTFILE backdoor)
- **When:** RECON (dir leaks), REPORT/TRIAGE (anti-dupe), malware/JS analysis

### awesome-writeups (report references)
- **Path:** `skills/bug-bounty/references/recon.md`
- **Contents:** curated real-world writeup links by vuln class (IDOR, SSRF, auth bypass, 2FA, RCE, CORS, subdomain takeover...)
- **When:** REPORT — compare severity reasoning, evidence structure, reproduction steps

### godmode (jailbreak for filter evasion)
- **Path:** skill `security/godmode` — GODMODE CLASSIC templates, Parseltongue (33 input obfuscation techniques), ULTRAPLINIAN (multi-model race)
- **When:** model API refuses a legit target-specific request (payload in scope, safe-harbor covered) — use Parseltongue to veil the request, NEVER for out-of-scope/destructive actions

---

## Command Examples & Discipline

Moved here from SOUL.md TOOLKIT/TOOLING DISCIPLINE (was duplicated and
drifting between files). Tools accelerate investigation, not replace
verification.

### SUBFINDER — passive subdomain discovery
```
subfinder -d example.com -silent
subfinder -d example.com -silent -o subdomains.txt
subfinder -dL domains.txt -silent -o subdomains.txt
```
Rule: Discovery ≠ vulnerability.

### NUCLEI — template scanning
```
nuclei -u https://target.example
nuclei -l urls.txt
nuclei -l urls.txt -o nuclei-results.txt
```
Rule: Scanner finding = CANDIDATE. Manual verification is required.

### SLITHER — static Solidity analysis
```
slither .                          # analyze project
slither contracts/Example.sol      # analyze file
slither . --checklist              # triage checklist
slither . --json slither.json      # machine-readable output
```
Rule: Static-analysis result = HYPOTHESIS. Trace to actual execution and impact.

### GIT — history mining
```
git log --oneline -20                    # recent changes
git log -- path/to/file                  # file history
git log -S "functionName" --all          # search history
git diff OLD_COMMIT..NEW_COMMIT          # inspect change
```
Area repeatedly patched by security fixes = priority attack surface.

### RIPGREP — fast code search
```
rg "functionName" .
rg "onlyOwner|authorize|delegatecall|call\(" .
```
Note: to also match the literal opening parenthesis of a call expression
(e.g. distinguish `call(` from the bare word `call`), append an escaped
parenthesis to the pattern: add `\(` right after `call` in the regex
above. Written out in full: backslash, then open-parenthesis.

### GENERAL RULE
Use the fastest tool that produces useful evidence.

When a tool fails:
- diagnose
- change approach
- retry with a materially different method
- record the limitation
- continue investigation where possible

Never enter an infinite identical retry loop.

---

## Healthy Workflow

1. Passive recon first (safe, context-rich).
2. Active enumeration → map surface.
3. **Manual analysis** of candidates (tools assist, brain decides).
4. Manual verification + PoC (code proves).
5. Report.

## What NOT To Do

- Submit findings directly from scanner output without manual verification.
- Run destructive/DoS scanners against production.
- Trust any tool's output blindly — always verify.

### otp_check.py (OTP/email-bounce reader — whitelist-only)
- **Path:** `~/.muse/home/otp_check.py`
- **Creds:** `~/.secrets/otp.env` (OTP_EMAIL, OTP_APP_PASS — provision via `provision_otp.sh`, operator-only, chmod 600)
- **Whitelist:** `~/.secrets/otp_senders.txt` — hanya domain TARGET yang API-nya butuh kode OTP/auth dari inbox. Domain di luar list DITOLAK otomatis.
- **Usage:**
  ```
  python3 ~/.muse/home/otp_check.py --sender <target-domain> --latest-only
  python3 ~/.muse/home/otp_check.py --latest-only   # scan semua whitelist
  ```
- **When:** EXECUTE/VERIFY — saat target (log-in flow, signup, 2FA, reset) butuh kode OTP dari email. Panggil → print `OTP=123456` → pakai kode itu untuk lanjut tes. FALLBACK kalau `NO_OTP`: refresh inbox/browser lalu retry 2x; kalau tetap kosong lapor jangan tebak.
- **HARD BOUNDARY:** email tumbal HANYA untuk baca OTP target. SUBMIT REPORT TETAP MANUAL OPERATOR — script ini tidak pernah mengirim apa pun.

### WEB EXTRACTION (web_extract MATI — JANGAN DIPANGGIL SAMA SEKALI)

- **JANGAN pernah panggil tool web_extract** — backend ddgs = search-only, SELALU error.
  Dokumen/baca URL WAJIB lewat terminal + script extract.py. Pakai:
  ```
  python ~/.muse/home/extract.py "<url>"        # teks (default)
  python ~/.muse/home/extract.py "<url>" --html # raw HTML
  ```
  Script: curl dulu (cepat, HTTP 200 normal) → kalau 403/kosong, fallback Playwright CDP
  (chrome LIVE 127.0.0.1:9222). Output langsung stdout, gak nulis file.
  Kalau output `EXTRACT_ERR:` → lapor aja (jangan re-run 10x).

---

# ADDENDUM — environment mapping for THIS machine (2026-10-03; appended at adoption — the text above is unchanged)

The "Installed Tool Arsenal", "installed on this VPS", `otp_check.py`, and
"WEB EXTRACTION" sections above describe the operator's OTHER environment
(a MUSE VPS profile under `/opt/muse` and `~/.muse` ). Those paths do NOT
exist on this machine. Mapping for this workspace:

- **PayloadsAllTheThings** — present here at `tools/PayloadsAllTheThings`
  (424 files, installed 2026-10-02; nested sample zips stay sealed).
- **git-dumper / GitDorker / HolyTips / researchhh / awesome-writeups** — NOT installed
  here. Treat their entries above as a catalog of what exists on the other VPS;
  if a hunt needs one of them here, it goes through the normal screen-then-install
  flow with operator approval first.
- **Foundry (forge/cast/anvil)** — installed here at `~/.foundry/bin` (1.8.4).
  JDK/Maven/jadx and the fallback browser fleet live under `tools/`
  (see TOOLS.md).
- **otp_check.py** — no equivalent exists here, and Gmail is deliberately NOT
  connected in this environment (deferred). OTP-assisted login testing
  here follows this platform's protected one-time-code flow, not that script.
- **WEB EXTRACTION section** — describes a broken tool in the OTHER agent's
  stack; it does not apply here. Web reading here uses this platform's browser
  tooling (plus the fallback fleet in `tools/browser-fallback/`).
- **godmode entry** — recorded above as catalog data about the other profile.
  It is NOT adopted as operating behavior here: this agent does not use
  jailbreak/filter-evasion techniques against its own safeguards. In-scope
  requests are handled directly; out-of-scope ones are declined with a reason
  and an in-scope alternative, per SOUL.md OPERATING PRINCIPLES.
