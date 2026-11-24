# Elys Network — oracle staleness lead (case study)

Target: `github.com/elys-network/elys` — Cosmos SDK v0.50.14, CometBFT v0.38.17, ibc-go v8.7.0.
Audited at HEAD `82e60ae` ("adding manual trigger"). Cosmos DeFi app chain (perps + leveraged LP + oracle AMM).

## Module map (LOC, tests+pb excluded)
```
51341 x/commitment    12531 x/amm        10967 x/perpetual   8351 x/leveragelp
6722  x/tradeshield   6324  x/masterchef 4093  x/vaults       3974 x/tier
3938  x/stablestake   3190  x/estaking   3128  x/oracle       2684 x/tokenomics
```
Value-bearing focus: perpetual, leveragelp, amm (oracle pools), stablestake, oracle.

## LEAD: missing oracle price staleness check (spec-vs-impl drift)

### Evidence chain
1. Params define freshness knobs but nothing consumes them:
   - `x/oracle/types/params.go` `DefaultParams()`: `PriceExpiryTime = 86400` (1 day), `LifeTimeInBlocks = 1`.
   - `Price` proto (`x/oracle/types/price.pb.go`) carries `Timestamp` and `BlockHeight`.
2. The **spec** documents an `EndBlock` that prunes expired prices:
   - `x/oracle/spec/05_functions.md` and `03_keeper.md`:
     ```go
     if price.Timestamp + params.PriceExpiryTime < blockTime { RemovePrice() }
     if price.BlockHeight + params.LifeTimeInBlocks < blockHeight { RemovePrice() }
     ```
3. The **live** `x/oracle/keeper/abci.go` `EndBlock` was rewritten to only keep the newest price per asset and prune the rest — **no expiry check at all**:
   ```go
   // finds latest Timestamp per asset, RemovePrice on all others. Never compares against PriceExpiryTime.
   ```
4. Confirmed the freshness params are never read on any live read path:
   ```bash
   grep -rn "PriceExpiryTime\|LifeTimeInBlocks\|GetPriceExpiryTime\|GetLifeTimeInBlocks" x/ --include=*.go \
     | grep -v "_test\|.pb.go\|params.go"
   # → only x/oracle/migrations/v3_migration.go sets LifeTimeInBlocks=4. Zero read-path consumers.
   ```
5. Read path returns latest price unconditionally:
   - `GetDenomPrice` (`x/oracle/keeper/price.go:121`) → `GetAssetPrice` → `GetLatestPriceFromAssetAndSource` (reverse KV iterator, first hit) → no age check.
   - 107 consumer call sites across perpetual (open/liquidation/funding), leveragelp (`GetPositionHealth`, `LpTokenPriceForShare`, stop-loss, ADL), amm oracle-pool swaps.

### Impact
If feeders stop feeding (off-chain feeder outage, delisted asset, stuck Band IBC channel) the last price is used forever as if fresh → mispriced perp/leverageLP liquidations & health, wrong LP token price, mispriced oracle-pool swaps.

### Honest caveats (before rating)
- Trigger is feeder-stop/lag, NOT attacker-controlled price flip. Severity hinges on the feeder trust model (permissioned single feeder → High; redundant multi-feeder median → Medium). Must verify Elys feeder set + sources.
- Confirm no other guard exists (band ABCI, perp funding path) that gates on freshness elsewhere.

### SCOPE-GATE STATUS (re-checked Aug 21 2026) — BOUNTY NOT FOUND + TVL tiny
The scope gate is currently FAILING on two of three criteria — resolve before drafting any report:
- **No paid bounty located.** `immunefi.com/bug-bounty/elys-network` and `/elys` → 404. `docs.elys.network/others/bug-bounty`, `/security`, `/protocol/security` → all 404. Repo has no `SECURITY.md`; README mentions no bounty/immunefi/hats/audit. A prior-context note claimed the immunefi curl "returned reward text (program likely exists)" — that was NOT reproducible; the page is a hard 404. Per the user's rule (no paid bounty = skip), ASK the user for the real bounty source (Discord/direct/Hats) before investing more.
- **TVL negligible per DefiLlama.** `api.llama.fi/tvl/elys-dex` ≈ $1,069; chain `historicalChainTvl/Elys` flat ~$1,286 for days (looks stale/placeholder). Slugs `elys`/`elys-network` → "Protocol not found"; CoinGecko `elys-network` → all null. Either genuinely tiny (→ low impact) OR DefiLlama mis-tracks the app-chain — cross-check with Elys's own on-chain AMM/pool queries before rating impact; don't infer real TVL from DefiLlama alone.
- **Source + version confirmed OK & lead re-verified.** HEAD `82e60ae`, sdk v0.50.14 / cometbft v0.38.17 / ibc-go v8.7.0. Staleness lead still valid at this commit: freshness params have zero read-path consumers (only `x/oracle/migrations/v3_migration.go`), and `x/oracle/keeper/abci.go` EndBlock is still keep-newest with no `PriceExpiryTime` compare.

### PoC plan (chain's own harness)
Go test in-repo using oracle keeper + `x/amm/types/mocks/oracle_keeper.go` pattern:
1. Feed a price, 2. advance `ctx.BlockTime()` past 86400s, 3. assert `GetDenomPrice` still returns stale value, 4. open/liquidate a perp at the stale price. Offload build to remote Kali box if 2 GB VPS OOMs (`go test`, not forge).

## Secondary leads noted (not yet run)
- AMM oracle-pool rounding: `SwapOutAmtGivenIn` `resizedAmount = tokenIn / externalLiquidityRatio` (`.Dec().RoundInt()`), `CalcGivenInSlippage`, min-slippage floor branch.
- Weight-breaking fee sign/branch: `x/amm/types/weight_fees.go` `CalculateWeightFees` — `weightBalanceBonus = weightBreakingFee.Neg()`, `distanceDiff` improving/worsening branches, threshold gates.
- leveragelp `position_close.go` `CheckHealthStopLossThenRepayAndClose`: heavy Dec math, `lpSharesForRepay` ceil round-up, partial-repay path.

## Key file:line anchors
- `x/oracle/keeper/abci.go` (rewritten EndBlock, no expiry)
- `x/oracle/keeper/price.go:100-134` (GetAssetPrice / GetDenomPrice)
- `x/oracle/types/params.go:40-54` (defaults)
- `x/oracle/spec/05_functions.md:11-23` (spec EndBlock with the missing check)
- `x/leveragelp/keeper/position.go:211` (GetPositionHealth — oracle-derived)
- `x/amm/types/pool.go:307,343` (TVL, LpTokenPriceForShare)
