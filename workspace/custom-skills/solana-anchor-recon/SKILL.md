
# Solana Anchor Program Recon

Systematic reverse-engineering of Anchor-based Solana programs (launchpads, DEXs, staking, DeFi protocols) starting from just the frontend URL. Produces a full attack surface map (instructions, accounts, PDAs, admin model, RPC whitelist) with **zero SOL spent** — critical when devnet airdrops are rate-limited.

## Triggers
- Bug bounty target is a Solana dApp with a public frontend (Next.js/React common)
- Target uses Anchor framework (visible via `AnchorProvider` / `@coral-xyz/anchor` in bundle)
- You need instruction/account/PDA enumeration before writing exploits
- IDL is not published on-chain (common for production programs)

## Core Recon Pipeline

### 1. Program ID discovery
Frontend hydrates a program client — Program ID is in the bundle. Download all `/_next/static/chunks/*.js`, grep base58 candidates 32–44 chars, then classify each via `getAccountInfo`:

```bash
mkdir -p js
curl -sL https://TARGET/ -o index.html
grep -oE '/_next/static/[^"]+\.js' index.html | \
  xargs -I{} -P8 sh -c 'curl -sL "https://TARGET{}" -o "js/$(basename {})"'
cat js/*.js | grep -oE '\b[1-9A-HJ-NP-Za-km-z]{32,44}\b' | sort -u > candidates.txt
```

Classify each candidate:
- `owner=BPFLoaderUpgradeab1e...`, `executable=true` → **Program** (target!)
- `owner=AddressLookupTab1e...` → **ALT** — mine the addresses INSIDE it (ecosystem map)
- `owner=<program_id>` → PDA owned by program (GlobalConfig, treasury, keeper)
- `lamports>0` on system-owned → **treasury wallet**

Vanity prefixes (e.g. `popi...`) usually mark project-owned accounts — grep them first.

### 2. IDL extraction

**Try on-chain first:**
```python
from solders.pubkey import Pubkey
PROG = Pubkey.from_string("<PROGRAM_ID>")
base_pda, _ = Pubkey.find_program_address([], PROG)
idl_addr = Pubkey.create_with_seed(base_pda, "anchor:idl", PROG)
# Fetch getAccountInfo(idl_addr). If exists:
# Layout: 8 disc + 32 authority + 4 data_len + zlib-compressed JSON
```

**If not on-chain (common), extract from JS bundle:**
See `scripts/extract_idl_from_bundle.py`. The IDL is embedded as a `JSON.parse('...')` call in one of the chunks — literal is a JS single-quoted string with `\"` escapes. Unescape via `content.encode().decode('unicode_escape')` before `json.loads`.

**Vite/SPA variant (TurboFlow 2026-09):** the IDL may be a **bare JS array literal**, not `JSON.parse('...')`. The entry chunk (`/assets/main-*.js`) lazy-imports ~100+ `assets/<name>-<hash>.js` chunks — download them ALL first, then locate `instructions:[` / `discriminator:[`. The IDL sits as an unquoted object-literal array (e.g. `Ys=[{name:"deposit_native",discriminator:[13,158,...],accounts:[...],args:[...]},...]`) — those `discriminator` byte arrays ARE the Anchor hashes, so read them straight off. Extract with a **char-walk bracket matcher** (count `[`/`]`, skipping `"`/`'` string spans) rather than regex. `scripts/extract_idl_from_bundle.py` handles the `JSON.parse` form; write a ~15-line Node walker for the array-literal form.

**The bundle often carries the WHOLE multi-chain map, not just Solana:** the same chunk held the program per-env map (`{dev:…,uat:…,prod:"HwWQZ…"}`), the EVM bridge ABI, and the EVM per-chain address map (`Us={56:"0x…",1:"0x…"}`). Grep `[0-9]{1,7}:"0x[a-fA-F0-9]{40}"` and `dev:`/`uat:`/`prod:` maps — a "Solana perps" frontend can be fronting a cross-chain bridge. Full recipe: `references/turboflow-svm-bridge-recon-2026-09.md`.

**Manual char-walk when the regex misses it (popi.wtf, 2026-08):** for `s=JSON.parse('{...}')` where the payload has nested quotes/escapes, walk from `find("JSON.parse('", <skip webpack module header ~180>)`, respecting `\\` escapes, stop at the unescaped closing `'`, then `raw.encode('utf-8').decode('unicode_escape')` → `json.loads`. `idl['address']` = program ID; `idl['metadata']['name']`/`['version']` name it. Confirm live: `getAccountInfo(program, dataSlice len=0)` → owner `BPFLoaderUpgradeab1e…` + executable=true. Full recipe + a real 35-ix / 9-account / 106-error launchpad attack-surface map in `references/popi-wtf-popilaunch-recon-2026-08.md`.

