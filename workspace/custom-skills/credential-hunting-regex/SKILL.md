
# Credential Hunting Regex Patterns

**Source:** https://github.com/h4x0r-dz/Leaked-Credentials
**Use Case:** Quick DevTools sweeps, Burp Suite traffic analysis, custom nuclei/grep templates

---

## Chrome DevTools Regex (Network Tab Filter)

Paste into Network tab filter bar (enable regex icon `.*`):

```regex
(access_key|access_token|admin_pass|admin_user|algolia_admin_key|algolia_api_key|alias_pass|alicloud_access_key|amazon_secret_access_key|amazonaws|ansible_vault_password|aos_key|api_key|api_key_secret|api_key_sid|api_secret|api.googlemaps AIza|apidocs|apikey|apiSecret|app_debug|app_id|app_key|app_log_level|app_secret|appkey|appkeysecret|application_key|appsecret|appspot|auth_token|authorizationToken|authsecret|aws_access|aws_access_key_id|aws_bucket|aws_key|aws_secret|aws_secret_key|aws_token|AWSSecretKey|b2_app_key|bashrc password|bintray_apikey|bintray_gpg_password|bintray_key|bintraykey|bluemix_api_key|bluemix_pass|browserstack_access_key|bucket_password|bucketeer_aws_access_key_id|bucketeer_aws_secret_access_key|built_branch_deploy_key|bx_password|cache_driver|cache_s3_secret_key|cattle_access_key|cattle_secret_key|certificate_password|ci_deploy_password|client_secret|client_zpk_secret_key|clojars_password|cloud_api_key|cloud_watch_aws_access_key|cloudant_password|cloudflare_api_key|cloudflare_auth_key|cloudinary_api_secret|cloudinary_name|codecov_token|config|conn.login|connectionstring|consumer_key|consumer_secret|credentials|cypress_record_key|database_password|database_schema_test|datadog_api_key|datadog_app_key|db_password|db_server|db_username|dbpasswd|dbpassword|dbuser|deploy_password|digitalocean_ssh_key_body|digitalocean_ssh_key_ids|docker_hub_password|docker_key|docker_pass|docker_passwd|docker_password|apikey|dockerhub_password|dockerhubpassword|dot-files|dotfiles|droplet_travis_password|dynamoaccesskeyid|dynamosecretaccesskey|elastica_host|elastica_port|elasticsearch_password|encryption_key|encryption_password|heroku_api_key|sonatype_password|awssecretkey)
```

---

## Burp Suite Regex (Search Tab → Regular Expression)

Captures key-value pairs with values 8-64 chars:

```regex
(?i)((access_key|access_token|admin_pass|admin_user|algolia_admin_key|algolia_api_key|alias_pass|alicloud_access_key|amazon_secret_access_key|amazonaws|ansible_vault_password|aos_key|api_key|api_key_secret|api_key_sid|api_secret|api.googlemaps AIza|apidocs|apikey|apiSecret|app_debug|app_id|app_key|app_log_level|app_secret|appkey|appkeysecret|application_key|appsecret|appspot|auth_token|authorizationToken|authsecret|aws_access|aws_access_key_id|aws_bucket|aws_key|aws_secret|aws_secret_key|aws_token|AWSSecretKey|b2_app_key|bashrc password|bintray_apikey|bintray_gpg_password|bintray_key|bintraykey|bluemix_api_key|bluemix_pass|browserstack_access_key|bucket_password|bucketeer_aws_access_key_id|bucketeer_aws_secret_access_key|built_branch_deploy_key|bx_password|cache_driver|cache_s3_secret_key|cattle_access_key|cattle_secret_key|certificate_password|ci_deploy_password|client_secret|client_zpk_secret_key|clojars_password|cloud_api_key|cloud_watch_aws_access_key|cloudant_password|cloudflare_api_key|cloudflare_auth_key|cloudinary_api_secret|cloudinary_name|codecov_token|config|conn.login|connectionstring|consumer_key|consumer_secret|credentials|cypress_record_key|database_password|database_schema_test|datadog_api_key|datadog_app_key|db_password|db_server|db_username|dbpasswd|dbpassword|dbuser|deploy_password|digitalocean_ssh_key_body|digitalocean_ssh_key_ids|docker_hub_password|docker_key|docker_pass|docker_passwd|docker_password|dockerhub_password|dockerhubpassword|dot-files|dotfiles|droplet_travis_password|dynamoaccesskeyid|dynamosecretaccesskey|elastica_host|elastica_port|elasticsearch_password|encryption_key|encryption_password|env.heroku_api_key|env.sonatype_password|eureka.awssecretkey)[a-z0-9_ .\\-,]{0,25})(=|>|:=|\\|\\|:|<=|=>|:).{0,5}['\"]([0-9a-zA-Z\\-_=]{8,64})['\"]
```

