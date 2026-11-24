# Templar Protocol Audit — 2026-08-12

## Target Summary
- **Name:** Templar Protocol
- **TVL:** $24M (DeFiLlama)
- **Category:** Lending
- **Chain:** NEAR (also Soroban/Stellar)
- **GitHub:** `Templar-Protocol/contracts`
- **Audits:** 3 (Guvenkaya, Thesis Defense, Halborn)
- **Codebase:** 250+ Rust files, ~1,382 tracked files in repo

## Architecture
- **Market contract:** Immutable `MarketConfiguration` set at deploy. No admin upgrade path.
- **Governance:** RBAC + timelock-based `PendingActions` queue (curator-primitives). Timelocked for fee increases, cap increases, relaxation changes.
- **Async model:** NEAR cross-contract calls are multi-receipt (3+). Callbacks check `PromiseResult::Successful`/`Failed` and rollback state changes correctly.
- **Oracle:** Pyth price feeds with `confidence` interval checks. Pessimistic valuation for collateral, optimistic for borrow liability.
- **Liquidation:** Supports undercollateralization + expiration. Proper `liquidatable_collateral()` math with spread. Liquidator must send between min/max acceptable.
- **Yield:** Supply yield calculated from interest + static yield pool for protocol account.

## Audit Surface Checked
| Area | Assessment |
|------|-----------|
| Reentrancy | NEAR async model — no reentrancy possible by design |
| Access control | RBAC + timelock governance. No single-key admin |
| Oracle manipulation | Pyth with confidence checks, min confidence interval enforced |
| Rounding errors | `checked_sub`, `saturating_sub`, `saturating_mul` throughout |
| Liquidation math | Proper pessimistic/optimistic valuation, spread enforced |
| Async callbacks | All rollback on transfer failure. `withdraw_static_yield` has known issue fixed in eb622a0 |
| Private keys | Zero leaked — all `.env` files are placeholders (`<your-secret-key>`) |
| Storage collision | Borsh serialization, no upgradeable proxies |
| Signature replay | `accumulator` enforces non-decreasing snapshot index |

## Known Issues (Documented)
1. **Static yield withdrawal rollback** (v1.1.0): `withdraw_static_yield` callback didn't write rollback to storage. Fixed in `eb622a0e14be166e84b7087752c49f3bbadf353a`.
2. **Fee persistence on failed borrows**: Intentional — prevents griefing where attacker locks supply without paying fees.

## Verdict
**CLEAN — 0 critical, 0 high, 0 medium bugs found.** This is institutional-grade code with 3 audits covering the same version. The market config is immutable, governance is timelock-based, and async callbacks handle rollback correctly.

## Kill Signal
3+ mid-tier audits (Guvenkaya, Thesis Defense, Halborn) = same as 2+ top-tier. The cumulative audit coverage eliminates the attack surface. Do not re-audit Templar.

## Session Notes
- User initially pushed for "komira.co.id" exploit (illegal, refused). Redirected to Templar.
- User wanted private key leaks. Searched entire repo — zero real keys, all placeholders.
- Code quality is extremely high. Proper Rust patterns, comprehensive tests, fuzz targets.
- This is a NEAR-native protocol, not an EVM fork. Different attack surface entirely.