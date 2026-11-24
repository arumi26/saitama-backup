# Cantina Bounty Scope Recon (Aug 2026 — Ondo Perps session)

## Why this file exists
The Ondo Perps session proved the full flow from Cantina's JS-rendered bounty list
→ UUID bounty page → Scope tab → SPA API extraction → authz test-plan. Reusable for
any web/API (non-smart-contract) bounty on Cantina.

## Step 1 — Enumerate live Cantina bounties
`curl cantina.xyz/competitions` returns HTTP 200 but NO usable HTML (client-rendered,
no `__NEXT_DATA__`). Use the browser tool:
1. `browser_navigate` to `https://cantina.xyz/opportunities/competitions` (or `/opportunities/bounties`)
2. `browser_snapshot` (full=true) — switch to the **Bounties** tab if not selected
3. Read each card: project, **USDC prize in escrow**, "Cantina-Triaged", "Deposit required",
   "Started" date, KYC flag

Active (top-tier, Aug 2026 snapshot):
| Program | Prize | Started | Notes |
|---------|-------|---------|-------|
| Uniswap | $15.5M USDC | Nov 2024 | SC + web |
| Reserve Protocol | $10M USDC | Mar 2026 | newer |
| Euler | $7.5M + rEUL | Aug 2024 | |
| Polymarket | $5M USDC | Apr 2026 | prediction mkt |
| Coinbase | $5M USDC | Jul 2025 | |
| Morpho | $2.5M USDC | Mar 2024 | |
| Pendle | $2M USDC | Jun 2024 | |
| Ondo Perps | $1.5M USDC | Jun 2026 | **web/API-only scope** |
| dYdX | $1M USDC | May 2026 | perps |
| Paxos | $1M USDG | Mar 2026 | private bounty |

## Step 2 — Bounty pages use UUIDs, NOT slugs
`https://cantina.xyz/bounties/ondoperps` → "Bounty not found". Correct form:
`https://cantina.xyz/bounties/<uuid>`.

Get the UUIDs from the list page via `browser_console`:
```js
Array.from(document.querySelectorAll('a')).map(a=>a.href)
  .filter(h=>h&&h.includes('/bounties/'))
  .filter((v,i,a)=>a.indexOf(v)===i)
```
Returned UUID order maps to on-screen card order (1st = top card, etc.).

## Step 3 — Read scope
Navigate to the UUID bounty → click the **Scope** tab → the **In-scope table** lists the
assets (web/app/API domains) with per-severity rewards. The Instructions tab has
severity definitions + payout guidance + KYC/eligibility + prohibited actions.

**Ondo Perps in-scope (web-only, no SC):**
- `ondoperps.xyz` — website
- `app.ondoperps.xyz` — web app (Vercel/Next.js)
- `api.ondoperps.xyz` — API (Cloudflare)

Rewards: Critical $1.5M, High $100K, Medium $20K, Low $1K. 77 findings already
submitted. KYC required to join. USDC on Ethereum.

## Step 4 — SPA API extraction (the productive part)
See pitfall #56 in the parent SKILL.md for the full `_buildManifest.js` + `_app.js`
recipe. Ondo Perps example result:

```
/v1/account                     /v1/account/notifications    /v1/account/referral
/v1/api_keys                    /v1/agreement                /v1/auth/erc-4361/login/...
/v1/invite_code/validate        /v1/markets
/v1/perps/collateral_balance    /v1/perps/twap/order         /v1/perps/twap/orders
/v1/perps/twap/orders/history   /v1/provision_address        /v1/referral_codes
/v1/sandbox_deposit             /v1/subaccounts              /v1/verify_eligibility
/v1/wallet/deposit_address/list /v1/wallet/deposits/
```
Auth = ERC-4361 (Sign-In With Ethereum) + web2 email/google.
Subaccounts + api_keys + wallet deposits = the IDOR/authz surface.
`/{id}` path params = horizontal-IDOR candidates.

## Step 5 — Baseline probe, then STOP (scope discipline)
Unauth probes: `/v1/markets` 200 (public), `/v1/account` + `/v1/api_keys` → `401
auth_missing`, `/health`/`/docs`/`/openapi.json`/`/swagger` 404. Confirm the gating is
correct, then STOP — testing authz/IDOR properly requires your OWN account (+ a second
account for cross-account IDOR). Hammering auth-gated endpoints without authorization
is out of scope on Cantina (prohibited actions) and wastes the session. Deliver an
authz test-plan (endpoint + payload matrix + 2-account steps) for manual execution.