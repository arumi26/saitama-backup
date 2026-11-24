
# Cosmos SDK DeFi Chain Audit (Go)

Class-level workflow for auditing Cosmos-SDK DeFi protocols (Go, not Solidity/Rust-consensus). Sibling to `web3-audit` (Solidity), `rust-protocol-audit` (Rust consensus), `solana-anchor-audit-triage`. Reach here when the target is a **Cosmos SDK application chain** with DeFi `x/` modules.

## 0. Scope gate (before any deep work)
- Confirm public source + live bounty (Immunefi/Hats/direct) + real TVL. No bounty = skip. (User rejects inflated severity and scanner noise — see `triage-validation`.)
- Note the cosmos-sdk / cometbft / ibc-go versions from `go.mod` — bug patterns and SDK-provided guards differ across v0.47/v0.50.

### Finding the bounty channel + verifying TVL (do this FIRST, it kills dead targets fast)
User often says "skip Immunefi / go direct" — and many Cosmos chains report to a **direct email**, not a platform. Discover the channel by sweeping `SECURITY.md` across candidate repos rather than guessing URLs:
```bash
# Sweep SECURITY.md for a batch of chains, then read the reporting section:
for r in osmosis-labs/osmosis neutron-org/neutron sei-protocol/sei-chain quicksilver-zone/quicksilver; do
  for b in main master develop; do
    curl -sfL -m8 -A "Mozilla/5.0" "https://raw.githubusercontent.com/$r/$b/SECURITY.md" \
      | grep -iE "bounty|immunefi|reward|hackenproof|hats|security@|disclos|\\\$[0-9]" && echo "  ^^ $r@$b" && break
  done
done
```
Observed Aug 2026: **Osmosis** → `security@osmosis.team` + GitHub Private Vulnerability Reporting (direct, Go/Cosmos, $14M TVL) ✅; **Neutron** → `security@solva.solutions` (direct, but CosmWasm-heavy); **Quicksilver** → `security@quicksilver.zone` (72h SLA); **Sei** → routes back to Immunefi (skip if user refuses Immunefi). No `SECURITY.md` + no platform page = likely no paid bounty (e.g. Elys: Immunefi/docs both 404 → treat as unpaid research only).

Verify **real TVL** before committing (a live-looking dApp can have ~$0 TVL — Elys read flat **$1.3k** for days):
```bash
curl -sL -m10 "https://api.llama.fi/v2/historicalChainTvl/<ChainNameCap>" | jq -r '.[-1] | "tvl=$\(.tvl)"'  # chain TVL
curl -sL -m10 "https://api.llama.fi/tvl/<protocol-slug>"                                                       # single protocol
```
Flat TVL over many days or a tiny absolute number ⇒ dead/placeholder feed; economic impact ≈ 0, so even a valid bug isn't worth a report. Public LCD `.../amm/pool_all` returning `"Not Implemented"` (code 12) is common and does NOT confirm TVL either way — trust DefiLlama's chain series over a random public LCD.

### PITFALL — verify the target is ACTUALLY Cosmos before loading this workflow
Do NOT trust the ecosystem label the user (or a listing) gives. Confirm the stack yourself with two cheap curls before cloning:
```bash
curl -sL -m12 -A "Mozilla/5.0" -o /dev/null -w "%{http_code}\n" \
  "https://raw.githubusercontent.com/<org>/<repo>/<branch>/go.mod"   # 200 + cosmos-sdk line = real Cosmos
curl -sL -m12 -A "Mozilla/5.0" "https://raw.githubusercontent.com/<org>/<repo>/<branch>/package.json" | jq -r .name
```
`go.mod` 404 + a `package.json` present ⇒ it's a TS / Go-EVM chain, NOT Cosmos SDK — this skill's `x/`-module / `math.LegacyDec` / oracle-keeper techniques don't apply. Real miss (Aug 2026): user asked to "hack Shardeum" calling it a Cosmos target; Shardeum is a **TypeScript EVM L1** (Shardus consensus, `@shardeum-foundation/*` deps, no `go.mod`) with **no paid bounty** — only a public GitHub `bug-reporting` issue tracker (`shardeum.org/bug-bounty` and `immunefi.com/bug-bounty/shardeum` both 404). No paid bounty = skip regardless of stack. Surface the mismatch and ask for the real bounty source rather than burning time on the wrong methodology.

