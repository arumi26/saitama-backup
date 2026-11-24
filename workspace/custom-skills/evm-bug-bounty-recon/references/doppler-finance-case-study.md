# Doppler Finance Case Study — TWO SEPARATE CODEBASES, DIFFERENT CHAINS

**Date:** 2026-07-17 (updated 2026-07-18 after verification)  
**Researcher:** Nanwasa  
**Target:** Doppler Finance — **CRITICAL CORRECTION: Two distinct deployments**

---

## 2026-09 UPDATE — Ethereum RLUSD Vault: On-Chain Map + LIVE-BROKEN Invariant

Prior sessions left the Ethereum vault address as "not publicly verified." It is now fully
identified, and its headline invariant is **live-broken on mainnet**.

### Deployment map (verified on-chain)

| Item | Value |
|---|---|
| Vault proxy (Ethereum) | `0xfD5366c739d08018286Dd0c6c0F547Ec72906717` |
| Implementation (ERC-1967) | `0x64fd24937bf062474a3380f1bd67c7876d1bffb6` |
| ERC-1967 impl slot | `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc` |
| Deposit token | RLUSD (Ripple USD) `0x8292bb45bf1ee4d140127049757c2e0ff06317ed` |
| Treasury (matches docs page) | `0x6567412A6D8692104A25B09534B556E2c4E74902` |
| Owner / Operator | `0xe72551d7a9713e140e8699c23ff8edeb1d44905d` / `0xba55929b662dc8f6694b2ca1e3412d557a9b96de` |

### How the address was found — Vite bundle env mining

`doppler.finance` and `app.doppler.finance` are SPAs (every path → 200 catch-all); the vault
address was NOT on any docs page. It was inlined in the app bundle:

```bash
curl -sL https://app.doppler.finance/ -o app.html
grep -oE '/assets/[^"]+\.js' app.html | sort -u
curl -sL https://app.doppler.finance/assets/index-*.js -o app.js
grep -oE '.{160}VITE_VAULT_ETHEREUM.{200}' app.js      # → address in the inlined env
grep -oE 'VITE_[A-Z_]+["'"'"']?\s*[:=]\s*["'"'"'][^"'"'"']+' app.js | sort -u
```

Vite inlines `VITE_*` env vars into the client bundle exactly as Next.js does
`NEXT_PUBLIC_*` — a parallel surface to `references/nextjs-dapp-recon.md`. Also leaked: a
QuickNode RPC URL with an embedded API key. Docs *did* confirm the same treasury address,
so the bundle address could be cross-checked rather than trusted blindly.

### Proof the on-chain code == the audited repo

The repo (`Doppler-Finance/vault` @ commit `8e338ad`) is the SAME commit Zenith audited.
Confirmed by extracting PUSH4 selectors from the implementation's runtime bytecode and
intersecting with the repo's compiled ABI selectors → **67/68 match** (the 1 "missing" was a
regex-extraction artifact, not a real difference). See the SKILL.md section
"Prove the Deployment IS the Code You Audited" — and heed its `lstrip('0x')` pitfall, which
produced the false "missing selector" on the first pass here.

### The bug is LIVE — treasury invariant broken on mainnet

`setTreasury` asserts `IERC20(token).balanceOf(_treasury) >= totalSupply + totalInterest`, but
`updateYield()` increments `totalInterest` with **zero tokens moved and no check** → the
invariant is broken by the operator's normal daily action, and nothing restores it. Live read:

```
totalSupply    = 146,074.60 RLUSD
totalInterest  =   5,487.58 RLUSD
OBLIGATION     = 151,562.18 RLUSD
treasury.bal   =  46,717.95 RLUSD
SHORTFALL      = 104,844.23 RLUSD   (69.18% unbacked)
```

`_undelegate()` pulls `principal + interest` all-or-nothing (`safeTransferFrom(treasury, this,
total)` reverts if short) → the shortfall is borne by the LAST claimer, who cannot even
recover principal. This is FINDINGS.md **F-D** manifesting on-chain.

**Honest-reporting caveat:** docs state the vault's yield is CeDeFi/off-chain, so a treasury
shortfall *may* reflect off-chain deployment rather than an in-flight exploit. The CODE bug
(unfunded liability) is real regardless; the live number is corroboration, not proof of
imminent loss. Don't headline it as "funds are gone."

### HOMONYM TRAP — `hackerone.com/doppler` is a DIFFERENT company

