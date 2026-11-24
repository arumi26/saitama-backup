# Next.js dApp Recon Recipe (bundle env mining + testnet kill signal)

Case: Lotus Protocol / Lotus Labs (`loanscape.lotuslabs.net`, `staging.lotuslabs.net/vaults`,
`lotus-api-staging.onrender.com`) — 2026-09. Verdict: **KILL** — testnet-only, no program,
unverified source. But the recon path is reusable for any Next.js web3 dApp.

## 1. Next.js bundle harvest (always first)

```bash
curl -s "https://TARGET/" -o home.html
grep -oE '/_next/static/chunks/[^"]+\.js' home.html | sort -u > chunks.txt
while read c; do curl -s "https://TARGET$c" -o "$(echo "$c"|md5sum|cut -c1-8).js"; done < chunks.txt
```

Then mine the concatenated chunks:

```bash
# NEXT_PUBLIC_* env vars actually inlined into the client bundle — GOLD
cat *.js | grep -oE 'NEXT_PUBLIC_[A-Z0-9_]+' | sort -u
# Values: the assigned literal sits right after the key
cat *.js | grep -oE 'NEXT_PUBLIC_(API_URL|TOLGEE_API_KEY|WALLETCONNECT_PROJECT_ID|VAPID_PUBLIC_KEY|VERCEL_GIT_COMMIT_SHA)["'\'']?[:=]["'\'']?[^"'\'',;} ]{0,80}' | sort -u
# Internal API routes referenced by the app
cat *.js | grep -oE '"/v[0-9]/[a-zA-Z0-9/_-]+"' | sort -u
# Supabase / JWT / API keys
cat *.js | grep -oE 'eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{10,}' | sort -u
```

**What this yields:** `NEXT_PUBLIC_API_URL` → the real backend (e.g. `https://lotus-api-staging.onrender.com`),
`NEXT_PUBLIC_VERCEL_GIT_COMMIT_SHA` → exact deploy commit, plus the full internal API route map.
`NEXT_PUBLIC_*` are **public by design** — not a finding on their own, but they hand you the backend to probe.

**Source maps:** check `/<chunk>.js.map` — 404 on Vercel/Next prod is normal; 200 = full source recovery.

## 2. Backend API enumeration (from the discovered base)

```bash
API="https://<api-base>"
curl -s "$API/v1/health"            # liveness
curl -s "$API/v1/deployments"       # <-- deployment/contract map endpoint (see §3)
curl -s -D - -o /dev/null "$API/"   # header fingerprint (server, x-render-origin-server, etc.)
# Route fuzz (read-only GETs only)
for r in health auth/nonce auth/session deployments prices notifications faucet ...; do
  printf "/v1/%-20s %s\n" "$r" "$(curl -s -o /dev/null -w '%{http_code}' "$API/v1/$r")"
done
```

Fastify (Node) fingerprint: `{"message":"Route GET:/x not found","error":"Not Found","statusCode":404}`.
Auth-required endpoints return `401 {"message":"Session token required"}` — good, auth enforced.

## 3. Deployment-info endpoints leak the whole contract map

`GET /v1/deployments` returned every chain's deployer, block number, and **full contract address
map** (lotus, riskEngine, oracle, fuses, factories, vaults, tokens). This is by-design for the
frontend but is the fastest way to map the real on-chain surface without any explorer.
Also check `/v1/prices`, `/v1/chains`, `/v1/config`.

## 4. TESTNET-ONLY KILL SIGNAL (the decisive gate)

Check every chainId the app knows about:

```bash
curl -s "$API/v1/deployments" | python3 -c "import sys,json;print(list(json.load(sys.stdin)['deployments'].keys()))"
# 1337 / 31337 / 84532 / 11155111 / 421614 / 97 / 80002  = testnet / devnet
# 1 / 8453 / 42161 / 10 / 137                              = mainnet
```

**Public anvil node = red flag for "dev chain exposed as prod":**

```bash
curl -s -X POST "$RPC" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}'
# "anvil/v1.8.1"  -> Foundry dev node, NOT a real chain
curl -s -X POST "$RPC" ... -d '...{"method":"eth_accounts"...}'
# returns 11 default anvil accounts (0xf39fd6e5..., mnemonic "test test ... junk") = known keys, zero value
curl -s -X POST "$RPC" ... -d '...{"method":"anvil_nodeInfo"...}'   # dev-only admin method answers = unhardened
```

**Kill signal:** all deployments on testnet/devnet + contracts unverified on explorer +
no public source (GitHub org has only image repos) + fork of a known OSS codebase (IPOR Fusion) +
no bounty program. → **No payout, no authorization → KILL, do not exploit.** Testnet + default
anvil keys = no real funds at stake even if a contract bug exists.

## 5. Pitfalls confirmed this session

- **Escaped reflection ≠ XSS.** `?pair=<script>alert(1)</script>` on a Next.js RSC app echoed back
  as `\u003cscript\u003ealert(1)\u003c/script\u003e` **inside** a `<script>self.__next_f.push(...)`
  block. JSON/JS-string escaping means the payload can never break out of the string context.
  Always read the RAW bytes around the reflection (`python3 -c "print(repr(d[i-400:i+200]))"`) and
  check whether it landed in an HTML attribute vs a JS string, and whether `<`/`>` were escaped.
  Test a real breakout vector (`"><img src=x onerror=alert(1)>`) before claiming XSS.
- **CORS reflect-any-origin without `Access-Control-Allow-Credentials`** is a non-finding when auth
  is a `Bearer` token (not cookies). `evil.example.com` echoed in `access-control-allow-origin` +
  `vary: Origin` alone = Low/Info at best. Confirm credentials header AND that auth is cookie-based
  before escalating. (Same rule as the flaunch case.)
- **`eth_accounts` returning default anvil accounts** is a testnet/dev fingerprint, not a
  "leaked private keys" finding — those keys are the well-known Foundry test mnemonic.
- **GitHub API returning `null` / `message`** → rate-limited or org private; retry once, don't
  conclude "no repos" from a single null.

## 6. Report verdict shape (for this user)

Deliver a compact table: Gate result (program? security.txt? mainnet? verified source?) →
findings table with **realistic severity** (Info/Low only here) → "no high/critical" →
next-step options. No inflated severity, no "$X bounty" guesses. See `bb-methodology` user rules.
