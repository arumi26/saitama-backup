# Exactly Protocol Case Study (July 2026)

## Target
- **Protocol:** Exactly Protocol (`exactly/protocol`)
- **Live TVL:** ~$2.9M total deposits as of app.exact.ly extraction
- **Bounty:** $25K Critical (Immunefi)
- **Type:** Lending + installments router on Optimism
- **Repos checked:** `exactly/protocol` public source; periphery files include `InstallmentsRouter.sol`, `EscrowedEXA.sol`, `DebtManager.sol`, `Swapper.sol`, `StakedEXA.sol`, `RewardsController.sol`

## Targeted Surfaces (Current Session)

- **InstallmentsRouter:** arithmetic/accounting path for installment borrow/repay, maxRepay logic, and any summation loops where overflow or rounding could bypass repayment caps.
- **EscrowedEXA:** reserve/savings accounting, vesting/broker fee flow, and transfer/claim hooks.
- **DebtManager:** flash-loan-backed leverage/deleverage paths, Balancer flash-loan callback state updates, and any post-leverage health-factor assumptions.
- **Swapper:** Socket Gateway return-value trust, Permit2 nonce domain separation, ETH/EXA swap slippage checks.
- **StakedEXA / RewardsController:** penalty/rounding logic, harvest callback surface, savings redirection.

## Compile-Tooling Caveat

This session hit a non-durable tooling blocker while scaffolding PoCs: `forge install` was unavailable in the first shell, and after installing dependencies the OpenZeppelin preset constructor signature did not match the local OZ package layout. That is an environment/state issue, not a protocol bug. Capture as a pitfall:

- Prefer `forge-std` + minimal hand-written mock ERC20 when PoC scaffolding is needed.
- Do not let `new ERC20(name, symbol, decimals)` failures block analysis; keep PoC lightweight until dependencies stabilize.

## Lessons Learned

1. **Target viability changed post-deep-dive.** The earlier `$50M+` / `$50K-$1M` framing is stale. Use live app/Immunefi scope as source of truth, not cached notes.
2. **Well-audited but not perfect:** Even audited protocols miss deprecated function usage.
3. **Low bounty for low-likelihood bugs:** $1K-$5K range, not jackpot.
4. **Expand search:** Look for multiple bug classes simultaneously (oracle, rounding, access control, reentrancy).
5. **Web/API recon can compensate for thin contract surface.** When smart contract audit yields low-confidence findings, pivot quickly to web/app/API/bridge surfaces instead of burning more contract hours.
6. **PoC scaffolding failures are not analysis failures.** Keep the hunt moving; write a minimal mock-based PoC rather than fighting toolchain state.
