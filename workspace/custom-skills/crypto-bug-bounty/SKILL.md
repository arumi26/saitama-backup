
# Crypto Bug Bounty Hunting

Full-spectrum workflow for finding and reporting smart contract vulnerabilities on DeFi protocols for bug bounty rewards.

## Workflow
### Phase 1: Target Discovery

1. Search Immunefi for active bounty programs
2. Filter by TVL ($1M-$50M sweet spot), age (<6 months = less audited), bounty range
3. Prioritize previously-hacked protocols (residual bugs likely)
4. **Check GitHub Issues first** — look for open security issues labeled `security`, `disclosure`, or `critical`. These may indicate known vulnerabilities you'd duplicate work on, or they may contain PoCs worth adapting.
5. Check if source code is public on GitHub

**Targets to AVOID:** Well-audited protocols (GMX, Aave, Uniswap, Curve) — too well-designed, 0 permissionless exploits typically. If the user does point you at a Curve-family / Vyper target anyway, load `references/vyper-curve-audit-recon.md` first — it carries Curve's self-hosted program details (`security@curve.finance`, $250K critical, front-end-only bugs OUT of scope), the `curve-lite`-vs-`curve-core` deployed-source-of-truth rule, the **deployment-YAML live-vs-WIP triage** (a `_v_NNN.vy` absent from `deployments/prod/` is WIP = zero bounty value — this killed the fresh twocrypto v300 "donation protection" lead), Vyper `range(x, bound=N)` semantics, Slither's Vyper ≤0.3.7 ceiling, and the normalize-and-diff "deployed == audited" proof.

**Targets to PURSUE:**
- Newer protocols (< 1 year old)
- Compound/Aave forks (known vulnerability patterns)
- Cross-chain bridges (complex attack surface)
- Yield aggregators (economic exploits)

### Phase 1.5: Compute Feasibility Check (BEFORE committing to a target)
Before deep-diving a cloned target, sanity-check whether the 2GB VPS can even compile it.
Read `foundry.toml`: `via_ir = true` + a large vendored dep tree (Balancer-v3, full OZ
upgradeable, big monorepos) means solc will likely OOM (`SIGKILL`) on 2GB. If a build OOMs
twice, stop retrying — it's a hardware ceiling, not a transient error. Either pick a lighter
target or offload the build to the user's 24GB home box over Tailscale. PoC-first is
mandatory, so unbuildable = unsubmittable. See `references/remote-build-offload.md` for the
Tailscale-SSH offload workflow and the Ubuntu-noble install gotchas.

**Foundry install on a fresh remote box (over SSH):** `curl -L https://foundry.paradigm.xyz | bash`
then `foundryup`; binaries land in `~/.foundry/bin` and are NOT auto-added to non-login SSH
PATH — always prefix commands `export PATH="$HOME/.foundry/bin:$PATH"`. Run the install in
`terminal(background=True, notify_on_complete=True)` (it takes a couple minutes). The remote
box may already have git but not forge — check `forge --version` first. Once the box is up, the
whole build+PoC loop runs remote — see `references/remote-build-offload.md` for the SSH banner
filter, the scp-breaks-use-stdin-pipe file-transfer trick, PATH for pip-user slither, and the
import-layout gotcha when dropping verified source into a fresh `forge init`.

### Phase 2: Contract Acquisition
**Hardhat/yarn install on a box with NO GitHub SSH key blocks on `git+ssh://` lockfile entries.** A Hardhat TS repo's `yarn.lock` frequently pins a test dep as `git+ssh://git@github.com/<org>/<repo>.git#<sha>` (e.g. Lombard pinned `dapphub/ds-test` that way). On a VPS/CI with no `~/.ssh` GitHub key, `yarn install` dies with `Host key verification failed / Could not read from remote repository`, exit 128. Fix in seconds — swap the scheme to HTTPS in the lockfile, no auth needed for public repos:
```bash
grep -nE 'resolved "git\+ssh' yarn.lock            # find offenders (usually 1)
sed -i 's#git+ssh://git@github.com/#git+https://github.com/#g' yarn.lock
yarn install --frozen-lockfile --non-interactive   # now resolves over public HTTPS
```
Then `solc-select use <pragma version>` (the repo is likely 0.8.x — `grep -rhoE "pragma solidity [^;]+" contracts/ | sort | uniq -c | sort -rn` to find the dominant version) before any static-analysis/slither/compile. Install in `terminal(background=True, notify_on_complete=True)` — a 70MB Hardhat repo + 600+ packages takes ~15-20s.

**Slither bulk-run recipe (avoids the shared-flag trap).** `slither contracts/strategy/ contracts/stakeAndBake/` (two dirs at once) errors with `slither: error: unrecognized arguments`. Run **per-file in a shell loop** with the same remap string, and filter the noise — OpenZeppelin `Math.mulDiv`, Solady, and `node_modules` findings drown out the real signal:
```bash
REMAPS="@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/ @openzeppelin/contracts-upgradeable/=node_modules/@openzeppelin/contracts-upgradeable/ @layerzerolabs/=node_modules/@layerzerolabs/ @uniswap/=node_modules/@uniswap/ solady/=node_modules/solady/ ds-test/=node_modules/ds-test/"
for f in contracts/strategy/*.sol; do
  timeout 90 slither "$f" --solc-remaps "$REMAPS" --exclude-dependencies 2>&1 \
    | grep -A2 "INFO:Detectors" | grep -viE "openzeppelin|solady|node_modules|Math.mulDiv|^--$" | head -25
done
```
<!-- Build errors can OOM a 2GB VPS; see Phase 1.5 + remote-build-offload.md. -->
When git clone fails (auth issues):
```python
# Use GitHub API to get tree
url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/main?recursive=1"
r = requests.get(url, timeout=10)
tree = r.json().get('tree', [])
sol_files = [f for f in tree if f['path'].endswith('.sol') and f.get('size', 0) > 5000]

# Download via raw.githubusercontent.com
url = f"https://raw.githubusercontent.com/{owner}/{repo}/main/{path}"
```

Focus on:
- Largest .sol files (most logic)
- Files with keywords: vault, router, oracle, liquidat, redeem, withdraw, borrow

