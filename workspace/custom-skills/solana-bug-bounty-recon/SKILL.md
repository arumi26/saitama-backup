
# Solana Bug Bounty Recon Workflow

Framework terbukti dari sesi `popi.wtf`. Recon-phase gak butuh SOL — semua lewat `simulateTransaction` dengan `sigVerify=false`.

## Phase 1 — Frontend Recon (30 min)

### 1.1 Fetch main HTML + JS bundles
```bash
mkdir -p target-recon/js && cd target-recon
curl -sL -A "Mozilla/5.0" https://TARGET/ -o index.html
grep -oE '/_next/static/[^"]+\.js' index.html | sort -u > js_bundles.txt
cat js_bundles.txt | xargs -I{} -P 8 sh -c 'curl -sL "https://TARGET{}" -o "js/$(basename {})"'
```

### 1.2 Hunt Program ID + ecosystem addresses
```bash
cat js/*.js | grep -oE '\b[1-9A-HJ-NP-Za-km-z]{32,44}\b' | sort -u
```
Vanity prefixes give hints: `popi...` = popi ALT, `pAMM...` = PumpSwap.

Verify each address via `getAccountInfo`. `executable=true` + owner `BPFLoaderUpgradeab1e...` = program. `data_len=760, owner=AddressLookupTab1e...` = ALT.

### 1.3 Extract Anchor IDL from JS bundle
Anchor apps embed IDL as `JSON.parse('...')` string literal:

```python
import json
with open('js/BUNDLE.js', encoding='utf-8', errors='replace') as f:
    content = f.read()
target = '"address":"PROGRAM_ID_HERE"'
idx = content.find(target)
parse_start = content.rfind('JSON.parse(', 0, idx)
i = parse_start + len("JSON.parse(") + 1  # skip opening quote
start = i
while i < len(content):
    if content[i] == '\\': i += 2; continue
    if content[i] == "'": break
    i += 1
raw = content[start:i]
unescaped = raw.encode().decode('unicode_escape')
idl = json.loads(unescaped)
json.dump(idl, open('idl.json','w'), indent=2)
```

### 1.4 Compute discriminators
```python
import hashlib
for a in idl['accounts']:
    print(a['name'], hashlib.sha256(f"account:{a['name']}".encode()).digest()[:8].hex())
# Instruction discriminators = sha256("global:ix_name")[:8] (usually already in IDL)
```

## Phase 2 — On-Chain Enumeration

### 2.1 Fetch program accounts by discriminator
```bash
DISC_B58=$(python3 -c "import base58; print(base58.b58encode(bytes.fromhex('DISC_HEX')).decode())")
curl -s -X POST https://api.devnet.solana.com \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getProgramAccounts\",\"params\":[\"PROGRAM_ID\",{\"encoding\":\"base64\",\"filters\":[{\"memcmp\":{\"offset\":0,\"bytes\":\"$DISC_B58\"}}]}]}" > accounts.json
```

### 2.2 Borsh-decode accounts
Field types dari IDL:
- `pubkey` = 32 bytes
- `u32/u64/i64` = `struct.unpack('<I/Q/q', ...)`
- `bool` = 1 byte
- `string` = `u32 length + bytes`
- `Option<T>` = `u8 tag + T if tag==1`
- Enum = `u8 variant index`

### 2.3 Classify + anomalies
Count by phase, spot invariant violations (participants > 0 but sol == 0, migrated & !settled, etc).

## Phase 3 — Attack Surface Map

Klasifikasi IDL instructions:

**ADMIN indicators (auth bypass target):**
- Name: `initialize`, `set_`, `admin_`, `claim_dev`, `migrate_global`, `update_`, `withdraw`, `close_`
- Signer named `admin` / `authority`
- Account with `relations: ["global_config"]` = Anchor `has_one`

**PUBLIC ix (logic bugs):**
- Bonding curve math (`buy_slot`, `sell_slot`)
- RNG consumption (`spin`, `resolve_spin`, `roll_jackpot`)
- Timing-sensitive (`migrate`, `settle_slots`)

