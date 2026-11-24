
# Rust Protocol / Consensus Code Audit

## USER PREFERENCE: BREACH MODE

When the user says "breach mode" or pushes for deeper analysis ("lanjutin sampe tembus", "masih kurang", questions your knowledge depth):
- **Never declare "clean" prematurely** - exhaust ALL attack vectors first
- **Run 40+ attack vectors minimum** before giving honest assessment
- **If no critical bugs found**, give honest assessment with specific recommendations (pivot vs. continue)
- **User expects aggressive, deep analysis** - not surface-level scanning
- **Don't repeat the same checks** - if a vector is clean, move on

## PERSISTENCE DOCTRINE (Never Give Up)

The user explicitly corrected me on this: *"Bisa ga sih kamu punya jiwa semangat ga nyerah dan gas nerus sampe dapet hasilnya?"*

Translation: "Don't you have the spirit to never give up and keep pushing until you get results?"

**Rules:**
1. **"Gas pol" is the only acceptable answer** — when user challenges your persistence, double down. Start a TODO list, commit to deliverables, show action.
2. **Every session must produce at least one concrete output** — a report written, a target scanned, a bug found. Never end a session with "I looked at X but nothing interesting."
3. **When stuck, change approach, not target** — if code audit hits 0 bugs, switch to: infrastructure recon, CORS scanning, JS analysis, API testing on the SAME target's web surfaces.
4. **If all approaches on one target fail** — produce a submission-ready report for the best finding you have (even Medium severity), then pivot to fresh target.
5. **Track progress with todo list** — show the user what you've committed to and check items off as completed.
6. **Never say "pivot" without first delivering something** — even a Medium-severity CORS report is better than declaring "no critical bugs found" with nothing to show.
7. **When stuck on code audit, switch to web/infra recon on the SAME target** — CORS scanning, JS analysis, endpoint discovery. Every target has a web surface.
8. **Session 2026-08-01 proof:** 55 attack vectors on Alpenglong = 0 criticals. Switched to BlockPI CORS scan → found wildcard + internal endpoints. Produced ready-to-submit report. The pivot was correct but only AFTER exhausting code audit AND producing a deliverable.

## CASE STUDY

See `references/alpenglow-case-study.md` for a full audit of Alpenglow (Solana consensus) — 55 attack vectors run, 3 low/informational findings, 0 critical/high.

## ATTACK VECTOR CHECKLIST (55+ vectors)

Run these systematically. Mark each as ✅ clean, ⚠️ low finding, 🔥 exploitable.

### Phase 1: Arithmetic Safety (10 vectors)
```
□ 1. f64→u64 casts in reward calculations - can they overflow at extreme values?
□ 2. u128 cross-multiplication in Fraction comparison - any precision loss?
□ 3. saturating_add / checked_sub - are they used consistently?
□ 4. Division before multiplication - rounding errors?
□ 5. NonZero<u64> usage - can any denominator be zero?
□ 6. u64::MAX boundary checks - can any sum exceed u64?
□ 7. i32 overflow in timeout multipliers - what is the i32::MAX boundary?
□ 8. Duration arithmetic - can as_secs_f64() lose precision?
□ 9. Stake accumulation - can aggregate_stake overflow?
□ 10. Epoch calculation - can epoch * slots overflow?
```

### Phase 2: BLS Cryptographic Safety (8 vectors)
```
□ 11. unwrap() calls in BLS verification - count them, check if triggerable
□ 12. unsafe PopVerified::new_unchecked - does aggregated key inherit PoP?
□ 13. Rogue key attacks - can malicious pubkey be injected into aggregation?
□ 14. Empty pubkey aggregation - what happens with empty input?
□ 15. Signature verification edge cases - verify_distinct_aggregated
□ 16. PoP (Proof of Possession) bypass - any path that skips PoP?
□ 17. Base2 vs Base3 encoding - can wrong encoding bypass verification?
□ 18. Bitmap overlap in check_disjoint - can primary/fallback overlap?
```

### Phase 3: Vote Pool / Equivocation (6 vectors)
```
□ 19. Vote type conflicts - can validator vote Skip AND Notarize?
□ 20. MAX_NOTAR_FALLBACK_ENTRIES - what happens at limit?
□ 21. Duplicate vote detection - can same vote be added twice?
□ 22. Rank overflow - can rank >= max_validators bypass checks?
□ 23. Vote pool pruning - can old votes be exploited after prune?
□ 24. Bitmap manipulation - can crafted bitmap bypass equivocation check?
```

