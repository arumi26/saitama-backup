# Foundry Installation & PoC Setup

## Install Foundry (Ubuntu/Linux)
```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

## Verify Installation
```bash
which forge && forge --version
which cast && cast --version
```

## Create PoC Project
```bash
forge init poc-exploit --no-commit
cd poc-exploit
```

## Fork Target Chain for Simulation
```solidity
// test/Exploit.t.sol
pragma solidity ^0.8.26;
import "forge-std/Test.sol";

contract ExploitPoC is Test {
    function setUp() public {
        // Fork Base mainnet (or target chain)
        vm.createSelectFork("https://base-mainnet.g.alchemy.com/v2/YOUR_KEY");
        // Or use public RPC
        // vm.createSelectFork("https://mainnet.base.org");
        
        // Fund attacker with ETH
        vm.deal(address(0xATTACKER), 100 ether);
    }
    
    function test_Exploit() public {
        // 1. Prerequisites setup
        // 2. Execute exploit steps
        // 3. Assertions (verify funds moved, state changed)
        assertEq(token.balanceOf(attacker), expectedAmount);
    }
}
```

## Run PoC
```bash
forge test --match-test test_Exploit -vvvv
```

## Key Concepts
- **Fork = local mainnet copy.** All state, balances, contracts mirrored. No real funds.
- **`vm.deal` = give ETH to any address.** No need for real wallet.
- **`vm.prank` = impersonate any address.** Execute as owner, admin, victim.
- **`vm.expectEmit` = verify events.** Prove funds were transferred.

## Common Pitfalls
- Fork URL must be archive node (supports historical state queries)
- Alchemy/Infura free tier works for forking
- `--no-commit` on forge init avoids git issues
- Foundry uses Solidity 0.8.x by default — matches most modern contracts