**Pitfall — SPA `.well-known/security.txt` returns 200 HTML:** on Next.js/Vercel apps, `/.well-known/security.txt` yields the app's 200 HTML shell, not a disclosure file. Don't read a 200 as "security.txt exists" — check the body/content-type. Absent security.txt + private/404 GitHub org = no declared disclosure path; get scope + bounty/reward confirmation from the team (Twitter/Discord) BEFORE writing any report.

Yields: 20-100 instructions, N account types, N error codes (each error = one invariant to break), events, and full type definitions.

### 3. Anchor discriminators (needed for tx construction + account filtering)

```python
import hashlib
ix_disc  = hashlib.sha256(b"global:instruction_name").digest()[:8]
acc_disc = hashlib.sha256(b"account:AccountName").digest()[:8]
```

See `scripts/anchor_discriminator.py`.

### 4. Enumerate all program accounts by type

```bash
# Get all Launch accounts via memcmp filter on discriminator
DISC_B58=$(python3 -c "import base58; print(base58.b58encode(bytes.fromhex('<HEX>')).decode())")
curl -X POST https://api.devnet.solana.com -H "Content-Type: application/json" -d @- <<EOF
{"jsonrpc":"2.0","id":1,"method":"getProgramAccounts",
 "params":["<PROGRAM>",{
   "encoding":"base64",
   "dataSlice":{"offset":0,"length":8},
   "filters":[{"memcmp":{"offset":0,"bytes":"$DISC_B58"}}]
 }]}
EOF
```

Use `dataSlice` to keep response small when just enumerating pubkeys; drop it when fetching full data.

### 5. Borsh-decode accounts
See `scripts/borsh_reader.py`. Field order matches the IDL. First 8 bytes = discriminator, rest = borsh-serialized struct.

**Schema evolution detection:** decode 100+ accounts. If some fail with the current IDL, group failures by data length:
- Failure size > success size → legacy schema (fields were removed)
- Failure size < success size → newer schema (fields were added; program was upgraded but old accounts not migrated)
- Ghost accounts (garbage after discriminator) → failed-init or deploy leftover

Legacy accounts are potential **DoS/griefing bugs** if the program ever reads them in a shared code path.

### 6. Admin auth probing (ZERO SOL, via simulateTransaction)

This is the highest-payout technique in this skill. Test whether admin-only instructions can be executed by an unauthorized signer:

```python
# 1. Find a whale wallet from tx history of the program (has SOL, so tx doesn't fail on fee)
# 2. Build the admin ix with:
#    - fee_payer = whale
#    - "admin"/"authority" signer position = ATTACKER pubkey (not real admin)
#    - all other PDAs derived normally
# 3. Simulate with sigVerify=false — bypasses the fact that neither whale nor attacker signed

curl -X POST https://TARGET/api/rpc -H "Content-Type: application/json" -d '{
  "jsonrpc":"2.0","id":1,"method":"simulateTransaction",
  "params":[TX_B64, {"encoding":"base64","sigVerify":false,"replaceRecentBlockhash":true}]
}'
```

Expected: `Custom: 6039` (or similar Unauthorized). Auth check works.
**BUG if simulation succeeds → P1 CRITICAL** ($1k–$2k typical for launchpads).

Anchor built-in errors also fire before your custom errors — see `references/anchor-error-codes.md`.

### 7. RPC proxy whitelist enumeration
Most launchpads run their own `/api/rpc` proxy. `simulateTransaction` is almost always allowed (needed by frontend for previews) — gives you a **free tx probe channel through the target's own infra**. Enumerate:

```bash
for m in getBalance sendTransaction requestAirdrop simulateTransaction \
         getAccountInfo getProgramAccounts getVersion getIdentity; do
  echo -n "$m: "
  curl -s -X POST https://TARGET/api/rpc -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$m\"}" | jq -r '.error.message // "ALLOWED"'
done
```

`method not allowed: X` responses give you the exact blocklist.

## No source? Decompile the SBF binary

When the target is deployed + upgradeable but source is private (no GitHub, no on-chain IDL,
code-search blocked), escalate to binary RE. Dump the ProgramData account, base64-decode, strip the
~45-byte header, **md5 it against your local `.so`** to confirm you hold the LIVE bytecode, then:

1. **Ghidra with the eBPF processor (`eBPF:LE:64:default`) decompiles SBF ELF** — this is the unlock
   (688 KB `.so` → ~65 k lines of C). radare2 default builds usually lack the BPF plugin; don't rely on it.
   Run `scripts/sbf_ghidra_decompile.sh` (headless; postScript MUST be a `.java`, not Jython).
2. `llvm-objdump` disasm labels are **decimal** and `byte = label*8` — calibrate against `.text` before
   trusting any address.
