
# Browser-Extension Wallet Audit

Bug-bounty audit workflow for MV3 browser-extension crypto wallets. The extension
is often the LEAST-contested surface on a wallet's bounty program (everyone piles
onto the smart contracts / web app), and the reward ceiling is high because a real
renderer/IPC break = key access. This skill is the repeatable recon + attack-surface
map. Pair with `triage-validation` and `report-writing` before submitting.

**Sibling surface — web dApp connector (Trezor Connect / Suite web).** When the
target is a hardware wallet, the same "page data → signing path without an origin
gate" hunt applies to the web companion (`suite.trezor.io`) and its Connect SDK
popup (`connect.trezor.io`), where the trust boundary is `postMessage` +
`BroadcastChannel` + iframe/popup handshakes. See
`references/hardware-wallet-web-connector-audit.md` — includes the sparse-checkout
recipe for auditing the Trezor Suite monorepo without cloning it whole, the full
dapp→device origin-trust chain map with per-file checks, and the honest "this is
post-audit hardened, pivot to swap/vault integrations" verdict (Trezor, Aug 2026).

## 0. Get the CRX and unpack it (reusable recipe)

Chrome Web Store extension ID is the 32-char string in the URL
(`chromewebstore.google.com/detail/<name>/<ID>`). Download the CRX from Google's
update service, then strip the CRX3 header to get a plain zip.

```bash
EXTID="aholpfdialjgjfhomihkjbmgjidlcdno"   # Exodus Web3 Wallet
CRX="https://clients2.google.com/service/update2/crx?response=redirect&os=linux&arch=x64&os_arch=x86_64&nacl_arch=x86-64&prod=chromiumcrx&prodchannel=unknown&prodversion=120.0.0.0&acceptformat=crx2,crx3&x=id%3D${EXTID}%26uc"
curl -sL -A "Mozilla/5.0 h1-<yourH1user>" "$CRX" -o ext.crx     # 302->redirect to CDN

# CRX3 = 'Cr24' magic + uint32 version + uint32 header_len + protobuf header + ZIP
python3 - <<'PY'
import struct
d=open('ext.crx','rb').read()
assert d[:4]==b'Cr24'
ver=struct.unpack('<I',d[4:8])[0]; hlen=struct.unpack('<I',d[8:12])[0]
open('ext.zip','wb').write(d[12+hlen:])
print('crx v%d header %dB zip@%d'%(ver,hlen,12+hlen))
PY
mkdir unpacked && (cd unpacked && unzip -oq ../ext.zip)
```

Then read `manifest.json` first — it defines the entire trust boundary.

## 1. Manifest triage — the trust boundary

```bash
python3 -c "import json;m=json.load(open('unpacked/manifest.json'));[print(k,'=',json.dumps(m.get(k))[:300]) for k in ['manifest_version','permissions','host_permissions','externally_connectable','content_scripts','web_accessible_resources','background','content_security_policy']]"
```

What each field means for the audit:

| Field | Attack angle |
|-------|--------------|
| `content_scripts[].matches` | Which origins get the injected provider. A `https://*/*` match = every site talks to the content script (expected for wallets). A **second** content script with a curated allowlist (e.g. `content-connect-banner.js` on 42 dApp origins) is where hardcoded-origin bugs live. |
| `externally_connectable` | If set, listed sites can `chrome.runtime.sendMessage` DIRECTLY to background. Absent/default = **no external messaging** (good — page must go through content script). |
| `web_accessible_resources` | HTML/JS reachable via `chrome-extension://<id>/...` from web pages. Framed extension HTML + weak CSP = clickjacking / data-leak surface. |
| `content_security_policy.extension_pages` | `default-src 'self'` with no `unsafe-inline`/`unsafe-eval` blocks injected `<script>`. Note `connect-src https: wss: data: blob:` is common and permits fetch exfil if you already have script exec. |
| `background.service_worker` | The privileged core — key material, signing, connectedOrigins state. Usually a multi-MB minified bundle; grep it, don't read it. |

## 2. Map the content-script <-> background bridge

The renderer break you want: page-controlled data reaching a privileged sink
without an origin/approval gate. Grep the (small) content script:

```bash
cd unpacked
for kw in 'addEventListener("message"' onMessage postMessage '.origin' sender senderMetadata isTrusted targetOrigin; do
  echo "== $kw =="; grep -oc "$kw" content.js
done
```

