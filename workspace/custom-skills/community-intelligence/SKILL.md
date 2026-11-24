# Community Intelligence

**Category:** Meta & Self-Improvement

**Load when:** topik trending komunitas, sentimen komunitas, FUD, analisis chat, pertanyaan member
## DOCTRINE — komunitas = sumber sinyal, bukan cuma audiens
Ribuan pesan member = data: topik yang lagi panas, pertanyaan berulang (bahan FAQ/konten), sentimen, FUD yang harus diredam cepat. community-intelligence ubah itu jadi laporan terstruktur + ide konten.

Murni analitik teks (offline, deterministik). Pengambilan pesan mentah didelegasi ke process-orchestration-bots (telegram) / protocol-binding-service-bridge / skill browser. `now` di-inject buat window trending (TIME.md).

## TOOL (v4.2, net-new)
- `tools/community_intel.py` — `Message(text, ts, reactions)` → `analyze(msgs, now, window_hours)` → `IntelReport` (top_topics, trending_questions, sentiment pos/neg/netral, fud_alerts, content_ideas).

## ALUR STANDAR
```python
from community_intel import Message, analyze
msgs = [Message("Kapan claim ZkProtoX dibuka min?", ts=..., reactions=5), ...]
r = analyze(msgs, now=now, window_hours=24)
print(r.report())   # 🔥 topik · ❓ sering ditanya · 🚨 FUD · 💡 ide konten
```

## OUTPUT DIPAKAI BUAT
- FAQ/konten dari `trending_questions` (feed ke auto-guide-studio/omni-repurpose-engine)
- Respons cepat `fud_alerts` (klarifikasi resmi sebelum membesar)
- Prioritas topik konten minggu ini dari `top_topics`

## SCOPE & DELEGATION
| Butuh | community-intelligence | Delegasi |
|---|---|---|
| Tarik pesan TG/Discord/X | konsumsi `Message` | process-orchestration-bots / protocol-binding-service-bridge / skill browser |
| Bikin konten dari insight | hasilkan ide | auto-guide-studio (guide) / omni-repurpose-engine (repurpose) / copywriting-writing-mastery |
| Balas FUD publik | deteksi + draft ide | operator review → process-orchestration-bots |

## SAFETY RAILS
- Heuristik keyword — sentimen kasar, BUKAN pengganti baca manual buat isu sensitif.
- Privasi: analisis agregat; jangan expose identitas member individual di output publik.
- FUD soal "scam/gak cair" → cek fakta dulu (anti-scam-sentinel/contract-change-claim-address-watcher) sebelum klarifikasi.

🔧 Upgrade: jadwal harian via daily-assistant-briefing-alerts → laporan pagi "apa kata komunitas semalam".
