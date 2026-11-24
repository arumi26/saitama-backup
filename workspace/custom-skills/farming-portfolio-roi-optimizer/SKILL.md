# Farming Portfolio & ROI Optimizer

**Category:** Web3 & Crypto

**Load when:** ROI farming, portfolio airdrop, untung rugi farming, gas vs hasil, farm mana lanjut
## DOCTRINE — farming = keputusan ber-angka
Berhenti nebak. Tiap posisi farming dihitung: biaya (gas) vs expected value (estimasi airdrop × keyakinan + realisasi) → ROI → aksi keep/trim/drop. Deteksi wallet nganggur yang cuma bakar gas.

Murni logika (offline, deterministik). Data biaya/aktivitas mentah didelegasi ke web3-on-chain-operations/muse (on-chain) + `cost_ledger.py`.

## TOOL (v4.2, net-new)
- `tools/farm_roi.py` — `FarmPosition` → `evaluate()` → `PositionVerdict` (cost, EV, net, ROI, action, notes). `analyze(list)` → `PortfolioSummary` (agregat + ranking by net + grouping per aksi).

## ALUR STANDAR
```python
from farm_roi import FarmPosition, analyze
port = [FarmPosition("LayerZero", gas_spent_usd=120, est_airdrop_usd=2000,
        confidence=0.6, last_activity_days=3),
        FarmPosition("DeadFarm", gas_spent_usd=80, est_airdrop_usd=50,
        confidence=0.1, last_activity_days=60)]
print(analyze(port).report())   # ranking + keep/trim/drop + idle warning
```

## LOGIKA AKSI
- ROI ≥ 1 → **keep** · net>0 tapi ROI<1 → **trim** · net<0 → **drop**
- realized>0 & est=0 → **claim-soon/trim** · idle >30 hari tanpa realisasi → flag

## SCOPE & DELEGATION
| Butuh | farming-portfolio-roi-optimizer | Delegasi |
|---|---|---|
| Gas terpakai / modal terkunci on-chain | konsumsi `FarmPosition` | web3-on-chain-operations + muse + cost_ledger |
| Estimasi nilai airdrop | input `est_airdrop_usd` | pre-tge-alpha-radar (alpha) / scientific-deep-research (riset) |
| Eksekusi exit dari posisi | hasilkan aksi | airdrop-intelligence exit_planner + C1 + governor |

## SAFETY RAILS
- EV pakai `confidence` (0-1) — estimasi pendukung, bukan janji cuan.
- Keputusan drop = rekomendasi; operator tetap pegang kendali (R9 kalau ada konsekuensi dana).

🔧 Upgrade: feed `est_airdrop_usd` dari pre-tge-alpha-radar, export ranking ke XLSX via data-transformation-insight/file-artifact-production, auto-reminder task harian per posisi via daily-assistant-briefing-alerts.