---

## Quick Usage

### Chrome DevTools
1. Target site → `F12` → **Network** tab
2. Click regex icon `.*` in filter bar
3. Paste DevTools regex → Refresh page
4. Review filtered requests

### Burp Suite
1. Proxy traffic through Burp
2. **Burp → Search** → Type: **Regular expression**
3. Paste Burp regex → Search
4. Inspect matches (Group 3 = captured value)

### Command Line (gau + grep)
```bash
# Historical endpoints
gau target.com | while read url; do curl -s "$url" | grep -iE "api_key|secret|token|password"; done

# Live endpoints with httpx
httpx -l urls.txt -sr -regex "api_key|secret|token|password"
```

---

## Coverage Categories

| Cloud | SaaS/API | Database | CI/CD | Infra |
|-------|----------|----------|-------|-------|
| AWS, GCP, Azure, DO, Cloudflare, Alibaba | GitHub, GitLab, Slack, Stripe, Twilio, Algolia, Cloudinary, Datadog | MySQL, PostgreSQL, MongoDB, Redis, Elasticsearch, DynamoDB | Jenkins, Travis, CircleCI, GH Actions, Codecov, Sonatype | Docker, K8s, Heroku, Netlify, Vercel, Terraform, Ansible |

---

## Limitations & Tips

| Issue | Mitigation |
|-------|------------|
| False positives (var names) | Burp regex captures `= "value"` pattern; manual review |
| Minified JS bundles | Deobfuscate with source maps first |
| WebSocket/GraphQL | Check WS frames separately; GraphQL introspection |
| Encoded values (base64/JWT) | Decode before matching |

---

## Integration Ideas

- Save Burp regex as "Credential Hunt" for instant access
- Bookmark DevTools regex for quick filtering
- Build custom nuclei templates from patterns
- Combine with `gf` patterns: `gf secrets`, `gf api-keys`

---

## Case Studies (Session Evidence)

| Target | Platform | JS Chunks | Preview Deployments | API Endpoints | Credentials Found |
|--------|----------|-----------|---------------------|---------------|-------------------|
| **doma.xyz** | Next.js + Wagmi | 10 | 6 (`d3-*.app.doma.xyz`) | 15+ | **0** |
| **printer.fun** | Next.js + Wagmi/Viem | 10 | 0 (DigitalOcean) | 5 game pages | **0** |

**Combined:** 20 JS chunks, 6 preview deployments, 20+ API endpoints → **0 credentials found**

---

## Consolidated Lessons (Both Scans)

1. **Modern Next.js + wagmi/viem apps are clean by design** — Secrets stay server-side (Prisma/NextAuth), client bundles only get public configs (chain IDs, RPC URLs, contract ABIs)

2. **Chain configs in client are normal** — viem/wagmi chains config includes RPC URLs, contract addresses, explorers — all public by design

3. **Tokenized asset contracts are public** — ERC20 contract addresses for AAPL, NVDA, TSLA etc. are meant to be public on-chain

4. **Preview deployments need active crawling** — Don't just check they exist; probe `/api/debug`, `/.env`, `/actuator/env`, `/playground`. Vercel/Netlify previews inherit production auth.

5. **Feature flags in cookies ≠ credentials** — PostHog `phBootstrapData` is analytics, not auth

6. **Public RPC endpoints are safe** — Dangerous methods (`eth_sendTransaction`, `eth_sign`, etc.) properly restricted; only read methods work (by design)

7. **Bridge/3rd party apps on subdomains** — Check `__NEXT_DATA__` or equivalent for config leaks; usually only public chain configs

8. **Shopify password protection works** — Low priority target

9. **Modern Next.js + Prisma + NextAuth + wagmi/viem = inherently secure** against client-side credential leaks when properly implemented

10. **Scan efficiency:** 20 JS chunks + 6 preview deployments + 20+ APIs = ~50 min total, **0 credentials**, 0 false positives

---

## Workflow for Similar Targets

1. **Quick DevTools regex sweep** (30 sec) → if clean, skip deep Burp
2. **Check `__NEXT_DATA__`** for config leaks
3. **Probe preview deployments** if Vercel/Netlify detected (`d3-*.app.domain.xyz` pattern)
4. **Focus server-side audit** on API/DB (not client bundles)
5. **Document scan results** as evidence for triage kill confirmation

---

## Integration with Triage-Validation

If a triage finding flags \"JS Info Disclosure\" or \"Client-side config exposure\":
1. Run credential-hunting-regex scan
2. If zero matches → triage kill confirmed with evidence
3. If matches found → classify per patterns (API keys = High, feature flags = Informational)

**Triage + Credential Hunting = Definitive Kill Evidence** — This session proved 7 triage findings killed with 0 credential matches across 2 targets.