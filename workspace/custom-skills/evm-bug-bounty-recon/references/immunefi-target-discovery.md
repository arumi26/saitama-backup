# Immunefi Target Discovery Workflow

## Finding unaudited EVM protocols with GitHub

### Step 1: DeFiLlama scan
```python
# Save DeFiLlama data first (8.3MB response)
# curl -s 'https://api.llama.fi/protocols' -o /tmp/protocols.json

import json
with open('/tmp/protocols.json', 'r', errors='replace') as f:
    data = json.load(f, strict=False)

evm_chains = {'Ethereum', 'Arbitrum', 'Base', 'Optimism', 'Polygon', 'BSC', 'Binance', 'Avalanche', 'Fantom', 'Linea', 'Scroll', 'Mantle', 'Mode', 'Blast', 'Celo', 'Gnosis', 'zkSync Era'}
juicy = {'Derivatives', 'Yield', 'Yield Aggregator', 'Lending', 'Synthetics', 'RWA', 'Options', 'Leveraged Farming', 'CDP', 'Uncollateralized Lending', 'Collateral Management', 'Basis Trading'}

targets = []
for p in data:
    ct = p.get('chainTvls', {})
    total = sum(v for v in ct.values() if v and v > 0)
    if total < 1_000_000:
        continue
    cat = str(p.get('category', '') or '')
    if cat not in juicy:
        continue
    chains = set(p.get('chains', []))
    if not (chains & evm_chains):
        continue
    aud_raw = p.get('audits', '0') or '0'
    audit_count = int(aud_raw) if str(aud_raw).replace('_','').replace('None','0').isdigit() else 0
    if audit_count > 0:
        continue
    gh = p.get('github', [])
    if not gh:
        continue
    targets.append({
        'name': p['name'], 'tvl': total, 'cat': cat,
        'gh': gh, 'url': p.get('url', ''),
        'chains': list(chains & evm_chains)[:3]
    })
targets.sort(key=lambda x: -x['tvl'])
```

### Step 2: Check GitHub repo availability
```bash
curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=10" | python3 -c "
import sys, json
data = json.load(sys.stdin, strict=False)
for r in data:
    print(f\"{r['name']} | private={r.get('private')} | lang={r.get('language')}\")
"
```

### Step 3: Check Immunefi scope
Fetch `https://immunefi.com/bug-bounty/<slug>/information/` and extract:
- Maximum bounty
- Rewards by threat level
- Out-of-scope vulnerabilities (the "not eligible" section)
- Assets in scope (contract addresses)

### Step 4: Score and prioritize
| Factor | Points |
|--------|--------|
| NO audit | +5 |
| Public Solidity repo | +3 |
| Juicy category | +2 |
| TVL $1M-$20M | +2 |
| TVL $20M-$100M | +1 |
| TVL >$100M | -1 (heavily watched) |

## Results from July 2026 scan
55 protocols found with NO AUDIT + EVM + GitHub + juicy category.

Top picks:
1. **Wildcat Protocol** — $359M, Uncollateralized Lending, Ethereum, GH: wildcat-finance
2. **Templar Protocol** — $33.8M, Lending, Ethereum, GH: Templar-Protocol (Rust-based, not Solidity)
3. **T RIZE** — $23M, RWA, Base, GH: T-RIZE-Group (private repo)
4. **GAIB** — $19.9M, RWA, Multi-chain, GH: gaib-ai (private repo)
5. **Stobox** — $14M, RWA, Multi-chain, GH: StoboxTechnologies
6. **Delta Financial** — $8.9M, Options, Ethereum, GH: Delta-Financial
7. **Kinza Finance** — $6.7M, Lending, Multi-chain, GH: Kinza-Finance

## Pitfalls
- Many "NO AUDIT" protocols on DeFiLlama actually have audits not reported
- Private repos are common — fall back to Etherscan verified source
- Rust/CosmWasm protocols need different audit skills
- TVL on DeFiLlama can be stale or inflated
- Immunefi scope is STRICT — check before investing >30min
