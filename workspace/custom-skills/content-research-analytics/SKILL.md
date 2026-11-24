# Content Research & Analytics

**Category:** Content & Marketing

**Load when:** competitor analysis, trend research, social listening, audience insight, content pipeline, engagement
Sisi data & orkestrasi dari konten sosial: riset tren/kompetitor, insight audiens, social listening, analitik performa, A/B variant, best-time-to-post, engagement handler, dan **full content pipeline** (research → draft → visual → schedule → analyze). **Opsional.** Otak strategi di belakang content-strategy-social-media (produksi) & copywriting-writing-mastery (tulisan).

> Jujur soal data: analitik & "best time" butuh **data nyata** dari platform/akun operator (API/export). Tanpa itu = heuristik & benchmark umum, ditandai sebagai estimasi — bukan angka palsu.

---

## 1. Trend & competitor research

```
- Trending topic: cari di X/IG/LinkedIn/TikTok + Google Trends per niche & region
- Competitor teardown: format yang nempel, frekuensi, hook, gaya, gap yang bisa diisi
- Pain points: scrape komentar/forum/review → tema keluhan berulang = bahan konten
```

Sumber via web fetch operator / API. Untuk riset mendalam bersitasi → handoff scientific-deep-research. Output: daftar peluang konten ter-ranking by relevansi × momentum.

## 2. Audience insight & social listening

```python
# analisis komentar/engagement → tema + sentimen (real data dari export/API operator)
from content import analyze_comments
insight = analyze_comments(comments)   # → {themes, sentiment, questions, objections, quotes}
```

Real-time listening: pantau keyword/brand/kompetitor di sosial → peluang (pertanyaan belum terjawab, tren naik, krisis). Sambung alert (process-orchestration-bots/daily-assistant-briefing-alerts). Pertanyaan audiens = ide konten + objection buat di-address.

## 3. Performance analyzer

```python
from content import analyze_performance
report = analyze_performance(posts)    # butuh metrik real: impressions, engagement, CTR, saves
# → top/bottom performer, pola (format/jam/hook yang menang), rekomendasi konkret
```

Tanpa data real → kasih kerangka apa yang harus diukur, jangan ngarang angka. Pola menang → reinforce; yang flat → drop. Kaitkan ke self-improving loop (self-improvement-autonomous-fix): pola kebukti → instinct konten.

## 4. A/B testing & best-time

```python
from content import ab_variants, best_time
variants = ab_variants("caption asli", n=3, vary=["hook","cta","length"])  # 1 variabel/uji
slots = best_time(audience_tz="Asia/Jakarta", history=post_history)         # data > tebakan
```

A/B: ubah **satu** elemen per uji (hook ATAU CTA, jangan dua) — biar tau mana yang ngefek (prinsip sama agentic-eval-self-critique eval). Best-time dari data audiens sendiri > benchmark generik; tandai kalau cuma benchmark.

## 5. Engagement response handler

```
- Draft balasan komentar (match brand voice humanizer-brand-voice) — POSITIF cepat, KRITIK hati-hati
- Eskalasi: keluhan serius / legal / krisis → flag ke operator, JANGAN auto-reply
- Human-in-the-loop: draft dulu → approval → kirim (jangan auto-post balasan sensitif)
```

## 6. Full content pipeline (orkestrasi)

```
RESEARCH (content-research-analytics) → DRAFT (copywriting-writing-mastery+content-strategy-social-media) → HUMANIZE (humanizer-brand-voice) → VISUAL (creative-media-generation) →
SCHEDULE (process-orchestration-bots/power-pack-planner-swarm-automation cron) → PUBLISH (cross-platform, R9 gate) → ANALYZE (content-research-analytics) → loop balik
```

```python
from content import repurpose
pieces = repurpose(long_form_text, into=["x_thread","ig_carousel","reels_script","linkedin_post"])
# 1 long-form → banyak platform, tiap format di-adapt (bukan copy-paste)
```

- **Cross-platform publisher**: adapt (content-strategy-social-media) lalu publish ke banyak platform via API (protocol-binding-service-bridge).
- **Human-in-the-loop**: generate draft → minta approval operator → refine. Default buat outward content.
- **Scheduled agent**: konten rutin via cron (process-orchestration-bots/power-pack-planner-swarm-automation). Publish = aksi outward → R9 gate.
- **Self-improving loop**: performa (§3) → pelajaran (self-improvement-autonomous-fix) → strategi konten makin tajam.
- **Multi-agent**: riset / tulis / desain bisa di-split jadi lane swarm (power-pack-planner-swarm-automation) — executor yang publish, bukan lane riset.

---

## Catatan
- Analitik butuh data real — tanpa itu, heuristik bertanda "estimasi".
- Publish & auto-reply = outward → human-in-the-loop / R9 gate. Jangan auto-reply hal sensitif.
- Combo: content-research-analytics + content-strategy-social-media (produksi) + copywriting-writing-mastery (copy) + humanizer-brand-voice (humanize) + creative-media-generation (visual) + scientific-deep-research (riset dalam) + protocol-binding-service-bridge/process-orchestration-bots/power-pack-planner-swarm-automation (publish/schedule) + self-improvement-autonomous-fix/agentic-eval-self-critique (improve/eval).