3. Locate the **Anchor dispatch table** by scanning the disasm for consecutive `sha256("global:name")[:8]`
   immediates — that maps discriminator → handler. **Match with `& (2**64-1)`**: Ghidra prints any
   discriminator ≥ `0x8000…` as a *negated* negative literal (`-0x1a5c…`), so without the mask ~half the
   instructions silently fail to match (looks like "only 9 ix"). Two entries are Anchor **IDL builtins**,
   not project ix. Full recipe: `references/sbf-binary-reverse-engineering.md` §3.
4. **Recover the whole instruction enum from Rust debug strings — before decompiling.** 
   `strings -n 6 prog.so | grep -oE "[A-Z][A-Za-z0-9]+Instruction" | sort -u` (and the concatenated
   `Instruction: FooInstruction: Bar…` log blob) leaks every instruction variant even when the client
   IDL hides some (TurboFlow 2026-09: 18 on-chain vs 11 in the IDL — exposed the whole hidden
   risk/whitelist layer for free). Also grep `-oE "/[A-Za-z0-9._/-]+\.rs"` for the source tree.
5. Dump **custom error strings** (`strings | grep` for `invalid|must|reject|exceed|unauthor|paused`) — each
   project-authored message is an invariant that EXISTS; a check you expected but can't find is the lead.

Full recipe, pitfalls, and the fast falsification tests: `references/sbf-binary-reverse-engineering.md`.

## Priority Attack Vectors (after recon)

Order these by expected payout / effort:

1. **Admin auth bypass** — cheap to test, P1 payout
2. **VRF grinding** — commit-reveal windows in gacha/lottery/RNG
3. **Merkle proof forge** — client-supplied `_commitment` fields (verify hash + domain sep)
4. **Fee bucket off-by-one** — tiered fees (`<1000, 1000-1999, 2000-2999, 3000+` pattern is common)
5. **Fair vs bundle branch** — different fee splits for launch types = flag encoding bugs
6. **Migration race** — dev-fee-claim vs graduate ordering, `AlreadyMigrated` guards
7. **Legacy schema DoS** — old accounts causing panics in read paths
8. **Vanity mint bypass** — case sensitivity, unicode confusables, suffix vs full match
9. **Metadata URI XSS/SSRF** — `image` field in IPFS metadata JSON, `javascript:` URIs

## Pitfalls

