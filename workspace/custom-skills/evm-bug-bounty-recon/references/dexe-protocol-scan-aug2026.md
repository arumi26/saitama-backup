# DeXe Protocol Quick Scan — August 13 2026

**Target:** DeXe Protocol (Immunefi, $500K max bounty, BSC chain)
**Repo:** https://github.com/dexe-network/DeXe-Protocol (129 .sol files, 8 contract dirs)
**Scope:** 11 contracts including DeXe DAO, ContractsRegistry, UserRegistry, CoreProperties, PriceFeed, ERC721Expert, PoolFactory, PoolRegistry, SphereXEngine, PoolSphereXEngine

## Scan Methodology

1. Cloned repo with `git clone --depth 1`
2. Downloaded 26 priority contracts (core, factory, gov, user, proxy, libs)
3. Pattern scan: reentrancy, unchecked calls, tx.origin, delegatecall, missing access control
4. Deep dive: DistributionProposal.sol, GovPool.sol, PoolFactory.sol, TokenAllocator.sol

## Findings

### CRITICAL — Reentrancy in DistributionProposal.execute()

**Contract:** `contracts/gov/proposals/DistributionProposal.sol`
**Line:** 65
**Pattern:** CEI violation — external call before state update

```solidity
function execute(uint256 proposalId, address token, uint256 amount) external payable override onlyGov {
    // ...
    if (token == ETHEREUM_ADDRESS) {
        require(amount == msg.value, "DP: wrong native amount");
        (bool ok, ) = payable(msg.sender).call{value: amount - actualAmount}("");  // ← EXTERNAL CALL FIRST
        require(ok, "DP: failed to send back eth");
    }
    // State update AFTER external call:
    proposal.rewardAddress = token;       // ← CEI VIOLATION
    proposal.rewardAmount = actualAmount;
}
```

**Attack vector:** `msg.sender` is `GovPool` (the DAO contract). An attacker who can influence GovPool to call `execute()` with malicious parameters, or who can create a malicious GovPool via `PoolFactory.deployGovPool()`, could re-enter `DistributionProposal` during the external call and manipulate proposal state before it's finalized.

**CVSS estimate:** 8.5 (High/Critical — CEI + reentrancy in distribution contract)
**Note:** This requires either (a) compromised GovPool owner, or (b) attacker-deployed GovPool via PoolFactory with same codebase.

### MEDIUM — Missing Access Control on GovPool.tryExecute()

**Contract:** `contracts/gov/GovPool.sol` line 161
**Pattern:** Public function with no access control modifier

```solidity
function tryExecute(ProposalAction[] calldata actions) external returns (bool) {
    try actions.tryExecute() {
        revert();
    } catch (bytes memory reason) {
        return abi.decode(reason, (bool));
    }
}
```

**Impact:** Anyone can simulate proposal execution on any GovPool. This reveals whether actions would succeed/fail without cost. Could be used for oracle manipulation or state-dependent attacks if the simulated execution leaves residual effects (should be view-only but isn't).

### INFORMATIONAL — tx.origin in CREATE2 Salt Calculation

**Contracts:** `PoolFactory.sol` (lines 220, 315, 324), `TokenAllocator.sol` (line 262)
**Pattern:** `_calculateGovSalt(tx.origin, poolName)` used for CREATE2 address prediction

```solidity
function _calculateGovSalt(address deployer, string memory poolName) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(deployer, poolName));
}
```

**Why it's not a bug:** `tx.origin` is used as part of the salt for deterministic address prediction, NOT for authorization. The `predictGovAddresses()` function is public view. No privileged action is gated by `tx.origin` comparison. Standard pattern for CREATE2-based factory contracts.

**Severity:** Informational (address predictability note only)

### LOW — Unchecked low-level call in NetworkProperties.unwrapWeth()

**Contract:** `contracts/core/network-properties/NetworkProperties.sol` line 23
**Pattern:** `call{value}` with `assert(ok)` instead of `require`

```solidity
function unwrapWeth(uint256 amount) external {
    weth.withdraw(amount);
    (bool ok, ) = payable(msg.sender).call{value: amount}("");
    assert(ok);  // assert vs require — doesn't revert cleanly in production
}
```

**Impact:** `assert(false)` in Solidity >=0.8.0 consumes all remaining gas. Use `require` for external failures.

## Key Architecture Observations

1. **Modular library architecture:** GovPool uses libraries (GovPoolVote, GovPoolCreate, GovPoolExecute, GovPoolRewards, etc.) — increases complexity but allows targeted audit
2. **Access control pattern:** `onlyBABTHolder` modifier — requires holding BABT NFT or being a GovPool. PoolFactory deploys with `tx.origin` as deployer
3. **Proposal execution flow:** GovPool.execute() → GovPoolExecute.execute() → iterates ProposalAction[] → calls `actions[i].executor.call{value: actions[i].value}(actions[i].data)` for each action
4. **DistributionProposal.execute() called by GovPool** — onlyGov modifier ensures only the DAO contract can trigger distribution
5. **SphereXEngine integration:** PoolFactory adds deployed contracts to SphereXEngine allowed senders list

## Next Steps for Deep Dive

1. **Verify DistributionProposal reentrancy exploitability:**
   - Can an attacker create a malicious GovPool (via PoolFactory) that calls DistributionProposal.execute() with attacker-controlled params?
   - Is there a reentrancy guard (nonReentrant) on DistributionProposal functions? (Initial scan: none found)
   - Can the external call in execute() re-enter DistributionProposal.claim() or another state-modifying function?

2. **Check GovPoolExecute.execute() for similar patterns:**
   - Lines 42-52 iterate actions and call `actions[i].executor.call{value: actions[i].value}`
   - Are there state updates after these calls in GovPool or GovPoolExecute?

3. **Review GovValidators.sol** — validator voting logic, potential for validator bribery or threshold manipulation

4. **Check PriceFeed.sol** — oracle manipulation surface, assembly usage in price calculation

5. **On-chain verification:** Get deployed addresses from BSCscan, verify bytecode matches repo, check if DistributionProposal is used in production
