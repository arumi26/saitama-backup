# Case study — Next.js / XPR-Network dApp marketplace render review

A worked pass over a Next.js frontend where agents write listings, deliver files, and set
profile fields that other users then view in a wallet-connected origin. Kept as a reference
for **what "already hardened" looks like** so the next review can recognise it quickly and
spend effort where it matters instead of re-reading clean code.

Target shape: `pages/` router, Tailwind, `@proton/web-sdk`, four on-chain contracts
(`agentcore`, `agentfeed`, `agentvalid`, `agentescrow`), plus `next/og` image routes.

## Sink inventory found

| Sink | Data source | Verdict |
|------|-------------|---------|
| `dangerouslySetInnerHTML` ← `renderMarkdown()` | agent-written reports / `.md` deliverables | **safe** — custom renderer, escape-first |
| `dangerouslySetInnerHTML` ← `JSON.stringify(jsonLd)` | static, no attacker field | safe (no attacker data in the object) |
| `href={service.sample_uri}` / `{file.uri}` / `{evidenceUrl}` | on-chain `evidence_uri`, `sample_uri` | bounded by scheme allowlist + strict CSP |
| `href={`/services/${replacement.id}`}`, `{/agent/${service.agent}}` | parsed integer / account name | safe by construction |
| `<iframe src={first.uri} sandbox="allow-scripts">` | deliverable PDF | **correct** — no `allow-same-origin` |
| `router.push(...)` | internal paths only | safe |
| OG card route → server-side `fetch(attackerUrl)` | on-chain image URI | **safe** — full SSRF guard, see below |

Notable: no `eval`, no `new Function`, no `__proto__` / `Object.assign(JSON.parse(...))`,
no `innerHTML` anywhere outside the Markdown path. Secrets sweep found only contract account
names (`eosio.token`) and `--api-key sk-ant-xxx` placeholders in **documentation code
blocks** — not live credentials. `.env.example` contained only public `NEXT_PUBLIC_*` config.

## The Markdown renderer (the interesting file)

Hand-rolled, ~190 lines, deliberately not CommonMark. The safety argument is one invariant,
stated in its own header comment:

> Everything is HTML-escaped before any markup is added — including both quote characters,
> because link and image values are placed inside quoted attributes, and an unescaped `"`
> there closes the attribute and lets agent text append its own (`onerror=…`). … Only the
> tags produced here reach `dangerouslySetInnerHTML`, and nothing is un-escaped after the
> escape pass.

Verification points that made it hold up:

1. `escapeHtml` covers `& < > " '` — **both quote forms**, which is the whole ballgame.
2. `applyInline()` is **not exported**, with a comment explaining that calling it on raw
   text would put agent input straight into attributes. Good API design as a security control.
3. The one pre-escape regex (`<cite…>` stripping) only *removes* content — it cannot
   introduce a character or decode an entity.
4. No post-escape decode step anywhere.
5. URL captures are constrained to `https?:\/\/` in both the link and image patterns.
6. Emitted tags are a fixed allowlist; no variable tag names.
7. `dangerouslySetInnerHTML` output is only ever `renderMarkdown(...)`.

The accompanying test file fed the output into a real DOM and asserted on surviving
elements/attributes — the honest way to test a renderer.

## CSP (the backstop)

```
default-src 'self'
script-src 'self' 'wasm-unsafe-eval'          ← no 'unsafe-inline', no 'unsafe-eval'
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com
img-src 'self' data: blob: https:
connect-src 'self' https: wss: blob: data:
frame-src 'self' https:
worker-src 'self' blob:
object-src 'none'
base-uri 'self'
form-action 'self'
frame-ancestors 'none'
upgrade-insecure-requests
```

`script-src 'self'` with no inline/eval means an injected inline `<script>`, an `onerror=`
attribute, or a `javascript:` URL is refused by the browser **even if it reaches the DOM**.
That is what downgrades any escaping slip on this path from "account takeover in a
wallet-connected origin" to "cosmetic". The broad `connect-src`/`img-src` are a product
requirement (deliverables come from arbitrary gateways), not an oversight — say so.

`style-src 'unsafe-inline'` is present for server-rendered style attributes and the Markdown
renderer's inline styles. CSS cannot execute script; the `script-src` line is what matters.

## The OG-card route (server-side SSRF)

`/api/og/{jobs,services}/[id]` reads an item, takes `firstImageUri(evidence_uri)`, and
fetches that URL **server-side** to embed as a data URI. That URL is attacker-controlled.

The guard was already complete:

- `isPublicHttpsHost()` — parses the URL, **rejects non-`https:`**, checks a literal IP
  directly via `isIP()`, otherwise `lookup(host, { all: true })` and requires **every**
  resolved address to be public. Fails closed on unparseable.
- Full private-range table including `169.254/16` (cloud metadata), CGNAT `100.64/10`,
  `192.0.0.0/24`, `198.18/15`, `>=224`; IPv6 branch covering `::ffff:` IPv4-mapped,
  `64:ff9b` NAT64, `fe80::/10`, `fc00::/7`.
- `redirect: 'manual'` with an explicit 3xx → `null`. Comment even names the bypass:
  *"a public host could 302 to one"*.
- `content-type` allowlisted to rasterisable types; `content-length` **and** actual
  `arrayBuffer().length` both bounded at 8 MB.
- `AbortController` timeout (3.5 s) on the fetch, separate tighter budget (3 s) for the
  item lookup.
- Errors swallowed into a static-card fallback; stack traces only in a `?debug=1` branch
  gated on `NODE_ENV !== 'production'`.

The only thing left to note is that the guard lives in `lib/og-image.ts` and is called from
`lib/og-route.ts` — so any *future* route that fetches a user URL must be checked against
this pattern, not assumed to inherit it.

## Transferable takeaways

1. Comments in this class of codebase describe **intended** properties — treat them as a map
   of where to look, then verify each claim against the implementation.
2. The Markdown renderer being correct says nothing about the OG route. Finish each surface.
3. `sandbox="allow-scripts"` **without** `allow-same-origin` is the correct iframe shape for
   untrusted PDFs/HTML. The presence of both together is the finding.
4. Strict `script-src` is the single highest-leverage mitigation for this whole bug class —
   check it early, because it calibrates the severity of everything else.
5. "On-chain" ≠ trusted. Anyone who can write a listing or deliver a job controls those
   strings.
6. A review box with no `node_modules` (disk full) does not block this work: CSP, code
   reading, and the `node:dns`/`node:net` guard logic all need zero install. Mark genuinely
   version-dependent questions (e.g. React's `javascript:` href handling for the *installed*
   version) as **unverified** rather than asserting either way.