**Error codes = invariants map:**
- `6015 ArithmeticOverflow` = math wraps possible
- `6039 Unauthorized` = has_one enforcement
- `6082 LotterySnapshotSlotInFuture` = snapshot_slot ≤ current_slot

## Phase 4 — Simulate Attacks (No SOL)

### 4.1 Admin auth bypass probe
Build admin ix dengan attacker as signer, real `global_config`. Sim via `simulateTransaction` + `sigVerify=false`. Any err_code != 6039 (or non-error) berarti check bocor.

Fee payer must be a whale wallet (has SOL, discovered via `getSignaturesForAddress` on target account). Attacker only becomes signer via `sigVerify=false`.

### 4.2 Account substitution (Type Confusion)
Kalau Anchor cuma check discriminator + gak validate owner:
1. Create fake account via `system_program.create_account` (attacker as authority)
2. Populate dengan discriminator asli + attacker as admin field
3. Call `set_X` dengan fake account
4. Success = CVE, P1

**Test matrix — 5 substitution scenarios + expected rejection codes**

| Substituted account | Real value in test | Expected Anchor error | Verdict |
|---|---|---|---|
| `global_config` = attacker's system wallet | `AgRb...` (0 lamports, system-owned) | 3012 `AccountNotInitialized` | properly rejected |
| `global_config` = real Launch account (same prog owner, wrong discriminator) | Any Launch PDA | 3002 `AccountDiscriminatorMismatch` | properly rejected |
| `global_config` = random derived PDA | `find_program_address([b"fake_seed"], POPI)` | 3012 `AccountNotInitialized` | properly rejected |
| `launch` = attacker's system wallet (public ix `buy_slot`) | `AgRb...` | 3012 `AccountNotInitialized` | properly rejected |
| `admin` field via attacker sigVerify=false | real GC + attacker as admin signer | 6039 `Unauthorized` (custom) | properly rejected |

**Interpretation:** any err code in `{3002, 3007, 3012, 2006}` = Anchor's default `Account<T>` validation caught it → no bug. Only `err: None` (successful sim) OR unusual error like `6000-6014` (custom, mismatched semantics) is worth reporting.

Template: `templates/admin_bypass_template.py` — adapt by swapping account_overrides dict.

### 4.3 Fuzz existing tx (replay + mutate)
Find real successful tx, locate ix discriminator offset, mutate specific bytes. Test valid enum values vs invalid — mismatch = validation gap.

## Phase 5 — Web Layer (parallel)

Standard checks: SSR XSS (React usually clean), imgproxy SSRF (403 on tampering), RPC method bypass (test 60+ methods, spot non-whitelisted allowed), SIWS nonce reuse (30 concurrent), HPP, Race condition, Mass assignment, CORS misconfiguration.

### 5.0 Frontend Error/Telemetry Endpoints (client-log, error-report)

Web3 dApps commonly ship a "log-my-frontend-errors-to-backend" endpoint under names like `/api/client-log`, `/api/error-report`, `/api/telemetry`, `/api/log`. These are almost always weakly validated because devs treat them as internal. Verified P4 bug class:

**Test matrix (all reproducible unauth):**
```bash
# 1. Level whitelist bypass (200 = accepted)
for level in debug info warn error fatal panic emergency alert; do
  curl -sX POST https://TARGET/api/client-log \
    -H 'Content-Type: application/json' \
    -d "{\"level\":\"$level\",\"message\":\"probe\"}"
done

# 2. Rate limit check (30 rapid: if all 200 without 429, no rate limit)
for i in {1..30}; do
  curl -sX POST https://TARGET/api/client-log -H 'Content-Type: application/json' \
    -d "{\"level\":\"error\",\"message\":\"flood $i\"}" -o /dev/null -w '%{http_code} '
done

# 3. Control character injection (\n, \r, ANSI \x1b)
curl -X POST https://TARGET/api/client-log -H 'Content-Type: application/json' \
  -d '{"level":"error","message":"\n[ERROR] fake admin log entry"}'
```

