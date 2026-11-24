# Solana Anchor build toolchain & version pinning (Kali offload)

When the 2GB VPS can't hold a build, offload to the Kali box over Tailscale
(`ssh -i ~/.ssh/royco_remote ramsy@kali`). Solana Anchor builds are the most
version-fragile offloads there are — pin EVERYTHING or `anchor build` fails in
confusing ways.

## Version matrix (verified Aug 2026)

| Anchor | Rust (`rust-toolchain.toml`) | Solana/Agave CLI | real example |
|---|---|---|---|
| 0.29.0 | 1.74.1 | 1.17.x / `build-bpf` era | Kamino klend, kvault |
| 1.0.2  | 1.90.0 | 3.0.0 / Agave 2.x `build-sbf` | marginfi-v2 |

Rules, in order:
1. Read `rust-toolchain.toml` (the `channel =` line) FIRST — the repo pins it.
   Building with latest stable (e.g. 1.98) fails with `#![cfg_attr(feature =
   "stdsimd", feature(stdsimd))]` → `error[E0635]: unknown feature 'stdsimd'`
   inside `ahash`. Kamino klend pins 1.74.1; marginfi pins 1.90.0.
2. `rustup toolchain install <ver> --profile minimal` then
   `rustup override set <ver>` inside the repo dir.
3. Anchor version = read the workspace `Cargo.toml`:
   `anchor-lang = { version = "X.Y.Z" }`. Install via
   `avm install X.Y.Z && avm use X.Y.Z`.
4. `solana` CLI must be on PATH at
   `$HOME/.local/share/solana/install/active_release/bin`.

## build-bpf vs build-sbf rename (the #1 gotcha)

anchor < 0.30 invokes `cargo build-bpf`; Agave 2.x renamed it to `cargo
build-sbf` and dropped the old name.

- Symptom: `error: no such command: 'build-bpf'` / `error: Found argument
  'build-bpf' which wasn't expected`.
- Fix WITHOUT downgrading solana — symlink in the active bin dir:
  ```bash
  ln -sf $HOME/.local/share/solana/install/active_release/bin/cargo-build-sbf \
         $HOME/.local/share/solana/install/active_release/bin/cargo-build-bpf
  ```
- Also set `export GOWORK=off` (anchor uses a Cargo workspace; harmless, and
  some repos choke otherwise).

## Verify WITHOUT compiling: pure-math PoC (fastest verdict path)

You do NOT need a `.so` to prove or kill a rounding/accrual lead in a lending
or vault program. Reimplement the exact integer fixed-point math in Python
(`fractions.Fraction` or bit-shifts for U68F60 / I80F48) and test the leads
directly:
- floor vs ceil direction of an exchange-rate conversion
- `approximate_compounded_interest` (Taylor order-3) vs true compound
- withdrawal penalty, share-to-mint, deposit-cap saturating math

Iron-clad result in minutes vs a 20-min first compile that may never finish on
a rate-limited box. Example (Kamino klend `approximate_compounded_interest`):
measured under-pricing 0.17% (50% APY) → 1.94% (100% APY) → 9574% (1000% APY),
but it's a *lender*-side loss + the fn is literally named "approximate" →
informational, not submittable. The Python exact-integer check killed the lead
with zero BPF build.

## Fortress signal — check this BEFORE sinking hours

If `audits/` (or the org's `audits` repo) lists 3+ firms INCLUDING formal
verification (Certora / Osec / OtterSec + Sec3 + Ackee/Hashlock), the shallow
surface is gone. The only value is the *unaudited delta*:
```bash
git fetch --unshallow --tags
# last-audited version is often embedded in audit filenames:
#   e.g. kamino_lend_ottersec_1.16.0_and_1.17.0.pdf  →  last = 1.17.0
git diff --stat <last-audited-tag> HEAD -- programs/*/src
git diff --name-status <last-audited-tag> HEAD | grep '^A'   # NEW files = real new surface
```
Then read ONLY the NEW files (`instructions/*/`, `state/*`). Those are the sole
places a fresh Critical/High can hide. Kamino klend (delta v1.18→v1.25, 8 new
files) and marginfi (0.1.10→0.1.11, ~12k insertions: `premium.rs`,
`rebalance.rs`, `rate.rs`) both turned out defensive-by-construction — but that
is the correct thing to check, and it's ~100x cheaper than reading 68k LOC of
already-audited code.

### Pre-release delta nuance (marginfi)
The fresh delta may live on a dedicated branch (`0.1.11-main`) that is NOT
production. SECURITY.md can still make "release" / "pre-release" code eligible
— read the exact wording. But non-production features are usually capped a
severity lower even when in scope.

### Bounty-channel gotcha (marginfi)
Marginfi is email-direct (`security@mrgn.group`), NOT escrow-platform. It has a
real "Credits" payout history + live TVL, but no public USDC cap + no escrow —
the exact ghosting-risk shape this user avoids. Flag the channel tradeoff
explicitly before the user commits to a PoC for a direct-email target.