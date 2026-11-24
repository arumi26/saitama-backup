# Reference: SMART CONTRACT DEEP HUNT
Note: web3.md PRIORITY ENTRY POINTS identifies WHICH functions matter most
(value-moving, privilege, oracle, external-call, init). This file's
ANALYSIS ORDER defines HOW to dissect those same functions once identified
— run web3.md's 5-category scan first to pick targets, then apply this
file's 12-step order to each target.
> Structured per-contract analysis order. Complements `web3.md`
> (vulnerability classes + playbook) — this file defines HOW to dissect a
> single contract system end-to-end, in the order that maximizes early
> discovery of high-severity bugs.

---

# ANALYSIS ORDER

Work in this sequence — architecture first, interactions last:

1. Architecture
2. Trust boundaries
3. State variables
4. Access control
5. External calls
6. Accounting
7. Token handling
8. Oracle logic (see Oracle Attack Paths below)
9. Initialization
10. Upgradeability
11. Failure paths
12. Cross-function interactions

Rule: do not jump to PoC before steps 1-4 are mapped. Most critical bugs are
visible at the architecture/trust-boundary layer before any line is executed.
Note: Upgradeability/proxy (steps 9-10) is now OWASP SC10 (2026) —
treat storage-collision + re-initialization + delegatecall-to-untrusted
as a priority tier, not an afterthought, even on contracts that look
"simple" at first read.

---

# SECURITY INVARIANTS

For each major state variable identify:

* who can modify it;
* how it changes;
* what must remain true;
* what functions depend on it.

Build the invariant table early — every later finding is measured against it.
An unviolated invariant after full analysis = coverage evidence, not proof of safety.

---

# EXTERNAL CALLS

Inspect:

* call target
* caller-controlled target
* return handling
* callback behavior
* reentrancy
* state updates before/after call

Aggressive extension:
* mint/share-issuance ORDER vs internal balance update — if shares are
  minted before internal accounting reflects the deposit (or vice versa),
  a reentrant or sequenced call can double-mint even without draining
  funds via the "classic" external-call-before-state-update pattern
  (Solv Protocol 2026, ~$2.7M)
* who can deploy a malicious target contract (user-supplied addresses = top severity)
* low-level calls whose false return is silently ignored (`(bool ok,) = x.call();` unused)
* calls into tokens with hooks — assume the hook reenters and check the code path
* read-only reentrancy: view functions consulted by other protocols mid-callback


---

# ORACLE ATTACK PATHS

Price/feed trust is a composability boundary. For every oracle consulted:

* who can push a new price? (permissionless submitOrder vs allowlisted feed)
* how is the feed value read? (view call, callback, event, off-chain)
* staleness window — how old may a price be before it is rejected?
* deviation threshold — how far may aggregation drift before trigger?
* single-feed vs median: is a single source trusted without cross-check?
* fallback path: what happens when primary oracle reverts (ManualOracle
  fallback = classic bypass: manipulate primary to fail, force fallback)
* manipulation via liquidity: can a cheap trade move the TWAP/EMA input?
* EMA lag: fast price move vs slow moving-average → liquidation window
* decimal/base-currency mismatch vs the contract's expected quote
* read-only reentrancy: view fn of oracle called mid-transaction that
  can be influenced by tx caller
* chainlink-like fallback triggers: heartbeat exceeded → emergency mode

Severity rule: a manipulated price that changes liquidation/PnL/margin
= direct fund loss; a stale price that freezes withdrawals = DoS.


---

# ACCOUNTING

Trace:

```
DEPOSIT → INTERNAL ACCOUNTING → SHARE/BALANCE UPDATE → WITHDRAW → FINAL ASSET FLOW
```

Look for:

* rounding
* precision loss
* stale values
* inconsistent units
* incorrect share pricing
* missing accounting updates

Aggressive extension:

* conservation check: `sum(balances) == recordedTotal` before vs after every operation
* first-depositor / donation inflation paths
* dead-share handling and dust absorption
* fee-on-transfer and rebasing tokens breaking the deposit == share assumption
* simulate a full deposit→withdraw roundtrip in a fork — value out MUST equal value in
  (minus explicit fees); any drift = candidate

---

# INITIALIZATION

Check:

* constructor
* initializer
* reinitializer
* initialization state
* proxy initialization
* privileged setup

Aggressive extension:

* can the implementation contract itself be initialized (self-hosted proxy)?
* reinitializer version gaps (skip a version, replay old init)
* init parameters set from user input before access control kicks in
* timelock/proxy admin upgrade path initialized but unprotected
* These "Aggressive extension" bullets are concrete instantiations of
SOUL.md's RED-TEAM HUNT expansion categories (STATE/FLOW/ECONOMIC) for
this specific analysis step — not a separate checklist.

---

# VARIANT HUNT

When one vulnerability is confirmed, search the same root cause across:

* sibling functions
* sibling contracts
* inherited contracts
* proxy implementations
* other deployments
* other chains

One root cause = a family of bugs. Exhaust the family before writing the
first report — dedup within your own findings first, then submit the full
set with the shared root cause stated once.

Each variant is its OWN candidate — runs its own REACHABILITY_CHECKED
and VERIFIED gate independently. A confirmed root cause does not grant
inherited severity to siblings; a sibling function with the same pattern
but different/absent precondition access stays capped separately.
