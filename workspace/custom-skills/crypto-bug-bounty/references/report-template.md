# Bug Bounty Report Template

## Submission Format (Immunefi/HackerOne)

### Title
`[SEVERITY] Protocol Name - Brief Description`

Example: `[CRITICAL] Flaunch - Cross-Chain Implementation Swap Allows Silent Backdoor`

### Summary
2-3 sentences describing the vulnerability and its impact.

### Severity
- **CRITICAL:** Direct theft of funds, permanent freeze, protocol insolvency
- **HIGH:** Temporary freeze, significant fund loss, governance bypass
- **MEDIUM:** Minor fund loss, DOS, information disclosure
- **LOW:** Gas optimization, minor issues

### Vulnerable Code
```solidity
// File: Contract.sol
// Lines: 100-110
function vulnerableFunction() external {
    // Bug here
}
```

### Attack Flow
```
1. Attacker calls X with parameter Y
2. Protocol processes without validation Z
3. Attacker receives W amount of tokens
```

### Impact
- Funds at risk: $X
- Number of users affected: Y
- Duration of vulnerability: Z

### Proof of Concept
```solidity
// Foundry test
function testExploit() public {
    // Setup
    // Attack
    // Assert
}
```

### Remediation
```solidity
// Fixed code
function fixedFunction() external {
    // Fix here
}
```

## Submission Strategy

### First DM (Brief)
```
Hi [Team],

I found a critical vulnerability in [Contract] that allows [impact].

I have a working Foundry PoC with X/X tests passing. Can I share the full report?

Best,
[Your name]
```

### Wait 24-48 hours for response.

### Second DM (Full Report)
- Send full report WITHOUT PoC code
- Ask about bounty program
- Wait for confirmation

### Third DM (PoC Code)
- Only after they confirm bounty program
- Send Foundry test file
- Include reproduction steps

### If No Response
- Public tweet (responsible disclosure)
- Tag security researchers (@samczsun, @tayvano_)
- Wait 90 days before full disclosure

## CVSS Scoring

### Attack Vector (AV)
- Network (N): Remote exploitation
- Adjacent (A): Local network required
- Local (L): Local access required
- Physical (P): Physical access required

### Attack Complexity (AC)
- Low (L): No special conditions
- High (H): Requires specific conditions

### Privileges Required (PR)
- None (N): No authentication needed
- Low (L): Basic user access
- High (H): Admin access needed

### User Interaction (UI)
- None (N): No user action needed
- Required (R): User must take action

### Impact (CIA)
- High (H): Complete loss
- Low (L): Partial loss
- None (N): No impact

### Example CVSS Vector
`CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` = 9.8 Critical

## Bounty Estimation

| Severity | Typical Range | Immunefi |
|----------|---------------|----------|
| Critical | $50K-$10M | $50K-$10M |
| High | $10K-$100K | $10K-$100K |
| Medium | $1K-$10K | $1K-$10K |
| Low | $0-$1K | $0-$1K |

**Note:** Actual bounty depends on:
- TVL at risk
- Protocol's bounty budget
- Uniqueness of finding
- Quality of PoC