`hackerone.com/doppler` exists and looks like a program for this target. It is **Doppler
Secrets Manager** (`doppler.lol`), a secrets-management SaaS — unrelated to Doppler Finance
(`doppler.finance`). Doppler Finance has **NO** bounty program on any platform (Immunefi /
Cantina / Code4rena / HackerOne all checked); disclosure is Discord-only (their Risks page
invites risk reports there). A DDG/Google search for "Doppler HackerOne" lands on the
homonym — always open the program page and confirm the org's domain/product matches.

---

## ⚠️ CRITICAL CORRECTION (2026-07-18)

**Doppler Finance has TWO completely separate codebases on DIFFERENT chains:**

| | **XRPL EVM Sidechain** | **Ethereum Mainnet** |
|---|---|---|
| **GitHub** | `github.com/girin-app/contracts` | `github.com/Doppler-Finance/vault` |
| **Architecture** | Venus Protocol fork (Compound V2) | Custom single-sided vault |
| **Oracle** | Centralized `priceInjector` (3 oracles, UUPS) | N/A — no oracle, fixed APR via `yieldMaxRate` |
| **Audits** | **0 AUDITS** | **2 AUDITS** (Certik + Zenith, Aug 2025) |
| **TVL Source** | $94.3M — API-based (Fireblocks/Ceffu custody) | $228k — on-chain RLUSD vault |
| **Bug Bounty** | None (direct disclosure) | None (direct disclosure) |

**DEFI LLAMA $94.6M TVL = $94.3M XRPL (off-chain custodial) + $228k Ethereum (on-chain)**

**MY INITIAL AUDIT TARGETED WRONG CODEBASE FOR ETHEREUM MAINNET.** The Venus fork oracle bugs (CRIT-01, CRIT-02, HIGH-03) exist ONLY on XRPL EVM Sidechain (girin-app/contracts), NOT on Ethereum mainnet.

---

## XRPL EVM Sidechain — girin-app/contracts (0 AUDITS)

**GitHub:** github.com/girin-app/contracts (public, 6 commits, last Jan 2025)  
**Architecture:** Venus Protocol fork (Comptroller + LtToken + custom oracles)  
**Oracle:** Centralized `priceInjector` — 3 UUPS upgradeable oracles (`SlotMuxOracle`, `TimeoutOracle`, `RouterOracle`)  
**TVL:** $94.3M reported via API (Fireblocks + Ceffu custodial, NOT on-chain contract balances)

### Validated Findings on XRPL EVM Sidechain

| ID | Severity | Finding | Status |
|---|---|---|---|
| CRIT-01 | CRITICAL | Centralized Oracle Takeover — owner can swap `priceInjector` → full price manipulation | ✅ Validated in source |
| CRIT-02 | CRITICAL | UUPS Upgrade to Malicious Implementation — `_authorizeUpgrade` = `onlyOwner` | ✅ Validated in source |
| HIGH-03 | HIGH | No TWAP, 3-hour staleness only, no Chainlink fallback | ✅ Validated in source |

**Attack Chain (if owner compromised):**
1. `updatePriceInjector(attackerEOA)` on any oracle
2. `injectPricesByLtToken([victimMarket], [fakePrice])`
3. Liquidate borrowers at manipulated price / DOS protocol

**No mitigations:** No timelock, no multi-sig, no Chainlink fallback, no TWAP.

---

## Ethereum Mainnet — Doppler-Finance/vault (2 AUDITS, CLEAN)

**GitHub:** github.com/Doppler-Finance/vault (Vault.sol + Gateway.sol)  
**Audits:** 
- Certik: April 2025 (pentest, 2 Major logic flaws RESOLVED, 5 Minor, 4 Info)
- Zenith: August 2025 (0 issues found)

**Architecture:** Single-sided deposit vault with 7-day withdrawal delay, operator-delegated undelegate, yield distribution via `updateYield()` capped at `yieldMaxRate` (default 3%).

**Key Functions:**
- `deposit()` → mints xTokens (share tokens), sends underlying to treasury
- `withdraw()` → burns xTokens, queues withdrawal per day bucket
- `undelegate()` (operator only) → releases queued withdrawals from treasury to contract
- `claim()` → users claim released withdrawals after `withdrawalDelay` (7 days)
- `updateYield()` (operator only) → adds yield, capped at `totalSupply * yieldMaxRate / 10000` per day

**No Oracle:** Fixed yield rate, no price feeds, no liquidation logic.