## 1. Clone + module triage
```bash
git clone --depth 1 <repo> && cd <repo>
git log -1 --oneline                       # pin the commit you audit
grep -E "cosmos-sdk|cometbft|ibc-go" go.mod
ls x/                                       # module list
# LOC per module (skip tests + generated pb.go) → attack-surface ranking
for d in x/*/; do n=$(find "$d" -name '*.go' ! -name '*_test.go' ! -name '*.pb.go' | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'); echo "$n  $d"; done | sort -rn
```
Prioritize value-bearing modules: perpetual, leveragelp, amm/dex, stablestake, oracle, masterchef/staking. Deprioritize commitment/tokenomics/params unless they gate the above.

## 2. Map the oracle price path FIRST
Oracle is the root of trust for every DeFi calc (health, liquidation, LP price, swap). Trace it end to end:
```bash
grep -rn "func.*GetDenomPrice\|func.*GetAssetPrice\|func.*GetLatestPrice" x/oracle/ | grep -v "_test\|.pb.go"
grep -rn "GetDenomPrice\|GetAssetPrice" x/ --include=*.go | grep -v "_test\|.pb.go\|mocks/\|func (k Keeper)" | wc -l   # count consumers
```
Then hunt the highest-yield oracle bugs (see §3).

## 3. The five high-yield Cosmos-DeFi bug classes

### A. Stale / unchecked oracle price  (most common, often High)
Cosmos oracle modules keep the "latest" price in KV store. Check whether the **read path enforces freshness**:
- Is there a `PriceExpiryTime` / `LifeTimeInBlocks` / staleness param? Is it actually **read** on the read path, or only set in params?
  ```bash
  grep -rn "PriceExpiryTime\|LifeTimeInBlocks\|Stale\|expir" x/ --include=*.go | grep -v "_test\|.pb.go\|params.go\|spec/"
  ```
  Empty result = the param is dead weight and prices never expire → **stale-price finding**. Trigger: feeder outage / delisted asset / stuck IBC (Band) channel → last price used forever as if fresh → mispriced liquidations, LP token price, swaps.
- Severity depends on the **feeder trust model**: single/centralized permissioned feeder → High; multi-feeder redundant with median → Medium. Verify before rating.

### B. Spec-vs-implementation drift  (reusable technique)
Cosmos repos ship `x/<module>/spec/*.md` with reference `Keeper` code. Diff the spec against the live keeper — protocols refactor `abci.go` (Begin/EndBlock) and silently drop guards the spec still documents.
```bash
for m in x/*/; do [ -d "$m/spec" ] && echo "=== $m ===" && ls "$m/spec"; done
# read spec/*_functions.md / *_keeper.md, then compare to keeper/abci.go, keeper/price.go
```
Elys case: spec `EndBlock` pruned expired prices via `PriceExpiryTime`; the live `abci.go` ("adding manual trigger" commit) replaced it with "keep only newest, no expiry check". See `references/elys-oracle-staleness.md`.

### C. Rounding / precision loss in Dec / BigDec math
Cosmos uses `math.LegacyDec` and osmosis `osmomath.BigDec`. Hunt:
- `TruncateInt()` vs `RoundInt()` vs `.Ceil()` — who eats the rounding, user or pool? Pool should round in its own favor.
- Division before multiplication; `.Quo()` then `.Mul()` losing precision.
- `resizedAmount = tokenIn / externalLiquidityRatio` style resizing (oracle-pool slippage) — dust/zero at small inputs → free/underpriced swaps.
```bash
grep -rn "Quo\|Mul\|TruncateInt\|RoundInt\|Ceil\|Power\|Pow" x/amm/types/*.go | grep -iv _test | grep -i "swap\|price\|slippage\|share\|fee"
```

### D. Weight-breaking-fee / bonus sign & branch errors  (Osmosis-fork AMM)
Oracle pools (Plasma/Elys-style) charge a weight-breaking fee when a swap worsens pool balance and pay a bonus when it improves. Audit `CalculateWeightFees` / `GetWeightBreakingFee`:
- Sign of `weightBalanceBonus` (negative bonus = fee); `distanceDiff` branch (improving vs worsening); threshold `ThresholdWeightDifference`.
- Can an attacker craft a swap that flips the branch to **collect a bonus while worsening** the pool, or skip the fee? Cross-check `SwapOutAmtGivenIn` + `weight_fees.go`.

