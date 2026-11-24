# CROSS-CHAIN / BRIDGE HUNT

Activate when the target:

* bridges assets;
* sends cross-chain messages;
* uses relayers;
* uses validators;
* supports multiple chains;
* uses wrapped/canonical assets;
* has cross-chain governance.

---

# MESSAGE AUTHENTICATION

Verify:

* source chain
* destination chain
* source contract
* destination contract
* message ID
* nonce
* signatures
* validator set

Ask:

Can a valid message from one domain be accepted in another?

---

# REPLAY

Inspect:

* nonce
* message ID
* consumed-message tracking
* chain separation
* replay after failure
* replay after upgrade
* replay across deployments

---

# VALIDATORS / RELAYERS

Inspect:

* quorum
* signature threshold
* signer management
* stale signer sets
* unauthorized signers
* validator rotation

---

# TOKEN ACCOUNTING

Trace:

```
SOURCE LOCK/BURN → MESSAGE → DESTINATION VALIDATION → MINT/RELEASE
```

Verify conservation of value.

---

# FAILURE HANDLING

Investigate:

* failed message
* retry
* partial execution
* refund
* stuck funds
* cancellation
* emergency recovery

---

# UPGRADE / GOVERNANCE

Inspect:

* implementation upgrades
* validator changes
* trusted roots
* emergency admin
* timelock
* multisig

---

# MULTI-CHAIN VARIANT HUNT

When one issue is confirmed, inspect:

* every supported chain
* equivalent deployments
* chain-specific configuration
* chain-specific addresses
* different validator configurations
* different upgrade states

Same rule as smart-contract.md VARIANT HUNT: each chain/deployment is its
OWN candidate with its own REACHABILITY_CHECKED gate — a confirmed bug
on Chain A does not auto-inherit VERIFIED status for Chain B if the
validator config/deployment differs.

---

# EVIDENCE GATE (applies same as web3.md/smart-contract.md)

Every finding here still runs the full ladder: CANDIDATE → REPRODUCED →
REACHABILITY_CHECKED → VERIFIED. A signature-forgery or replay PoC built
by manually crafting a message in a test harness (not through the real
relayer/validator flow) is REPRODUCED only — check whether an actual
attacker could get that message signed/relayed before claiming severity.

Severity note: a confirmed signature-verification bypass or validator-
threshold flaw is typically CRITICAL (see examples.md: Ronin Bridge
pattern) — but only once the attack path to obtain/forge valid signatures
is demonstrated, not just "the check looks weak."

---

# 2026 PATTERN: TRUST ASSUMPTION OUTSIDE CODE

Biggest bridge losses in 2026 increasingly involve NO code bug — the
exploit is in off-chain trust config (DVN/verifier count, RPC
misconfiguration, relayer compromise) that sits outside typical audit
scope. Before declaring a bridge "clean" from code review alone, ask:

- What is the ACTUAL verifier/DVN threshold in production (not just
  what the code allows)? Config can diverge from code.
- Can a forged "retry message" produce value from nothing (replay/retry
  path exploited beyond normal first-message validation)?
- What was the INITIAL state at deploy — any field left at zero/default
  that should have been set (Nomad 2022 root-to-0x00 pattern)?

This is a SCOPE question, not just a code question — note explicitly
if verifier/relayer config is out-of-scope for your audit and flag it
as a finding anyway (governance/config risk, not Critical without
demonstrated compromise).

---

# ADDENDUM — team notes (2026-10-03; appended below the original at the operator's direction — the text above is unchanged)

Three checks the original does not name explicitly; treat them as part of the hunt:

1. **Finality / reorg assumptions** (under MESSAGE AUTHENTICATION + REPLAY): is a
   message accepted before the source chain reaches finality? If the destination
   can act on a source event that a reorg later erases, the result is a
   double-spend even with perfect signature verification. Verify the confirmation
   depth / finality gadget the relayer actually waits for, per chain.
2. **Rate limits / circuit breakers** (under IMPACT assessment): many production
   bridges cap value per message or per period, or pause on anomaly. The presence
   or absence of a working cap determines the demonstrated impact — and therefore
   the severity — of any mint/release or drain finding. Check the cap values in
   production config, not just that a cap mechanism exists in code.
3. **Wrapped / canonical asset mapping** (under TOKEN ACCOUNTING): verify the
   destination-side token mapping is the intended one — wrong mapped token,
   decimal mismatch between lock and mint legs, or a registerable/spoofable
   mapping entry breaks conservation of value without touching signatures.
   Trace one real asset end-to-end: locked amount on source == minted/released
   amount on destination, in the correct token.
