---
skill: saml
title: "SAML"
category: "Security · Auth"
load_when: "Enterprise SSO using SAML (ACS, SAMLResponse)."
pack: SUPERAGENT V10
bughunt: true
---
# SAML

## Where it pays
Enterprise ATO and cross-tenant SSO bypass.

## Signals
base64 SAMLResponse; signatures; assertions.

## Methodology
1. Signature exclusion.
2. XML Signature Wrapping (SAML Raider).
3. XXE in assertion.
4. Replay; audience/recipient confusion; comment injection in NameID.

## Validation gate
Authenticate as another/privileged user via forged/wrapped assertion.

## Impact & chains
**ATO**, cross-tenant, admin impersonation.

**→ next on hit: `../phases/04-chain.md`.**
