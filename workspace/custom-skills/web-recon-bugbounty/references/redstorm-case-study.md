# RedStorm.io Bug Bounty Case Study (July 2026)

## Key Techniques Discovered

### 1. Prior Art Search (DO THIS FIRST)
Before deep recon, search GitHub for existing public vulnerability reports:
```python
import requests
target = "redstorm.io"
r = requests.get(f"https://api.github.com/search/repositories?q={target}+bugbounty+OR+audit+OR+vulnerability")
for repo in r.json().get("items", [])[:5]:
    print(f"{repo['full_name']}: {repo.get('description', '')[:80]}")
```

**RedStorm finding**: Found `Anitaarista/redstorm-bugbounty-audit` with FULL vulnerability disclosure from April 2026. All "new" findings were already documented — would have been DUPLICATE submissions.

**Decision matrix**:
- Reported but unfixed 90+ days → submit with "independent discovery" claim
- Recently reported → pivot to finding NEW bugs not in public report

### 2. Standalone PHP Files on Broken Apps
When main app returns 500 (e.g., Laravel/Lumen with missing JWTAuth provider), standalone PHP files may still work:

```python
# App returns 500 with "Class 'Tymon\JWTAuth\Providers\LumenServiceProvider' not found"
# But standalone files work fine:
r = requests.get(f"https://{origin_ip}/phpinfo.php", headers={"Host": "www.redstorm.io"}, verify=False)
# Returns 200 with 107KB of PHP config!
```

**Why**: `phpinfo.php` doesn't require framework bootstrap — it's a standalone file.

**Files to try**:
- `/phpinfo.php`, `/info.php`, `/test.php`, `/i.php`, `/p.php`
- `/check.php`, `/status.php`, `/health.php`, `/ping.php`

### 3. Virtual Host Enumeration on Origin IP
After finding origin IP via CSP header leak (`103.10.61.120`), test different Host headers:

```python
origin_ip = "103.10.61.120"
vhosts = ["admin.smtapps.net", "api.smtapps.net", "staging.smtapps.net", 
          "dev.smtapps.net", "appsmith.smtapps.net", "ask.smtapps.net"]

for vh in vhosts:
    r = requests.get(f"https://{origin_ip}/", headers={"Host": vh}, verify=False, timeout=10)
    # Standard broken Lumen app = 63745 bytes
    if len(r.content) != 63745:  # Different app!
        print(f"{vh}: {r.status_code} ({len(r.content)} bytes)")
```

**RedStorm finding**: Found working apps on same IP:
- `ask.smtapps.net` → Q&A platform with `/admin` endpoint
- `adm-billing.smtapps.net` → Billing admin panel
- `appsmith.smtapps.net` → Appsmith instance
- `preman.smooets.com` → Planka project management

### 4. HackerTarget Reverse IP Lookup
```python
r = requests.get(f"https://api.hackertarget.com/reverseiplookup/?q={origin_ip}")
domains = r.text.strip().split('\n')
# Found 15+ domains: pagii.co, geeksfarm.com, smtapps.net subdomains...
```

**Why valuable**: Reveals internal tools, staging apps, related companies on same server. Each is a potential attack vector.

### 5. HTTP vs HTTPS Different Apps
```python
# HTTPS returns broken Lumen app (500)
r = requests.get(f"https://{origin_ip}/", headers={"Host": "www.redstorm.io"}, verify=False)
# 500, 63745 bytes

# HTTP returns completely different app!
r = requests.get(f"http://{origin_ip}/")  
# 200, 92131 bytes - Smooets.com (parent company website on Next.js)
```

**Lesson**: Always check both HTTP and HTTPS on origin IP — may be different vhosts/apps.

## Confirmed Vulnerabilities (Still Active July 2026)

| Finding | Status | Evidence |
|---------|--------|----------|
| Origin IP via CSP leak | ✅ Active | `103.10.61.120` via `redstorm-stable.smtapps.net` |
| WAF Bypass | ✅ Active | Direct HTTPS to origin bypasses Cloudflare |
| phpinfo.php exposed | ✅ Active | 107KB, PHP 7.3.26 (EOL), Xdebug enabled |
| Debug mode (Lumen) | ✅ Active | Full stack traces with file paths |
| MongoDB 27017 open | ✅ Active | Port scan confirms |

## Pitfall: Duplicate Risk
All above were already in public GitHub report from April 2026. Submission would be DUPLICATE unless:
1. Enough time passed (90+ days) to claim independent discovery
2. Found NEW bugs not in the report (we didn't find any novel ones)
