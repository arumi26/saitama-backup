# Closed-Source Solana Programs — Source Availability (2026-08-29)

**Finding**: Sanctum Infinity ($199M TVL LST) — source code NOT on GitHub.

| Search Method | Result |
|---|---|
| `sanctum-labs` org | 404 |
| `SanctumLabs` org | 29 repos, ZERO Solana/Anchor related |
| GitHub API search `sanctum+anchor+rust` | 0 results |
| `infinity-labs` org | Generic, no Solana programs |
| `solana program show INF1nf1...` | Valid program but no linked source repo |

**Fallback decision rule**: If org/repo direct check AND API search both return 0 usable results → source is NOT public. Move to Phase 7 binary analysis (`solana program dump`, `strings`, upgrade authority check) or switch targets. Do NOT spend >10 min searching per target.

**Source-confirmed-available**: Drift V2 (drift-labs/protocol), Marinade, OpenBook V2, Vaulxfi, Kamino.
**Source-confirmed-NOT-available**: Sanctum Infinity, Jito Solana (open-core only).