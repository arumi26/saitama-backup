# DeFi / Immunefi Hunting Techniques
# Reference file for superagent-v7 skill
# Created: 2026-07-31

## Target Discovery Pipeline

### 1. DefiLlama Protocol Enumeration
```bash
curl -s "https://api.llama.fi/protocols" -o /tmp/protocols.json
python3 << 'EOF'
import json
data = json.load(open('/tmp/protocols.json'), strict=False)
targets = []
for p in data:
    if p.get('category') in ['Lending','CDP','Derivatives','Bridge','DEX','Yield']:
        tvl = p.get('tvl',0) or 0
        if tvl > 1000000 and str(p.get('audits','0')) == '0':
            targets.append({
                'name': p.get('name'),
                'tvl': tvl,
                'chain': p.get('chain'),
                'category': p.get('category'),
                'url': p.get('url'),
                'github': p.get('github')
            })
targets.sort(key=lambda x: -x['tvl'])
for t in targets[:20]:
    print(f"{t['name']} | ${t['tvl']:,.0f} | {t['chain']} | {t['category']} | {t['url']}")
EOF
```

### 2. Immunefi Program Enumeration
```bash
# Extract program data from Immunefi page
curl -s "https://immunefi.com/bug-bounty/SLUG/information/" | \
  grep -oP '"maxBounty":\d+|"project":"[^"]*"|"slug":"[^"]*"'

# Full program data extraction
curl -s "https://immunefi.com/bug-bounty/SLUG/information/" | \
  python3 -c "
import sys, re, json
html = sys.stdin.read()
match = re.search(r'\"bounty\":\{.*?\}', html)
if match:
    data = json.loads(match.group(0))
    print(json.dumps(data, indent=2))
"
```

## Vulnerability Patterns

### CORS + Credentials Misconfiguration
```bash
# Test for CORS misconfiguration with credentials
curl -s -I -H "Origin: https://evil.com" "https://target.com" | grep -i "access-control"

# Vulnerable if:
# access-control-allow-origin: *
# access-control-allow-credentials: true

# Impact: Spec violation (RFC 6454), potential for abuse
# Severity: Low-Medium on Immunefi
# Note: Browsers block wildcard+credentials, but still reportable
```

### wallet_addEthereumChain Abuse
```javascript
// Look in JS bundles for this pattern:
c.request({
    method: "wallet_addEthereumChain",
    params: [{
        chainId: "0x" + Number(e.chainId).toString(16),
        chainName: e.chainName,
        nativeCurrency: {name: e.name, symbol: e.symbol, decimals: 18},
        rpcUrls: [e.rpc_url],  // ← Is this validated?
        blockExplorerUrls: [e.explorers]  // ← Is this validated?
    }, n[0]]
})

// Attack: If rpc_url comes from unvalidated API, attacker can:
// 1. Modify API response to point to malicious RPC
// 2. User adds malicious chain to MetaMask
// 3. All transactions go through attacker's RPC → funds stolen
```

### JSON-RPC API Fuzzing
```bash
# Enumerate available methods
for method in "rpc.listMethods" "rpc_modules" "web3_clientVersion" "net_version" \
  "net_listening" "net_peerCount" "eth_protocolVersion" "eth_syncing" \
  "eth_coinbase" "eth_mining" "eth_hashrate" "eth_gasPrice" "eth_accounts" \
  "eth_blockNumber" "eth_getBalance" "eth_sendTransaction"; do
  result=$(curl -s -X POST "https://api.target.com" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":[],\"id\":1}")
  if ! echo "$result" | grep -q "does not exist"; then
    echo "$method: $(echo "$result" | head -c 100)"
  fi
done
```

## Immunefi Submission Rules

### Out-of-Scope (will be rejected)
- Missing HTTP Security Headers WITHOUT demonstrated impact
- SPF/DMARC misconfigured records
- Leakage of non-sensitive API keys (Etherscan, Infura, Alchemy, Stripe publishable)
- Automated scanner reports WITHOUT demonstrated impact
- UI/UX best practice recommendations
- Self-XSS, CSRF with no state-modifying impact
- Theoretical impacts without PoC
- Attacks requiring physical access or local network access
- Missing SSL/TLS best practices
- Impacts requiring DDoS

### In-Scope (reportable)
- CORS misconfiguration with demonstrated impact
- Internal services exposed
- Build paths leaked (if they reveal sensitive info)
- Authentication bypass
- IDOR
- XSS (with PoC)
- SQLi (with PoC)
- SSRF (with PoC)
- RCE (with PoC)
- Subdomain takeover
- Smart contract vulnerabilities (Critical: $2,500-$100K)

### Payout Scale (BlockPI Network example)
- Critical: $2,500 - $5,000
- High: $1,500
- Medium: $1,200
- Low: $1,000

## Case Studies

### BlockPI Network (2026-07-31)
**Target:** RPC service, NOT DeFi protocol
**Findings:**
1. CORS wildcard on ALL subdomains (blockpi.io, dashboard.blockpi.io, public.blockpi.io)
2. Internal services exposed (hub.nimbly.blockpi.org, ai-assistant.blockpi.org, contact-zendesk.blockpi.org)
3. Build paths leaked (/opt/buildhome/repo/...)
4. Stripe live publishable key exposed
5. .env and .git return 403 (exist but blocked)

**Lesson:** RPC services don't hold user funds → no fund theft potential
**Pivot:** Target actual DeFi protocols (lending, bridge, DEX) for fund theft bugs

### Aurasell.ai (2026-07-31)
**Target:** SaaS platform
**Findings:**
1. PostHog API key exposure (Low severity, $5)
2. Hidden pages accessible (/hidden-pages/*, /form-test)
3. Exposed tracking IDs (LinkedIn, RE B2B)

**Lesson:** PostHog project keys allow event injection + /decide/ config leak
**Submission:** security@aurasell.ai (paused until Aug 31, 2026)

## Fund Theft Attack Vectors (Critical severity)

### Smart Contract
- Reentrancy (CEI violation)
- Flash loan attack
- Oracle manipulation (TWAP, spot price)
- Access control bypass
- Logic flaws (accounting state desync)

### Bridge
- Message forgery
- Validation bypass
- Replay attacks
- Finality race conditions

### Lending
- Price manipulation
- Liquidation bypass
- Collateral bypass
- Interest rate manipulation

### Wallet Interaction
- Transaction parameter manipulation
- Contract address substitution
- Malicious RPC redirection

### Authentication Bypass
- Take state-modifying actions on behalf of other users
- JWT manipulation
- OAuth flow abuse
- Session hijacking