**Signals:**
- No rate limit on client-log while `/api/auth/*` DOES rate-limit → misconfiguration
- Accepts `panic`/`fatal`/`emergency` → alerting can be poisoned unauth
- Newlines/ANSI preserved → log forgery for downstream ops review
- HTML payloads accepted → downstream XSS risk if operator dashboard renders raw

**Verified live on popi.wtf**: all 4 tests succeeded, reportable P4 ($50-150).

Full test matrix + report template: `references/client-log-unrestricted.md`.

### 5.1 Sentry Route Manifest Leak (Next.js dApps — always test this)

Next.js apps using Sentry SDK embed `globalThis._sentryRouteManifest` into the main-app bundle. This leaks **every route file** in the app — including `/dev/*`, `/dev/admin/*`, staging previews, mocks — that are supposed to be hidden. Reportable P4-P5 ($25-75) even if all leaked routes currently return 404, because it's a recon-amplification info-disclosure.

```bash
curl -s https://TARGET/_next/static/chunks/main-app-*.js \
  | grep -oE '_sentryRouteManifest=[^;]{0,4000}' | head -c 4000
```

Report template: see `references/nextjs-sentry-manifest-leak.md`.

### 5.2 Hidden Microservice Endpoint Tracing via base URL variable

When JS bundle has `fetch("".concat(r,"/somepath"))`, `r` is a base URL variable defined nearby. Trace it back to reveal a whole hidden endpoint cluster. Pattern found in popi:

```js
let r = "/api/referral";                 // <-- base URL variable
fetch("".concat(r, "/dashboard?..."))    // becomes /api/referral/dashboard?...
fetch("".concat(r, "/balance?..."))
fetch("".concat(r, "/bind"))
fetch("".concat(r, "/claim"))
fetch("".concat(r, "/my-ref-code"))
fetch("".concat(r, "/my-referees"))
```

Regex to find the pattern in bundles: `fetch\("\s*"\.concat\(([a-zA-Z_]+),"([^"]+)"`. Then trace the variable definition backward (usually within ~1000 chars of first use, look for `let VAR="/api/…"` or module-scope `r="…"`).

Once base found, always probe with IDOR pattern first:
```
GET  {base}/dashboard?wallet={anyWallet}   ← accepts wallet as param = IDOR candidate
GET  {base}/balance?wallet={anyWallet}     ← same
POST {base}/bind    body={referee_wallet, referrer_wallet, ref_code}
POST {base}/claim   body={wallet, siws_message, siws_signature}
```

**High-signal bugs to look for:**
- IDOR: does dashboard/balance return data for ANY wallet, or only session wallet?
- Self-referral: try `referee_wallet == referrer_wallet` in `/bind`.
- CSRF header theater: headers like `X-Popi-CSRF`, `X-Popi-Bind` are usually cosmetic (real auth is SIWS). Test with dummy values; if server rejects only on invalid SIWS not on missing custom header, it's cosmetic — don't waste a report calling it a CSRF bypass.

## Phase 7 — Closed-Source / Upgradeable Program Binary Analysis

When source code is NOT available (proprietary, not open-sourced, or GitHub repo is private/empty), you can still get meaningful recon from on-chain binaries.

### 7.1 Dump the program binary

```bash
solana program dump <PROGRAM_ID> --url https://api.mainnet-beta.solana.com /tmp/program.so
ls -lh /tmp/program.so  # 8-15MB typical for complex programs
```

This gets the raw BPF bytecode regardless of whether source is available.

### 7.2 Extract strings for recon

```bash
strings /tmp/program.so | grep -iE 'fee|transfer|sol|lamport|mint|account|swap|sell|buy|price|curve|bond|overflow|underflow|transfer_|system|spl|token|arithmetic|admin|mayhem|migrate' | sort | uniq -c | sort -rn | head -40
```

