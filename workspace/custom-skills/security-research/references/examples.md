# Reference: Real Disclosed Bug Patterns (by category)

> Pattern-match hypotheses against these BEFORE generic checklist scanning.
> Read during phase 3 (ANALYZE). Low→Medium tier — foundational patterns.

## WEB2

**LOW — self-XSS / no session impact**
Case: reflected XSS only triggers on attacker's own session, no way to
force victim to visit crafted URL with real impact.
Impact: no cross-user consequence → Low, usually not accepted.

**MEDIUM — IDOR data disclosure**
Case: endpoint returns private data for ANY object ID, not just
requester's own (e.g. HackerOne's own /bugs.json, report #2487889).
Root cause: user authenticated, but object ownership never checked.
Impact: private data leak, read-only → Medium.

---

## WEB3 (general / dApp layer)

**LOW — front-end display bug, no signing involved**
Case: UI shows wrong token balance/price but no transaction is affected —
purely cosmetic, user can't be tricked into signing anything.
Impact: no exploitable path → Low/Informational.

**MEDIUM — front-end signing UI mismatch**
Case: dApp shows "Approve 10 USDC" but actual transaction requests
unlimited (2^256-1) allowance. User signs without noticing.
Root cause: UI doesn't reflect real calldata being signed.
Impact: future risk IF funds present, but drain not yet demonstrated
→ Medium until exploit path proven.

---

## SMART CONTRACT (single-contract logic bugs)

**LOW — gas inefficiency / non-exploitable revert**
Case: function reverts under specific input but causes no fund loss,
no DoS beyond that single call, easily retried.
Impact: cosmetic/UX issue only → Low.

**MEDIUM — access control gap on non-critical setter**
Case: setFeeRecipient() missing onlyOwner, callable by anyone, but
fee recipient doesn't control fund custody directly — attacker can
redirect FUTURE fee revenue, not drain existing funds.
Impact: revenue diversion, not principal loss → Medium.

---

## BRIDGE (cross-chain)

**LOW — informational logging gap**
Case: bridge doesn't emit an event on a specific state change, making
off-chain monitoring harder — no direct fund/access impact.
Impact: observability gap only → Low.

**MEDIUM — missing rate limit on withdrawal**
Case: bridge allows unlimited withdrawal volume per block with no
circuit breaker, but validator signature check itself is sound.
Impact: amplifies damage IF another bug found, but alone doesn't
enable theft → Medium (defense-in-depth gap).

---

## LIQUIDITY POOL / AMM

**LOW — negligible dust rounding**
Case: swap math rounds down by 1 wei-equivalent, consistently, no
practical attacker profit path at any realistic trade size.
Impact: theoretical only → Low.

**MEDIUM — front-runnable slippage on small pools**
Case: swap function has no minimum-output check enforced by the
contract itself (relies on off-chain UI slippage setting only).
Attacker can sandwich a large swap on a low-liquidity pool.
Impact: individual user loses value per-trade, not systemic drain
→ Medium.

---

## DEFI (protocol-level economic logic)

**LOW — inconsequential rounding, protocol-favoring**
Case: share calculation rounds DOWN consistently favoring the protocol
(not the attacker) — minor dust left for last withdrawer.
Impact: negligible value leakage, no attacker profit path → Low.

**MEDIUM — reward calculation drift**
Case: staking reward accrual has minor precision drift over long
periods, slightly under/over-paying rewards, but no way for attacker
to trigger it on demand or profit deterministically.
Impact: fairness/accounting issue, not direct exploitable loss → Medium.

---

# ADDENDUM — HIGH / CRITICAL TIER (team addendum 2026-10-03, appended at the operator's direction — the Low→Medium volume above is unchanged)

> The volume above caps at Medium on purpose: each entry shows WHY the
> pattern stops there. This tier is the mirror image — patterns where the
> demonstrated impact crosses into principal loss, full account takeover,
> or systemic compromise. Same discipline: the tier comes from
> demonstrated impact, never from the shape of the bug.
> Read during phase 3 (ANALYZE), same as the volume above.

## WEB2

**HIGH — stored XSS in a session-bearing context**
Case: attacker-controlled content renders unescaped in other users'
authenticated pages (shared thread, comment, profile, support ticket).
Payload executes in the victim's session origin.
Impact: session/action abuse as the victim, wormable in shared contexts
→ High. (Contrast with the Low self-XSS above: the cross-user line is
the whole difference.)

**HIGH — SSRF reaching cloud metadata / internal services**
Case: server-side fetcher takes attacker URLs and returns or acts on
responses from 169.254.169.254 or internal hosts; credentials or
internal data obtained, OOB alone not required once content/action is
demonstrated.
Impact: cloud credential theft / internal pivot → High (Critical when
the credentials yield infrastructure control).

**CRITICAL — SQL injection with data extraction**
Case: injection point demonstrated extracting real data (UNION or blind
exfiltration of user records / credentials), not just an error message.
Impact: mass data breach, credential spill → Critical.

