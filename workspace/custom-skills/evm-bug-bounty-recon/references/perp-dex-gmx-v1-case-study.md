# GMX V1 Vault — Perpetual DEX Audit Case Study

**Date:** 2026-07-16
**Target:** GMX V1 Vault (`0x489ee077994B6658eAfA855C308275EAd8097C4A`, Arbitrum)
**TVL:** ~$179M ecosystem, V1 Vault specifically ~$537K across WETH/WBTC/LINK/UNI/USDC
**Category:** Perpetual DEX (leverage trading)
**Audits:** Multiple (well-audited)
**Source:** `github.com/gmx-io/gmx-contracts` (Solidity 0.6.12)

## Architecture (Key Contracts)

| Contract | Path | Purpose |
|----------|------|---------|
| Vault | `contracts/core/Vault.sol` | Holds funds, manages positions, pricing |
| VaultPriceFeed | `contracts/core/VaultPriceFeed.sol` | Oracle aggregation (Chainlink + AMM + FastPriceFeed) |
| FastPriceFeed | `contracts/oracle/FastPriceFeed.sol` | Pyth-based secondary oracle |
| VaultUtils | `contracts/core/VaultUtils.sol` | Position validation, funding fee calculation |
| PositionRouter | `contracts/core/PositionRouter.sol` | Delayed position execution |
| Router | `contracts/core/Router.sol` | User-facing entry, plugin system |
| OrderBook | `contracts/core/OrderBook.sol` | Limit/trigger orders |

## Oracle System (3-Layer)

```
VaultPriceFeed.getPrice()
├── getPrimaryPrice() — Chainlink (samples N rounds, returns max/min based on _maximise)
├── getAmmPrice() — AMM pair reserves (BNB-based pairs, can be manipulated)
└── getSecondaryPrice() — FastPriceFeed (Pyth, cumulative delta checks)
```

**Key parameters:**
- `priceSampleSpace = 3` — samples 3 Chainlink rounds
- `spreadBasisPoints` — per-token spread (max 50 bps)
- `maxDeviationBasisPoints` — FastPriceFeed max deviation from Chainlink
- `spreadThresholdBasisPoints = 30` — AMM price spread threshold
- `includeAmmPrice = false` during liquidation (anti-manipulation)

**Price usage pattern (CRITICAL):**
- Open long: `getMaxPrice` (worst for trader)
- Close long: `getMinPrice` (worst for trader)
- Liquidate long: `getMinPrice` (worst for trader)
- Open short: `getMinPrice` (worst for trader)
- Close short: `getMaxPrice` (worst for trader)

## Key Attack Surface: Pool Utilisation

**`_increaseReservedAmount` has NO upper bound check against `poolAmounts`.**

```solidity
function _increaseReservedAmount(address _token, uint256 _amount) internal {
    reservedAmounts[_token] = reservedAmounts[_token].add(_amount);
    // MISSING: require(reservedAmounts[_token] <= poolAmounts[_token])
}
```

**Consequence:** With 100x max leverage, a position can push `reservedAmounts` beyond `poolAmounts`, creating pool insolvency. The only check is in `increasePosition` via `VaultUtils.validateIncreasePosition()` which does NOT check pool bounds.

**On-chain state (block 484282625):**
```
WBTC Pool: 624 WBTC ($10.6M) — Reserved: 244 WBTC ($4.1M) — 39% utilised
WETH Pool: 6.5 WETH ($12.4K) — Reserved: 6.5 WETH — 100% utilised
USDC Pool: $20K — Reserved: $20K — 100% utilised
Max Leverage: 100x
Margin Fee: 10 bps (0.1%)
Liquidation Fee: $5 per position
Funding Rate Factor: 100
```

## Funding Rate Cascade Attack

**Formula:** `fundingRate = fundingRateFactor * (reservedAmounts / poolAmounts) * intervals`

