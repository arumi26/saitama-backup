# Stake.com Deep Source Audit — Sep 2026
Findings from StakeAPI + Stake-scraper source audit.

## GraphQL Surface (Confirmed)
- `UserProfile`, `UserBalances`, `BetHistory` — authenticated
- `AllHouseBets`, `CurrencyConfiguration(isAcp:Boolean!)`, `SportFixtureList`, `liveSportFixtureList` — possibly public
- `requestLoginUser` — unauthenticated login start
- `completeLoginUser` — 2FA completion
- `casinoBet`, `sportBet` — authenticated betting

## Auth
- session cookie == x-access-token (interchangeable)
- 2FA mandatory on login (requiresLoginCode field)
- Auth module is obfuscated .pyc — skip

## Findings (Need Account)
1. Float precision in bet amounts (`Float!`) — $25K-$100K if exploitable
2. isAcp privileged data exposure
3. Sport fixture IDOR via offset enum
4. preferenceHideBets client-side only

## CORS Triage
`ACAO:* + ACAC:true` on OPTIONS preflight ≠ browser-exploitable. Browsers reject with TypeError. Only report if actual POST also reflects ACAO.

## Network Detection
- CF 403 = Cloudflare JS challenge (response: "Just a moment...")
- ERR_CONNECTION_CLOSED = ISP TCP block (connection reset)
- From curl: CF sends HTML, ISP sends nothing/reset

## Kali Transfer
SSH MOTD banner breaks SCP. Use: `base64 -w0 file | ssh user@host "base64 -d > file"`

## Admin Paths (all 403)
/api/v1/admin, /admin, /backoffice, /api/v1/operator, /api/v1/kyc, /_api/graphql/admin

## Source Files
client.py (597 lines, full auth flow), endpoints.py (all queries + REST map), stake_scraper.py (sports fixture queries)