**High-yield technique — trace where the bonus is PAID, then diff the JOIN vs EXIT paths for asymmetry.** `CalculateWeightFees` only computes a number; the money moves in the `Apply*PoolStateChange` keeper funcs. Grep the consumers first:
```bash
grep -rn "weightBalanceBonus\|WeightBalanceBonus" x/amm/keeper/*.go | grep -iv _test
```
Then read `apply_join_pool_state_change.go` vs `apply_exit_pool_state_change.go` side by side. Elys (Aug 2026, HEAD 82e60ae) shows the pattern to look for:
- **JOIN**: positive bonus is actually paid out — `bankKeeper.SendCoins(rebalanceTreasury → joiner)` for `weightBalanceBonus.IsPositive() && joinCoins.Len()==1`; negative bonus pulls a `weightRecoveryFee` into the treasury. Money leaves the treasury here.
- **EXIT**: `weightBalanceBonus` is in the function **signature (line 14) but never referenced in the body** — the positive-bonus payout branch that JOIN has simply does not exist on exit.
That JOIN/EXIT asymmetry is the lead: if an attacker can repeatedly craft a *bonus-earning* join (drive `distanceDiff` negative past `ThresholdWeightDifference` so `weightBalanceBonus = weightRecoveryReward > 0`), each join drains `rebalanceTreasury` via `SendCoins`. Bounded by `treasuryTokenAmount` (payout is `min(bonus, treasury balance)`) — verify the treasury is attacker-refillable / non-trivially funded before rating. This is **attacker-controlled** (unlike stale-oracle which needs a feeder outage), so it rates higher if the PoC drains net-positive. PoC it with the keeper harness: seed a 2-asset oracle pool off-target-weight, join with the underweighted asset, assert `joiner` balance rose from treasury. See `references/elys-amm-weight-fee-lead.md`.

### E. Liquidation / position-health mispricing & Begin/EndBlock DoS
- `GetPositionHealth`, `LpTokenPriceForShare`, `TVL` — all oracle-derived; a stale/zero price here mis-triggers or blocks liquidations.
- BeginBlocker/EndBlocker loops over positions with pagination (`NumberPerBlock`, `NextKey`). Look for: unbounded iteration, panic in a per-position path not wrapped in `CacheContext`+recover (one bad position bricks the whole liquidation sweep), counter/`NextKey` desync skipping positions.
- `x/<mod>/keeper/begin_blocker.go`, `adl.go`, `position_close.go`.

### F. Smart-account / authenticator abstraction (Osmosis `x/smart-account`, and forks)
Osmosis-style account abstraction: pluggable authenticators (`AnyOf`, `AllOf`, `SignatureVerification`, `CosmwasmAuthenticatorV1`, spend-limit) checked in an ante decorator and re-checked in a post decorator. Historically bug-rich, but Osmosis `x/smart-account` is now **heavily audited** — expect a fortress; only chase if you find a concrete break, and grep the module's own tests for `Exploit`/`expected` first (dup guard). Where to look:
- **ante vs post divergence** (`x/smart-account/ante/ante.go` vs `post/post.go`): ante validates `len(selectedAuthenticators) == msgCount` in `GetSelectedAuthenticators`; post reads `selectedAuthenticatorsFromExtension[msgIndex]` **without** re-checking length. Same tx flows through both, so usually non-exploitable — but confirm the extension can't differ between phases.
- **`AnyOf.Authenticate`**: returns `nil` on the first sub-auth that passes (1-of-N). **`AllOf`**: fail-fast, all must pass. Check the loop can't be tricked into 0 iterations (guarded: `len==0` errors, `Initialize` requires `>=2` sub-auths).
- **`splitSignatures`** (`composite.go`): guarded with `len(signatures) != total` — index bugs already closed.
- **State-mutation discipline**: `Authenticate` MUST run on `neverWriteCtx, _ := ctx.CacheContext()` (never writes); mutation belongs in `Track`. `AnyOf.ConfirmExecution` uses `cacheCtx`+`write()` so only the succeeding sub-auth's writes persist. A violation (Authenticate writing to real ctx, or ConfirmExecution not cache-isolating) would be the finding.
- **`CosmwasmAuthenticatorV1`**: calls `contractKeeper.Sudo(ctx, contractAddr, ...)` into a user-chosen contract for auth. Surface exists (untrusted contract in the auth path) but requires an attacker-owned account + malicious contract, so impact is usually self-limited.

