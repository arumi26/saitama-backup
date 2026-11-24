# Reliquary-Style Staking Protocol Test Fixture Guide

## Problem
Reliquary-class protocols (staked NFT with maturity curves + rewarders) have complex test fixtures that are easy to get wrong. Common failures: `CURVE_OVERFLOW`, `ERC721InvalidReceiver`, `ERC20InsufficientAllowance`.

## Key Setup Rules

### 1. Pool Token Bootstrap for addPool
`addPool()` transfers 1 pool token to the `_to` receiver address. The `_to` address must:
- Have balance >= 1 of poolToken
- Be an ERC721Receiver if it's a contract (or use EOA like `address(5)`)
- Have approved Reliquary to transfer the 1 token

**Correct pattern:**
```solidity
poolToken.mint(address(reliquary), 100_000_000 ether); // supply for protocol
poolToken.mint(address(1), 1_000_000 ether);            // user A
poolToken.mint(address(2), 1_000_000 ether);            // user B
reliquary.grantRole(keccak256("OPERATOR"), address(this));
reliquary.addPool(
    100, address(poolToken), address(0), curve, "LP", nftDescriptor, true, address(5)
);
// NOTE: No approval needed — mint goes to relquary, which is msg.sender in addPool
// The 1 token transfer comes from relquary's own balance to address(5)
```

### 2. Reward Token vs Pool Token
Constructor takes `_rewardToken`. `addPool` takes `_poolToken`. They MUST be different tokens.
```solidity
rewardToken = new ERC20Mock(18);
poolToken = new ERC20Mock(18);
reliquary = new Reliquary(address(rewardToken), emissionRate, "Test", "tREL", 0);
```

### 3. Curve Parameters — Avoid CURVE_OVERFLOW
The overflow happens when: `curve.getFunction(max_time) * emissionRate * ACC_REWARD_PRECISION > uint256.max`
- Use small curve parameters: `slope = 100`, `minMultiplier = 365 days * 100`
- For zero-emission tests: `emissionRate = 0`
- Keep test time short: `skip(1 days)` instead of weeks

### 4. Position Approval for shift/merge/split
These functions require `approve(relquary, relicId)` from the owner of each position:
```solidity
vm.startPrank(address(1));
reliquary.approve(address(reliquary), idA);  // approve transfer of relic A
reliquary.shift(idA, idB, amount);           // now works
vm.stopPrank();
```

### 5. Role Setup
Original tests use `OPERATOR` role for `createRelicAndDeposit`. Grant it:
```solidity
reliquary.grantRole(keccak256("OPERATOR"), address(this));
reliquary.grantRole(keccak256("GUARDIAN"), address(this)); // for pause
```

## Attack Surface for Re-Audit

When re-auditing non-responsive protocols, focus on these shared-state paths:

### split() → merge() → shift() Invariant Check
```solidity
function testSplitMergeInvariant() public {
    // 1. Deposit 100 ether at time T0
    // 2. Wait 1 day → level advances
    // 3. Split into 2 x 50 ether
    // 4. Verify totalLpSupplied matches actual LP balance
    // 5. Merge back → verify totalLpSupplied still matches
    // 6. Shift between positions → verify again
}
```

### emergencyWithdraw() vs withdraw() Consistency
```solidity
function testEmergencyWithdrawConsistency() public {
    // 1. Deposit + accumulate rewards
    // 2. Call emergencyWithdraw()
    // 3. Compare reward state with normal withdraw()
    // 4. If rewarder hooks differ → HIGH severity bug
}
```

### Pause Bypass Check
```solidity
function testPauseBypass() public {
    // 1. Pause the protocol
    // 2. Try calling deposit(), split(), merge() → should revert
    // 3. Try calling emergencyWithdraw() → if it SUCCEEDS, that's a HIGH bug
}
```

## Files Referenced
- `/tmp/cod3x-audit/Reliquary/test/foundry/Reliquary.t.sol` — Original test suite (reference)
- `/tmp/cod3x-audit/Reliquary/test/foundry/SplitRewardTheft.t.sol` — Passing PoC
- `/tmp/cod3x-audit/Reliquary/test/foundry/EmergencyWithdrawBypass.t.sol` — Passing PoC
- `/tmp/cod3x-audit/Reliquary/test/foundry/RewarderStateCorruption.t.sol` — Passing PoC
- `/tmp/reliquary-audit/REPORT_v2.md` — Updated report with all findings