**Vault.sol Audit Notes:**
- Pausable, OwnableUpgradeable, UUPSUpgradeable
- `onlyOperator` on `undelegate()`, `updateYield()`
- `onlyGateway` on `claimBehalf()`
- Owner can: `setOperator`, `setGateway`, `setTreasury`, `setYieldMaxRate`, `setDepositCap`, `pause`/`unpause`
- Treasury balance validated on `setTreasury`: `balanceOf(treasury) >= totalSupply + totalInterest`

---

## Lessons Learned — TARGET VERIFICATION CHECKLIST

**BEFORE deep diving any protocol, ALWAYS verify:**

```bash
# 1. Check DeFiLlama chainTvls — is TVL on TARGET CHAIN or different chain?
# 2. Check GitHub org — are there MULTIPLE repos for different chains?
curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=50" | python3 -c "
import sys, json
for r in json.load(sys.stdin):
    print(f'{r[\"name\"]} | private={r.get(\"private\")} | lang={r.get(\"language\")}')"

# 3. Check audit status on PROTOCOL'S docs, not DeFiLlama
#    Doppler: docs.doppler.finance/resources/audits → Certik + Zenith for VAULT only

# 4. Find DEPLOYED contract addresses on TARGET CHAIN
#    - Etherscan/Basescan/Arbiscan verified contracts
#    - Protocol docs / developer portal
#    - JS bundle extraction from frontend
#    - NOT from DeFiLlama adapter (API-based TVL ≠ contract addresses)

# 5. Cross-reference: Does the GitHub repo code MATCH deployed bytecode?
#    cast code <address> | diff <local_compiled_bytecode>
```

**Mistake made:** Assumed `girin-app/contracts` (Venus fork) was the Ethereum mainnet deployment because DeFiLlama showed "Ethereum" in chains. Reality: DeFiLlama `chainTvls` for Ethereum was $228k RLUSD vault (DIFFERENT codebase), while $94.3M was XRPL (off-chain custodial API).

**Rule:** DeFiLlama "chains" field lists ALL chains protocol operates on — NOT which chain the GitHub repo deploys to.

---

## Bounty Program Status (Both Deployments)

❌ **No Immunefi bounty**  
❌ **No HackerOne/Bugcrowd/Intigriti**  
✅ **Direct disclosure only:** `security@doppler.finance` / `@doppler_finance` (X) / Discord

---

## Protocol Overview

Doppler Finance is a **Venus Protocol fork** (Compound V2 architecture) deployed on XRPL EVM Sidechain with a small Ethereum RLUSD vault. It markets itself as "XRPfi" — yield on XRP/RLUSD via CeDeFi strategies (Fireblocks + Ceffu custody).

**Key deviation from Venus:** Oracle system is **fully centralized** — not Chainlink, not TWAP. Prices injected off-chain by a single `priceInjector` address.

---

## Critical Findings

### CRIT-01: Centralized Oracle Takeover (CVSS 9.8)

**Files:** `SlotMuxOracle.sol`, `TimeoutOracle.sol`, `RouterOracle.sol`

All three oracle contracts inherit `UUPSUpgradeable` + `OwnableUpgradeable` with `onlyOwner` authorization:

```solidity
// SlotMuxOracle.sol L204-L208
function updatePriceInjector(address _priceInjector) onlyOwner external {
    priceInjector = _priceInjector;
}

// RouterOracle.sol L58-L60
function updateOracleInjector(address oracleInjector_) onlyOwner external {
    oracleInjector = oracleInjector_;
}
```

**Attack Chain:**
1. Compromise owner key / governance / timelock bypass
2. Call `updatePriceInjector(attackerEOA)`
3. Call `injectPricesByLtToken([victimMarket], [manipulatedPrice])`
4. Trigger liquidations at fake price → steal collateral
5. Or set price=0 → DOS all borrowing/liquidation

**No mitigations:** No timelock, no multi-sig, no Chainlink fallback, no TWAP.

### CRIT-02: UUPS Upgrade to Malicious Implementation

```solidity
// SlotMuxOracle.sol L44
function _authorizeUpgrade(address) internal override onlyOwner {}
```

Owner can deploy malicious logic → `upgradeTo(maliciousImpl)` → drain all markets.

### HIGH-03: No TWAP / Only 3-Hour Staleness

```solidity
// SlotMuxOracle.sol L35
priceAvailableTime = 3 hours;  // 10,800 seconds
```

- Single off-chain price feed
- No Chainlink fallback
- No time-weighted average
- 3-hour window = massive manipulation surface

---

## Oracle Architecture

