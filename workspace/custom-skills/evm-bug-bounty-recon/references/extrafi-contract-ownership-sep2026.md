# ExtraFi — Contract Ownership Analysis (Session Sep 2026)

## JS Bundle Contract Addresses Found

From `app.extrafi.io/assets/index-BYrZvAM4.js` (5.6MB):

### Factory Contracts (owner = address(0))
| Contract | Address | Owner |
|----------|---------|-------|
| Factory 1 | `0x420DD...e40Da` | `0x0000...0000` |
| Factory 2 | `0x9401...98631` | `0x0000...0000` |
| Factory 3 | `0xf104...ff5a` | `0x0000...0000` |

### Key Finding: Contract with Real Owner
| Contract | Address | Owner Chain |
|----------|---------|------------|
| XLend/Vault | `0x0555e30da8f98308edb960aa94c0db47230d2b9c` | `0xa9a6...9361` (EIP-1167 clone) |

**Owner `0xa9a6...9361` is an EIP-1167 minimal proxy (344 bytes).**
- getOwners() reverted = NOT standard Gnosis Safe pattern
- Balance: 0 ETH, tx count: 1
- Cannot extract signer keys

### Coinbase RPC Key (ACTIVE)
| Field | Value |
|-------|-------|
| Key | `0txHZs13U0KInOLNdOuRDjSUOeGHUs7d` |
| Base | `https://api.developer.coinbase.com/rpc/v1/base/<KEY>` |
| Optimism | `https://api.developer.coinbase.com/rpc/v1/optimism/<KEY>` |
| Verified | Sep 2026 — block 0x306cdcb, chain 8453 |

Also hardcoded in JS as `${paymasterRpcKey}`.

## Lessons
1. EIP-1167 clones often fail getOwners() — custom proxy, not standard GS
2. Private keys cannot be derived from on-chain data — period
3. Always check owner balance + tx count (0 balance + 1 tx = dead deployer)
4. eth_getCode returning 0x = EOA, not contract
