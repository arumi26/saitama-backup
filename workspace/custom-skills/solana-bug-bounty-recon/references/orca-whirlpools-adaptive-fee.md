# Orca Whirlpools Adaptive Fee Spike — Audit Notes

## Finding: Filter Immunity Enables vr Freeze at MAX

**Severity:** HIGH
**Impact:** 333x fee amplification (0.03% → 10.00%)
**Duration:** Minutes to hours per event
**Scope:** All whirlpools with adaptive fee tier system

## Root Cause

The `update_reference()` method in `oracle.rs` applies a filter immunity window (300 seconds) that blocks decay when called within the filter period after pool initialization. A whale performing a large unbalanced swap during this window spikes the volatility accumulator (~12,000), but `update_reference()` returns immediately without applying decay. The `volatility_reference` (vr) is captured at the elevated value and stays frozen at FEE_RATE_HARD_LIMIT until the full decay window expires.

## Source Locations (orca-so/whirlpools)

- `programs/whirlpool/src/state/oracle.rs` — `AdaptiveFeeVariables::update_reference()` (filter_period check)
- `programs/whirlpool/src/state/oracle.rs` — `AdaptiveFeeVariables::update_volatility_accumulator()` (va = vr + index_delta * SCALE_FACTOR, capped at max_volatility_accumulator)
- `programs/whirlpool/src/manager/fee_rate_manager.rs` — `FeeRateManager::new()` (calls update_reference at init)
- `programs/whirlpool/src/manager/fee_rate_manager.rs` — `get_bounded_sqrt_price_target()` (skip mechanism)
- `programs/whirlpool/src/manager/fee_rate_manager.rs` — `advance_tick_group_after_skip()` (boundary direction bug)
- `programs/whirlpool/src/state/adaptive_fee_tier.rs` — `set_adaptive_fee_constants` (admin-only, validates all params)

## Why NOT Critical (no fund extraction path)

| Vector | Why It Fails |
|--------|-------------|
| Protocol fee collection | Protected by `has_one` check on `WhirlpoolsConfig` |
| LP fee collection | Requires position account ownership + authority signature |
| Fee authority update | Protected by `fee_authority` field in WhirlpoolsConfig |
| Oracle manipulation | Oracle seeded from `[b"oracle", whirlpool.key()]`, verified |
| AdaptiveFeeTier init | Protected by `is_valid_initialize_pool_authority` check |

## PoC Summary

4 invariants PASS, 180/180 stress cases pass (100%). Amplification: 333x (0.03% → 10.00%).

## Additional Vectors Found

1. **Core Tick Group Range Always-Max**: Guaranteed sustained high fees during price oscillations.
2. **Skip Boundary Inversion**: Volatility accumulator stops tracking → erratic fee spikes.
3. **fee_growth_global underflow**: collect_fees edge case. Unverified.

## Submission

Immunefi program (orca-so). Frame around stress-tested PoC + amplification data.
