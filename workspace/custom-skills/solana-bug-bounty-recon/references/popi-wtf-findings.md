# popi.wtf Recon Session — 2026-07-14

Full reconstruction of the popi.wtf recon session on Solana devnet beta. Serves as a "what did we test and what's the outcome" template for similar Solana launchpad targets.

## Program identity

| Item | Value |
|---|---|
| Program ID (BPF) | `4gWMPvZ63Vez6FxVaXFLB4iQZnUAuuf9z4FguqJzfjg9` |
| Anchor name/version | `popilaunch` v0.1.0 |
| Admin / Upgrade authority | `BSntmPQuPCtk6Y7cApDHACeGMDHvuoThvvjx4ty9GPem` |
| GlobalConfig PDA | `E4HZvYD2vAZDR4vRMx8uxbk9XMRUMm6krQct19R7X8XE` |
| VRF | ORAO Network `VRFzZoJdhFWL8rkvu87LpKM3RbcVezpMEc6X5GVDr7y` |
| ALT (frozen) | `popiqcCZRn4NzjMBo1Mbk3LzydnQ229PKR88KJjdMMr` (16 ecosystem addresses) |
| PumpSwap AMM | `pAMMBay6oceH9fJKBRHGP5D4bD4sWpmSwMn52FMfXEA` |

## IDL discovery

- **NOT published on-chain** (no Anchor IDL account at derived PDA — 0-byte result)
- Embedded in JS bundle as `JSON.parse('...')` single-quoted literal
- Bundle: search all JS chunks for `"address":"<PROGRAM_ID>"`, walk back to `JSON.parse(`, decode via Python `unicode_escape`
- Content: 32 instructions / 104 errors / 9 accounts / 36 events / 47 types

## API endpoints inventoried

Public unauth:
- `GET /api/auth/mode` — `{authMode, authDisabled}`
- `POST /api/auth/nonce` — SIWS nonce, 5-min TTL, not bound to wallet
- `POST /api/auth/verify` — SIWS verify
- `GET /api/auth/me` — 401 if unauth
- `POST /api/auth/logout`
- `POST /api/client-log` — frontend error log ingest (no rate limit, no level whitelist)
- `GET /api/launches?phase={bonding|gacha|settle|graduated}&sort=trending&limit=N`
- `GET /api/users/{wallet}` — profile lookup returning `{wallet, username, bio, created_at}`
- `GET /api/users/{wallet}/launches` — launches by creator
- `POST /api/rpc` — Solana RPC proxy with method whitelist
- `WS /api/rpc-ws`

SIWS-authed (all 401 without session cookie):
- `GET /api/referral/dashboard?wallet=X` — IDOR candidate but SIWS-gated
- `GET /api/referral/balance?wallet=X`
- `GET /api/referral/my-referees`
- `POST /api/referral/my-ref-code` — `wallet + siws_message + siws_signature`
- `POST /api/referral/bind` — `referee_wallet + referrer_wallet + siws_*` + `X-Popi-Bind: 1` + `X-Popi-CSRF` headers
- `POST /api/referral/claim` — `wallet + siws_*`

Not accessible in prod (404, but leaked via Sentry manifest):
- `/dev`, `/dev/admin/feedback`, `/dev/admin/launches`, `/dev/admin/referrals`
- `/dev/animations`, `/dev/chart-preview`, `/dev/distribution-preview`
- `/dev/mock-launch`, `/dev/phantom-test`, `/dev/launch-mock`, `/dev/health/incident/:id`

## /api/rpc method whitelist (empirically confirmed)

**Allowed (23 methods)** — read-only Solana RPC:
`getAccountInfo`, `getBalance`, `getBlockTime`, `getEpochInfo`, `getFeeForMessage`, `getLatestBlockhash`, `getMinimumBalanceForRentExemption`, `getMultipleAccounts`, `getSignaturesForAddress`, `getSignatureStatuses`, `getSlot`, `getTokenAccountBalance`, `getTokenAccountsByOwner`, `getTransaction`, `isBlockhashValid`, **`simulateTransaction`**

**Blocked (32+)** — writes, subscriptions, cluster-wide reads:
`sendTransaction`, `sendRawTransaction`, `requestAirdrop`, `getProgramAccounts`, `getBlock`, `getSupply`, `getVersion`, `getIdentity`, `getClusterNodes`, all `*Subscribe` methods

`simulateTransaction` staying open is the CENTRAL finding for this class of target — enables no-SOL PoC construction for any admin ix.

## 3 findings submitted (Discord ticket, 2026-07-14 ~16:30 WIB)

### #1 Anchor source paths in on-chain logs (P5)
Any error-throwing admin ix returns log line:
```
Program log: AnchorError thrown in programs/popilaunch/src/instructions/set_keeper.rs:34. Error Code: Unauthorized...
```
Reveals repo layout + line numbers. Fix: rebuild without `source!()` metadata in error macros.

### #2 /api/client-log unrestricted (P4)
- Accepts arbitrary `level` values (`panic`, `fatal`, `emergency` all returned 200)
- No rate limit (30 rapid requests all 200, vs other endpoints 429 at ~5 req)
- No control-char stripping (`\n`, ANSI escapes preserved → log forgery)
- HTML payloads accepted (potential downstream stored XSS if operator dashboard renders raw)

### #3 Sitemap disclosure via Sentry manifest (P4-P5)
`globalThis._sentryRouteManifest` in `main-app-*.js` leaks all Next.js routes:
```bash
curl -s https://TARGET/_next/static/chunks/main-app-*.js | grep -o '_sentryRouteManifest=[^;]*'
```
Reveals `/dev/admin/*`, `/dev/health/*` etc. All return 404 today but reveal internal architecture.

## Whale wallet discovery (for fee-payer in sigVerify=false attacks)

`3F8pEs25PQTJbdT1yqxvy3WM9wp4Vhrk78jvWmPwjPGc` — 15 SOL, 10+ successful spins on DRAKE launch.

Method:
1. Query `getSignaturesForAddress` on any active Gacha-phase launch
2. For each sig, `getTransaction` → extract `accountKeys[0]` (fee payer)
3. Pick one with successful spin/buy ix (verified via IDL discriminator match)

## Reproducible artifacts

```
~/popi-recon/popi_idl.json            77KB full IDL (extracted from JS bundle)
~/popi-recon/all_launches_decoded.json 538 launches parsed
~/popi-recon/decode_launches.py       Borsh reader for Launch accounts
~/popi-recon/admin_bypass.py          Auth bypass probes (all rejected err 6039)
~/popi-recon/type_confusion.py        Account substitution tests (all rejected 3002/3007/3012)
~/popi-recon/race_and_hpp.py          Web-layer fuzz (nonce race, HPP, mass assignment, CORS)
~/popi-recon/spin_fuzz.py             Replay + mutate real spin tx
~/popi-recon/investigate.py           Anomaly hunter for 696 launches
~/popi-recon/sitemap_leaked.json      Full leaked route manifest
```

## Reward wallet

Reporter used `AgRbpv8Q9thtaF61DTEv9GcRXMEUjFzrwHTRZ2zBnNdp` — this is a **VPS-generated hunter wallet** (private key touched log/memory). Reward from popi if paid → transfer OUT to user's cold Solflare/Phantom wallet immediately.
