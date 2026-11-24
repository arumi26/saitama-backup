---
skill: jwt
title: "JWT Attacks"
category: "Security · Auth"
load_when: "Any JWT (eyJ...)."
pack: SUPERAGENT V10
bughunt: true
---
# JWT Attacks

## Where it pays
Forge tokens → impersonate any user/admin → ATO.

## Signals
JWT in cookies/headers/body; alg/kid/exp claims.

## Methodology
1. alg:none; strip signature.
2. RS→HS alg confusion with public key as HMAC secret.
3. Crack weak secret (hashcat -m 16500).
4. kid injection; no-verify/no-expiry; jwk/jku injection.

## 🧪 Try it locally (hands-on)
```bash
python3 ../../../tools/skill_router.py "jwt alg none and weak secret"

# Inspect + attack a captured token (your own session)
jwt_tool "$TOKEN" -T                         # tamper interactively
hashcat -a 0 -m 16500 jwt.txt wordlist.txt   # crack a weak HS256 secret
# alg:none / RS->HS confusion patterns: ../payloads/auth-tokens.txt
```
## Validation gate
Forged token the server accepts as another/privileged identity.

## Impact & chains
**ATO**, priv-esc, auth bypass app-wide.

**→ next on hit: `../phases/04-chain.md`.**
