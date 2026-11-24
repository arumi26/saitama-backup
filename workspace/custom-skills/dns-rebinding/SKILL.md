---
skill: dns-rebinding
title: "DNS Rebinding"
category: "Security · Web"
load_when: "dns rebinding, rebind, ssrf dns, ip rebinding, localhost rebind, singularity, internal service access"
pack: SUPERAGENT V10
bughunt: true
---

# DNS Rebinding

## Where it pays
Rebinding a hostname from your IP to an internal IP after the TTL expires lets a victim's browser (or an SSRF fetcher) reach internal services — bypasses IP allowlists.

## Attack-surface signals
Browser-based apps talking to `localhost`/LAN services, IoT/dev servers with no auth, SSRF fetchers that re-resolve DNS, 'connect to my local app' features.

## Methodology
1. Host a domain with very low TTL, first resolving to your server. 2. Victim loads your page; after TTL, rebind the domain to 127.0.0.1 / internal IP. 3. Same-origin requests now hit the internal service. 4. Read/act on the unauthenticated internal API.

## Payloads / probes
```
# attacker DNS: A record TTL=1
first → attacker_ip
then  → 127.0.0.1  (or 169.254.169.254 / 192.168.x)
fetch('http://rebind.attacker.com:8080/admin')
```

## Root causes
Services trust the Host/origin not the resolved IP; no auth on localhost/LAN services; fetchers re-resolve without pinning.

## Validation gate
Show access to an internal/localhost service a remote attacker shouldn't reach, achieved via the rebind.

## Impact & chains
Internal service access, metadata/credential theft, LAN pivot. Chains with web/ssrf and cloud-misconfig.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "dns rebinding, rebind, ssrf dns, ip rebinding, localhost rebind, singularity, internal service access"
```

→ Report with `../reporting/writeup.md` (CWE-350); validate with `../reporting/validation-gate.md`.
