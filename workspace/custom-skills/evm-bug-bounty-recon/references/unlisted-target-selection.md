# Unlisted Target Selection — DM-First Hunting Funnel

## When to use
User asks "next target?" / "biar gua DM dulu projectnya" — i.e. they want a target they can
**DM directly** (direct responsible disclosure), NOT one that forces a platform submission.
The gate is: *if the project is on a bounty platform, you must report through the platform and
you cannot cold-DM them with a finding.* So platform absence is a **hard filter, checked first**.

## The funnel (order matters — cheap filters first)

| Step | Source | Filter | Cost |
|---|---|---|---|
| 1 | `api.llama.fi/protocols` (~3000 protocols, ~8MB) | `audits == 0`, category has real on-chain Solidity | 1 curl |
| 2 | same payload | `listedAt` recent (new code = unaudited code) | free |
| 3 | same payload | TVL band **$15M–$350M** | free |
| 4 | bounty-targets-data + Immunefi sitemap | **not on any platform** | 5 curls |
| 5 | chain explorer API | source **verified on-chain** | 1-3 curls |
| 6 | docs site | team reachable + audit-scope gap | 1 curl |

Steps 1-3 cut 3000+ → ~64. Step 4 cuts to a handful. **Never deep-dive before step 4** —
an audited-and-listed target wastes the whole session.

### TVL band rationale
- **<$15M** → no money to pay, and the team often has no security budget at all.
- **>$350M** → heavily watched, dup risk high, and every finding is already known.
- **$15M–$350M** → they can pay, they have real funds at stake, and the crowd is thin.

### Category shortlist (categories that mean real Solidity to read)
`Lending`, `CDP`, `Yield Aggregator`, `Basis Trading`, `Leveraged Farming`, `Derivatives`,
`Options`, `Synthetics`, `Restaking`, `Bridge`, `Onchain Capital Allocator`, `DEX`.
**Skip** `RWA` / `CEX` / `RWA Lending` — usually off-chain bookkeeping with a thin token wrapper,
no interesting on-chain logic no matter how big the TVL number looks.

### `audits` field caveat
`audits: 0` on DeFiLlama ≠ unaudited. Teams under-report. Always confirm on the docs site
(step 6) before calling it an audit gap. The reverse is the valuable signal — see
"Audit-scope gap" below.

## Step 4 — Platform-coverage check (the decisive filter)

### A. H1 / Bugcrowd / Intigriti / YesWeHack / Federacy (bulk, one shot)
`arkadiyt/bounty-targets-data` republishes every public program daily as raw JSON. No auth.

```bash
cd /tmp
for f in hackerone bugcrowd intigriti yeswehack federacy; do
  curl -s -L --max-time 60 \
    "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/${f}_data.json" \
    -o "${f}_data.json" -w "$f: http=%{http_code} bytes=%{size_download}\n"
done
```

These are **wildcard/scope** dumps (451 H1, 279 Bugcrowd, 146 Intigriti, 58 YWH ≈ 934 rows),
not a clean program list. Match on the flattened blob, then **context-check every hit**:

```python
import json, glob, os
def walk(o, out):
    if isinstance(o, dict):
        for v in o.values(): walk(v, out)
    elif isinstance(o, list):
        for v in o: walk(v, out)
    elif isinstance(o, str): out.append(o)

for f in glob.glob('/tmp/*_data.json'):
    strs = []; walk(json.load(open(f)), strs)
    blob = " | ".join(strs).lower()
    for term in CANDIDATES:
        i = blob.find(term)
        if i >= 0:
            print(f"HIT {term}: ...{blob[max(0,i-70):i+50]}...")
```

**PITFALL — substring matching produces false positives.** `tydro` "matched" only because of
`safe`**`tydro`**`nes.com` in an unrelated scope. Always print ±70 chars of context and read it.
A hit without visible context is not a hit. (`cooler`, `re7`, `ethena` also matched this way.)

### B. Immunefi (bulk, one shot) — use the DYNAMIC sitemap
Immunefi is a Next.js SPA; there is no public JSON API. `robots.txt` names the real sitemap:

```bash
curl -s --max-time 45 https://immunefi.com/sitemap-dynamic.xml -o /tmp/smd.xml
grep -oE 'bug-bounty/[^<]+' /tmp/smd.xml | sed 's|bug-bounty/||' | sort -u
```

Returns ~241 URLs including every `/bug-bounty/<slug>/` program. Grep your candidate list
against it — a name absent from this list has no Immunefi program.

