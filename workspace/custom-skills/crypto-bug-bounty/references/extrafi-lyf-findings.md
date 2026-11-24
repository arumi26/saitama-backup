# ExtraFi LYF (Optimism) — Session Findings + Reusable Techniques

Target: Extra Finance, Immunefi (Smart-Contract-only scope), Optimism. Aave-fork lending +
leveraged-yield-farming (LYF). Source pulled keyless from Blockscout (`optimism.blockscout.com`).
2 prior audits (PeckShield, BlockSec) cross-checked — both extracted via `pdftotext -layout`.

## ⚠️ OUTCOME (later session, on-chain verified): Finding #1 = INFORMATIVE / mitigated. Do NOT submit.

The severity check this file demanded was RUN against live Optimism state (keyless public RPC)
and it **killed the finding**. Do not re-chase ExtraFi eToken inflation — the team already
mitigated it. Details:
- Queried all 82 reserves: `getETokenAddress(id)` → `totalSupply()` via keyless RPC.
- **~40 reserves have `totalSupply` == exactly `10000` wei** = deliberate dead-share seed on init
  = the standard first-depositor mitigation. Team is AWARE of this bug class.
- Seed math: to zero a 100k-token victim on a 10000-seeded reserve the attacker must donate
  ~1e9 tokens (**10,000× the victim deposit**) → economically absurd → **mitigated**.
- Only `reserveId=47` (token `RED`) had `totalSupply==0` (theoretically open) but it's a **dead
  reserve** — idle since Jul 2023, zero TVL, no realistic victim. Not a payable finding.
- Verdict: exploitability ~15%, triager would mark Informative/known. A local PoC being green
  proved the MATH, never the REACHABILITY. **PoC-green ≠ submittable.**

Reusable lesson: for any first-depositor/ERC4626-inflation finding, the go/no-go is a keyless
on-chain state sweep, NOT the local PoC. If every vault/reserve share-supply is a fixed small
constant, the team seeded dead shares → kill it. See the RPC snippet + seed math at the bottom.

## Finding #1 (PoC green on the MATH, but see OUTCOME above — mitigated on-chain): eToken first-depositor / donation inflation

**Class: ERC4626-style share inflation on a lending pool with no virtual shares + no zero-share revert.**

Root cause in `ReserveLogic.reserveToETokenExchangeRate()` + `LendingPool._deposit()`:
```solidity
availableLiquidity = IERC20(underlying).balanceOf(eTokenAddress)  // DONATABLE (raw balanceOf)
exchangeRate       = totalETokens * 1e18 / totalLiquidity          // no virtual shares/assets
eTokenAmount       = amount * exchangeRate / 1e18                   // NO require(eTokenAmount != 0)
```
Attack: attacker deposits 1 wei (rate 1e18 → 1 eToken) → **transfers underlying directly to the
eToken contract** to inflate `availableLiquidity` → victim's deposit floors to **0 shares** →
attacker holds 100% supply and redeems the whole pool incl. victim funds.

PoC (Foundry, ran GREEN on the 24GB box): victim deposited 100k, received **0 eTokens**;
attacker net profit == victim deposit. Root-cause + PoC harness pattern: deploy real
`LendingPool` + `AddressRegistry` (set `ADDRESS_ID_TREASURY=11`), `initReserve(asset)`, then
1-wei-seed → donate → victim deposit → attacker redeem. Mock underlying = 18-dec ERC20; WETH
placeholder is fine on the ERC20 path.