### Phase 4: Migration State Machine (6 vectors)
```
□ 25. genesis_block None edge case - what happens before genesis cert?
□ 26. Migration slot boundary - exact slot where migration happens
□ 27. Feature flag activation - can it be manipulated?
□ 28. Genesis cert creation - can it be frontrun?
□ 29. Mixed epoch handling - TowerBFT ↔ Alpenglow transition
□ 30. Migration phase transitions - can phase be skipped?
```

### Phase 5: Timer / Liveness (6 vectors)
```
□ 31. Timeout multiplier overflow - i32::MAX boundary
□ 32. Standstill detection - can it be gamed?
□ 33. Standstill certificate broadcast - can it be exploited?
□ 34. DELTA_TIMEOUT manipulation - can timing be influenced?
□ 35. Timer park_timeout - can it cause liveness issues?
□ 36. Leader handover timeout - can it be extended maliciously?
```

### Phase 6: Reward Certificate (6 vectors)
```
□ 37. Reward cert validator inclusion - can non-staked validator be included?
□ 38. Reward slot validation - can reward_slot be manipulated?
□ 39. Empty validators set - can empty set pass verification?
□ 40. Stake threshold bypass - can Fraction comparison be gamed?
□ 41. Reward epoch mismatch - can reward_epoch != current_epoch?
□ 42. NUM_SLOTS_FOR_REWARD boundary - can slot be manipulated?
```

### Phase 7: Integration / Edge Cases (4+ vectors)
```
□ 43. Parent ready tracker - multiple fallback blocks edge case
□ 44. Intra-window slot handling - slots within leader window
□ 45. Safe-to-notar thresholds - can they be manipulated?
□ 46. Fast handover - can handover be exploited?
□ 47. Block production during migration - what happens pre-genesis?
□ 48. Channel saturation - can channels be overwhelmed?
□ 49. Lock contention - RwLock usage patterns
□ 50. Snapshot/restore - can state be corrupted?
```

## FINDINGS TEMPLATE

For each finding, document:
```markdown
### [SEVERITY] Finding Title
**Location:** file.rs:line
**Attack Vector:** What an attacker would do
**Impact:** What breaks (consensus safety, liveness, funds, DoS)
**Exploitability:** How hard to exploit (easy/medium/hard/theoretical)
**PoC:** If possible, runnable code showing the bug
**Fix:** Suggested fix
```

## HONEST ASSESSMENT PROTOCOL

When done with all vectors:
1. **Count findings by severity** (Critical/High/Medium/Low/Info)
2. **If 0 Critical/High:** Say so honestly, explain why (well-audited, defense-in-depth, etc.)
3. **Recommend next action:** Pivot target vs. continue with different angle
4. **Don't fabricate findings** - a clean audit is still valuable

## RUST-SPECIFIC PATTERNS TO CHECK

```rust
// 1. unwrap() on external input - DoS vector
some_result.unwrap()  // <- Can this be triggered by malformed input?

// 2. unsafe blocks - soundness
unsafe { PopVerified::new_unchecked(key) }  // <- Is the invariant actually maintained?

// 3. as casts - truncation
leader_windows as i32  // <- Can this overflow?

// 4. checked_mul/checked_add with unwrap
.checked_mul(other).unwrap()  // <- Can this overflow?

// 5. saturating arithmetic - can it hide bugs?
a.saturating_add(b)  // <- Is the saturation actually correct here?

// 6. HashMap entry API - race conditions
self.entries.entry(slot).or_insert_with(|| ...)  // <- Can this be called concurrently?

// 7. BitVec operations - bounds checking
ranks.set(rank as usize, true)  // <- Can rank exceed max_validators?
```

## RECOMPACTION RECOVERY

When context is compacted mid-audit and user says "lanjutkan cari bugnya":

1. **Do NOT restart from scratch** — resume from exact same audit state
2. **Read compaction summary** for: target name, attack vectors already checked, findings so far
3. **Pick up from next un-checked attack vector** — don't re-check already-cleaned vectors
4. If no remaining vectors are listed, expand to next phase (integration → network → resource exhaustion)
5. If 40+ vectors yield 0 critical bugs — give honest assessment with recommendation
6. **Don't ask "what next"** — user expecting continuous execution, not confirmation loops
7. No need to re-announce basic commands (grep, find, sed) — resume with the specific analysis

## PITFALLS

1. **Don't assume "well-audited" means "bug-free"** - even audited code has bugs, just fewer
2. **Don't focus only on arithmetic** - protocol logic bugs are often more impactful
3. **Don't ignore `unwrap()` calls** - they're DoS vectors if reachable from external input
4. **Don't trust comments** - "SAFETY:" comments can be wrong
5. **Don't skip integration checks** - bugs often live at boundaries between modules
6. **Don't fabricate findings** - a clean audit with honest "no critical bugs" is still valuable
7. **Don't give up too early** - run ALL vectors before declaring clean