- **Bundled IDL can be STALE — newer OR older than the DEPLOYED program.** The deployed program is the source of truth. Symptom: your `sha256("global:name")` discriminator hits an Anchor fallback (`InstructionFallbackNotFound`) on-chain even though the IDL "matches". Fix: pull a real tx (`getSignaturesForAddress` → `getTransaction`) and read `Program log: Instruction: <CamelCaseName>` — the logs name the instructions the DEPLOYED version actually has (TurboFlow 2026-09: bundle IDL listed `ReviewToken`, deployed had `ReviewTokenSolV1` + `InitRiskConfig`/`Whitelist` the bundle lacked). Never trust the bundle IDL for discriminators; verify against tx logs or on-chain IDL.
- **PDA derivation without the Anchor CLI:** `from solders.pubkey import Pubkey; pda,_ = Pubkey.find_program_address([b"role_data"], PROG)`. Borsh-decode the result to enumerate role members — if every member is a system-owned EOA (owner `1111…1111`), that's a single-key **centralization** note, not a bug; don't inflate it.
- **Devnet airdrop is rate-limited PER-WALLET, not per-IP.** Rotating proxies won't help. Make a fresh keypair or wait ~24h. Free wallet is free but airdrop endpoint tracks the destination address.
- **`AccountNotFound` on simulate** means fee_payer is empty. Use a whale wallet as fee_payer — `sigVerify=false` bypasses the "did whale sign?" check.
- **IDL from JS bundle uses `JSON.parse('...')` with `\"` escapes** — parse the JS-string first (`unicode_escape`), then `json.loads`. Failing to unescape leaves you with `\"key\":\"val\"` which is invalid JSON.
- **Anchor error codes** in tx logs are `Custom: N` in decimal, but the message says `custom program error: 0x1776` in hex. `0x1770 = 6000` is the first user-defined error. Anchor built-ins (100-3999) fire before yours.
- **Anchor prints Left/Right pubkey on `assert_eq!` failure** — leaks the expected admin. Also leaks source file paths (e.g. `programs/foo/src/instructions/bar.rs:34`) which is a bonus tree map.
- **Address Lookup Tables (ALT)**: header is 56 bytes, then 32-byte addresses. Parse authority_option byte (offset 17) — 0 means FROZEN (immutable).
- **Vanity prefix at END of pubkey** (e.g. `9JcjgedfxjcdR2DWV6zj1gyHrQNy1jozMbyDA851popi`) is often a mint-address suffix requirement enforced by the program (`InvalidMintSuffix` error). Test bypass: case, unicode.
- **Frontend SSR (Next.js/React) escapes text nodes properly** — `<img>` in launch name becomes `&lt;img&gt;`. Don't waste time on `name`/`symbol` XSS via SSR. Focus on `href={uri}` sinks and client-side `dangerouslySetInnerHTML` on user-controlled metadata JSON.
- **imgproxy signed URLs** are typically tight — signature covers full URL. Tampering returns 403 immediately. Skip unless you find a plaintext/insecure prefix leak.
- **Falsify a "missing check" hypothesis CHEAPLY before deep RE.** Before grinding a handler in the decompiler, run two decisive tests: (a) grep the decompiled body for the **PDA seed literals** the check would need — if `review_token` references the `risk_config` seed 3×, the check is present (TurboFlow 2026-09: killed the "review_token skips risk check" hypothesis); (b) compare **IDL account lists** — an ix with 9 accounts and no `risk_config`/`whitelist_entry` accounts physically cannot run that check. Two identical failed deep-dives = you skipped this.
- **Verify claims against the IDL account list, not memory.** TurboFlow 2026-09: an earlier note claimed `set_contract_status` lacked `role_data` (→ auth bypass); the IDL account list INCLUDES `role_data` → role-gated → false positive. Re-read the extracted IDL before writing any finding.
- **Frontend bundles leak more than the program ID** — grep for `helius-rpc.com` / `ankr.com` / `quiknode` RPC endpoints and POST `getHealth`/`getVersion` unauthenticated to prove a live leaked endpoint (cost/DoS + quota abuse), and grep emails for PII. These are reportable LOW/INFO findings that don't need source access.
- **Liveness-test EVERY leaked key before writing it up.** A key in a bundle is not a finding until it works. TurboFlow 2026-09: the leaked Ankr key returned `401 API key not found` → DEAD → dropped. Same for suspicious hex: 32-byte `0x…` constants in a bundle are usually **elliptic-curve constants** (secp256k1 / P-256), not private keys — verify before claiming key leakage.
- **Run all BB recon/RE/probing on the REMOTE audit host, not the workstation.** User directive (*"Jangan di lokal"*). Local disk is near-full; the VPS has the toolchain (`/root/.foundry/bin`, `/root/.local/bin`, jadx/apktool, Ghidra) and the network. SSH the analysis over; only the final report/PDF build stays local (Hermes venv `weasyprint`). Never run target scans from the laptop.
- **Know when to stop deep RE (deficit awareness).** SBF handler bodies decompile to Anchor entrypoint wrappers, not readable logic; ~65k lines of pseudocode for zero confirmed bugs is diminishing returns. After the cheap falsification tests, if nothing confirms, consolidate and report honestly (no severity inflation) rather than grinding on.

## Verification checklist
- [ ] Program ID confirmed executable + BPFLoaderUpgradeable owned
- [ ] Upgrade authority identified from ProgramData PDA (`.parsed.info.authority`)
- [ ] IDL extracted, `len(instructions) > 0`
- [ ] Discriminators computed and match what appears in real tx data
- [ ] At least 100 accounts of the main type decoded
- [ ] Admin ix probe returns Unauthorized (6039 or similar) → auth solid
- [ ] RPC proxy whitelist mapped (which methods allowed vs blocked)
- [ ] Ecosystem addresses from ALT identified and classified

## Files
- `scripts/extract_idl_from_bundle.py` — pull Anchor IDL from Next.js JS bundle
- `scripts/borsh_reader.py` — minimal Borsh decoder for Anchor accounts
- `scripts/anchor_discriminator.py` — compute ix/account discriminators
- `references/anchor-error-codes.md` — Anchor built-in error codes + how to read them from logs
- `references/rpc-proxy-methods.md` — which RPC methods hardened proxies typically allow/block
- `references/turboflow-svm-bridge-recon-2026-09.md` — Vite-bundle IDL-from-array-literal recipe, cross-chain map extraction (Solana program + BSC/ETH proxy from one bundle), stale-bundle-IDL vs deployed-program pitfall, role-member EOA enumeration, zero-SOL triage of a live cross-chain bridge
- `references/sbf-binary-reverse-engineering.md` — **when source is private:** md5-verify the deployed `.so`, Ghidra eBPF decompile, `label*8` disasm scheme, Anchor dispatch-table location, Rust `&str` xref mapping, custom-error invariant inventory, and the FAST seed-string / account-list falsification tests
- `scripts/sbf_ghidra_decompile.sh` + `scripts/DumpDecomp.java` — headless Ghidra eBPF decompile of a stripped SBF program to `decomp_all.c`
