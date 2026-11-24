# Alpenglow Consensus Analysis — Solana Bug Bounty Competition

## Target
- **Repo:** `anza-xyz/alpenglow` (rules) + `anza-xyz/agave` (code)
- **Prize Pool:** Up to 50,000 SOL (~$7.5M at $150/SOL)
- **Submission Window:** Aug 5-19, 2026 (2 weeks)
- **Submission:** GitHub Security Advisory on `anza-xyz/alpenglow`

## In-Scope Crates (Core)
| Crate | Lines | Purpose |
|-------|-------|---------|
| `votor/` | 10,670 | Voting engine, consensus pool, event handler |
| `votor-messages/` | 2,558 | Vote/certificate types, wire serialization, migration |
| `bls-sigverify/` | 3,695 | BLS vote/cert signature verification |
| `bls-cert-verify/` | 945 | Certificate verification, stake-threshold checks |

## Severity Categories & Awards
| Category | Award (SOL) | USD (~$150/SOL) |
|----------|-------------|-----------------|
| Loss of Funds | 6,250-25,000 | $937K-$3.75M |
| Consensus/Safety Violation | 3,125-12,500 | $468K-$1.87M |
| Liveness/Loss of Availability | 1,250-5,000 | $187K-$750K |
| DoS | 315-1,250 | $47K-$187K |

## Certificate Types & Thresholds
| Certificate | Threshold | Description |
|-------------|-----------|-------------|
| Finalize | 60% | Slow finalization |
| Skip | 60% | Skip certificate |
| Notarize | 60% | Notarization |
| NotarizeFallback | 60% | Combined Notarize+NotarizeFallback votes |
| FinalizeFast | 80% | Fast finalization |
| Genesis | 82% | Migration genesis vote |

## Key Security Mechanisms
1. **Equivocation Detection** — Vote pool tracks per-rank voting history, rejects duplicates
2. **Fraction Comparison** — Uses u128 cross-multiplication to avoid overflow
3. **Saturating Arithmetic** — All stake calculations use `saturating_add`/`checked_add`
4. **Migration State Machine** — 5 phases: PreFeatureActivation → Migration → ReadyToEnable → AlpenglowEnabled → FullAlpenglowEpoch

## High-Risk Areas for Bugs
1. **Migration Logic** (~500 lines) — Complex state machine, genesis vote threshold (82%)
2. **Fast Leader Handover** — Timeout logic, parent-ready tracking
3. **Intrawindow Slots** — Off-by-one errors in leader window handling
4. **Reward Certificate Validation** — Slot calculation edge cases
5. **Base3 Certificate Formation** — Combining Notarize+NotarizeFallback votes

## Analysis Methodology
1. Clone `anza-xyz/agave` (shallow): `git clone --depth=1 --filter=blob:none`
2. Read RULES.md for scope and eligibility
3. Analyze core crates in order: `bls-cert-verify` → `votor-messages` → `bls-sigverify` → `votor`
4. Focus on: threshold checks, arithmetic, state transitions, equivocation handling
5. Build PoC on local fork (never mainnet)
6. Submit via GitHub Security Advisory

## Key Files
- `bls-cert-verify/src/cert_verify.rs` — Certificate verification (945 lines)
- `votor/src/aggregate_accumulator.rs` — Vote aggregation
- `votor/src/consensus_pool/vote_pool.rs` — Vote pool with equivocation detection
- `votor-messages/src/migration.rs` — TowerBFT→Alpenglow migration
- `votor-messages/src/certificate.rs` — Certificate types and thresholds
- `votor-messages/src/fraction.rs` — Fraction type for precise stake comparison

## Potential Findings (Low Severity)

### 1. MAX_NOTAR_FALLBACK Discrepancy
```
parent_ready_tracker: MAX_NOTAR_FALLBACK_BLOCKS = 4
vote_pool (BLS sigverify): MAX_NOTAR_FALLBACK_ENTRIES = 3
```
**Impact:** Parent-ready tracker can track more blocks than validators can vote for.
**Severity:** Informational

### 2. Timeout Multiplier DoS
```
1.05_f64.powi(leader_windows as i32)
```
**Impact:** If attacker triggers standstill, timeout increases by 5% per leader window. Max 1 hour.
**Severity:** Low (DoS)

### 3. Many `unwrap()` in BLS Verification
```
bls-cert-verify/src/cert_verify.rs: 15+ unwrap() calls
```
**Impact:** If any BLS operation fails, node panics. Could be DoS vector.
**Severity:** Low-Medium (DoS)

### 4. Slot 1 Edge Case
```
slot.is_multiple_of(NUM_CONSECUTIVE_LEADER_SLOTS) || slot == 1
```
**Impact:** Slot 1 is always treated as first in leader window. Intentional for genesis.
**Severity:** Informational

## Verdict
Code is well-audited with proper overflow protection, equivocation detection, and state machine validation. No Critical or High vulnerabilities found. Best potential is DoS/Liveness findings (315-1,250 SOL).
