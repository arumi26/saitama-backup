# DeFi Target Hunting — From Scratch to PoC

## When to use
Need to find exploitable DeFi protocols from scratch — no specific target given. User says "cari target" or "exploit something."

## Step 1 — Scan DeFiLlama for juicy targets
```bash
curl -s 'https://api.llama.fi/protocols' > /tmp/protocols.json
```
Filter criteria (Python with `json.load(strict=False)`):
- **Category:** Derivatives, Yield, Yield Aggregator, Lending, Synthetics, RWA, Options, Leveraged Farming, CDP
- **TVL:** Use `chainTvls` dict (sum across EVM base keys), NOT the top-level `tvl` field (often missing/broken)
- **EVM chains:** `{'Ethereum', 'Arbitrum', 'Base', 'Optimism', 'Polygon', 'BSC', 'Binance', 'Avalanche', 'Fantom', 'Linea', 'Scroll', 'Mantle', 'Mode', 'Blast', 'Celo', 'Gnosis', 'Moonbeam', 'Moonriver', 'zkSync Era'}`
- **Audit count:** 0 = highest priority, 1 = secondary, 2+ = skip
- **GitHub:** Must have `github` field populated

**Pitfall:** DeFiLlama `chainTvls` keys use exact chain names (e.g., `Arbitrum`, not `arbitrum`). The `chains` field is a list. Both must be checked.

## Step 2 — Clone & audit contracts
```bash
# Try common repo names
for name in contracts protocol-contracts smart-contracts; do
  git clone --depth 1 "https://github.com/${org}/${name}" 2>/dev/null && break
done
```
If private repo → check via `curl -s "https://api.github.com/orgs/${org}/repos?per_page=10"` for public repos.

## Step 3 — Quick audit triage
Priority order:
1. **Vault/Pool** — holds funds, check reentrancy, CEI, access control
2. **Oracle/PriceFeed** — single-source? TWAP? staleness check?
3. **Liquidation** — edge cases, forced closures, MEV
4. **Router/PositionManager** — who can call, what's validated

Solidity <0.8: Check for raw overflow (no SafeMath). Solidity >=0.8: Focus on logic bugs, access control, oracle manipulation.

## Step 4 — On-chain verification
```python
from web3 import Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
# Use raw eth_call with Web3.keccak(text="functionName(types)")[:4] for speed
# Check: pool amounts, reserved amounts, utilisation, leverage, funding rates
```

Key metrics to collect:
- Pool amount vs reserved amount (utilisation %)
- Max leverage
- Funding rate factor
- Price spread (max - min)
- Whether pool can go insolvent (reserved > pool)

## Step 5 — Foundry PoC fork test
```bash
forge init --no-git poc && cd poc
# Write test that calls actual on-chain contracts via fork
forge test --rpc-url "$RPC" -vvvv
```
Use public RPC (Arbitrum: `https://arb1.arbitrum.io/rpc`). Archive node needed for old blocks.

## Pitfalls
1. **DeFiLlama `tvl` field often empty** — use `chainTvls` dict instead
2. **GitHub repos often private** — check `api.github.com/orgs/{org}/repos` for public alternatives
3. **Public RPC no archive** — can't fork old blocks, use latest
4. **Checksum addresses in Solidity** — Foundry rejects non-checksummed, use `cast to-check-sum-address`
5. **`emit log` in `view` functions** — Foundry reverts, remove `view` modifier from test functions
6. **Unicode in Solidity strings** — use ASCII only (`→` → `->`)

## Immunefi scope check
Always check scope BEFORE deep audit:
- `https://immunefi.com/bug-bounty/{protocol}/scope/` — lists in-scope contracts
- `https://immunefi.com/bug-bounty/{protocol}/information/` — out-of-scope exclusions
- "Primacy of Rules" = team's scope page takes precedence over Immunefi default
- Common exclusions: price manipulation, admin key exploits, economically impractical attacks