Key checks (Exodus v26.6.25 findings as the reference shape):
- **Inbound message origin check** — legit code gates on `t.origin===window.location.origin` before trusting `message` events. Missing/weak check = any frame can inject provider RPC.
- **senderMetadata** — content script attaches `{title, icon}` from the PAGE (attacker-controlled) and forwards to background. Background must NOT use this as a trust signal, only as display. Trace where `senderMetadata`/`connectionInfo.origin` is consumed.
- **Background origin source** — the trustworthy origin is `sender.origin` / `sender.tab` (set by Chrome), NOT anything from the message body. Grep background for `sender.origin` vs message-derived origin.
- **Enumerate which content-script methods are actually CALLED from page-reachable code**, not just schema-defined: `grep -oE 'C4\.[A-Za-z]+\(' content.js | sort -u` (adapt the bridge-object name). A well-built wallet exposes ONE dApp entry (e.g. `sendInpageRequest`); the 30+ privileged methods (`getPrivateKey`, `getPhraseForAccountDangerously`, `importPhrase`) sit on the schema but are never invoked from the page path.

**Seed-leak router check (highest-paying class — recovery-phrase/key leak).** Wallets
route extension-UI calls through a SEPARATE channel from the dApp bridge (e.g.
`__glow_background_request` → `qY[type](payload, sender)`). The make-or-break question:
can a secret-export handler be reached from a **content script on an attacker page**, or
is it gated to extension pages (`popup.html`/`prompt.html`)? The router MUST validate
`sender.url`/`sender.origin`/`sender.tab` is an extension page before running secret
handlers. Also compare the password source of each exporter: a literal `password` arg
needs re-auth (safe); one using the **cached temp-password** (`getTempPassword()`) is
silent — safe if UI-only, CRITICAL if page-reachable. Full recipe + Glow v0.61.0 worked
example: `references/mv3-background-router-sender-gate.md`.

## 3. Origin-trust model (connect / auto-approve)

Wallets keep a `connectedOrigins` store with per-origin flags. Grep background:

```bash
for kw in connectedOrigins isTrusted isAutoApprove setAutoApprove approveTransactions approveMessage ensureTrusted AUTO_CONNECT; do
  echo "== $kw =="; grep -oc "$kw" background.js
done
```

Understand the gate hierarchy before claiming impact (this is where severity is won or lost):
- `trusted:true` typically only skips the **connection-approval prompt**, not signing.
- `autoApprove` (if present) skips **transaction/message** prompts — but is usually
  default `false` and only settable by explicit per-origin user action = NOT
  attacker-reachable. Verify this in code before assuming tx auto-sign.
- `approveTransactions` / `approveMessage` still fire even for trusted origins in a
  correctly-built wallet. If you can reach a signing path with NO approve call for an
  attacker-controlled origin, THAT is the critical.

## 4. Dangling-domain in a hardcoded allowlist (the finding this skill was built on)

Wallets hardcode dApp origins that get elevated treatment (auto-connect, connect
banner, curated integrations). If any of those domains has **lapsed**, an attacker
registers it and inherits the elevated trust.

```bash
# 1) extract every hardcoded https origin from content scripts + manifest matches
grep -oE 'https://[a-z0-9.*-]+' content.js content-connect-banner.js 2>/dev/null \
  | sed -E 's#^https?://(\*\.)?##; s#/.*##' | sort -u > /tmp/origins.txt
python3 -c "import json;m=json.load(open('manifest.json'));[print(x) for cs in m['content_scripts'] for x in cs.get('matches',[])]" \
  | sed -E 's#^https?://(\*\.)?##; s#/.*##' >> /tmp/origins.txt
sort -u /tmp/origins.txt -o /tmp/origins.txt

# 2) flag NXDOMAIN roots (candidate = registerable)
while read d; do
  st=$(dig @1.1.1.1 "$d" A +noall +comment 2>/dev/null | grep -oE 'status: [A-Z]+' | head -1)
  echo "$d -> $st"
done < /tmp/origins.txt | grep -i NXDOMAIN
```