**CRITICAL — authentication bypass for arbitrary accounts**
Case: logic flaw (token forgery, session prediction, reset-flow abuse,
OAuth account-linking confusion) lets an attacker log in as ANY user,
including admins, without the victim's credentials.
Impact: full account takeover at scale → Critical.

---

## WEB3 / SMART CONTRACT

**CRITICAL — reentrancy / ordering drain**
Case: external call (or hook callback) before state update lets the
attacker repeat a withdrawal/mint inside one flow until the contract's
balance or share accounting is exhausted. Proven by fork PoC showing
attacker balance up, protocol balance down.
Impact: direct principal loss → Critical.

**CRITICAL — oracle manipulation with extraction**
Case: price read from a manipulable source (spot pool, single feed,
fallback oracle) moved by flash loan or cheap trade, then consumed by
borrow/mint/liquidate in the same flow to extract value.
Impact: direct fund loss, repeatable while the source stays
manipulable → Critical.

**HIGH — access control missing on a value-moving function**
Case: mint/withdraw/upgrade/setOracle-class function callable by anyone
(contrast with the Medium non-critical setter above: THIS function
touches custody directly).
Impact: principal at risk the moment it is called → High; Critical
once a full drain path is demonstrated end-to-end.

**HIGH — uninitialized / takeover-able proxy implementation**
Case: implementation contract initializable by anyone, or proxy admin
reachable without the documented timelock/multisig, giving control of
upgrade or delegatecall target.
Impact: full protocol control pending one transaction → High;
Critical with a demonstrated malicious-implementation upgrade.

---

## BRIDGE (cross-chain)

**CRITICAL — signature / validator-threshold compromise (Ronin pattern)**
Case: the message-verification trust root itself fails — forged
signatures accepted, threshold met by compromised/stale/attacker-
influenced keys, or a valid message from one domain accepted in
another (domain confusion). Attacker mints/releases assets without a
corresponding lock/burn.
Impact: unbacked minting / vault drain → Critical. This is the pattern
bridge.md cites here. Gate: the path to obtain or forge the valid
signatures must be demonstrated, not inferred from a "weak-looking"
check (bridge.md EVIDENCE GATE); below that demonstration it is a
governance/config finding, not Critical.

**HIGH — replay across domains / after failure or upgrade**
Case: consumed-message tracking missing or reset by upgrade/failure
handling, so one legitimate deposit executes twice (or on two chains).
Impact: double release of real funds → High; Critical when replay is
repeatable at will rather than once per incident.

---

## LIQUIDITY POOL / AMM — DEFI

**CRITICAL — flash-loan-funded price manipulation drain**
Case: pool price used as oracle by a lending/vault protocol; attacker
flash-borrows, skews the price, borrows/mints/redeems against the
false price, restores the pool, repays — all in one transaction, net
positive.
Impact: protocol insolvent by the extracted amount → Critical.

**HIGH — first-depositor share inflation**
Case: vault share price manipulable by donation; first depositor (or a
frontrunner) sets a share price that makes later depositors mint ~0
shares while their full deposit is captured.
Impact: direct theft from subsequent depositors → High; Critical when
the vault is a shared/default integration draining many users.

**HIGH — reward/claim accounting break with on-demand trigger**
Case: (contrast with the Medium drift above) accounting error the
attacker can trigger deterministically and repeatedly — double-claim,
exit-queue re-entry, snapshot reuse — converting directly to excess
payout.
Impact: repeatable direct loss → High.

---

## MOBILE

**HIGH — renewable session credential in plaintext client storage**
Case: app/SDK stores the session token AND its renewal secret
unencrypted on device (SharedPreferences / NSUserDefaults / plain
file); the renewal endpoint accepts the secret without any additional
factor, so extraction (backup, forensic, co-resident malware, another
app bug) converts to a persistent session that survives password
changes until the server revokes it.
Impact: durable account takeover from a local read primitive → High.
(If the stored value is short-lived and non-renewable, it caps lower —
the renewability is what carries the tier.)

**HIGH — exported component / deep link crossing a trust boundary**
Case: exported activity/provider or a URL-scheme handler performs a
privileged action (session transfer, payment confirm, data export) on
parameters supplied by any other app or web page, without caller
validation.
Impact: drive-by privileged action in the victim's session → High.

**MEDIUM-HIGH — JS bridge in a WebView without origin discipline**
Case: native bridge (token access, API calls, payments) exposed to
every frame/navigation in a WebView that loads remote or
user-influenced content; any page reaching the WebView reaches the
bridge.
Impact: depends on bridge powers — token exfiltration or privileged
API calls from arbitrary web content → High when tokens/actions are
reachable, Medium when the bridge is read-only low-sensitivity.

---

## How to use this tier

- Pattern-match for the CEILING, then prove the FLOOR: the entry tells
  you the maximum the pattern can justify; your finding earns the tier
  only at the demonstrated rung (bridge.md / smart-contract.md gates).
- If the demonstration stops one rung short (drain path shown but not
  executed, signatures forgeable in harness but not via the real flow),
  the finding stays at the lower tier with the gap stated — see the
  Medium volume for how those capped versions read.
