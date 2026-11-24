# Custom Blockchain Recon (Non-EVM, Non-Solana, Non-Move)

When a target is a custom blockchain (Zetrix, etc.) — not EVM, not Solana, not Sui/Move.

## Key Difference from EVM Recon

Standard EVM JSON-RPC methods (`web3_clientVersion`, `eth_blockNumber`, `eth_getBalance`) will fail on custom chains:
- Response: `"File not found"` (HTTP 200) or empty body
- Custom chains use their own protocol — not Ethereum JSON-RPC

**Do NOT waste time cycling through Ethereum RPC methods** — they won't work.

## Custom Chain Surface Discovery

### 1. Find the Protocol from Documentation
```
docs.TARGET.com → GitBook → API References → find actual RPC endpoint format
```
Look for:
- HTTP RPC tools section
- SDK documentation (Node.js, Go, Java)
- Network configuration page
- WebSocket endpoints (protobuf-based)

### 2. Extract RPC Format from npm Packages
```
npm registry → package.json → dependencies → custom SDKs
```
Zetrix example: `zetrix-sdk-nodejs` uses `protobufjs`, `bignumber.js`, `zetrix-encryption-nodejs`
→ Signal: protobuf-based, not JSON-RPC

### 3. Subdomain Architecture Map
Custom chains typically expose:
| Subdomain | Purpose | Attack Surface |
|:----------|:--------|:---------------|
| `node.*` | RPC node | CORS, unauthenticated RPC |
| `test-node.*` | Testnet RPC | CORS, weaker auth |
| `explorer.*` | Block explorer | Cloudflare, GraphQL |
| `swap-api.*` | DEX backend | Bare nginx, no WAF |
| `dao.*` | Governance SPA | Vue/React, API endpoints |
| `validator.*` | Validator portal | JWT/auth bypass |
| `faucet.*` | Testnet faucet | Rate limiting, abuse |
| `ide.*` | Smart contract IDE | XSS, auth bypass |
| `multisig.*` | Multi-sig wallet | Auth bypass, IDOR |
| `verifyid.*` | Identity verification | ZKP/DID surface |
| `tradefi.*` | Trade finance | Financial logic bugs |
| `ztrade.*` | Exchange | Auth, order manipulation |

### 4. npm Package Intelligence
```
npm registry → search for "{chain}-sdk" or "{chain}-mcp"
```
Extract from `package.json`:
- Dependencies → protocol stack (protobuf, grpc, websocket)
- `repository.url` → internal Git server IPs (common leak!)
- Scripts → build/test commands revealing internal tooling

**Confirmed leak (Zetrix, Aug 2026):** `zetrix-sdk-nodejs` package.json exposes `http://192.168.1.11/zetrix-v4/zetrix-sdk-nodejs.git` — internal network IP

### 5. CORS on Blockchain Nodes
Custom chain nodes often have CORS wildcard for development convenience:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept
```
**Impact:** Cross-origin RPC access from any attacker site. Can drain RPC quota, inject malicious requests, or extract chain data.

## Pitfalls

### Custom RPC Protocol Assumption
- **Wrong:** Assume custom chain uses Ethereum JSON-RPC
- **Right:** Check docs/SDK first, then try chain-specific methods
- Signal: `"File not found"` on `eth_blockNumber` → custom protocol

### npm Package Internal IP Leak
- Check `repository.url` in every SDK package.json
- `192.168.x.x`, `10.x.x.x`, `172.16-31.x.x` = internal network
- These are common in custom chain SDKs (dev setup never cleaned)

### SPA API Discovery on Custom Chains
- Validator/DAO SPAs use `/api/*` endpoints with JWT auth
- `{"errorCode":2,"message":"Invalid TOKEN"}` = Spring Boot backend
- 401 on ALL paths = auth gate before route resolution
- Try registration endpoints — they may be unauthenticated

## Zetrix Case Study (Aug 2026)

**38 subdomains discovered** via HackerTarget hostsearch. Key findings:
- `swap-api.zetrix.com` — bare nginx/1.18.0 502, no WAF (AWS direct IP `54.179.255.249`)
- `node.zetrix.com` + `test-node.zetrix.com` — CORS: * on blockchain nodes, all methods allowed
- `validator.zetrix.com` — Spring Boot `/api/*`, JWT auth, `{"errorCode":2,"message":"Invalid TOKEN"}` on all endpoints including `/api/register`, `/api/login`, `/api/v1/*`
- `dao.zetrix.com` — Vue SPA, openresty, no API endpoints found in JS bundle (Axios with `ACCESS_TOKEN` storage)
- `covinsure.zetrix.com` — AmazonS3 bucket, AES256 encryption, CloudFront fronted, Angular SPA
- Internal IP `192.168.1.11` leaked in `zetrix-sdk-nodejs` package.json → `repository.url`
- CSP on `www.zetrix.com` missing `script-src` — only style-src + font-src, complete XSS vector (HIGH)
- Imperva WAF detected via `incap_ses_` + `visid_incap_` cookies
- `explorer.zetrix.com` + `blockscan.zetrix.com` behind Cloudflare challenge
- No bug bounty program, no security.txt — direct disclosure only via GitHub/email
- WordPress REST API `/wp-json/wp/v2/*` returns 500 (all endpoints broken)
- XML-RPC disabled (`Access to XML-RPC is disabled by site admin!`)
- WordPress Yoast SEO v28, cookie `wp_wpfileupload_*` without HttpOnly flag
- npm packages: `zetrix-mcp-server` (v1.0.27, 55 tools), `agentic-wallet-mcp` (v0.7.0), `zetrix-sdk-nodejs` (v1.0.3)
- GitHub org: `Zetrix-Chain` with 26 repos, `zetrix-agentic-wallet` + `x402-zetrix-js` + `x401-zetrix-js` updated Aug 2026
- `docs.zetrix.com` — GitBook (Next.js), Cloudflare
- `verifyid.zetrix.com` → 301 redirect to `zid-apply.zetrix.com` (Cloudflare)
- `ds.zetrix.com` on AWS `54.169.4.127` (non-CF)