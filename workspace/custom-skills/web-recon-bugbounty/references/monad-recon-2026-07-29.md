# Monad.xyz Recon Case Study — July 2026

## Target
- URL: https://www.monad.xyz/
- Type: L1 Blockchain (parallel EVM, 10K TPS, 0.6s finality)
- Tech: Next.js (App Router, i18n) on Vercel, Cloudflare for docs

## Recon Results

### Headers
- CSP: strict, `default-src 'self'`, `unsafe-eval` in script-src
- HSTS: max-age=63072000 (2 years)
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- Server: Vercel
- X-Powered-By: Next.js

### Subdomains
- www.monad.xyz → 200 (Next.js + Vercel)
- testnet.monad.xyz → 301 → developers.monad.xyz
- developers.monad.xyz → 200 (Mintlify docs, Cloudflare)
- api.monad.xyz → no DNS

### API Surface
- /api/ → 307 redirect (robots.txt: Disallow: /api/)
- /api/auth → 404
- /api/v1 → 404
- /api/health → 404 (Next.js 404 page)

### Well-Known Endpoints
- /.well-known/security.txt → 404 (Next.js 404 HTML page, NOT a real 404)
- No agent-skills, MCP, or API catalog endpoints found

### robots.txt
```
User-Agent: *
Allow: /
Disallow: /api/
```

### Sitemap
- /sitemap.xml → empty or minimal URLs

### CSP Third-Party Domains
- `molandak.org` — asset CDN (images, media) — investigate for takeover
- `lumacdn.com` — image CDN
- `unicorn.studio` — asset CDN
- `beehiiv.com` — newsletter forms
- `tally.so` — form embedding
- `googletagmanager.com` — analytics
- `vercel-scripts.com` — Vercel analytics

### JS Chunks (Next.js)
- 20+ JS chunks at `/_next/static/chunks/`
- Build ID: `dpl_4wMiuTDvpXGCJ5dxYEDHZWYKmNPQ` (Vercel deploy ID)
- RSC payload embedded in `self.__next_f.push()` calls

### Attack Surface Summary
1. `/api/` dir hidden in robots.txt — fuzz common routes
2. `unsafe-eval` in CSP — XSS gadget possible
3. `molandak.org` in CSP — unrelated domain, check takeover
4. Tally.so/beehiiv integrations — form injection
5. developers.monad.xyz (Mintlify) — check Mintlify CVEs
6. Next.js build ID — enumerate SSG pages
7. No security.txt — no clear bounty contact

### Bounty Status
- No Immunefi program found for Monad
- No HackerOne program found
- Best route: direct contact via Discord/security email
