---
skill: chaining
title: "Chaining Catalog"
category: "Security · Bug-Hunt Core"
load_when: "Phase 04, after any finding, to escalate impact."
pack: SUPERAGENT V10
bughunt: true
---
# Chaining Catalog
Read primitive → desired capability → connector.

| Start | Connector | Result |
|---|---|---|
| Open redirect | OAuth redirect_uri / token in URL | **ATO** |
| IDOR (read) | leaked id / email-change endpoint | IDOR(write)/reset → **ATO** |
| SSRF | cloud metadata 169.254.169.254 | IAM creds → **infra** |
| Blind XSS | fires in admin panel | admin session → **full compromise** |
| File upload | path/filename/Content-Disposition control | stored XSS / webshell → **RCE/ATO** |
| CORS reflect + creds | authed JSON cross-origin | data exfil |
| LFI | log/session poisoning / PHP wrappers | **RCE** |
| SQLi | stacked / INTO OUTFILE | dump / **RCE** |
| Mass assignment role=admin | privileged API reachable | **priv-esc** |
| GraphQL batching | OTP/rate-limit bypass | brute → **ATO** |
| Subdomain takeover | parent cookies / OAuth whitelist | session/token theft |

## Operator pattern
After a **read** primitive, find the **state-change** primitive on the same id/flow. Terminal escalations: reset/email-change → ATO · refund/transfer → financial · role/membership → priv-esc.

**→ consumed by `../phases/04-chain.md`.**
