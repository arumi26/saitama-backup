# VDP Casino / Cloudflare-Turnstile Recon (Stake.com class, Aug 2026)

Lessons from recon on a Cloudflare-Turnstile-protected crypto casino with a
Bugcrowd VDP (`stake.com`). Applies to any big consumer web app behind CF
challenge with a self-provisioned-account bounty program.

## 1. Read the Bugcrowd scope BEFORE touching anything active
The engagement page (`bugcrowd.com/engagements/<slug>`) is JS-heavy — a raw
snapshot returns empty table cells. Extract the real scope with browser_console
reading `document.body.innerText`:
```js
(()=>{const b=document.body.innerText;const i=b.search(/scope|in scope|out of scope|target/i);return b.slice(i>0?i:0,(i>0?i:0)+3000)})()
```
This surfaces: In-Scope targets, Focus Areas, Credentials note, Safe Harbor.

**Stake.com scope (confirmed):** ONLY `https://stake.com/*` is in scope. Every
subdomain (api./engine./beta./old./tableau./2foauth. …) is **OUT of scope**
unless explicitly listed. Focus Areas: **GraphQL services** + **Credentials**.

## 2. Self-provisioned test accounts (@bugcrowdninja.com)
Many Bugcrowd programs let you sign up with a `<handle>@bugcrowdninja.com`
email → auto-approved, all features unlocked, no payment/deposit needed. The
handle is tied to YOUR Bugcrowd account (need one first). This is the
authorized way to test authenticated surface — casino bugs ($$) live behind
login (bet/bonus/withdraw business logic, IDOR on other users' data, race
conditions / double-spend). Never test with a real-money account or another
user's data.

## 3. Third-party services = OUT of scope (kill fast)
Before deep-testing any subdomain, resolve its CNAME:
```bash
curl -s "https://dns.google/resolve?name=SUB.TARGET.com&type=CNAME" | \
  python3 -c "import json,sys;[print(a.get('data')) for a in json.load(sys.stdin).get('Answer',[])]"
```
`tableau.stake.com` → CNAME `*.analytics.tableau.com` + server `sfdcedge` =
Tableau Cloud (Salesforce). A bug there is reported to Salesforce, not Stake.
Version disclosure (`/api/3.4/serverinfo`) on a 3rd-party SaaS = info-leak, not
paid. Triage-validation Q3 (root cause in in-scope asset) kills it.

## 4. Cloudflare Turnstile bypass reality
- **Datacenter VPS IPs fail Turnstile hard.** DigitalOcean/AWS egress gets the
  永久 "Just a moment…" loop; `cf_clearance` never sets. cloakbrowser free tier
  (v0.4.10 AND v0.5.7) on a VPS did not solve stake.com's challenge.
- **Residential IP (home Kali box) is the right tool** — real `google-chrome`
  binary + home ISP IP has a far better Turnstile pass rate than headless
  Chromium on a datacenter IP. Run the CF-gated browser work on Kali, not VPS.
- **`page.goto(..., wait_until="commit", timeout=120000)`** — a CF-challenged
  page never fires `load`/`domcontentloaded`, so the default goto TIMES OUT and
  raises. Use `wait_until="commit"` and wrap goto in try/except, then poll
  `page.title()` in a loop (≈18×4s) until it stops containing "moment".
- If residential + real Chrome still fails, the honest options are: (a) a
  residential proxy via cloakbrowser paid key, or (b) pivot to non-CF surface.
  Don't burn cycles re-running the same failing config.

## 5. cloakbrowser gotcha — stdlib shadowing
A stray `inspect.py` (or any stdlib name) in the CWD breaks cloakbrowser import
with `AttributeError: module 'inspect' has no attribute 'signature'`. Run from a
clean working dir (e.g. `/tmp/stakework/`), never a dir polluted with scratch
`.py` files named after stdlib modules.

## 6. GraphQL introspection via authed page context
Once CF is passed in the browser, run introspection from the PAGE (same-origin,
carries cf_clearance + session) instead of curl:
```js
await fetch('/_api/graphql',{method:'POST',headers:{'Content-Type':'application/json'},
  body:JSON.stringify({query:'{__schema{queryType{name} mutationType{name} types{name}}}'})})
```
curl from the shell hits the CF wall; the browser fetch inherits the solved
challenge cookie.
