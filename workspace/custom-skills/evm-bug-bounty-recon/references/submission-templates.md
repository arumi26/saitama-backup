# Bug Bounty Submission Email Templates

## Template 1: Initial Disclosure (Redbelly-style, non-Immunefi)

```
TO: {SECURITY_EMAIL}
CC: {YOUR_EMAIL}
SUBJECT: [SECURITY DISCLOSURE] {SEVERITY} — {Brief Title}

Dear {PROJECT} Security Team,

I am an independent security researcher. I am disclosing {N}
security findings in your {CONTRACT_TYPE} deployed on
{NETWORK}.

Contract: {CONTRACT_ADDRESS}
Network:  {CHAIN_ID} ({NETWORK_NAME})
RPC:      {RPC_URL}

EXECUTIVE SUMMARY
-----------------
{N_CRITICAL} CRITICAL — {one-line}
{N_HIGH} HIGH     — {one-line}
{N_MEDIUM} MEDIUM   — {one-line}

FINDING 1 ({SEVERITY}): {TITLE}
{description paragraph}

Attack Scenarios:
  A) {scenario}
  B) {scenario}

Root Cause: {technical root cause in 1-2 sentences}

Full technical details, PoCs, bytecode analysis, and remediation
recommendations are in the attached PDF report.

ACTION REQUESTED:
1. Confirm safe harbor / responsible disclosure policy
2. Provide base contract source for deeper verification
3. Acknowledge {SEVERITY} (CVSS {score}) given confirmed on-chain evidence

All testing was read-only eth_call. No transactions broadcast.

Best regards,
{YOUR_NAME}
Security Researcher
{DATE}
```

## Template 2: Follow-Up (No Response After 7 Days)

```
SUBJECT: RE: [SECURITY DISCLOSURE] {SEVERITY} — {Title} — Follow-up

Hi {TEAM},

Following up on my disclosure from {DATE}. No response received yet.

The vulnerability details remain the same. Confirmed on-chain at
{CONTRACT_ADDRESS}.

Please confirm receipt. Happy to discuss on a call if needed.

Best,
{YOUR_NAME}
```

## Template 3: Bounty Confirmed — Send PoC

```
SUBJECT: RE: [SECURITY DISCLOSURE] {SEVERITY} — PoC Code

Hi {TEAM},

Per your request, attached is the Foundry PoC for the
{SEVERITY} finding.

The PoC:
- Uses forge test with fork mode
- Does NOT require mainnet deployment
- Demonstrates the vulnerability in <{N} steps>
- Can be run against testnet for verification

Best,
{YOUR_NAME}
```

## Submission Channel Priority

1. **Escrow platform** (Immunefi, Cantina, Sherlock, Hashlock) — USDC escrow, verified payout
2. **security.txt** — RFC 9116 standard, programs often auto-registered
3. **Direct email** — info@, bugs@, security@ — no escrow, higher unpaid risk
4. **GitHub SECURITY.md** — last resort

**Preference:** Escrow > email-direct. User expressed frustration with unpaid email submissions.

## Tiered Disclosure Protocol

| Stage | Content | Recipient |
|-------|---------|-----------|
| **Step 1** | Brief description + "I have PoC" | Bounty team |
| **Step 2** | Full report (PDF) without exploit code | Bounty team |
| **Step 3** | PoC code (Foundry test) | Only after bounty confirmed |

This protects researcher from: dev fixes without paying, poaching, non-payment.
