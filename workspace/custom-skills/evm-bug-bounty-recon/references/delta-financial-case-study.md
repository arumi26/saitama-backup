# Delta Financial Case Study (2026-07-16)

## Protocol Profile
- **Name:** Delta Financial
- **TVL:** $9.1M (Options category)
- **Chain:** Ethereum
- **Audits:** 0 (DeFiLlama), no audit files in repo
- **GitHub:** `Delta-Financial/Smart-Contracts` + `Delta-Financial/StableYield`
- **Language:** Solidity 0.7.6 (pre-built-in overflow, uses SafeMath)
- **Contract count:** ~15 Solidity files across versions (v076, v424, v500, v612)

## Architecture
- **Core:** `DELTA_Deep_Farming_Vault.sol` (996 lines) — yield farming with booster/multiplier system
- **Withdrawal:** `DELTA_Vault_Withdrawal_MasterCopy.sol` (155 lines) — proxy-based per-user withdrawal contracts with 52-week vesting
- **Distribution:** `DELTA_Distributor.sol` (232 lines) — reward distribution: 20% sold, 16% burned, 8% dev, 56% farming vault
- **Router:** `Delta_Router.sol` (198 lines) — Uniswap V2 LP management
- **Governance:** `DELTA_Governance_Relay.sol`, `DELTA_MultiSignature_TimeLock.sol`

## Bugs Found

### BUG 1: `withdrawEverythingWithdrawable()` — `revert()` dead code (MEDIUM)
**File:** `DELTA_Vault_Withdrawal_MasterCopy.sol:93-115`

```solidity
function withdrawEverythingWithdrawable() public {
    // ... checks ...
    uint256 deltaDue = withdrawableTokens();
    DELTA_TOKEN.transfer(msg.sender, deltaDue);    // transfer matured
    uint256 leftOver = DELTA_TOKEN.balanceOf(address(this));
    
    IDELTA_DISTRIBUTOR distributor = deltaDistributor();
    if(leftOver > 0) { 
        revert();                                    // ALWAYS REVERTS
        DELTA_TOKEN.approve(address(distributor), leftOver);  // unreachable
        distributor.addDevested(msg.sender, leftOver);
    }
    everythingWithdrawed = true;
}
```

`revert()` on line 109 undoes the entire transaction including the transfer on line 103.
Whenever maturation is < 100% (which is always until week 52), there IS leftover,
so the function ALWAYS reverts. User must wait full 52 weeks to withdraw anything.

**Impact:** DOS — users cannot withdraw until full vesting period. Not fund-draining.
**Fix:** Remove `revert()`. The approve+addDevested should execute normally.

### BUG 2: `addDevested()` — no access control (LOW)
**File:** `DELTA_Distributor.sol:225-228`

```solidity
function addDevested(address user, uint256 amount) public {
    require(DELTA_TOKEN.transferFrom(msg.sender, address(this), amount), "...");
    pendingCredits[user] = pendingCredits[user].add(amount.mul(PERCENT_BURNED).div(100));
}
```

Anyone can call `addDevested()`. They must supply DELTA tokens (transferred from caller),
and receive only 16% as permanent credit. The remaining 84% stays in distributor.
**Not exploitable for profit** — caller loses 84% of supplied tokens.

### BUG 3: `emergencyShutdown()` — misleading parameter name (INFORMATIONAL)
**File:** `DELTA_Deep_Farming_Vault.sol:883-893`

Parameter named `stopPanicMultisigOnly` but when `true`, it UN-panics after multisig check.
Logic is correct (guardian can panic, only multisig can un-panic) but naming is inverted.

## Why Not Exploitable for Fund Drain
- All token transfers are internal (`DELTA_TOKEN.transfer`) with proper balance checks
- `onlyMultisig()` gates all admin functions
- `onlyOneActionPerBlock()` prevents flash loan attacks within single block
- No external oracle dependency in vault logic (yield is internally distributed)
- Pre-0.8.0 but SafeMath used consistently — no overflow surface found
- Withdrawal contract uses proxy pattern with proper initialization guard