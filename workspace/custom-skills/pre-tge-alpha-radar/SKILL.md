# Pre-TGE Alpha Radar

**Category:** Web3 & Crypto

**Load when:** alpha airdrop, pre-TGE, points program, testnet incentivized, radar airdrop, proyek belum ada token
## DOCTRINE — discovery, bukan eligibility
airdrop-intelligence jawab "wallet gue layak gak buat airdrop X?" — **pre-tge-alpha-radar jawab "proyek mana yang worth difarming SEKARANG?"** sebelum token-nya ada. Ini alpha mentah: jualan utama komunitas.

Murni logika scoring (offline, deterministik). Pengumpulan sinyal mentah (funding, deploy kontrak, points program, GitHub, governance) didelegasi ke protocol-binding-service-bridge/scientific-deep-research/web3-on-chain-operations.

## TOOL (v4.2, net-new)
- `tools/alpha_radar.py` — `ProjectSignal` → `score_project()` → skor 0-100 + tier (cold/watch/warm/hot) + alasan konkret + estimasi effort. `rank(list)` urutkan banyak proyek.

## SINYAL YANG DINILAI
points program (paling kuat) · testnet incentivized · governance tanpa token · backing VC tier-1 · besar funding · momentum dev (commit/kontrak) · pertumbuhan sosial · timing TGE (6-18 bln sejak raise). **Token udah ada → skor di-cap 30** (peluang airdrop utama lewat).

## ALUR STANDAR
```python
from alpha_radar import ProjectSignal, rank
sigs = [ProjectSignal("ZkProtoX", funded_usd=30e6, points_program=True,
        testnet_live=True, github_commits_30d=80, backed_by_tier1=True,
        days_since_last_round=300, social_growth_pct=60)]
for r in rank(sigs, top=10):
    print(r.report())   # 📡 ZkProtoX: 78/100 (hot) · effort high
```

## SCOPE & DELEGATION
| Butuh | pre-tge-alpha-radar | Delegasi |
|---|---|---|
| Data funding/sosial/GitHub | konsumsi `ProjectSignal` | protocol-binding-service-bridge (API) / scientific-deep-research (riset) |
| Aktivitas on-chain (deploy/testnet) | konsumsi sinyal | web3-on-chain-operations + muse |
| Cek wallet sendiri layak | — | airdrop-intelligence eligibility |
| Eksekusi farming | hasilkan watchlist | client-revenue-engine + airdrop_runner (governor) |

## SAFETY RAILS
- Skor = **probabilitas + estimasi**, BUKAN jaminan ada airdrop/cuan. Sampaikan apa adanya.
- Effort tinggi = modal/waktu besar — pasangkan sama farming-portfolio-roi-optimizer (ROI) sebelum all-in.

🔧 Upgrade: combo farming-portfolio-roi-optimizer buat hitung ROI kandidat, auto-guide-studio buat auto-bikin panduan begitu masuk tier hot.
