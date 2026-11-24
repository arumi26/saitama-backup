
# WordPress Bug Bounty (Legitimate)

Reusable workflow for finding, verifying, and reporting WordPress vulnerabilities **the right way**: authorized targets only, source-verified CVEs, local reproduction, professional disclosure.

## Hard scope rules (non-negotiable)

- **Authorization first.** Only test: (a) a WP install you own/control, (b) a target explicitly in-scope on a bug bounty program (HackerOne, Intigriti, Bugcrowd, Patchstack, WPScan, or a vendor's published program), or (c) a plugin/theme whose *source code* you audit statically (reading public code is always fine).
- **Never mass-scan or mass-exploit.** Firing an exploit at "all WordPress sites" / IP ranges / random domains is out of scope, illegal, and gets you banned. One authorized target at a time.
- **Reproduce on your OWN box.** Prove impact on a local/containerized WP install you control — never on a live third-party site you don't own, even if the bug is real.
- **A viral CVE claim is not evidence.** Social-media threads ("500M sites at risk!", screenshots of a PoC repo) are frequently fabricated, inflated, or misattributed. Verify at the source before spending any time. See "CVE verification" below.

## Phase 0: Verify the CVE is real BEFORE anything else

Do this in ~2 minutes. Most hype CVEs die here.

```bash
# 1. NVD — authoritative. If it 404s or says "RESERVED"/"REJECTED", treat as unconfirmed.
curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=CVE-2026-XXXXX" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('vulnerabilities',[]);print('NOT FOUND' if not v else json.dumps({'id':v[0]['cve']['id'],'status':v[0]['cve']['vulnStatus'],'desc':v[0]['cve']['descriptions'][0]['value'][:300]},indent=1))"

# 2. WPScan DB (WordPress-specific, often ahead of NVD for plugins)
#    Browser: https://wpscan.com/search?text=<plugin-name>
#    Or API (needs free token): https://wpscan.com/api/v3/plugins/<slug>

# 3. Patchstack DB — https://patchstack.com/database/  (search plugin/CVE)

# 4. Plugin changelog — did the vendor actually ship a fix?
curl -s "https://plugins.svn.wordpress.org/<slug>/trunk/readme.txt" | grep -iA3 "changelog\|security\|fixed"
```

**Red flags the CVE is fake/inflated:**
- Not in NVD *and* not in WPScan *and* not in Patchstack → almost certainly fabricated.
- "Pre-auth XSS → RCE, no creds, 500M sites" — reflected XSS does not become RCE without a second bug + a logged-in admin victim. Chained-impact claims need a chain; a single reflected-XSS payload does not RCE a server.
- PoC repo created same day as the hype, no NVD reference, author account brand new.
- The "detection nuclei template" link 404s or points to an unmerged PR.

If it fails verification: note "unverified, likely fabricated" and stop. Do not build tooling around it.

## Phase 1: Pick a legitimate target

Sources of in-scope WP targets:
- **Patchstack mVDP / Alliance** — https://patchstack.com/ — pays for plugin/theme bugs, huge in-scope catalog, WordPress-focused. Best fit for WP work.
- **WPScan** — https://wpscan.com/ — submit plugin/theme vulns.
- **HackerOne / Intigriti / Bugcrowd** — filter programs that list a WordPress site or "any of our plugins" in scope. Read the scope + rules page fully.
- **Your own plugin/theme** — auditing code you wrote/run is always allowed.

Prefer: plugins with 10k–100k+ installs (impact but less picked-over than the top 5), recently updated (active vendor = pays + patches), custom code (not just wrappers).

## Phase 2: Set up a LOCAL reproduction lab

```bash
# Fastest: wp-env (official) or docker-compose
npm i -g @wordpress/env    # or use docker
mkdir wp-lab && cd wp-lab
cat > .wp-env.json <<'EOF'
{ "core": "WordPress/WordPress#master",
  "plugins": [ "https://downloads.wordpress.org/plugin/<slug>.<version>.zip" ],
  "config": { "WP_DEBUG": true, "WP_DEBUG_LOG": true, "SCRIPT_DEBUG": true } }
EOF
wp-env start        # WP at http://localhost:8888 (admin: admin/password)
```

Docker alternative:
```bash
docker run -d -p 8080:80 --name wplab -e WORDPRESS_DEBUG=1 wordpress:latest
# then install the target plugin version via wp-cli:
docker exec wplab wp plugin install <slug> --version=<vuln-version> --activate --allow-root
```

Enable Xdebug/log so you can trace the sink. Grab the exact vulnerable version (from the CVE), not latest.

## Phase 3: Static audit — find the sink

WordPress bug classes and where they live:

| Class | Grep pattern | Root cause |
|-------|-------------|-----------|
| Reflected/Stored XSS | `echo $_GET`, `echo $_POST`, `_REQUEST`, missing `esc_html`/`esc_attr`/`esc_url` | unsanitized output |
| SQLi | `$wpdb->query("... $_` , string-interp into query, missing `$wpdb->prepare()` | unparameterized query |
| Auth bypass / broken access control | `add_action('wp_ajax_nopriv_...` , missing `current_user_can()`, missing `check_admin_referer()` | no capability/nonce check |
| CSRF | form/AJAX handler with no `wp_verify_nonce` / `check_ajax_referer` | missing nonce |
| Arbitrary file upload | `move_uploaded_file`, `wp_handle_upload` without type/ext validation | unrestricted upload |
| LFI/RFI | `include $_`, `require($_GET`, `file_get_contents($_` | path from user input |
| SSRF | `wp_remote_get($_`, `curl_exec` with user URL | server-side fetch of user URL |
| Insecure deserialization | `unserialize($_`, `maybe_unserialize` on user data | PHP object injection |
| Priv-esc | `update_user_meta` on `wp_capabilities`, `update_option` reachable pre-auth | option/meta tamper |

```bash
# Search the plugin source (read-only, always legal)
search inside plugin dir for the patterns above; trace user input → sink.
# Key: does the vulnerable handler require a nonce AND a capability check?
grep -rn "wp_ajax_nopriv" .        # pre-auth reachable AJAX = high value
grep -rn "current_user_can\|check_admin_referer\|wp_verify_nonce" .   # what protections exist?
```

Diff the vulnerable version vs the patched version — the security fix shows you the exact sink:
```bash
# download both versions, diff them
diff -ru plugin-<vuln>/ plugin-<patched>/ | grep -A5 -B5 "esc_\|prepare\|current_user_can\|nonce\|sanitize"
```

## Phase 4: Reproduce on YOUR lab

- Build the minimal request (curl / a single HTML form you host on `localhost`) that triggers the sink on your local WP.
- Capture: the exact request, the response showing impact (reflected payload executing, SQL error/extracted data, unauthorized action succeeding), screenshot/log.
- For XSS: prove JS executes in the victim's browser context (`alert(document.domain)` is the standard neutral PoC). Note the required victim role (unauth vs admin) — it changes severity a lot.
- For access control: show a low-priv or unauth user performing the privileged action.
- **Do not** point the PoC at any domain you don't own.

## Phase 5: Severity — be honest

- **Reflected XSS, unauth**: Medium (needs victim to click attacker link). NOT "RCE".
- **Stored XSS reachable by unauth → executes in admin context**: High (can lead to admin account takeover → then plugin/theme editor RCE, but that's a *chain* you must demonstrate, not assume).
- **SQLi unauth**: High/Critical.
- **Unauth arbitrary file upload of .php**: Critical (real RCE).
- **Broken access control on a state-changing action**: Medium–High by impact.
- Use CVSS 3.1; don't inflate. Triagers reject inflated severity, and a fabricated/overclaimed report risks a program ban.

## Phase 6: Report (platform-ready)

Structure (English for platform submissions):
```
Title: [Plugin Name x.y.z] <Bug class> in <function/endpoint> (pre-auth/authenticated)
Summary: 1-2 sentences — what, where, impact.
Affected: plugin slug + exact version range, file:line, function.
Preconditions: auth level required, config required.
Steps to reproduce: numbered, exact request(s), against a local install.
PoC: curl / HTML form (targeting localhost only in the writeup).
Impact: concrete, honest, with CVSS vector.
Remediation: the specific fix (add nonce + current_user_can; use $wpdb->prepare; esc_html on output).
```

Disclosure discipline:
- Submit through the program's channel (Patchstack/WPScan/H1/Intigriti/vendor security contact). Don't publish PoC publicly until fixed + coordinated.
- If no program exists but the plugin is on wordpress.org: report to **Patchstack** or **WPScan** (they coordinate with vendors) or the vendor's `readme.txt` contact. Responsible disclosure, give them time.

## Pitfalls
- **wp.org auto-updates**: many users are patched fast; impact ("N million at risk") is usually far lower than raw install count. Don't quote install count as "at risk".
- **`wp_ajax_` vs `wp_ajax_nopriv_`**: only `nopriv` handlers are pre-auth reachable. Confirm which hook registers the vulnerable callback.
- **Nonce ≠ authz**: a nonce stops CSRF, not privilege escalation. A handler can have a valid nonce and still miss `current_user_can()` — that's a broken-access-control bug for any logged-in low-priv user.
- **SSR escaping**: modern themes/Gutenberg escape output; test the actual sink, don't assume.
- **Don't trust the hype PoC repo** — read its code before running; some "PoC" repos are themselves malware/backdoored. Reproduce from your own understanding of the sink, in your own lab.
- **Verify the CVE exists (Phase 0) before building anything.** Fabricated CVEs with slick repos + nuclei templates are a common bait; wasting hours on a non-existent bug (or worse, running a backdoored "exploit tool") is the trap.

## Reference file
`references/sinks-and-cve-verification.md` — (1) full WP source→sink map + grep sweep + version-diff audit recipe; (2) worked CVE-verification case studies (CVE-2026-63030 "wp2shell" = REAL, NVD status Analyzed, RCE chain 63030+60137 with pinned version range; CVE-2026-64638 "XSS2Shell" = PENDING, NVD status Received, inflated "XSS→RCE" claim) plus a "real vs hype" tell table. Consult it whenever a target runs WordPress or someone drops a WP CVE + PoC repo.

## Quality bar
- [ ] CVE/vuln verified at NVD or WPScan or Patchstack (not social media)?
- [ ] Reproduced on a LOCAL install you own?
- [ ] Exact affected version + file:line identified?
- [ ] Severity honest, CVSS vector included?
- [ ] Report has concrete remediation?
- [ ] Disclosed through a legitimate coordinated channel?
