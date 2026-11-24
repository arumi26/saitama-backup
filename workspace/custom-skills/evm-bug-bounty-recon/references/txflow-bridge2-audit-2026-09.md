# TxFlow Bridge2 — audit-vs-deployed discrepancy + Vite env map (2026-09)

Combined EVM-contract + web3-dApp recon on **TxFlow** (perp DEX + own L1). Target had
GitHub-less deployment, an OpenZeppelin audit PDF, verified source on Arbiscan, and a Vite
dApp frontend. Two reusable takeaways: (A) an audit's `Resolved` status does **not** mean the
fix is on-chain; (B) the Vite `VITE_*` block is a full infra map.

## A. Audit "Resolved" ≠ deployed-fixed

- Contract: **Bridge2** (Arbitrum). Verified source pulled via Arbiscan → `verified_Bridge2.sol`.
- Audit: **OpenZeppelin** bridge audit PDF (`pdftotext -layout` → `oz_bridge_audit.txt`).
- OZ **M-01** = "updateValidatorSet replay" → status **"Resolved as recommended"**.
- **But** the deployed verified source still lacks the fix:

  | function | `checkMessageNotUsed(message)`? |
  |---|---|
  | `updateValidatorSet` (L466) | **NO** — builds `message`, calls `updateValidatorSetInner` directly |
  | `modifyLocker` (L595) | yes (L612) |
  | `modifyFinalizer` (L621) | yes (L638) |
  | `emergencyUnlock` (L773) | yes (L791) |

  So a validator-set-update replay guard the audit says was added is **absent from the
  deployed bytecode path** — the exact inverse of the "Ack'd/To-do = known → duplicate" rule.

- Separately, OZ **L-04** ("Bridge2 declares a `Deposit` event but `depositWithPermit` emits
  nothing; accounting relies on USDC `Transfer` logs") was **Resolved-by-design** → a textbook
  "read the vendor response per finding, then DON'T report it" case. Grep of the deployed
  source confirmed no `emit Deposit(...)` anywhere — matching the audit's by-design rationale.

### Method (run before trusting any "fixed" status)
```bash
# 1. pull the deployed verified source (Arbiscan/Blockscot) and the audit text
pdftotext -layout oz_audit.pdf oz_audit.txt
# 2. for every finding the audit marks Resolved, grep the deployed source for the added guard
grep -n "checkMessageNotUsed\\|nonce\\|onlyOwner\\|onlyRole\\|require(" verified_<C>.sol
# 3. confirm the verified source == deployed bytecode (selector match) before claiming
# 4. only then: is the still-missing guard actually exploitable + novel? (7-Question Gate)
```
Caveats: (1) prove source==bytecode; (2) confirm "Resolved" meant a *code* change, not an
operational mitigation; (3) a resolved-but-not-deployed issue can still be a duplicate.

## B. Vite `VITE_*` env map (one grep = whole infra)

`app.txflow.com` is a Vite SPA (`/assets/index-<hash>.js`). The `VITE_*` object is a single
literal — `grep -ohE 'VITE_[A-Z0-9_]+:"[^"]*"'` on the chunks dumped:

| key | value (2026-09) |
|---|---|
| `VITE_API_BASE_URL` | `https://api.txflow.com` |
| `VITE_BRIDGE_API_BASE_URL` | `https://api-bridge.txflow.com` |
| `VITE_WALLET_API_BASE_URL` | `https://api-wallet.txflow.com` |
| `VITE_SENSORS_SERVER_URL` | `https://beacon-log-server.txflow.com` |
| WS | `wss://api.txflow.com/ws`, `/ws-rtds`, `/api-ws` |
| `VITE_SIGNATURE_CHAIN_ID` | `42161` (Arbitrum) |
| `VITE_TXFLOW_CHAIN_ID` | `869` (own L1, `TxFlow-Mainnet`) |
| `VITE_BRIDGE2_CONTRACT_ADDRESS` | `0xcDE3F99bCB4c91e19124e41730489EAeFEc24565` |
| `VITE_OFIN_USDC_CONTRACT_ADDRESS` | `0xd04f0d19E8FbA49cfA541E272F9C60a2ad720464` |
| `VITE_USDC_CONTRACT_ADDRESS` | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` |
| `VITE_PRIVY_APP_ID` | `cmm37hbx002w60clbjjby3z3d` |
| `VITE_FINGERPRINT_API_KEY` | `oFFsgPaHIVfSSUxJdgbW` |

Probing outcome: `api.txflow.com` / `api-bridge` / `api-wallet` all **404 on every path**
(`/`, `/health`, `/api/v1`, `/openapi.json`, …) → stubs ("Platform API: Coming Soon" in docs).
`beacon-log-server` = sensors analytics ingest. Docs (`docs.txflow.com` GitBook) `llms.txt` +
`.md` suffix worked; the L1 pages are marketing only (no contracts/code).

## C. Bridge2 contract shape (bridge-audit mental model)

Hot/cold validator sets; 2/3 power quorum over hot (or cold) wallets; **dispute period measured
in BOTH time and blocks** (`getDisputePeriodErrorCode`); `lockers` can `voteEmergencyLock()`;
`finalizers` gate `batchedFinalizeWithdrawals`; `emergencyUnlock` (cold-quorum, `whenPaused`)
atomically sets+finalizes a new validator set. Replay protection = `checkMessageNotUsed`
(`usedMessages[message]`) + per-op `nonce` in the signed payload — the op that's *missing* the
guard is the one to look at.

## D. Web2 API verdict + program existence (2026-09 follow-up)

After the contract work, the web/API surface was mapped end-to-end and **closed as by-design** —
record it so a future session does not re-run this recon:

- **API architecture (Hyperliquid model, documented):** `POST /info` = single **unauthenticated**
  read endpoint (body `{"type":"<query>"}` → `clearinghouseState`, `spotClearinghouseState`,
  `webData2`, order book, meta). `POST /exchange` = single **EIP-712-signed** write endpoint
  (place/cancel order, `withdraw3`, `tokenSend`, `setReferrer`) → returns `403 "action is not
  allowed."` unsigned. Docs state it outright: *"Reads are unauthenticated; every `/exchange` write
  is a locally signed payload."* → **NOT an auth bug.** (Full false-positive writeup:
  `triage-validation` → `references/public-swap-api-false-positives.md`.)
