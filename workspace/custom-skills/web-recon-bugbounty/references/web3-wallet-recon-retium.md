# Web3 Wallet App Reconnaissance — Retium Case Study (2026-08-02)

## Context
Retium Wallet (`https://wallet.retium.org/`) is a NEAR-based Web3 wallet on a new L1 blockchain focused on RWA (Real World Assets) tokenization. Frontend is Nuxt.js SPA with Vite build, hosted behind Cloudflare.

## Architecture Summary

```
┌─────────────────────┐      ┌──────────────────────────┐
│  wallet.retium.org  │─────▶│  wallet-gateway.retium.org │
│  (Nuxt.js SPA)      │  ↕    │  (Custom wallet API)       │
│  + Cloudflare       │      │  :443 / API endpoints       │
└─────────────────────┘      └──────────────────────────┘
         ↕                                  ↕
    NEAR accounts                    Wallet backend service
    (mnemonic → keyHexToMnemonic)     (stake/unstake/send)
```

## Key Recon Patterns

### 1. Extract API Config from Minified JS
```bash
# Get the main JS bundle
curl -sL "https://wallet.retium.org/assets/index-DmJ_LkM0.js" > /tmp/retium.js

# Extract API config variables (grep around known patterns)
grep -oP '.{0,150}API_BASE_URL.{0,150}' /tmp/retium.js
grep -oP '.{0,150}API_KEY.{0,150}' /tmp/retium.js
grep -oP '.{0,200}ws[^,]{0,200}' /tmp/retium.js | grep -i 'https\|retium\|baseURL\|apiKey'
```

**Retium-specific findings:**
- `Kv = "https://wallet-gateway.retium.org"` — gateway base
- `ws = "${Kv}/api"` → `https://wallet-gateway.retium.org/api`
- `Ss = "retium_local_dev_key"` — API key
- API uses `X-API-Key` header

### 2. Extract API Endpoints
```bash
# Find all .get() and .post() calls in bundle
grep -oP '\.(get|post)\([^)]*\)' /tmp/retium.js | \
  grep -i 'wallet\|api\|user\|account\|auth\|stake\|mint\|nft\|transfer\|balance'
```

**Retium endpoints discovered:**
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/wallet/{walletId}` | Get wallet info |
| GET | `/api/wallet/{walletId}/tokens` | Wallet tokens |
| POST | `/api/wallet/{walletId}/import-token` | Import token contract |
| POST | `/api/wallet/send` | Send transaction |
| POST | `/api/wallet/{walletId}/stake` | Stake tokens |
| POST | `/api/wallet/{walletId}/unstake` | Unstake tokens |
| GET | `/api/wallet/{walletId}/transactions` | Transaction history |

### 3. API Key Classification
The `retium_local_dev_key` pattern suggests:
- **Environment-specific naming** (dev key in production JS) = potential information leak
- Local dev keys in production builds usually means the backend doesn't enforce strong auth on all endpoints
- **Verification**: test endpoint access with the key — if it works, it's a confirmed leak
- If it's a staging key with no real data access → low severity info leak

### 4. Nuxt Payload Extraction
Nuxt apps often embed API route info in payload:
```bash
# Get Nuxt SSR payload data
curl -sL "https://wallet.retium.org/_payload.json" 2>/dev/null
# Look for API route definitions, server middleware, proxy config
```

### 5. CSP & Security Posture
- **Strict CSP**: `script-src 'self'` — no inline scripts allowed
- **Self-hosted fonts**: DM Sans + DM Mono from `/fonts/` — no Google leaks
- **Cloudflare bot protection**: iframe challenge injection
- **No third-party tracking**: zero external requests by design

## Recon Playbook (General Pattern)

When targeting any Web3 wallet app:

1. **Get HTML** → extract JS bundle URLs
2. **Download bundle** → save locally
3. **Grep for config patterns**:
   - `baseURL`, `baseUrl`, `api_url`, `API_BASE_URL`
   - `apiKey`, `api_key`, `API_KEY`
   - `FAUCET_BASE_URL`, `rpc_url`, `RPC_ENDPOINT`
   - `wallet-gateway`, `wallet-api`, `wallet-service`
   - `X-API-Key`, `Authorization`, `Bearer`
4. **Grep for API calls**:
   - `\.get\(`, `\.post\(`, `\.fetch\(`
   - URL template literals: `` `/${variable}` ``
   - Path segments: `/wallet`, `/tokens`, `/stake`, `/send`
5. **Map the architecture**:
   - Frontend domain vs gateway domain
   - Auth pattern (API key? wallet signature? JWT?)
   - Blockchain type (NEAR, Solana, EVM, custom)
6. **Test endpoints** with discovered keys
7. **Check for bug bounty** before deep exploitation

## Retium-Specific Details

- **Blockchain**: NEAR-based (wallet ID generation, mnemonic, keyHexToMnemonic)
- **Purpose**: RWA (Real World Assets) tokenization L1
- **Presale**: Active token sale on homepage
- **Socials**: @RetiumChain (X), Telegram, Discord, Medium
- **Docs**: https://docs.retium.org/whitepaper
- **Bug bounty**: None found on Immunefi/HackerOne as of recon date
- **Security.txt**: Not found at `/.well-known/security.txt`
- **GitHub**: Not found (private repo or not public yet)
- **TVL**: Unknown (not on DefiLlama as of recon date)

## Bounty Potential Assessment

| Factor | Score | Notes |
|--------|-------|-------|
| API Key Leak | Medium | Hardcoded `retium_local_dev_key` in production JS |
| Presale Target | High | Active token sale = high-value, less audited |
| Custom Blockchain | Medium | New L1, potentially under-audited |
| Bounty Program | Low | None found yet |
| Competition | Low | New protocol, fewer hunters |

**Recommended action**: Check for GitHub source code → audit gateway API → submit if bug bounty exists, otherwise email disclosure to security@retium.org or via Discord.