Strings reveal:
- Internal Rust source paths: `programs/pump/src/buy.rs`, `src/lib.rs` → code structure
- Error code strings: `ArithmeticOverflow`, `InsufficientFunds`, `BondingCurveComplete` → known invariants
- Instruction names: `BuyV2Instruction`, `SellV2Instruction`, `MigrateInstruction` → confirmed ix set
- Admin function paths: `set_reserved_fee_recipients.rs`, `admin_update_token_incentives.rs` → untested code paths
- Custom panic messages: `Overflowing user accumulator` → state corruption vectors

### 7.3 Check upgrade authority (CRITICAL)

```bash
solana program show <PROGRAM_ID> --url https://api.mainnet-beta.solana.com
```

Look for:
```
Owner: BPFLoaderUpgradeab1e11111111111111111111111  ← UPGRADEABLE
Authority: <pubkey>                                      ← SINGLE POINT OF FAILURE
```

```
solana account <AUTHORITY_KEY> --url https://api.mainnet-beta.solana.com
# Check balance + ownership
```

**Upgradeable finding:** For programs managing user funds ($50M+ TVL), an upgradeable program with a single-key upgrade authority is a **secondary Critical** — rug pull vector if key compromised. Report as "program authority centralization risk" + "unauthorized upgrade path."

### 7.4 Binary analysis payload patterns

**Constant product formula detection** (look in strings):
```
programs/pump/src/util/constant_product.rs   ← AMM uses x*y=k formula
programs/pump/src/util/fee.rs                ← fee calculation
```
Constant product = same class of bugs as Uniswap V2: price manipulation, rounding errors, overflow with large inputs.

**MayhemMode / untested code paths** (look for):
```
ToggleMayhemMode, SetMayhemVirtualParams, MayhemModeDisabled
```
Separate virtual parameter set toggled by admin = untested code path = likely audit miss.

**Arithmetic overflow signals:**
```
Account arithmetic overflowed
Overflowing user accumulator
Overflowing sol volume
```

### 7.5 PIDL extraction (if Anchor-compiled)

Even without published IDL, the on-chain program may store IDL in a PDA:
```bash
# Try known Anchor IDL account seeds
solana account idlACpGYGHxqJkDzK2gzqR9UpqD3QxwkHdoTpC5MjQ5 --url https://api.mainnet-beta.solana.com 2>&1
```

If IDL exists on-chain → extract discriminators + account layouts directly.

## Phase 8 — Self-Hosted Target Selection (Solana DeFi)

### 8.1 DeFiLlama API for Solana-native protocols

```python
import urllib.request, json

# Get all Solana-native (single-chain) protocols sorted by TVL
r = urllib.request.urlopen('https://api.llama.fi/protocols?chain=Solana')
data = json.load(r)

solana_native = []
for p in data:
    chains = p.get('chains', [])
    if not (len(chains) == 1 and 'Solana' in chains):
        continue
    tvl = p.get('tvl', 0) or 0
    if tvl < 50e6:  # filter >$50M for meaningful payout
        continue
    slug = p.get('slug', '')
    name = p.get('name', '?')
    audited = bool(p.get('audit'))
    url = p.get('url', '')
    solana_native.append((name, tvl, audited, url, slug))

solana_native.sort(key=lambda x: x[1], reverse=True)
for name, tvl, audited, url, slug in solana_native[:20]:
    print(f'{name:30s} ${tvl/1e6:.1f}M  audited={audited}  {url}')
```

### 8.2 Target scoring (go if >= 7/10)

**Rule:** WRITE the report confidently. ASSESS honestly when user asks.

