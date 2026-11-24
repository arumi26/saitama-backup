# Admin-Only Missing Validation

**Load when:** auditing smart contracts for bugs where admin/governance functions accept parameters that should be validated but aren't. Common categories: `address(0)` fee recipient/treasury, zero amounts, out-of-bounds indices, duplicate keys.
## Pattern

When a contract has a helper like `_checkAddress()`, `_checkNonZero()`, or similar, audit every function that takes a typed parameter and confirm the helper is actually called. Inconsistency between functions = bug.

## Detection Steps

1. Find all validation helpers in the contract:
   ```
   grep -rn "function _check\|function _validate\|function _require" src/
   ```

2. Find all functions that take address / uint / bytes parameters:
   ```
   grep -rn "function .*address \|function .*uint \|function .*bytes " src/
   ```

3. For each public/external function with a parameter, check whether it calls the corresponding validator before using the parameter in storage write, transfer, or external call.

4. Cross-reference with `_checkAddress`-using functions (e.g., `setOperatorAddresses` HAS, `deactivateOperator` MISSING). The presence of the helper somewhere else in the same contract is the smoking gun.

## Real-World Example (Kiln V1)

`StakingContract.sol` has `_checkAddress(address)` that reverts on `address(0)`. It is used in:
- `initialize_1` (line 163-184)
- `setOperatorAddresses` (line 417-418)
- `setWithdrawer` (line 434)

But missing in three admin-only functions:
- `deactivateOperator(uint256, address)` — line 482-491
- `activateOperator(uint256, address)` — line 496-502
- `setTreasury(address)` — line 214-217

**Impact**: admin can set fee recipient or treasury to `address(0)`. Every future `operator.call{value: ...}("")` or `treasury.call{value: ...}("")` succeeds (EVM treats address(0) as an EOA accepting ETH), but the funds are permanently locked because no private key exists for address(0).

## Severity Matrix

| Likelihood | Impact | Severity |
|-----------|--------|----------|
| Low (admin-only, no exploit path) | Medium (cumulative fee burn, recoverable via admin) | **MEDIUM** |
| Low | High (permanent loss of all role-controlled funds) | HIGH |
| Medium (compromised admin / UI mistake) | Medium | MEDIUM-HIGH |

Typical Cantina rating: **MEDIUM** for input validation gaps without a revert safety net.

## PoC Template

```solidity
contract ZeroAddressValidationPoC is Test {
    Target target;
    address admin = address(0xAD);

    function setUp() public {
        // deploy target with valid params
        target = new Target();
        target.initialize(admin, ...);
    }

    function test_BuggyFunction_DoesNotRevert() public {
        // BUG: this should revert but doesn't
        vm.prank(admin);
        target.buggyFunction(0, address(0));   // or whatever input

        // Verify state was corrupted
        assertEq(target.someAddress(), address(0));
    }
}
```

Run: `forge test --match-contract ZeroAddressValidationPoC -vv`

## Recommended Fix

Add the missing validator at the top of the buggy function:

```solidity
function deactivateOperator(uint256 _operatorIndex, address _temporaryFeeRecipient) external onlyAdmin {
    _checkAddress(_temporaryFeeRecipient);   // <-- add this
    ...
}
```

Apply same fix to `activateOperator` and `setTreasury`. Audit other contracts in scope for the same gap.

## Bug Report Template

```
SUMMARY:
<Contract> has <N> admin-only functions that skip the existing
_checkAddress validator. An admin (or compromised/mistaken admin)
can set <parameter> to address(0), after which <downstream effect>
sends ETH to a non-existent recipient and the funds are permanently
burned.

DESCRIPTION:
<Walk through the inconsistency — helper exists in X functions,
missing in Y functions. Reference line numbers.>

Attack path:
1. Admin calls <buggy function>(address(0)). No revert.
2. <downstream code path> triggers.
3. <fee/transfer> sent to address(0). Lost forever.

PoC: <paste Foundry test results, e.g. "2/2 tests pass with
forge test --match-contract XYZ -vv">

Severity: MEDIUM (admin-only, but no revert safety net for
mistakes or compromise).

Fix: add _checkAddress(...) to all <N> functions.
```

## Related Patterns

- **Missing zero-address check** — most common, addressed here.
- **Missing array bounds check** — `_indexes[i]` access without length check.
- **Missing duplicate key check** — `_addValidator` without `_isDuplicate` guard.
- **Missing amount > 0 check** — `withdraw(amount)` allowing amount = 0 (no-op but spams events).

All follow same detection methodology.
