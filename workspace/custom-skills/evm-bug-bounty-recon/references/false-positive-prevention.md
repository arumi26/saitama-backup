# False Positive Prevention in Smart Contract Audits

## The Problem
Finding a suspicious code pattern (e.g., `fee * 2`, `amount - fee`, unchecked transfer) is NOT a vulnerability until you prove the attacker can actually lose funds.

## The Verification Checklist (MANDATORY before any claim)

### 1. Trace Every Variable to Origin
```
Suspicious: safeTransfer(user, amount - fee)
            safeTransfer(feeReceiver, fee * 2)

Step 1: Where does `fee` come from?
→ _prepareOrder() → _computeFee(taking, order.feeRateBps)
→ fee = taking * feeRate / 10000

Step 2: What is `amount`?
→ `taking` = (fillAmount * order.takerAmount) / order.makerAmount
→ This is the INPUT amount the user agreed to trade

Step 3: Was fee already deducted from user's side?
→ Yes: user sends (taking + fee), receives (taking - fee)
→ Net user cost = fee (already deducted from input)

Step 4: Does feeReceiver get fee from BOTH sides?
→ Taker side: fee collected via deduction from user's output
→ Maker side: fee collected via deduction from user's output
→ feeReceiver: fee (taker) + fee (maker) = 2 * fee
→ CORRECT: feeReceiver gets the combined fee from both parties
```

### 2. Concrete Exploit Scenario
**Must answer these questions:**
- [ ] Who calls the vulnerable function? (anyone / admin / specific role)
- [ ] What does the attacker send? (specific amount, specific params)
- [ ] What does the attacker receive? (more than they sent?)
- [ ] What does the protocol lose? (provable fund drain)
- [ ] Can this be repeated? (stateful or stateless)

**If you can't answer ALL five → NOT A BUG.**

### 3. Run Foundry PoC Before Reporting
Even a minimal test proves the concept:
```solidity
function test_AttackDrain() public {
    // 1. Setup: attacker has X collateral
    // 2. Trigger: call vulnerable function
    // 3. Assert: attacker balance > X (fund loss confirmed)
    assertTrue(attackerBalanceAfter > attackerBalanceBefore);
}
```

**If Foundry setup fails or test doesn't trigger → the bug doesn't exist.**

## Common False Positive Patterns

| Pattern | Why It Looks Bad | Why It's Often OK |
|---------|-----------------|-------------------|
| `fee * 2` | Double charging | Fee from both sides of trade |
| `amount - fee` | User pays fee twice | Fee deducted from gross, not net |
| `transfer(user, largeAmount)` | Huge payout | User's position already worth that |
| `onlyOwner` function | Privileged access | Normal admin function |
| `delegatecall` | Code injection risk | Common proxy pattern |
| `unchecked {}` | Overflow possible | Gas optimization, bounds checked elsewhere |
| `balanceOf > 0` check | May miss edge cases | Standard pattern, value = 0 means nothing to do |

## Decision Flowchart
```
Find suspicious code?
├─ Can you trace the full transfer flow?
│  ├─ NO → More analysis needed, don't report yet
│  └─ YES ↓
├─ Can you write a concrete exploit scenario?
│  ├─ NO → Not a bug (or not yet proven)
│  └─ YES ↓
├─ Can you run a Foundry test that proves fund loss?
│  ├─ NO → Not exploitable / not a bug
│  └─ YES ↓
└─ CRITICAL FINDING — Write report
```

## Session Evidence (2026-07-17)
- **False positive found:** Trading.sol MERGE path `makerFee * 2` claimed as double fee
- **Trace proved:** fee collection correct, both sides' fees go to receiver
- **Lesson:** Always trace full transfer flow before claiming CRITICAL
- **Reference:** `src/exchange/mixins/Trading.sol` lines 263-296
