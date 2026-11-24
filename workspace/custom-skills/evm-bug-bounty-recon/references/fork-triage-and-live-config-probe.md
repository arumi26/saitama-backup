# Fork Triage + Live Config Probe (Aave-family forks)

Recipe distilled from the Tydro (Ink / Kraken L2) 2026-09 session. Goal: decide in ~5 minutes
whether a deployed lending fork is worth a source audit, and if so, map its config surface
using public getters instead of raw storage slots.

**Outcome of the source session:** Tydro = 100% stock Aave V3.5 + standard BGD periphery. Zero
custom logic. Verdict: **DROP, no reportable finding.** Use this as the worked example of a
correct early bail.

---

## Step 1 — Authorship scan (the fork reality check)

Distinct module names (`Dustbin`, `ConfigEngine`, `StataFactory`) are NOT evidence of custom
code. Rebranded stock modules keep the upstream `@author` header. Scan top-level `src/*.sol`:

```bash
for f in /root/<target>/src/*.sol; do
  auth=$(grep -m1 -oE "@author .*" "$f")
  spdx=$(grep -m1 -oE "SPDX-License-Identifier: .*" "$f")
  printf "%-40s %-32s %s\n" "$(basename $f)" "$spdx" "$auth"
done
```

All-`@author Aave` / `@author BGD Labs` → vanilla fork → **stop**. The Tydro run produced:

```
Pool.sol                        MIT     @author Aave
PoolConfigurator.sol            MIT     @author Aave
TydroOracle.sol                 MIT     @author Aave      # = AaveOracle verbatim
L2PoolInstance.sol              BUSL    @author BGD Labs
ConfigEngine.sol                BUSL    @author BGD Labs
StataFactoryImpl.sol            BUSL    @author BGD labs
Dustbin.sol                     MIT     (none)            # = OZ TransparentUpgradeableProxy
DustbinImpl.sol                 MIT     (none)            # = stock Aave periphery
```

Rule of thumb: a stock Aave V3.x fork's only remaining "surface" is deployment-specific config,
which is governed by the team's own admin keys — a governance observation, not a bounty.

## Step 2 — Confirm the deployed impl IS the source you audited

Two `L2PoolInstance` instances can exist (the one in `addrs.txt` vs the one the proxy actually
points at). Resolve authoritatively — never trust a hand-written address list:

```bash
R="https://rpc-gel.inkonchain.com"
PROV="0x4172E6aAEC070ACB31aaCE343A58c93E4C70f44D"   # PoolAddressesProvider
cast call $PROV "getPool()(address)" --rpc-url $R                      # authoritative Pool
cast storage <POOL> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $R  # EIP-1967 impl
# Cross-check on blockscout:
curl -s "https://explorer.inkonchain.com/api/v2/smart-contracts/<POOL>" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['name'],d['is_verified'],d['implementations'])"
```

Both `L2PoolInstance` addresses were verified with the same name/compiler — same source, two
deployments. Confirm the proxy's `implementations[].address_hash` matches the impl slot value
before concluding "the audited source == the running code".

## Step 3 — Decode the full reserve config from `getConfiguration(address)`

One packed word per reserve. Bit layout (from `ReserveConfiguration.sol`):

| field | start bit | width |
|---|---|---|
| LTV | 0 | 16 |
| liquidationThreshold | 16 | 16 |
| liquidationBonus | 32 | 16 |
| decimals | 48 | 8 |
| isActive | 56 | 1 |
| isFrozen | 57 | 1 |
| borrowingEnabled | 58 | 1 |
| isPaused | 60 | 1 |
| borrowableInIsolation | 61 | 1 |
| siloedBorrowing | 62 | 1 |
| flashloanEnabled | 63 | 1 |
| reserveFactor | 64 | 16 |
| borrowCap | 80 | 36 |
| supplyCap | 116 | 36 |
| liquidationProtocolFee | 152 | 16 |
| debtCeiling | 212 | 40 |

```python
def b(v,a,n): return (v>>a)&((1<<n)-1)
# raw = eth_call getConfiguration(asset)
ltv=b(v,0,16); lt=b(v,16,16); bon=b(v,32,16); dec=b(v,48,8)
```
Red flags to compute per reserve: `ltv > lt` (instant-borrow against own collateral),
`0 < bon < 10000` (liquidation bonus below 100% = liquidator pays to liquidate), `lt == 0`
while borrowing enabled. Tydro: all clean.

## Step 4 — eMode categories via bitmaps (NOT storage slots)

The eMode struct is `{ltv, lt, bonus, collateralBitmap, label, borrowableBitmap}` — but do NOT
try to read it from storage. Use the getters:

```bash
cast call $POOL "getEModeCategoryCollateralBitmap(uint8)(uint128)" 1 --rpc-url $R
cast call $POOL "getEModeCategoryBorrowableBitmap(uint8)(uint128)" 1 --rpc-url $R
```
Bit `i` set = reserve index `i` (map index → asset via `getReservesList()`).
A non-correlated asset wrongly inside an ETH-correlated eMode (93/95% LTV) = real finding.
Tydro: cat1 = weETH/wrsETH/ezETH→WETH, cat2 = sUSDe/USDe→stables, cat6 = SolvBTC→GHO — all sane.

