# Cod3x-Labs/Reliquary — Deposit Helper Invariant Break (July 2026)

## Target
- **Repo:** `Cod3x-Labs/Reliquary` (GitHub)
- **Related:** `Cod3x-Labs/Cod3x-Lend-Leverager`
- **Bounty status:** NO ACTIVE BOUNTY PROGRAM FOUND (as of 2026-07-22)
- **Audit:** Reliquary V2 audit by cergyk (April 2024) — does NOT cover the helper contracts

## Vulnerability: Shared Helper Contract Drains All User Deposits

### Affected Contracts
1. `contracts/helpers/DepositHelperReaperVault.sol`
2. `contracts/helpers/DepositHelperERC4626.sol`
3. `contracts/helpers/DepositHelperReaperBPT.sol`

### Root Cause
Helper contracts aggregate deposits from multiple users into a single external vault/strategy. They track per-user shares internally, but withdrawal functions pull ALL vault shares/tokens owned by the helper, not just the caller's portion.

### Code Evidence

**DepositHelperReaperVault.sol** — withdraw flow:
```solidity
// Bug: withdraws ALL vault shares held by helper
vault.withdrawAll();
// Then sends everything to caller
```

**DepositHelperERC4626.sol** — `_withdraw()` line 134:
```solidity
// Bug: withdraws ALL vault assets owned by helper
_vault.withdraw(_vault.maxWithdraw(address(this)), msg.sender, address(this));
```

### Impact
- **Severity:** CRITICAL
- **Attack vector:** Permissionless — any user who deposited via the helper can call `withdrawAllAndHarvest()` and drain all pooled funds
- **Result:** Other users' deposits are stolen; subsequent withdrawals revert with "no shares" or return 0

### PoC Status
- **ReaperVault:** ✅ PASSING — test proves attacker receives full pool (1500), victim reverts with "no shares"
- **ERC4626:** ✅ PASSING — test proves attacker receives full pool (1500), victim receives 0
- **BPT:** Not yet tested, same pattern expected

### Why This Is Real
- Traces show exact state changes: attacker balance goes from 0 → 1500, victim balance stays at 500 (not drained from wallet, but locked in vault)
- Victim's `userShares` mapping is NOT cleared by attacker's call — victim's shares still recorded, but vault has 0 balance
- This is NOT a rugpull owner scenario — this is a **permissionless invariant break** any user can trigger

### Remediation
Helper must track per-user vault shares and withdraw only caller's shares:
```solidity
// Track per-user vault shares on deposit
userVaultShares[msg.sender] += mintedShares;

// Withdraw only caller's shares
uint256 callerShares = userVaultShares[msg.sender];
vault.withdraw(callerShares, msg.sender, address(this));
userVaultShares[msg.sender] = 0;
```

### Bounty Submission Status
- **NO ACTIVE BOUNTY PROGRAM** for Cod3x-Labs/Reliquary
- Cannot submit until bounty program is launched
- Findings documented for future submission

## Lesson Learned
- Helper contracts that aggregate funds are high-value targets — always audit withdrawal math
- `withdrawAll()` and `maxWithdraw(address(this))` are red flags in shared helper contracts
- Even if base protocol is audited, helper contracts added later may not be in audit scope
- Email bounce does not mean no contact path: fall back to README security contact, then GitHub org API `email`/`blog`/`twitter_username`, then org Twitter handle. Use tiered disclosure: brief description + PoC availability → full report without code → PoC only after bounty/channel confirmation.
- When reporting inactive/private-contact programs, extract public contact signals from GitHub org API and README before composing the disclosure message.