# Elys AMM — weight-balance-bonus JOIN/EXIT asymmetry (lead)

Target: `github.com/elys-network/elys/v7`, HEAD `82e60ae`. Cosmos SDK v0.50.14 / CometBFT v0.38.17 / ibc-go v8.7.0. Osmosis-fork oracle AMM (`x/amm`, `PoolParams.UseOracle`).

## The bonus/fee mechanism
`x/amm/types/weight_fees.go` `CalculateWeightFees` returns `(weightBalanceBonus, weightBreakingFee, swapFee)`:
- `initialWeightDistance` / `weightDistance` = pool distance from target weights before/after the op; `distanceDiff = weightDistance - initialWeightDistance`.
- `weightBalanceBonus := weightBreakingFee.Neg()` by default (a fee, i.e. negative bonus).
- If `distanceDiff.IsNegative()` (op IMPROVES balance): fee zeroed, and if `initialWeightDistance > ThresholdWeightDifference` then `weightBalanceBonus = weightRecoveryReward` (**positive** = pool pays user).
- `GetWeightBreakingFee` (`x/amm/types/utils.go:74`) caps fee at 0.99 and is a `Pow` of weight ratios.

## The asymmetry (the actual lead)
The number computed above only moves money inside the `Apply*PoolStateChange` keeper funcs:

- `x/amm/keeper/apply_join_pool_state_change.go`
  - `weightBalanceBonus.IsNegative()` branch (line ~63): pulls `weightRecoveryFee = bonus.Abs()*WeightBreakingFeePortion` from pool → `rebalanceTreasury`.
  - `weightBalanceBonus.IsPositive() && joinCoins.Len()==1` branch (line ~96): computes `bonusTokenAmount = joinAmt*bonus*inPrice/outPrice`, clamps to `min(bonus, treasuryBalance)`, and **`bankKeeper.SendCoins(rebalanceTreasury → joiner)`**. This is a real outflow to the user.
- `x/amm/keeper/apply_exit_pool_state_change.go` (121 lines total)
  - `weightBalanceBonus` appears **only in the signature (line 14)**; `grep -n weightBalanceBonus` returns that one line. No positive-bonus payout branch, no negative-bonus recovery branch. Exit swap/taker fees are handled but the weight bonus is silently dropped.

So the positive-bonus payout exists on JOIN but not EXIT. On the swap path, `SwapOutAmtGivenIn` (`x/amm/types/swap_out_amt_given_in.go`) computes `weightBalanceBonus` via the same `CalculateWeightFees` and returns it; `calc_in_route_spot_price.go` / `calc_out_route_spot_price.go` add it into `weightBalance` and pay `bonusTokenAmount` from treasury when `.IsPositive()`.

## Attack hypothesis (unproven at session end — PoC pending)
1. Create/seed a 2-asset `UseOracle` pool that is off-target-weight so `initialWeightDistance > ThresholdWeightDifference`.
2. JOIN (or swap) with the underweighted asset so `distanceDiff < 0` (improves balance) → `weightBalanceBonus = weightRecoveryReward > 0`.
3. `apply_join_pool_state_change` sends bonus tokens from `rebalanceTreasury` to attacker.
4. Immediately reverse (exit / opposite swap) — since EXIT drops the bonus, the round-trip may net positive if the bonus paid out exceeds the fees on the reverse leg.

## Rate-limiters to verify before claiming severity
- Payout is `min(bonusTokenAmount, rebalanceTreasury balance of otherAsset)` — capped by treasury funding. If treasury is dust, impact is dust.
- Reverse leg pays swap fee + taker fee + weight-breaking fee (the worsening direction), which may exceed the bonus → net loss, no bug. Must PoC net P&L, not just "bonus was paid".
- `distanceDiff` sign + `ThresholdWeightDifference` / `ThresholdWeightDifferenceSwapFee` gating may make the bonus branch unreachable in a single tx.

## PoC plan (keeper harness)
`x/amm/keeper/zz_poc_weightbonus_test.go`, `package keeper_test`, reuse `KeeperTestSuite`. Seed oracle prices for both denoms, create a `UseOracle` pool skewed off target weight, fund `rebalanceTreasury`, record attacker balance, JOIN with underweighted asset, assert attacker balance increased by treasury outflow, then measure round-trip P&L. Build on Kali with `GOWORK=off GOTOOLCHAIN=auto` (see SKILL.md §4 pitfalls).

## Scope caveat (blocking)
As of Aug 2026 no paid Elys bounty was found: `immunefi.com/bug-bounty/elys-network` → 404, `docs.elys.network/security` & `/others/bug-bounty` → 404, repo README has no bounty/immunefi mention. DefiLlama `elys-dex` TVL ≈ $1k (flat) — likely mis-tracked (app-chain has its own on-chain TVL) but must be confirmed via a working LCD before rating economic impact. Confirm a payout venue + real TVL before investing in the full report.
