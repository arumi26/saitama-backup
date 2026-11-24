# PumpFun / Bonding Curve Audit Notes (July 2026)

**Target:** Trustdev-eth/evm-base-pumfun-smart-contract-v1  
**Chain:** Base  
**Type:** Pump.fun-style bonding curve → Uniswap V2 AMM graduation  
**Age:** ~2 months (pushed 2026-05-26)  
**Bounty:** None tracked — user will report to Twitter/X dev directly

---

## Architecture

User → TokenFactory.deployERC20Token → PumpFun.createPool() (bonding curve) → Buy/Sell on curve → graduation (20% remaining OR mcap threshold) → Owner withdraw() → PancakePair LP via Router

### Contracts (752 LOC total)
| File | LOC | Role |
|------|-----|------|
| PumpFun.sol | 277 | Core bonding curve: createPool, buy, sell, withdraw, calculateEthCost |
| TokenFactory.sol | 63 | Deploys ERC20 tokens, auto-creates bonding curve pool |
| Router.sol | 247 | Add/remove liquidity, swap between token+WETH via Pair |
| Pair.sol | 165 | Uniswap V2 style Pair with mint/burn/swap |
| Token.sol | 33 | Standard OpenZeppelin ERC20 |

---

## Vulnerability Analysis

### CRITICAL-01: Pair.sol mint()/burn()/swap() — No Access Control

**File:** contracts/Pair.sol  
**Issue:** No onlyRouter/onlyCore modifier. Anyone can call mint() to set arbitrary reserves + LP ownership, or swap() to manipulate pool state without token movement.  
**Impact:** Reserve manipulation, fake LP tokens, price manipulation.  
**Severity:** CRITICAL — impact depends on Router mediation.

### HIGH-01: PumpFun.buy() — CEI Violation

**File:** contracts/PumpFun.sol lines 117-130  
**Pattern:** payable(feeRecipient).transfer(feeAmount) + IERC20(token).transfer(msg.sender, amount) BEFORE state updates (realTokenReserves -= amount, etc.)  
**Mitigation:** nonReentrant blocks reentering buy/sell, but state is stale for any reentrant read.  
**Fix:** Move state updates before external calls.

### HIGH-02: TokenFactory Owner Rug via setPoolAddress

**File:** contracts/TokenFactory.sol lines 60-63  
**Pattern:** onlyOwner can redirect contractAddress to malicious PumpFun clone → all deployed tokens auto-approve 10^27 to attacker.  
**Impact:** All tokens deployed through factory at risk if owner compromised.  
**Fix:** Timelock/multisig on setPoolAddress, or set once in constructor.

### MEDIUM-01: calculateEthCost Return 0 for Small Amounts

**File:** contracts/PumpFun.sol lines 159-166  
**Pattern:** Integer division rounds ethCost to 1 wei for amount=1 when reserves are large (10^27 / 3*10^21).  
**Impact:** Tokens can be bought for effectively 1 wei on initial curve.  
**Severity:** MEDIUM — dust attack, limited fund loss.

### LOW-01: withraw() Doesn't Reset Virtual Reserves

After graduation + owner withdrawal, virtualEthReserves and virtualTokenReserves retain old values. Complete is true so no further trades, but external integrators may read stale state.

### INFO-01: No Min/Max Fee Bounds

setFeeAmount(feeBasisPoint, createFee) has no bounds — fee can be 0 or 10000 (100%). Owner-dependent.

---

## Bonding Curve Attack Surface Checklist

When auditing any bonding curve protocol:

1. **CEI order** — Does buy()/sell() transfer BEFORE updating reserves?
2. **Access control on Pair/AMM** — Can anyone call mint()/burn()/swap()?
3. **Token approval risk** — TokenFactory auto-approve max to settable address?
4. **Rounding edge cases** — calculateEthCost or similar can return 0?
5. **Reserve invariants** — Virtual and real reserves stay in sync?
6. **Graduation finality** — What happens after curve completion?
7. **Fee bounds** — Can owner set fees to 100%?
8. **Owner rug vectors** — withraw() after forcing completion, setFeeRecipient, setOwner

### Memecoin Specific Risks

- Bonding curves are inherently front-runnable
- TokenFactory with 10^27 auto-approval creates large approval surface
- Fee structure (createFee + basisFee) extracts significant value from early traders
- Only slippage protection is maxEthCost/minEthOutput — MEV prone

---

## Reference

Repo: https://github.com/Trustdev-eth/evm-base-pumfun-smart-contract-v1  
Cookie domain: pumpfun-protocol.vercel.app (Vercel Challenge detected on web scan)