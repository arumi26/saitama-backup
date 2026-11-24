# Stake.com Admin Panel ConOPS (2026-09-02)

## Target: stake.com (crypto casino/gambling, Immunefi program)

## API Architecture
- POST https://api.stake.com/_api/graphql (legacy subdomain, no CF)
- POST https://stake.com/_api/graphql (current, CF Managed Challenge)
- Auth: X-Access-Token header = session cookie value
- cf_clearance cookie required for CF-protected endpoints

## GraphQL Schema (reverse-engineered from 3 community repos)
Public queries (no auth): AllHouseBets, CurrencyConfiguration, SportFixtureList
Auth mutations: RequestLoginUser, CompleteLoginUser, SportBet
Login response leaks: roles, flags, KYC status, active/previous seeds

## Identified Vulnerabilities
1. GraphQL introspection enabled without auth
2. Role/flag/KYC data returned in CompleteLoginUser response
3. SportBet mutation has no visible server-side amount cap
4. contentNotes linkUrl = stored XSS vector in admin panel
5. x-lockdown-token header = empty default accepted
6. Two API subdomains have inconsistent auth enforcement
7. No GraphQL query depth/complexity limit
8. GraphQL batching: 10 mutations per HTTP request (rate limit bypass)

## Source Repos
- ljk1072911239/stake.com-Scraper-and-Autobetting-tool
- ChipaDevTeam/StakeAPI  
- LennyMalcolm0/Stake-Replica