## 4. PoC — use the chain's own keeper test harness
Don't hand-roll. Cosmos modules ship keeper test suites (`keeper_test.go`, `testutil/`, mock oracle keepers under `types/mocks/`). Write a Go unit/integration test inside the repo that:
1. Seeds a price via the oracle keeper.
2. Advances `ctx.BlockTime()` / `BlockHeight()` past the (unenforced) expiry.
3. Asserts `GetDenomPrice` still returns the stale value, then drives a liquidation/swap at the stale price.
Green test = concrete PoC, not theory. If the 2 GB VPS can't build, offload to the remote Kali box (see `foundry-poc-remote-harness` for the Tailscale/SSH offload pattern — same idea, `go test` instead of `forge`).

**PITFALL — the Kali offload box may have NO Go toolchain preinstalled** (provisioned for Solidity/web-recon; `go version` → "GO MISSING"). Install before any `go test`/`go build`:
```bash
SUDO_ASKPASS=/tmp/.ap.sh sudo -A DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go   # apt candidate ≈ Go 1.26 (Aug 2026)
/usr/bin/go version   # verify
```
`go` is not on PATH non-interactively — call `/usr/bin/go` or `export PATH="/usr/bin:$HOME/go/bin:$PATH"`. The first `go test` pulls the whole module graph (cosmos-sdk + cometbft + ibc-go, hundreds of MB) — run it `background=true, notify_on_complete=true`, never foreground (the ssh call hits the 60s clamp). Clone into a persistent path (`~/elys`), not `/tmp`, since the box wipes `/tmp` on reboot. For Solana/Anchor targets the same box carries rustc/cargo + `anchor-cli` (no `solana` CLI) — usable for the `solana-anchor-audit-triage` flow without extra install.

**PITFALL — `go.work` workspace mode breaks `-mod=mod`.** Most modern Cosmos repos ship a `go.work` (+ `go.work.sum`; Elys uses `use ( . ./indexer )`). In workspace mode `go test -mod=mod` dies with `-mod may only be set to readonly or vendor when in workspace mode`. Fix: run with **`GOWORK=off`** and drop any `-mod` flag.

**PITFALL — `GOTOOLCHAIN=auto` is NOT enough; PIN to the exact `go.mod` version.** Verified the hard way this session: with Kali's system Go 1.26 and `GOTOOLCHAIN=auto`, the build failed at link time with `github.com/bytedance/sonic/ast: invalid reference to encoding/json.unquoteBytes` (sonic reaches into stdlib internals that moved between Go 1.23→1.26). `auto` did NOT downgrade to the pinned toolchain — it linked with 1.26 and broke. Fix: read `grep '^go ' go.mod` and pin exactly, e.g. `GOTOOLCHAIN=go1.23.9` (Go auto-downloads that toolchain and links cleanly). Working invocation:
```bash
export GOWORK=off GOTOOLCHAIN=go1.23.9 PATH=/usr/bin:$PATH   # match go1.23.9 to `grep '^go ' go.mod`
cd ~/elys && go test ./x/oracle/keeper/ -run TestKeeperSuite/TestPoC_OracleStaleness -v -count=1
```
Sequence that actually got to green (3 tries): `-mod=mod` → workspace error; `GOWORK=off GOTOOLCHAIN=auto` → sonic link error; `GOWORK=off GOTOOLCHAIN=go1.23.9` → PASS.

**Test placement + harness reuse.** Drop the PoC *inside the module's own package*, never in `/tmp` (import resolution + linter fail otherwise). Copy to `x/<mod>/keeper/zz_poc_<name>_test.go` (`zz_` prefix sorts it last/obvious), `package keeper_test`, and reuse the existing `KeeperTestSuite`. Elys pattern:
```go
// suite setup already exists in keeper_test.go:
//   suite.app = simapp.InitElysTestApp(true, suite.T())
//   suite.ctx = app.BaseApp.NewContext(true)
func (suite *KeeperTestSuite) TestPoC_OracleStaleness() {
    k := suite.app.OracleKeeper
    ctx := suite.ctx.WithBlockTime(t0).WithBlockHeight(100)
    k.SetPrice(ctx, types.Price{Asset:"ATOM", Price: sdkmath.LegacyMustNewDecFromStr("10.0"),
        Source: types.ELYS, Timestamp: uint64(t0.Unix()), BlockHeight: 100})
    ctx = ctx.WithBlockTime(t0.Add(30*24*time.Hour)).WithBlockHeight(h)  // advance past 86400s expiry
    k.EndBlock(ctx)                                                       // prove pruning != expiry
    p, found := k.GetAssetPrice(ctx, "ATOM")                             // still $10 => stale bug
}
```
Note the **module major-version suffix** from `go.mod` line 1 (Elys = `github.com/elys-network/elys/v7`) — imports and the `simapp` path carry the `/vN`.

