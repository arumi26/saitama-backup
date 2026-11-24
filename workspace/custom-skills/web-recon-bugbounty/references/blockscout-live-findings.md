# Blockscout Live Exploit Findings — July 2026

Confirmed on live instances:
- `https://eth.blockscout.com`
- `https://polygon.blockscout.com`
- `https://arbitrum.blockscout.com`

Source: `endpoint.ex:36-39` production config defaults to wildcard `*` origin with `credentials: true`.

## Confirmed Findings

### CRITICAL — CORS Wildcard + Credentials
- **Instances:** Ethereum, Polygon, Arbitrum
- **Headers:** `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true`
- **Impact:** Any attacker origin can make authenticated cross-origin requests and read the response if victim is logged into Blockscout
- **Live proof:**
  - `Origin: https://evil.com` + GET `/api/v2/addresses/0xdAC17...` returns `200` with `ACAO: *`
  - Address balance data exfiltrated successfully on Ethereum and Arbitrum
- **Bounty range:** $10K-$25K per instance

### HIGH — GraphQL Playground Exposed
- **Paths:** `/graphiql` on all 3 instances (returns `200`)
- **Impact:** Full schema introspection, query surface mapping, potential data exfiltration via GraphQL queries
- **Note:** `/schema.graphql` returned `404`; playground UI is exposed instead
- **Bounty range:** $5K-$15K

### MEDIUM — API Docs Exposed
- **Path:** `/api-docs` on all 3 instances (returns `200`, Next.js HTML)
- **Impact:** Information disclosure, endpoint enumeration for further attacks
- **Bounty range:** $2K-$5K

### MEDIUM — Session Cookie Not HttpOnly
- **Config:** `http_only: false` on `_explorer_key` session cookie
- **Impact:** XSS can steal session cookies = account takeover
- **Bounty range:** $2K-$5K

## Attack Flow

1. Attacker hosts malicious site `evil.com`
2. Victim visits `evil.com` while logged into Blockscout
3. JavaScript on `evil.com` makes requests to Blockscout API with `credentials: include`
4. Browser sends cookies because `ACAC: true`
5. `ACAO: *` allows attacker to read response via JavaScript
6. Data exfiltrated: address tags, transaction history, email, watchlists

## Remediation

```elixir
# endpoint.ex — CORS
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
  http_only: true,  # CHANGE FROM false TO true
  domain: @cookie_domain,
  max_age: @session_cookie_ttl
)
```

## Recon Checklist for Explorer-Class Targets

- [ ] CORS wildcard + credentials on `/api/*` endpoints
- [ ] GraphQL playground/schema exposure (`/graphiql`, `/schema.graphql`)
- [ ] Session cookie flags (`HttpOnly`, `Secure`, `SameSite`, `Domain`)
- [ ] Admin panel feature flags + default deploy values
- [ ] Account API auth bypass / IDOR on tags/watchlists/API keys
- [ ] Rate-limit bypass headers (`bypass-429-option`, temp token header)
- [ ] Universal proxy socket routes for SSRF/origin confusion
