# Twyne (0xTwyne) — Collateral-Vault Integration-Seam Audit Notes

**Disclosure path:** email — `security@twyne.xyz` (confirmed via `https://twyne.xyz/.well-known/security.txt`, Expires 2026-12-31). No forced-KYC platform. Ideal "report ke email" target.

**Repo:** `github.com/0xTwyne/twyne-contracts-v1` (custom src ~3.2k lines). Deps via git submodule: euler-price-oracle, euler-vault-kit, aave-v3-origin, openzeppelin-contracts-upgradeable, forge-safe, forge-std. `optimizer_runs = 20_000`, no `via_ir`. Submodule tree is deep (Aave+Euler) — `git submodule update --init --recursive --depth 1` takes minutes; run background+notify. Author email fallback: `git log -1 --format="%ae"` → `bunbun295`.

**Architecture:** Twyne wraps Euler EVK (EVC/eVault) + Aave v3. A `CollateralVault` reserves credit from an `intermediateVault` (Euler eVault) and borrows against it, letting a borrower push LTV beyond the external protocol's native liq-LTV. TVL ~$14.5M (Ethereum), listed 2026-02. Also has gitbook-docs listing 8+ audits (yAudit ×5, SecEureka ×3, Enigma fuzzing ×3) — shallow surface is GONE. The live surface = cross-protocol integration seams.

## Custom-code map (audit priority)
- `src/twyne/CollateralVaultBase.sol` (611 lines) — abstract base: deposit/withdraw/borrow/repay, `liquidate()`, `handleExternalLiquidation()`, `rebalance()`, and the dynamic-LTV math.
- `src/twyne/AaveV3CollateralVault.sol` (381) + `EulerCollateralVault.sol` (365) — concrete `_getExtLiqLTV`, `_getBC`, `_canLiquidate`, `_borrow/_repay`, `_handleExcessCredit`, `_invariantCollateralAmount`.
- `src/twyne/VaultManager.sol` (304), `src/TwyneFactory/CollateralVaultFactory.sol` (167), `src/operators/*` (leverage/deleverage/teleport).

## Angles worth a PoC (unverified — need full build, likely Kali offload)
1. **`collateralForBorrower(B,C)` 3-regime interpolation** (lines ~493-518): precision/rounding at the regime boundaries (`MAXFACTOR*B >= maxLTV_t*C` vs `MAXFACTOR²*B <= liqLTV_e*C`). Interpolation case does `(MAXFACTOR²-liqLTV_e)*(maxLTV_t*C - MAXFACTOR*B) / (MAXFACTOR*(MAXFACTOR*maxLTV_t - liqLTV_e))`. Check whether a borrower can craft B/C near a boundary to extract more collateral on liquidation than the healthy `C-B`.
2. **`_isNotExternallyLiquidated()` uses RAW `IERC20(asset()).balanceOf(address(this))`** vs tracked `totalAssetsDepositedOrReserved` (line 57-59). A donation of `asset` to the vault flips the flag to "not externally liquidated" — check if a direct token transfer can mask a real external liquidation or grief the `handleExternalLiquidation` path.
3. **`skim()`** (line 332): sets `totalAssetsDepositedOrReserved = balanceOf(this)` — 1-click-leverage final step. Confirm it can't over-credit collateral vs what was actually deposited (interaction with donation + `_handleExcessCredit`).
4. **`maxRelease` / `_handleExcessCredit` desync** — internal `totalAssetsDepositedOrReserved` vs Euler `intermediateVault.debtOf(address(this))`. Any path where these drift lets credit be released/reserved incorrectly.
5. **Dynamic-LTV `_collateralScaledByLiqLTV1e8`** (line 454): `isRebalancing` includes `intermediateVault.cash()` in C_LP — a flash-deposit into the intermediate Euler vault right before `rebalance()` inflates `cash()`, potentially loosening the invariant. Trace whether `rebalance()` (permissionless, `callThroughEVC`) can be sandwiched.

**Grading discipline:** every mutating fn is `onlyBorrowerAndNotExtLiquidated` (borrower-gated) EXCEPT `liquidate()`, `rebalance()`, `canRebalance()`, `checkVaultStatus()` — those are the permissionless surface. A "trusted price"/LTV param supplied by the borrower to their OWN vault is inside granted trust (see the Trusted-Role rule) — only escalate if a THIRD party can reach the bad state. PoC-first before any severity claim.