DO:
- State facts as facts: "Server returns X when Y is sent" — not "Server *may* return X"
- Include exact reproducible curl one-liner. Triagers copy-paste.
- Attach a fix recommendation with concrete code/config (fix + PoC = accept more often).
- Rate severity where user impact actually justifies. Under-rating = accept but low pay; over-rating = reject entirely.
- Put reporter contact + reward wallet at bottom (not header — some intake forms strip PII from title fields).

DON'T:
- Hedge in the report body ("this might be a bug"). Triager decides severity, not lo.
- Bundle 5+ findings in one report — split ke 1 report per finding.
- Include a weak finding alongside strong ones — rejected weak finding drags perception on the strong one.
- Use "critical" without CVSS impact proof.

**When user asks "is this really a bug?" after you've written the report:**
- Give calibrated ranking (which finding strongest, which tipis but recognized class).
- Distinguish: (a) real bug, (b) real bug class weak PoC, (c) informational-only, (d) rejected class.
- Never dismiss your own verified findings preemptively.
- If bounty class is recognized elsewhere (HackerOne/Immunefi past reports), cite it.
- Explicit user preference in past sessions: DO NOT reply with percent probability breakdown (60%/25%/12%). That reads as defeatism. Instead: "solid / solid / tipis but recognized class → submit all three".

### 6.2 Submission channel fallback chain

Try in order — each is slower but more reliable paper trail:
1. **HackerOne / Bugcrowd / Immunefi** — if program listed there, use platform. Highest weight.
2. **Program's own Google Form** — many crypto betas use temporary forms. Screenshot the confirmation immediately — forms get closed/replaced without notice.
3. **Discord ticket channel** — post-form fallback. Structure: 1 intro message + N finding messages (~2000 chars each, Discord message limit). Discord often refuses arbitrary text attachments during beta ("for security reasons") — prep report as pasteable code blocks, not `.md` files.
4. **Direct email** — `security@target`. Slowest, most reliable audit trail.

**Discord message pack pattern** (verified on popi.wtf ticket):
- MSG 1 — Intro: reporter handle, N findings summary (one line each), signal continuation
- MSG 2..N — Finding body: severity, affected endpoint, curl PoC, expected vs actual, fix
- MSG N+1 — Closing: wallet for reward, offer to test fixes

Attach as `.txt` files (not `.md`) — some Discord tickets accept plain text attachments even when refusing markdown/code files.

**Source availability gate (2026-08-29):** Before spending time on a target, confirm source exists. Try `git clone <org>/<repo>` AND GitHub API search (`/search/repositories?q=<keyword>+stars:>5`). If both return 0 results, move to Phase 7 binary analysis — see `references/closed-source-programs-2026-08.md`.

### 6.3 Wallet import format quirks

Same 64-byte Solana keypair, different apps expect different encoding:

```python
import json, base58
raw = bytes(json.load(open("keypair.json")))  # Solana CLI JSON format = 64-byte array

# Phantom / most browser wallets — base58 88-char string of ALL 64 bytes
phantom_import = base58.b58encode(raw).decode()

# Solflare "Private Key" tab — hex 128-char (64 bytes hex)
solflare_hex = raw.hex()

# Backpack / Solana CLI — JSON array literal
backpack_json = json.dumps(list(raw))

# NOT VALID for import: seed-only (first 32 bytes b58) — different encoding entirely
```

**Import failure debug:**
- Copy-paste whitespace: paste to plaintext editor first, strip newlines, then paste to wallet.
- App-expects-seed-phrase: some wallets refuse raw key entirely, only accept 12/24-word phrase. Workaround: import to CLI-friendly wallet (Backpack), then transfer out.
- Base58 char validation: no `0`, `O`, `I`, `l`. If your string has any of these, format is wrong.

## Phase 0 — Target Selection (do this BEFORE recon)

**"self-hosted `security.txt` + email-direct bounty + real TVL" = himpunan kosong di Solana DeFi.** Verified by probing top-20 Solana DeFi (jup.ag, kamino, drift, marginfi, raydium, orca, meteora, sanctum, marinade, jito, save, phoenix, tensor, loopscale, exponent, ratex, adrena, carrot, texture): NONE self-host a bounty-only `security.txt`. Every protocol with real TVL routes bounties through an escrow platform (Immunefi majority, rest Cantina/Hats) — deliberately, so hunters trust they'll be paid and the project can't be accused of ghosting.

