# Solana / Anchor Hunt Execution Discipline

## Outcome-first loop
A security hunt is not successful because recon, source mapping, or toolchain setup completed. The deliverable is one of:

1. a reproducible failing invariant or exploit PoC;
2. a concrete candidate killed by a test/trace, with the next surface selected; or
3. a bounded no-finding verdict after the predefined surface budget is exhausted.

Do not repeatedly narrate setup progress. Report only state changes that affect the hunt: build green, test failing for the intended reason, candidate disproved, or blocker requiring a different route.

## Early decision gate
Within the first five meaningful actions:

- verify bounty/scope and payout route;
- identify the latest audited commit and compute the unaudited delta;
- select one value-bearing invariant;
- choose the cheapest executable harness;
- define the pivot/stop condition.

If the delta is defensive and heavily tested, do not call the target “clean” after source reading. Say only that no lead survived the current pass, then either test a specific invariant or pivot.

## Harness ladder
Use the cheapest rung that proves or kills the hypothesis:

1. Existing host-side `cargo test` for pure Rust/math/state logic.
2. Add a focused unit/property test around the exact invariant.
3. Standalone Rust harness with faithful structs/math.
4. Anchor program build and local-validator integration test.
5. Full workspace build only when account constraints/CPI behavior require it.

A full Anchor build is not a prerequisite for pure accrual, rounding, conservation, or state-machine math. Avoid burning the hunt budget compiling unrelated mock programs.

## Anchor workspace build recipe
For modern Anchor branches:

```bash
export PATH="$HOME/.cargo/bin:$HOME/.avm/bin:$HOME/.local/share/solana/install/active_release/bin:/usr/bin:$PATH"
avm use <repo-anchor-version>
rustup override set <repo-rust-version>
solana --version
anchor --version
```

If generated keypairs disagree with `declare_id!` / `Anchor.toml`, use a disposable worktree and run:

```bash
anchor keys sync
anchor build --ignore-keys
```

Never modify the canonical audit checkout just to satisfy local generated keypairs. Record the exact commit before build.

## Timeout / failure pivot
A long full-workspace build timing out without `.so` is a decision point, not a reason to repeat the same build:

- inspect which crate/program caused the delay;
- switch to `cargo test -p <relevant-crate> <focused-test>` or a standalone harness;
- compile only the in-scope program if the workspace supports it;
- retry the full build only after changing the approach materially.

same overflow behavior.

**Compiled binary delivery:** Ship the compiled binary + source. The binary alone proves execution; the source lets triagers verify logic without rebuilding. Store at `/home/ubuntu/poc_<project>/poc_exploit`. A successful run output like `stolen 500000000 > vault 50000000` is sufficient evidence of exploitability for bounty programs that require PoC.

## SBPF Build + Deploy Bootstrap (Fresh Box)

```bash
# 1. Install Solana (binary release — avoids crates.io yank issues)
curl -sSfL https://github.com/anza-xyz/agave/releases/download/v1.18.12/agave-ubuntu-x86_64-v1.18.12.tar.bz2 | \
  tar -xj -C /tmp/solana-release/
export PATH=/tmp/solana-release/solana-release/bin:$PATH

# 2. Build program (cargo-build-sbf installs its own BPF toolchain)
cd /path/to/repo
cargo build-sbf --arch v1 2>&1 | tail -20
# Output: target/deploy/<program>.so (SBPF v1 — most widely compatible)

# 3. Start local validator with broader feature set
# WARNING: --enable-sbpf-v3/--enable-sbpf-v4 do NOT exist as flags.
# The validator auto-determines supported SBPF versions from the feature set.
# Clone from devnet to get the broadest feature set:
nohup solana-test-validator \
  --url https://api.devnet.solana.com \
  --clone-feature-set \
  --ledger /tmp/ledger \
  -q --reset \
  > /tmp/validator.log 2>&1 &
# Note flag order matters: --clone-feature-set must come before --ledger.

# 4. Deploy
solana config set --url http://127.0.0.1:8899
solana program deploy target/deploy/<program>.so
```

### Known Friction Points

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `Detected sbpf_version required by the executable which are not enabled` | Default localhost genesis only enables SBPF v1 | Use `--clone-feature-set --url https://api.devnet.solana.com` |
| `rustup target add bpfel-unknown-unknown` fails | nightly toolchain name mismatch | Skip it — `cargo-build-sbf` manages toolchain internally |
| `--enable-sbpf-v3: unknown argument` | Flag deleted in v1.18.12 | Remove; clone feature set instead |
| `--bpf-program <name> file.so: No such file or directory` | Flag expects a keypair FILE, not a program name | Omit pre-deploy flag, deploy separately with `solana program deploy` |
| `Os { code: 28 } No space left` during build | Platform-tools download to `~/.cache/solana/` | Clean: `rm -rf ~/.cache/solana/v<cache-version>/platform-tools/` or free disk |
| Validator exits silently on bad flag | Error goes to stderr before log redirect | Capture output to a file: `exec > /tmp/validator.log 2>&1` at the start |

### SBPF Version Selection

- `cargo build-sbf --arch v1` → universal compatibility, works on any test-validator
- `cargo build-sbf --arch v0` → oldest, minimum binary size but fewer instructions
- Default (no `--arch`) → uses program's Cargo.toml or SDK default (may require newer runtime)
- **Anchor 0.32 with solana-program 2.x builds SBPF v2+ by default** — deploy needs `--clone-feature-set`

### Disk Management on 2GB VPS

Platform-tools extraction needs ~2.5GB temporarily. Clean up between builds:
```bash
rm -rf ~/.cache/solana/v*/platform-tools/
rm -rf /path/to/repo/target/sbpf-solana-solana/
df -h /  # verify >2GB free
```

## Reporting language
Use evidence-calibrated labels:

- **Confirmed:** PoC/test fails for the intended reason and demonstrates impact.
- **Candidate:** source-level hypothesis, not yet reproduced.
- **Killed:** test/trace disproved exploitability.
- **No lead survived this pass:** bounded review found nothing reproducible.

Avoid “clean,” “fortress,” or “solid” as audit conclusions unless a formal scope and exhaustive methodology justify them. Never substitute volume of reviewed LOC for exploit evidence.
