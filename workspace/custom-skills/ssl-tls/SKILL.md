---
skill: ssl-tls
title: "SSL/TLS Security"
category: "Security · Web"
load_when: "ssl tls, certificate, heartbleed, weak cipher, tls misconfig, cert validation, mitm, hsts"
pack: SUPERAGENT V10
bughunt: true
---

# SSL/TLS Security

## Where it pays
TLS misconfig enables MITM, data interception, and trust bypass — easy wins on any HTTPS scope.

## Attack-surface signals
Any HTTPS endpoint; cert details; TLS version/cipher; HSTS header; cert pinning in mobile/thick clients.

## Methodology
1. Scan with testssl.sh / sslyze — note TLS version, ciphers, cert chain.
2. Weak protocols (SSLv3, TLS 1.0/1.1), weak ciphers (RC4, DES, EXPORT), no PFS.
3. Cert issues: expired, self-signed, wrong CN/SAN, weak key (<2048 RSA), SHA-1.
4. Known CVEs: Heartbleed, POODLE, BEAST, ROBOT, Logjam, FREAK.
5. Missing HSTS / HSTS bypass; cert validation bypass in clients (accept-all).
6. mTLS misconfig; cert pinning bypass (pairs with mobile skills).

## Payloads / probes
```
testssl.sh https://target
sslyze --regular target:443
nmap --script ssl-enum-ciphers,ssl-heartbleed -p 443 target
openssl s_client -connect target:443 -tls1
```

## Root causes
Weak cipher/protocol enabled · outdated TLS stack · cert not validated client-side · missing HSTS · private key disclosure (Heartbleed).

## Validation gate
Demonstrate a weak protocol/cipher negotiated, a known-CVE response, or cert-validation bypass — not just a scanner banner.

## Impact & chains
MITM / data interception · trust bypass · (Heartbleed) memory/key leak. Chains with mobile pinning bypass and auth/session.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "ssl tls, certificate, heartbleed, weak cipher, tls misconfig, cert validation, mitm, hsts"
```

→ Report with `../reporting/writeup.md`; validate with `../reporting/validation-gate.md`.