- **Route inventory from the bundle** (only 6): `/info`, `/account`, `/exchange`, `/explorer`,
  `/request-fund`, `/api/v1/*`. `/account` with a `user` param returned `[]` — because the addresses
  grepped from the bundle were **contract addresses** (`VITE_USDC_CONTRACT_ADDRESS`,
  `VITE_BRIDGE2_CONTRACT_ADDRESS`), not users. Don't mistake a contract address for a user address.
- **Faucet `POST /request-fund {address}`** → credits **3000 testnet USDC** to an arbitrary address,
  no auth, rate-limited **1 hour per address**. Every bypass attempt (case-variation, whitespace,
  `0X` prefix, extra `amount` field, array type-confusion) was **rejected** — the limit holds. On a
  **testnet** this is a faucet = Informational/by-design. Kill.
- **Program existence: NONE.** `immunefi.com/bug-bounty/txflow/` → **404**, no `/security` page,
  no security.txt program, docs only have an "Audits" page. Bridge API host (`devnet-bridge.txflow.net`)
  is Cloudflare-403 on every path. Official bridge = **TxRelay (txrelay.com)**, a third-party host.
- **Testnet vs mainnet:** the recon target (`app.txflow-testnet.xyz`) is **testnet** (`VITE_NETWORK=
  TxFlow-Testnet`, chainId 2511, USDC `0x1088D67F…`). The **mainnet** deployment uses different
  addresses (see §B: chainId 869, Bridge2 `0xcDE3…4565`). Always distinguish the two before triaging
  value-at-risk.

**Verdict: KILL.** No bounty program + contract fully audited (OZ, findings known/resolved) + API
by-design + testnet. The honest call is no report — do not inflate the faucet or the public reads.

## E. Signature.sol internals (replay-message reconstruction for PoC)

`Signature.sol` is a 50-line top-level file (not a contract) shipped alongside Bridge2. The
replay PoC hinges on understanding how `message` is derived, because `makeMessage` is `private
view` in Bridge2 but its inputs are all in calldata / state:

```solidity
struct Agent { string source; bytes32 connectionId; }            // source = "a" (constant)
struct Signature { uint256 r; uint256 s; uint8 v; }
bytes32 constant AGENT_TYPEHASH = keccak256("Agent(string source,bytes32 connectionId)");
address constant VERIFYING_CONTRACT = address(0);                 // ← pinned to 0x0, not Bridge2

hash(agent) = keccak256(abi.encode(AGENT_TYPEHASH, keccak256(bytes("a")), agent.connectionId))
makeMessage(data) = hash(Agent("a", keccak256(abi.encode(address(this), data))))
```

