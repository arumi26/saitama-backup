# Hardware-Wallet Web App Recon (Trezor Suite class)

Recon pattern for the WEB surface of a hardware-wallet ecosystem (Trezor,
Ledger Live web, Keystone, etc.). These targets are DIFFERENT from a normal
web app: the CSP is usually hardened, the app is often fully open-source, and
the real critical surface is funds-integrity, not reflected XSS.

## 0. Scope / program (Trezor, verified Aug 2026)

- Bug bounty is **direct email**, not a platform: `security@satoshilabs.com`
  (Signal encrypted channel offered for sensitive reports). Fits operators who
  prefer free direct-email submission with no platform KYC gate.
- Confirm via `curl -s https://trezor.io/.well-known/security.txt` →
  Contact + Policy (`/support/a/how-to-report-a-security-issue`) +
  Acknowledgments (github.com/orgs/trezor/discussions).
- **In scope:** "websites running at `*.trezor.io` operated by us" + Trezor
  devices/software/infrastructure.
- **Report must include:** Description + potential impact + **PoC code** +
  reproduction steps. Reward scales with severity; **first valid submission**
  only → dedup race matters, move fast on a real find.
- **Out of scope:** third-party-hosted (Medium/Twitter/FB/Cloudflare), DoS,
  physical + supply-chain attacks (separate track), best-practice-only reports.

## 1. Read the CSP first — it tells you which bug classes are dead

`suite.trezor.io/web/` (Suite web, v26.8.x, React/webpack, Sentry) headers:

```
CSP: default-src 'self'; script-src 'self' 'unsafe-eval'; script-src-attr 'none';
     style-src 'self' 'unsafe-inline'; img-src 'self' blob: data: https://*.trezor.io;
     connect-src data: *; object-src 'none'; base-uri 'none'; frame-ancestors 'self';
     frame-src 'self' trezorsuite://*; upgrade-insecure-requests;
     report-uri https://<sentry>/security/
COOP: same-origin | XFO: SAMEORIGIN | HSTS preload
Permissions-Policy: usb=(self) camera=(self) clipboard-write=(self) ... (rest OFF)
```

Read this literally:
- **No `unsafe-inline` in script-src** → reflected/stored XSS needs a real DOM
  sink or a script-injection primitive, not a plain HTML echo. Don't burn time
  spraying `<script>` payloads — they can't execute.
- `'unsafe-eval'` present (webpack/wasm need it) → a lead only if you can reach
  an `eval`/`Function` sink with attacker data; not directly exploitable.
- **`connect-src data: *` is wide open** → the one genuinely loose directive.
  Probe whether user-controllable data drives outbound `fetch`/XHR (SSRF-ish
  exfil channel, partner-URL injection). This is the highest-value CSP gap.
- `frame-ancestors 'self'` + COOP same-origin + XFO SAMEORIGIN → clickjacking
  and cross-origin framing are closed.
- `frame-src trezorsuite://*` → desktop deep-link scheme; note for the desktop
  app, not the web audit.

`connect.trezor.io` (Trezor Connect popup, AmazonS3-hosted): `COOP: unsafe-none`,
`XFO: DENY`, `script-src 'self' 'unsafe-eval' 'unsafe-inline'`. The `unsafe-none`
COOP + the popup/postMessage model is the interesting Connect surface.

## 2. Do NOT reverse minified chunks — the app is open-source

`main.*.js.map` on Suite web is live (HTTP 200) but only carries the webpack
runtime bootstrap + `suite-web/src/index.ts`; real logic is in lazily-loaded
chunks. Reversing those is the slow path. **The entire Suite + Connect are
open-source** (`github.com/trezor/trezor-suite` monorepo). Audit the source
directly against the live build version (grab it from the Sentry release id
baked into `main.*.js`, e.g. `SENTRY_RELEASE.id = "26.8.2.web.codesign.<sha>"`).
Same applies to any open-source wallet — GitHub source beats source-map digging.

## 3. Where the real (funds-affecting = critical) bugs live

Hardened headers mean the bug bar is integrity of what the user signs, not XSS:

- **Transaction-review integrity** — does the address/amount rendered in Suite
  match what's serialized to the device? Look for render-vs-sign mismatch,
  address substitution, clipboard/ENS resolution tampering, output reordering.
- **Swap/Buy partner flows (Invity)** — origin + `postMessage` trust between the
  partner iframe/popup and Suite; combined with `connect-src *` this is an
  exfil / parameter-injection surface.
- **DeFi vault interaction (Morpho / Steakhouse "Prime Vaults" in Suite)** —
  contract-address pinning, spoofed vault, approval-target confusion. (Note:
  smart-contract risk of the vaults themselves is out of Trezor's control and
  they say so; the in-scope bug is Suite pointing at the wrong contract.)
- **Trezor Connect `postMessage` origin validation** — the classic hardware-
  wallet web bug: does Connect validate the requesting origin before relaying a
  sign request? COOP `unsafe-none` on connect.trezor.io makes this worth a hard
  look.

## 4. Subdomain notes (subfinder on trezor.io, Aug 2026)

High-interest in-scope hosts beyond `suite`: `wallet`, `beta-wallet`,
`old-wallet` (legacy signing portals), `trade-dashboard`, `savings` (swap/vault
angle), `start`, `data.trezor.io` (+ `gitlab.data`, `remote.data`, `smtp.data`),
staging (`auth-staging`, `staging-exchange1/2`, `staging-cdn`). `app.trezor.io`
does NOT resolve; the web app is `suite.trezor.io/web/`.

## Takeaway rule

On a hardware-wallet web target: (1) read the CSP and cross off the dead bug
classes before testing, (2) if the app is open-source, audit source at the live
version instead of reversing chunks, (3) aim at signing-integrity /
postMessage-origin / partner-flow bugs — that's the path to a fundable critical,
not reflected XSS.
