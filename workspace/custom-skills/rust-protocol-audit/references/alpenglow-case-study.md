# Alpenglow Consensus Code Audit — Case Study

**Target:** `anza-xyz/agave` (Alpenglow — Solana's new consensus protocol)
**Date:** 2026-08-01
**Prize pool:** Up to 50,000 SOL (~$7.5M)
**Submission window:** Aug 5-19, 2026
**In-scope crates:** votor/, votor-messages/, bls-sigverify/, bls-cert-verify/
**Code size:** ~20,000 lines Rust

## Method

55 orthogonal attack vectors were run systematically across 7 phases:
- Phase 1: Arithmetic Safety (10 vectors)
- Phase 2: BLS Cryptographic Safety (8 vectors)
- Phase 3: Vote Pool / Equivocation (6 vectors)
- Phase 4: Migration State Machine (6 vectors)
- Phase 5: Timer / Liveness (6 vectors)
- Phase 6: Reward Certificate (6 vectors)
- Phase 7: Integration / Edge Cases (4+ vectors)

Plus Phase 0: Pre-dive recon (GitHub issues, recent commits, README scanning).

## Findings

| # | Finding | Severity | Exploitable? |
|---|---------|----------|-------------|
| 1 | Timeout multiplier `1.05^n` overflows `i32` after ~249 days standstill — but MAX_TIMEOUT (1hr cap) prevents practical exploit | Informational | ❌ |
| 2 | 102 `unwrap()` calls in BLS verification — potential DoS via crafted input | Low | ❌ Inputs are BLS-verified, hard to reach |
| 3 | `unsafe PopVerified::new_unchecked` in `verify_base3` — comment explains safety reasoning, constituent keys have valid PoP | Informational | ❌ |
| 4 | `f64→u64` cast in reward calculation — safe at any realistic capitalization | Informational | ❌ |
| 5 | `Fraction` comparison uses correct `u128` cross-multiply — no precision loss | N/A (good) | ✅ Well-implemented |

**Total:** 55 vectors, 3 informational/low findings, 0 critical/high. ❌

## Why No Critical Bugs

1. **Code quality is genuinely high** — Rust + `saturating_add` + `checked_sub` everywhere
2. **Multiple audits already done** — Anza internal + external auditors + Cantina competition
3. **30+ known issues already tracked** (all closed or being fixed)
4. **Defense-in-depth** — BLS PoP, threshold checks, equivocation detection, parent-ready tracking all layered

## Key Technical Details

### Constants Found
```rust
const MIGRATION_SLOT_OFFSET: Slot = 32;        // Test config
const MIGRATION_SLOT_OFFSET: Slot = 5000;      // Production
const MAX_NOTAR_FALLBACK_BLOCKS: usize = 4;    // common.rs
const MAX_NOTAR_FALLBACK_ENTRIES: usize = 3;   // vote_pool.rs
const MAX_TIMEOUT: Duration = Duration::from_secs(3600);  // 1 hour cap
const DELTA_TIMEOUT: Duration = Duration::from_millis(400);
const DELTA_STANDSTILL: Duration = Duration::from_millis(10_000);
const BAN_TIMEOUT: Duration = Duration::from_hours(48);
```

### Thresholds
```rust
// CertificateType thresholds
Finalize(_)      => 60%
FinalizeFast(_)  => 80%
Notarize(_)      => 60%
NotarizeFallback => 60%
Skip(_)          => 60%
Genesis(_)       => GENESIS_VOTE_THRESHOLD (unknown)

// Safe-to-notar thresholds
SAFE_TO_NOTAR_MIN_NOTARIZE_ONLY                    => 40%
SAFE_TO_NOTAR_MIN_NOTARIZE_FOR_NOTARIZE_OR_SKIP    => 20%
SAFE_TO_NOTAR_MIN_NOTARIZE_AND_SKIP                 => 60%
SAFE_TO_SKIP_THRESHOLD                              => 40%
```

### Vote State Machine
Each validator per slot:
- Can vote: Skip XOR SkipFallback XOR Finalize XOR Genesis XOR Notarize XOR NotarizeFallback
- Can NOT vote Skip + Notarize on same slot
- Can NOT vote Finalize + any other type on same slot
- MAX_NOTAR_FALLBACK_ENTRIES=3 per slot per rank

### Reward Calculation
```rust
let numerator = epoch_state.max_possible_validator_reward as u128 
    * validator_stake_lamports as u128;
let denominator = epoch_state.slots_per_epoch as u128 
    * total_stake_lamports as u128;
let reward_lamports: u64 = (numerator / denominator).try_into().unwrap();
// Split equally: validator gets half, leader gets half
```

### Fraction Comparison (Safe)
```rust
impl Ord for Fraction {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        let lhs = (self.numerator as u128)
            .checked_mul(other.denominator.get() as u128).unwrap();
        let rhs = (other.numerator as u128)
            .checked_mul(self.denominator.get() as u128).unwrap();
        lhs.cmp(&rhs)
    }
}
// Uses u128 cross-multiplication — no precision loss like f64 would have
```

### Unwrap Hotspots
- BLS cert verify: 37 `unwrap()` calls
- BLS vote sigverify: 63 `unwrap()` calls
- BLS sigverifier: 2 `unwrap()` calls
- Vote reward: ~28 `unwrap()` calls (reward calculation, deserialization, bitmap encoding)

### Known Issues (OUT OF SCOPE for competition)
- 16+ tracked GitHub issues, all closed or in-progress
- OPEN issues (#14206, #13374, #13215) are public → OUT OF SCOPE per competition rules
- Recent fix: commit 4f21b82 — channel deadlock in votor (#14206)

## What Would Be Needed for a Breakthrough

- **Deep BLS crypto edge case** — requires formal crypto expertise
- **Full validator simulation** — race conditions at 1000+ node scale
- **Integration bugs** — Alpenglow ↔ TowerBFT migration ↔ banking stage interactions
- **Economic game theory** — stake-weighted voting edge cases at validator set transitions

## Lesson

Well-audited consensus code (20K+ Rust lines, multiple audits, active team) = 0 NEW critical bugs after 55 vectors. Pivot to less-audited targets or activate Breach Mode (economic/serialization/concurrency/integration/network attacks beyond code).