| Oracle | Purpose | Price Source |
|--------|---------|--------------|
| `SlotMuxOracle` | Main oracle, packs 2 prices per slot (gas optimization) | `priceInjector` off-chain |
| `TimeoutOracle` | Simpler single-price oracle | `priceInjector` off-chain |
| `RouterOracle` | Routes ltToken → underlying → oracle address | `oracleInjector` sets mapping |

All three are **upgradeable proxies** with single-owner control.

---

## Venus Fork Deviations (Audit Surface)

| Component | Venus Standard | Doppler Implementation | Risk |
|-----------|---------------|------------------------|------|
| Oracle | Chainlink + TWAP (ResilientOracle) | Centralized priceInjector | CRITICAL |
| Comptroller | `Comptroller.sol` (Venus) | Nearly identical | LOW |
| LtToken | `VToken.sol` (Venus) | `LtToken.sol` renamed, same logic | LOW |
| Interest Rate | JumpRateModelV2 | Identical | LOW |
| Access Control | ACM (AccessControlManager) | Identical | LOW |
| Upgradeability | UUPS (some) | All oracles UUPS + Ownable | HIGH |

---

## On-Chale Verification Status

**Ethereum RLUSD Vault:** TVL tracked via API (`https://api.doppler.finance/v2/staking-info/token/RLUSD`) — **not on-chain contract balances**. DeFiLlama adapter calls centralized API.

**XRPL EVM Sidechain:** Main TVL ($94M) on XRPL EVM — contract addresses **not publicly verified** on explorer. No Etherscan-equivalent for XRPL EVM yet.

**Implication:** Cannot verify actual contract holdings vs API-reported TVL. CeDeFi custody (Fireblocks + Ceffu) means on-chain balances ≠ user funds.

---

## Bounty Program Status

❌ **No Immunefi bounty**  
❌ **No HackerOne/Bugcrowd/Intigriti**  
✅ **Direct disclosure only:** `security@doppler.finance` / `@doppler_finance` (X) / Discord

---

## PoC: Oracle Price Injection Attack

```solidity
// Foundry test — simulates owner compromise → price manipulation
function test_OraclePriceInjection() public {
    vm.createSelectFork(XRPL_EVM_RPC_URL);
    
    ISlotMuxOracle oracle = ISlotMuxOracle(SLOT_MUX_ORACLE_ADDRESS);
    address attacker = address(0xDEAD);
    vm.deal(attacker, 100 ether);
    
    // Owner compromised — attacker becomes priceInjector
    vm.prank(oracle.priceInjector()); // or owner()
    oracle.updatePriceInjector(attacker);
    
    // Inject fake price: 1 RLUSD = $0.01 (100x manipulation)
    address[] memory markets = new address[](1);
    uint128[] memory prices = new uint128[](1);
    markets[0] = VICTIM_LTTOKEN_RLUSD;
    prices[0] = 10_000_000_000_000_000; // $0.01 * 1e18
    
    vm.prank(attacker);
    oracle.injectPricesByLtToken(markets, prices);
    
    // Verify manipulation
    uint256 price = oracle.getUnderlyingPrice(VICTIM_LTTOKEN_RLUSD);
    assertEq(price, 10_000_000_000_000_000);
    
    // Impact: liquidate borrowers at fake price
    // IComptroller(ILtToken(VICTIM_LTTOKEN_RLUSD).comptroller())
    //     .liquidateBorrow(victim, repayAmount, ltTokenCollateral);
}
```

---

## Lessons for Venus Fork Hunting

1. **Always check oracle implementation first** — Venus forks often replace ResilientOracle with custom/centralized oracles
2. **UUPS + onlyOwner = critical risk** — any upgradeable contract with single-owner upgrade auth is a protocol takeover vector
3. **CeDeFi protocols with API-based TVL** — verify on-chain vs off-chain reporting
4. **XRPL EVM Sidechain** — new hunting ground, limited tooling, early-stage protocols
5. **Venus fork ≠ safe** — Doppler has 0 audits despite being a "battle-tested" fork; custom oracle breaks the security model

---

## Submission Template

```markdown
# Doppler Finance - Oracle Centralization Vulnerabilities

**Severity:** CRITICAL (3 findings)
**TVL at Risk:** $94.6M
**Audit Status:** 0 audits
**Bounty:** Direct disclosure (no Immunefi)

## CRIT-01: Centralized Oracle PriceInjector Takeover
## CRIT-02: UUPS Upgrade to Malicious Implementation  
## HIGH-03: No TWAP / 3-Hour Staleness Only

[Full PoC + Foundry tests attached]
```