## 5. Report
Run the 14-point `triage-validation` gate before submitting. Rate honestly on the feeder/trust model. Use `report-writing` for the draft. User wants ready-to-paste email + PDF from their own account.

## Pitfalls
1. **Don't rate stale-oracle as Critical reflexively** — it needs a feeder-outage/lag trigger, not attacker-controlled price flip. Verify feeder model first.
2. **`.pb.go` and `mocks/` are noise** — always exclude from grep, or LOC/consumer counts lie.
3. **Spec is aspirational** — the `spec/*.md` may describe code that no longer exists; that gap IS the finding, but confirm the live keeper, never report off the spec alone.
4. **Generated params getters (`GetPriceExpiryTime`) existing ≠ being called** — grep for the call site, not the definition.
5. **Web/Firecrawl tools may be down on the box** — fall back to `curl -A "Mozilla/5.0" <immunefi-url>` to confirm the program/scope exists; never fabricate bounty numbers.
6. **Oracle pools are 2-asset only** in many forks (`Validate()` enforces `len(PoolAssets)==2`) — multi-asset attack ideas may be dead on arrival.
7. **DUP-CHECK against the target's OWN test suite before PoC'ing any AMM/join/swap lead.** Mature protocols ship regression tests for the exact vector you're chasing, marked so the exploit is *expected to fail*. Grep first: `grep -rln "Exploit\|exploit\|unfair\|manipulat\|attack" x/<mod>/keeper/*_test.go`. Elys had `TestMsgServerJoinPoolExploitScenario` ("unfair liquidity extraction", asserts `GreaterOrEqual(expectedNumShares, resp.ShareAmountOut)`, `expPass:false`) — that guard killed the weight-bonus-drain lead as a likely known/mitigated issue. Same lesson as Twyne (`test_e_vectorAttack` marked "expected"). Also check design-level self-limiting: `WeightBreakingFeePortion=0.5` means you pay full breaking fee on imbalance but recover only half on rebalance → net extraction negative by design; bonus payout is `min(bonus, treasuryBalance)`.
8. **Recency ranking on a `--depth 1` clone is useless** — `git log -1 --format=%ci -- x/<mod>/` returns the same squash/bump date for every module (Osmosis showed all modules at one date). To find the *least-audited* module, use LOC + module novelty (is it Osmosis-unique like `protorev`/`smart-account`/`cosmwasmpool`, or a well-worn `gamm`/`bank` fork?), not file mtime. Fetch full history (`git clone` without `--depth`, or `git log` per path on a full clone) if you genuinely need churn data.

## Osmosis-specific attack surface (Aug 2026, HEAD ~v31, cosmos-sdk 0.50.14)
Module LOC ranking (largest first): `concentrated-liquidity` 13.8k, `gamm` 11.3k, `poolmanager` 9.4k, `superfluid` 7.6k, `protorev` 6.9k, `incentives` 6.5k, `lockup` 6.4k, `smart-account` 4.2k, `txfees` 3.5k, `cosmwasmpool` 2.8k, `tokenfactory` 2.7k, `twap` 2.6k. Highest-yield-per-audit-scarcity: **concentrated-liquidity** (tick/`sqrtPrice` rounding — biggest surface), **protorev** (Osmosis-unique MEV/arb; profit split `arbProfit.Amount.MulRaw(profitSplit).QuoRaw(100)` in `developer_fees.go` — check truncation/who-eats-the-dust and `ConvertProfits` denom path), **smart-account** (see §3F — but fortress). Core `gamm`/`bank`/`staking` are worn smooth by years of audits; deprioritize unless you spot something concrete.

## References
- `references/elys-oracle-staleness.md` — full Elys case: module map, the spec-vs-impl oracle staleness lead, and the grep chain that found it.
- `references/elys-amm-weight-fee-lead.md` — Elys AMM weight-balance-bonus JOIN/EXIT payout asymmetry lead (attacker-controlled treasury-drain hypothesis), rate-limiters to verify, and PoC plan.
