# Web3 dApp Frontend Authz Hunting — IDOR + 2FA Bypass

**Class:** Modern web3 dApp frontend (Next.js SPA + REST/GraphQL API + JWT/session + optional TOTP) — perps DEX, lending, NFT marketplace, governance frontend. **NOT** smart contract code.

**Built from:** Aug 2026 Ondo Perps session (Cantina $1.5M Critical), applied methodology from JIRA/2FA/SAML/Methods/Beginner PDF cheat-sheets.

---

## Why this is high-value target class

- **Under-hunted vs SC.** Audit industry focuses on contracts. Frontend API IDOR = direct theft, often misses audits.
- **High payout ceiling.** Perps DEXs: Cantina $1.5M Critical, Immunefi up to $3M.
- **Repeatable methodology.** Same patterns across Ondo Perps, dYdX, Polymarket, Pendle, Morpho app.
- **Heterogeneous auth = authz gaps.** SIWE + Web2 + 2FA + API keys = many surfaces to mismatch.

---

## Phase 1 — Asset discovery (5 min)

```bash
# 1.1 Subdomain enum
curl -s "https://crt.sh/?q=%25.<target>&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > subs.txt
subfinder -d <target> -silent >> subs.txt

# 1.2 Live host probe
cat subs.txt | dnsx -silent 2>/dev/null | httpx -silent -status-code -title -tech-detect | tee live.txt

# 1.3 SPA bundle → full API surface (the gold)
curl -sL "https://<app>.<target>" -o app.html
grep -oE 'src="[^"]+\.js[^"]*"' app.html | sort -u
# For Next.js, _app.js + page chunks at /_next/static/chunks/
curl -sL "https://<app>.<target>/_next/static/chunks/main-XXXXXXXX.js" -o _app.js
curl -sL "https://<app>.<target>/_next/static/<BUILDID>/_buildManifest.js" -o bm.js

# 1.4 Extract API base + all /v1/ paths from bundle
grep -oE "https?://api\.[a-zA-Z0-9.-]+" _app.js | sort -u
grep -oE '"/v1/[a-zA-Z0-9./_{}?=&-]+"' _app.js | tr -d '"' | sort -u
```

**Output:** 25-60 endpoints (auth, account, subaccounts, api_keys, wallet, deposits, orders, perps). Each `{id}` path is an IDOR candidate.

## Phase 2 — Public-vs-Auth probing (no account needed, 1 min)

```bash
for p in "/v1/markets" "/v1/account" "/v1/api_keys" "/v1/health" "/v1/docs"; do
  code=$(curl -s -m10 -o /tmp/probe.json -w "%{http_code}" "https://api.<target>$p")
  echo "$code  $p  $(head -c 130 /tmp/probe.json)"
done
```

**Healthy:** Public = 200, Auth-gated = 401 `auth_missing`.
**Red flag:** Auth-gated returns 200 with partial data (info leak) OR 404 (enumeration).

## Phase 3 — IDOR matrix (the main course, 2-3 hours)

### Setup
1. Register 2 accounts (A & B) with separate wallets/emails
2. Generate API keys for both via UI
3. Capture Burp baseline traffic for both
4. Note each account's `account_id`, `subaccount_id[]`, `api_keys[]`, deposit addresses
5. Mint tiny positions: $1-5 deposit + 1 small TWAP order

**Critical: only test your own accounts.**

### Endpoint priority (per-value)

| Endpoint | Why high-value | Mutation pattern |
|---|---|---|
| `/v1/api_keys` | Full ATO if accessible | `?user_id=B`, body `{"user_id":"B"}` |
| `/v1/subaccounts/{id}` | Direct resource ID | Replace `A_id` with `B_id`; path traversal `../subaccounts/B` |
| `/v1/wallet/deposits/{id}` | Other users' deposit history | Replace deposit_id |
| `/v1/perps/twap/orders` | Other users' financial positions | `?owner=B_subaccount_id` |
| `/v1/perps/twap/order/{id}` (POST) | **Critical** — write-side | Body: `{"on_behalf_of":"B_subaccount_id",...}` |
| `/v1/wallet/deposit_address/list` | Other users' deposit addresses | `?user_id=B` |
| `/v1/perps/account/pledge` | Collateral ops on behalf of others | Body: `{"subaccount":"B_id"}` |

### Reading the response

