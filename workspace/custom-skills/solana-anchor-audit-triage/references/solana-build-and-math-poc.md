# Solana Anchor: Build Toolchain + Math PoC Without BPF

Two durable techniques from the Kamino klend deep-pass (Aug 2026): how to get a
fresh Anchor clone to actually BUILD on a modern box, and how to prove/kill a
fixed-point math lead with Python exact-integer — no BPF `.so`, no SOL, no RPC.

## 1. Building a cloned Anchor program (the "worth a deep pass" step)

### PITFALL — Rust toolchain pinning (`stdsimd` unknown-feature error)
Anchor-0.29-era repos ship a `rust-toolchain.toml` pinning an OLD Rust (klend
pins `channel = "1.74.1"`). Building with the box's default `stable` (Rust
1.98 on Kali in 2026) fails in a transitive dep:
```
error[E0635]: unknown feature `stdsimd`
  --> /.../ahash-<ver>/src/lib.rs
```
`ahash` uses `#![cfg_attr(feature = "stdsimd", feature(stdsimd))]`, which newer
Rust removed. The repo already declares the right toolchain — you just have to
install + override it:
```bash
rustup toolchain install 1.74.1 --profile minimal   # match rust-toolchain.toml channel
cd <repo> && rustup override set 1.74.1
rustc --version                                     # verify
```

### PITFALL — `anchor build` fails: `cargo build-bpf` renamed to `build-sbf`
Anchor 0.29/0.30 invokes `cargo build-bpf`; the Agave 2.x solana CLI renamed
that subcommand, so you get either:
```
error: no such command: `build-bpf`
    Did you mean `build-sbf`?
```
or `error: Found argument 'build-bpf' which wasn't expected`.
Two fixes, quick then correct:
```bash
# quick: symlink the renamed subcommand
SOLBIN="$HOME/.local/share/solana/install/active_release/bin"
ln -sf "$SOLBIN/cargo-build-sbf" "$SOLBIN/cargo-build-bpf"

# correct: install the solana 1.17.x CLI era where build-bpf still exists
sh -c "$(curl -sSfL https://release.anza.xyz/v1.17.25/install)"
```

### You usually DON'T need the BPF build to prove/kill a math lead
For fixed-point / rounding / compound-interest candidates, reimplement the
exact integer math in Python and compare to a reference. Deterministic verdict,
zero build. Reserve the full `anchor build` for reachability (full CPI path)
only.

## 2. Math PoC via Python exact-integer (no BPF)

Solana Anchor programs use fixed-point math — U68F60 (60 fractional bits) via the
`fixed` crate, and `BigFraction` via `uint::construct_uint` U256/U128. Reproduce
it exactly with Python big ints:
```python
FRAC_BITS = 60
ONE = 1 << FRAC_BITS
def fq(x): return x / ONE            # scaled int -> python float for display
def from_num(n): return n << FRAC_BITS

# fraction mul:  (a * b) >> FRAC_BITS
# fraction div:  (a << FRAC_BITS) // b
# to_floor()/.to_ceil()/.to_round() map to int trunc / ceil / round of the scaled value
```
For compound interest, the true reference is `(1 + r/units)^elapsed`:
```python
import math
# rate is scaled: r = rate_sf / ONE ; base = r / units_per_year
true_compound = math.exp(elapsed * math.log1p(base))   # NOT (1+base)**elapsed
```

Pitfalls that bit this session:
- `(1+base)**elapsed` overflows/hangs for `elapsed` up to ~150M (SLOTS_PER_YEAR)
  or `base` up to 1 (100% APY). Use `math.exp(n * math.log1p(base))`.
- Naive 3-nested loops (supply × liquidity × q) hit 80M iterations and hang the
  box. Random-sample each dimension (e.g. 200k samples) or bound each.
- **Direction discipline:** under-pricing interest accrual hurts LENDERS, not
  an attacker → Informational/Low, NOT a submittable Critical. A math bug is
  payable only if an attacker can extract funds net-positive. Confirm the
  victim side before rating.

## 3. Audit exhaustion by version TAG (Solana convention)

Unlike EVM repos, Solana teams tag releases (`release/v1.25.0`) and audit PDFs
name the version reviewed (e.g. `ottersec_1.16.0_and_1.17.0.pdf`). Find the
unaudited delta in two minutes:
```bash
git clone --depth 1 <repo> && cd <repo>
git fetch --unshallow --tags
git tag | grep release | sort -V | tail          # HEAD version
# last-audited version = highest in audit filenames (here 1.17.0)
git diff --stat release/v1.17.0 release/v1.25.0 -- programs/<prog>/src   # LOC delta
git diff --name-status release/v1.17.0 release/v1.25.0 -- programs/<prog>/src | grep '^A'  # NEW files
```
The 8 newly-ADDED files + 73 modified since the last audited tag ARE the only
worth-auditing surface — everything else is exhausted by 6 audit firms +
Certora formal verification. Read ONLY that delta; do not re-litigate core
`lending_operations.rs` / `reserve.rs` that N firms already swept.

Kamino klend result (2026-08): v1.18→v1.25 delta audited — ownership-transfer
state machine (CPI/compute-budget-gated), permissioning bitflags, withdraw
queue, oracle `is_known_to_be_zero` hardening, `approximate_compounded_interest`
TRUE_APR basis. Verdict: no Critical/High; the compound-interest under-price is
lender-side and by-design ("approximate"). Fortress.