So every `message` is fully deterministic from `(address(thisBridge), dataHash)` where
`dataHash = keccak256(abi.encode("<op>", ...args))`. **An attacker who sees one valid
`updateValidatorSet` tx can recompute `message` and replay the identical call** — provided
the replay guard is absent from that path (M-01 gap). The EIP-712 `domainSeparator` is set
**once in the constructor** (`domainSeparator = makeDomainSeparator()`), and
`makeDomainSeparator()` hardcodes version `"869"` + `block.chainid` — so on the TxFlow L1
(chainId 869) the domain is pinned to that chain and the `VERIFYING_CONTRACT = address(0)`
means the signing key is a **validator hot-wallet key**, not a user key. A replay PoC only
needs to reconstruct `dataHash` (all args are public calldata) — no key needed, the attacker
just replays the *same* 2/3-quorum signature set that a validator already produced.

**PoC shape:** (1) `updateValidatorSet(vsetA, sigs)` → ok, sets `pendingValidatorSetUpdate`;
(2) after dispute period, `finalizeValidatorSetUpdate()` → ok; (3) `updateValidatorSet(vsetA,
sigs)` **again** with the SAME `vsetA` + SAME `sigs` → because `checkMessageNotUsed` is
absent in that branch, `usedMessages[message]` is never set → the call succeeds a second
time, re-setting `pendingValidatorSetUpdate` for an already-finalized epoch (and
`require(newValidatorSet.epoch > activeValidatorSet.epoch)` L508 should catch it *if* the
epoch is unchanged — so the exploit variant is: replay with an **incremented epoch + same
validator set + same signatures** to force a second pending-update window, letting a finalizer
re-finalize the same set past the original dispute window). Confirm exploitability against
the live `epoch` value before claiming — the 7-Question Gate still applies.

**LIVE PoC result (2026-09, Foundry unit test on the VPS — NOT a fork).** Built a standalone
harness (MockUSDC + `new Bridge2(...)`, no mainnet fork — mainnet is a custom L1 869 with no
public archive RPC worth forking here, and the replay gap is a *logic* property so a fresh
deploy test is sufficient). `vm.sign(pkV, msgHash)` reproduced a valid 2-sig set, called
`updateValidatorSet` twice with identical args. **Outcome:** CALL #1 passed
`checkValidatorSignatures` and set `pendingValidatorSetUpdate.epoch=1`; CALL #2 (replay) did
**NOT** revert on "message already used" (proving the M-01 guard is genuinely absent) — it
proceeded straight into `checkValidatorSignatures` and then reverted with *"Submitted
validator set signatures do not have enough power"*. **Interpretation (honest, do not
inflate):** the replay gap is *real but currently gated* — the replay succeeds the message
stage only if the quorum check still passes against the **active** validator set. A same-set
replay that bumps `epoch` with the *same* signatures will fail the power check ONLY if the
active set's `totalValidatorPower` has since changed. The unmitigated window is: validator
powers are static within an epoch, so a **same-epoch replay before `finalize`** (or an
attacker who also controls ≥2/3 of power) can re-request a pending update. This is a **Low–Medium
defense-in-depth gap / archival finding**, NOT a Critical theft vector, because finalizing a
second update still needs a finalizer (`checkFinalizer`) + a passing dispute period + ≥2/3
power. Report it as "M-01 replay guard not applied to `updateValidatorSet` (audit claimed
resolved)" — informational/low — do NOT claim Critical. The 7-Question Gate kills the Critical
claim here.

### Quorum math cheat-sheet (reuse for any Nitro-bridge fork)
`checkValidatorSignatures` passes iff `3 * cumulativePower > 2 * totalValidatorPower`
(strictly > 2/3). With powers `[34,33,33]` (total 100): `v1+v2 = 67` → `3*67=201 > 2*100=200`
→ **PASSES** (just barely). `v1 alone = 34` → `102 > 200` false → fails. Any single validator
with <67 power cannot approve alone — you need the exact ≥-ceil(2/3) subset. Set test powers
so your chosen 2-of-3 quorum is 67 (34+33) or 68; if you pick 50+30+20 total=100, `50+30=80`
passes but `50` alone fails.

