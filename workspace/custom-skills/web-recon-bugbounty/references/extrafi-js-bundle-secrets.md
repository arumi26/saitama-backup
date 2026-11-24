# Extrafi.io JS Bundle Secret Discovery (July 2026)

**Target:** `app.extrafi.io` — DeFi protocol (lending, isolated markets, kinked rates)
**Bundle:** `/assets/index-CUqGb5Vp.js` — 5.6 MB (5.4M chars)
**Frontend:** Vite/React SPA behind Cloudflare
**Backend:** AWS ALB (`AWSALB`/`AWSALBCORS` cookies)

## Discovery Method

1. Fetch main page: `curl -sL 'https://app.extrafi.io'` → 2,840 bytes (loading shell)
2. Extract JS bundle path: `grep -oP 'src="[^"]+\.js"'`
3. Download bundle: `curl -sL 'https://app.extrafi.io/assets/index-CUqGb5Vp.js' -o bundle.js` → 5.4MB
4. Search for patterns with Python:

```python
import re
with open('bundle.js', 'r', errors='replace') as f:
    content = f.read()

# API keys and secrets
apis = re.findall(r'["\']((?:/api|https?://[^"\']*api)[^"\']*)["\']', content, re.I)

# URLs with embedded keys
rpcs = re.findall(r'(https?://[^"\'\\]+(?:key|token|api[_-]?key)[^"\'\\]*)', content, re.I)

# Provider configs (WalletConnect, Firebase, etc.)
providers = re.findall(
    r'(projectId|appId|apiKey|authDomain|databaseURL|projectNumber|storageBucket|messagingSenderId|appId|measurementId)\s*[:=]\s*["\']([^"\']+)["\']',
    content
)
```

## Leaked Credentials

### 1. Coinbase Developer RPC Key (LIVE)
```
https://api.developer.coinbase.com/rpc/v1/base/0txHZs13U0KInOLNdOuRDjSUOeGHUs7d
https://api.developer.coinbase.com/rpc/v1/optimism/0txHZs13U0KInOLNdOuRDjSUOeGHUs7d
```

**Usage:** Hardcoded in `useWriteContractsWithPaymaster()` for Base + Optimism chains.

**Read-Only Behavior:** Coinbase Developer RPC keys are paymaster keys:
- `eth_blockNumber`, `eth_call`, `eth_getBalance`, `eth_getLogs` → ✅ WORK
- `eth_sendTransaction`, `personal_sendTransaction` → `"request denied"` 🚫
- Funds-safe: cannot transfer ETH/tokens
- Unlimited free queries charged to protocol's Coinbase account

### 2. The Graph API Key (LIVE)
```
a4998f968b8ad324eb3e47ed20c00220
```

**Usage:** Used for 3 subgraph deployments:
```
https://gateway.thegraph.com/api/a4998f968b8ad324eb3e47ed20c00220/deployments/id/QmXYvc82BmDKdPbhi6i6kgYCnPpA1uHifdWVoMEMBKuRa1
https://gateway.thegraph.com/api/a4998f968b8ad324eb3e47ed20c00220/deployments/id/QmT6s8gNmKrshbuHz3636UgCLp9RkBKQmRh2zt4wzpnDpL
https://gateway.thegraph.com/api/a4998f968b8ad324eb3e47ed20c00220/deployments/id/Qmdj5T4wJG4u7rBbwpUqmc8eFHAqNew7L1RDvuJ4MP7oSv
```

**Access:** Full query access — unlimited subgraph queries paid by protocol.

### 3. Alchemy RPC Keys (ENV Vars — Partially Exposed)
```javascript
`${ALCHEMY_API_KEY_BASE}`
`${ALCHEMY_API_KEY}`
`${ALCHEMY_API_KEY_BERACHAIN}`
```

The template strings are exposed, but values are injected via env vars at build time. Keys NOT directly leaked.

### 4. Internal API Endpoints
```
https://api.extrafi.io
https://strato-api.extrasafe.link/api/v1
https://rpc.extrafi.io/
```

## Detection Patterns for Future Scans

When scanning SPA JS bundles for secrets:

```python
# Pattern 1: RPC URLs with embedded keys
r"https?://[^"\'\\]*rpc[^"\'\\]*(?:key|token|api[-_]key)[^"\'\\]*"

# Pattern 2: Coinbase Developer API keys (format: 0x + 64 hex chars)
r"api\.developer\.coinbase\.com/rpc/[^"\'\\]+/0x[a-fA-F0-9]{64}"

# Pattern 3: The Graph API keys (32-char alphanumeric)
r"gateway\.thegraph\.com/api/([a-f0-9]{32})"

# Pattern 4: Template string env vars (partially exposed config)
r"https?://[^"\'\\]*\$\{[A-Z_]+(?:KEY|KEY_[A-Z]+)\}"

# Pattern 5: Paymaster/proxy configs
r"(paymaster|sponsor|gasless|relayer|biconomy|gelato)"
```

## Report Strategy

1. **Never post full key in public** — team can fix without paying
2. **Show proof with partial redaction** — `0txHZ****...****Us7d`
3. **Demonstrate impact** — show live RPC query returning data
4. **Typical bounty range:** $500-$2,000 for read-only key leaks
5. **Submission channel:** GitHub security advisory, Discord DM, or Telegram
6. **Include fix suggestion:** "Move API keys to server-side proxy or env-only build variables not bundled in client JS"