## Step 5 — Oracle sanity

```bash
cast call $ORACLE "getAssetPrice(address)(uint256)" <ASSET> --rpc-url $R
cast call $ORACLE "getSourceOfAsset(address)(address)" <ASSET> --rpc-url $R
```
Price is in base-currency units (USD here, 1e8). Compare against market. Two assets sharing one
feed (USDT0+USDe, or kBTC+SolvBTC) is *plausible* (same underlying family), not automatically a
bug — only flag if the shared feed is wrong for one of them. All Tydro prices were accurate.

## Step 6 — Interest-rate strategy params (the "economic angle")

If you must keep going on a stock fork, the only remaining surface is economics. On Aave V3.5
there is **ONE shared `DefaultReserveInterestRateStrategyV2`** for the whole pool — every reserve
returns the *same* `getInterestRateStrategyAddress`, with per-reserve params stored in a mapping
inside it. So don't loop expecting per-reserve strategy contracts; read the mapping:

```bash
R="https://rpc-gel.inkonchain.com"; ST="0xcfdada7dcd2e785cf706badbc2b8af5084d595e9"
cast call $ST "getInterestRateDataBps(address)(uint256,uint256,uint256,uint256)" <ASSET> --rpc-url $R
# per-field getters:
cast call $ST "getOptimalUsageRatio(address)(uint256)"        <ASSET> --rpc-url $R
cast call $ST "getBaseVariableBorrowRate(address)(uint256)"   <ASSET> --rpc-url $R
cast call $ST "getVariableRateSlope1(address)(uint256)"       <ASSET> --rpc-url $R
cast call $ST "getVariableRateSlope2(address)(uint256)"       <ASSET> --rpc-url $R
```

**UNITS GOTCHA:** `getInterestRateDataBps(...)` returns **bps** (10000 = 100%), but the individual
`getOptimalUsageRatio` / `getBaseVariableBorrowRate` / `getVariableRateSlope1|2` getters return
**RAY** (1e27 = 100%). Mixing them silently produces numbers that look 1e23× too big. Decode one
way or the other, and cross-check the two against each other before trusting either.

Tydro values (2026-09) — all within normal Aave-fork ranges:

| Asset | optimal | base | slope1 | slope2 | max@100% |
|---|---:|---:|---:|---:|---:|
| WETH | 90% | 3.0% | 1.0% | 1.0% | 5.0% |
| kBTC | 45% | 8.0% | 4.0% | 80% | 92% |
| USDT0 / USDG | 90% / 83% | 0% | 4.0% | 10% | 14% |
| GHO | 90% | 0% | 5.5% | 10% | 15.5% |
| USDC | 95% | 6.3% | 0% | 0% | 6.3% |
| weETH/wrsETH/ezETH/sUSDe/SolvBTC/syrupUSDT | 45% | 0% | 10% | 300% | 310% |
| USDe | 80% | 0% | 4.0% | 12% | 16% |

**Verdict rule:** unusual ≠ broken. Flat 3% base on WETH, constant 6.3% on USDC, and 45%-optimal +
300% slope2 on LST/LRTs are all *governance choices*, not exploitable misconfig — nothing here is
drainable. On a stock fork this whole surface belongs to the team's admin keys → governance
observation, **not a bounty**. Don't inflate it.

## Pitfalls hit this session
- **`cast call` cannot decode nested-tuple / struct returns.** `getReserveData(address)` (17-field
  struct), `getAllReservesTokens()((string,address)[])`, and the data provider's
  `getReserveConfigurationData(address)` all fail with `Error: parser error:` followed by the raw
  words. Do NOT retry with different signature syntax — go straight to raw
  `cast rpc eth_call '{"to":..,"data":..}' latest --rpc-url $R` and slice the hex into 64-char
  words, converting each with `int(word,16)`. Word `0` of a struct return is the first field, so
  index from the struct's own field order, not from a guess.
- **`cast storage` at the IMPL address reads the impl's own (empty) storage.** Reading slots at the
  implementation returns all zeros and looks like "no data" — always read `cast storage` at the
  **proxy** address. (Same class of trap as reading logic from a proxy: resolve which address owns
  the storage first.)
- **Aave V3.5 Pool storage is ERC-7201 namespaced.** Even at the proxy, naive
  `keccak(abi.encode(asset, slot))` mapping-slot reads return zeros — the namespaced base slot is
  `keccak256("aave.storage.pool")`-style, not slot 0. Consequence: you cannot reach the reserve
  struct by hand-computed slots. **Three separate slot-guessing attempts all returned zeros this
  session — stop after the second and switch to getters** (Two-Pass Rule).
- **`eth_getStorageAt` eMode/reserve scan = rabbit hole.** Offsets shift with proxy/inheritance
  layout; all reads returned zeros. Getters are the answer.
- **ACL role getters revert** on V3.5-style ACLs: `getRoleMemberCount(bytes32)` reverts with
  `execution reverted` — the deployed ACL interface differs from the repo's `AccessControl`.
  Don't burn turns; admin-role enumeration is low-value on a stock fork anyway.
- **`addrs.txt`-style address lists lie.** Always resolve the live impl via `getPool()` on the
  AddressesProvider + the EIP-1967 slot.
