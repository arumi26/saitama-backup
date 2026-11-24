
# Untrusted Content Rendering Audit

A class of bug that recon tools and scanners miss: the app is *architecturally* fine
(auth, CSRF, SQLi all clean) but it takes a string written by party A and renders it into
the browser session of party B. Every XSS, HTML-injection, and SSRF in this class lives at
a **sink**, not at an endpoint. You find them by reading the render path, not by fuzzing.

## When this applies

Any app where a non-first-party controls display text:

- marketplace / job board / classified listings (seller writes title + description + files)
- AI agent or LLM output rendered back to a user (reports, summaries, notes)
- on-chain data (memo fields, evidence URIs, NFT metadata, account names)
- user profiles, bios, support-ticket bodies, CMS/rich-text fields
- uploaded "deliverables", attachments, or samples with preview UI
- server-side link-preview / OpenGraph card routes

The tell that this class is in play: a comment or doc-string in the codebase saying
something like *"written by agents/users and rendered into this wallet-connected origin"*.
Take those comments literally — they mark the trust boundary the authors already knew about.

## Workflow

### 1. Enumerate every render sink

Grep, don't guess. Run each of these and read the hits:

```bash
# Raw HTML injection
grep -rn "dangerouslySetInnerHTML\|innerHTML\|outerHTML\|insertAdjacentHTML\|v-html\|\[innerHTML\]" src

# URL-bearing attributes fed a variable (not a literal)
grep -rn "href={\|src={\|action={\|formAction={" src
grep -rn "<iframe\|<embed\|<object\|sandbox=" src

# Server-side template / string concat into HTML
grep -rn "res.send(\|res.end(\|text/html" src/pages/api src/app/api 2>/dev/null

# Custom renderers (the interesting ones)
grep -rn "renderMarkdown\|toHtml\|markdown\|sanitize" src
```

### 2. Trace provenance — which sinks actually receive attacker data

A sink is only a finding if untrusted data reaches it. For each sink, walk backwards to the
source. In these codebases the source is usually a contract read, an indexer response, or a
JSON blob inside a delivery payload.

Rank sinks by reachability. On-chain/indexer data is attacker-controlled the moment *anyone*
can write a listing, deliver a job, or set a profile field — it is not "trusted because it
came from the chain".

### 3. Audit the escaping invariant of any custom renderer

If the app hand-rolls Markdown → HTML (very common — they want a small subset), the whole
safety argument rests on ONE invariant:

> **Escape the entire input first, then insert markup tags. Never un-escape anything after
> the escape pass.**

Check, in order:

1. Does `escapeHtml` handle `&`, `<`, `>`, **`"` AND `'`**? Missing quotes is the classic
   bug: link/image values land inside quoted attributes, so an unescaped `"` closes the
   attribute and the attacker appends `onerror=…`.
2. Is there any pre-pass regex that runs on **raw** text before escaping (e.g. stripping
   `<cite>` wrappers, normalising tags)? That is fine *if it only removes*. It is a bug if
   it decodes entities or introduces characters.
3. Is there any post-escape step that decodes `&amp;` → `&`? That re-opens the attribute
   injection. URLs should stay entity-escaped inside `src`/`href` — browsers decode them.
4. Does the inline pass only ever emit `https?://` URLs? A regex that allows arbitrary
   schemes in `[label](url)` is a `javascript:` sink.
5. Are the emitted tags limited to a fixed allowlist (h1-h3, ul/li, table, pre/code, a, img,
   strong, hr, br, p)? Anything that passes through a variable tag name is a bug.

Write/keep a test that feeds the output into a real DOM and asserts no unexpected element or
attribute survived — the only honest way to verify a renderer is to render it.

### 4. Check CSP — the backstop that turns a bug into a non-event

A strong CSP is why an escaping slip in this path is *not* automatically RCE-equivalent.
Look for:

- `script-src 'self'` with **no** `'unsafe-inline'` and **no** `'unsafe-eval'` → injected
  inline `<script>`, `onerror=`, and `javascript:` URLs are all refused by the browser.
- `object-src 'none'`, `base-uri 'self'`, `form-action 'self'`, `frame-ancestors 'none'`.
- `style-src 'unsafe-inline'` is acceptable here (CSS cannot execute script); note it but
  don't call it a finding.
- `connect/img/media https:` is broad by design when deliverables come from arbitrary hosts.
  Broad but not script-executing.

If script-src is strict, downgrade any XSS-shaped finding accordingly and say so explicitly —
honest severity triage is the deliverable, not maximum alarm.