Consequence: if the user asks for "non-Immunefi, non-Cantina, self-hosted, real payout" targets, that's a contradiction. Email-direct-only projects are small/new with no TVL → unclear bounty + no obligation to pay + exactly the ghosting pattern the user hates. **Do NOT invent fictional targets to look compliant.** The honest answer to "Immunefi is all dup" is: chase FRESH CODE, not a new platform — live audit contests (Sherlock/Code4rena) are new code = zero-dup by definition + escrow-guaranteed pool. New Immunefi listings (report count 0-5) and newly-added scope on old programs are the other zero-dup sources.

Quick self-host probe (rules out the self-hosted fantasy fast):
```bash
for d in <domains>; do
  for p in /.well-known/security.txt /security.txt; do
    b=$(curl -sL -m7 -A "Mozilla/5.0" "https://$d$p")
    echo "$b" | head -1 | grep -qv '<' && echo "$b" | grep -qi 'Contact:' && echo "[+] $d$p" && echo "$b" | grep -iE '^(Contact|Policy|Expires):'
  done
done
```

## Phase 9 — Solana Adaptive Fee Program Bugs

When auditing adaptive fee implementations on Solana (Orca Whirlpools, Meteora, etc.), these are the confirmed attack patterns:

### 9.1 Filter Immunity Freeze (HIGH)

The `update_reference()` function in adaptive fee systems applies a filter window during pool initialization that blocks decay. If vr is set high during this window, it stays frozen until the decay period expires.

**Confirmed on Orca Whirlpools** (`oracle.rs:update_reference`):
```rust
// When elapsed < filter_period: NO change (vr frozen)
// When elapsed >= decay_period: vr reset to 0 (full decay)
// Between: proportional decay
```

Attack flow:
1. Swap spikes `volatility_accumulator` to ~12,000
2. Call `update_reference` with elapsed < filter_period (300s)
3. Function returns immediately → vr captured at max
4. vr stays at `FEE_RATE_HARD_LIMIT` (10.00%) for remaining exploitation window

**Impact:** 333x fee amplification on all subsequent traders. Duration: minutes to hours.

**PoC:** See `references/orca-whirlpools-adaptive-fee.md` for stress-tested Rust standalone PoC (180/180 cases pass).

**Severity calibration:** This is **HIGH** (economic damage), NOT CRITICAL, because:
- Inflated fees go to Protocol Fee Vault + LP Fee Accumulator
- Collection requires `collect_protocol_fees_authority` key (separate authority)
- LP fee collection requires position ownership proof
- No direct path to attacker wallet without additional authority compromise
- CRITICAL = requires demonstrated fund extraction path, not just economic harm

### 9.2 Core Tick Group Range Always-Max (potential HIGH)

From `fee_rate_manager.rs` lines 87-109: mathematical guarantee that when price deviation crosses tick group boundaries, `volatility_accumulator` is forced to `max_volatility_accumulator` on every tick crossing — independent of actual volatility. This creates guaranteed sustained high fees during price oscillations.

### 9.3 Skip + advance_tick_group Boundary Inversion (MEDIUM)

Direction tracking bug in `advance_tick_group_after_skip`: `tick_group_index` can go backward while price advances → volatility accumulator stops tracking → fee rate spikes erratically. Requires deeper PoC to confirm fund-impacting exploitation window.

### Severity Calibration Rule (enforced, not advisory)

For adaptive fee programs:
- **CRITICAL** needs: (a) demonstrated fund transfer to attacker wallet, OR (b) access control bypass on `collect_protocol_fees` / `decrease_liquidity` that moves funds out
- **HIGH** qualifies: economic damage with proven + stress-tested amplification (333x, guaranteed duration)
- **MEDIUM** qualifies: edge case fee miscalculation without proven sustained impact

