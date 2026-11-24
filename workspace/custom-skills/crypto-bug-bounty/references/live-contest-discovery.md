# Live Contest / Bounty Discovery via Direct APIs

When `web_search` / `web_extract` are paywalled (Firecrawl BILLING_ERROR 402) or the
platform pages are JS-rendered SPAs that return only HTML shells, hit the platforms'
JSON APIs directly with `curl` (via the `terminal` tool). These endpoints are unauthenticated
and return machine-readable contest/bounty lists.

## Sherlock (audit contests + public bug bounties)
```bash
curl -sL -m 20 -H "User-Agent: Mozilla/5.0" "https://mainnet-contest.sherlock.xyz/contests?page=1"
# paginate with ?page=2, ?page=3 ; response has {items:[...], next_page: N|null}
```
Each item: `status` (RUNNING / SHERLOCK_JUDGING / FINISHED), `starts_at`, `ends_at`
(unix), `rewards`, `prize_pool`, `title`, `short_description`, `private` (bool),
`type_label`. **Filter live:** `starts_at <= now <= ends_at and not private`.
Most listed items are FINISHED/JUDGING — a truly-open submission window is rare.

## Cantina (competitions)
```bash
curl -sL -m 20 -H "User-Agent: Mozilla/5.0" "https://cantina.xyz/api/v0/competitions?status=live"
```
Returns a JSON array. Per item: `name`, `url`, `company`, `timeframe.{start,end}` (ISO-8601),
`status`, `totalRewardPot`, `currencyCode`, `instructions` (full markdown: scope, repo,
commit, in-scope impacts, out-of-scope, mandatory-PoC rule, prior audits), `kycRequired`,
`allowedSeverities`, `cantinaTriaged`.
**Pitfall:** `?status=live` returns ~140 items but MOST have already-passed `timeframe.end`
(the API's "live" flag is stale). Compute `days_left = (end - now)` and keep only `> 0`.
Fetching a single competition by id (`/api/v0/competitions/<id>`) returned `{type,msg}`
error in testing — parse the fields from the list response instead.

## Immunefi
`https://immunefi.com/public-api/bounties/` and the bounties page return a Next.js HTML
shell (not JSON) to curl. Use the browser tool or parse `__NEXT_DATA__` from the HTML if
you must; otherwise rely on Sherlock/Cantina which expose clean JSON.

## Reading a Cantina competition's scope (what to extract before cloning)
From `instructions` markdown, pull: **Repository** + **Commit** hash + **Files** (usually
`src/`), **In-Scope Impacts** (the ONLY impacts that pay — e.g. "funds to non-whitelisted
addresses", "funds permanently locked"), **Out of Scope** (oracle/NAV/price manipulation,
whitelisted-party misbehaviour, MEV/gas/frontrunning, centralization, external-protocol
bugs — all common exclusions), **Mandatory PoC Rule** (all High/Med need coded PoC), and
**Previous Audits** (in repo `audit/` dir — issues there are OUT OF SCOPE).

## Maturity read (EV calibration)
A contest that already shows `totalFindings > 0`, is `cantinaTriaged`, and ships 2+ prior
audit PDFs in `audit/` is MATURE: low-hanging fruit is gone. Realistic yield in the last
few days is Medium (rounding/griefing/DoS), not High. Read the prior audit PDFs FIRST
(`pdftotext -layout audit/*.pdf`), extract every finding title, and treat them as
out-of-scope duplicates — then hunt only what they missed (deep accounting/invariant bugs).