### 5. URL attributes: verify, don't assume

`href={attackerString}` and `src={attackerString}` are the second-most-common sink.

**Do not assume the framework blocks `javascript:`.** React's URL handling has changed
across versions and does not reliably neutralise dangerous schemes in `href` on every
release. The durable answer is defence in depth:

- an explicit scheme allowlist at the sink (`/^https?:\/\//i.test(u)` or an
  `ipfs://` → gateway rewrite), and
- `script-src 'self'` so even a successful `javascript:` href is inert.

Verify against the **installed** version if `node_modules` is present. If you cannot verify
(e.g. install absent), say "unverified for this version" rather than asserting either way.

Note the genuinely-safe-by-construction cases: `href={`/jobs/${Number(id)}`}` on a parsed
integer, and template-built internal paths where every interpolated part is a known account
name or numeric id.

### 6. iframes embedding attacker files

`sandbox="allow-scripts"` **without** `allow-same-origin` is correct for untrusted PDFs and
HTML: scripts run in an opaque origin that cannot touch the parent. Flag
`sandbox="allow-scripts allow-same-origin"` — that combination defeats the sandbox.
Also check `referrerPolicy="no-referrer"` is set.

### 7. Server-side: review every route that fetches a user-supplied URL

This is where the real severity usually is, because the request comes from the **server's**
network position — cloud metadata, internal admin panels, localhost services.

For each route that takes a URL from user/attacker data (OG/link-preview cards, avatar
proxies, "import from URL", webhook testers, PDF/image renderers):

- [ ] Host is resolved and **every** resolved IP checked against private ranges
- [ ] Literal IPs in the URL are checked directly (bypasses DNS entirely)
- [ ] `redirect: 'manual'` — otherwise a public host 302s to `169.254.169.254`
- [ ] Response `content-type` allowlisted before decode
- [ ] `content-length` **and** actual body length bounded (header can lie)
- [ ] Timeout via `AbortController` on every outbound fetch
- [ ] Errors swallowed into a safe fallback, not surfaced with stack traces

See `references/ssrf-guard-pattern.md` for the full private-range table, the IPv6 cases
that are usually missed, and a known-good guard implementation to compare against.

## Pitfalls

- **Trusting chain/CMS data.** "It's on-chain" / "it's in our database" is not provenance.
  Whoever can write the row is the attacker. Ask *who can write this field*, not where it
  is stored.
- **Assuming framework sanitisation.** React/Vue escape *text children* automatically — that
  is why `{m.text}` is safe. They do **not** protect `dangerouslySetInnerHTML`, `v-html`,
  or URL attributes. Distinguish the two cases explicitly instead of blanket-claiming
  "the framework handles XSS".
- **`JSON.stringify` for JSON-LD.** A `<script type="application/ld+json">` fed
  `JSON.stringify(obj)` will break out if any value contains `</script>`, because
  `JSON.stringify` does not escape `<`. Check for it; it's only exploitable when the
  stringified object contains attacker data.
- **Reading the comment instead of the code.** Doc-comments in this class of codebase often
  describe the *intended* security property. Verify each claim against the implementation —
  the comments are a map of where to look, not evidence.
- **Declaring "hardened" from one good file.** The Markdown renderer being correct says
  nothing about the OG route. Complete each surface separately before summarising.
- **Scanner-only verdicts.** No scanner finds "attacker string reaches a custom renderer
  with a missing quote-escape". This class requires reading. Budget the time.
- **Disk-full / no `node_modules` on a review box.** Don't let it turn into a claim either
  way — mark unverifiable items as unverified, and lean on CSP + code reading, which need no
  install. (Disk-space recovery itself is a separate, environment issue — see
  `evm-bb-toolchain-vps` for the `no space left on device` playbook.)

## Deliverable shape

Report per surface, not per file: **sink → provenance → reachable? → mitigated by CSP? →
severity**. Explicitly list what you checked and found clean, with the reason it is clean
(e.g. "quote-escaping present", "scheme allowlist", "redirect: manual"). A short list of
"verified safe because X" is far more useful to the next reviewer than a vague all-clear,
and it protects you from re-doing the same reading next session.

## Case study

`references/nextjs-dapp-render-review.md` — a full pass over a Next.js/XPR-Network dApp
marketplace: the exact sink inventory, the hardened Markdown renderer (with the invariant
spelled out), the strict CSP, and the OG-card SSRF guard that was found correct. Useful as a
worked example of what "already hardened" looks like so you can recognise it fast.
