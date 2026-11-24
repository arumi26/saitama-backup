# Auditing Mature / Competition Targets (2+ audits, own invariant suite)

When the only live submission window is a Cantina/Sherlock competition on an already-audited
protocol, the EV is moderate-at-best and the workflow is different from a fresh unaudited target.
Be honest with the user up front: 2 audits + a team invariant suite + N triaged findings = low
probability of a High, realistic ceiling is usually a Medium (rounding/griefing/value-transfer edge).

## Ordered workflow that actually fits this target class

1. **Confirm the submission window is OPEN (not judging/finished).** Many "live" contests are past
   the submission phase. Check the deadline field, not just the status flag. (See
   `live-contest-discovery.md` for the stale-flag pitfall.)
2. **Clone at the EXACT commit in scope**, then `git checkout <hash>`. Competition scope pins a commit.
3. **Extract and read every `audit/*.pdf` FIRST** (`pdftotext -layout`). Build a table of every prior
   finding + severity. Those are duplicates/out-of-scope. The bugs they found map the *shallow* surface.
4. **Open `test/invariant/` and read the handler.** The invariant assertions ARE the protocol's own
   threat model, written by the team. If they fuzz conservation/solvency/state-machine identities,
   you will not beat grep-and-flag. You need an edge case the handler's op-mix or bounds don't reach.
5. **Read the in-scope impact definition literally.** Royco Day paid only for: (a) funds sent to a
   non-whitelisted address, (b) funds permanently locked/unrecoverable. Everything else — rounding
   dust, griefing, temporary DoS — is explicitly out. Do NOT chase bugs outside the two impact classes.
6. **Target the deep surface:** multi-leg composite flows (multi-asset deposit/redeem), cross-tranche
   value transfer (e.g. self-liquidation bonus paid from JT NAV to an LPT/ST redeemer), deferred/healed
   requirement checks that store a bool instead of a magnitude, rounding *direction* in share<->value
   round-trips.
7. **PoC-FIRST, always.** No severity claim before a green Foundry test proves funds moved / locked.

## Candidate-hunting heuristics that surfaced on Royco Day

- **Boolean "pending violation" flags that don't store magnitude.** `PENDING_LIQUIDITY_VIOLATION` is
  written as `1` when a worsening leg defers its check inside a multi-asset flow, and deleted when a
  later leg settles "satisfied". Worth a PoC: can a marginally-satisfied final leg heal a large
  deferred violation? (On Royco the `liquidityUtilizationWAD <= WAD` gate is absolute, so it looked
  closed — but this shape of "record-then-heal without remembering how bad it was" is a recurring
  bug pattern across protocols; always PoC it.)
- **Cross-tranche bonus/subsidy on a composite redemption.** In `lptRedeemMultiAsset` the inner ST
  redemption leg passes through `applySeniorTrancheSelfLiquidationBonus`, which sources value from
  `jtEffectiveNAV`. Check whether a non-ST actor (LPT holder) can trigger a JT->self value transfer,
  and whether it's cappable/gameable. Value-transfer-between-tranches is the highest-severity class
  on a tranching protocol because it maps directly to "funds lost by one cohort".
- **NAV conservation enforced by `require` in two places** (pre-op and post-op sync). Any arithmetic
  that could make `collateralNAV != stEff + jtEff` reverts hard — so a *leak* bug can't exist; only a
  *misattribution within conservation* (value moved to the wrong tranche while the sum still balances)
  is viable. Focus fuzzing/manual trace there.

## VPS build constraint (2GB RAM DigitalOcean box)

Compiling a large repo (Royco Day: ~12K SLOC + Balancer-v3 + OZ + solady + solc 0.8.35) on a 2GB box
thrashes swap hard (solc alone ~40% mem) and takes ~10+ minutes. This is expected, not a hang.
- Run `forge build` in the BACKGROUND with `notify_on_complete=true`; do not block a foreground call.
- Ensure `export PATH="$HOME/.foundry/bin:$PATH"` (Foundry PATH is not auto-set on this box).
- Fully init submodules first: `git submodule update --init --recursive --depth 1` (also long; bg it).
  The `--depth 1` matters — full history of Balancer/OZ is huge.
- While the build runs, keep reading source with read_file/search_files — the two are independent, so
  batch the reading against the background compile instead of idling.
- If the box OOM-kills solc, close other memory hogs or accept the slow swap-backed compile; do NOT
  conclude "build is broken" — check `free -h` and `ps aux | grep solc` to confirm it's still grinding.
