# Reference: Web3 / Smart Contract Exploitation (v2)

> Full coverage: finding, exploiting, and proving vulnerabilities in smart contracts,
> dApps, and on-chain systems. PoC in Foundry/Hardhat fork — prove exploits work safely.
## PRIORITY ENTRY POINTS — check before systematic checklist

Before running the full CORE ATTACK SURFACES checklist, identify these
first (highest historical Critical/High density):

1. **Value-moving functions** — any function that transfers/mints/burns/
   withdraws tokens or ETH. Map every one before anything else.
2. **Privilege-changing functions** — ownership transfer, role grant,
   pause/unpause, upgrade trigger, admin-only setters that affect economics.
3. **Price/oracle read paths** — anywhere the contract reads a price and
   acts on it (borrow, liquidate, mint, redeem).
4. **External call + state-write ordering** — every external call; check
   what state is written before vs after it (reentrancy surface).
5. **Initialization/upgrade entry** — constructor vs initializer, proxy
   admin, storage layout across implementations.

Rule: map these 5 categories for the target FIRST. Only after they're
covered, run the full CORE ATTACK SURFACES / INVARIANT-FIRST checklist
for remaining coverage. A bug in category 1-2 is worth more than ten bugs
in categories outside this list — spend disproportionate time here.


## GOVERNANCE & TRUST ASSUMPTIONS (non-code attack surface)

2026 data: majority of largest losses did NOT come from a code bug —
they came from governance process, key management, or social
engineering (Drift: months-long fake trading-firm social engineering
to gain contributor trust; StablR: key management/governance failure,
not a contract bug).

Before/alongside code review, map:
- Who holds admin/owner keys? Single key, multisig, timelock?
- What's the signer-change process? Can it be socially engineered?
- Is there a trusted-contributor onboarding path that could be abused?
- Config/infra outside the repo (RPC provider, relayer, oracle feeder)
  — who controls it, and is that control verifiable on-chain or just
  claimed off-chain?
- Does CI/CD (GitHub Actions, deploy scripts) have access to deployer/
  admin private keys? A compromised pipeline is a compromised admin key
  — map this even though it's "just infra," because it directly reaches
  on-chain privilege.

This surface is often genuinely out of a code-audit's scope — but
worth noting explicitly as a governance/process finding (not Critical
without demonstrated compromise), per SCOPE DISCIPLINE.

## PATTERN-MATCH BEFORE GENERIC SCAN

Before generic hypothesis generation, check known root causes for this
specific protocol TYPE:
- Lending/CDP → liquidation math, collateral ratio, bad-debt socialization
- AMM/DEX → price manipulation, slippage, LP share math (ERC4626-style)
- Bridge → message replay, validator trust, finality assumptions (see bridge.md)
- Staking/rewards → reward calculation drift, double-claim, exit-queue gaming
- Governance → flash-loan voting, timelock bypass, quorum manipulation
- Vault/Pool → first-depositor share inflation, update-before-external-
  call ordering (double-mint via reentrancy), approval/arbitrary-call
  handling on deposit/withdraw paths
- Any signature-gated action → domain separator, nonce, chainId, AND
  check every field the signature is supposed to bind — a field left
  out of the signed payload is forgeable even if signature itself is valid

2026 pattern: privileged-function input left unvalidated, dismissed as
"informational" because "only admin can call it" (Drift pattern) —
still report it. Admin key compromise is a realistic threat model, not
a theoretical one.

Then: check git history for security-related commits/PRs on the categories
above (`git log -S "onlyOwner"`, `-S "require("`, etc. on relevant files) —
areas repeatedly patched = priority attack surface. Pattern-match against
known root causes FIRST, generic checklist SECOND.


## Platform Landscape
- **Immunefi** — largest smart contract bounty platform; rewards based on impact (% of funds at risk). Requires strong technical PoC + realistic funds-at-risk estimate.
- **Code4rena / Sherlock / Cantina** — competitive time-boxed audit contests; findings graded by severity (Critical/High/Medium) + write-up quality + dedup handling.
- **HackenProof, protocol in-house programs** — check individual policies.

## Core Exploit Verification
- **PoC in fork/local/testnet.** Fork mainnet to Foundry/Hardhat to prove the exploit path.
- **Funds-at-risk estimation** must be realistic — don't overclaim, back every number with exploit path proof.
- **Whitehat rescue** only through official program procedures when available.

---

## Smart Contract Vulnerability Classes

### Reentrancy
- **Single-function reentrancy**: external call before state update, check-effect-interaction violated.
- **Cross-function reentrancy**: state shared across functions, one function calls external while other expects clean state.
- **Cross-contract reentrancy**: reentrancy through tokens with hooks (ERC777, ERC721 onReceived, ERC1155).
- **Read-only reentrancy**: view function returns stale state during reentrant call — used for oracle price manipulation.
- **Detection**: grep for external calls before state writes, look for callback-capable tokens.
- **Exploit (Foundry)**:
```solidity
// Attacker contract
function attack() external {
    target.deposit{value: 1 ether}();
    target.withdraw(1 ether);
}
receive() external payable {
    if (address(target).balance >= 1 ether) {
        target.withdraw(1 ether);  // reenter
    }
}
```
- **Fix**: checks-effects-interactions, reentrancy guard (OpenZeppelin), pull-over-push.