**True IDOR when:**
- Response contains B's data with A's auth token → Critical (depending on field)
- `200 OK` for B's ID but `404`/`403` for random fake IDs (proves ownership check missing)

**False positives:**
- `401`/`403` for both A and B IDs (no leak)
- `404` for all IDs (no enumeration)
- A's data returned regardless of requested ID (frontend default fallback)

## Phase 4 — 2FA bypass (13 techniques, 1-2 hours)

| # | Test | Time | Likely impact |
|---|------|------|---------------|
| 1 | **Response manipulation** — Burp Repeater: failed-2FA response → mutate `{"success":true,"verified":true}` | 2 min | **Critical** if accepted |
| 2 | **Status code manipulation** — replace 401 with 200 + body | 2 min | Critical |
| 3 | **Code leakage in response** — trigger 2FA, inspect response | 2 min | High |
| 4 | **JS file analysis** — grep `_app.js` for hardcoded TOTP secret / test mode / default codes | 5 min | Critical if hardcoded |
| 5 | **Code reusability** — submit correct code twice within 5 min | 2 min | High |
| 6 | **Brute-force gap** — check rate-limit per IP/account | 10 min | Medium (do not execute bruteforce) |
| 7 | **Cross-user code integrity** — A's TOTP at B's verify endpoint | 5 min | High |
| 8 | **CSRF on 2FA disable** — check for CSRF token in disable request | 5 min | High |
| 9 | **Password reset disables 2FA** — walk forgot-password flow | 10 min | Critical (ATO via reset) |
| 10 | **Backup code abuse** — apply 1-7 to backup-code path | 5 min | depends on #1-7 |
| 11 | **Clickjacking on disable page** — check `X-Frame-Options` / `frame-ancestors` CSP on `/settings/security` | 2 min | Medium |
| 12 | **Stale sessions on 2FA enable** — login 2 devices, enable 2FA on A, is B session still valid? | 5 min | High |
| 13 | **Null / 000000 / empty** — submit `"000000"` or `null` or `""` | 2 min | Critical if accepted |

**Top 3 highest-yield:** #1, #13, #9. Quick to test, frequent wins.

## Phase 5 — Quick-win misc (5 min)

### 5.1 Security headers
```bash
for u in "https://<target>" "https://app.<target>" "https://api.<target>"; do
  curl -sI -m12 "$u" | grep -iE "x-frame|content-security|strict-transport|x-content-type|access-control-allow-origin|access-control-allow-credentials"
done
```

**Reportable:** `ACAO: *` + `ACAC: true` on API endpoints (CSRF via origin reflection).

### 5.2 Source map leak
```bash
for js in main-XXXXXXXX.js framework-XXXXXXXX.js; do
  url="https://<app>.<target>/_next/static/chunks/$js"
  src=$(curl -s -m8 "$url" 2>/dev/null | grep -oE 'sourceMappingURL=[^"]*' | head -1)
  if [ -n "$src" ]; then
    map_url="$url.map"
    code=$(curl -sI -m8 "$map_url" 2>/dev/null | head -1)
    [ "${code:9:3}" = "200" ] && echo "FOUND: $map_url"
  fi
done
```

If `.map` files public → full Next.js source readable. Audit `pages/api/*` for auth checks, 2FA verification, role gates.

### 5.3 Subdomain probe
Run `crt.sh + subfinder` for `staging.*`, `dev.*`, `api-staging.*`, `admin.*`, `debug.*`. Often hidden surfaces.

## Phase 6 — 14-point triage gate (mandatory)

Every finding must pass ALL:
1. In scope — endpoint on program's listed asset table
2. Reproducible 5x — different IP, cleared cookies, fresh session
3. Root cause — explain *why* (missing ownership check, client-controlled `verified` flag)
4. Realistic impact — theft of funds, ATO, data breach (no theoretical)
5. Affected users — single, all, or specific tier
6. Uniqueness — check Hacktivity for prior reports
7. Severity — Critical/High/Medium/Low per program
8. CVSS 3.1 — proper vector
9. CWE — IDOR=CWE-639, 2FA bypass=CWE-287+352, CSRF=CWE-352
10. Attack scenario — clear end-to-end
11. PoC quality — replayable curl + screenshots
12. Fix recommendation — concrete code
13. Ethical guardrails — only your accounts, no data taken, no DoS
14. **Confidence ≥85%** — if unsure, don't submit

