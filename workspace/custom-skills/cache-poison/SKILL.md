---
skill: cache-poison
title: "Cache Poisoning / Deception"
category: "Security · Web Exploitation"
load_when: "CDN/edge-cached apps; unkeyed inputs influencing responses."
pack: SUPERAGENT V10
bughunt: true
---
# Cache Poisoning / Deception

## Where it pays
Mass XSS/redirect via cache, or trick cache into storing private pages.

## Attack-surface signals
Unkeyed headers (X-Forwarded-Host/Scheme), odd params; extension-based caching.

## Methodology
1. Find unkeyed inputs that change the response.
2. Inject via unkeyed header, get cached, fetch as victim (same key).
3. Deception: /account/nonexistent.css cached as static.
4. Confirm X-Cache HIT + persistence (use your own 2nd session).

## Payloads
```
X-Forwarded-Host: evil.com  (reflected into cached <script src>?)
```
Pairs with `xss.md` (header-reflected).

## Root causes
Reflecting unkeyed headers · caching by extension/path not content · key vs routing mismatch.

## Bypasses
Unkeyed header variety; path confusion.

## Validation gate
Show a cached malicious response served to a different user (your own 2nd session).

## Impact & chains
stored XSS/redirect at scale · private data disclosure.

**→ next on hit: `../phases/04-chain.md`.**
