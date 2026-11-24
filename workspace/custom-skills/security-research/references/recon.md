# Reference: Reconnaissance Methodology (v3)

> Unrestricted reconnaissance. Map everything. Leave no asset undiscovered.

## Principles
Recon = mapping the **full attack surface**. Goal: know everything exposed, what's interesting,
where bugs are most likely. Order: **passive → active → targeted**. Passive doesn't touch
target directly; active probes directly. Go as deep as needed.

---

## 1. Passive Recon (no direct target contact)

- **Certificate Transparency**: crt.sh, censys — discover subdomains from certificates.
- **DNS & WHOIS history**: passive DNS, DNS archives for old/forgotten assets.
- **Search engine dorking**: `site:`, `inurl:`, `filetype:` operators for exposed files.
- **Wayback / archives**: historical endpoints & parameters that may still be alive.
- **Public code repos**: GitHub/GitLab for org repos, leaked secrets, TODO comments, configs.
- **Passive tech fingerprint**: BuiltWith, public headers, favicon hashes.
- **ASN & IP ranges**: map IP blocks owned by org from public data.

**Output**: candidate subdomain list, suspected technologies, historical assets, info leaks.

---

## 2. Active Enumeration

- **Subdomain enumeration**: brute force + resolve. Verify which are alive.
- **Port & service discovery**: open ports + service/version banners.
- **Content discovery**: hidden directories/endpoints via wordlists. Start small, scale up.
- **Parameter discovery**: hidden parameters on endpoints (arjun, param-miner).
- **Crawling / spidering**: map application flow, forms, JS endpoints, API calls from frontend.
- **JS analysis**: parse JavaScript for endpoints, frontend API keys, feature flags, logic.
- **JS bundle deep-dive**: unpack .js.map, grep for API endpoints/internal
  routes not in public docs — client-side code often leaks server logic
  that should've stayed server-side. Full process in
  `JS / MOBILE DEEP ANALYSIS` below.
- **Source map extraction**: unpack `.js.map` files to recover original source.
- **Swagger/GraphQL discovery**: `/swagger.json`, `/api-docs`, introspection queries.
- **.git / .env hunting**: exposed git repos, environment files, backup files.

---

## 3. Attack Surface Mapping

| Aspect | What to record |
|---|---|
| Entry points | All endpoints/params accepting user input |
| Auth surface | Login, password reset, SSO, tokens, session management |
| Roles & tenancy | Different access levels, multi-tenant boundaries |
| Sensitive data | Where money/PII/secrets flow |
| Tech stack | Frameworks, versions, dependencies (for known CVEs) |
| Trust boundaries | Where data crosses trust zones |

---

## 4. Prioritization

Rank by:
1. **High-value functions**: payments, auth, uploads, admin panels, internal APIs, integrations.
2. **Complexity**: new/complex features more fragile than mature ones.
3. **Trust boundaries**: role/tenant/user transitions = IDOR/authz bug goldmine.
4. **Forgotten assets**: old subdomains, leaked staging, deprecated API versions.

**Output**: ranked test candidates, each with vulnerability class hypothesis.

---

## Anti-patterns
- Collecting 10,000 subdomains but never analyzing any deeply.
- Running every tool at once without reading output.
- Active scanning wildcards that include out-of-scope assets.
- Skipping passive recon and going straight aggressive (loses context + noisy).

---

# RECON PLAYBOOK — SYSTEMATIC OBJECTIVE

## OBJECTIVE

Build the broadest useful attack-surface map before deep testing.

Do not confuse asset discovery with vulnerability discovery.

---

## DISCOVERY — UNIFIED ASSET TYPES

Identify:

* domains
* subdomains
* applications
* APIs
* authentication endpoints
* admin interfaces
* storage
* cloud assets
* repositories
* smart contracts
* deployments
* RPC endpoints
* bridge endpoints
* documentation
* public configuration

---

## WEB2 ATTACK SURFACE MAP

Map:

* login
* registration
* password reset
* session management
* authorization
* APIs
* file upload
* file download
* SSRF candidates
* redirects
* webhooks
* integrations
* admin functionality
* object identifiers
* GraphQL
* WebSocket

---

## WEB3 ATTACK SURFACE MAP

Map:

* contracts
* proxy implementations
* upgrade authorities
* ownership
* roles
* oracles
* price feeds
* tokens
* vaults
* routers
* liquidation
* staking
* rewards
* governance
* bridges
* cross-chain messaging
* deployment differences

---

## SOURCE MAPPING

For each important component determine:

* source repository
* branch/commit
* deployment address
* chain
* compiler
* proxy implementation
* upgrade mechanism
* dependencies

Source-to-deployment mapping is where diff-based bugs live: deployed bytecode
that diverges from public repo, or two deployments of the same repo with
different constructors/configs.

---

## ACTIVE RECON

Do not stop at passive discovery.

For every interesting asset:

1. identify technology;
2. identify trust boundaries;
3. identify sensitive functions;
4. identify privileged operations;
5. identify user-controlled inputs;
6. identify external dependencies;
7. generate attack hypotheses.

Each hypothesis → verify phase (`verification-and-poc.md`) → never stay at hypothesis.

---

## JS / MOBILE DEEP ANALYSIS

Goal: treat the client bundle (web JS or mobile app binary) as a map of
the server's internal surface that the devs forgot is public.

### Web JS process
1. Enumerate every JS file (main bundle + chunks + vendor + source
   maps if exposed). Pull with a simple crawler or `httpx` + grep on
   `<script src=`.
