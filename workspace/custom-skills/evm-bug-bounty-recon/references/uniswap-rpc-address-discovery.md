# Uniswap Router Address Discovery via RPC (Non-SDK Chains)

## Problem
`@uniswap/sdk-core` may not have deployment addresses for newer/smaller chains (e.g., Robinhood Chain ID 4663). The `node tools/fetch_addresses.mjs` script fails with `ERR_MODULE_NOT_FOUND`. Uniswap's support page may also be inaccessible.

## Solution: Blockscout Search + RPC Selector Calls

### Step 1: Find candidate contracts via Blockscout
```bash
# Search for SwapRouter02 (V3)
curl -s "https://<CHAIN>.blockscout.com/api/v2/search?q=SwapRouter02" | jq '.items[] | select(.type=="contract") | .address_hash'

# Search for UniswapV2Router02
curl -s "https://<CHAIN>.blockscout.com/api/v2/search?q=UniswapV2Router02" | jq '.items[] | select(.type=="contract") | .address_hash'
```

Multiple results are common — there may be several deployments (some by third parties, some broken).

### Step 2: Verify via RPC selector calls
Identify the REAL router by calling known function selectors:

```bash
# SwapRouter02 (V3) — call factory() selector = 0xc45a0155
for addr in <candidate_addresses>; do
  curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$addr\",\"data\":\"0xc45a0155\"},\"latest\"],\"id\":1}" \
    | jq -r '.result'
done
# Compare returned factory address against known UniswapV3Factory addresses from Blockscout search

# V2Router02 — call WETH() selector = 0xad5c4648
for addr in <candidate_addresses>; do
  curl -s -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$addr\",\"data\":\"0xad5c4648\"},\"latest\"],\"id\":1}" \
    | jq -r '.result'
done
# Valid WETH address (>42 chars, not 0x0) = real router
```

### Step 3: Cross-reference factory addresses
```bash
# Search for UniswapV3Factory on Blockscout
curl -s "https://<CHAIN>.blockscout.com/api/v2/search?q=UniswapV3Factory" | jq '.items[] | select(.type=="contract") | .address_hash'

# The SwapRouter02 whose factory() return matches a verified UniswapV3Factory address = CORRECT router
```

### Step 4: Verify deployment (code size > 0)
```bash
curl -s -X POST "$RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getCode","params":["<addr>","latest"],"id":1}' \
  | jq -r '.result | length'
# Should be > 4 (0x prefix + bytecode). ~24000 bytes = real deployment.
```

## Robinhood Chain (4663) Results — 2026-07-30

| Contract | Address | Verification |
|----------|---------|--------------|
| SwapRouter02 (V3) | `0xeEA4F049b3671064a47c459BafEeD1f0483C0AaF` | factory() → `0xa177FF772ee843BF54C3Fd37df486086F9C366D3` (matches UniswapV3Factory) |
| V2Router02 | `0xA5deC66ECa62AE363dC47965bB790C3B8870b6B6` | WETH() → `0x0bd7D308f8e1639fAB988dF18a8011F41eacad73` |
| WETH | `0x0bd7D308f8e1639fAB988dF18a8011F41eacad73` | Derived from V2Router02 WETH() call |
| UniswapV3Factory | `0xa177FF772ee843BF54C3Fd37df486086F9C366D3` | From Blockscout search |

Code sizes: SwapRouter02 = 24,497 bytes, V2Router02 = 21,996 bytes — both confirmed deployed.

## Other Useful Selectors

| Function | Selector | Use Case |
|----------|----------|----------|
| `WETH9()` | `0x9e3da6f5` | SwapRouter02 (V3) WETH address |
| `WETH()` | `0xad5c4648` | V2Router02 WETH address |
| `factory()` | `0xc45a0155` | V3 SwapRouter → V3 Factory address |
| `factory()` | `0xc45a0155` | V2Router02 → V2 Factory address (different ABI) |
| `totalSupply()` | `0x18160ddd` | Token verification |
| `balanceOf(address)` | `0x70a08231` | Token balance check |

## Key Takeaway
When SDK doesn't support a chain, **don't guess addresses from search results alone**. Always verify via RPC selector calls — many chains have multiple contracts named "SwapRouter02" but only one is the legitimate Uniswap deployment. The factory() → factory address cross-reference is the definitive verification.