## Time budget & realistic yield

| Phase | Time | Yield |
|-------|------|-------|
| Recon + API mapping | 30-60 min | — |
| Public probing | 1 min | 0-1 Low |
| IDOR matrix | 2-3 hr | **1-3 Critical/High** |
| 2FA bypass | 1-2 hr | 0-2 Medium |
| Misc (headers, source map) | 15 min | 0-1 Low, **0-1 Critical if maps leak** |
| Triaging | 30-60 min | required gate |
| Submission | 30 min | — |
| **Total** | **6-10 hours** | **2-6 reportable** |

**Realistic on a fresh (≤90 days) program:** 0-1 Critical IDOR, 0-1 Critical 2FA bypass, 1-3 Medium-Low.

## Variations across web3 dApps

Same methodology applies to:
- **Spot DEXs** — `/v1/orders`, `/v1/balances` IDOR
- **Lending protocols** — `/v1/positions`, `/v1/collateral` IDOR + liquidation abuse
- **NFT marketplaces** — `/v1/listings`, `/v1/offers` (critical forgeries)
- **Bridge frontends** — `/v1/transfers`, `/v1/signatures` (replay attacks)
- **DAO frontends** — `/v1/proposals`, `/v1/votes` (governance manipulation)
- **Token swap frontends** — `/v1/swap`, `/v1/quote` (price/amount mutation)

Pattern: any **multi-user stateful platform** with REST/GraphQL has the same surface.

## Tools

| Need | Tool |
|------|------|
| Subdomain enum | subfinder, crt.sh, assetfinder |
| Live probe | httpx, dnsx |
| JS bundle analysis | grep + unfurl |
| HTTP capture | **Burp Suite** (essential for Repeater/Intruder) |
| Auth header decode | jwt.io |
| TOTP 2FA | Google Authenticator / Authy |
| API replay | curl + Burp Repeater |
| IDOR enumeration | Burp Intruder on `{id}` position |

**Burp Suite is non-negotiable** for the IDOR/2FA workflow. Replaces 5+ hours of manual curl scripting.

## Worked example — Ondo Perps (Aug 2026, Cantina $1.5M Critical)

- 38 subdomains → 11 live
- Next.js SPA (`app.ondoperps.xyz`) + Cloudflare API (`api.ondoperps.xyz`)
- 28+ `/v1/` endpoints extracted from `_app.js`: `auth/erc-4361`, `auth/web2`, `account`, `subaccounts`, `api_keys`, `wallet`, `perps/twap/*`
- Auth: SIWE + Web2 + optional 2FA, returns `401 auth_missing` on gated endpoints
- 77 findings already submitted (early-stage, ~2.5 months live)
- Test-plan delivered with 13 IDOR probes + 13 2FA bypass tests
- Real execution blocked: requires user's own 2 accounts (KYC needed for fiat deposit)

## Submission template

```markdown
# Title: [Severity] [Component] - [Type] allows [Impact]

## Summary
One paragraph.

## Severity & CVSS
- Severity: Critical
- CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N → 9.1
- CWE: CWE-639 (Authorization Bypass)

## Vulnerability Details
- Component: https://api.<target>/v1/<endpoint>
- Description: <root cause>

## Steps to Reproduce
1. Login as User A
2. Capture authorized request to `/v1/<endpoint>`
3. Replace `user_id` parameter with User B's ID
4. Observe response contains User B's data

## PoC
```bash
curl -H "Authorization: Bearer <JWT_A>" \
  "https://api.<target>/v1/<endpoint>?id=<B_USER_ID>"
```

## Impact
Attacker with their own account can read/modify other users' [data/funds] by enumerating/replacing resource IDs.

## Fix Recommendation
Add ownership check in handler:
require(apiKeys[userId].owner == msg.sender, "Unauthorized");

## Environment
- Date: <date>
- Tools: Burp Suite, curl
- Test accounts: A, B (researcher-owned)
```

## Critical reminders

- **Only test your own accounts.** 2 accounts with KYC is the minimum.
- **Don't DoS / spam.** Respect rate limits; one probe at a time.
- **Stop at first Critical.** Save evidence, don't exploit further.
- **Triaging before submission is non-negotiable.** A 0.36 N/A ratio burns your reputation.
- **Patch window = 60-90 days** for escrow programs before public disclosure.
