# Self-Hosted Lab Targets for Web Bug Bounty Practice

Deploy these locally when no live target is available. All run on localhost, no internet required after initial pull.

## Quick Deploy Priority

### 1. OWASP Juice Shop (RECOMMENDED — one command)
```bash
# Fix docker socket permission first:
sudo chmod 666 /var/run/docker.sock

# Deploy:
docker run -d --name juice-shop -p 3000:3000 --restart unless-stopped bkimminich/juice-shop:latest

# Verify:
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200

# Access: http://localhost:3000
# Vulns: 200+ across OWASP Top 10 (SQLi, XSS, IDOR, SSRF, business logic, etc.)
# No setup required — runs standalone
```

### 2. DVWA (Damn Vulnerable Web App) — requires LAMP
```bash
# Install stack:
sudo apt-get install -y php php-mysql mysql-server apache2

# Start services:
sudo service mysql start
sudo service apache2 start

# Setup DB:
sudo mysql -u root -e "CREATE DATABASE dvwa; CREATE USER 'dvwa'@'localhost' IDENTIFIED BY 'p@ssw0rd'; GRANT ALL ON dvwa.* TO 'dvwa'@'localhost'; FLUSH PRIVILEGES;"

# Install:
cd /tmp && git clone --depth 1 https://github.com/digininja/DVWA.git
sudo cp -r DVWA/* /var/www/html/dvwa/
sudo cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php

# Configure:
sudo sed -i "s/\$_DVWA\['db_user'\] = 'root'/\$_DVWA['db_user'] = 'dvwa'/" /var/www/html/dvwa/config/config.inc.php
sudo sed -i "s/\$_DVWA\['db_password'\] = 'p@ssw0rd'/\$_DVWA['db_password'] = 'p@ssw0rd'/" /var/www/html/dvwa/config/config.inc.php

# Access: http://localhost/dvwa/
# Login: admin / password
```

### 3. WebGoat — requires Java + Node.js
```bash
cd /opt && sudo git clone --depth 1 https://github.com/WebGoat/WebGoat.git
cd WebGoat && npm install && npm start
# Access: http://localhost:8080/WebGoat
# Heavier setup, comprehensive lessons
```

## Bug Class Practice Order (Juice Shop)

| Order | Bug Class | Path/Challenge | Tool |
|-------|-----------|----------------|------|
| 1 | SQL Injection | Login, search | Manual + SQLMap |
| 2 | XSS (reflected/stored/DOM) | Search, comments, product reviews | XSStrike / manual |
| 3 | IDOR | User profiles, orders | Burp / curl |
| 4 | SSRF | URL fetch, image load | ffuf + payloads |
| 5 | Authentication bypass | Registration, login flow | Manual |
| 6 | Business Logic | Coupon codes, price manipulation | Manual + Burp |
| 7 | File upload | Profile picture upload | Burp + PHP reverse shell |
| 8 | Sensitive data exposure | .env, config files | Directory fuzz |
| 9 | CSRF | Profile update, email change | Burp CSRF PoC |
| 10 | Race conditions | Coupon redemption | Burp Repeater + turbo |

## Workflow: Practice → Report Template

1. Find vuln manually or with tool
2. Write curl one-liner PoC (reproducible, no browser needed)
3. Document: URL, parameter, payload, impact
4. Compare against real H1/Immunefi reports for report quality
5. Move to next bug class

## Docker Socket Permission Fix

If `docker` command fails with "permission denied":
```bash
ls -la /var/run/docker.sock
# Expected: srw-rw---- 1 root docker
# Fix:
sudo chmod 666 /var/run/docker.sock
# Or add user to docker group + newgrp:
sudo usermod -aG docker $USER
newgrp docker
```

## When Self-Hosted Practice Is Done

After Juice Shop is fully exploited (all challenges solved):
1. Remove Juice Shop: `docker stop juice-shop && docker rm juice-shop && docker rmi bkimminich/juice-shop`
2. Move to real target — use `bug-bounty-playbook` or `web-recon-bugbounty` skill
3. Check self-hosted bug bounty programs list (HackerOne filter, GitHub lists)
4. Target discovery: DeFiLlama → filter NO AUDIT → GitHub → source audit

## References
- Juice Shop: https://github.com/juice-shop/juice-shop
- DVWA: https://github.com/digininja/DVWA
- WebGoat: https://github.com/WebGoat/WebGoat
