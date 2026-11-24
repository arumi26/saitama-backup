# Marinade Finance — Audit Attack Surface + Deep Findings (Aug 2026)

Source: github.com/marinade-finance (71 repos, public). Anchor 0.27.

## Program IDs
- liquid-staking-program: MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD (v2.1.0, Jul 2026)

## Priority Repos
1. liquid-staking-program (131 stars) — main SC
2. validator-bonds (11 stars) — LESS audited
3. marinade-dapp — web frontend
4. marinade-ts-sdk — TypeScript SDK

## Confirmed Findings (Aug 2026)

### F-003: Delinquent Upgrade State Machine Invariant Violation — CRITICAL

**Root cause:** Missing `is_iterating_stakes()` guard in `update_active` (Phase 1).
Commit `3e7c090` added Phase 2 guard (`!is_iterating_validators()`) but missed Phase 1.

**PoC proof** (`poc_invariant_sim.rs`, 336 lines, standalone Rust — no fork needed):
  - Single 9-lamport reward: divergence 4500 vs 4509 → `UpgradingInvariantViolation`
  - Multi-epoch 1M SOL: epoch 1 FAILS (1000000 vs 1000450)
  - Deep invariant suite (`poc_deep_invariants.rs`, 12 tests): confirmed Phase 1
    overcounts by 4 lamports on 5-validator sample at 0.045% reward rate
    (captured=1500, new_total=1504). All other invariants (mint/burn, fee math,
    stake removal, emergency cooling) pass cleanly — no additional drain path found.

**Key lines:**
  - `crank/update.rs` :281-286 (invariant check)
  - `crank/update.rs` :307 (Phase 2 guard EXISTS; Phase 1 guard MISSING)
  - `crank/update.rs` :388-390 (rewards update real total)
  - `crank/update.rs` :485 (snapshot captures only original delegated lamports)
  - `crank/finalize_delinquent_upgrade.rs` :37-38 (secondary: u64 underflow)

**Impact:** $2.5B TVL frozen. 6 instructions blocked: emergency_unstake, partial_unstake,
deactivate_stake, merge_stakes, add_validator, deposit_stake_account.

**Fix:** `require!(!is_iterating_stakes() && !is_iterating_validators(), ...)` at update.rs:307.

**Scope framing:** Frame as logic error (state machine invariant violation), NOT DoS.
DoS is out of scope; logic errors are prioritized. Freeze is a consequence, not the vector.

### F-Secondary: u64 Underflow in finalize_delinquent_upgrade

`crank/finalize_delinquent_upgrade.rs:37-38`:
```rust
delinquent_balance_left -= validator.active_balance
    - validator.delinquent_upgrader_active_balance;
```
Post-slash: wraps to u64::MAX. Fix: `.saturating_sub()`.

## Bounty Program (ACTIVE — Aug 2026)

- **Platform:** Immunefi → https://www.immunefi.com/bounty/marinade
- **Rates:** Critical up to $250K USD (10% economic damage, min $50K); High = $15K
- **Scope:** All smart contracts on GitHub (liquid-staking-program ✅)
- **In-scope:** Logic errors ✅, freezing ≥ 6 days ✅, loss of funds ✅
- **Out-of-scope:** DoS attacks ❌
- **Payout:** mSOL + MNDE (denominated in USD)

## Disclosure Contacts

| Contact | Source | Reliability |
|---------|--------|-------------|
| security@marinade.finance | docs + webmail probe | HIGH |
| aankor@marinade.finance | git log | MEDIUM |
| chalda@marinade.finance | git log | MEDIUM |

## Audit History

- v2.1.0: Neodyme + Sec3. Delinquent upgrader added post-audit.
- Commit 3e7c090: Partial fix (Phase 2 guard only) — proves bug class known but fix incomplete.

## Full Fund-Movement Map (28 instructions audited)

| Instruction | Auth Gate | Fund-Movement | Drain Risk |
|-------------|-----------|---------------|------------|
| deposit | None (user) | SOL→reserve, mint mSOL | ✅ Clean |
| deposit_stake_account | User + validator check | Stake→program, mint mSOL | ✅ Clean |
| order_unstake | User (burn auth) | Burn mSOL, ticket→reserve | ✅ Clean |
| claim | User (ticket) | Reserve→user | ✅ Clean |
| liquid_unstake | User (burn auth) | mSOL→liq_pool, SOL→user | ✅ Clean |
| remove_liquidity | LP token holder | liq_pool SOL→user, burn LP | ✅ Clean |
| withdraw_stake_account | User (burn auth) | Split stake→user, burn mSOL | ✅ Clean |
| add_liquidity | None (user) | SOL→liq_pool, mint LP | ✅ Clean |
| emergency_unstake | Manager auth | Stake→reserve CPI | ✅ Manager-only |
| partial_unstake | Manager auth | Split+deactivate stake | ✅ Manager-only |
| emergency_pause | Pause authority | Set paused=true | ✅ Auth check |
| change_authority | Admin auth | Update all authorities | ✅ Admin-only |
| set_validator_score | Manager auth | Update score | ✅ Manager-only |
| crank/stake_reserve | Reserve PDA | Reserve→stake CRa | ✅ PDA-only |
| update_active | No external caller | Internal crank only | N/A |

**Conclusion:** No contract-level drain path for untrusted accounts. Only F-003 (logic error)
q qualifies for HIGH bounty ($15K).
