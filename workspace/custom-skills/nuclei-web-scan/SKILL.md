
# Nuclei Web Scan Workflow

## Setup (one-time)
```bash
export PATH="$HOME/go/bin:$PATH"
nuclei -update-templates  # installs to ~/nuclei-templates/
```

## Template Categories
```
~/nuclei-templates/http/
  exposures/          - .git, .env, config files, source maps, API keys
  misconfiguration/   - default creds, debug modes, CORS, headers
  takeovers/          - subdomain takeover (dangling CNAME, DNS)
  cves/               - ~5000 CVE templates by vendor
  vulnerabilities/    - generic vuln classes (SQLi, XSS, SSRF, SSTI, etc.)
  fuzzing/            - directory/parameter fuzzing
  technologies/       - tech fingerprint (WAF, framework, server)
  token-spray/        - API token validation across services
  default-logins/    - default credential checks
  exposed-panels/    - admin panels, dashboards
```

## Scan Patterns

### Phase 1: Quick recon (parallel, background)
```bash
cat > /tmp/targets.txt << 'EOF'
https://target.com
https://app.target.com
https://api.target.com
EOF

# Run 4 parallel scans (use terminal background=true)
nuclei -l /tmp/targets.txt -t ~/nuclei-templates/http/exposures/ -severity medium,high,critical -rl 50 -timeout 8 -silent -nc -o /tmp/nuc-exp.txt &
nuclei -l /tmp/targets.txt -t ~/nuclei-templates/http/misconfiguration/ -severity medium,high,critical -rl 50 -timeout 8 -silent -nc -o /tmp/nuc-misc.txt &
nuclei -l /tmp/targets.txt -t ~/nuclei-templates/http/takeovers/ -severity medium,high,critical -rl 50 -timeout 8 -silent -nc -o /tmp/nuc-tk.txt &
nuclei -l /tmp/targets.txt -t ~/nuclei-templates/http/technologies/ -rl 50 -timeout 8 -silent -nc -o /tmp/nuc-tech.txt &
wait
cat /tmp/nuc-*.txt
```

### Phase 2: Targeted CVE + vuln scan
```bash
nuclei -u https://api.target.com -t ~/nuclei-templates/http/cves/ -severity medium,high,critical -rl 30 -timeout 10 -silent -nc -o /tmp/nuc-cve.txt
nuclei -u https://api.target.com -t ~/nuclei-templates/http/vulnerabilities/ -severity medium,high,critical -rl 30 -timeout 10 -silent -nc -o /tmp/nuc-vuln.txt
```

### Phase 3: Tag-based targeted scan
```bash
nuclei -u https://target.com -tags express,nodejs,cors -severity medium,high,critical -rl 30 -timeout 8 -silent -nc
nuclei -u https://target.com -t ~/nuclei-templates/http/vulnerabilities/generic/ -rl 20 -timeout 8 -silent -nc
```

## Key Flags
| Flag | Purpose |
|------|---------|
| `-l` | target list file |
| `-u` | single URL |
| `-t` | template dir/file |
| `-severity` | filter: info,low,medium,high,critical |
| `-rl` | rate limit (requests/sec) |
| `-timeout` | per-request timeout (sec) |
| `-silent` | suppress banner |
| `-nc` | no color output |
| `-o` | output file |
| `-tags` | filter by tech tag |
| `-j` | JSON output |

## Pitfalls
- `-bulk` flag does not exist in nuclei v3. Use `-rl` for rate limiting.
- Cannot use shell `&` in foreground terminal(). Use terminal(background=true) instead.
- CVE scans timeout at 180s for large target lists. Run per-target with `-u` not `-l`.
- False positives: `node-express-dev-env` matches on X-Powered-By Express header only, not actual env leak. Always verify with curl manually.
- SPA fallback: React/Vue SPAs return 200 for ALL paths (serving index.html). Verify response body size. If all paths return same byte count, it is SPA fallback, not a real endpoint.
- Cloudflare WAF may block nuclei requests or return 403 for all paths. Check with curl -sI first.
- execute_code is blocked for subprocess calls in cron mode. Use terminal() directly.

## Verification Flow
1. Nuclei reports finding. Run: curl -sI to check status code.
2. If 200: curl -s to check actual content (head -20).
3. If SPA (same index.html for all paths): false positive, kill it.
4. If real endpoint: check for actual sensitive data (env vars, creds, source code).
5. Run 7-Question Gate before reporting.

## Tech Detect Patterns
| Finding | Meaning |
|---------|---------|
| waf-detect:cloudflare | Cloudflare WAF present |
| aws-detect:aws-alb | AWS Application Load Balancer |
| tech-detect:express | Express.js backend |
| tech-detect:nginx / tech-detect:apache | Web server |
| tech-detect:nextjs | Next.js (SSR or static) |
| tech-detect:gitbook | GitBook documentation |