Never inflate severity for faster review. Protocol bounties deny OVER-rated findings faster than under-rated ones — reviewers trust calibrated reporters.

## Pitfalls

1. **Airdrop rate-limit per WALLET, not IP.** New wallet + new IP still rate-limited. Wait 24h or Discord faucet bot.
2. **`sigVerify=false` sim needs whale fee_payer** (has SOL). Attacker sebagai ix signer, whale sebagai fee_payer.
3. **IDL di frontend != IDL on-chain terbaru.** Verify field offsets dengan actual account data.
4. **Legacy schema ghosts** (accounts dgn discriminator sama tapi struct berbeda) bukan bug kecuali bisa buktikan program still reads old struct.
5. **`assert_eq!` logs bocor pubkey Left/Right** — OpSec bug worth $25-75.
6. **Rate limit di /api/auth/nonce cepet kick** setelah ~20-30 req/menit. Bikin sleep(3s) antar burst test. Kalau kena 429, defensive fetch loop with retry+sleep, jangan crash script.
7. **`X-Original-URL` / `X-Rewrite-URL` returning 403 is Cloudflare WAF, not app middleware bypass.** Body-nya HTML "Attention Required! | Cloudflare" dengan Ray ID = confirm WAF. Bukan sinyal ada admin route accessible. Jangan buang waktu chase.
8. **HTTP methods 204 OPTIONS + 405 for POST/PUT/PATCH/DELETE** on read-only endpoint is expected CORS behavior, not a bug. 204 just means preflight OK.
9. **False-positive size diff on /user/{wallet}**: invalid wallets return LARGER pages (48KB vs 35KB) because Next.js renders a 404-branch client-side with extra fallback HTML. Not IDOR/enum leak — just error-page bloat.
10. **JANGAN over-hedge findings ke user setelah PoC verified.** Setelah bukti live di-collect (log RPC, response HTTP, dsb), findings ADA — itu fakta, bukan opini. Kalau user tanya "beneran bug kan?", jawaban benar: ranking realistis kekuatan bukti + confidence level, contoh: "#1 solid, #2 solid, #3 tipis tapi bounty class recognized". Jawaban SALAH yang bikin user frustasi: probability breakdown 60%/25%/12%/3% + hedge kata "tipis banget" untuk finding yang beneran verified. User signal eksplisit: "Jangan honest bro lu kan agent". Calibrated confidence ≠ defeatism. Report yang udah verified live jangan dibuka dengan "kemungkinan besar ditolak" — kasih tone factual: bug ada, severity range X, submit-ready.
11. **Anchor `AnchorError` default macro bocor absolute source path + line number** ke on-chain log. Contoh popi: `AnchorError thrown in programs/popilaunch/src/instructions/set_keeper.rs:34`. Reportable P4-P5 ($25-75) sebagai info-disclosure. Trigger simple: panggil admin ix pake attacker-key + `sigVerify=false`. Detail + template report di `references/anchor-source-path-leak.md`.