2. If `.map` files are exposed (check `/path/app.js.map`), pull them —
   source-map unpacking reconstructs original file/folder structure,
   which often reveals internal module names, feature flags, and
   comments devs never meant to ship.
3. Run `linkfinder` (or equivalent regex sweep) across every bundle to
   extract endpoint-shaped strings: relative paths, `/api/`, `/v1/`,
   `/internal/`, `/admin/`, GraphQL operation names, WebSocket URLs.
   Diff this list against what you've actually seen in traffic — the
   delta is your target list of UNDOCUMENTED endpoints.
4. Run `secretfinder`/entropy-based regex across bundles for: API
   keys, JWT signing hints, hardcoded creds, internal hostnames,
   S3/GCS bucket names, third-party service tokens (Stripe, Firebase,
   Algolia, Sentry DSN). Firebase configs and loosely-scoped cloud
   keys are consistently high-value here.
5. Grep for feature-flag / role logic done CLIENT-SIDE: patterns like
   `if (user.role === 'admin')`, `isBeta`, `featureFlags[`, config
   objects fetched once and cached. If a "hidden" feature is gated
   only in the UI, hit the underlying endpoint directly — the server
   check is often missing or looser than the client's.
6. Extract and diff GraphQL: if introspection is off, mine bundles for
   operation names/fragments used by the app, then replay each query
   manually with a low-priv token to test authorization per-field, not
   just per-endpoint.
7. For SPA route tables (React Router / Vue Router config embedded in
   bundle), enumerate routes that aren't linked anywhere in the UI —
   admin panels, internal tools, debug pages often live at reachable
   but unlinked routes.

### Mobile-specific additions
1. Unpack the APK/IPA (apktool / jadx for APK, class-dump or a
   decompiler for IPA) and repeat steps 3–5 against decompiled
   sources/strings, plus `strings` on the binary for quick wins.
2. Check for endpoints/hosts that only exist in mobile builds, not the
   web app — mobile-only APIs are less scrutinized and frequently
   missing checks the web equivalent has.
3. Intercept traffic with a proxy (Burp/mitmproxy) + cert-pinning
   bypass (objection/Frida) — compare mobile API responses to web ones
   for the same account; mobile often returns MORE fields (over-fetch
   → info disclosure) because the client is trusted to filter.
4. Check for hardcoded API keys/secrets in the binary that differ from
   web (mobile builds ship more often with debug/staging keys left
   in).

### Output of this step
Feed every discovered endpoint/param/operation name into normal
fuzzing + auth-matrix testing (IDOR, BOLA, missing rate limit) — this
step's job is purely SURFACE DISCOVERY, not exploitation.

---

## MONITOR FOR CHANGES

Principle: new code is buggy code. Being the first person to test a
change — a deploy, a contract upgrade, a new endpoint — beats being the
most skilled tester of old, already-hammered code.

### What to monitor per target
1. **JS bundle hashes** — diff bundle filenames/content hashes on a
   cron. A changed hash = new deploy = re-run the JS deep-analysis
   step above on the diff, not the whole bundle, to spot new
   endpoints/flags fast.
2. **Subdomains/DNS** — continuous subdomain enum, not one-time. New
   subdomain appearing = likely new service, often stood up without
   the same hardening as the main app (staging, internal tools,
   acquisition integration).
3. **Certificate Transparency logs** — new cert issuance for the
   target's domain/wildcard often precedes a new subdomain going
   live; catching it at cert-issuance time gets you there before the
   service is even linked anywhere.
4. **GitHub/GitLab orgs** — watch commits, new repos, and especially
   force-pushes or deleted-then-recreated branches (often used to
   scrub a leaked secret — the secret is still in the reflog/cache
   for a window).
5. **Job postings / changelog / status page / release notes** —
   announce upcoming features, new tech stack, new third-party
   integrations before they're public-facing; each is a preview of
   next attack surface.
6. **Smart contract specific**: watch for proxy upgrade events, new
   contract deployments from the same deployer address, governance
   proposals scheduling an upgrade. Test the upgraded implementation
   the moment it's verified on-chain, before liquidity/usage ramps up.
7. **Mobile app store listings** — version bump = pull the new
   APK/IPA immediately and diff against the previous decompiled
   version for new endpoints/logic.

### How to operationalize
- Automate with cheap, boring tooling: cron job + `httpx`/`subfinder`
  for subdomains, a hash-diff script for JS bundles, a CT-log watcher
  (e.g. via `certstream`), GitHub API polling for target orgs, RSS/
  webhook watch on changelog and status pages.
- Keep a per-target baseline snapshot (subdomain list, JS bundle
  hashes, contract bytecode hash) so diffs are cheap to compute.
- Prioritize testing time on WHAT CHANGED, not the whole target —
  this is the actual edge: not smarter, just faster to the new
  surface.
- Set a personal SLA: new deploy/subdomain/contract detected →
  initial pass within hours, not days. Value of a diff decays fast
  once other hunters' tooling catches the same change.

---

## RECON OUTPUT — ASSET REGISTER

Every asset should receive:

```
ASSET
TYPE
SOURCE
DEPLOYMENT
TECHNOLOGY
TRUST BOUNDARY
INTERESTING FUNCTIONS
POTENTIAL ATTACK SURFACE
STATUS
```

Status values:

```
UNKNOWN | CANDIDATE | VERIFIED | OUT_OF_SCOPE
```

Never mark a target safe solely because automated discovery found nothing.

An empty scan result is UNKNOWN, not safe — absence of discovery is not
evidence of absence of attack surface.