Confirm registrability rigorously (don't claim available off one signal):
- **DNS**: `dig @1.1.1.1 <d> A +noall +comment` shows `status: NXDOMAIN` across
  multiple resolvers (1.1.1.1 / 8.8.8.8 / 9.9.9.9).
- **RDAP** (authoritative, HTTP, no rate-limit like whois): resolve the TLD's RDAP
  base from IANA bootstrap then query — `objectClassName:"error"` / `errorCode:404`
  = not registered.
  ```bash
  BASE=$(curl -s https://data.iana.org/rdap/dns.json | python3 -c "import json,sys;d=json.load(sys.stdin);[print(s[1][0]) for s in d['services'] if 'markets' in s[0]]")
  curl -s "${BASE}domain/mango.markets" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('objectClassName'),d.get('errorCode'))"
  ```
- **Historical proof it mattered**: `crt.sh/?q=<domain>&output=json` shows the domain
  had certs (was a real dApp) before it lapsed — strengthens the report. crt.sh
  rate-limits/500s intermittently; retry with `-A Mozilla/5.0` and a short sleep.

**Honest severity (critical to get right for this class):** a registerable domain in
an *auto-connect* allowlist = attacker site loads pre-`trusted:true`, skipping the
connection prompt and leaking wallet address + phishing legitimacy. It is **Medium**
(maybe High) — NOT Critical — because transaction/message signing still requires user
approval. A domain in a *connect-banner-only* list is even lower. Do not inflate to
Critical; H1 triagers on wallet programs downrank inflated dangling-domain reports.
It becomes Critical only if you also prove a signing-path bypass for that origin.

## 4b. Beyond the extension: org-level infra + npm supply-chain recon

When the extension itself proves hardened, pivot to the wallet vendor's broader
surface before declaring the target exhausted. Two high-EV, low-contest angles:

**Infra / internal services.** Enumerate subdomains and probe the live ones. Wallet
vendors run dev/ops tooling (Coder workspaces, AI gateways, status pages, admin
panels) on `*.ot.<domain>` / `*.ai.<domain>` style hosts. Most sit behind Cloudflare
Access SSO (`*.cloudflareaccess.com` redirect on `/auth`) or CF Bot Management (403
"Firewall Triggered") — those are dead ends, note and move on. Check unauth surface:
`/healthz`, `/api/v2`, `/v1/models`, buildinfo endpoints often 200 and leak version
strings (e.g. Coder `v2.34.5`) but the actionable APIs return 401. A 200 buildinfo is
recon, not a finding.

**npm dependency-confusion (with the critical false-positive gate).** If the vendor
publishes packages (`@vendor/*`) and you have their monorepo, harvest every dep and
check which are unpublished:

```bash
python3 - <<'PY'
import json,glob,urllib.request,urllib.error,concurrent.futures
deps=set()
for pj in glob.glob('/path/to/repo/**/package.json',recursive=True):
    try:
        d=json.load(open(pj))
        for k in ('dependencies','devDependencies','optionalDependencies','peerDependencies'):
            deps.update((d.get(k) or {}).keys())
    except: pass
def chk(n):
    try: return (n, urllib.request.urlopen(urllib.request.Request('https://registry.npmjs.org/'+urllib.request.quote(n,safe='@/'),headers={'User-Agent':'x'}),timeout=10).getcode())
    except urllib.error.HTTPError as e: return (n,e.code)
    except Exception as e: return (n,str(e)[:20])
miss=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=25) as ex:
    for n,c in ex.map(chk,sorted(deps)):
        if c==404: miss.append(n); print('404:',n)
print(f'{len(deps)} deps, {len(miss)} unpublished')
PY
```

**CRITICAL — a 404 does NOT mean exploitable.** Before getting excited by a wall of
unpublished `@vendor/*` names, verify the scope is claimable:
- npm reserves a scope the moment ANY package under it is published. If `@vendor` has
  even one published package, **non-members cannot publish `@vendor/anything`** — every
  404 under that scope is a private/internal package that is *unregisterable by an
  attacker*. Dependency-confusion is **BLOCKED**. Confirm:
  `curl -s https://registry.npmjs.org/@vendor%2fsome-published-pkg | python3 -c "import json,sys;print([m['name'] for m in json.load(sys.stdin).get('maintainers',[])])"`
  — a returned maintainer proves the scope is owned.
- Dependency-confusion is only live for **UNSCOPED** internal names (bare `foo-internal`)
  that 404, OR scoped names whose entire scope is unclaimed. Filter to unscoped 404s and
  check those specifically; if zero, the vector is dead — do not file it.

Filing a dep-confusion report against a claimed scope = invalid/informative and burns
triager goodwill. Kill the false positive yourself before it reaches a report.

## 4c. Mobile app in scope — decide BEFORE sinking time into an APK pull

Wallet programs almost always scope the iOS + Android apps too (Glow: iOS, Android, Safari
ext, browser ext). Once the extension proves hardened, weigh the mobile surface against two
hard constraints BEFORE decompiling:

- **`attacker must NOT have physical access to an unlocked device`** (near-universal wallet
  clause) kills most *static* mobile findings — `allowBackup`, exported activities/services,
  debuggable flag, deeplink-to-export — because reproducing them typically needs local device
  access. Read the exclusion first; if the finding needs the device in-hand, it's out of scope.
- **Seed at rest lives in Android Keystore / iOS Keychain (hardware-backed).** Static decompile
  (jadx/apktool/dex2jar) shows *how* keys are stored and can catch real issues (plaintext
  SharedPrefs, world-readable files, seed in a deeplink/intent, hardcoded secret,
  `allowBackup=true` on the seed store) — but proving an exploitable seed-leak usually needs
  **runtime** (Frida + rooted device/emulator), which a headless Linux box can't provide alone.

**APK acquisition is CF-gated.** apkpure/apkcombo/apkmirror front download endpoints with
Cloudflare Managed Challenge; direct-CDN URLs (`d.apkpure.com`, `download.apkpure.net`,
`d.cdnpure.com`) return an HTML challenge page (200 with `<!DOCTYPE`, or 404), not the APK.
The reliable unblock is the **user's own `cf_clearance` cookie + matching UA** (they solve the
challenge in-browser and export it) — ask for it rather than grinding mirror bypasses. Get the
package id from the vendor's bug-bounty/download page (Glow: `com.luma.wallet.prod`, App Store
`id1599584512`), not by guessing (`com.glow.*` / `app.glow.*` all 404'd on Play).

**Honest routing:** if the target's payable classes need runtime/device you don't have, say so
and offer the pivot to pure smart-contract work (fully auditable + PoC-able from the box) rather
than producing a static-only Medium that may be out of scope. Match the surface to what you can
actually prove.

**APK tooling on a Linux offload box (install once):** `apt-get install -y jadx apktool dex2jar`
— the dex2jar binary is invoked as `d2j-dex2jar` (not `dex2jar`). Java is a prereq (present on Kali).
Package id + store links come from the vendor's own bug-bounty/download page; Glow's were
`com.luma.wallet.prod` (Play) + App Store `id1599584512`, and guessing (`com.glow.*`, `app.glow.*`,
`io.glow.*`) all 404'd on Play — don't guess, read the page.

**Glow clean-verdict worked example (2026-08-23):** ext id `ojbcfhjmpigfobfclfflafhblgemeidi`
v0.61.0. `externally_connectable` absent; `content.js` had ONE page listener calling only
`C4.sendInpageRequest`; the seed exporter `getPhraseForAccountDangerously` (which uses the cached
temp-password `Ir()`/`getTempPassword()`, NO password re-prompt — looks scary) is invoked only from
`pages/popup.js|onboarding.js|prompt.js`, never from `content.js`, and the background router
(`__glow_background_request` → `qY[type](payload, sender)`) is reachable only via same-extension
`sendMessage` which the absent `externally_connectable` restricts to extension contexts. Result:
seed/key-export path NOT web-reachable → clean, not submittable. This is the canonical "scary schema,
unreachable handler" shape — confirm reachability before grading, don't inflate.

## 5. H1 program hygiene
- Set User-Agent to include `h1-<username>` on every request to in-scope assets.
- Re-read scope exclusions each session — wallet programs commonly exclude
  address-bar spoofing, hardcoded 3rd-party blockchain API keys, self-XSS,
  and known outdated-dependency XSS. Check your finding isn't a listed known-issue.

## Pitfalls
- **`clients2.google.com/service/update2/crx` needs `response=redirect`** or you get a
  204; follow the 302 with `-L`. The CDN blob is the CRX.
- **CRX3 header is protobuf, not fixed-size** — you MUST read `header_len` at bytes
  [8:12] and skip `12+header_len`; don't hardcode an offset.
- **`__MSG_appName__` in manifest name** is an i18n placeholder — the real name is in
  `_locales/en/messages.json`, not a bug.
- **Background bundle is multi-MB minified** — never `read_file` it whole; `grep -oc`
  for keyword presence, then slice ±context around specific hits with python.
- **Extension-page CSP `default-src 'self'` blocks injected `<script>` but not the
  framework's virtual-DOM render** — an Inferno/React `dangerouslySetInnerHTML` sink
  can still render attacker HTML (event handlers blocked by CSP, but DOM-clobbering /
  form injection may survive). Don't declare a renderer safe just because CSP is strict.
- **Don't confuse `trusted` with `autoApprove`** — read both getters in background
  before writing impact. `trusted` skips connect prompt; only `autoApprove` (rarely
  attacker-reachable) skips signing.
- **whois hangs / isn't installed on minimal VPS** — use RDAP over HTTP instead; it's
  authoritative and scriptable.
