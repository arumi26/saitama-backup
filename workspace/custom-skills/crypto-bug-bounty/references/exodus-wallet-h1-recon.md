# Exodus (HackerOne @exodus) — Recon Notes & Wallet-Vendor Playbook

Reusable notes for Exodus specifically, and the general **wallet-vendor bug-bounty** pattern
(source-available in-scope crypto libs beat WAF-walled web endpoints for EV).

## Program facts (as of Aug 2026)
- Platform: HackerOne `hackerone.com/exodus`. Launched Nov 2020. Response efficiency 98%,
  time-to-bounty < 3 business days. Total paid ~$144,740. Min $100 / **max $100,000**.
- Web asset (`*.exodus.io` / `*.a.exodus.io`) reward tiers: Low $300–500, Med $500–2,500,
  High $2,500–5,000, Critical $5,000–10,000. **Web criticals cap ~$10k** — the $100k ceiling
  is for wallet/crypto/contract classes, not web.
- Scope buckets: Official APIs & Company Domains (`*.exodus.io`, `*.a.exodus.io` wildcards),
  XO Ramp, **XO Swap** (see hard-stop), Smart Contracts, Passkey Assets, Exodus Pay Assets,
  **Open-Source Libraries (SDK & Crypto)**, Client Apps, Desktop Wallet application.

## Hard "do NOT touch" (auto-N/A / needs written permission)
- **XO Swap / Exchange** — any testing that creates an order/exchange/swap = closed as Not
  Applicable. Do not touch `xoswap-*`, `exchange*.exodus.io` flows.
- Contact form / support-ticket spam = prohibited.
- DoS, rate-limit, brute-force against backend infra = "do not attempt without permission"
  (email bugbounty@exodus.com first, ~2 working day response).
- Social engineering / phishing = prohibited.
- Known-issue non-payables: browser address-bar spoofing; hardcoded 3rd-party blockchain API
  keys (bitcoin/tezos/waves etc — "effectively public"); outdated swaggerhub/openapi XSS on
  hosted blockchain APIs; 12-word seed phrases found in source.
- **Testing etiquette:** add `h1-<YourH1Username>` to the `User-Agent` header so they can
  whitelist your IP — otherwise the WAF adds an explicit block rule.

## Recon snapshot
- ~324 unique subdomains (subfinder on exodus.io + exodus.com), ~101 live. Almost everything
  is Cloudflare + **"Exodus - Firewall Triggered"** WAF + Cloudflare Bot Management → plain
  curl/httpx gets 403. Real testing needs the `h1-<user>` UA + IP whitelist, and even then the
  bot-management layer is stiff. **Do not sink hours fighting the WAF from a VPS.**
- Non-WAF-walled live surfaces worth a look:
  - `inference-d.ot.exodus.com` — **"Exodus AI Gateway · Phase 0"**, brand-new internal pilot.
    OpenAI-compatible `/v1` base, `/v1/models` → 401, Google SSO ("Sign in with Exodus Google").
    Fresh code = fresh bugs; note it's `.ot.` (internal ops) subdomain — confirm in-scope before
    heavy testing (wildcard is `*.exodus.io`/`*.exodus.com` "public face"; `.ot.` may be gray).
  - `xqa-next.ai.exodus.com` — Coder (cloud IDE) instance.
  - `status.exchange.exodus.io` — Nuxt/Vercel status page (exchange-related → likely N/A surface).

## The wallet-vendor EV play (generalizable)
Wallet vendors (Exodus, and peers) publish their **crypto + SDK libraries as an in-scope
open-source monorepo**. This is the single highest-EV surface:
- Source-available → you can write a **real Foundry/jest PoC**, which is mandatory for payout.
- Crypto primitive bugs map to the top reward tier (up to $100k), not the $10k web cap.
- No WAF, no rate-limit-permission dance, no "creates an order" auto-N/A trap.

**Exodus monorepo:** `github.com/ExodusOSS/hydra` (public mirror; `exodus-oss` repo now
redirects here). Layout: `libraries/`, `features/`, `modules/`, `sdks/{argo,headless,headless-react}`,
`adapters/`, `apps/`. Clone depth-1 (~59MB, 4211 files).

High-value crypto/keychain files to audit (all read this session, code quality is HIGH —
nothing exploitable confirmed, treat as mapped-not-cleared):
- `features/keychain/module/keychain.js` — seed mgmt, `addSeed`/`addExternalPrivateKey`,
  `signBuffer` dispatch, lock/unlock. Uses `@exodus/crypto` (bip32/slip10 KDF map).
- `features/keychain/module/crypto/schnorr-z.js` — **hand-rolled Zilliqa Schnorr** with a
  custom single-round HMAC-DRBG nonce (`singleRoundHmacDRBG`). Custom nonce generation in a
  signature scheme is always worth deep scrutiny (nonce reuse / bias → key recovery). Top lead.
- `features/keychain/module/crypto/secp256k1.js`, `sodium.js`, `ed25519.js`, `cardano.js`
  (Byron 1000-iteration seed derivation), `tweak.js` (BIP340 negate-if-odd-Y taproot tweak).
- `libraries/secure-container/` — **SECO** wallet-encryption format: scrypt (N=16384,r=8,p=1) +
  AES-256-GCM, 12-byte IV, checksum = sha256(metadata‖len‖blob). Blob-key wrapped by
  passphrase-stretched key. Format-confusion / checksum / IV-reuse leads live here.
- `libraries/bip322-js/` — BIP-322 message signing (fork of LegReq ref impl). `Address.ts`
  address-type detection is prefix-based (loose); `Signer.ts` P2TR/P2SH tweak paths.
- `libraries/json-rpc/index.js` — has a `tests/prototype-pollution.js`, meaning they already
  fuzz PP; `_makeErrorObject` reconstructs Error from wire data (recursive cause) — worth a look
  but they clearly hardened it.

**Method:** `git clone --depth 1`, then read the crypto primitives directly (they're small,
well-commented). Build a jest/Foundry PoC only after you have a concrete nonce/format/validation
flaw. PoC-first, claim-second still governs — high code quality means most leads die on close read.
