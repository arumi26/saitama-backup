# Reference: Verification & PoC — Exploit Development (v3)

> Goal: prove the bug is real and exploitable with clean, working code.
> The exploit speaks. The code proves.

## PoC Principles

1. **Minimal but complete** — Fewest steps that prove the exploit path end-to-end.
2. **Working code** — Runnable Foundry test, bash one-liner, or Python script. Not pseudo-code.
3. **Full path** — Show the complete attack: setup → trigger → impact.
4. **Reproducible** — Someone else can clone and run it without guessing.
5. **Documented** — Every step explained, every command included.

## What Makes a PoC "Enough"

| Bug | Sufficient proof | Goal |
|---|---|---|
| IDOR | Access another user's resource | Show authorization boundary violated |
| SQLi | Extract data via UNION or blind exfiltration | Prove data access |
| SSRF | Hit internal service or metadata endpoint | Prove internal network access |
| RCE | Execute command, return output | Prove code execution |
| XSS | Execute arbitrary JavaScript in target context | Prove script injection |
| Web3 Reentrancy | Drain funds in Foundry fork test | Prove funds extractable |
| Web3 Oracle | Manipulate price + extract via flash loan in fork | Prove mispricing exploitable |
| Web3 Access Control | Call protected function from unauthorized address in fork | Prove access bypass |

## Reproduction Documentation

