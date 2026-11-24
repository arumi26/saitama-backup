# Non-Immunefi crypto bug bounties with public repos (shortlist, Aug 2026)

Discovered this session when the user wanted a fresh SC target and said "skip Immunefi, go direct." All figures pulled live 2026-08-21; bounty text quoted from each project's own `SECURITY.md`, TVL from DefiLlama. RE-VERIFY before relying — programs change.

## Discovery method (reusable)
Platform "active contest" APIs are unreliable for finding *open* windows (they serve archives — see the pitfall in SKILL.md). The durable move is to sweep `SECURITY.md` across candidate repos and read the reporting section:
```bash
for r in drift-labs/protocol-v2 Ellipsis-Labs/phoenix-v1 openbook-dex/openbook-v2 \
         osmosis-labs/osmosis neutron-org/neutron quicksilver-zone/quicksilver \
         Stride-Labs/stride sei-protocol/sei-chain; do
  for b in main master develop; do
    body=$(curl -sfL -m8 -A "Mozilla/5.0" "https://raw.githubusercontent.com/$r/$b/SECURITY.md") && \
      echo "=== $r@$b ===" && echo "$body" | grep -iE "bounty|immunefi|reward|hackenproof|hats|security@|disclos|\\\$[0-9]" && break
  done
done
# TVL sanity per target:
curl -sL "https://api.llama.fi/tvl/<protocol-slug>"                       # single protocol
curl -sL "https://api.llama.fi/v2/historicalChainTvl/<ChainCap>" | jq '.[-1]'   # chain
```

## Solana / Anchor (Rust) — direct-report, self-administered

### Drift Protocol v2 ⭐ top pick (confirmed bounty + real TVL)
- Bounty: **10% of funds at risk, up to $500,000** (Critical); High $10k–$50k, paid USDC. PoC on privately-deployed mainnet required for crit/high.
- Report: `hello@drift.trade` (direct, self-run, NOT a platform).
- Repo: `github.com/drift-labs/protocol-v2` (public). TVL ~$258M (DefiLlama `drift`).
- Reality: ~77k LOC Rust perp DEX, audited by OtterSec/Zellic for years = **fortress**. Easy criticals gone. Strategy: target the *freshest* module by churn, focus funds-math (liquidation, funding rate, AMM curve, spot borrow) + Pyth/Switchboard oracle staleness/confidence-interval edges. A submittable Med/High is realistic; a Critical is low-probability. Clone `programs/drift`; 10 instruction dirs, other programs in repo (openbook_v2/pyth/switchboard) are vendored deps, not the target.

### Phoenix (Ellipsis Labs)
- Bounty: **up to $200,000** (Critical); High up to $25k. Administered by Ellipsis Labs + OtterSec (direct).
- Repo: `github.com/Ellipsis-Labs/phoenix-v1` (+ `sokoban` red-black tree in scope). TVL ~$1M, labeled "Legacy" → limited upside.

### OpenBook v2 — weak
- No formal bounty ("welcome security research, will explore options"). `contact@openbook-solana.com`. Repo `openbook-dex/openbook-v2`, TVL ~$1.1M. Goodwill only.

## Cosmos-SDK (Go / CosmWasm) — direct email, NO published USD amount
All real disclosure channels but none commits a dollar figure — treat as discretionary/responsible-disclosure, not a guaranteed bounty. Do not fabricate a number.
- **Osmosis** — `security@osmosis.team` + GitHub Private Vulnerability Reporting. Mature, heavily audited, $14M TVL. (See cosmos-sdk-defi-audit skill for the module map.)
- **Quicksilver** — `security@quicksilver.zone` (72h SLA, GPG key). Repo active but DefiLlama chain TVL $0 → likely wind-down. Low priority.
- **Stride** — `security@stridelabs.co`. Protocol `stride` ~$5.4M TVL. No USD figure in policy.
- **Persistence** — `admin@persistence.one`. TVL ~$13k (negligible).
- **Composable/Picasso** — `security@composable.finance`. No amount stated.

## Important negatives (don't waste time)
- **Neutron** — `neutron-org/neutron` is now **archived**; SECURITY.md points to `security@solva.solutions` + a canonical fork `solva-solutions/neutron` (created 2026-07-13, 0 stars). This is a wind-down, not a fresh bounty. Skip.
- **Sei, Cosmos Hub (Gaia)** — route to Immunefi/HackerOne → excluded when the user refuses Immunefi.
- **Elys** — no bounty program anywhere (Immunefi + docs `/security` + `/bug-bounty` all 404), TVL ~$1.3k. Valid bugs exist (oracle staleness PoC went green) but nowhere to submit + no economic impact → unpaid research only.
- **Shardeum** — NOT Cosmos (TypeScript EVM L1); only a GitHub `bug-reporting` issue tracker, no paid bounty. Skip.
- **Sherlock** — zero currently-open public bug bounties this session (Metric $150k / Tare $50k both closed late-July 2026, in judging). Worth re-polling `/contests?page=1` for the next fresh public bounty.

## Bottom line
Only Drift ($500k) and Phoenix ($200k) satisfy all of {real USD bounty, public repo, not-Immunefi, deployed with TVL} with a *confirmed* figure. Drift is the clear top pick despite being a fortress: highest ceiling + $258M TVL = a real incentive to pay even a Medium. Cosmos direct-email channels are real but pay is discretionary/unconfirmed.
