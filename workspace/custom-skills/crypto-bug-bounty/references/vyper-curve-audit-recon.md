# Vyper / Curve-Style Repo Audit Recon

Playbook for auditing Curve-like Vyper codebases (multi-chain, per-chain deployment
YAMLs, modular `contracts/<domain>/<module>/<file>_v_NNN.vy` layout). Use when a target
is Vyper, or when the user points at a Curve-family bounty.

## 1. Program & scope reality (Curve)

- Curve's bounty is **self-hosted**, NOT Immunefi/HackerOne. Read the program page
  (`classic.curve.finance/bugbounty`) — it is a JS SPA, so `curl` returns an empty shell.
  Render with the browser tool, and pull the payout image directly:
  `curl -sL https://classic.curve.finance/bounty.png -o bounty.png` then OCR it
  (tesseract / pytesseract) — the table lives in the PNG, not in HTML.
- Contact: **`security@curve.finance`** (also in each contract's `@custom:security` tag).
- Payout (as observed): Critical **$250K**, High $50K, Moderate $10K, Low $1K.
- Scope: "substantial loss of money, broken liveness, irreversible loss of funds."
  Explicitly **excluded: front-end code that does not cause a smart-contract vuln** —
  so hunting `classic.curve.finance` front-end is wasted effort; hunt the contracts.
- Curve is on the well-audited AVOID list for a reason. Expect the fresh surface to be
  either (a) already covered by a public audit, or (b) WIP / not yet deployed. Prove
  which, then decide — do not manufacture a finding to look productive.

## 2. Deployed source-of-truth vs the repo you cloned

Deployment YAMLs carry `contract_github_url: https://github.com/curvefi/<repo>/blob/<commit>/...`.
The **authoritative deployed source is whatever repo that URL names** — for Curve it is
`curvefi/curve-lite` (Jan-2025 commits), and `curvefi/curve-core` is a later
rename/consolidation of the same tree. If you audit `curve-core` without checking, you may
be reading WIP. Always:

```bash
# what repo+commit is actually live
grep -rhoE "contract_github_url: .*" deployments/prod/ | sed 's/.*blob\///;s#/contracts.*##' | sort -u
```

## 3. Live-vs-WIP triage via deployment YAMLs (the highest-value trick)

A `_v_NNN.vy` file existing in `contracts/` does NOT mean it is deployed. The prod YAMLs
enumerate exactly what is live per chain. Use them as a gate BEFORE deep-reading a file:

```bash
cd deployments/prod
# every contract that is actually deployed (unique, with count of chains)
grep -rhoE "contract_path: .*" . | sed 's/contract_path: //' | sort | uniq -c | sort -rn
```

- If a module/version does not appear → it is WIP/devnet-only → **zero bounty value**.
- Case: twocrypto `implementation_v_300.vy` (a brand-new "donation protection" mechanism —
  the most interesting fresh code in the tree) was absent from all prod YAMLs = WIP.
  Correct call: do not report it.
- The deployed-but-older version (`implementation_v_210.vy`) IS live — so it is the real
  target, and it must then be checked against its audit (see §5).

## 4. Vyper idioms that look like bugs but are not

- **`range(x, bound=N)` == `range(0, x)`.** Vyper's two-arg `range` with `bound=` iterates
  `0 .. x-1`, it is NOT a start/stop pair. So `for i in range(n_all_coins, bound=MAX_ALL_COINS)`
  loops `0..n_all_coins-1`; the `if i == 0` guard inside is coherent, and a
  `for i in range(len(_coins), bound=MAX_LEN)` loop also covers `0..len-1`. Do not flag
  these as off-by-one / wrong-bounds without checking the Vyper semantics first.
- **Extra trailing zeros in a `DynArray` handed to another pool are harmless** if the
  callee indexes by a fixed `N_COINS` constant rather than `len(amounts)`. Verify the
  callee's loop bound before calling it a bug.
- **Tooling ceiling:** Slither's Vyper support tops out around **0.3.7**; it errors out on
  0.4.x sources (Curve-core is 0.4). For Vyper ≥0.4 fall back to `vyper` compile-check
  (`pipx install vyper==<pragma version>; vyper <file>.vy`) plus manual review. Do not burn
  time retrying slither on modern Vyper.
- **Display mangling ≠ source bug.** Tool output sometimes renders `empty(Epoch)` as a
  garbled `Epompty(Epoch)`, making it look like a typo/compile error. Verify against raw
  bytes before claiming: `grep -n "<line>" file | od -c`. If the bytes are `empty(Epoch)`,
  it is fine — retract.

## 5. Prove "deployed == audited" by diffing the canonical audited repo

Curve keeps the source-of-truth for each AMM in its own repo (`twocrypto-ng`,
`stableswap-ng`, ...). To know whether the deployed file is already-audited code or a
silent delta, normalize both sides (strip comments/pragma/imports/blank lines) and diff:

```bash
diff <(grep -vE "^\s*#|^\s*$|pragma|^from |^import " deployed/math_v_210.vy) \
     <(grep -vE "^\s*#|^\s*$|pragma|^from |^import " twocrypto-ng/contracts/main/TwocryptoMath.vy)
```

- Case result: twocrypto `math_v_210.vy` vs `twocrypto-ng` `TwocryptoMath.vy` differed only
  by `/`→`//` syntax modernization and a copyright year → semantically identical →
  already audited → EXHAUSTED.
- Empty/trivial diff = audited = drop it. A real semantic diff = your candidate surface.

## 6. Org survey: `pushed_at` lies, `git log` tells the truth

When scanning a GitHub org for the freshest work, the API `pushed_at` field reflects
metadata pushes (README edits), not code. Clone and read real commit dates:

```bash
git -C <repo> log -1 --format="%cd %s" --date=short
```

Cross-check the actual newest `.vy` commits before committing to a target.

## 7. Verdict discipline

Heavily-audited DeFi infra (Curve, Aave, Uniswap, GMX) is a low-EV cold hunt. After a
focused pass, if every fresh file is either WIP, already-audited, or admin-gated, the
honest output is **NO-GO + pivot**, not an inflated finding. A report without a green PoC
is auto-rejected and risks the program relationship.
