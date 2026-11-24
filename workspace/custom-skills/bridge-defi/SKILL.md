---
skill: bridge-defi
title: "Cross-Chain Bridge & DeFi Logic"
category: "Security · Web3"
load_when: "bridge security, cross-chain bridge, defi exploit, flash loan attack, price oracle manipulation, liquidity, amm, lp drain"
pack: SUPERAGENT V10
bughunt: true
---

# Cross-Chain Bridge & DeFi Logic

## Where it pays
Bridges and DeFi protocols hold huge TVL; logic flaws (validation, oracle, reentrancy, accounting) have caused the largest crypto hacks. Distinct from a generic contract audit.

## Attack-surface signals
Cross-chain bridges (lock/mint, message passing), AMMs, lending, yield vaults, anything using price oracles or external message verification.

## Methodology
1. **Bridge message verification:** can a forged/replayed deposit proof mint on the other chain? Signature/merkle validation gaps. 2. **Oracle manipulation:** flash-loan the price feed to mis-price collateral. 3. **Accounting:** rounding, share-inflation, fee-on-transfer, reentrancy in withdraw. 4. **Access control** on privileged mint/withdraw. 5. Model the exploit with a Foundry fork test.

## Payloads / probes
```
// conceptual checks (fork test, not live)
- replay a processed deposit proof
- flash-loan → skew oracle → borrow underwater
- first-depositor share inflation
- reentrancy on claim/withdraw
```

## Root causes
Unverified cross-chain messages, single-source/ manipulable oracles, unchecked arithmetic/accounting, missing access control.

## Validation gate
Demonstrate on a fork/testnet: forged mint, oracle-driven insolvency, or an accounting drain — never on live funds.

## Impact & chains
Fund theft, infinite mint, protocol insolvency. Chains with web3/smart-contract-audit and web3/token-scan.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "bridge security, cross-chain bridge, defi exploit, flash loan attack, price oracle manipulation, liquidity, amm, lp drain"
```

→ Report with `../reporting/writeup.md` (CWE-840); validate with `../reporting/validation-gate.md`.
