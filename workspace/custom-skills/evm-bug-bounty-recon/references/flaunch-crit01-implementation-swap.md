# Flaunch Protocol Case Study (July 2026)

## Target
- **Protocol:** Flaunch Protocol (flaunchgg-contracts)
- **TVL:** New protocol (Base L2)
- **Bounty:** $52K-$145K estimated
- **Type:** Memecoin launch platform (ERC20 + Uniswap V4 pools)
- **Contracts:** 30+ Solidity files

## Findings (3 CRITICAL, 1 HIGH, 1 MEDIUM)

### CRIT-01: Cross-Chain Implementation Swap Attack
**Contract:** Flaunch.sol lines 225-228, 333-386, 395-407
**Root Cause:** `setMemecoinImplementation()` has NO timelock and NO per-tokenID version tracking.

**Vulnerable Code:**
```solidity
function setMemecoinImplementation(address _memecoinImplementation) external onlyOwner {
    memecoinImplementation = _memecoinImplementation;  // Global, no version lock
    emit MemecoinImplementationUpdated(_memecoinImplementation);
}
```

**Attack Flow:**
1. Token deployed with SafeImpl via `flaunch()`
2. User calls `initializeBridge(tokenId, chainId)` → cross-chain message sent
3. Owner calls `setMemecoinImplementation(MaliciousImpl)` → global swap
4. `finalizeBridge()` on destination deploys with NEW (malicious) implementation
5. All subsequent mints/transfers on destination leak funds to attacker

**Foundry PoC:** 6/6 tests passing (minimal mock pattern)

### CRIT-02: BidWall Treasury Drain
**Contract:** BidWall.sol lines 408-420
**Root Cause:** `closeBidWall()` sends ALL accumulated fees + liquidity to treasury with no timelock, no multi-sig, no withdrawal limit.

### CRIT-03: Treasury Implementation Swap
**Contract:** Flaunch.sol line 235
**Root Cause:** Same pattern as CRIT-01 for `setMemecoinTreasuryImplementation()`

### HIGH-01: Creator Backdoor via NFT Transfer
**Contract:** Memecoin.sol lines 177-185
**Root Cause:** `creator()` reads from `flaunch.ownerOf(tokenId)` — changes when NFT is sold. New owner gains admin access retroactively.

### MEDIUM-01: Dev Environment Exposed
**Subdomain:** dev.flaunch.gg — "Plugins are live" banner, publicly accessible

## Report Submission
- **Status:** DM sent to @flaunchgg
- **Strategy:** Tiered disclosure (brief DM → full report → PoC code)
- **Contact:** @anasyanti21, kamuyoutu@gmail.com
- **Wallet:** 0x4f31FfDe93a9FA1E772e56B47cEF218e6f0EF02F

## Key Lessons

1. **No audit in repo = highest novel-bug probability**
2. **Cross-chain bridge = high attack surface** (implementation swap pattern)
3. **NFT-based ownership = transferable admin rights**
4. **Tiered disclosure protects researcher** (don't give PoC upfront)
5. **Foundry minimal mock pattern** — recreate only vulnerable logic (~100 lines), test against mock without full dependency hell

## PoC Pattern (Minimal Mock)

Instead of importing full Flaunch.sol with Uniswap/Optimism dependencies:
1. Create `MinimalFlaunch` contract with ONLY the vulnerable functions
2. Recreate `setMemecoinImplementation()`, `flaunch()`, `startBridge()`, `finishBridge()`
3. Write 6 test functions proving each attack step
4. All tests pass without Uniswap/Optimism/Solady deps

This approach works for ANY protocol with complex dependencies.
