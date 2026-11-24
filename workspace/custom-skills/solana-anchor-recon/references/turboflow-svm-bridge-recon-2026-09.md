# TurboFlow / svm-bridge — cross-chain recon from ONE Vite bundle (2026-09)

Zero-SOL recon of a live cross-chain bridge. **No critical found** — this is a worked example of the
*extraction + honest triage* pipeline, not a bug writeup.

## Target shape
- **TurboFlow** (`tf.xyz`) — Telegram Mini App + Android APK (`one.surf.protocol.prod` v1.0.3, 178MB).
  Marketed as Solana perps / "event contracts"; actually fronts a **cross-chain bridge** (`svm-bridge`).
- API `apis.tf.xyz`; staging `sit-api` / `api` / `uat.turboflow-test.xyz` (public).
- Auth: Telegram `initData` → **Privy** embedded wallet (`pf:"privy", method:"telegram"`) → backend
  token `r_*` + `UID` header + `Biz-pf: 6`.

## Step 1 — Vite bundle, not Next.js
`https://tf.xyz/assets/main-<hash>.js` lazy-imports **114** `assets/<name>-<hash>.js` chunks. Download
ALL (they're small), then grep. Names leak intent: `config-*.js`,
`use-privy-embedded-solana-wallet-*.js`, `whitelistTypes-*.js`.

## Step 2 — IDL as a BARE ARRAY LITERAL (not `JSON.parse`)
The Anchor IDL lived in `index-<hash>.js` as an unquoted JS array assigned to a minified var:
`Ys=[{name:"deposit_native",discriminator:[13,158,13,223,95,213,28,6],accounts:[...],args:[...]},...]`.
- Regex fails on this; write a **char-walk bracket matcher** (count `[`/`]`, skip `"`/`'` string spans).
- The `discriminator` byte arrays ARE the Anchor hashes — read them directly, no need to recompute.
- `idl['metadata']['name']` = `svm_bridge`, version `0.1.0`.

## Step 3 — the same bundle carried the EVM side
- Program per-env map: `{dev:"HUBwJRGV…", uat:"ERi8LesM…", prod:"HwWQZdX116omFGrygkpng7fTzMbrg6JGpLaoM77cM7vg"}`.
- EVM bridge ABI array + per-chain address map: `Us={56:"0x145CD0d5C3dD0eF1405dCf1b4D2BCE7c611625dB", 1:"…"}`.
- Leaked an **Ankr RPC key**: `rpc.ankr.com/solana/48c5329b…` (in `config-*.js`).
  → **CORRECTION (verified later): this key is DEAD** — `POST rpc.ankr.com/solana/<key>` returns
  `401 API key not found`. Do NOT report it. Always liveness-test a leaked key before writing it up.
→ Lesson: a "Solana dApp" can front an EVM bridge. Grep `{[0-9]{1,7}:"0x[a-fA-F0-9]{40}"}` too.

## Step 4 — on-chain map (Solana)
| Item | Value |
|---|---|
| Program (prod) | `HwWQZdX116omFGrygkpng7fTzMbrg6JGpLaoM77cM7vg` (upgradeable, 688KB) |
| ProgramData | `7jn8SF6uUubRsLQP1FHbzzRnQhFAUMFSiw9B6TQN34iC` |
| Upgrade authority | `HJbtKYPEum9bMVorEs8DEJUXLXv5XCi3mYuzJ45bYCxK` (**single keypair**, account absent on-chain) |
| BridgeAccount | `2WpgSwhTXohXDxxCMmdaKgdaiuD62H6XreDMvu3PykLS` |
| RoleData | `8BXB7nkesJEu8JwjrAkP7zMYaSzJ6pe8HLf9mbXLSG47` |
| transfer_authority | `8iquHJQyXUq8ykTEKZjtS4wSHKnxiw4ghGWUNzPnA9Q4` |

PDA derivation (no Anchor CLI needed):
```python
from solders.pubkey import Pubkey
pda, _ = Pubkey.find_program_address([b"role_data"], PROG)   # -> RoleData account
```
Borsh-decode → role members. All were **system-owned EOAs** (`owner=1111…1111`): DEFAULT_ADMIN,
PROPOSE, REVIEW, TOKEN_ADMIN. That's a **centralization Info**, not a bug.

## Step 5 — PITFALL: deployed program ≠ bundle IDL
`sha256("global:grant_role")[:8]` did NOT match on-chain → Anchor fallback error. The deployed program
was **newer** than the bundled IDL (it had `ReviewTokenSolV1`, `InitRiskConfig`, `Whitelist` the bundle
lacked). Authoritative instruction names came from real tx logs:
```python
# getSignaturesForAddress(PROG) -> getTransaction(sig) -> meta.logMessages
# "Program log: Instruction: DepositToken" / "ReviewToken" / "ProposeDeposit"
```
Live: deposit nonce ≈ **11,530** → bridge is real and active. Never trust the bundle for discriminators.

## Step 6 — EVM side (BSC + ETH)
| Item | Value |
|---|---|
| Proxy (OZ TransparentUpgradeableProxy) | `0x145CD0d5C3dD0eF1405dCf1b4D2BCE7c611625dB` |
| Impl (BSC) | `0xe4920f7fe76aa34a0c69d2e7aef78f4179c8f9bc` |
| Impl (ETH) | `0xA8Fa31388d7d9A02450A943f486BBEa3b4B60Bc1` (code identical) |
| ProxyAdmin | `0xcd43379650cfe58ff73a1db0bdfa2863cd8afbcb` → owner `0xec5641…5dfc` (**EOA**) |
| domainID / feeAddress | `53` / `0x59ec6d4c2aa1bb81e9b13e04a95f4d7f6a71ee90` |
| Roles | OZ AccessControl: `SUPER_ADMIN`, `NORMAL_ADMIN` |

**Uninitialized-impl probe:** `eth_call` `initialize(uint8,address,address)` **against the impl** →
no revert ⇒ impl uninitialized; proxy already init (`domainID()=0x35`). Transparent proxy ⇒ storage is
separate, no selfdestruct ⇒ **Low/Info** (hardening: `_disableInitializers()`). Do not inflate.

## Step 7 — honest triage (what was NOT reported as critical)
| # | Sev | Finding |
|---|---|---|
| F1 | Low/Info | Impl EVM uninitialized (transparent proxy ⇒ limited impact) |
| F2 | Info | Centralization: Solana upgrade authority = single keypair; ProxyAdmin owner = EOA; all bridge roles = EOA |
| F3 | Info | Bundle leaks staging hosts + full IDL/ABI. (The Ankr key in the same bundle is **DEAD** — `401`; do NOT report.) |
| F4 | Low | Public staging APIs reachable from the internet |

## Blockers (why no deeper audit)
- **Source not public:** impl unverified on Sourcify/Blockscout; BSCScan/Etherscan + Jina reader
  CF-blocked → bytecode RE needed.
- **Deployed program newer than IDL** → discriminators for the live version must come from tx logs.
- IDOR on `/account/*` needs a valid Privy token (can't forge without a bot token).

## Reusable takeaways
1. Vite SPA → enumerate `assets/*.js` chunks from the entry bundle, don't stop at `main-*.js`.
2. IDL may be an unquoted JS **array literal** — char-walk it, don't regex it.
3. One bundle can hand you BOTH chains (Solana program map + EVM ABI/address map).
4. Verify discriminators against **tx logs** before any on-chain call — the bundle IDL is often stale.
5. `solders` `Pubkey.find_program_address([b"seed"], PROG)` replaces the Anchor CLI for PDA work.
6. Read `Program log: Instruction: <Name>` for the deployed version's real instruction set.

---

## Follow-up session — source-less binary RE + falsification (2026-09)

Same target, escalated from recon to **reverse engineering the deployed `.so`** (no source anywhere).

### Confirmed live bytecode
Dumped ProgramData, stripped the header, md5 `c5fbe95668186f17027a43537cf2576a` == local `bridge.so`
⇒ auditing the deployed production program, not a stale copy.

### Decompile succeeded
`Ghidra` eBPF processor (`eBPF:LE:64:default`) → **65,132 lines / 2.4 MB** of C pseudocode.
radare2 on the box lacked the BPF plugin. Headless postScript had to be **`.java`** (PyGhidra), not `.py`.
Full method: `references/sbf-binary-reverse-engineering.md`.

### Dispatch table (18 ix, from disasm)
Found at ~`0x52240`; handlers spaced `0x58`, each a thunk into a large monomorphized body.
**Deployed has 18 instructions; the shipped client IDL exposes only 11.** Hidden 7:
`review_token_sol_v1`, `init_/update_/apply_risk_config`, `add_/remove_/apply_whitelist_entry`.

### Access model (on-chain)
BridgeAccount `bridge_admin` / `operator` / `allowed_program_id` all **default/unset** ⇒ authz is
entirely RoleData. Roles: DEFAULT_ADMIN(2), PROPOSE(2), REVIEW(2), TOKEN_ADMIN(1) — all system-owned EOAs
(centralization Info). Permissionless: `deposit_native` / `deposit_token` (role_data optional) — the
only externally reachable surface. `local_domain_id=52`, deposit nonce ≈ 11,537.

### Custom error inventory (validation EXISTS)
`strings -n 6 bridge.so | grep` → `Invalid token mint.` · `Invalid receiver.` · `Invalid amount.` ·
`Risk check rejected. reason <bitmap>` · `Risk config timelock not expired.` · `Bridge is not active.` ·
`Destination recipient address exceeds…`. Build paths leaked: `…/platform-tools/programs/svm-bridge/src/instructions/withdraw/{review_token,review_token_sol_v1}.rs`, `risk_admin.rs`, `states/risk_config.rs`.

### RULED OUT (triage — do NOT report)
- **O1 "review_token skips risk check" → REJECTED.** `review_token` (0x47ff0) references the `risk_config`
  PDA seed **3×** ⇒ risk check IS executed. The cheap seed-string test killed the hypothesis before deep RE.
- **O2/O3 "set_contract_status lacks role_data" → REJECTED.** IDL account list INCLUDES `role_data` ⇒
  role-gated. An earlier note got this wrong — always re-read the extracted IDL before writing a finding.

### Confirmed findings (no source needed)
| # | Sev | Finding |
|---|---|---|
| F1 | Low–Med | Frontend ships a **live unauthenticated Helius mainnet RPC**: `hulda-iojerh-fast-mainnet.helius-rpc.com` — `getHealth`→`ok`, `getVersion`→`solana-core 4.3.0-rc.1` (free access to paid quota; cost/DoS) |
| F4 | Info/PII | Personal email `M8ch88l@gmail.com` leaked in shipped JS |
| F2 | Info | Internal build paths leaked in binary (`platform-tools/programs/svm-bridge/src/...`) |
| F3 | Info | Undocumented risk/whitelist layer (18 on-chain ix vs 11 in client IDL) |

### Disclosure channel
No bounty platform → direct: `contacts@tf.xyz` · `x.com/TurboFlow_xyz` · `t.me/turboflow_xyz`.

### Blockers
Still no public source (on-chain Anchor IDL not published; GitHub repo `SatoshiVM/svm-bridge-contracts`
is README-only; GitHub code search needs auth; grep.app Vercel-blocked). Handler-level RE of `deposit_*`
converges slowly — the honest next step is a Solana-native decompiler or the source itself.

---

## Session 3 — full dispatch map + confirmed triage (2026-09)

**Run entirely on the remote audit host, not locally** (user directive: *"Jangan di lokal"*). All recon,
RE, and API probes go over SSH to the BB VPS; only the final PDF/report build is local (Hermes venv
`weasyprint`). Do not run scans from the workstation — treat the VPS as the analysis box.

### Dispatch table fully mapped (18 ix → handler)
Matched every dispatch constant to a name via `sha256("global:<ix>")[:8]` **with the `& (2**64-1)` mask**
(see `references/sbf-binary-reverse-engineering.md` §3). Full map recovered, e.g.:
`review_token→0x0006cf88`, `review_native→0x0006f520`, `deposit_token→0x0006c498`,
`propose_deposit→0x0006c8f0`, `init_risk_config→0x0006d968`, `update_risk_config→0x0006de90`,
`apply_risk_config→0x0006e9b0`, `add/remove_whitelist_entry→0x0006ebc0/0x0006f078`,
`apply_whitelist_entry→0x0006fac8`, `grant_role→0x0006a9e8`. Two extra entries (`FUN_00066b50`,
`FUN_0007ea30`) are Anchor **IDL builtins**, not project ix.

### Hidden instruction set confirmed from binary strings
`strings bridge.so | grep -oE "[A-Z][A-Za-z0-9]+Instruction"` recovered the **17-variant enum** absent
from the client IDL: `Initialize, GrantRole, RevokeRole, InitProposeChain, InitProposeToken,
SetContractStatus, DepositNative, DepositToken, ProposeDeposit, ReviewToken, ReviewTokenSolV1,
InitRiskConfig, UpdateRiskConfig, ApplyRiskConfig, AddWhitelistEntry, RemoveWhitelistEntry, ReviewNative`
(+ `ApplyWhitelistEntry`). Source tree + custom errors also recovered (see SBF ref §3b/§6).

### Triage corrections (do NOT report)
- **Ankr key `48c5329b…` → DEAD** (`401`). Dropped.
- **32-byte `0x…` hex constants in the bundle are elliptic-curve constants** (secp256k1 / P-256), **not
  private keys**. Do not report them as key leakage — verify before claiming.
- Handler-level RE of the SBF pseudocode (`decomp_all.c`, ~65k lines) is **diminishing returns** — the
  decompiled bodies are Anchor entrypoint wrappers, not readable handler logic. Stop after the cheap
  falsification tests (§7 of the SBF ref) unless you have a Solana-native decompiler.

### Final confirmed findings (unchanged severity — no inflation)
F1 Helius live RPC (Low–Med, *possibly by-design* — mark it honestly) · F2 Sentry DSN (Info, public by
design) · F3 personal email (Info). **No fund-loss bug confirmed.** Deliverable = MD + PDF via Telegram
`MEDIA:`; user sends the disclosure email themselves (no SMTP).