### Access Control Failures
- **Detection**: sensitive functions without modifiers; missing `onlyOwner`; uninitialized implementation; init function callable multiple times; role misconfiguration.
- **Exploitation**: call protected functions from unauthorized accounts, reinitialize via delegatecall to implementation, abuse over-privileged roles.
- **Fix**: consistent access modifiers, Ownable/AccessControl patterns, `_disableInitializers()`, init protection.

### Oracle / Price Manipulation
- **Detection**: price from single DEX spot price; no TWAP; dependency on manipulatable reserves; stale Chainlink feeds (no heartbeat check).
- **Exploitation**: flash loan → swap to manipulate pool price → trigger target using manipulated price. Foundry fork PoC.
- **Common targets**: lending protocols (borrow at manipulated price), CDPs (mint more), perps (manipulate funding/mark).
- **Fix**: TWAP or robust oracle (multi-source), sanity bounds, staleness checks, delay mechanisms.

### Integer / Accounting Errors
- **Detection**: rounding favoring attacker, unchecked math (Solidity <0.8 or `unchecked` blocks), share/asset ratio inflation attacks (ERC4626 donation attack), fee calculation errors.
- **Common patterns**: division before multiplication causing precision loss, first-deposit frontrun (donate to manipulate share price), rebase token incompatibility, fee-on-transfer token accounting.
- **Exploitation**: precision attacks — deposit tiny amounts to drain due to rounding to zero.
- **Fix**: safe math libraries, rounding in protocol's favor, invariant validation, virtual shares.

### Logic / Invariant Violations
- **Detection**: protocol invariants (total supply, collateralization ratio, value conservation) broken by specific operation sequences.
- **Exploitation**: Foundry invariant tests (`forge test` with `invariant_` prefix) to find violation paths.
- **Fix**: enforce invariants on-chain, restrict state transitions, add assertions.

### DoS / Griefing
- **Detection**: unbounded loops, gas griefing, dependency on external calls that can revert, block stuffing vectors.
- **Exploitation**: make a function consume all gas (long loop), revert via external dependency, lock funds.
- **Fix**: avoid unbounded loops, pull pattern, gas limits, handle external call failures gracefully.

### Signature Vulnerabilities
- **Detection**: signatures without nonce/domain separator/expiry; cross-chain replay; signature malleability, ECDSA nonce reuse.
- **Exploitation**: replay signatures across contexts/chains, forge via malleability, recover keys via nonce reuse.
- **Fix**: EIP-712 domain separator, nonce, deadline, chainId in digest.

### Front-running / MEV
- **Detection**: sensitive operations without ordering protection (no slippage, no commit-reveal).
- **Exploitation**: sandwich attacks on swaps, liquidation frontrunning, NFT mint sniping, MEV extraction.
- **Fix**: slippage bounds, commit-reveal schemes, private mempool/Flashbots, auction-based ordering.

### Upgradeability & Proxy Vulnerabilities
- **Detection**: storage collision (different layout in impl vs proxy); uninitialized implementation (can be taken over); exposed proxy admin; upgrade without timelock.
- **Exploitation**: self-destruct + CREATE2 to replace implementation, initialize uninitialized implementation, corrupt storage via collision.
- **Fix**: proven proxy patterns (UUPS/Transparent), locked initializer, timelock on upgrades, storage gaps.

### Flash Loan Attack Vectors
- **Detection**: price derived from pool balances, governance voting weight based on holdings, liquidation without incentive.
- **Flash loan sources**: Aave, Uniswap V3, Balancer — typically zero-fee or low-fee.
- **Exploitation pattern**: borrow → manipulate → extract → repay. All in one transaction.
- **Common targets**: oracle-dependent protocols, governance with token-based voting, under-collateralized lending.

### Cross-chain / Bridge Vulnerabilities
- **Detection**: message validation gaps, replay across chains, missing finality checks, validator threshold bypass.
- **Exploitation**: forge cross-chain messages, replay deposits on multiple chains, exploit race conditions.
- **Fix**: replay protection (nonce + chainId), validate message proofs, sufficient validator threshold, finality delays.

---

## dApp / Off-chain Surface

- **Front-end attacks**: misleading signing UI, wrong contract addresses, XSS triggering malicious transactions.
- **API/indexer attacks**: auth bypass on API that controls protocol parameters, IDOR on user data, exposed admin keys.
- **Bridge & cross-chain**: message validation, proof verification, cross-chain replay.
- **Wallet integration**: unlimited approvals, phishing flows via dApp front-end, RPC manipulation.

---