**PITFALLS on the way there (don't burn cycles):**
- `https://immunefi.com/sitemap.xml` returns **HTTP 200 but zero `<loc>` entries** — a decoy.
  Always count `<loc>` before concluding anything from a sitemap.
- `/public-api/bounties`, `/api/bounties`, `/graphql` → **404** (308 then 404).
- `_next/data/<buildId>/...` → no `buildId` in the RSC payload (`self.__next_f.push`), so the
  classic Next.js data-route trick does not apply here. Use the sitemap.
- A 400KB `bug-bounty/` page contains a few program names (Chainlink, Aave, Wormhole, Ethena)
  but **not the full list** — do not treat it as an inventory.

### C. Per-project probe (fallback when A+B are inconclusive)
The skill's existing dual-URL probe still applies:
`https://immunefi.com/bug-bounty/<project>/` and `https://immunefi.com/bounty/<project>/` →
404 on both = no program.

**Homonym trap (already in SKILL.md, restated because it bites here):** open the page and
confirm the org's domain/product matches your target before concluding "listed".

## Step 5 — Verified source on niche / non-mainstream chains

Mainstream explorers (Etherscan V2 needs a key) are often not the answer. **Blockscout v2 API
works unauthenticated on most EVM chains** — including chains Etherscan doesn't cover:

```bash
# Ethereum / Base / Optimism / Arbitrum / Gnosis
curl -s "https://eth.blockscout.com/api/v2/smart-contracts/<ADDR>"
# Ink (Kraken L2)
curl -s "https://explorer.inkonchain.com/api/v2/smart-contracts/<ADDR>"
```

Fields that matter: `is_verified`, `name`, `language`, `source_code`,
`additional_sources` (count = multi-file project), `proxy_type` (`eip1967` = implementation
behind it), `implementations`.

**Ink also has name search** — useful when docs give you nothing but a product name:
```bash
curl -s "https://explorer.inkonchain.com/api/v2/search?q=<ProjectName>"
# returns items[] with address_hash, is_smart_contract_verified, name, symbol, token_type
```

**Existence check via plain RPC** (works on any chain, incl. HyperEVM
`https://rpc.hyperliquid.xyz/evm`):
```bash
curl -s -X POST $RPC -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getCode\",\"params\":[\"$ADDR\",\"latest\"]}"
# result == "0x" -> nothing deployed; byte length/2-1 = runtime size
```

**PITFALL — Sourcify returns HTTP 200 + an HTML page for unknown contracts.**
`https://repo.sourcify.dev/contracts/full_match/<chain>/<addr>` and the `server/files/any/...`
endpoint returned **200 with a 21KB Next.js HTML document** for every Rysk address — verified
or not. **Never infer "verified" from the status code.** Check `content-type` / body shape, or
prefer Blockscout. (`/metadata.json` on the same path returned a real 404 — inconsistent.)

**Proxy addresses need one more hop.** `name: TransparentUpgradeableProxy` /
`OwnedUpgradeabilityProxy` means the source you got is the *proxy*, not the logic. Read the
implementation slot (EIP-1967: `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`)
or the explorer's `implementations` field, then re-query the implementation.

## Step 6 — Docs recon (two tricks, both fast)

### GitBook: append `.md`, or read `llms.txt`
Any GitBook-hosted docs page returns clean Markdown at `<page-url>.md`, and `/llms.txt` is a
full doc index:
```bash
curl -s "https://docs.<project>.com/llms.txt"
curl -s "https://docs.<project>.com/<section>/<page>.md"
```
This beats scraping the JS-rendered HTML (GitBook pages are React + `__NEXT_DATA__` blobs).

### Audit-scope gap = the hunt direction
Read the project's own audit page and look for a scope disclaimer. A fork of a well-audited
base will say something like:

> "The lending base is the Aave V3 codebase, which has been independently audited across
> multiple rounds by six firms and formally verified by Certora. Tydro then adds its own
> modules... **A deployment's own code and modifications are not covered by audits of the base.**"

That sentence is a **map**: the base is picked clean, and the team has publicly acknowledged
that their custom layer is unaudited. Audit the fork's *deltas* — the modules that don't exist
upstream. On an Aave fork that means things like a `Dustbin` (post-liquidation dust accounting),
`ConfigEngine`, `E-Mode` logic, credit-delegation, and any custom oracle wrapper.

### Reachability
Confirm a live team channel before recommending the target: `twitter` field on the DeFiLlama
payload + a `@handle` on the site. No reachable team = no DM = dead target for this workflow.

## DM opener template (no bug location, no platform named)

> Hi — I've been auditing the <Project> deployment on <chain> (the <base> stack + your custom
> contracts).
>
> I found what looks like an exploitable issue in your deployment-specific code. I'd rather
> hand it to you privately first, before anything else.
>
> Who's the right person for a security report, and is there a reward/bounty for valid findings?

Rules (user mandate): first DM names **no platform** and **no bug location**. Ask about reward
*before* handing over the finding. Only send after a concrete finding exists — a DM that says
"I'm looking at your code" gets ignored.

## Session results — 2026-09 (worked example)

Funnel output: 3000+ protocols → 64 no-audit EVM candidates → 2 finalists.

| | **Tydro** | **Rysk v12** |
|---|---|---|
| Chain | Ink (Kraken L2) | HyperEVM + Ethereum |
| TVL | $139M supplied / $66M borrowed | $60M + $10.5M |
| Code | Aave V3 full stack + custom modules | new primitive, built from scratch |
| Audit | Zellic Aug 2026 — **only the "Multiply" + "Payload" features** | none found |
| On platform | no (absent from all 5 datasets + Immunefi sitemap) | no |
| Source on-chain | verified, full Aave map (Pool, ConfigEngine, Dustbin, ACL…) | proxy only, impl needs slot read |
| DM | @tydrohq | @ryskfinance |

**Winner: Tydro** — verified source available immediately, $139M TVL, and its own docs state the
custom deployment layer is outside the audit scope. Rysk has higher bug density but the source
takes an extra hop (Cloudflare-gated explorer + proxy slot).

**Useful detail:** DeFiLlama's `/protocol/<slug>` endpoint returns the full contract list under
`chainTvls`, plus `twitter`, `url`, `audits`, `audit_links`, `listedAt`, `hacks`, `raises` —
one call replaces most of the recon.

## Pitfalls recap
1. **Substring hits are not hits** — print context, read it (`safetydrones` ⊃ `tydro`).
2. **`sitemap.xml` can be a 200-with-zero-loc decoy** — count `<loc>` first; `sitemap-dynamic.xml`
   is the real one on Immunefi.
3. **Never infer Sourcify verification from HTTP 200** — it serves an HTML page either way.
4. **A verified proxy address is not the audited logic** — read the impl slot and re-query.
5. **`audits: 0` on DeFiLlama is unreliable in both directions** — confirm on the docs site.
6. **Don't deep-dive before the platform check** — a listed target forces platform submission.
