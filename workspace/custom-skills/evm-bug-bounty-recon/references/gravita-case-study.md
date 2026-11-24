# Gravita Protocol — Case Study (2026-07-16)

## Target Profile
- **Protocol:** Gravita Protocol (CDP/Liquity fork, multi-collateral)
- **TVL:** ~$12M
- **Chain:** Ethereum + Scroll
- **Source:** `Gravita-Protocol/Gravita-SmartContracts` (GitHub)
- **Audit:** Dedaub, April 2023

## Findings

### CRIT-01: Batch Liquidation Price Reuse (NOVEL)
**Code:** `VesselManagerOperations.sol` lines 64, 121
**Bug:** `vars.price = fetchPrice(_asset)` fetched once, used for up to 25 vessels
**Combined with:** PriceFeed.sol no TWAP (direct `latestRoundData()`)
**Exploit chain:** Flash loan → manipulate spot price → batch liquidated at fake price
**Verdict:** ECONOMICALLY UNEXPLOITABLE → attack cost $2.5M vs profit $250K max
**Bounty estimate:** $500-2,000 (informational, novel but unprofitable)

### HIGH-01: ETH Oracle Single Point of Failure (NOVEL)
**Code:** `PriceFeed.sol` lines 175-178 (`_calcEthIndexedPrice`)
**Bug:** ALL ETH-indexed assets depend on `fetchPrice(address(0))`
**Impact:** Cascade liquidations if ETH oracle compromised
**Bounty estimate:** $5,000-10,000

### Key Lesson
**Not in Dedaub audit → novel.** But CDP pattern well-studied → high background knowledge risk.
Economically unfeasible to exploit → downgrade from Critical to Informational.
**Target rating: 4/10** — good for learning, bad ROI.

## Files Produced
- `/tmp/gravita_findings.md` — raw findings
- `/tmp/gravita_report_final.md` — submission-ready report
- `/tmp/gravita_verdict.md` — honest assessment + ROI analysis
- `/tmp/dedaub_audit.txt` — competitor audit extract
- `/tmp/Gravita-SmartContracts/` — source clone