## Contract Analysis Workflow
1. Get verified source from explorer or program repo.
2. Map architecture: actors, fund flows, external calls, trust assumptions, invariants.
3. Form hypotheses per vulnerability class above.
4. Prove with **Foundry PoC on fork** (test that fails = invariant broken).
5. Estimate funds at risk → severity.
6. Report with full exploit scenario, PoC code, financial impact.

## Anti-patterns
- "Just test small on mainnet" → NO. Always fork/testnet for exploit testing.
- Overclaiming "critical, all funds can be stolen" without full exploit path proof.
- Missing scope check: many programs only cover specific contracts, not entire protocol.

---

# WEB3 SECURITY PLAYBOOK — SYSTEMATIC SURFACES

## CORE ATTACK SURFACES (checklist per protocol)

Inspect:

* access control
* reentrancy
* accounting
* oracle manipulation
* price calculations
* rounding
* precision
* liquidation
* flash-loan composition
* token handling
* callbacks
* signatures
* governance
* upgradeability
* initialization
* denial of service
* economic invariants
* cross-contract interactions

---

## INVARIANT-FIRST ANALYSIS

For every protocol identify:

* assets
* liabilities
* balances
* shares
* prices
* collateral
* debt
* permissions
* state transitions

Then define:

**WHAT MUST ALWAYS BE TRUE?**
Most commonly broken invariants in 2026 incidents — start here:
- total supply vs actual collateral/backing
- share price vs underlying asset ratio (vault/pool)
- locked/escrowed amount vs minted/issued amount
Search for ways to violate that invariant.

---

## TOKEN HANDLING

Inspect:

* ERC20 assumptions
* fee-on-transfer behavior
* rebasing
* decimals
* non-standard return values
* callbacks
* approvals
* allowance transitions
* mint/burn authority

---

## ORACLES

Inspect:

* source — who can push a new price (permissionless vs allowlisted feed)
* freshness — staleness window: how old may a price be before rejection
* manipulation resistance — deviation threshold, single-feed vs median
* decimal conversion — base/quote currency mismatch with contract expectation
* fallback behavior — ManualOracle/emergency path (manipulate primary to fail ⇒ force fallback)
* stale data — heartbeat exceeded, feed swap, phaseId changes
* chain-specific differences — feed address/behavior per deployment

Cross-check the oracle axis whenever the contract reads a feed:

* Chainlink (aggregator, heartbeat, deviation) — probe latestAnswer,
  latestTimestamp, phaseId changes, feed-swap history
* Pyth (price feeds, EMA) — probe update fee gating, staleness, confidence
* Custom/Stork-style feeds (RiseX pattern) — probe who may submit price,
  update permission, callback binding, and fallback manual oracle
* Off-chain relays — probe signature binding to (asset, timestamp, id)

Rule: if a protocol's worst case depends on a price being correct, map the
price-update path before anything else.
2026 pattern — cross-protocol oracle: a protocol can unintentionally
BECOME a price oracle for another protocol that reads its pool
reserves/exchange rate directly (not via Chainlink/Pyth, but via
reading another DeFi protocol's own state). Map not just "what oracle
does this read" but "does ANY other protocol treat this contract's
state as a price source" — that makes THIS contract an oracle
attack surface even if it never calls itself one (Makina Finance 2026:
Aave flash loan → Uniswap swap → Curve price read → yield protocol
drain, ~$5M).

---

## ZK / VERIFIER

Inspect:

* verifier contract parameters — correctly matched to the circuit's
  compiled artifact (wrong verifying key = silently accepts invalid proofs)
* public inputs — are ALL values the circuit should constrain actually
  bound as public inputs, or can some be manipulated outside the proof?
* trusted setup — ceremony legitimacy, if applicable
* proof malleability — can a valid proof be altered and still verify?
* edge cases in circuit logic — off-by-one, range checks, unused signals

Rule: a misconfigured verifier (wrong key, unbound input) can make an
ENTIRE ZK system accept fraudulent proofs while every individual
circuit constraint is "correct" in isolation — check the wiring, not
just the circuit.

---

## ACCESS CONTROL MAP

Map:

```
ROLE → HOLDER → FUNCTION → STATE CHANGE → IMPACT
```

Inspect:

* owner
* admin
* role managers
* multisig
* timelock
* upgrade authority

---

## UPGRADEABILITY

Verify:

* proxy
* implementation
* initialization
* upgrade authorization
* storage layout
* migration
* upgrade sequencing
* emergency upgrade mechanisms

---


## COMPOSABILITY

Ask:

Can a safe function become unsafe when combined with:

* another function?
* another contract?
* flash liquidity?
* callback?
* oracle?
* bridge?
* governance action?
2026 pattern: largest exploits increasingly chain 3+ protocols where
EACH is individually audited/safe (Makina Finance: Aave flash loan →
Uniswap swap → Curve price manipulation → yield protocol drain). Don't
stop composability analysis at "is THIS contract safe" — actively map
what OTHER protocols this one reads price/state from or is integrated
with, and simulate the chain, not just the single hop.
Do not analyze every function in isolation.
