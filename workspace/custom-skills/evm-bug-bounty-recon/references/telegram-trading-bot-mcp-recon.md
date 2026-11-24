# Telegram Trading Terminal / MCP-Server Recon Surface

New web3 product class (2026): non-custodial **Telegram trading bots** that also expose an
**MCP (Model Context Protocol) JSON-RPC endpoint** so AI agents can trade on the user's behalf.
Wallets are embedded (Privy), funds move gaslessly cross-chain, and there is usually a marketing
Next.js site + Mintlify docs + Railway-hosted API backends. This is the passive recon recipe and
surface map.

## Host / subdomain pattern
Enumerate with crt.sh + hackertarget, then sweep `code|redirect|size`:

```bash
for h in www docs api app production staging privy admin status; do
  r=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}|%{size_download}" --max-time 8 -L "https://$h.$TARGET")
  echo "$h.$TARGET → $r"
done
```

Typical finds:
| Host | Tech | Notes |
|---|---|---|
| `www` | Next.js / Vercel | marketing only (terms/privacy — read the ToS here) |
| `docs` | Mintlify | 3rd-party → OOS; **but the docs are the map**: `/llms.txt` + per-page `.md` |
| `production` / `staging` | Railway | API backends; `staging` frequently left public |
| `privy` | Privy API reverse proxy | thin passthrough to `auth.privy.io` |
| apex `/api/mcp` | MCP server | documented, often 307→404 until account is granted access |

## Docs mining (Mintlify)
`https://docs.$TARGET/llms.txt` is the full page index. Fetch any page as raw markdown by
appending `.md` (e.g. `/builders/mcp-tools.md`, `/builders/deep-links.md`, `/essentials/security.md`).
This is where the MCP URL, auth scheme, tool list, and deep-link encoding are documented.

## Health-endpoint probes (safe, passive)
```bash
curl -s https://production.$TARGET/api/health   # {"status":"ok","timestamp":"..."} = live backend
curl -s https://production.$TARGET/healthz       # "ok"
curl -s https://staging.$TARGET/api/health       # public staging = info disclosure (LOW)
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://$TARGET/api/mcp   # 405 = route exists, wrong method
```
`/api/health` leaking `{"status":"ok","timestamp":...}` is **LOW / informational** — do not inflate.

## MCP endpoint recon (read-only, no auth)
Documented shape: `POST https://$TARGET/api/mcp`, header `Authorization: Bearer <token>`,
JSON-RPC 2.0 over Streamable HTTP, **one request per call** (batches → 400).
```bash
curl -s -X POST "https://$TARGET/api/mcp" -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
curl -s -X POST "https://$TARGET/api/mcp" -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
```
Unauth → `307` redirect to www → `404` means the endpoint is **not publicly active** (only for
granted accounts). The **authz split to test IF authorized**: read token vs read-write token vs
per-wallet "money-out" permission, and per-tool spending limits. A token that escalates
read→write or bypasses money-out = critical. **Do not test without written authorization.**

## Privy proxy recon
`privy.$TARGET` is a reverse proxy in front of Privy's API. Probe the standard Privy paths:
```bash
for p in /api/v1/wallets /api/v1/users /api/v1/sessions /api/v1/transactions /api/v1/analytics_events; do
  curl -s --max-time 8 "https://privy.$TARGET$p" | head -c 200; echo
done
```
- `{"error":"Privy app ID must be attached to the request header privy-app-id","code":"missing_or_invalid_privy_app_id"}` → passthrough confirmed; the proxy does **not** inject the app-id.
- `{"error":"missing required parameters"}` on `/sessions`, `/siwe/init`, `/oauth/init`.
- `405` on `/analytics_events` (exists, wrong method).
Header probe: `-H "privy-app-id: test"` → `Invalid Privy app ID`. Interesting-but-untestable
without auth: app-id handling, session flow, Telegram `initData` validation on mini apps.

## Telegram deep-link parser (Base62)
Documented in `/builders/deep-links.md`. Payload rides the Telegram `/start` param (64-char limit,
fixed-width Base62 segments):
- `g_{amount}{chainCode}{base62Token}` — group buy (fixed USD)
- `b_...` — market buy panel
- `gs_{percent}{chainCode}{base62Token}` — group sell
- `ref_{ref}-{tokenAddress}` — referral
- optional 14-char tail `{7-char-affiliate}{7-char-group}`, use `0000000` for empty
Token width: 27 chars EVM, 43 chars Solana. Chain codes: e=1 b=8453 n=56 a=42161 m=4326
s=Solana t=4217 o=143 y=1514 h=999 p=9745 r=4663 i=57073 l=988 x=196 v=43114.
**Untestable-without-auth hypotheses:** amount/percent overflow, affiliate/group ID injection,
Base62 decode confusion. Report only if authorized.

## Authorization gate (do this FIRST)
This class is usually **not** on a bounty platform. Run the gate before any active probing:
1. `curl -s -o /dev/null -w '%{http_code}' https://www.$TARGET/.well-known/security.txt` (and every host).
2. Immunefi / HackerOne / Bugcrowd / Cantina / Hats / Sherlock listing → 404 = not listed.
3. Read `www.$TARGET/terms` — a "Prohibited Activities" clause banning "interfere with the
   integrity, security, or proper functioning of any computer/server/network" + "reverse engineer"
   with **no security-contact exception** = no safe harbor.
4. No public GitHub org/repo = no source-audit path.
→ All four fail ⇒ passive-only. Map the surface on paper, stop before fuzzing.

## Worked example (Cove, 2026-09)
`cove.trade` — Genesis block0 Corp, non-custodial Telegram trading terminal, 16 chains,
Privy wallets, Husher (Private Disperse + Wallet Marketplace) + MoonPay partners.
Live: www (Vercel/Next.js), docs (Mintlify), production + staging (Railway), privy (proxy).
`cove.trade/api/mcp` documented (66 tools) but 307→404 (not public). No security.txt, no
Immunefi/H1/Bugcrowd, no GitHub org, ToS bans access testing → **passive recon only**.
Findings kept: staging `/api/health` public (LOW), prod health timestamp leak (LOW),
privy-proxy passthrough confirmed (INFO). Zero reportable — correct outcome.
