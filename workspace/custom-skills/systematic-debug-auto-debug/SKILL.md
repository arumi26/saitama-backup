# Systematic Debug & Auto-Debug

**Category:** Meta & Self-Improvement

**Load when:** systematic debug, auto-debug, root cause, trace, stack trace, step through, isolate bug
Debug terstruktur 4-fase + loop hipotesis otomatis. fault-diagnosis-resolution = pustaka pola error (cepat, lookup). systematic-debug-auto-debug = metode buat bug yang **gak ada di pustaka** — yang aneh, intermittent, atau dalam. Load systematic-debug-auto-debug saat fault-diagnosis-resolution mentok atau bug non-trivial.

---

## 4 fase (urut — jangan loncat ke Fix)

```
1. RCA        → Root Cause Analysis: reproduce → isolasi → cari akar, BUKAN gejala
2. PATTERN    → cocokin ke pola dikenal (fault-diagnosis-resolution library, error sebelumnya di memory/self-improvement-autonomous-fix)
3. HYPOTHESIS → rumuskan dugaan yang TESTABLE, ranking by likelihood × cheapness-to-test
4. FIX        → uji hipotesis #1; benar → patch + regression test (agentic-eval-self-critique); salah → hipotesis #2
```

Anti-pattern fatal: langsung nebak fix tanpa reproduce. "Coba restart / tambah try-catch" tanpa tau akar = nutup gejala, bug balik lagi.

## Fase 1 — RCA

```
- Reproduce dulu. Gak bisa reproduce → kumpulkan kondisi (input, env, timing, state).
- Isolasi: bisect (komentari setengah / git bisect), minimal repro case.
- Tanya "kenapa" sampai akar: error X → karena Y → karena Z. Akar = Z, bukan X.
- Bukti, bukan tebakan: log, stack trace, state dump, KQL (enterprise-defensive-ops), eth_call revert reason.
```

## Fase 2 — PATTERN

Cocokin ke yang udah dikenal sebelum mikir dari nol:
- Pustaka fault-diagnosis-resolution (nonce too low, RPC timeout, duplicate webhook, dll).
- Memory/self-improvement-autonomous-fix — "error ini pernah ketemu?" (lesson reinforced).
- Gejala klasik: race (intermittent), off-by-one (boundary), stale cache (kadang benar kadang salah), env drift (jalan di lokal, gagal di prod).

## Fase 3 — HYPOTHESIS (inti auto-debug)

```python
from eval import variance   # reuse buat flaky bug
# Susun hipotesis sebagai pernyataan testable + cara uji termurah
hypotheses = [
  {"h":"RPC ankr rate-limit di burst", "test":"swap ke llamarpc, retry 20×", "cost":"low", "p":0.6},
  {"h":"nonce race antar wallet paralel", "test":"serialize 1 wallet, ulang", "cost":"low", "p":0.3},
  {"h":"gas estimate kurang saat spike", "test":"naikin buffer 2×, ulang", "cost":"med", "p":0.1},
]
# urut by p × (1/cost) → uji termurah-paling-mungkin dulu
```

Auto-debug loop:
```
WHILE bug belum terjelaskan:
  pick hipotesis dengan (likelihood × murah-diuji) tertinggi
  jalankan test → observasi
  konfirm → ke FIX
  bantah → buang, update prior hipotesis lain, lanjut
  semua habis → generate hipotesis baru dari bukti terbaru (jangan ngotot ke yang udah dibantah)
```

Untuk bug **intermittent**: pakai `variance()` (agentic-eval-self-critique) — jalanin N kali, lihat distribusi mode kegagalan. Bug yang 2/10 muncul = sinyal race/timing/rate-limit.

## Fase 4 — FIX

```
- Fix akar, bukan gejala. Kalau cuma bisa gejala → tandai + log alasannya (jangan diam).
- Tambah regression test (agentic-eval-self-critique Eval) — bug yang sama gak boleh balik diam-diam.
- Reversible & operasional (RPC/retry/cache) → boleh auto-fix (self-improvement-autonomous-fix SAFE_AUTO_ACTIONS).
- Nyentuh skill/dana/rail → proposal (frozen-paths), operator acc + re-lock.
- Catat ke memory (self-improvement-autonomous-fix): gejala → akar → fix. Next time jadi entry fault-diagnosis-resolution.
```

---

## Output ke operator

```
🔬 systematic-debug-auto-debug mass-mint flaky (3/50 gagal "AlreadyMinted")
  RCA: gagal hanya di wallet yang udah mint epoch lalu — bukan bug, state on-chain
  HYP#1 (p .7): checker eligibility skip cache stale → CONFIRMED (cache 1h, mint 40m lalu)
  FIX: invalidate eligibility cache sebelum batch → regression test added (agentic-eval-self-critique)
  auto-fix? NO (logic skill universal-nft-minter) → 📝 proposal ditulis
```

systematic-debug-auto-debug = metode. Pustaka cepat tetap fault-diagnosis-resolution; bukti kuantitatif tetap agentic-eval-self-critique; lesson disimpan self-improvement-autonomous-fix.
