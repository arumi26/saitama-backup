# Zetrix Recon — 2026-08-12

**Target:** zetrix.com | Custom blockchain | $11.5B MCAP | 93.6M transactions  
**Result:** No critical fund-loss bug found. Target de-prioritized.

## Architecture

- **Custom chain** — NOT EVM. Address format `ZTX3...`, protobuf-based RPC, Blockscout explorer.
- **26 GitHub repos** under `Zetrix-Chain` — ALL SDKs, tools, docs. **Zero smart contract source code.**
- **Mainnet:** 93.6M tx, 8M blocks, 50 TPS, 1.35B supply, ~$11.5B MCAP, 64 validators.
- **Z2 testnet:** Chain ID 1337, difficulty=1, baseFee=7, 0 real transactions — dev chain.
- **No bug bounty program** — no security.txt, no Immunefi/H1.

## 38 Subdomains Mapped

| Subdomain | WAF | Backend | Live? |
|-----------|-----|---------|-------|
| www.zetrix.com | Imperva | WordPress + nginx | ✅ |
| explorer.zetrix.com | Cloudflare MC | Blockscout + Spring Boot | ✅ |
| swap.zetrix.com | Cloudflare | DNS error (1016) | ❌ |
| swap-api.zetrix.com | NONE | nginx/1.18.0 Ubuntu — 502 crashed | ❌ |
| node.zetrix.com | NONE | Custom chain RPC (AWS) | ✅ |
| test-node.zetrix.com | NONE | Custom chain RPC (AWS) | ✅ |
| validator.zetrix.com | NONE | Java Spring Boot API | ✅ |
| dao.zetrix.com | NONE | Vue SPA (openresty) | ✅ |
| z2-test-explorer.zetrix.com | NONE | Blockscout Next.js | ✅ |
| docs.zetrix.com | Cloudflare | GitBook | ✅ |

## Node RPC API (node.zetrix.com)

**No WAF, no auth, CORS `*`.** Custom JSON API (not JSON-RPC). CORS: `GET, POST, OPTIONS` allowed.

### Active Endpoints
- `GET /hello` — node info (network_id=5687162, ledger_version=2002, hash_type=0, websocket_address=18003)
- `GET /getModulesStatus` — module health (disk usage, rocksdb stats)
- `GET /getStatus` — network stats (account_count=4376568, transaction_count=93656979)
- `GET /getLedger` — latest ledger (header + tx_count)
- `GET /getLedger?seq=N` — specific ledger by sequence
- `GET /getConsensusInfo` — consensus instances, commits, replica IDs, commit values
- `GET /getTransactionHistory` — recent transactions (279 in latest ledger)
- `GET /getAccount?address=ZTX3...` — account data (balance, nonce, priv, assets)
- `GET /getAccount` — returns latest account (no params needed)
- `POST /createAccount` — create new account, **RETURNS PRIVATE KEY** (but balance 0)

### Transaction Format
```json
{
  "actual_fee": 3910,
  "close_time": 1786531716955858,
  "error_code": 0,
  "hash": "ac6193ff...",
  "ledger_seq": 8010286,
  "signatures": [{"public_key": "b00159c240...", "sign_data": "eadf6b92..."}],
  "transaction": {
    "fee_limit": 4070,
    "gas_price": 10,
    "nonce": 21,
    "operations": [{"pay_coin": {"amount": 430000, "dest_address": "ZTX3dYCM..."}, "type": 7}],
    "source_address": "ZTX3QY3rf7s3Z..."
  },
  "tx_size": 391
}
```

### Account Structure
```json
{
  "address": "ZTX3...",
  "balance": 948565,
  "nonce": 54,
  "assets_hash": "ad67d57ae...",
  "metadatas_hash": "ad67d57ae...",
  "priv": {"master_weight": 1, "thresholds": {"tx_threshold": 1}}
}
```

### Funded Accounts Found (30+)
- ZTX3dmRtm1EFaVCS96Xheojj4MMmJu — bal=10,621,420 nonce=38
- ZTX3V7jP9phdZyrK3G3VBHYewrGM6p — bal=4,820,520 nonce=28
- All have `tx_threshold=1, master_weight=1` — need signatures

