# Target Discovery Session — 2026-07-16

## DeFiLlama Data Quirks (confirmed)

- `/protocols` endpoint: `tvl` field populated for only 5,685/7,858 entries. Small protocols invisible through this field.
- `chainTvls` is the authoritative source for per-chain TVL. Keys follow `<ChainName>`, `<ChainName>-borrowed`, `<ChainName>-pool2`, `<ChainName>-staking`, `<ChainName>-vesting`. Sum only base chain keys.
- TVL distribution (base EVM chains only): 0-200K=39, 200K-500K=1, 500K-1M=0, 1M-5M=0, 5M-10M=0, 10M-50M=0, 50M+=10. The middle range is almost empty — most protocols are either tiny or giant.
- Juicy categories (Derivatives/Yield/Lending/RWA/Synthetics/CDP) in 200K-15M range: ~591 matches across ALL chains, ~1 match EVM-only with GitHub+no-audit.

## Promising Targets Identified

| Protocol | TVL | Cat | Aud | GH | Notes |
|----------|-----|-----|-----|-----|-------|
| GAIB | $20M | RWA | 0 | gaib-ai (private) | Ethereum/Base/Arbitrum, RWA narrative, private repo |
| Templar Protocol | $37.8M | Lending | 0 | Templar-Protocol (public) | Rust/Cargo, not Solidity. Has proxy-oracle, vault, market, kernel |
| Harvest Finance | $13.3M | Yield Agg | 1 | harvest-finance (public) | Solidity 0.5.16, jadul code, pre-SafeMath era |
| Stobox | $14M | RWA | 0 | StoboxTechnologies (public) | STV3 protocol, RWA tokenization |
| T RIZE | $23M | RWA | 0 | T-RIZE-Group (private) | Base chain |
| Moonlander | $19M | Derivatives | 0 | none | Cronos zkEVM, no GitHub |
| Metronome Synth | $15M | Synthetics | 0 | none | Ethereum/Base/Optimism, no GitHub |

## Harvest Finance Notes (Solidity 0.5.16 Attack Surface)

- Contracts use `pragma solidity 0.5.16` — no built-in overflow protection
- Uses OpenZeppelin from that era (ERC20Capped, ERC20Detailed)
- Custom `Governable` contract with `onlyGovernance` modifier
- Grain token: governance-controlled minting
- Strategy contracts: Compound interaction, vault migration
- **Bug classes available in 0.5.x:**
  - Integer overflow/underflow (no SafeMath unless explicitly imported)
  - Reentrancy (no `nonReentrant` on many functions)
  - Unchecked external calls (`address.call` without success handling)
  - tx.origin for auth (if used instead of msg.sender)

## GitHub API Pattern

Check repo privacy before cloning:
```bash
curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=10" | python3 -c "
import sys, json
data = json.load(sys.stdin, strict=False)
for r in data:
    print(f\"{r['name']} | private={r['private']} | updated={r['updated_at'][:10]}\")
"
```

## Key Insight

Protocols in the $1M-$15M range with NO audit + public GitHub + EVM + juicy category are EXTREMELY rare (~1 found across 7,858 protocols). The hunting sweet spot is:
- **$200K-$1M, EVM, juicy cat, no audit** → practically nonexistent in DeFiLlama data
- **$10M-$40M, EVM, juicy cat, 0-1 audit, public GH** → 5-10 candidates, worth deeper audit
- **$10M+ with 1 old audit + jadul Solidity** → Harvest Finance pattern, revisit old code with modern tooling