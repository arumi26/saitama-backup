---
skill: oauth
title: "OAuth / OIDC"
category: "Security · Auth"
load_when: "Any 'Sign in with…' / OAuth / OIDC / SSO."
pack: SUPERAGENT V10
bughunt: true
---
# OAuth / OIDC

## Where it pays
Full ATO, often one-click.

## Signals
redirect_uri, state, code/token in URL, account linking.

## Methodology
1. redirect_uri loose match → steal code/token.
2. Missing state → login CSRF.
3. Token leak via referer/fragment.
4. Account pre-hijack; scope/consent; PKCE downgrade.

## Validation gate
Obtain a valid session/token for an account you don't own.

## Impact & chains
**ATO** at scale; chains with open redirect + subdomain takeover.

**→ next on hit: `../phases/04-chain.md`.**
