# JS Source-Map Harvesting → Client-Side Source Review

Publicly served `.js.map` files hand you the app's unminified proprietary `src/` — no
account, no login. Fastest way to audit client-side trust boundaries (postMessage bridges,
open redirects, support-impersonation flows) that scanners cannot see, and the one path
available against **OAuth-only-signup targets** where you cannot self-serve an account.

## Step 1 — Enumerate the app's OWN chunk maps (the vendor map is a decoy)

Grabbing the big `dist-*.js.map` usually returns **only `node_modules`** (vendor). The app's
real `src/` lives in *other* chunk maps. Pull the entry HTML and list every asset:

```bash
curl -s https://target/ -o idx.html
grep -oE '/assets/[A-Za-z0-9._-]+\.(js|css)' idx.html | sort -u
# also: grep -oE 'dist-[A-Za-z0-9_-]+\.js' idx.html   (modulepreload hints)
```

Fetch the `.map` for each **app-ish** chunk (`main-*`, `hooks-*`, `user-*`, `mutation-*` —
not `vendor-*`):

```bash
for c in main-XXXX hooks-XXXX user-XXXX; do
  curl -s -o "$c.map" -w "$c -> %{http_code} %{size_download}\n" \
    "https://target/assets/$c.js.map"
done
```

200 + multi-MB body = live map. **Prod often 404s even when QA serves them** — check both and
scope the finding accordingly.

## Step 2 — Extract only the app's source (filter node_modules)

```python
import json, glob, os
os.makedirs('src_all', exist_ok=True)
for f in glob.glob('*.map'):
    m = json.load(open(f))
    for s, c in zip(m.get('sources', []), m.get('sourcesContent', [])):
        if 'node_modules' in s:            # skip vendor
            continue
        open('src_all/' + os.path.basename(s), 'w').write(c or '')
```

`sourcesContent` is present in most maps → full unminified TS/TSX. If absent, `sources`
paths alone still leak internal file structure and module names.

## Step 3 — Grep for the security-sensitive modules

```bash
# trust-boundary / auth flows
grep -rilE "postMessage|BroadcastChannel|origin|redirect|returnPath|returnTo|impersonat|view-as|viewAs|snapshot" src_all/
# secrets / sinks / logging
grep -rInE "(sk[-_]live|AKIA|ghp_|-----BEGIN|client_secret|api[_-]?key)" src_all/
grep -rInE "(console\.(log|info|debug)|dangerouslySetInnerHTML|innerHTML|eval\(|new Function)" src_all/ \
  | grep -iE "token|secret|auth|credential"
```

## Step 4 — Review client-side trust boundaries (fail-closed checklist)

| Sink | What "safe" looks like |
|---|---|
| `window.addEventListener("message", h)` | `if (event.origin !== EXACT_ORIGIN) return` — exact string, not `includes`/`startsWith`/loose regex |
| `postMessage(data, targetOrigin)` | target origin is a literal, never `"*"` |
| incoming object → storage/state | keys filtered against a fixed allowlist (unknown keys rejected) |
| open redirect (`returnPath`/`returnTo`) | canonicalize with `new URL(x, "https://dummy.invalid")`, compare `.pathname`/`.origin`, reject `://`, `javascript:`, `..`, `%2f/%5c` |
| URL-fragment token handoff | fragment consumed only by a dedicated callback route; origin allowlist strict |
| support impersonation (`viewAs`) | server enforces session auth; client guard is fail-closed (capture-phase click/keydown/submit blockers) |

## Step 5 — Exploitability gate (BEFORE writing it up)

A hardened-looking bridge is only a finding if the **trusted endpoint is attacker-reachable**.
For every allowlisted origin/host ask: *can an attacker control it?*

```bash
# preview-deploy pattern: is the repo public (fork PRs → attacker-controlled preview)?
curl -s "https://api.github.com/orgs/ORG/repos?per_page=100" \
  | python3 -c 'import json,sys; [print(r["name"], r["private"]) for r in json.load(sys.stdin)]'
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://<preview-origin>/
```

- Repo **private** + preview origins **403** → not externally reachable → **internal hardening
  note, NOT reportable.**
- Repo **public** / preview **200** → attacker can host a page on a trusted origin → real finding.

## Pitfalls

- Don't stop at the first map — the vendor map is a decoy; the app source is in the app chunks.
- "Client-side source disclosed" is itself usually **Low/Info**; the value is the *review*, not the disclosure.
- No secrets in source ≠ nothing there: auth-flow logic (bridges, impersonation, redirects) is the payload.
- A trust boundary that is perfectly hardened is a **negative result** — record what you checked
  and *why it's clean* so the next session doesn't redo the reading.
- Client-side source review needs **no account** — reach for it first when signup is OAuth-only
  and you can't self-serve credentials.

## Worked example

A QA SPA served 57 unminified `src/` files across its app chunk maps. Reviewed:
`previewAuthBridge.ts` (cross-origin Bearer handoff — exact-origin gate + key allowlist → safe),
`viewAs.ts` (support impersonation — fail-closed guard → safe), `changeStackAuthRedirect.ts`
(open-redirect canonicalization → safe), slack/discord return-path guards → safe. Sweep for
secrets/token-logging → zero hits. The one structural candidate (preview-auth bridge delivering
a token to `pr-<N>-ui-*` origins) was **downgraded to a hardening note** after the exploitability
gate: the app repo was private and preview origins returned 403 → not attacker-reachable.
