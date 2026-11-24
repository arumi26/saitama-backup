---
skill: virtual-hosts
title: "Virtual Host Discovery & Routing Abuse"
category: "Security · Recon"
load_when: "virtual host, vhost, vhost fuzzing, host header routing, hidden vhost, internal vhost, host header bypass"
pack: SUPERAGENT V10
bughunt: true
---

# Virtual Host Discovery & Routing Abuse

## Where it pays
The same IP often serves multiple apps by Host header. Fuzzing vhosts reveals staging/internal/admin apps not linked anywhere — fresh, un-tested surface.

## Attack-surface signals
A single IP behind many domains, wildcard DNS, CDNs; apps that route on Host; 403/404 on the main host but different content for other Host values.

## Methodology
1. Collect candidate names (subdomain enum, cert SANs, wordlists). 2. Fuzz the Host header against the IP (ffuf -H 'Host: FUZZ'). 3. Diff responses to find distinct vhosts (staging, admin, internal). 4. Also try Host-header routing bypass to internal-only vhosts.

## Payloads / probes
```
ffuf -u http://TARGET_IP -H 'Host: FUZZ.target.com' -w vhosts.txt -fs <baselen>
curl -H 'Host: admin.internal' http://TARGET_IP/
curl -H 'Host: staging.target.com' http://TARGET_IP/
```

## Root causes
Host-based routing exposes apps not meant to be public; default/fallback vhost serves sensitive content; no auth on internal vhosts.

## Validation gate
Show access to a distinct, sensitive vhost (staging/admin/internal) reachable via the Host header on an in-scope IP.

## Impact & chains
Access to hidden/internal apps, fresh attack surface, auth bypass. Chains with recon/subdomain and reverse-proxy-misconfig.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "virtual host, vhost, vhost fuzzing, host header routing, hidden vhost, internal vhost, host header bypass"
```

→ Report with `../reporting/writeup.md` (CWE-284); validate with `../reporting/validation-gate.md`.
