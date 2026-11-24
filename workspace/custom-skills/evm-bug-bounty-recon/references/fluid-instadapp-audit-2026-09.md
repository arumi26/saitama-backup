# Fluid (Instadapp) — Smart Contract Audit Case Study (2026-09)

Repo: `instadapp/fluid-contracts-public` (local `/home/ubuntu/bb/instadapp/fluid`, `git clone --depth 1`).
Verdict: **0 exploitable high/critical.** Live mainnet protocol, multiple prior audits. Not a soft target.

## Architecture map (where the money is)
- `liquidity/` — core Liquidity layer (all funds held here; protocols plug in)
- `protocols/lending/fToken` — ERC4626-style lending shares (`_tokenExchangePrice` vs `_liquidityExchangePrice`)
- `protocols/lending/merkleDistributor` — reward claims (cumulative + optional vesting)
- `protocols/dex/poolT1`, `protocols/dex/smartLending` — DEX / leveraged
- `protocols/dexLite` — newer DEX module (less battle-tested → higher-value pivot)
- `protocols/vault/vaultT1`, `protocols/vault/vaultTypesCommon` — vaults + liquidation
- `config/*Auth` — auth contracts (e.g. `paybackOnBehalfAuth`)
- `periphery/wallet`, `periphery/liquidation`, `periphery/wethWrapper`
- `oracleV2/usdOracle`

## Slither is blocked on this repo (do NOT burn cycles)
```bash
slither . --compile-force-framework foundry --filter-paths "lib/|mocks/|test/"
# -> slither.solc_parsing.exceptions.ParsingError: Type not found struct Structs.RateDataV1Params
```
Known slither parsing limitation here, not a code finding. Fall back to manual read + targeted grep.

## Targeted grep set that worked
```bash
cd contracts
grep -rn 'tx.origin' --include=*.sol . | grep -v lib/
grep -rn 'delegatecall' --include=*.sol . | grep -v lib/ | grep -vi spell
grep -rc 'unchecked' --include=*.sol protocols/ | grep -v ':0' | sort -t: -k2 -rn | head
grep -rn 'function .*external.*onlyOwner' --include=*.sol periphery/
grep -rn -A6 'function liquidityCallback\|function dexCallback' --include=*.sol protocols/
```

## Callback auth invariant (Fluid-style Liquidity layer)
Every `liquidityCallback` / `dexCallback` MUST check `msg.sender == LIQUIDITY` **and** an entered-bit
(e.g. `vaultVariables & 1 == 0`, `dexVariables & 1 == 0`, `_status == ENTERED`). Verified present in
vault/vaultT1, dex/poolT1, fToken, paybackOnBehalfAuth. This is the invariant to re-verify on forks.

## Findings reviewed → verdict
| Area | Observation | Verdict |
|---|---|---|
| merkleDistributor `_claim` | `claimed[recipient][positionId]` NOT keyed per cycle; cumulative `cumulativeAmount_ - claimed` | ✅ Safe (cumulative design, no double-claim; underflow guarded) |
| merkleDistributor `approveRoot` | no `whenNotPaused` (proposeRoot has it) | ⚠️ Low — inconsistent, minimal impact |
| merkleDistributor config | comment says `cyclesPerDistribution==0 = paused`, code reverts | ℹ️ Info — comment/code mismatch |
| fToken exchange-price | rewards rate capped ±MAX_REWARDS_RATE; static offset clamped ≥0; liquidity EP monotonic check | ✅ Safe |
| paybackOnBehalfAuth `_status` | set ENTERED without try/finally | ℹ️ Info — `onlyMultisig` + all revert paths revert whole tx, no stuck state |
| periphery/wallet `delegatecall` | arbitrary target delegatecall | ✅ By-design — `_validateOwner` recomputes CREATE2 addr; owner-gated |

## Heavily-audited signal (learn to pivot)
fToken/main.sol carries in-code comments that literally answer prior auditors, e.g.
"Note to be extra safe we do the burn before the withdrawFromLiquidity" and
"no overflow: |rewardsRate_| <= MAX_REWARDS_RATE (50e12), timeElapsed bounded".
When you see this, the core is picked clean. Stop grinding; pivot to newer modules
(`dexLite`, `smartLending`, `vaultT1`) or another target.

## Submission note
Do not submit Low/Info to a battle-tested protocol — dup/no-impact, burns reputation.
