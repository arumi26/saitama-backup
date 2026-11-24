# popi.wtf — popilaunch Solana Anchor Recon (2026-08)

## Target
- **Frontend:** https://popi.wtf — "PvP gacha launchpad for memecoins" (Next.js, Cloudflare + Caddy, multi-chain SOL + custom "ROBIN" EVM chain)
- **Program ID:** `BNtfydNwzthyGfH1LMxt5AzQkJo7iyfGFbjjNKuHFH6M` — confirmed live Solana mainnet (owner `BPFLoaderUpgradeab1e…`, executable=true)
- **IDL:** `popilaunch` v0.1.0 — 35 instructions, 9 accounts (48 event types), 106 errors
- **RNG:** ORAO VRF (`VRFzZoJdhFWL8rkvu87LpKM3RbcVezpMEc6X5GVDr7y`)
- **No security.txt, no public GitHub org (`popiwtf` 404).** Disclosure contacts: Twitter @popiwtf + Discord. No bounty program page confirmed — clarify scope/reward tier with the target before writing reports.

## IDL extraction — this app uses `JSON.parse('...')`, NOT an object literal
The full Anchor IDL is embedded in chunk `9733-*.js` as `s=JSON.parse('{"address":"BNtfy…","metadata":{"name":"popilaunch"…}')`. The `extract_idl_from_bundle.py` regex that looks for object literals misses it. Working extraction:
```python
data = open('9733-*.js').read()
start = data.find("JSON.parse('", 180)          # skip the webpack module header
i = start + len("JSON.parse('"); buf=[]
while i < len(data):
    c = data[i]
    if c == '\\': buf.append(data[i:i+2]); i+=2; continue
    if c == "'": break
    buf.append(c); i+=1
raw = ''.join(buf)
idl = json.loads(raw.encode('utf-8').decode('unicode_escape'))  # unescape JS string FIRST
```
- The `.well-known/security.txt` path on a Next.js SPA returns the **200 HTML shell** (not a real security.txt) — don't mistake it for a disclosure file. Confirm by content-type/`404` body text.
- `/api/*` endpoints found in bundle: `/api/rpc`, `/api/rpc-ws`, `/api/robin-rpc`, `/api/robin-ws`, `/api/arc-amm`, `/api/robin-amm`, `/api/{robin,arc}-idx`, `/api/auth/{nonce,verify,me,mode,logout}`. The `/api/rpc` proxy is the free tx-probe channel (see main skill §7).

## Attack surface map (106 errors = 106 invariants)
Mechanic: `create_launch` → `buy_slot`/`confirm_bump` (bonding curve) → `spin`/`open_gacha`/`resolve_spin`/`cancel_spin` (gacha via VRF) → `commit_lottery`/`roll_jackpot`/`admin_lottery` (lottery) → `migrate`/graduate → `claim_*`/`close_failed_launch`.

Priority vectors (EV order):
1. **VRF commit-reveal grinding** — `spin`/`resolve_spin`/`cancel_spin`; errors `RandomnessNotReady`(6002), `WrongRandomnessAccount`(6013), `InvalidSpinState`(6032). Can attacker cancel-retry until a favorable seed, or does `cancel_spin` burn the commit? Check `spin_count` ∈ {1,5,10,15,25} (6030) fee scaling.
2. **Per-wallet cap bypass** — `ExceedsMaxPerWallet`(6014): 3% supply via buy_slot/confirm_bump, 20% dev bundle in create_launch. Multi-slot / multi-wallet sybil?
3. **Lottery commit race** — `LotteryAlreadyCommitted`(6028) + `reset_lottery_snapshot` retry loop; `commit_lottery`/`roll_jackpot` ordering vs `MigrationNotCompleted`(6024)/`LotteryWindowNotOpen`(6023).
4. **Refund/claim double-spend** — `claim_refund`/`claim_excess`/`claim_tokens`/`claim_dev_*`; `AlreadyClaimedTokens`(6017), `RefundsIncomplete`(6037), `DevRefundIncomplete`(6038), `VaultUnderfunded`(6035), `close_failed_launch` vs `force_close_failed_launch_after_timeout`.
5. **Admin auth probe (ZERO SOL)** — 15 admin ix (`set_admin`, `set_fee_config`, `claim_dev_fees`, `admin_lottery`, `set_keeper`, `rotate_fee_recipient`, `set_split_config`). Simulate each with attacker in the authority signer slot + `sigVerify=false` via `/api/rpc`. Expected `Custom:6039 Unauthorized` / `6029 UnauthorizedLottery` / `6034 InvalidAuthority`. Any simulate SUCCESS = P1.
6. **SelfBump**(6020) / stale victim pick — `VictimSlotNotFound`(6031), `InvalidVictimSlot`(6019), `WrongVictim`(6004): PvP bump mechanic, check victim-slot PDA validation can't be spoofed.
7. **`NoCPI`(6006)** guard — confirm which ix are CPI-guarded and whether any value-moving ix is reachable via CPI trampoline.

## Full error table
106 errors 6000–6039+ extracted to `idl.json`. Key economic guards: `SlippageExceeded`(6001), `ArithmeticOverflow`(6015), `BelowMinBuy`(6010), `InvalidSlot`/BLOCK_BUY_GAP(6009), bonding durations {10,15,30,60}min (6021), gacha durations {1,5,30,45,60}min (6022).
