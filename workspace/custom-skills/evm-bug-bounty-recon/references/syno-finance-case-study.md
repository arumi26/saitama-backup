# Synonym Finance (SYNO) — Wormhole Lending Audit Session

## Target Profile
- **Protocol:** Synonym Finance / SYNO
- **Chains:** Base, Blast, Mode, Linea + Hub chain (Ethereum)
- **TVL:** ~$200K (low)
- **Audits:** 0 confirmed
- **GitHub:** `github.com/SynonymFinance/smart-contracts-public` (4,074 LOC, public)
- **Bounty:** No active program disclosed on Immunefi/HackerOne/Cantina
- **Architecture:** Hub/Spoke cross-chain lending via Wormhole tunnel + CCTP USDC

## Key Contracts Reviewed
| Contract | Lines | Role |
|----------|-------|------|
| `Hub.sol` | 600 | Cross-chain lending state + liquidation |
| `Spoke.sol` | 336 | User entrypoint + Wormhole message sender |
| `WormholeTunnel.sol` | 552 | Wormhole + CCTP message routing |
| `Liquidator.sol` | 100 | Liquidation executor |
| `LiquidatorFlashLoan.sol` | 280 | Flash loan liquidation |
| `Create2Factory.sol` | 80 | Deterministic proxy deployment |
| `WormholeRelayerGovernance.sol` | 138 | Upgrade governance |

## Findings

### SYNO-01: WormholeTunnel `forceApprove` + External Call (False Positive)
**Severity:** INFORMATIONAL (not exploitable)
**Location:** `evm/src/contracts/wormhole/WormholeTunnel.sol:350-361`

```solidity
// line 350-361
if (token != IERC20(address(0))) {
    token.forceApprove(recipientAddress, message.amount);
}
(success, ret) = recipientAddress.call{value: msg.value}(
    abi.encodeWithSelector(
        message.target.selector,
        message.source,
        token,
        message.amount,
        message.target.payload
    )
);
```

**Initial assessment:** Looks like approve-then-call anti-pattern. If `recipientAddress` is Hub/Spoke, attacker could mint a malicious contract at same address and steal tokens.

**Actual security:** The `receiveWormholeMessages()` function has three layered gates:
1. `onlyWormholeRelayer(sourceChain)` — only Wormhole relayer can call
2. `onlyRegisteredSender(sourceChain, sourceAddress)` — only registered tunnel endpoints
3. `replayProtect(deliveryHash)` — VAA hash replay protection

An attacker cannot forge a valid Wormhole VAA or delivery message. The `forceApprove` + `call` pattern is **standard Wormhole token bridging** — the recipient is the Hub/Spoke contract, which is controlled by protocol, not attacker.

**Verdict:** False positive. Pattern looks dangerous in isolation but is safe in full context.

### SYNO-02: Create2Factory Without Access Control (Dismissed)
**Location:** `evm/src/contracts/relayer/create2Factory/Create2Factory.sol:28-48`

```solidity
function create2(bytes memory userSalt, bytes memory bytecode) public payable returns (address payable) {
    address addr = Create2.deploy(msg.value, salt(msg.sender, userSalt), bytecode);
    emit Created(addr);
    return payable(addr);
}

function create2Proxy(bytes memory userSalt, address impl, bytes memory call) public payable returns (address payable) {
    address payable proxy = create2(userSalt, abi.encodePacked(type(SimpleProxy).creationCode, abi.encode(address(init))));
    Init(proxy).upgrade(impl, call);
    return proxy;
}
```

**Initial assessment:** Permissionless proxy deployment. Anyone can deploy a proxy pointing to any implementation.

**Actual security:** The factory is a utility contract. No protocol logic uses it in the current codebase (`grep` showed 0 references from Hub/Spoke/Liquidator). It's likely intended for future relayer infrastructure, not active in the attack surface.

**Verdict:** Dismissed. No concrete attack scenario with value movement.

### SYNO-03: WormholeRelayerGovernance `contractUpgrade` Reentrancy Risk
**Severity:** MEDIUM (owner-only, upgrade path)
**Location:** `evm/src/contracts/relayer/wormholeRelayer/WormholeRelayerGovernance.sol:90-103`

```solidity
function contractUpgrade(address newImplementation) external onlyOwner {
    address currentImplementation = _getImplementation();
    _upgradeTo(newImplementation);
    (bool success, bytes memory revertData) = address(this).call(abi.encodeCall(this.checkAndExecuteUpgradeMigration, ()));
    if (!success) {
        revert ContractUpgradeFailed(revertData);
    }
    emit ContractUpgraded(currentImplementation, newImplementation);
}
```

**Assessment:** The `_upgradeTo()` + `checkAndExecuteUpgradeMigration()` uses `address(this).call(...)`, which is a standard reentrancy-safe pattern since `msg.sender == address(this)` is asserted. However, if the upgrade migration logic is complex, there could be edge cases.

**Verdict:** Owner-only, not permissionless. Report as informational if at all.

## Key Lessons

1. **Wormhole bridges have strong cryptographic gates.** The guardian set + VAA signing makes message forgery infeasible. Approve-then-call patterns inside `receiveWormholeMessages()` are safe because the function itself is already gated by Wormhole auth.

2. **Cross-chain lending attack surface is in the Hub message handlers, not the tunnel.** Focus on:
   - `instantActionMessage()` nonce replay
   - `userActionMessage()` asset validation
   - `finalizeCreditMessage()` credit state machine
   - Cross-chain message replay between chains

3. **Low TVL + 0 audit ≠ easy bugs.** SYNO has clean code despite being unaudited. The Wormhole SDK provides hardened messaging primitives. Novel bugs are more likely in custom Hub/Spoke accounting logic than in the tunnel itself.

4. **No active bounty = report risk.** Without a disclosed program, submission to unknown contact = low probability of reward. Pivot to protocols with active Immunefi/Cantina scope.

## Next Steps
- Deep dive Hub optimistic finality state machine for nonce/credit replay bugs
- Check if Spoke `handleInstantAction()` credit limit can be bypassed via cross-chain replay
- Pivot to Variational Protocol ($100K Critical bounty, verified SettlementPool)
