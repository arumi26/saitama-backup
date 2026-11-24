# Kraken VRP + Ink L2 Recon (self-hosted, email-direct) — Aug 2026

## Program facts (verified via security.txt + VRP page)
- **Type:** self-hosted, email submission — `bugbounty@kraken.com`
- **security.txt:** `https://www.kraken.com/.well-known/security.txt` (Contact, PGP, Signature, Policy, Wall-of-Fame acknowledgments)
- **Rewards (paid in BTC):** Low $500–1K · Medium $2.5K–5K · High $20K–50K · **Critical $100K–$1.5M**
- **Track record:** 26 reports rewarded last year, top Wall-of-Fame payout $60,100; avg payout ~$3,962
- **Safe harbor:** yes

## In-scope properties
| Host | Property |
|---|---|
| www.kraken.com | Main website |
| api.kraken.com | REST API |
| ws.kraken.com / ws-auth.kraken.com | WebSockets API |
| futures.kraken.com/derivatives/api/v3 | Derivatives REST |
| wss://futures.kraken.com/ws/v1 | Futures WebSocket |
| trade.kraken.com / pro.kraken.com | Kraken Pro |
| www.cryptofacilities.com / .co.uk | Crypto Facilities |
| www.cfbenchmarks.com | CF Benchmarks |
| www.staked.us / mainnet.staked.cloud/api | Staked |
| **`*inkonchain.com`** | **Ink L2 (wildcard — widest/freshest surface)** |
| id.kraken.com | Kraken SSO |
| Desktop app, Android/iOS apps, Kraken Wallet | native apps |
| "Any host verified to be owned and maintained by Kraken" | catch-all |

## Target selection insight
The `*inkonchain.com` wildcard is the highest-value pick: it's Kraken's own OP-stack
L2, less battle-tested than the core exchange, and the wildcard means broad surface.
Core exchange domains (www/api/ws.kraken.com) are tier-1 hardened — treat like the
"big target quick scan" (report padding, not criticals).

## Ink recon snapshot (from XL Axiata box via DoH+--resolve, see main SKILL)
- subfinder → **87 subdomains**; parallel DoH-resolve → 45 resolved; curl --resolve → **43 live**
- High-signal live hosts:
  - `explorer.inkonchain.com` + `explorer-sepolia` (Blockscout — CORS `*`+creds, /graphiql, /api-docs — see blockscout-live-findings.md)
  - `mystery-faucet.inkonchain.com` (200 — faucet claim logic, rate-limit/abuse)
  - `ink-verify-api.inkonchain.com` / `-sepolia` (contract verification API)
  - `rpc-gel*.inkonchain.com` (405 on GET = JSON-RPC POST endpoint), `ws-gel*` (400 = WebSocket upgrade expected)
  - `staging.inkonchain.com` (200 — staging env, often weaker controls)
  - `portal.inkonchain.com` (bridge/portal — funds path, but returned 000 from this box; recheck)
  - `paint.inkonchain.com`, `ink-kit.inkonchain.com`, `gm.inkonchain.com`
  - `*.dev.inkonchain.com` (admin/analytics/private/vpn/owa/mx — dev cluster, mostly 404 catch-all on CF edge)
- Blockscout explorer is the fastest path to a real finding (known CORS/GraphQL class).
  RPC/WS hosts on Google Cloud IPs (34.12.x / 35.204.x) sit off Cloudflare — probe directly.

## Deep-dive results (Aug 2026 — bridge focus)
| Host | Finding | Severity reality |
|---|---|---|
| `explorer.inkonchain.com` | `ACAO:*`+`ACAC:true` on `/api/account/v2/user/info`; GraphQL introspection open at `/api/v1/graphql` | LOW-MED — Blockscout default, browser blocks `*`+creds, bearer-auth not cookie. Kraken likely knows. |
| `mystery-faucet.inkonchain.com` | Next.js+hCaptcha. `/api/info` leaks faucet acct+payout. `/api/claim` validates captcha BEFORE rate-limit. chainId **763373 = Ink Sepolia = TESTNET** | ~nil $ impact (testnet ETH) |
| `staging.inkonchain.com` | `/openapi.json`,`/health`,`/metrics` all 200 | FALSE POSITIVE — Next.js SPA catch-all (HTML shell). Body-check always. |
| `status.inkonchain.com` | Atlassian Statuspage | Out of scope (3rd-party) |
| **`bridge-gel.inkonchain.com` + `-sepolia`** | **`x-vercel-error: DEPLOYMENT_NOT_FOUND`** — dangling Vercel. Wayback: served bridge redirect until 2025-04 | **TAKEOVER CANDIDATE** — bridge subdomain on wildcard = High/Critical if claimable. Verify passively; do NOT deploy. |

## Ink native bridge = OP-stack standard contracts
From docs.inkonchain.com/useful-information/contracts: OptimismPortal, L1/L2StandardBridge,
L1CrossDomainMessenger, SystemConfig, DisputeGameFactory, L1ERC721Bridge + `0x4200...` predeploys.
Bridge UI on main site = external `superbridge.app` redirect (NOT self-hosted). Deep bridge-contract
audit = smart-contract track, not web.

## Untouched high-value paths (next session)
- Ink RPC/sequencer infra (`rpc-gel*` 405, `ws-gel*` 400, on Google Cloud IPs off-Cloudflare) — realistic L2 Critical
- `ink-verify-api.inkonchain.com` — DNS didn't resolve from XL box; retry clean resolver
- `id.kraken.com` SSO — account-takeover = Critical class

## Access note
From Indonesian ISP the whole `*.inkonchain.com` + `*.kraken.com` set is DNS-blocked
(blockpage). Run recon via DoH (1.1.1.1 dns-query) + `curl --resolve`, or from a box
on a clean network. Cloudflare edge for the web tier is 104.18.36.214 (shared).
Cloudflare flattens CNAMEs → origin provider (Vercel/etc.) only visible via `x-vercel-*`
response headers, not `dig CNAME`.