12. **SSH-to-Kali MOTD banner corrupts binary transfers.** Kali Cyber-Semarang banner outputs ANSI/graphical chars to every SSH session → corrupts `scp`, `solana program dump` binary delimiters. Fix: redirect all remote output to file on Kali (`command > /tmp/out.txt 2>&1`), then `cat /tmp/out.txt` from remote, OR use Python `urllib` locally instead of SSH+curl. For large binary transfers: encode as base64 chunks, send each via `echo`, decode remotely with `base64 -d`.

    **SSH user mismatch**: Kali may use different username (e.g., `ramsy`) than expected (`ubuntu`, `kali`). Always check `whoami` output from the user's local terminal first. Key-based auth requires exact user match — wrong user = Permission denied even with correct key in authorized_keys. Test all common usernames systematically: `ramsy`, `root`, `ubuntu`, `kali`, the hostname slug.

    **Refined Kali SSH technique (2026-08-29):**
    - Direct `terminal()` with `ssh user@host "cmd"` works reliably (no Python subprocess wrapper needed)
    - Python subprocess wrapper with SSH subprocess.run() times out at 15s even for simple commands (`rc=255`) — use terminal tool directly
    - `PrintMotd=no` + `LogLevel=QUIET` in ssh options does NOT suppress banner (it's a .profile/.bashrc print, not standard MOTD)
    - For multi-line scripts: use heredoc `ssh host "cat > /tmp/script.py << 'EOF'\n...\nEOF"` then `ssh host "python3 /tmp/script.py"`
    - For output: pipe through `grep -v` with known MOTD patterns, or redirect to file + `cat` the file

13. **`pip3 install` with PEP 668 on Kali.** Kali's Python 3.14+ uses `--break-system-packages` for `pip3 install --user` fallback. Use `pip3 install --user --break-system-packages <pkg>` or install in venv.

14. **GitHub API rate-limit unauthenticated requests (60/hr/IP).** If you hit 403, wait or use authenticated request. For code search, try directly from Kali (different IP = different rate limit bucket).

15. **Solana program source NOT on GitHub.** High-TVL protocols like Sanctum Infinity have NO public source — searched `sanctum-labs`, `SanctumLabs`, `sanctumso`, `infinity-labs`, code search for "infinity anchor solana" — all returned 0 usable results. Fall back immediately to Phase 7 (binary analysis via `solana program dump`, `strings`, upgrade authority check) rather than spending 30+ min searching. Confirm with: `solana program show <PID>` gives upgrade authority + owner even without source.

16. **PDF generation with WeasyPrint beats fpdf2 for audit reports.** fpdf2 has latin-1 only encoding, deprecated API (`ln=` → `new_x=`, `new_y=`), and fails on Unicode chars like em-dashes. WeasyPrint handles full HTML+CSS → A4 PDF with Unicode, tables, and styling. Install: `pip3 install weasyprint`. Write report as HTML with `@page { size: A4; margin: 2cm }`, body `font-size: 10pt`, pre/code blocks with `white-space: pre-wrap`. Stripping non-latin-1 chars (`encode('latin-1','replace')`) is a workaround but ugly — use WeasyPrint instead.

17. **Base64 file transfer pattern to Kali (verified 2026-08-29).** Cleanest for binaries + text:
    ```python
    import subprocess, base64, os
    with open('/local/file', 'rb') as f: b64 = base64.b64encode(f.read()).decode()
    # Transfer
    subprocess.run(["ssh", key, host, f"echo '{b64}' | base64 -d > /remote/file"])
    # Verify
    subprocess.run(["ssh", key, host, f"ls -la /remote/file"])
    ```
    Works for files up to ~7KB (within SSH command length limits). For larger files, split into chunks or use `scp` with `-o BatchMode=yes -o StrictHostKeyChecking=no`.

## Session Files (dari popi run)
```
~/popi-recon/popi_idl.json                 77KB full IDL
~/popi-recon/all_launches_decoded.json     538 launches decoded
~/popi-recon/decode_launches.py            Borsh decoder
~/popi-recon/admin_bypass.py               auth bypass template
~/popi-recon/spin_fuzz.py                  fuzz template
~/popi-recon/race_and_hpp.py               web-layer fuzz template
~/popi-recon/FINDINGS.md                   attack surface map
```

## Real World Numbers (popi.wtf)

- Total launches enumerated: 696 (538 decoded, 158 legacy schema)
- IDL: 32 ix / 104 errors / 9 accounts / 36 events
- Whale wallet used as fee_payer: 3F8pEs25... (15 SOL, 10+ successful spins)
- All admin bypass rejected with err 6039 (proper `has_one` enforcement)
- CU consumption on failed admin ix: ~7649 (Anchor exit-early on relations check)
