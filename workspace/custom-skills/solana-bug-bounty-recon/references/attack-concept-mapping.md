# General Security Concepts → Solana Bug Classes

Cross-reference for translating classical / kernel / web bug classes into Solana-specific attack vectors. Useful when reviewing new Solana programs — check each class systematically. Users often bring general bug-bounty cheatsheets (PayloadsAllTheThings etc.) that expect this translation.

## Kernel / systems concepts → Solana

| General class | Solana equivalent | Testable no-SOL? | Test method |
|---|---|---|---|
| **Use-After-Free** | **Account resurrection**: close → send SOL to same address → re-init with different type | No — needs writes | Try to close+recreate a PDA with different discriminator; requires broadcast |
| **Type Confusion** | **Account substitution**: pass wrong-type account where `Account<T>` expected | **Yes** — `simulateTransaction` sigVerify=false | Substitute global_config with different discriminator account. See `templates/admin_bypass_template.py` |
| **Double-fetch (io_uring)** | **Reentrant CPI**: program A → B → A with state read twice | Rare in practice — most Anchor programs error `NoCPI` explicitly | Check IDL for CPI-permitting instructions; error 6006 "NoCPI" means mitigated |
| **Buffer overflow** | Stack/heap in program (mostly SBF-safe by design) | No — modern Solana runtime enforces bounds | — |
| **UAF via free-then-realloc** | **Account close + shell drop-in** with new struct | No — needs SOL | — |

## Web bug classes → Solana

| Class | Solana equivalent | Testable no-SOL? | Notes |
|---|---|---|---|
| **SSRF** | **imgproxy / metadata gateway** proxying user-controlled URIs | Partial | Set token metadata URI to internal address; requires create_launch with SOL |
| **IDOR** | **wallet query params** on read endpoints (`?wallet=X`) | Yes | Query other wallets' data unauth. Watch for session-vs-param mismatch |
| **Dependency confusion** | Anchor crate typosquat, Metaplex plugin swap | Static | Grep `Cargo.toml` for unusual sources |
| **Race condition** | **Concurrent CPI** / tx pipeline race | Hard on Solana — deterministic ordering per block | — |
| **Log injection** | **Program `msg!` logs** rendered in operator dashboards | Yes | Inject newlines/ANSI in `msg!` outputs via `client-log`-style relays |
| **CSRF** | **SIWS auth flow** with weak origin check | Yes | Test SIWS bind without required custom headers |
| **XSS via user metadata** | **Token `name`/`symbol`/`uri` fields** rendered in launch pages | Yes | React SSR usually saves you; DOM render less safe |

## Cryptographic bug classes → Solana

| Class | Solana equivalent | Testable? |
|---|---|---|
| **Merkle proof forge** | **Roll_jackpot** / **snapshot commitment** with client-supplied `holders_commitment` | Requires Merkle library + on-chain state |
| **RNG manipulation** | **VRF grinding** on ORAO / Switchboard integrations — cancel-and-retry cycle | Requires SOL + tight timing |
| **Timestamp manipulation** | Program using `Clock.unix_timestamp` for randomness or timing gates | Yes — enumerate program logic |
| **Off-by-one in fee/refund tiers** | **Bonding curve refund fee buckets** (0-999, 1000-1999, etc.) | Requires create_launch + real refunds |
| **Signature malleability** | Ed25519 on Solana — not malleable, safe | — |

## Pattern to internalize

Every "kernel-style memory safety" concept has an Anchor-runtime equivalent where the mistake is **account validation**, not memory corruption. Anchor's `Account<T>` type solves the common cases (discriminator + owner check) automatically, but developers can still miss:

1. `AccountInfo<'info>` — no type check at all
2. `UncheckedAccount<'info>` — explicit opt-out from Anchor validation
3. Manual `AccountLoader::try_deserialize` calls in custom code paths
4. Custom PDA seed validation gaps (developer forgets `seeds = […], bump` on some accounts)
5. `remaining_accounts` iteration without validating each entry

When auditing, grep IDL for accounts marked plain `pubkey` (not `defined: {...}`) — those are the `AccountInfo` types with lowest built-in safety.

## What to do first on a new target (priority order)

1. **Extract IDL** from JS bundle → map ADMIN vs PUBLIC instructions
2. **Classify all `Account<T>` types** — look for `AccountInfo` / `UncheckedAccount` in `accounts` arrays
3. **Enumerate `/api/rpc` whitelist** — confirm `simulateTransaction` is open (enables no-SOL PoC)
4. **Find whale wallet** via `getSignaturesForAddress` — use as fee_payer in sigVerify=false attacks
5. **Test account substitution** on each admin ix (`templates/admin_bypass_template.py`)
6. **Web-layer fuzz** (`race_and_hpp.py`-style tests) in parallel with on-chain work
7. **Cheap wins** last — SSR XSS, CORS, sitemap disclosure (report as P4-P5)