#### When there is NO source repo — pull VERIFIED on-chain source (Immunefi scope = etherscan links)
Many Immunefi programs list scope as **explorer address links**, not a GitHub repo, and the org may not exist on GitHub at all (ExtraFi: `github.com/ExtraFi` + every handle variant 404'd). Get the verified source straight from the explorer:
- **Etherscan/Optimistic-Etherscan v2 API needs an API key** — `api.etherscan.io/v2/api?chainid=10&module=contract&action=getsourcecode&address=<addr>` returns `{"status":"0","result":"Missing/Invalid API Key"}` without one. Don't waste time retrying keyless.
- **Blockscout is the keyless fallback and returns FULL multi-file verified source:**
  ```python
  # Optimism example; swap host per chain (base.blockscout.com, eth.blockscout.com, etc.)
  r = curl(f"https://optimism.blockscout.com/api/v2/smart-contracts/{addr}")
  d = json.loads(r)
  files = {}
  if d.get("source_code"): files[d.get("name")+".sol"] = d["source_code"]  # main contract
  for f in d.get("additional_sources", []):                                # all imported files
      files[f["file_path"]] = f["source_code"]
  ```
  `additional_sources` carries the entire dependency tree (e.g. ExtraFi `Pool` = 46 files / 330KB, `LendingPool` LYF = 33 files, all pulled keyless in one pass). It also gives the real verified contract name, which often differs from the Immunefi label (a "Pool_Impl" row was actually `RewardDistributor`).
- Grab the in-scope address list from the Immunefi Scope tab: `browser_console` with `[...document.querySelectorAll('a')].map(a=>a.href).filter(h=>/etherscan|basescan|0x[a-fA-F0-9]{40}/.test(h))` dumps every asset link at once (the scope table is JS-rendered, so plain curl of the page HTML misses it).

### Phase 2.5: Read Prior Audits BEFORE Attacking (mature/competition targets)
When a target ships with `audit/` PDFs (Cantina/Sherlock competitions almost always do), extract and read them FIRST:
```bash
pdftotext -layout audit/Firm-Target.pdf out.txt   # then read findings + severities
```
- Every finding already reported = OUT OF SCOPE / duplicate. Map them so you don't re-derive known bugs.
- The bugs auditors LISTED tell you where the shallow surface was; what remains is the deep surface (accounting rounding, cross-tranche value transfer, state-machine edge cases).
- **A team's OWN invariant/fuzz suite in `test/invariant/` is a maturity red-flag AND a treasure map.** It tells you exactly which invariants are load-bearing (e.g. Royco Day hard-`require`s `collateralNAV == stEff + jtEff` to the wei in two places). If they fuzz it, grep-and-flag will not beat them — you need a genuinely novel edge case their handler doesn't reach. See `references/mature-protocol-audit.md`.

#### Prove exhaustion via the audit's commit hash BEFORE auditing (do this FIRST)
Audit reports (PDF/md) almost always state the exact **commit hash** they reviewed and the **scope file list**. Use both to compute the *unaudited delta* — this is the only part worth your time, and it takes 2 minutes:
```bash
pdftotext -layout audits/Firm-Target-review.pdf out.txt   # find "COMMIT <hash>" + "SCOPE" list
git fetch origin <audit-commit-hash>                        # pull the exact reviewed tree
git diff --stat <audit-commit-hash> HEAD -- src/            # source changes SINCE the audit
git log --oneline <audit-commit-hash>..HEAD                 # commits since the audit
```
- **Empty `src/` diff = the whole target is audited = EXHAUSTED.** Do not audit it. In one session the "fresh v2" premise collapsed here: Flex's latest commit `chore: add zc review` only *added the PDF* — zero source change since the audited commit — and the audit (Zero Cool, 12 findings incl. 1 High/7 Med, all unresolved) already covered every `src/` file including the "new v2" `Lender.sol`. A 12-unresolved audit means the team already knows all the shallow + medium bugs; anything you'd find is a duplicate.
- **Non-empty `src/` diff ≠ unaudited — check DIRECTION before reading code.** If the bundled PDF carries remediation markers (`grep -cE "Fixed in PR|Acknowledged|Fix verified"`), it is the FINAL post-remediation report, and the scope commit is the PRE-fix snapshot — so the diff is the auditor's own fix set, not new code. Prove direction by grepping a known one-token fix in BOTH trees (`git show <scope>:file | grep <token>` vs `git show HEAD:file | grep <token>`); whichever still holds the buggy form is pre-fix. Remediation-only delta = fully audited = EXHAUSTED. (3F Grunt: 1416-line diff, all remediation across PR 208–220; 27 Fixed + 12 Acknowledged, 33 "Fix verified"; 2466 tests green → NO-GO, no report.)
- **"v2" / a recent `Merge pull request` / a new subdirectory is NOT automatically unaudited.** Cross-check its files against the audit's SCOPE list. New code that's still inside the reviewed commit + scope is already covered.
- **Map every audit finding to your own candidates.** If your prior finding (e.g. "permissionless re-kick", "oracle no staleness") appears in the report, it's a public duplicate — drop it. What remains worth pursuing is only code changed AFTER the audit commit, or files explicitly OUT of the audit scope.

See `references/audit-commit-exhaustion-check.md` for the full 2-minute git-diff-against-audit-commit workflow, the pre-fix-vs-post-fix **direction check** (remediation-only delta), the Flex + 3F Grunt EXHAUSTED case studies, and the fresh-target triage disqualifier table (fork / non-EVM / honeypot / already-audited).

### Phase 3: Audit Priority Order
1. **Oracle integration** — `latestAnswer()`, `latestRoundData()`, TWAP, price feeds
2. **Access control** — `onlyOwner`, `onlyController`, permissionless functions
3. **Liquidation logic** — health factor checks, seize calculations
4. **Withdrawal/redemption** — share calculations, rounding direction
5. **Reentrancy** — CEI pattern, ReentrancyGuard usage
6. **Flash loan vectors** — single-block manipulation

### Phase 4: Common Vulnerability Patterns

See `references/common-vuln-patterns.md` for detailed patterns.

#### Incomplete Fix Commits Hide Remaining Gaps (any chain)
When a commit message says "prevent X from violating Y" and adds a guard for one variant of a state enum, grep for ALL variants — the fix may only cover a subset. Pattern: `git log --oneline | grep -i "fix\|prevent\|guard"` → read the diff → check which enum variants are covered. In Marinade `3e7c090` ("Fix delinquent + depositfee"): added `!is_iterating_validators()` guard for Phase 2 but did NOT add `!is_iterating_stakes()` guard for Phase 1 — Phase 1 remains exploitable via any natural reward event.

**Ordering-bypass variant (guard evaluated at action time, keyed on EXISTING state).** A fix that adds a guard which only fires when prior state exists can be outrun by *reversing the action order*. Canonical case (XPR Network `agentvalid` SLASH-2026-02): the 2026-01 fix made `unstake()` refuse while a `valactivity` row exists (post-validation time-lock), but `validate()` never checks for a pending unstake — so `unstake(90% of stake) → validate()` evades the lock, leaving only `min_stake` slashable (penalty drops ~90%). The fix's OWN comment documented the ordering it covered (`validate()+unstake()`); the mirror image was untested. **Recipe:** read the fix comment to see which ordering it defends, then (a) grep the *reverse* path for the guard, and (b) grep every sibling that releases/exits value (`withdraw`, `resolve`, `cancel`) and confirm it enforces the *same* invariant — the fix usually patches one function and forgets its siblings. Same root cause as the already-paid finding, opposite ordering = a valid new HIGH, not a duplicate. Worked example + vert PoC: `antelope-eosio-contract-audit` → `references/proton-vert-harness.md`.

**Per-chain toolchains differ — don't reach for Foundry on a non-EVM target.** Solidity/EVM → `evm-smart-contract-audit`; Solana/Anchor → `solana-smart-contract-audit`; Cosmos-SDK Go → `cosmos-sdk-defi-audit`; **Antelope/EOSIO AssemblyScript (`*.contract.ts`) → `antelope-eosio-contract-audit`** (uses `@proton/vert`, not `forge`); off-chain indexers/backends → `onchain-indexer-audit`. When a repo has `assembly/*.contract.ts` files, you are NOT on an EVM chain — load the Antelope skill before planning the PoC.

#### Two-Phase Upgrade State-Machine DoS (Solana/Cosmos)
A program iterates all accounts in phase 1 accumulating a running total, then asserts it matches a global counter at the boundary. If ANY other instruction mutates that global counter during iteration (rewards, slashes, fee accrual), the accumulator drifts → invariant violation → upgrade frozen. Check: (a) which instructions run during the iteration window? (b) do reward/slash handlers update the accumulator too? If no, it's a logic error with freeze as *consequence*, not the attack vector. In Marinade: `delinquent_upgrader` `IteratingStakes` phase + concurrent `update_active` reward/slash updates.

#### Standalone Rust PoC — No BPF Build Needed (2GB VPS friendly)
When the Anchor dep tree OOMs `forge build` or the BPF toolchain is missing, prove math/state-machine bugs with a standalone Rust simulation — no BPF build, no fork, no RPC needed:
1. Extract the EXACT accounting logic from the vulnerable instruction (copy `checked_add`/`checked_sub` chains verbatim)
2. Reimplement the state structs (DelinquentUpgraderState, ValidatorSystem, StakeSystem) as plain Rust
3. Simulate the attack: crank iteration + reward event + invariant check
4. Compile with `rustc poc_invariant_sim.rs -o /tmp/poc_sim && /tmp/poc_sim`

This proves the math WITHOUT needing the full Anchor build. It does NOT prove on-chain reachability (for that you still need a fork), but for logic-error bounty submissions, the math proof + code trace is sufficient to get triaged. The PoC must reproduce the EXACT same arithmetic as the on-chain program — use the same `checked_*` methods, same overflow behavior.

#### Scope Framing: DoS vs Logic Error for Bounty Submission
Many bounty programs (Marinade, etc.) explicitly **exclude "Any denial of service attacks"** from scope. If your finding has freeze/DoS as the *impact*, reframe before submitting:
- ❌ "DoS attack freezes protocol" → **OUT OF SCOPE**
- ✅ "State machine invariant violation in [X] causes upgrade freeze as unintended consequence" → **LOGIC ERROR, IN SCOPE**
- The impact (freeze) is real and severe, but classify the *root cause*, not the consequence
- Support this with: "Logic errors" = explicitly prioritized in bounty criteria
- If the bounty scope says "Temporary freezing ≥ 6 days" and your freeze is permanent, that's a HIGHER severity tier, not a scope mismatch

#### Commented-Out Safety Guards Are Signals, Not Noise
When a check like `if last_update_epoch == clock.epoch { return Ok(()) }` is commented out with a note like "maybe parallel update artifact", the reason it was disabled is exactly the vulnerability surface — repeated calls per epoch, each recalculating price/minting fees.

#### New Pattern Class: Credit & Position Accounting Bugs
Lending pools often maintain internal credit/debt balances that must be synchronized with actual token flows. Mismatches here are CRITICAL:

**Typical bug pattern:**
```solidity
// WRONG: Credit updated BEFORE validating actual debt position
uint256 credit = credits[reserveId][user];
credits[reserveId][user] = credit.add(amount);  // Inflates credit unconditionally

if (amount > borrowed) amount = borrowed;  // Too late — credit already inflated
```

**Why it's exploitable:** If `amount` exceeds the user's actual borrowed debt, credit gets inflated by more than the legitimate position change. An attacker can then use inflated credit to borrow far beyond their stake.

**Where to look:** 
- `repay()` functions that call `credit.add(amount)` without prior debt validation
- `borrow()` or `withdraw()` that deduct credit before verifying available liquidity
- Liquidation calculations that use stale or incorrectly-synchronized balance data

**Verification technique:** Trace the exact order of operations. In any position-modifying function, confirm: (a) input validation happens BEFORE state changes, (b) credit/debt updates use validated amounts, (c) all synchronized state variables (totalBorrows, totalSupply, credits, debtPositions) are updated atomically with consistent values.

**ExtraFi case study (V-01):** LendingPool.repay() inflated credits by the full `amount` parameter even when that exceeded the borrower's actual debt. Only whitelisted vault contracts could call repay(), making this trust-based but still dangerous if a vault contract is compromised or manipulated. Check the repo's open GitHub issues — issue #5 contained a security disclosure for this exact bug.

**Reachability wall (whitelisted-caller bugs):** when the vulnerable fn is gated to an unknown whitelisted caller (`require(borrowingWhiteList[msg.sender])`), the bug is only real if that caller can actually reach the bad path. Find the live caller from **decoded Blockscout event logs** (`/api/v2/addresses/{addr}/logs` → read the caller param out of the `Repay`/`Borrow` event), then pull ITS source. If the caller contract is **unverified everywhere** (Blockscout empty, Etherscan Cloudflare-blocked, Sourcify empty), you cannot prove reachability → the finding stays a candidate, not a submittable Critical. PoC-first/claim-second still governs. Full case + log-decoding snippet in `references/extrafi-lyf-findings.md`.

#### Bug Class: ERC4626-style first-depositor / donation share inflation (lending eToken)
Lending pools that mint shares as `amount * totalShares / totalLiquidity` where
`totalLiquidity == IERC20(underlying).balanceOf(shareToken)` (raw, donatable) — with **no
virtual shares/assets** and **no `require(sharesMinted != 0)`** — are vulnerable. Attacker
1-wei-seeds a fresh reserve, donates underlying directly to the share-token contract to inflate
the rate, victim's deposit floors to 0 shares, attacker (100% supply) redeems the whole pool.
**Severity discipline:** this is HIGH by default, Critical ONLY if you prove on-chain the team
lists reserves **unseeded** (the exploit window). `initReserve` being `onlyOwner` + not seeding
means every new asset listing is a potential window — but a team that always seeds closes it.
Report the precondition honestly; do not auto-inflate to Critical. Confirmed + PoC-green on
ExtraFi (not in PeckShield/BlockSec audits) — **BUT the on-chain sweep later killed it: ~40 of
82 reserves carry a fixed `totalSupply==10000` dead-share seed = deliberate mitigation, so the
finding is Informative/known, not payable.** A green local PoC proves the MATH, never the
REACHABILITY. **Go/no-go = a keyless RPC state sweep of every reserve's share supply, not the
PoC:** if all supplies are a fixed small constant (10000), the team seeded → kill it. Only an
actually-empty (`totalSupply==0`) AND live (isActive/borrowingEnabled, real TVL, recent activity)
reserve keeps it alive. See `references/extrafi-lyf-findings.md` for the RPC sweep snippet, the
seed math (10000-seed forces a 10,000× donation → absurd), and the cloakbrowser CF-bypass recipe.

#### Delegate-Authority Reward Inflation → Vault Drain (kFarms class)
When a program exposes a `delegate_authority`-gated instruction that **increases a user's reward tally** without validating against available vault balance, and a separate `harvest` instruction **pays out based solely on that inflated tally**, the combination is a critical vault-drain vector:

```rust
// Vulnerable pattern (kFarms reward_user_once):
pub fn reward_user_once(ctx: Context<RewardUserOnce>, reward_index: u8, amount: u64) -> Result<()> {
    let farm = &mut ctx.accounts.farm_state;
    let user = &mut ctx.accounts.user_state;
    // NO validation: amount vs farm.reward_infos[index].rewards_available
    user.rewards_issued_unclaimed[reward_index] = user.rewards_issued_unclaimed[reward_index]
        .checked_add(amount).unwrap();
    farm.rewards_issued_unclaimed += amount;
    Ok(())
}

// Harvest reads inflated tally and pays out:
pub fn harvest(ctx: Context<Harvest>, reward_index: u8) -> Result<()> {
    let user = &ctx.accounts.user_state;
    let payout = user.rewards_issued_unclaimed[reward_index]; // inflated value
    token::transfer(..., payout)?;  // NO check against vault balance
    Ok(())
}
```

**Detection checklist:**
- [ ] Delegate-authority instruction modifies user reward/share tally
- [ ] NO `require!(amount <= reward_info.rewards_available)` or equivalent cap
- [ ] Harvest/payout reads tally directly — no second validation pass
- [ ] No slashing, cap, or max-available cross-check between the two functions
- [ ] Feature-flag gating ≠ reduced severity (if admin can enable the flag)

**Fix:** Add upper-bound in the delegate instruction:
```rust
require!(amount <= reward_info.rewards_available, FarmError::AmountExceedsAvailable);
```

#### Solana PoC Without Solana CLI (2GB VPS — Works Every Time)
When `solana-test-validator`, Anchor CLI, or the BPF toolchain won't install on a resource-constrained VPS, **prove the bug with a standalone Rust simulation** — no BPF build, no fork, no RPC needed:
1. `grep` the exact vulnerable function body from the source repo
2. Reimplement ONLY the accounting logic as plain Rust structs + functions (no Anchor, no BPF)
3. Replicate the `checked_add`/`checked_sub` chains verbatim — same overflow behavior
4. Simulate the attack: inflate → harvest → verify state corruption
5. Compile: `rustc poc.rs --edition 2021 -o poc && ./poc`
This proves the **math** without needing the full Solana runtime. It does NOT prove on-chain reachability (for that you still need a fork test on Kali), but for logic-error bounty submissions, the math proof + source-line reference is sufficient to get triaged.

**Anchor instruction encoding for proof-of-concept (Python, no runtime needed):**
- Compute discriminator: `sha256("global:<instruction_name>")[:8]`
- Encode args in little-endian: `struct.pack("<I", u32_arg) + struct.pack("<Q", u64_arg)`
- Build account list matching the Anchor `Accounts` struct exactly (signer/writable flags)
- This demonstrates transaction format understanding without broadcasting anything

**When to use which approach:**
- `fork_poc.rs` (pure Rust): For math/logic bugs — always works, zero dependencies
- `kfarms_exploit.py` (Python): For demonstrating instruction encoding + account layout
- Anchor test (`tests/fork_anchor.ts`): For full integration testing on Kali (needs Solana CLI)
- `install_kali.sh`: Bootstrap script for full Solana + Anchor toolchain

**Bounty classification:** Maps to "Direct theft of any user funds" = CRITICAL on most programs. Minimum reward typically $100K+.

### Phase 5: Report Writing
See `references/report-template.md` for submission format.

**PDF generation gotcha (fpdf2):** the default Helvetica core font is latin-1 only — any Unicode em-dash `—`, en-dash `–`, smart quotes, arrows `→`, `≈`, `×`, `≠` in report text raises `FPDFUnicodeEncodingException` mid-render and leaves no file. Sanitize the report string to ASCII first (`—`/`–`→`-`, `→`→`->`, curly quotes→straight, `×`→`x`, `≈`→`~`) OR register a TTF Unicode font. Also, in a `multi_cell` "key: value" helper, reset `set_x(l_margin)` and pass an explicit width — a stale x from a preceding `cell()` can leave "Not enough horizontal space to render a single character".

### Phase 6: Submission Strategy
1. DM first (brief description, mention PoC exists)
   - **When no program is found and the user wants the reward question answered first, the
     first DM asks ONLY whether a reward exists.** Never name a bounty platform
     (Immunefi/Cantina) and never name the vulnerable function/library/mechanism. Naming the
     *version* is safe (a release spans the whole public suite); naming the *function*
     collapses the search to one file. Template + safe-vs-leaks table:
     `report-writing` → `references/direct-disclosure-no-program.md` (Step 4).
2. Wait 24-48 hours for response
3. If confirmed bounty program → send full report (without PoC code)
4. If they confirm interest → send PoC code
5. If no response → public tweet (responsible disclosure)

**Tiered disclosure (CRITICAL):**
- Step 1: Brief description + "I have Foundry PoC, 3/3 tests passing"
- Step 2: Full report with vulnerability description + attack flow (NO PoC code)
- Step 3: PoC code only AFTER bounty confirmed
- Why: Protects researcher if dev fixes without paying

**Report format (Indonesian user preference):**
- English for technical content (standard for bounty submissions)
- Add Indonesian explanations for complex concepts
- Include "Remediation" section with concrete code fix
- Include "Positive Findings" section (what protocol does right)

**When user says "Kasih format report"** — add detailed explanations, not just code snippets. User wants professional reports with full context.

## Pitfalls
- **Don't audit well-audited protocols** — GMX, Aave, Uniswap, tBTC-v2, GMX Synthetics, Hop Protocol, Union Labs ZK have 0 permissionless bugs typically
- **ZK proof protocols are dead ends for general auditors** — Union Labs has standard Groth16 verification. Pivot to simpler targets unless you have specialized crypto knowledge.
- **Very popular protocols (50K+ stars) = heavily audited** — low bug probability. Focus on smaller, newer protocols.
- **Data-only repos are NOT targets** — repos with just CSVs and local scripts (e.g., `dymensionxyz/staker-snapshots`) have no attack surface. Do not waste time.
- **Don't submit without PoC** — reports without PoC get rejected or low bounty
- **Don't reveal full attack flow in first DM** — keep details for negotiation
- **Don't execute on mainnet** — use Foundry fork simulation only. A compiled standalone PoC binary + source is sufficient proof for bounty submission. Mainnet exploitation is illegal and disqualifies you from every bounty program.
- **Protocol-favorable rounding is NOT a bug** — check direction before reporting
- **`latestAnswer()` without staleness = known pattern** — check if already reported in past audits
- **Follow up stuck submissions aggressively** — moderator read but no response → escalate to owner/team directly after 3-5 days
- **Aggressive mode = parallel multi-target** — scan 5-10 repos simultaneously, then deep-dive the most promising. Do not spend hours on one dead-end target.
- **"Expand biar dpt banyak"** — scan more contracts in same protocol, look for multiple vulnerability classes simultaneously (oracle, rounding, access control, reentrancy, flash loan).
- **One apparent critical bug is usually a false positive** — before drafting a report, verify with code trace or fork-based simulation. Retire false positives publicly; do not let them pollute submission history.
- **A versioned contract file existing in the repo ≠ it is deployed.** Before deep-reading a `*_v_NNN.vy` / `*_vN.sol`, confirm it is actually live: Vyper/Curve-style repos enumerate deployed addresses in `deployments/prod/**` YAMLs (`grep -rhoE "contract_path: .*" deployments/prod/ | sort | uniq -c`); Solidity repos have `broadcast/` or a deployment manifest. Code absent from those = WIP/devnet-only = zero bounty value. (Curve twocrypto `implementation_v_300.vy`, the most interesting fresh code in the tree, was not in any prod YAML → correctly dropped.)
- **Verify suspicious-looking syntax against raw bytes before claiming a bug.** Tool/terminal rendering can mangle source: `empty(Epoch)` displayed as a garbled `Epompty(Epoch)` and looked like a typo/compile error. Confirm with `grep -n "<line>" file | od -c` — if the bytes are valid, retract immediately.

## Initial Disclosure Format (Tiered)
When reporting to a personal/private contact, use a **brief initial report first**, then reveal details only when requested.

**Initial report template:**
```
Halo, nama saya [Nanwasa] dan saya menemukan kerentanan pada domain/subdomain [URL/repo]

Vulnerability :
[Short name]

Affected URL :
[File path + function + lines]

Severity :
[HIGH/MEDIUM-HIGH/etc]

Impact :
[1-2 sentence user impact]

Thank You

Regards,
[Nama]
```

**Rules:**
- Send one bug per initial message unless the receiver explicitly asks for all findings
- Do NOT include PoC code, remediation, or detailed attack flow in initial report
- Wait for dev/blues to say "please send details" or "we need more info" before sending full report
- If no response in 3-5 days → follow up once, then pivot target

## Two-Bug Reporting Style
When multiple bugs are found:
- Send **separate initial reports** for each bug, not combined
- Number them clearly: Bug #1, Bug #2
- Wait for acknowledgment before sending second bug report
- This prevents devs from fixing one without paying and ignoring the other

## PoC Validation Discipline
- **Verify PoC logic before claiming PASS.** A test that fails due to harness bug is NOT a passing PoC.
- Common harness bugs: wrong balance assertions, underflow in mock accounting, incorrect event signatures
- Run `forge test --match-test <test_name> -vvvv` and read the trace before marking PoC as valid
- If PoC fails due to test harness, fix harness first. Do not claim bug is confirmed until test passes for the right reason.

## Viable Target Check (Before Deep Audit)
- **One-fetch bounty + audit-history discovery via the project's docs security page.** Before valuing a DeFiLlama/GitHub candidate, fetch its gitbook `resources/security.md` (or the docs `.../Security` page) — it usually lists BOTH the bounty program link AND every audit in one file. Twyne's `raw.githubusercontent.com/0xTwyne/gitbook-docs/main/resources/security.md` gave the Immunefi URL plus 8+ audits (yAudit ×5, SecEureka ×3, Enigma fuzzing ×3) in a single curl — instantly answering "is there a program?" and "how heavily audited is this?" before cloning. Check `<org>/gitbook-docs` repo or `docs.<project>.*/security` first. **Next.js/Fumadocs docs sites expose a markdown alternate** — the rendered HTML `<head>` carries `<link rel="alternate" type="text/markdown" href=".../page.md">`; just `curl -sL <canonical-url>.md` to pull the full clean page (scope table, severity tiers, out-of-scope list) with zero JS rendering and no browser/Firecrawl dependency. Velocity's bounty page came through this way as a complete markdown table (`docs.velocity.exchange/protocol/risk-and-safety/bug-bounty.md`). This is the fastest way to read a program's out-of-scope list BEFORE auditing — and the out-of-scope list is what kills most delta-hunt findings (privileged-key paths, off-chain bot errors, audit duplicates).
- **Audit density calibration (heavily-audited-but-still-worth-it).** Many audits ≠ automatic skip. Weigh audit count AGAINST custom-code footprint and integration complexity. Twyne: 8+ audits but only ~667 lines of custom code (`src/twyne` + `src/TwyneFactory`) wrapping Euler EVC/EVK + Aave — the shallow surface is gone, but cross-protocol integration seams (Twyne↔Euler↔Aave collateral accounting, dynamic LLTV, liquidation incentive) are exactly where multi-audit protocols still leak edge cases. Small focused custom surface + a working archive fork RPC for that chain = worth a focused pass even against a wall of audits. Read the audit reports first (Phase 2.5) to map the known surface, then hit the integration seams. **Session-specific angle map + disclosure contact for Twyne in `references/twyne-collateral-vault-audit.md`.**
- **Always verify bounty program exists** before spending hours on PoC
- **Check the program's ASSET CATEGORIES before valuing any web/infra finding.** An Immunefi program can be **Smart Contract ONLY** — if there is no "Websites and Applications" (or "Blockchain/DLT") asset category, then leaked API keys, CORS misconfig, open S3 buckets, and every other web/frontend bug are **OUT OF SCOPE and will be rejected**, no matter how real they are. ExtraFi's Immunefi is SC-only: a prior session's 3 web findings (live leaked Coinbase RPC key, CORS wildcard, public S3) were all real and verified but unpayable there. Read the Scope tab's category selector + the reward table's asset-type headers FIRST. If the finding class doesn't match a listed asset category, it's only useful as a direct-to-team disclosure (email/security.txt), not a platform submission.
- Check: Immunefi/Cantina/Sherlock listing, GitHub activity (last commit < 6 months), Discord/Telegram active?
- Dead-end signals: all commits > 1 year old, "protocol shutdown" tweets, no active community, no bounty page
- If target is dead → pivot immediately. Do not spend more than 30 minutes on a dead target.
- Save PoC + report anyway for personal reference, but do not expect reward

## Email / GHSA Disclosure-Path Target Classification (do FIRST when user says "report ke email")

When the user says **"cari yang report bugnya ke email"**, **"web yang submitnya lewat email"**, **"nggak lewat platform"**, or colloquially **"bukan yang submit bayar dulu"**, treat this as a strict target-shape constraint—not a request for any security contact:

1. **WEB target required** — prioritize website/API/wallet frontend/backend assets with explicit web impacts (IDOR, XSS, injection, payment/order tampering, sensitive-data exposure). Do not answer with an L1 node, consensus codebase, or smart-contract-only program merely because it has a large bounty.
2. **Direct inbox submission required** — the user must be able to submit from their own email to a published security address. GHSA is acceptable only if they have not explicitly insisted on email.
3. **A security email alone is insufficient** — verify that the policy actually awards bounties for reports sent by email. If `security.txt` also points to HackerOne/Bugcrowd/Immunefi/Cantina, read the policy; if outside-platform reports are ineligible, disqualify it.
4. **No platform friction** — exclude programs whose bounty submission or payout requires platform routing, KYC, entry fees, deposits, or paid access. Interpret "bayar dulu" as rejection of platform/account friction, not merely a literal payment question.
5. **Reward and web scope must be evidenced** — quote the published reward table/maximum and explicit web assets or accepted web vulnerability classes. Responsible disclosure with no evidenced reward is a contact, not a bounty target.

The deliverable is a target whose disclosure path is a **private email** the user can drive from their OWN inbox, whose **web assets are explicitly in scope**, and whose policy confirms a **real reward**—NOT merely a platform listing. Classify each candidate BEFORE deep-auditing:

- **security.txt is the fast probe:** `curl -sL --max-time 8 https://<domain>/.well-known/security.txt | grep -iE "mailto|contact:"`.
  - `Contact: mailto:security@<domain>` → **email path ✓** (best; e.g. Twyne = `security@twyne.xyz`, confirmed via security.txt).
  - `Contact: https://github.com/<org>/<repo>/security` → **GHSA path ✓** (private advisory the user files themself — e.g. Panoptic's security.txt points at `github.com/panoptic-labs/docs/security`, and Panoptic has NO Immunefi at all). GHSA is an email-equivalent self-drive path; a repo's GitHub Security tab "Report a vulnerability" = private advisory.
- **Platform ≠ email path — DISQUALIFY for this request:**
  - Has an **Immunefi** listing (`curl -sL -o /dev/null -w "%{http_code}" -A Mozilla/5.0 https://immunefi.com/bug-bounty/<slug>/` → `200`) → report goes through the platform, not email. Skip when user wants email (GammaSwap, Ostium both returned 200 = Immunefi).
  - **Cantina `private_contest` + `kycRequired:true`** (seen in the live-competitions JSON, e.g. Royco Day) → account+KYC required, not email. Skip.
- **Contact when there's no security.txt:** `git log -1 --format="%an <%ae>"` on the cloned repo gives a real reachable author email (per Contact Discovery). Hand the user a ready-to-paste email draft + PDF to send from their own inbox.
- **The intersection "fresh + small + light-to-build + email/GHSA + live-paying" is THIN.** Most fresh small DeFiLlama DEXes either (a) have no public contracts (Tangent, Fira, NUVA — GitHub org 404), or (b) route through Immunefi/Cantina. In one full scan, Panoptic HypoVault (GHSA) and Twyne (`security@twyne.xyz`) were the only clean email/GHSA fits. Don't over-promise volume; give the honest shortlist as a table.

## Standalone-Mock PoC When The Heavy Dep Tree OOMs (2GB VPS, target-contract-is-light)
When the vulnerable contract itself is small (e.g. HypoVault vault core = ~774 lines) but its import tree (`panoptic-v2-core`, boring-vault, full OZ-upgradeable) OOMs `forge build` on the 2GB VPS, DON'T give up on a PoC — **rebuild the target standalone against hand-written faithful mocks** instead of the vendored deps:
1. `forge init /tmp/<x>-poc`, copy the target `.sol` in, rewrite its import block to a single local `deps.sol`.
2. In `deps.sol` reproduce ONLY what the target touches, faithful to the originals: the base ERC20 (copy the real `ERC20Minimal`/solmate variant verbatim — virtual-supply semantics matter for inflation tests), OZ `Address.functionCallWithValue`, a real `Math.mulDiv` (512-bit), `SafeTransferLib`, minimal `Ownable/Initializable`, `ERC721Holder/ERC1155Holder`.
3. Mock only external collaborators you control (`MockAccountant` returning attacker-set NAV, `MockToken` with settable decimals).
4. **Neuter `_disableInitializers()` to a no-op in the mock** so the harness can `initialize()` the impl directly (prod runs behind a proxy w/ fresh storage — the init guard is not the audit target). Without this you get `[FAIL: already init]` in `setUp()`.
5. Pitfalls that bit this session: `address(0xM1)` etc. are INVALID hex — use `makeAddr("x")`; and `makeAddr` can't run in a state-var initializer, assign inside `setUp()`. Copy `forge-std` into `lib/` + `echo 'forge-std/=lib/forge-std/src/' > remappings.txt`.
6. This proves/​kills MATH bugs (share inflation, proration rounding, basis conservation, epoch replay, reserved-vs-balance desync) deterministically with zero RPC/fork. It does NOT prove reachability through the real dep code — for that you still need the full build (offload to Kali). HypoVault ran 11 angles green this way; only a 1-wei A9 dust drift surfaced (bounded, no supply-invariant break → informational).

## Email Submission Workflow

User explicitly asks: **"Cari biar gua submit lewat email"** — prepare targets that accept email-only submission (no platform account needed).

### Target Discovery for Email Submission

1. **Check `/.well-known/security.txt`** — standardized contact disclosure:
   ```bash
   curl -sL --max-time 10 "https://target.com/.well-known/security.txt"
   # Returns: Contact: mailto:security@target.com, Policy: https://docs...
   ```

2. **Check docs subdomain** for security page:
   ```bash
   curl -sL --max-time 10 "https://docs.target.com/pendle-v2/Security"
   # May list audits, bounty rules, scope, and contact
   ```

3. **Subdomain probe for live instances:**
   ```bash
   for sub in app api docs staging test; do
     code=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 5 "https://${sub}.target.com")
     echo "$sub.target.com -> HTTP $code"
   done
   ```

4. **GitHub org check** for contract source and past audits:
   ```bash
   curl -s "https://api.github.com/orgs/target-org/repos?per_page=5"
   ```
   Check: `pendle-finance/pendle-core-v2-public` style repos contain `audits/` directories.

5. **Immunefi / HackerOne scan** — check if they also have a platform bounty:
   ```bash
   curl -s "https://api.immunefi.com/v1/projects?search=targetname"
   ```
   If no result → email is the only submission path.

### Email Submission Format

**Initial disclosure (brief, one bug per email):**
```
Subject: [PROTOCOL NAME] Security Vulnerability — [VULN TYPE]

Halo, saya menemukan kerentanan pada [target/endpoint]

Vulnerability: [short name]
Affected: [file/function/endpoint]
Severity: [CRITICAL/HIGH/MEDIUM]

I have a working PoC. Can share details on request.
```

**Rules:**
- Send ONE bug per initial email (unless asked for all)
- Do NOT include PoC code or full attack flow in initial email
- Wait for response before sending full report
- If no response in 3-5 days → follow up once, then pivot
- If email bounces → check docs/FAQ for alternative contact

### Targets Already Recon'd for Email Submission

| Target | Contact | Status |
|--------|---------|--------|
| BlockPI Network | security@blockpi.network | CORS wildcard + internal services exposed, ready to submit |
| Open Collective | security@opencollective.com | Stripe/Sentry/Google Maps keys found, bounty paused until Aug 31 |
| Pendle Finance | security@pendle.finance | security.txt confirmed, docs page active, but Ackee/Dedaub/Dingbats/C4 audited |

### Fallback: When Web Tools Are Down (Payment Required / Timeout)

If web_search, web_extract, and browser tools fail:
1. Curl + raw GitHub: https://raw.githubusercontent.com/org/repo/main/path
2. GitHub API: https://api.github.com/search/repositories?q=keyword+language:solidity
3. DefiLlama cached data: Check /tmp/protocols.json if previously saved
4. Security.txt direct probe — works without any API
5. Subdomain probes — no dependencies needed
6. DNS enumeration for infrastructure recon
7. **Live contest/bounty discovery via platform JSON APIs** — Sherlock (`mainnet-contest.sherlock.xyz/contests`) and Cantina (`cantina.xyz/api/v0/competitions?status=live`) return clean JSON to plain `curl`, bypassing Firecrawl billing errors and SPA HTML shells. See `references/live-contest-discovery.md` for endpoints, field maps, the "stale live flag" pitfall, and maturity/EV calibration.
8. **Exploit-intel harvesting from rekt.news (Next.js `__NEXT_DATA__` scrape).** When web tools are down and you want a study/pattern bank of recent real exploits, the rekt.news leaderboard is a Next.js app whose entire post index (title, date, slug, loss `amount`) lives in one `__NEXT_DATA__` JSON blob — no API needed:
   ```bash
   curl -sL -A "Mozilla/5.0" https://rekt.news/leaderboard/ -o /tmp/rekt.html
   # then in python: json.loads(re.search(r'id="__NEXT_DATA__"[^>]*>(.*?)</script>', html, re.S).group(1))
   # walk the dict for nodes having 'title' + 'date'; sort by parsed date; take the newest N
   # each article: curl -sL https://rekt.news/<slug>/ then extract the same __NEXT_DATA__ body field
   ```
   Article bodies are Markdown inside `__NEXT_DATA__` (key `body`/`content`) — strip HTML tags + unescape. This is how the 2026 exploit-pattern bank (`web3-audit` → `references/2026-exploit-patterns.md`) was built. Pair with the Cosmos/affected-team post-mortems on GitHub (`github.com/cosmos/security`) for the real technical root cause when the news writeup is only narrative.

## Contact Discovery
When submitting personal disclosure:
1. **Git log emails:** `git log --format="%ae" | sort -u`
2. **GitHub contributors:** repo page → Contributors tab
3. **X/Twitter status:** check latest posts for shutdown or winding down signals
4. **Privacy/contact page** — check FAQ, docs, or security page
5. **Discord:** usually linked in README or website footer
6. **./well-known/security.txt** — always check first before fallback
7. **Avoid:** generic security@ that may not be monitored — verify against security.txt docs page

## Expanded Attack Surface (Non-Contract Targets)
Web3 bug bounty is NOT just smart contracts. High-value targets:

### Wallet-Vendor Source-Available Libs (HIGHEST EV — do this before fighting a WAF)
Wallet vendors (Exodus, and peers) publish their **crypto + SDK libraries as an in-scope
open-source monorepo**. This beats their WAF-walled web endpoints on expected value every time:
- Source-available -> you can write a real Foundry/jest PoC (mandatory for payout).
- Crypto-primitive bugs map to the TOP reward tier (Exodus: up to $100k) vs the web-critical cap
  (Exodus web critical ~$10k only).
- No Cloudflare bot-management wall, no rate-limit-permission dance, no "creates a swap/order =
  auto-N/A" trap that guts the web surface.
- Highest-scrutiny files: **hand-rolled signature schemes with custom nonce generation**
  (nonce reuse/bias -> key recovery), wallet **encryption/container formats** (scrypt+AES-GCM,
  IV reuse, checksum/format confusion), address-type detection, and any lib whose test dir
  already fuzzes a bug class (they've hardened it -- look for what the fuzzer can't reach).
- Reality check: mature vendors write HIGH-quality crypto code. Most leads die on close read.
  Map the primitives, pick the custom/hand-rolled ones, PoC-first before claiming anything.
- See `references/exodus-wallet-h1-recon.md` for the Exodus `@exodus` H1 program (scope, reward
  tiers, XO-Swap auto-N/A hard-stop, `h1-<user>` UA whitelist rule, WAF reality) and the
  `ExodusOSS/hydra` monorepo file map (keychain, schnorr-z custom DRBG, SECO container, bip322-js).

### Web Application / Explorer
- **Blockscout-class explorers** — CORS misconfiguration, GraphQL introspection, session cookies, API docs exposure
- **Dashboard/frontend** — XSS, CSRF, secrets leak, CORS bypass, API key exposure
- **Admin panels** — if enabled in production, check for auth bypass

### Wallets / Extensions
- **Browser extensions** — background script permissions, message passing, key storage
- **Mobile wallets** — deep links, clipboard theft, intent hijack

### Infrastructure
- **RPC endpoints** — rate limiting, authentication bypass
- **Subgraphs/The Graph** — access control, query depth limits
- **IPFS pinning** — content manipulation, gateway vulnerabilities

### Bridges / Relayers
- **Off-chain validation** — relayer key management, message replay
- **Validator sets** — threshold signature issues, slashing logic

## Phoenix/Elixir Web App Patterns
When auditing Elixir/Phoenix apps (e.g., Blockscout):
- Check `endpoint.ex` for CORS config: `origin: *` + `credentials: true` = CRITICAL
- Check `/graphiql` and `/schema.graphql` exposure
- Check `http_only: false` on session cookies
- Check for conditional admin panel exposure
- Check rate limiting on sensitive endpoints

## Target Discovery When Programs Are Not Listed
When Immunefi/Cantina/HackerOne listings are dry or user asks for more targets, use this fallback:

1. **GitHub search** for recent Solidity repos on target chains:
   `https://api.github.com/search/repositories?q=Base+chain+smart+contract+language:solidity&sort=updated`
2. **DefiLlama chain pages** for small/new protocols:
   `https://defillama.com/protocols/lending/base`, `.../dexes/blast`, etc.
3. **Cross-reference** each candidate: GitHub public source? TVL < $10M? Launch < 6 months? Any audit?
4. **Rule out dead ends fast:** token-only repos, forks without modifications, abandoned projects, already-audited large protocols
5. **Web3 infra targets** — explorers, wallets, bridges, subgraphs, frontends may have no smart-contract bounty but still have web/app bugs worth reporting if a program exists or can be opened

**DeFiLlama fresh-scan is a WEAK source — triage each hit in ~30s before cloning.** A tight `tvl 0.5–50M + EVM chain + listed <120d + has github + bug-rich category` filter routinely returns only 3-4 hits, and most die on first inspection. Run these disqualifiers via GitHub API BEFORE cloning (all cheap `curl`):
   - **`"fork": true`** on the org's main repo → it's someone else's code (e.g. BTCD = a fork of `IPOR-Labs/ipor-fusion`). Skip. Check: `curl .../repos/<org>/<repo> | grep '"fork"'`.
   - **No Solidity/Vyper repo in the org at all** → the protocol isn't EVM smart-contract (e.g. Surge Credit = Bitcoin/Taproot/MPC; repos are all C++/Rust/TS/Go infra). Skip. Check: list org repos, look at `language` field.
   - **Already flagged honeypot in memory / prior session** (e.g. Ledgity) → skip without re-checking.
   - **Has a recent `audits/` dir with a fresh review** → run the commit-hash exhaustion check above.
   When the filter dries up, don't keep widening it blindly — pivot to **live-contest platforms** (Cantina/Sherlock/Code4rena JSON APIs, see `references/live-contest-discovery.md`) which guarantee an in-scope target + paying program, or ask the user for a specific target they already have on radar (Twitter/Discord alpha). A user-supplied target beats blind DeFiLlama nabbing every time.

## False-Positive Discipline
- **Match the RPC key's chain to the target's chain BEFORE relying on it.** A user-supplied Alchemy/Infura key is scoped to whichever networks are enabled on that *app*. An ETH-mainnet key does NOT work for an Optimism/Base/Arbitrum target — you'll get `-32600 "OPT_MAINNET is not enabled for this app"`. Test with `eth_blockNumber` on the exact endpoint first (`https://opt-mainnet.g.alchemy.com/v2/<key>` vs `eth-mainnet…`). For read-only state queries (`eth_call`, storage reads, reserve/supply sweeps) you rarely need a paid key at all — public RPCs (`optimism.publicnode.com`, `drpc.org`, `1rpc.io/op`) are un-rate-limited enough. A paid archive key only matters for **forking at a historical block**. Don't block on the wrong-chain key when a public RPC unblocks the read.
- **Never hunt/use leaked API keys to unblock yourself — use public RPC.** When you need chain RPC access and don't have a key for that chain, the answer is a free public RPC or the user enabling the network on their own app, NOT searching JS bundles for someone's leaked key and using it (that's credential theft, and a leaked-key finding is itself out of scope on SC-only programs anyway). The state sweep that killed the ExtraFi finding ran entirely on keyless public OP RPC.
- **Retire false positives immediately** — do not keep them as active candidates; they waste PoC time and pollute reports
- **One apparent critical bug is usually a false positive** — verify with code trace or fork simulation before drafting a report
- **PoC-FIRST, claim-SECOND (hard rule).** Never state a severity (Critical/High/Med) before a Foundry test is GREEN proving funds moved / state broke. Writing the PoC is what kills the false positive. In one session two separate "CRITICAL" claims (DeXe `tryExecute`, a supposed "unchecked transfer") both collapsed the moment a faithful PoC ran. Pattern-matching ("arbitrary call + no modifier = critical", "unchecked ERC20 return = bug") without reading the FULL mechanism is the #1 source of wasted hours and rejected reports. Reproduce the REAL contract's exact control flow in the PoC (including any assembly/revert), not a simplified stub.
- **Simulation / dry-run pattern is NOT a bug.** An external-call-forwarding function with no access modifier that ALWAYS reverts at the end (e.g. `_throwRevert(true)` via assembly, or a bare `revert()` after the calls) and is wrapped in `try {...} catch { return abi.decode(reason) }` is a deliberate off-chain simulation primitive. Because the whole call frame reverts, ALL state changes roll back — zero funds move, nothing persists. Before flagging any "unauthenticated arbitrary call" as critical, check whether it terminates in an unconditional revert consumed by an outer try/catch. If so, it's safe by construction. Verify with a PoC asserting target state is UNCHANGED after the call.
- **Canonical WETH `transfer()` unchecked-return is not a bug.** If the token address is fixed to canonical WETH (from a registry, e.g. `registry.getWETHContract()`), `transfer()` always returns true and reverts on insufficient balance — unchecked return is safe. Only unchecked returns on *arbitrary/user-supplied* tokens are exploitable. Also confirm the exact file/function/line before claiming — a grep hit does not mean the bug lives where you first assumed.
- **A REAL logic bug with NO impact is still a false positive — always trace the withdrawal/exit gate.** A flawed check that lets extra states through is only exploitable if the *value-extraction* path is also open. Teller v1 `CollateralFacet.depositCollateral()` gates status with `require(status == (TermsSet ^ Active) & status)` — i.e. `status == 3 & status`, which mathematically lets `Closed(3)` and `NonExistent(0)` pass (only `TermsSet(1)`/`Active(2)` intended). The bug is genuine. But `withdrawCollateral()` is independently gated `require(msg.sender == loan.borrower)` and skips the ratio check only for non-Active loans — so an attacker can never pull collateral a victim deposited; at most a borrower moves their OWN funds in and out of their own closed loan. Net impact: zero. Before writing up any "theft via bad status/validation check", find the function that actually MOVES the funds out and confirm it isn't gated to the legitimate owner. Verify the enum ordering from source (`enum LoanStatus { NonExistent, TermsSet, Active, Closed, Liquidated }`), not from assumption.
- **Re-verify any report sitting on disk from a PRIOR session before submitting.** A finished PDF/`report.md` from an earlier context is a self-report, not verified truth — a past session may have overclaimed. Re-read the real source (raw GitHub) and re-run the PoC (`forge test`) THIS session before telling the user it's submittable. The Teller XOR report was a polished PDF claiming "CRITICAL collateral theft"; a 5-minute re-trace of the current source debunked it. Contrast: PerpBond/iAERO's PoC re-ran 2/2 green this session → genuinely submittable.
- **Pivot on dead ends fast.** If a target has no exploitable surface after 1-2 focused passes, move to a different target/vector instead of deepening the same hole.
- **See `references/impact-gate-triage.md`** for the "real bug, zero impact" false-positive class (flawed check whose value-extraction path is independently owner-gated), the Teller v1 XOR case study (debunked — do not re-report), and the prior-session-report re-verification workflow.
- **Mature multi-audit codebases: classify the Slither flood BEFORE claiming.** When Slither + manual review returns only FALSE POSITIVES that are all by-design, the target is heavily-hardened — say so plainly, don't manufacture a critical. The specific FP patterns that dominate hardened code (all confirmed benign on Lombard strategy + bridge + stakeAndBake):
  - **`reentrancy-no-eth` on a CEI-correct fn** — state updated before `safeTransfer`, `nonReentrant` on the modifier, and the asset is ERC-20 (not ETH → the `no-eth` variant carries no callback risk). Verify CEI order + reentrancy guard before believing it.
  - **`dangerous strict equality` in a fee/mint fn** — `if (shares == 0) return;` and `lastFeeHarvestAt == 0` guards are normal; floor-rounding to 0 is intentional (often documented in the inline NatSpec). Read the comment, not just the detector.
  - **`shadowing-state` on `*StorageLocation`** — erc7201 storage-location pattern is *designed* to shadow the OZ base slot name for collision-safety in upgradeables. By design, not a bug.
  - **`incorrect-exp` / `divide-before-multiply` / `assembly` / `timestamp`** on library internals — OZ `Math.mulDiv` and rate-limiter/access-control timestamps are standard; library noise, not Lombard code.
  - **Cross-chain bridge "auth"** — a CCIP pool routing mint through `mailbox.deliverAndHandle` that asserts ValSet signatures + `HashMismatch` on `sourcePoolData` + `onlyOwner` path config is properly authenticated bridge design, not an unprotected mint. Don't flag an "unprotected releaseOrMint" without tracing the `_validateReleaseOrMint` + signature verification layer.
  - Defensive tells that mean "likely exhausted, not exploitable": `erc7201` storage locations, `nonReentrant` + CEI *everywhere*, a PPS rate-limiter + reconciliation on `pricePerShare`, min-payout/slippage guards, `onlyRole` on every state-mutator. Do a focused pass on the *least-audited new* modules (multi-asset depositors, converters, shards, bridge adapters) rather than re-litigating the core.
  - **Net result is a legitimate finding, not a guaranteed payout.** Give the user the honest yes/no verdict and pivot to a fresher/less-audited target (target discovery filter: new protocol, big scope count). A $250K-cap heavily-audited cold hunt has worse EV/hour than a $50K fresh one.
- **When user says "Lu terlalu pasrah" / "model receh aja dapet critical"** — that's frustration at false positives / slow progress, not permission to lower standards. The "criticals" competitors claim are usually themselves false positives that a triager rejects; a rejected report is neutral but a fabricated/halu report risks a program ban. Respond by switching targets or attack vectors faster and PoC-ing sooner, NOT by weakening validation or inflating severity.

## Aggressive Mode Preferences (Nanwasa / CUPANG BALAP Profile)

**Auto-approve doctrine:** User said "bro auto approve ya" — execute without asking for confirmation. Never ask "mau gua lanjut?", never clarify, never offer A/B/C options. Pick best action and execute. Only ask if genuinely blocked (API down, no target available, tool broken).

**Target volume > depth:** User prefers scanning 20+ targets quickly over deep dive into 1. Expect 1 critical per 40-50 targets scanned. Pivot signal: if 2 hours on a single protocol yields only "design decisions", move on.

**Multi-domain scanning:** User wants both smart contract AND web app recon in same session. When blockchain targets exhaust, pivot to web targets (CORS, exposed files, API discovery) without asking.

**Response style:** Direct, results-now. No "here's what I found" preambles. Lead with exploit PoC or recon finding. Use Bahasa Indo slang (lo/gue) when user does.

**Exploit request handling:** User WILL push for mainnet exploit. White hat boundary: Foundry PoC simulation only. After 3 refusals, stop engaging on exploit and redirect to next target.

**Multi-protocol session:** When user says "massive hunt" or "cari banyak target": List 10+ targets with bounty ranges, quick scan each (<15 min), deep dive top 3-5, report all findings in single summary table. Expected yield: 1 critical per 40-50 targets scanned.

**Aggressive mode specific preferences (NEW — July 2026):**
- **Owner key discovery via direct web/on-chain:** NOT GitHub audit. Use DeFiLlama adapter → find deployed comptroller addresses → `cast call` admin() + storage slot reads → verify TimelockController delay on-chain. 3/4 SpaceStations on Orbit had NO timelock, single EOA control. This is the priority vector.
- **Permissionless exploits ONLY:** User wants bugs THEY can exploit, not admin-only bugs. When user says "bugnya bisa withdraw ga" or "test bug itu work apa tidak" — they want oracle manipulation, reentrancy, flash loan attacks, rounding errors. Admin-only bugs (implementation swap requiring owner key) are real but NOT what user wants.
- **Fast scanning over deep dives:** "Yang penting ada benefit buat gua." Quick scan 20+ targets → deep dive top 1-2. Don't waste 3+ hours on saturated bounties (GMX, Aave, Uniswap).
- **No confirmation questions:** "Gimana bro" / "Bro lanjutin" = frustration signals. Continue from where you left off. Don't pause or ask for confirmation.
- **MEV sandwich bot as alternative revenue:** When bug hunting hits a wall, offer the sandwich bot. Requires minimal capital ($2-5 gas on Arbitrum L2), works 24/7, doesn't depend on finding novel bugs. Template: `templates/mev-sandwich-bot.py`.
- **Well-audited protocols are dead ends after 1-2 hours.** If after scanning GMX (315 files), tBTC-v2 (145 files), or Aave you find only "design decisions" not bugs — PIVOT. Don't waste 3+ hours.
- **Saturated bounties have diminishing returns.** GMX ($5M Immunefi bounty) was audited by multiple firms, hunted by hundreds for 3+ years. ROI: 1h on $5M saturated vs 1h on $50K unsaturated — latter has higher expected value/hour.
- **Tiered disclosure for reports:** Step 1: Brief description + "I have Foundry PoC". Step 2: Full report without PoC code. Step 3: PoC code only after bounty confirmed. Protects researcher if dev fixes without paying.
- **"Tidak ada system yang aman" = keep pushing.** When user says this after exhaustive audit, say so directly: "Genuinely spent 2+ hours, no novel critical bug found." Don't invent findings. Pivot to: (a) smaller unaudited targets, (b) web app recon, (c) MEV bot as alternative revenue.
- **User pushes for black hat / active exploitation.** Firm refusal required each time. User accepts alternatives (bug bounty) when theft is refused.
- **Legal scope only.** User accepts refusal on illegal tools and continues with legal hunting. Never breach this boundary.
- **Indonesian casual tone.** Use "bro/gua/lo", direct, no moralizing, no disclaimers.
- **Hands-off automation.** When a script/bot/cron is already set up, run it without asking "mau gue jalankan?". Just execute and report results.

## Proxy Rotation for Web App Scanning
Use user-supplied HTTP proxies when scanning web properties to avoid rate limiting. Rotate among 3+ proxies per request.


## JS Bundle API Key Extraction Pattern
When scanning DeFi frontends for leaked secrets:
1. GET homepage → extract all `<script src="...">` URLs
2. Download each JS file (limit 500KB)
3. Regex scan for: `alchemy`, `infura`, `apiKey`, `api_key`, `rpc_key`, `projectId` (WalletConnect 32-hex)
4. Verify by testing discovered RPC endpoints with `eth_blockNumber` / GraphQL queries

## Campaign / Price Sheet Calculator
For retail price list PDFs with mixed campaign rules:
1. Extract all pricing rows via `pdftotext` or PyMuPDF
2. Structure per SKU: HET → diskon faktur (fixed %) → netto1 → min_order_qty → netto2 (volume disc)
3. Build calculator: user inputs product + kemasan + qty, tool resolves min order threshold per variant and outputs line total + grand total
4. Key rule: volume minimums are **per variant** (per kemasan), NOT aggregated across variants of the same product family

## EDELx / ITLG Farming Cron
- Save JWE tokens to `/home/ubuntu/edelx-bot/.edel-cookies`
- Vote cron: every 2 hours via `edelx_auto_vote.py --check`
- Server-side freezes (`VAULT_MIGRATION_FREEZE`) cannot be bypassed; retry cron is the only path
- ITLG: use backup token refresh when primary expires; cron for claim/monitor

## Quality Bar
- [ ] Working exploit code (not just theory)?
- [ ] Every step reproducible without guessing?
- [ ] CVSS/severity backed by real impact argument?
- [ ] Report has actionable remediation?
- [ ] Checked for duplicates (past audits, GitHub issues)?
- [ ] Account for SPA fallbacks: `.env` return 200 on React/Next.js apps may be HTML, not real leak. Validate by non-HTML content type and non-JSON/generic structure.