**Severity discipline — this is HIGH, not auto-Critical.** Precondition: only works on a
**fresh / not-yet-seeded reserve**. Live reserves (2023-era, real supply) are immune. `initReserve`
is `onlyOwner` and does NOT seed. So the exploit window = each new asset listing that the team
does not seed. To justify Critical you must prove on-chain that ExtraFi actually lists reserves
unseeded — otherwise report as High and state the precondition honestly. NOT in either audit
(cross-check of PeckShield + BlockSec for "first deposit / inflat / donation / exchange rate /
zero share" returned nothing) → non-duplicate.

## Finding #2 (candidate, reachability BLOCKED): repay() credit inflation

`LendingPool.repay()` does `credits[reserveId][msg.sender] += amount` **before** clamping
`amount = min(amount, borrowed)`. Over-repay (`amount > borrowed`) mints phantom borrowing
credit while only `borrowed` tokens move → free uncollateralized borrow power = pool theft.
BUT `repay()` is gated `require(borrowingWhiteList[msg.sender])` → only the ExtraFi vault
(VeloPositionManager) can call it. Reachability depends on whether that vault ever forwards
`amount > borrowed`. Could NOT confirm: the on-chain vault is **unverified** everywhere
(see technique below), and a 2-audit + 2023-live pool likely clamps upstream ⇒ treat as
probable false positive until the vault source is obtained. This is the credit-accounting
bug class already documented in SKILL.md's Phase 4 — the lesson here is the reachability wall.

## Reusable technique: find the real on-chain caller of a whitelisted fn via decoded event logs

When a bug is only reachable through a whitelisted caller you don't know, pull the contract's
decoded logs from Blockscout and read the event params — the caller address is right there:
```python
d = json.loads(curl(f"https://optimism.blockscout.com/api/v2/addresses/{LENDING_POOL}/logs"))
for it in d["items"]:
    dec = it.get("decoded")
    if dec and dec["method_call"].startswith("Repay"):   # Repay(reserveId, onBehalfOf, caller, amount)
        print({p["name"]: p["value"] for p in dec["parameters"]})  # caller = the vault addr
```
This surfaced the live VeloPositionManager address (reserveId 50, real TVL) in one call.

## Reachability dead-end: unverified caller contract kills the finding

The discovered vault was **unverified on every keyless source** — Blockscout (`source_code`
empty), Optimistic-Etherscan (Cloudflare "Just a moment…" block), Sourcify full+partial match
(both empty). Without the caller's source you cannot prove the over-repay path is reachable, so
the finding stays a candidate, not a submittable bug. Decision: don't claim it; either obtain
the source via a CF-bypass browser (cloakbrowser) or move on. Do NOT submit a "Critical" whose
reachability you can't demonstrate — PoC-first / claim-second still governs.

## Reusable technique: keyless on-chain state sweep to KILL/keep a share-inflation finding

Public Optimism RPCs answer `eth_call` with NO API key (`mainnet.optimism.io`,
`optimism.publicnode.com`, `optimism.drpc.org`, `1rpc.io/op`). Sweep every reserve's share
supply to decide severity — this is the go/no-go, not the local PoC:
```python
from Crypto.Hash import keccak
def selfn(sig):
    k=keccak.new(digest_bits=256); k.update(sig.encode()); return k.hexdigest()[:8]
def call(to,data):  # curl eth_call → result hex
    p=json.dumps({"jsonrpc":"2.0","method":"eth_call","params":[{"to":to,"data":data},"latest"],"id":1})
    return json.loads(curl_post(RPC,p)).get("result")
enc=lambda x: hex(x)[2:].rjust(64,"0")
# nextReserveId() → loop 1..N; getETokenAddress(id) → totalSupply()
for rid in range(1, int(call(LP,"0x"+selfn("nextReserveId()")),16)):
    et="0x"+call(LP,"0x"+selfn("getETokenAddress(uint256)")+enc(rid))[-40:]
    ts=int(call(et,"0x"+selfn("totalSupply()")) or "0x0",16)
    # ts == fixed small constant (e.g. 10000) across reserves ⇒ team seeded dead shares ⇒ MITIGATED
```
Read `reserves(uint256)` (public mapping getter) to decode a reserve's flags (isActive/frozen/
borrowingEnabled) + underlying token when you need to check if a `totalSupply==0` reserve is
actually live vs a dead/decommissioned one.

## CF-bypass to read an unverified/blocked contract on Etherscan (cloakbrowser)

`pip install cloakbrowser` (NOT `from cloakbrowser import CloakBrowser` — that class doesn't
exist). Use the module-level `launch()` which returns a Playwright Browser:
```python
import cloakbrowser
b = cloakbrowser.launch(headless=True)          # add humanize=True to pass tougher CF
ctx = b.new_context(); page = ctx.new_page()
page.goto("https://optimistic.etherscan.io/", wait_until="domcontentloaded", timeout=60000)
for _ in range(8):                              # spin until CF challenge clears (~7 iters/28s)
    page.wait_for_timeout(4000)
    if "Just a moment" not in page.title(): break
```
Each page nav is slow (CF revalidates); a 4-address batch blows past a 60s foreground timeout —
run it `terminal(background=True, notify_on_complete=True)`. Warm up CF once on the root domain,
then reuse the same page for subsequent `/address/{addr}#code` navigations.
