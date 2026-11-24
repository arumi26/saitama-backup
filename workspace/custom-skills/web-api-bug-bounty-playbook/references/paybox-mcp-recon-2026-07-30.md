# PayBox MCP + OAuth DCR Recon — Case Study (2026-07-30)

## Target
- `api.paybox.sh` — PayBox.sh MCP (Model Context Protocol) server
- Parent company: **MoonPay** — has active bug bounty on HackerOne (`hackerone.com/moonpay`)
- Scope includes: `paybox.sh`, `app.paybox.sh`, `api.paybox.sh`, `*.moonpay.com`, `*.moonpaycloud.com`

## MCP Connection (Raw JSON-RPC over HTTP)

PayBox MCP uses OAuth 2.1 for auth. Connection flow without ChatGPT web UI:

```bash
# 1. OAuth discovery
curl -s "https://api.paybox.sh/.well-known/oauth-protected-resource"
# → {"resource":"https://api.paybox.sh/mcp","authorization_servers":["https://api.paybox.sh"],"bearer_methods_supported":["header"],"scopes_supported":["mcp"]}

curl -s "https://api.paybox.sh/.well-known/oauth-authorization-server"
# → issuer, authorization_endpoint, token_endpoint, registration_endpoint, grant_types, PKCE S256

# 2. Initialize session
curl -s -X POST "https://api.paybox.sh/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer pbx_live_..." \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"recon","version":"1.0"}},"id":1}'
# → Server: rmcp v1.7.0, 17 tools available

# 3. List tools
# tools/list → list_credentials, get_portfolio, request_swap, request_transfer,
#   request_wallet_sign, request_payment, discover_services, pay_x402, etc.

# 4. Call a tool
curl -s -X POST "https://api.paybox.sh/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer pbx_live_..." \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_credentials","arguments":{}},"id":2}'
```

## Findings

### 1. Unauthenticated DCR with Arbitrary Redirect URI (HIGH)

`POST /oauth/register` accepts client registration with **no authentication** and **arbitrary redirect_uri**.

```
POST /oauth/register → returns client_id: pbx-oauth-XXX
  redirect_uris: ["https://attacker.example.com/callback"]  ← attacker controlled
  token_endpoint_auth_method: "none"
```

Authorize endpoint redirects to `app.paybox.sh/connect?app=pbx-oauth-XXX` — victim sees paybox.sh domain, trusts it.

### 2. Unlimited Client Registration (MEDIUM)

5+ clients created consecutively, all succeeded, no rate limit. Client IDs persist.

### 3. CORS Credentials=True on /oauth/token (MEDIUM)

`Access-Control-Allow-Credentials: true` returned for ALL origins on `/oauth/token`. If ACAO reflects origin, browser-based token theft possible.

### 4. MCP Token Scope — Properly Secured ✅

- Token scoped to single user's wallet only (no IDOR)
- EVM wallet grant requires passkey approval (no self-escalation)
- Wallet signing requires explicit user ceremony for new keys

## Not Yet Tested

- Complete phishing flow end-to-end (needs browser + victim interaction)
- `iframe.moonx-dev.com` (signing app XSS/SSRF surface)
- `api.moonx-dev.com` (wallet management API)
- `github.com/moonpay` (source code, leaked secrets)
- x402 payment proof forgery

## Key Takeaway

MCP servers are a new bounty surface (2025-2026). OAuth flows protecting them often inherit legacy DCR endpoints that were designed for trusted clients. When an AI platform exposes:
1. `/oauth/register` (check if unauth)
2. `/oauth/authorize` (check redirect_uri validation)
3. `/oauth/token` (check CORS)

...it creates a phishing chain from a trusted domain → victim authorizes → code goes to attacker → token exchange → MCP tool access (wallet, payments, signing).
