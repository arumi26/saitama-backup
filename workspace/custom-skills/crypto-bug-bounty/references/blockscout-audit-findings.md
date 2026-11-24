# Blockscout Web Application Audit Findings

Confirmed on live instances:
- Ethereum: `https://eth.blockscout.com`
- Polygon: `https://polygon.blockscout.com`
- Arbitrum: `https://arbitrum.blockscout.com`

## Confirmed Findings

### 1. CORS Wildcard + Credentials
- **Severity:** CRITICAL
- **Instances:** Ethereum, Polygon, Arbitrum
- **Headers:** `access-control-allow-origin: *` + `access-control-allow-credentials: true`
- **Impact:** Any origin can read authenticated API responses if victim is logged in
- **Source:** `endpoint.ex:36-39` production config defaults to wildcard origin
- **PoC:** `Origin: https://evil.com` + GET `/api/v2/addresses/...` returns data with ACAO=*

### 2. GraphQL Playground Exposed
- **Severity:** HIGH
- **Paths:** `/graphiql` on all 3 instances
- **Impact:** Schema introspection, query surface mapping
- **Note:** `/schema.graphql` returned 404, but playground is live

### 3. API Docs Exposed
- **Severity:** MEDIUM
- **Path:** `/api-docs`
- **Impact:** Information disclosure, endpoint enumeration

### 4. Session Cookie Not HttpOnly
- **Severity:** MEDIUM
- **Source:** `endpoint.ex:96-99` — `http_only: false`
- **Impact:** XSS can steal session cookies

### 5. Missing CSP
- **Severity:** MEDIUM
- **Impact:** XSS amplification

## Attack Flow

1. Attacker hosts malicious site
2. Victim visits while logged into Blockscout
3. JavaScript makes cross-origin requests
4. Browser sends cookies due to `credentials: include`
5. ACAO=* allows attacker to read response
6. Data exfiltrated: address tags, transaction history, email, watchlists

## Remediation

```elixir
# endpoint.ex
@cors_plug_options [
  origin: ["https://blockscout.com", "https://www.blockscout.com"],
  credentials: true,
  headers: [...]
]

# Session cookie
plug(Plug.Session,
  store: BlockScoutWeb.Plug.RedisCookie,
  key: "_explorer_key",
  signing_salt: "iC2ksJHS",
  same_site: "Lax",
  http_only: true,  # CHANGE TO TRUE
  domain: @cookie_domain,
  max_age: @session_cookie_ttl
)
```

## Bounty Estimate
- CORS: $10K-$25K
- GraphQL introspection: $5K-$15K
- API docs: $2K-$5K
- Total: $17K-$45K
