# Solana dApp — Negative Test Results Bank

Bug classes tested and confirmed **CLEAN** on well-engineered Solana dApp targets (popi.wtf as reference). Skip these first-pass unless the target shows weak signals — save time for higher-yield attack surfaces.

## Frontend (React / Next.js Solana)

| Class | Result | Why |
|---|---|---|
| SSR XSS via `name`/`symbol` | Clean | React auto entity-escapes in `<title>`, `og:*` meta tags |
| DOM XSS via metadata JSON | Clean | Metadata fields not passed to `dangerouslySetInnerHTML` |
| Imgproxy SSRF (signature tamper) | Clean | HMAC-signed URLs, 403 on any tamper |
| CORS misconfig | Clean | Same-origin only, no ACAO reflection |
| HTTP Parameter Pollution | Clean | Next.js `URLSearchParams` — first-param wins consistently |
| Mass Assignment on `/verify` | Clean | Extra JSON fields silently ignored |
| SIWS nonce race (30 concurrent) | Clean | Unique nonce every call, 5-min TTL, atomic per-request |
| SIWS nonce cross-wallet binding | Clean | Nonce not bound to wallet, but verify checks signature-wallet |
| SQL injection on `/launches?search=` | Clean | Parameterized queries |
| `/api/rpc` method-whitelist bypass | Clean | Firm allow-list |
| Auth mode toggle via param | Clean | `?debug=1`, `?admin=true`, `?force=true` all no-op |
| Case-variant path bypass | Clean | Router normalized |
| `X-Original-URL` / `X-Rewrite-URL` bypass | Clean (403 was Cloudflare WAF, not app) | Middleware doesn't honor header rewrites |

## Anchor program (has_one / Account<T> validation)

| Class | Result | Test method |
|---|---|---|
| Admin auth bypass (`has_one = admin`) | Clean — err **6039 Unauthorized** | Simulate admin ix with attacker key as `admin` signer |
| Type confusion — attacker wallet as global_config | Clean — err **3012 AccountNotInitialized** | System-owned pubkey as `Account<GlobalConfig>` |
| Type confusion — wrong-type popi account | Clean — err **3002 AccountDiscriminatorMismatch** | Launch account substituted where GlobalConfig expected |
| Type confusion — random PDA | Clean — err **3012** | Fresh `find_program_address` on unused seed |
| `buy_slot` with invalid launch | Clean — err **3012** | System wallet as launch |
| Spin count fuzz | **Inconclusive** — err 0x0 (state check runs first) | Mutate `spin_count` byte in real tx |

Interpretation of Anchor error codes:
- `2001` ConstraintHasOne — `has_one` field mismatch
- `2006` ConstraintSeeds — PDA seed mismatch
- `3002` AccountDiscriminatorMismatch — wrong account type
- `3007` ConstraintOwner — owner != program
- `3012` AccountNotInitialized — account exists but discriminator zero / doesn't exist
- `6000+` Custom program errors (per-project, see IDL)

## Rate limits observed (popi baseline)

| Endpoint | Rate limit |
|---|---|
| `/api/auth/nonce` | 429 at ~20-30 req/min |
| `/api/referral/*` | 429 at ~3-5 req/min |
| `/api/auth/verify` | 429 at ~5 req/min |
| `/api/client-log` | **NO rate limit** (this itself was reported as finding) |
| `/api/launches` | cached (`s-maxage=3`), no per-IP limit needed |
| Solana devnet airdrop | per-WALLET-address, **24h reset**, per-IP jitter doesn't help |

## Faucet dead-ends

Standard Solana devnet faucets all rate-limit per-wallet:
- `solana airdrop` CLI → 429
- Solana official faucet API → HTML response (captcha wall)
- Helius / QuickNode APIs → 404 or `{"error":"Method not found"}`

Working alternatives:
1. Wait 24 hours per wallet
2. Discord faucet bot on target's server (if any)
3. Transfer devnet SOL from an existing wallet
4. New wallet + Discord faucet bot combination

## Report style pitfall

When submitting findings, do NOT over-hedge the writeup. Users get frustrated when the agent adds too many "may or may not", "speculative", "unverifiable" caveats. Impact statements should be direct — reader is a triager who wants signal, not disclaimers. State speculation ONCE explicitly in an "unverified effects" bullet, don't sprinkle it through every sentence.

DO:
> Attackers can send fake `panic` events. Impact: alert fatigue, on-call paging abuse.

DON'T:
> Attackers *may* be able to send events *that could potentially* trigger alerts, *though this depends* on the observability stack configuration *which we cannot verify from outside*.
