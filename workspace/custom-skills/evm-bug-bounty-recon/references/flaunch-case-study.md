# Flaunch.gg — Case Study (2026-07-16)

## Target Profile
- **Protocol:** flaunch Protocol (memecoin launch platform)
- **Chain:** Base (Optimism Superchain)
- **TVL:** Unknown (early stage)
- **Source:** `flaunchgg/flaunchgg-contracts` (GitHub, 69 stars)
- **Audit:** NONE FOUND in repo
- **Web:** `flaunch.gg` (Vercel, Next.js), `legacy.flaunch.gg` (CF), `dev.flaunch.gg` (Vercel, active)

## Smart Contract Findings

### CRIT-01: Cross-Chain Implementation Swap
**Contract:** `Flaunch.sol` lines 225-228, 333-386, 395-407
**Bug:** `setMemecoinImplementation()` changes deployed code while token is mid-bridge.
Token on destination chain uses NEW implementation, not the one active at bridge initiation.
No per-tokenId version lock. Bridge window = 1 hour (MAX_BRIDGING_WINDOW).
**Bounty estimate:** $25K-$75K

### CRIT-01 Foundry PoC — VERIFIED (2026-07-16)

**File:** `/home/ubuntu/flaunchgg-contracts/test/poc/CRIT01_ImplementationSwap.t.sol`
**Result:** 3/3 tests PASSED

```
[PASS] test_CRIT01_ImplementationSwapAttack() — Full attack flow
[PASS] test_CRIT01_NoVersionLock() — All tokens share single impl slot
[PASS] test_CRIT01_BridgeWindowAttack() — 1-hour window allows swap
```

**Attack demonstration:**
- MaliciousImpl mints 10% bonus to attacker on every `mint()`
- MaliciousImpl steals 5% on every `transfer()`
- Verified: user balance 1000, attacker balance 100 (10%), total supply 1100

**Report:** `/home/ubuntu/flaunchgg-contracts/test/poc/REPORT_CRIT01.md`

### CRIT-02: BidWall Treasury Drain
**Contract:** `BidWall.sol` lines 372-425
**Bug:** `closeBidWall()` sends ALL accumulated fees + liquidity to `memecoinTreasury` with no verification treasury is legitimate. No timelock, no withdrawal cap.
**Bounty estimate:** $10K-$25K

### CRIT-03: Treasury Implementation Swap
**Contract:** `Flaunch.sol` line 235
**Bug:** Same pattern as CRIT-01 — treasury implementation can be swapped mid-bridge.
**Bounty estimate:** $10K-$25K (combined with CRIT-01 = $50K-$100K)

### HIGH-01: NFT-Based Creator Backdoor
**Contract:** `Memecoin.sol` lines 177-185
**Bug:** `creator()` reads `flaunch.ownerOf(tokenId)` — changes on NFT transfer. Buyer gains admin rights retroactively.
**Bounty estimate:** $5K-$15K

## Web Recon Findings

### WEB-01: legacy.flaunch.gg Active
**URL:** `https://legacy.flaunch.gg` (redirect from `app.flaunch.gg`)
**Title:** "Flaunch — Withdraw"
**Content:** Withdrawal portal for deprecated group stakes, ConnectButton + GroupList components.
**Status:** ACTIVE, users can still withdraw old staked tokens.
**Risk:** Old contracts still connected, potential unmaintained attack surface.

### WEB-02: dev.flaunch.gg Exposed
**URL:** `https://dev.flaunch.gg` (200 OK)
**Status:** ACTIVE with "Plugins are live" announcement banner — NEWER version than prod.
**Meta:** `robots: noindex` — intentionally hidden from search engines.
**Risk:** Dev env may have weaker config, debug endpoints, newer/untested code.

### WEB-03: JS Bundle Contract Extraction
Found 10+ contract addresses in legacy JS chunks including:
`0xb15aee5..., 0x787b7b71..., 0x18207136..., 0x88fbb146..., 0xa18fa303..., 0xfca9fc2c...`

## Authorization Bypass Test (FeeEscrow)
**Contract:** `FeeEscrow.sol` → `withdrawFees(msg.sender, _recipient)`
**Verdict:** SAFE — only msg.sender's OWN balance withdrawable. No outsider theft possible.
`_recipient` can differ from sender = legitimate feature (send to different wallet).

## Foundry PoC Pitfalls (LibClone / Minimal Proxy)

1. **Constructors don't run on clones.** `LibClone.cloneDeterministic()` creates EIP-1167 minimal proxies. State set in constructor stays at zero. FIX: set attacker/state in `initialize()` instead.

2. **`predictDeterministicAddress` needs 3 args.** `LibClone.predictDeterministicAddress(impl, salt, deployer)` — NOT 2 args. Missing deployer = compile error.

3. **Unicode in Solidity strings = compile error.** `emit log("...")` fails with `Invalid character in string`. FIX: use ASCII only — `[OK]`, `[!!]`, `===`.

4. **CREATE2 address changes with implementation.** After `setMemecoinImplementation()`, `predictDeterministicAddress()` returns a DIFFERENT address because impl is part of the hash. Must re-predict after swap.

5. **`mint()` requires `msg.sender == flaunch`.** In PoC, test contract can't call mint directly. FIX: route through mock contract (`mintToken()` / `mintTokenAt()` helpers), or use `vm.prank()`.

6. **Transfer requires token holder.** `vm.prank(user)` before transfer to impersonate holder.

## Key Lessons
1. **No audit = high novel-bug probability.** Flaunch far better ROI than Gravita.
2. **New protocol class = new attack surfaces.** Cross-chain bridge + NFT-based auth = unique bugs.
3. **Dev/legacy subdomains = recon gold.** dev.flaunch.gg had banner not on prod; legacy.flaunch.gg is live withdrawal portal.
4. **Web3 dApps rarely have traditional admin panels.** Auth via wallet signature; admin functions on-chain.
5. **"Bisa withdraw ga?" test requires Foundry PoC.** Static analysis can identify bug, but exploitability proof needs chain fork.
6. **FeeEscrow pattern:** `balances[msg.sender]` determines withdrawable amount, `_recipient` determines destination. Separate = legitimate, not auth bypass.
7. **Authorization bypass check workflow:** For every withdrawal/claim function, trace (a) who can call it, (b) what balance is checked, (c) where funds go. `msg.sender` controls ALL THREE in well-written contracts. Separate recipient param is not a bug — it's a feature.
8. **User may push hard for mainnet exploit — HOLD THE LINE.** Offer Foundry PoC simulation only. Channel into white hat bounty path.
9. **No PK leak found despite aggressive scan.** Flaunch team OPSEC is solid.

## Files Produced
- `/home/ubuntu/flaunchgg-contracts/test/poc/CRIT01_ImplementationSwap.t.sol` — Foundry PoC (3/3 PASS)
- `/home/ubuntu/flaunchgg-contracts/test/poc/REPORT_CRIT01.md` — Formal report
- `/tmp/flaunch_audit.md` — full findings report
- `/tmp/flaunchgg-contracts/` — dev branch clone