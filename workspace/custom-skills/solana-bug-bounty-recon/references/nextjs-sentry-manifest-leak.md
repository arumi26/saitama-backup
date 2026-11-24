# Next.js Sentry Route Manifest Leak — Class-Level Info Disclosure

Reusable bug pattern for any Next.js app using `@sentry/nextjs` SDK. Reproduces on popi.wtf 2026-07-14 and is present in most Next.js apps that bundle Sentry client-side.

## Detection (one-liner)

```bash
curl -s https://TARGET/_next/static/chunks/main-app-*.js \
  | grep -oE '_sentryRouteManifest=[^;]{0,4000}' | head -c 4000
```

If output contains `"dynamicRoutes":[...]` and `"staticRoutes":[...]`, the app leaks its full sitemap. Look for `/dev/*`, `/admin/*`, `/staging/*`, `/mock/*`, `/preview/*`, `/internal/*` entries — those are the interesting ones to include in the report.

## Severity Rubric

- **P4-P5 baseline** ($25-75, or T-shirt tier): all leaked routes return 404 in prod. Impact = recon amplification only.
- **P3** ($100-250): at least one leaked route serves partial content (200, or 401 with data) that wasn't discoverable via other means.
- **P2-P1** ($500+): a leaked route has an auth bypass or IDOR. Chain the disclosure with the follow-on bug in the same report.

## Report Template

```markdown
# Information Disclosure: Complete Sitemap Leaked via Sentry Route Manifest

**Severity**: Low (P4-P5)
**Category**: Information Disclosure
**Target**: `https://TARGET`

## Summary

The main-app JavaScript bundle at `/_next/static/chunks/main-app-<hash>.js` (loaded on every page) contains an embedded `globalThis._sentryRouteManifest` JSON object that discloses every route in the Next.js application — including internal `/dev/*` and `/dev/admin/*` paths that are meant to be hidden. This provides an unauthenticated attacker a complete map of the application's route structure.

## Steps to Reproduce

1. Open `https://TARGET/` in incognito.
2. DevTools → Network → filter `main-app`.
3. Response body of `main-app-<hash>.js`.
4. Search `_sentryRouteManifest`.
5. Observe embedded JSON with static and dynamic route lists.

Or:
    curl -s https://TARGET/_next/static/chunks/main-app-<hash>.js \
      | grep -oE '_sentryRouteManifest=[^;]*' | head -c 4000

## Full Route List Disclosed

<paste `dynamicRoutes` + `staticRoutes` here — flag `/dev/*` and `/admin/*` entries>

## Root Cause

The `@sentry/nextjs` SDK generates a route manifest at build time and injects it into the client bundle via `globalThis._sentryRouteManifest` for automatic route-based error tracking. This manifest is an unfiltered leak of every route file in the Next.js `app/` or `pages/` directory, regardless of whether those routes are meant to be publicly reachable in production.

## Impact

- Reconnaissance amplification: attackers no longer need to fuzz for internal / admin panel paths — the exact list is served on every page load.
- Surface prediction: attackers can prepare exploit payloads for `/dev/admin/*` in advance and immediately test them the moment any dev-gate weakens.
- OSINT enrichment: reveals preview / mock / test routes running alongside prod.

Direct exploitation is not currently possible because `/dev/*` routes return 404 in production. Reported as P4-P5 under the applicable bounty rubric.

## Recommendation

1. Disable Sentry route manifest injection via Sentry SDK config (see `withSentryConfig` options in current `@sentry/nextjs` version). Look for a flag that suppresses `_sentryRouteManifest` on client bundles.
2. Remove `/dev/*` route files from production Next.js build. Use `next.config.js` build hooks or split dev-only routes into a separate non-deployed app.
3. Add runtime middleware guard returning `NOT_FOUND` on `/dev/*` in production regardless of file presence.

## PoC Evidence

<curl output + verified 404 status for each `/dev/*` route>
```

## Field-Tested Response Times

Popi triage response time unknown as of 2026-07-14 (report drafted but not yet submitted). Update this file after submission with actual response time and payout.

## Related Patterns to Chain

If Sentry manifest reveals `/api/rpc-ws` or WebSocket endpoints not documented, probe them separately — same JS bundle often exposes internal admin GraphQL, tRPC procedures, or REST admin endpoints. Standard hunt: `grep -oE '/api/[a-zA-Z0-9_/\-]+' bundle.js | sort -u`.
