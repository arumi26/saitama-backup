# Flaunch CRIT-01: Cross-Chain Implementation Swap Attack
**Date:** 2026-07-16
**Status:** PoC verified (3/3 tests PASS)
**Bounty estimate:** $25K-$75K

## Vulnerability
`setMemecoinImplementation()` allows owner to swap implementation globally without per-tokenId version lock. `finalizeBridge()` reads CURRENT implementation, not locked version.

## Key Code
```solidity
// Flaunch.sol line 225-228
function setMemecoinImplementation(address _memecoinImplementation) external onlyOwner {
    memecoinImplementation = _memecoinImplementation;  // Global, no version lock
}

// Flaunch.sol line 400 (inside finalizeBridge)
address memecoin_ = LibClone.cloneDeterministic(memecoinImplementation, bytes32(_tokenId));
// ↑ Reads CURRENT state, not locked version
```

## Attack Flow
1. Token deployed with SafeImpl via `flaunch()`
2. User calls `initializeBridge(tokenId, chainId)` → message sent to L2
3. Owner calls `setMemecoinImplementation(MaliciousImpl)`
4. L2 receives message → `finalizeBridge()` deploys with MaliciousImpl
5. All subsequent mints/transfers on L2 leak funds to attacker

## PoC Results
```
[PASS] test_CRIT01_ImplementationSwapAttack()
  [OK] Step 1: Token deployed with SafeImpl
  [OK] Step 2: Bridge initialized
  [!!] Step 3: Owner swapped to MaliciousImpl
  [OK] Step 4: Bridge finalized with MaliciousImpl
  [!!] Step 5: MINT BACKDOOR - 10% to attacker on every mint
  [!!] Step 6: TRANSFER BACKDOOR - 5% stolen on every transfer

[PASS] test_CRIT01_NoVersionLock()
  [OK] PROVEN: All tokens share single implementation slot

[PASS] test_CRIT01_BridgeWindowAttack()
  [OK] PROVEN: 1-hour bridge window allows implementation swap
```

## PoC Patterns Learned
1. **LibClone minimal proxies: constructors don't run.** Set state in `initialize()` instead.
2. **`predictDeterministicAddress` needs 3 args:** `(implementation, salt, deployer)`.
3. **CREATE2 address changes when implementation changes.** Must re-predict after impl swap.
4. **Use `vm.prank(address)` to impersonate users** in Foundry tests.
5. **Unicode in `emit log()` strings = compile error.** Use ASCII only.
6. **Route calls through mock contracts** when target has `require(msg.sender == flaunch)`.

## Remediation
```solidity
mapping(uint tokenId => address) public bridgingImplementation;

function initializeBridge(uint tokenId, uint chainId) public {
    bridgingImplementation[tokenId] = memecoinImplementation; // Lock version
}

function finalizeBridge(uint tokenId, MemecoinMetadata memory metadata) public {
    address impl = bridgingImplementation[tokenId]; // Use locked version
    address memecoin_ = LibClone.cloneDeterministic(impl, bytes32(tokenId));
}
```

## Files
- PoC: `/home/ubuntu/flaunchgg-contracts/test/poc/CRIT01_ImplementationSwap.t.sol`
- Report: `/home/ubuntu/flaunchgg-contracts/test/poc/REPORT_CRIT01.md`
