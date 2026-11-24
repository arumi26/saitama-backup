# Credit Inflation via CEI Violation in Repay Logic

**Date:** 2026-08-11
**Source:** Live session audit of ExtraFi (extrafi.io)
**Contract:** `LendingPool.repay()` at 0xBB505c54D71E9e599cB8435b4F0cEEc05fC71cbD on Base

## Bug Pattern

Credit is incremented BEFORE the repayment amount is capped to the actual debt — a CEI (Checks-Effects-Interactions) violation.

```solidity
// BUG: credit updated BEFORE amount is capped
uint256 credit = credits[debtPosition.reserveId][_msgSender()];
credits[debtPosition.reserveId][_msgSender()] = credit.add(amount);  // ← FULL amount

if (amount > debtPosition.borrowed) {
    amount = debtPosition.borrowed;  // ← capped AFTER credit update
}
```

## Exploit

If caller passes `amount = 1000 ETH` but `debtPosition.borrowed = 1 ETH`:
- `credit += 1000 ETH` (full!)
- `amount` capped to 1 ETH
- Vault pays 1 ETH, gets 1000 ETH borrowing credit

## Impact

CRITICAL — TVL drain via unlimited credit generation. The vault can borrow the full credit amount, draining the lending pool.

## Current Status

- Bug confirmed on mainnet (Base, LendingPool 0xBB50...)
- Bytecode verified: `repay()` selector 0xf5e1c4e1 confirmed in on-chain bytecode
- Documented in `BUG_FIXES_AND_MODIFICATIONS.md` (ExtraFi)
- GitHub Issue #5: OPEN since 2026-04-28
- Currently NOT exploitable: `borrowingWhiteList` is empty (0 vaults whitelisted)
- If a vault is ever whitelisted → immediate exploit possible

## On-Chain Verification

```bash
export ETH_RPC_URL="<BASE_RPC>"
POOL="0xBB505c54D71E9e599cB8435b4F0cEEc05fC71cbD"
# Verify contract is deployed
cast code $POOL | wc -c  # 40398 bytes
# Check if paused
cast call $POOL "paused()(bool)"  # false
# Check debt positions
cast call $POOL "nextDebtPositionId()(uint256)"  # 247
# Check whitelist
cast call $POOL "borrowingWhiteList(address)(bool)" 0xf9cFB8a62f50e10AdDE5Aa888B44cF01C5957055  # false
```

## Audit Search Pattern

```bash
grep -rn "credit.*=.*credit.*add\|credit.*=.*credit.*+" --include="*.sol" contracts/
grep -A 5 "credit*add\|credit*+" contracts/*.sol | grep -B 5 "if.*amount.*>"
```

If the credit update appears BEFORE an `if (amount > debt) amount = debt` capping line, flag it.

## Mitigation (from ExtraFi repo fix)

```solidity
// FIXED: cap amount FIRST, then update credit with capped amount
if (amount > debtPosition.borrowed) {
    amount = debtPosition.borrowed;
}
reserve.totalBorrows = reserve.totalBorrows.sub(amount);
debtPosition.borrowed = debtPosition.borrowed.sub(amount);

uint256 credit = credits[debtPosition.reserveId][_msgSender()];
credits[debtPosition.reserveId][_msgSender()] = credit.add(amount); // capped amount
```