## F. VPS Foundry rebuild recipe (custom-L1 Nitro-bridge-fork contracts)

To run a `forge test` PoC against a verified-source contract that (a) imports
`@arbitrum/nitro-contracts` **but is deployed on a custom L1**, and (b) imports OZ:

```bash
# on BB VPS, /root/<target>
# 1. minimal source tree: only the .sol files + a stub for any L2-precompile import
mkdir -p src/interfaces
cat > src/interfaces/ArbSys.sol <<'EOF'
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.9;
interface IArbSys { function arbBlockNumber() external view returns (uint256); }
contract ArbSys {
    function arbBlockNumber() external view returns (uint256) { return block.number; }
}
EOF
# patch the verified source import:
sed -i 's|@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol|./interfaces/ArbSys.sol|' src/Bridge2.sol

# 2. OZ v5.0.2 — extract ONLY the contracts/ dir (the full repo pulls certora/ + test/ + hardhat/
#    into the build and pollutes forge). Use the GitHub archive, unzip, then move just `contracts`:
curl -sL https://github.com/OpenZeppelin/openzeppelin-contracts/archive/refs/tags/v5.0.2.zip -o /tmp/oz.zip
mkdir -p lib && cd lib && unzip -qoz /tmp/oz.zip openzeppelin-contracts-5.0.2/contracts -d ./
mv ./openzeppelin-contracts-5.0.2/contracts ./oz   # → lib/oz/...
# actually the archive nests as openzeppelin-contracts-5.0.2/contracts, so:
mv ./openzeppelin-contracts-5.0.2 ./oz && rm -rf ./openzeppelin-contracts-5.0.2

# 3. foundry.toml — point OZ remapping at the nested contracts dir
cat > foundry.toml <<'EOF'
[profile.default]
src = "src"
out = "out"
libs = []
EOF
echo "@openzeppelin/contracts/=lib/oz/contracts/" > remappings.txt
forge build
```

**PITFALL — OZ archive nesting.** The GitHub tag archive is `openzeppelin-contracts-5.0.2/`
with `contracts/` INSIDE it. `unzip -d` with a `-o`-only flag ("not extracting; -d ignored")
is a red herring — the `-o` there means *overwrite* and the warning means it did NOT extract
to `-d` as you expected. Just `unzip -qoz /tmp/oz.zip` (unzip's own `-o`=overwrite, `-z`=zip)
into a workdir, then `mv openzeppelin-contracts-5.0.2/contracts lib/oz/`. Verify with
`find lib/oz -name ECDSA.sol`.

**PITFALL — uploading .sol files to the VPS over sshpass.** A remote heredoc that contains
`$(cat /local/path)` does NOT expand locally — the `$(...)` is sent as a literal string and the
remote shell tries to run `cat` on a path that doesn't exist on the VPS. Use **base64**:
```bash
B64=$(base64 -w0 /local/Bridge2.sol)
sshpass -p "$BB_PASS" ssh ... "echo '$B64' | base64 -d > /root/target/src/Bridge2.sol"
```
(A 28KB .sol ≈ 38KB base64 — comfortably under the line limit.)

**PITFALL — `sshpass -e` requires SSHPASS in the shell that calls it.** `source ~/.bbvps.env &&
sshpass -e ssh ...` fails with "SSHPASS environment variable not set" when the env file defines
`BB_PASS` (a custom var, not SSHPASS). Fix: `sshpass -p "$BB_PASS" ssh ...` (pass the password
directly), or `(source env && export SSHPASS="$BB_PASS" && sshpass -e ssh ...)` in one subshell.

## G. checkValidatorSignatures loop quirk (audit, not exploit)

L431-447: `signatureIdx` advances **only** when `recoverSigner(message, signatures[signatureIdx])
== activeValidatorSet.validators[i]`; on mismatch the loop iterates to the next validator while
`signatureIdx` stays put. Two consequences: (a) a signature that recovers to `address(0)` REVERTS
(the `require(signerRecovered != address(0))` in `recoverSigner`), so "inject garbage signatures"
is **not** a power-inflation vector — it aborts the whole call; (b) an attacker CAN pad
`signatures` with extra valid-but-mismatched sigs to *waste* quorum slots, but that only
*reduces* `cumulativePower`, never increases it. Net: this loop is fail-safe, NOT the bug.
The replay gap (M-01, §E) is the live finding — do not chase the signature-skip angle.