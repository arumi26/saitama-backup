# Omni-Repurpose Engine

**Category:** Content & Marketing

**Load when:** repurpose konten, ubah jadi thread, carousel IG, multi platform, script tiktok, distribusi konten
## DOCTRINE — distribusi > produksi
Konten bagus yang cuma tayang di 1 platform = sia-sia. omni-repurpose-engine ubah 1 sumber → X thread + post TG + carousel IG + script TikTok + script YouTube sekaligus, lokal ID, konsisten brand, dengan batasan tiap platform (280 char X, slide IG, durasi video).

Murni penyusun teks (offline, deterministik). Pelengkap content-strategy-social-media (kalender/strategi) — omni-repurpose-engine fokus TRANSFORMASI format. Publish didelegasi ke process-orchestration-bots/daily-assistant-briefing-alerts.

## TOOL (v4.2, net-new)
- `tools/repurpose.py` — `SourceContent(title, key_points, cta, referral_url, hashtags)` → `to_x_thread()` (≤280/tweet), `to_telegram()`, `to_ig_carousel()` (cover+poin+CTA), `to_tiktok_script()` (hook/body/cta + estimasi detik), `to_youtube_script()` (intro/segmen/outro), `repurpose_all()`.

## ALUR STANDAR
```python
from repurpose import SourceContent, repurpose_all
src = SourceContent(title="3 Airdrop Base Worth Difarming",
    key_points=["ZkProtoX points aktif", "BaseSwap volume tinggi"],
    cta="Cek panduan di channel.", referral_url="https://airdropfinder.id",
    hashtags=["airdrop", "base"])
out = repurpose_all(src)   # x_thread / telegram / ig_carousel / tiktok / youtube
```

## SCOPE & DELEGATION
| Butuh | omni-repurpose-engine | Delegasi |
|---|---|---|
| Sumber konten (panduan) | konsumsi `SourceContent` | auto-guide-studio guide / community-intelligence insight |
| Hook pembuka terbaik | pakai default | hook-a-b-lab hook lab (skor + varian) |
| Render video beneran | hasilkan script | video-script-to-screen-pipeline + skill remotion_video |
| Publish/jadwal | hasilkan teks | process-orchestration-bots / daily-assistant-briefing-alerts / content-strategy-social-media kalender |

## SAFETY RAILS
- Semua varian bawa disclaimer/DYOR yang sama dengan sumber — jangan hilang pas dipotong.
- Cek batas karakter kehormat (clip otomatis udah ada, tapi review hasil clip).

🔧 Upgrade: pipeline penuh auto-guide-studio → hook-a-b-lab (pilih hook) → omni-repurpose-engine (semua format) → video-script-to-screen-pipeline (video) → process-orchestration-bots (publish).
