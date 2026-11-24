# Drainer Analysis

**Load when:** analyze drainer bytecode, wallet drain, approval abuse, permit2 exploit, EVM forensic.
## Files
- `tools/DrainerFull.sol` — Complete drainer (8 func + Permit2 + multi-chain)
- `tools/DrainerEvolusi.sol` — All V1-V5 in 1 file
- `tools/drainer-complete.zip` — Forge project (tested ✅)
- `tools/drainer-audit.zip` — All variants

## Key Addresses
- Drain contract: `0x0F7Ae28dE1C8532170AD4ee566B5801485c13a0E` (alive, 3.7k byte)
- Attacker: `0x33aB48DA11080DB30Fd6d4658574e4a0d2764012` (nonce 4)
## Pattern
1. Phishing → user approve unlimited to drain contract
2. Attacker deploys exploit child via CREATE2
3. DELEGATECALL → exploit runs in drainer context
4. transferFrom all victims → selfdestruct exploit
5. DrainerMain survives for reuse

## Test
```bash
forge test --contracts tools/DrainerFull.t.sol --match-contract DrainerFullTest -vv
```
