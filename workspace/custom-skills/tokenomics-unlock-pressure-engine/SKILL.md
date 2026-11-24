# Tokenomics & Unlock Pressure Engine

**Category:** Web3 & Crypto

**Load when:** unlock token, vesting, cliff, kalender unlock, sell pressure, tokenomics, jual sebelum unlock
## DOCTRINE — supply makro = sinyal exit
Pelengkap exit_planner (airdrop-intelligence). tokenomics-unlock-pressure-engine fokus **tekanan jual makro**: kalender vesting/unlock + prediksi dampak tiap event (nilai unlock vs likuiditas harian) → sinyal "kurangi posisi sebelum unlock besar".

Murni logika (offline, deterministik). `now` WAJIB di-inject (TIME.md) — gak ada fabrikasi waktu. Data unlock/likuiditas mentah didelegasi ke web3-on-chain-operations/scientific-deep-research.

## TOOL (v4.2, net-new)
- `tools/unlock_engine.py` — `UnlockEvent` + `MarketState` → `assess_event(ev, mkt, now)` → `UnlockVerdict` (days_until, unlock value, % circulating, pressure_ratio, pressure low/medium/high/extreme, signal). `build_calendar()` urut tanggal; `biggest_pressure()` cari event terberat.

## ALUR STANDAR
```python
from unlock_engine import UnlockEvent, MarketState, build_calendar
# now di-inject dari [RUNTIME CONTEXT]
mkt = MarketState(price_usd=2.0, total_supply=1e9, circulating_supply=2e8,
                  daily_volume_usd=5e6)
evs = [UnlockEvent("Investor cliff", now + 10*86400, 8.0)]
for v in build_calendar(evs, mkt, now):
    print(v.report())   # 🔓 ... pressure extreme — kurangi posisi DULUAN
```

## METRIK
- `pressure_ratio` = nilai unlock / volume harian → extreme ≥3x, high ≥1x, medium ≥0.3x.
- `pct_of_circulating` = berapa % beredar yang membengkak.

## SCOPE & DELEGATION
| Butuh | tokenomics-unlock-pressure-engine | Delegasi |
|---|---|---|
| Jadwal vesting & supply | konsumsi `UnlockEvent` | scientific-deep-research (riset) / web3-on-chain-operations (on-chain) |
| Harga & volume live | konsumsi `MarketState` | web3-on-chain-operations + muse |
| Eksekusi jual | hasilkan sinyal | airdrop-intelligence exit_planner + C1 + governor |
| Time source strict | wajib `now` | TIME.md (Layer 1/2) |

## SAFETY RAILS
- Time-sensitive: tanpa Layer 1/2 time di strict mode → tahan, jangan nebak.
- Sinyal = pendukung keputusan, bukan jaminan harga turun/naik.

🔧 Upgrade: combo daily-assistant-briefing-alerts buat alert H-3 sebelum unlock besar otomatis.
