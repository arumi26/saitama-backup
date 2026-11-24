# Aggressive Mode Bug Bounty Methodology (2026-07-24)

## Core Philosophy
**"Yang penting ada benefit buat gua"** — Fast scanning over deep dives. Permissionless exploits only.

## Owner Key Discovery via Direct On-Chain (NEW)

### Methodology
1. **Find deployed comptrollers** from DeFiLlama adapter registry
2. **Query admin hierarchy on-chain** via `cast call` / `cast storage`
3. **Identify ultimate controller** — often single EOA controlling multiple markets

### Orbit Protocol Case Study
```bash
# 1. Find comptrollers from DeFiLlama adapter
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/registries/compound.js" | grep -A 10 "orbitlending-io"

# 2. Check admin (slot 0 in UnitrollerAdminStorage)
# admin() selector = 0xf851a440
cast call <COMPTROLLER> "0xf851a440" --rpc-url https://rpc.blast.io

# 3. If admin is TimelockController, check delay
# slot = keccak256("minDelay") = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
cast storage <TIMELOCK> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url https://rpc.blast.io
# Returns 0x15180 = 86400 = 24h
```

**Orbit Results:**
| SpaceStation | Admin | Timelock |
|---|---|---|
| 0x1E18C3cb... | Timelock (24h) | YES |
| 0x273683CA... | EOA (direct) | **NO** |
| 0xe9266ae9... | EOA (direct) | **NO** |
| 0xfFF8Fc17... | EOA (direct) | **NO** |

**Ultimate Controller:** EOA `0x6315f65843e7582508e4f0aac20a7203e7b09f02` — controls 3/4 directly, 4th via timelock.

## Target Selection Criteria (Aggressive Mode)

### Priority Order
1. **Novel contracts** (not forks) — highest novel bug probability
2. **<$10M TVL, <6 months old, 0 audits** — fewest eyes
3. **Compound/Aave forks WITH permissioned extensions** — extensions = new attack surface
4. **Fork-chain protocols (Base, Blast, Mode, Linea, Scroll)** — modifications = bugs

### Avoid
- Saturated bounties (GMX, Aave, Uniswap, GMX) — 1-2h deep dive = dead end
- Well-audited protocols (>1 recent audit, 10+ paid reports)
- Known Issue Assurance + recent audit = low marginal value

## Scanning Pipeline (Aggressive)

### Phase 1: Mass Target Discovery (15 min)
```bash
# DeFiLlama filter
curl -s "https://api.llama.fi/protocols" | python3 -c "
import sys, json
data = json.load(sys.stdin, strict=False)
for p in data:
    ct = p.get('chainTvls', {})
    base_tvl = sum(v for k,v in ct.items() if k in {'Ethereum','Arbitrum','Base','Optimism','Polygon','BSC','Blast','Mode','Linea','Scroll','Mantle','Fantom','Celo','Gnosis','Moonbeam','Moonriver','zkSync Era','XRPL EVM'} and v)
    if 200_000 < base_tvl < 15_000_000 and p.get('category') in {'Lending','Derivatives','Yield','Yield Aggregator','Synthetics','RWA','Options','Leveraged Farming','CDP'}:
        aud = int(p.get('audits','0')) if str(p.get('audits','0')).replace('_','').replace('None','0').isdigit() else 0
        if aud == 0:
            print(f\"{p['name']} — \${base_tvl/1e6:.1f}M — {p.get('category')} — GH:{bool(p.get('github'))}\")
"
```

### Phase 2: Quick Filter (5 min/target)
```bash
# GitHub org check
curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=10" | python3 -c "
import sys, json
data = json.load(sys.stdin, strict=False)
for r in data:
    print(f\"{r['name']} | private={r.get('private')} | updated={r['updated_at'][:10]}\")
"

# Website alive?
curl -sI https://<protocol>.finance | head -1
```

### Phase 3: Quick Audit Scan (15 min/target)
- Clone → `forge build` → `find . -name "*.sol" | wc -l`
- Grep: `owner`, `timelock`, `oracle`, `liquidate`, `flashloan`, `fee`
- Check admin functions for timelock
- Check oracle staleness thresholds

### Phase 4: Deep Dive Top 3-5 (1-2h each)
- Foundry PoC for each finding
- Economic viability check
- Immunefi scope verification

## Bug Classes Prioritized (Aggressive)
1. **Permissionless exploits only** — oracle manipulation, reentrancy, flash loan, rounding
2. **Admin-only bugs** → only if admin = single EOA (no timelock)
3. **Economic viability** — $2.5M attack cost vs profit must be positive

## Reporting Strategy (Tiered Disclosure)
1. **Step 1:** Brief description + "I have Foundry PoC"
2. **Step 2:** Full report WITHOUT PoC code
3. **Step 3:** PoC code ONLY after bounty confirmed

## Pivot Signals
- 2h on single protocol, only "design decisions" found → PIVOT
- 17+ paid reports on bounty page → SATURATED
- Saturated protocols (GMX, Aave, Uniswap) → 1-2h max then pivot
- Web app recon as alternative revenue when smart contracts dry

## MEV Sandwich Bot (Alternative Revenue)
- Template: `templates/mev-sandwich-bot.py`
- Arbitrum L2: $2-5 gas, 24/7 operation
- Config: `max_gas_gwei=0.03`, `min_profit_usd=$10`, auto-compound

## Hard Rules
- **NO mainnet exploit** — Foundry fork simulation only
- **NO private key hunting** — ECDSA is unrecoverable
- **NO phishing/social engineering** — legal boundary
- **Foundry PoC = mandatory** before any submission
- **User pushes for black hat** — firm refusal, redirect to next target