Record exactly so anyone can reproduce:
- Prerequisites: accounts/roles needed, initial state, environment setup.
- Numbered steps: every action + relevant request/response.
- Observed vs expected results (why it's a bug).
- Artifacts: screenshots, logs, request dumps.
- Timestamp & request IDs (for vendor log correlation).

## PoC Template (for reports)

```
## Reproduction
Prerequisites: [setup details]

1. [Step one — with exact command/request]
2. [Step two]
3. [Step three]
4. [Observe result — exploit succeeded]

Evidence: [screenshot/log/script output]

Impact note: [what this means for the system/protocol]
```

## For Web3: Foundry Fork PoC Template

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract ExploitTest is Test {
    // Contract interfaces
    ITarget target;
    IERC20 token;
    
    address attacker = address(0xBAD);
    
    function setUp() public {
        // Fork mainnet at specific block
        vm.createSelectFork("MAINNET_RPC_URL", BLOCK_NUMBER);
        
        // Setup attacker with starting funds
        vm.deal(attacker, 10 ether);
        // Deal tokens if needed
    }
    
    function testExploit() public {
        vm.startPrank(attacker);
        
        // Step 1: Setup
        // Step 2: Trigger vulnerability
        // Step 3: Extract funds
        
        // Assert exploit worked
        assertGt(token.balanceOf(attacker), initialBalance);
        
        vm.stopPrank();
    }
}
```

## For Web: Curl/HTTP PoC Template

```bash
# Step 1: Setup / authenticate
curl -X POST https://target.com/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# Step 2: Exploit the vulnerability
curl -X GET https://target.com/api/users/999 \
  -H "Authorization: Bearer <token>" \
  -H "X-Forwarded-For: 127.0.0.1"

# Step 3: Observe — returns admin user data despite limited role
```

## Redaction

- Censor tokens, cookies, PII, keys in all artifacts.
- Store evidence securely, delete when no longer needed.
- For Web3: include PoC script (Foundry test) + fork instructions.

---

# VERIFICATION GATE — L0 TO L4

A candidate becomes **VERIFIED** only when the technical claim is demonstrated.

Required (all eight):

1. attacker capability
2. exact entry point
3. root cause
4. execution path
5. violated invariant
6. affected state/asset
7. reproducible result
8. security impact

---

## CHAIN HUNTING

Core idea: severity is often a property of the CHAIN, not the individual
finding. Most triagers score bugs in isolation — the job here is to score
them as a system.

### Process
1. Keep a running "findings ledger" for EVERY target, including bugs
   that would normally get thrown away (Low, Info, "won't fix",
   rate-limited, duplicate). Format per entry: what it leaks/bypasses,
   what precondition it needs, what precondition it satisfies for
   something else.
2. After each new finding, ask three questions:
   - What does this GIVE that wasn't available before (an ID, a
     token, a timing oracle, a state that can be forced, an object
     that can now be referenced)?
   - What does this bug NEED that another finding in the ledger
     already produces?
   - Does this skip a step in a flow that was previously gated
     (auth, ownership check, rate limit, CAPTCHA)?
3. Common chain shapes to actively test for. Each shape below is backed
   by at least one publicly disclosed report or named researcher —
   these are PRECEDENT for what to hypothesize and test, not evidence
   for the current target. A cited precedent NEVER substitutes for
   this target's own REACHABILITY_CHECKED / VERIFIED steps (see
   `Chain evidence gate` below) — it only tells you the shape is worth
   hunting for.

   - **IDOR (read-only, "Low") + predictable/sequential ID generation
     → account takeover.** Precedent: MTN Group, HackerOne report
     #1272478, "IDOR Leads To Account Takeover Without User
     Interaction"; Automattic/CrowdSignal, "IDOR when editing users
     leads to Account Takeover without User Interaction" (178
     upvotes).
   - **CSRF on a "harmless" endpoint + stored XSS elsewhere + no
     re-auth on a sensitive change → account takeover.** Precedent:
     InnoGames, HackerOne, "Chaining Bugs: Leakage of CSRF token
     which leads to Stored XSS and Account Takeover" (186 upvotes,
     $1,100) — title literally names this as a chain.
   - **Open redirect ("Low", "just phishing") + OAuth flow that
     trusts redirect_uri or postMessage origin loosely → token/code
     theft or account takeover.** Precedent: Uber, HackerOne, "Open
     Redirect on central.uber.com allows for account takeover"
     ($8,000); Frans Rosén (Detectify Labs), "Account hijacking using
     'dirty dancing' in sign-in OAuth-flows" — stealing OAuth tokens
     via a mis-scoped postMessage listener, no XSS required.
   - **Business-logic race condition (double-spend on a coupon/wallet/
     limited-resource endpoint) + missing server-side recompute →
     arbitrary discount, negative balance, or resource overdraw.**
     Precedent: James Kettle (Director of Research, PortSwigger),
     "Smashing the State Machine: The True Potential of Web Race
     Conditions" — the reference research for this entire bug class.
   - **Small SSRF/open-redirect primitive in shared infrastructure
     (a library, a CDN feature, a common framework) → chained into
     cache poisoning + stored XSS → impacts every site built on that
     shared component, not just one target.** Precedent: Sam Curry
     et al., "Exploiting Web3's Hidden Attack Surface: Universal XSS
     on Netlify's Next.js Library" — an open-redirect + SSRF bug in
     the `netlify-ipx` module chained to persistent XSS across dozens
     of sites (Gemini, PancakeSwap, Docusign, MoonPay, Celo) that
     happened to share the same vulnerable dependency. Lesson:
     when a primitive is found in a library/framework rather than
     target-specific code, check who else depends on it.
   - **Information disclosure (internal email, user ID, staff role,
     debug endpoint) + weak/missing rate limit on a sensitive action
     → credential stuffing or brute-force becomes feasible at scale.**
     General pattern, well documented across multiple disclosed
     reports; not tied to one specific named report here — treat as
     a textbook shape to test, same rigor as the cited ones.
   - **SSRF that can only reach internal metadata (looks "Low" if
     cloud blocks external egress) + a separate internal-service auth
     bypass found via JS/route disclosure → full internal pivot.**
     General pattern (the metadata-SSRF-to-internal-pivot shape is
     best known from the 2019 Capital One breach, which was an
     exploited production incident, not a bug-bounty report) — no
     single disclosed bug-bounty report is cited here; test it with
     the same skepticism as an uncited hypothesis, not as a
     precedent-backed one.
4. Re-test rejected/duplicate reports periodically against NEW
   findings on the same target — a bug marked Low six months ago can
   become the missing link for a Critical chain today.
5. When writing up a chain, report it as ONE finding with a single
   PoC that walks step 1 → step N, and explicitly state the
   standalone severity of each component vs. the combined impact.
   This is what gets chains upgraded from Low to Critical in
   triage — the triager's impact analysis is being done for them.

### Chain evidence gate (mandatory)

A chain is NOT exempt from the normal lifecycle just because each
component looks small. The composed chain follows the SAME state
machine as a single finding (SKILL.md CANDIDATE LIFECYCLE):

1. Each individual component used in a chain must independently carry
   its own state (CANDIDATE / REPRODUCED / REACHABILITY_CHECKED /
   VERIFIED). Pulling a still-CANDIDATE or REPRODUCED-only finding
   into a chain does NOT upgrade it — it stays capped at its own
   state's severity ceiling.
2. The chain's end-to-end PoC (step 1 → step N, run as one continuous
   path) must itself pass REACHABILITY_CHECKED — i.e. every
   precondition handed from one step to the next must come from a
   public/adversary-reachable call, not from manually seeding state
   to "skip ahead" to the next component. A chain PoC that seeds any
   intermediate state is FIXTURE-VERIFIED, capped at MEDIUM, same as
   any other fixture-seeded finding.
3. Only once the full chain reproduces end-to-end through reachable
   state does it become VERIFIED, and only then does the COMBINED
   impact (not any single component's impact) get used for severity/
   CVSS scoring.
4. A Low/Info component sitting in the ledger with no verified
   partner yet stays reported (or held) at its own real severity —
   never pre-emptively written up as "part of a future critical
   chain" without the chain itself being demonstrated.

This keeps chain hunting from becoming a shortcut around the
REACHABILITY GATE and NO-OVERCLAIM rules (SKILL.md EXECUTION PROTOCOL
/ CANDIDATE LIFECYCLE) — it's a discovery technique for what to test
next, not a severity-inflation technique.

---

## EVIDENCE LEVEL

```
L0 — IDEA Interesting hypothesis. Not ranked.
L1 — CANDIDATE Technical evidence suggests a possible issue. Not ranked.
L2 — REPRODUCED PoC executed, bug mechanism confirmed to run — Not ranked.
even if via fixture-seeded state (proves code
PATH only, not reachability).
L2.5 — REACHABILITY_CHECKED Every precondition the PoC relied on Not ranked yet.
traced to a public/adversary-reachable path.
Failing this caps severity at MEDIUM even if
L2 reproduction was clean (FIXTURE-VERIFIED).
L3 — VERIFIED Root cause + reachability + security Eligible for ranking.
consequence all demonstrated.
L4 — SUBMISSION READY Verified + dedup + scope + impact + final review.
```

Levels are monotone: never skip a level, never promote on plausibility.
L2→L3 is NOT direct — L2.5 (REACHABILITY_CHECKED) is mandatory between
them. A PoC that only reproduces via fixture-seeded state stays capped
at L2.5-failed (= FIXTURE-VERIFIED, max MEDIUM severity) permanently,
regardless of how clean the reproduction is.
(These map 1:1 to the state ladder in SOUL.md EVIDENCE DISCIPLINE and
SKILL.md CANDIDATE LIFECYCLE — only L3+ may be RANKED, only L4 may be
submitted.)

---

## REPRODUCTION

Prefer:

* deterministic PoC
* minimal steps
* exact environment
* exact contract/deployment
* transaction/test evidence

Reproduce repeatedly where practical.

The Foundry/Web3 and Curl/Web templates above are the standard carriers for
this evidence — a PoC that cannot be re-run by a third party is L1, not L2.

---

## FAILURE CLASSIFICATION

```
NOT_REPRODUCED
DISPROVEN
BLOCKED
ENVIRONMENT_LIMITATION
UNKNOWN
CONFIRMED
```

Never convert UNKNOWN into PASS.

Each failed attempt gets a classification, not a shrug — the classification
dictates the next move (SOUL.md AUTO-PIVOT): DISPROVEN closes the lane,
BLOCKED/ENVIRONMENT_LIMITATION record the blocker, UNKNOWN keeps the
hypothesis alive with a changed approach.

---

# DEDUP / KNOWN-ISSUE CHECK

Never submit before duplicate verification.

---

## PROGRAM DISCLOSURES

Search:

* disclosed reports
* resolved findings
* security disclosures
* incidents

Compare:

* root cause
* attack path
* affected component
* impact

---

## REPOSITORY

Search:

* GitHub Issues
* Pull Requests
* SECURITY.md
* security commits
* discussions

Search by:

* function
* contract
* error
* vulnerability class
* invariant

---

## AUDITS

Inspect:

* audit reports
* contest findings
* remediation reports
* post-audit changes

---

## DEPLOYMENT HISTORY

Compare:

* current source
* deployment commit
* audited commit
* patched commit
* deployed bytecode where available

---

## CLASSIFICATION

```
EXACT_DUPLICATE
LIKELY_DUPLICATE
RELATED_BUT_DISTINCT
NEW_ROOT_CAUSE
UNKNOWN
```

If UNKNOWN:

- UNVETTED
- do not submit

---

## FINAL RECORD

Every candidate carries a dedup record before submission:

```
Program disclosures:  PASS / FAIL / UNKNOWN
Repository:           PASS / FAIL / UNKNOWN
Audits:               PASS / FAIL / UNKNOWN
Deployment history:   PASS / FAIL / UNKNOWN

Result: [classification]
```

All four lanes PASS → L4 reachable. Any UNKNOWN → stays below submission gate.