At >100% utilisation, funding rate exceeds 100% per interval (8h). This liquidates ALL existing positions within 1 funding interval.

**Attack sequence:**
1. Flashloan collateral (e.g., 3.8 WBTC ≈ $65K)
2. Open 100x long → push reservedAmounts from 39% to 100%+
3. Funding rate spikes → existing positions liquidated
4. Capture liquidation fees + pool imbalance
5. Close position + repay flashloan

**Constraint:** Position size must not exceed pool amount (otherwise `increasePosition` fails in `_increaseReservedAmount`). The attack works within pool bounds by pushing utilisation from 39% to ~100%.

## Foundry Fork Testing

**Public RPC pitfall:** Arbitrum public RPC (`arb1.arbitrum.io/rpc`) does NOT support archive state. Use latest block only:
```bash
forge test --rpc-url "https://arb1.arbitrum.io/rpc" --match-test "test_InspectVault" -vvvv
# Do NOT use --fork-block-number with public RPC
```

**Checksum address requirement:** Solidity 0.8.x enforces EIP-55 checksum on address literals. Use `cast to-checksum-address 0x...` or `Web3.to_checksum_address()` in Python.

**Console log in view functions:** `emit log(...)` and `emit log_named_uint(...)` modify state (emit events). Cannot be used in `view` functions. Remove `view` modifier from test functions that use logging.

**eth_call for fast on-chain reads (Python/web3.py):**
```python
from web3 import Web3
w3 = Web3(Web3.HTTPProvider("https://arb1.arbitrum.io/rpc"))
VAULT = w3.to_checksum_address("0x489ee077994B6658eAfA855C308275EAd8097C4A")

def call_view(to, sig, args=""):
    data = Web3.keccak(text=sig)[:4].hex() + args
    result = w3.eth.call({"to": to, "data": bytes.fromhex(data)})
    return int(result.hex(), 16)

padded = WETH[2:].lower().zfill(64)
pool = call_view(VAULT, "poolAmounts(address)", padded)
reserved = call_view(VAULT, "reservedAmounts(address)", padded)
```

## Lessons Learned

1. **"No system is safe" is correct but misleading.** GMX V1 has real bugs (pool utilisation gap), but exploiting them requires significant capital ($65K+) and precise timing. The bug is real but the exploit is hard.

2. **DeFiLlama TVL distribution is deceptive.** The $179M GMX TVL is NOT in the V1 Vault ($537K). Most is in GLP/GM pools or staking. Always check on-chain pool amounts, not just protocol-level TVL.

3. **100x leverage is the attack amplifier.** Without 100x max leverage, the pool utilisation manipulation would require 10-50x more capital. The leverage multiplier is what makes the bug exploitable.

4. **`includeAmmPrice = false` during liquidation is smart defense.** GMX explicitly disables AMM price during liquidation to prevent oracle manipulation. This blocks the most common perp DEX attack vector.

5. **Funding rate cascade is a NOVEL attack class.** Not documented in standard audit checklists. The formula `factor * (reserved/pool) * intervals` creates a positive feedback loop when utilisation exceeds 100%.

## Immunefi Bounty Status

**V1 is OUT OF SCOPE.** GMX Immunefi bounty (updated Jan 2026) lists only V2 contracts on Avalanche. V1 contracts (Vault, VaultPriceFeed, etc.) are NOT in scope.

**Pool insolvency is EXPLICITLY EXCLUDED:** "Cases involving risks of losses to the GLP pool in case the assets in the pool decrease in price" — this covers the utilisation manipulation finding.

**Other excluded categories relevant to this audit:**
- Price manipulation on exchanges
- Exploits that are not economically practical to execute
- Exploits due to delays or sizes of price feed updates
- Liquidation keeper gas griefing

**Lesson:** Always check Immunefi scope + exclusions BEFORE deep audit. The pool utilisation bug is real but cannot be submitted for bounty.