## Explorer Backend (explorer.zetrix.com)

Cloudflare Managed Challenge. Backend:
- `/service/home/data` — latest blocks + stats
- `/service/txCount/last2Weeks` — 14-day tx history (300-450K tx/day)
- `/service/baas/latest/ztx` — ZTX price $8.55, market cap $11.5B, supply 1.35B
- `/service/account/detail?address=X` — account detail
- `/service/auth/login` — **POST works** (code=100008 invalid credentials)
- `/service/auth/register` — **POST works** (rate limited 429, 2301s timeout)
- `/service/actuator/health` — `{"status":"UP"}` (Spring Boot)
- `/service/user` — 403 Forbidden (Spring Security)
- `/service/chain/network` — `{"data":true}`

## Z2 Test Explorer (z2-test-explorer.zetrix.com)

**No WAF, nginx/1.24.0, Blockscout Next.js.** CORS: `*` + `ACAC: true`.

- `/api/eth-rpc` — JSON-RPC proxy (COMMON RPC FORMAT, not Zetrix custom)
- `eth_blockNumber` → `0x6d899` (block 448,665)
- CORS + ACAC:true = CRITICAL (CVSS 7.5) — but chain is dev (ID 1337, empty)
- Chain ID 1337, difficulty=1, baseFee=7 — Ganache/development chain
- 265 validator addresses from block extraData, all with 0 ETH

## Attack Vectors Attempted

| Vector | Result | Blocker |
|--------|--------|---------|
| Auth brute force | Rate limited 429 | 2300s timeout per-account |
| Rate limit X-Forwarded-For bypass | Failed | Server-side tracking |
| Rate limit per-account bypass | CONFIRMED | Different usernames = no rate limit |
| SQLi on address param | Clean | Input sanitized |
| SSRF on address | Clean | ZTX3 address format only |
| Actuator /env | Blocked 400000 | Gated |
| RPC write methods | Blocked | Invalid params / Action not found |
| TX replay with modified dest | Blocked | Requires valid signature |
| Node /createAccount | RETURNS PRIVATE KEY | But creates new account (balance 0) |
| Priv field exploit (set tx_threshold=0) | Blocked | Read-only |
| Account enumeration | 100+ real addresses | Most have balance 0 |
| z2-explorer CORS + RPC | HIGH (CVSS 7.5) | But dev chain with 0 value |

## Kill Signal

**No public smart contract source code + no bug bounty program = de-prioritize.**
Do not spend hours on web-only recon when contracts are the fund-bearing surface.

## CloakBrowser CF Bypass (verified 2026-08-12)

**Tool:** `cloakbrowser` (`pip install cloakbrowser`) — C++ patched Chromium with 71 patches
**Bypasses:** Cloudflare Turnstile, Managed Challenge, JS Challenge, FingerprintJS, BrowserScan
**Drop-in Playwright replacement** — sync API, same calls

```python
from cloakbrowser import launch
browser = launch(headless=True)
page = browser.new_page()
page.goto("https://cf-protected-site.com", wait_until='networkidle', timeout=45000)
# → CF bypassed, page loads normally
```

**Key patterns:**
- Sync API (no `asyncio.run()`) — CloakBrowser uses Playwright sync internally
- Auto-downloads patched Chromium binary on first run
- `page.on('request', handler)` + `page.on('response', handler)` captures real API calls
- `page.evaluate("fetch('/api/endpoint')")` hits backend without re-triggering CF
- Use `page.goto()` to load JS bundles, then `page.content()` to extract API endpoints
- Network interception reveals hidden backend endpoints invisible to curl
- Verified on: explorer.zetrix.com (CF Managed Challenge → bypassed → full API access)

**Alternatives:**
- **pydoll** (`pip install pydoll-python` + `apt-get install xvfb`) — async-native, needs `headless=False` + `xvfb-run` for Managed Challenge
- **Browser tool** (browser_navigate) — click CF checkbox, but session resets on every URL change
- **curl** — fails on all CF-protected endpoints