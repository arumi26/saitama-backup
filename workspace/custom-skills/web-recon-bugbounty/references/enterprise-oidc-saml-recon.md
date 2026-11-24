# Enterprise OIDC/SAML IdP Recon Pattern (OneLogin/Okta/Azure AD)

## When to Use
When a target uses a third-party Identity Provider (IdP) for authentication:
- OneLogin (`*.onelogin.com`)
- Okta (`*.okta.com`, `*.oktacdn.com`)
- Azure AD (`login.microsoftonline.com`)
- Auth0 (`*.auth0.com`)
- PingFederate, Keycloak, ForgeRock, etc.

## Recon Workflow

### 1. Discover IdP
```bash
# Check login page for redirect to IdP
curl -sL "https://TARGET/login" | grep -oP '(onelogin|okta|azure|auth0|ping|keycloak)[a-z0-9.-]*\.(com|net|io)'

# Check HTML for IdP config
curl -sL "https://TARGET/js/*.js" | grep -oiP '(clientId|client_id|issuer|authority|tenant|domain)[^;]{0,50}'

# Check .well-known endpoints
curl -s "https://TARGET/.well-known/openid-configuration"
```

### 2. OIDC Config Dump
```bash
curl -s "https://TARGET/.well-known/openid-configuration" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('Grant types:', d.get('grant_types_supported',[]))
print('Auth methods:', d.get('token_endpoint_auth_methods_supported',[]))
print('Response types:', d.get('response_types_supported',[]))
print('Claims:', d.get('claims_supported',[]))
"
```

### 3. SSO Parameter Injection
```bash
# OneLogin
for param in "partnerId=hacker" "targetIdP=https://evil.com" "loginId=attacker@evil.com"; do
  curl -sI --max-time 3 "https://TARGET.onelogin.com/sso?${param}" | head -1
done

# Okta
curl -sI --max-time 3 "https://TARGET.okta.com/app/TargetApp/okta/signin?id=HACKER_ID" | head -1
```

### 4. JWKS Key Analysis
```bash
curl -s "https://TARGET/.well-known/jwks.json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for key in d.get('keys',[]):
    print(f'kty={key.get(\"kty\")}, kid={key.get(\"kid\")}, alg={key.get(\"alg\")}')
"
```

### 5. Subdomain/Tenant Enumeration
```bash
for sub in "dev-TARGET" "staging-TARGET" "TARGET-dev"; do
  code=$(curl -sI --max-time 3 "https://${sub}.onelogin.com" 2>&1 | grep -oE 'HTTP/[0-9.] [0-9]+' | awk '{print $2}')
  [ "$code" != "000" ] && echo "${sub}.onelogin.com → HTTP $code"
done
```

## Common Findings

| Finding | Severity | Notes |
|---------|----------|-------|
| Deprecated grant types listed in config | Low | e.g. `password` grant but 410 Gone |
| `none` auth method listed | Low-Medium | If no valid clients, just config noise |
| Sensitive claims in JWT (`department`, `title`) | Low | Requires valid token to exploit |
| SAML metadata returns 500 error | Low | Check if error leaks useful info |
| SSO parameter injection | Blocked | IdP vendor protects this (400/403) |

## What NOT to Report
- SSO injection blocked by IdP vendor — working as designed
- Password grant deprecated (410 Gone) — not exploitable
- Public JWKS keys — expected behavior
- OIDC/SAML config being public — expected behavior

## Real Case: Hilton (2026-08-03)
- **IdP:** OneLogin (`hilton.onelogin.com`)
- **OIDC config:** Public, lists `none` auth + `password` grant (deprecated, 410 Gone)
- **JWKS:** Public at `/oidc/certs` (expected)
- **SSO injection:** Blocked (400/403) — OneLogin platform protection
- **SAML metadata:** `/saml/metadata` → 500 (OneLogin error page)
- **Verdict:** Low severity — OIDC config inconsistency only
