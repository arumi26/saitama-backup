# Perpetual DEX Bug Bounty Hunting

Ostium-like protocols: decentralized perpetuals, leverage trading, synthetics.
These are high-value targets — complex math, oracle dependencies, liquidation logic.

## DeFiLlama Filtering for Perpetuals

Beyond category matching (`Derivatives`, `Synthetics`, `Options`), add keyword
filtering on `name` and `description` fields:

```python
name = p.get('name','').lower()
desc = (p.get('description') or '').lower()
is_perp = any(kw in name or kw in desc for kw in [
    'perpetual','perp','leverage','margin','futures',
    'synthetix','gmx','gains','ostium'
])
```

**IMPORTANT:** Include `Dexes` category — it contains DEX derivatives (perpetuals).

## Two-Step Pipeline (required for 8.3MB DeFiLlama response)

```bash
# Step 1: Save to file
curl -s 'https://api.llama.fi/protocols' --max-time 90 -o /tmp/defillama_protocols.json

# Step 2: Process with Python
python3 -c "
import json
with open('/tmp/defillama_protocols.json') as f:
    data = json.load(f, strict=False)
# ... filter logic here
"
```

**Never** use inline `curl | python3 -c` for DeFiLlama — stdout truncation + consent guards.

## Sample Targets (2026-07-16 scan)

From 7,860 protocols, filtering for: Derivatives/Options/Synthetics, TVL $100K-$10M,
NO audit (audit_count=0), public GitHub, EVM chains:

| Protocol | TVL | Chain | GitHub | Notes |
|----------|-----|-------|--------|-------|
| Gambit Financial | $0.2M | Binance | xvi10 | next-platform-starter only (frontend, no contracts) |
| Hakka Finance | $4.3M | Binance/Ethereum | hakkafinance | Derivatives |
| Delta Financial | $9.1M | Ethereum | Delta-Financial | Options, Smart-Contracts repo, Solidity 0.7.6 |

**Delta Financial deep dive (2026-07-16):**
- Repo: `Delta-Financial/Smart-Contracts` + `Delta-Financial/StableYield`
- Solidity 0.7.6 (pre-built-in overflow checks), uses SafeMath manually
- Core: `DELTA_Deep_Farming_Vault.sol` (996 lines) — yield farming with booster system
- `DELTA_Vault_Withdrawal_MasterCopy.sol` — withdrawal proxy, 52-week vesting
- `DELTA_Distributor.sol` — reward distribution, 20% sold, 16% burned
- `Delta_Router.sol` — Uniswap V2 LP add/remove
- Contracts contain hardcoded mainnet addresses (deployed)
- Bugs found: `revert()` dead code in `withdrawEverythingWithdrawable()` line 109, `addDevested()` public with no access control, `emergencyShutdown()` naming/logic mismatch
- NOT a perpetuals protocol — more yield farming + options vesting

**Gains Network gTrade V6.1:**
- Repo: `GainsNetwork/gTrade-v6.1` (updated 2026-07-07)
- Solidity 0.8.14, 5 contract repos
- Perpetual trading with Chainlink price aggregator
- NFT-based limit order execution, timelock protection
- Audited 2x — lower novel-bug probability
- Code quality high, CEI patterns clean
- Skip unless hunting for post-audit regression bugs

## Full Target List (2026-07-16, TVL $50K-$100M, Derivatives/Synthetics/Options/Leveraged Farming/Dexes, GitHub present)

| Protocol | TVL | Category | Aud | GitHub | Chain |
|----------|-----|----------|-----|--------|-------|
| Unbound | $0.1M | Derivatives | 0 | unbound-finance | Polygon/Ethereum |
| Gambit Financial | $0.2M | Derivatives | 0 | xvi10 | Binance |
| Hakka Finance | $4.3M | Derivatives | None | hakkafinance | Binance/Ethereum |
| Delta Financial | $9.1M | Options | 0 | Delta-Financial | Ethereum |
| Gains Network | $18.2M | Derivatives | 2 | GainsNetwork | Base/Polygon |
| Avantis | $29.8M | Derivatives | 2 | Avantis-Labs | Base |
| Bumpin Trade | $4.0M | Derivatives | 0 | bumpin-exchange | Solana |
| Kai Finance | $2.8M | Leveraged Farming | 0 | kunalabs-io | Sui |
| AirPuff | $0.5M | Leveraged Farming | 0 | Airpuff | zkLink/Mantle |
| Perpetual Protocol | $0.5M | Derivatives | 2 | perpetual-protocol | Optimism |
| Stella | $0.4M | Leveraged Farming | 2 | stellaxyz | Arbitrum |
| Dual Finance | $0.7M | Options | 0 | Dual-Finance | Solana |

## GitHub Search for Fresh Perpetuals

Complement DeFiLlama with direct GitHub code search:

```bash
# Perpetual swap contracts, recent pushes, Solidity
curl -s 'https://api.github.com/search/repositories?q=perpetual+swap+contract+language:solidity+pushed:>2026-01-01&sort=updated&per_page=10'

# Leverage trading
curl -s 'https://api.github.com/search/repositories?q=leverage+trading+solidity+defi+pushed:>2026-01-01&sort=updated&per_page=10'

# GMX forks (popular perpetual DEX fork target)
curl -s 'https://api.github.com/search/repositories?q=gmx+fork+solidity+pushed:>2025-06-01&sort=updated&per_page=10'
```

**Note:** GitHub search API rate limit is 10 requests/minute. Cache results.

## Attack Surface Checklist for Perpetual DEX

| Surface | What To Look For |
|---------|-----------------|
| Price oracle | Single Chainlink feed? No TWAP? `getPrice()` called once per batch? |
| Liquidation | Price stale between vessels? Can attacker trigger liquidation at manipulated price? |
| Funding rate | Manipulable via position skew? Can attacker open opposing positions to farm funding? |
| Position size caps | `maxPosDai` adjustable by gov only? Or dynamic based on pool? |
| Slippage | Market orders — is `_slippageP` user-supplied or enforced? |
| Timelock bypass | Limit order timelock in blocks — can be bypassed via NFT execution path? |
| Delegatecall | `closeTradeMarketTimeout()` uses `delegatecall` — context-preserving reentry risk? |
| Token depeg | If protocol uses its own token as collateral — death spiral on depeg? |

## Web App Recon for Vercel-Hosted DeFi Apps

Many DeFi frontends are Next.js on Vercel. Key patterns:

### Vercel Challenge Protection
- First request: 200 with content
- Subsequent requests: 403 with `x-vercel-mitigated: challenge`
- IP-based blocking — once challenged, all endpoints return 403
- Workaround: Playwright/Puppeteer with JS execution, or residential proxy rotation
- Don't waste time retrying from same IP

### CORS Wildcard
- `Access-Control-Allow-Origin: *` on static pages = LOW impact (not bounty-able alone)
- Only report if API endpoints (returning JSON) also have wildcard CORS
- Check: `curl -sI -H 'Origin: https://evil.com' https://target/api/endpoint | grep -i access-control`

### Vercel Deployment Info
- `x-vercel-id` header leaks region + deployment hash
- `server: Vercel` confirms hosting
- `x-vercel-cache: HIT/MISS` shows caching behavior