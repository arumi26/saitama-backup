# Content Strategy & Social Media

**Category:** Content & Marketing

**Load when:** content calendar, content strategy, content pillar, carousel, reels, platform adapter, social media
Mesin konten sosial end-to-end: strategi (pillar/audience/positioning), kalender, adaptasi per-platform, hook scroll-stopper, caption+hashtag, dan script thread/carousel/reels. **Opsional, non-dana.** Tool: `tools/content.py`. Pelengkap content-creation-distribution (voice ID/CT & airdrop), humanizer-brand-voice (humanizer), creative-media-generation (visual), copywriting-writing-mastery (copy frameworks), content-research-analytics (riset/analitik).

> Beda dari content-creation-distribution: content-creation-distribution = voice Indonesia/crypto-twitter + template airdrop. content-strategy-social-media = strategi & produksi sosial umum lintas platform. Combo keduanya buat konten crypto-ID.

---

## 1. Content strategy builder

Sebelum produksi, tentuin fondasi (sekali, simpan di vault daily-assistant-ii-watchdog-vault-triage, reuse):

```
PILLARS    → 3-5 tema inti (mis. edukasi · behind-scenes · proof · opini · CTA). Rasio 70-20-10.
AUDIENCE   → siapa, masalah apa, di platform mana, bahasa apa
POSITIONING→ 1 kalimat: "buat [audience] yang [masalah], gua [solusi unik]"
TONE       → ambil dari brand voice (humanizer-brand-voice) / USER.md
GOAL        → awareness | trust | leads | sales — beda goal, beda format
```

Output = "content OS" yang nyetir semua keputusan berikutnya. Tanpa ini, konten jadi random.

## 2. Content calendar generator

```python
from content import calendar
plan = calendar(pillars=["edukasi","proof","opini"], days=30, per_week=5,
                platforms=["x","linkedin","ig"])
# → list {date, pillar, platform, format, topic_slot} — isi topik via LLM/ide (content-research-analytics)
```

Distribusi pillar merata + variasi format, hindari spam 1 jenis. Mingguan/bulanan. Sambung cron (process-orchestration-bots/power-pack-planner-swarm-automation) buat auto-publish.

## 3. Platform-specific adapter

Satu pesan, beda baju per platform — JANGAN copy-paste identik:

| Platform | Format menang | Panjang | Nada |
|---|---|---|---|
| **X/Twitter** | thread, 1-liner punchy | pendek, hook di tweet 1 | cepat, opini |
| **LinkedIn** | thought leadership, story | medium, baris pendek | profesional-personal |
| **Instagram** | carousel, visual-first | caption medium + hook | visual, relatable |
| **TikTok/Reels** | script video pendek | 15-60s, hook 3 detik pertama | energetik, native |

```python
from content import adapt
variants = adapt("inti pesan lo", platforms=["x","linkedin","ig","tiktok"])
```

## 4. Viral hook & scroll-stopper

Hook = 80% performa. Stop scroll dalam 3 detik / baris pertama:

```
POLA HOOK:
- Kontras   : "Semua orang bilang X. Mereka salah."
- Angka      : "3 kesalahan yang bikin lo rugi..."
- Pertanyaan : "Kenapa post lo gak ada yang liat?"
- Stakes     : "Gua kehilangan $5k sebelum sadar ini"
- Curiosity gap: "Ini yang gak ada yang kasih tau soal..."
```

Hook harus relevan ke isi (clickbait yang gak nepatin = kill trust). CTA jelas di akhir: satu aksi, bukan lima.

## 5. Caption + hashtag optimizer

```python
from content import caption, hashtags
cap = caption("topik", platform="ig", hook_style="curiosity", cta="follow")
tags = hashtags("topik", platform="ig", mix=("broad","niche","branded"))  # campur jangkauan
```

Hashtag: campur broad (jangkauan) + niche (relevan) + branded (milik lo). Riset trending → content-research-analytics. Jangan spam 30 tag generik.

## 6. Thread / carousel / reels writer

```python
from content import thread, carousel, reels_script
thread("topik", n=7)              # X/LinkedIn: hook → poin → CTA, tiap tweet berdiri sendiri
carousel("topik", slides=8)        # IG: 1 ide/slide, slide 1 = hook, terakhir = CTA
reels_script("topik", seconds=30)  # script + timing + voiceover + on-screen text
```

Repurposing 1 long-form → multi-format → content-research-analytics pipeline.

---

## Catatan
- Konten = artefak, gak ada gate. Publish ke platform = aksi outward → kalau via agent, R9 gate sekali.
- Humanize sebelum publish (humanizer-brand-voice) biar gak "bau AI". Visual → creative-media-generation. Frameworks copy → copywriting-writing-mastery.
- Combo: content-strategy-social-media + copywriting-writing-mastery (copy) + humanizer-brand-voice (humanize) + creative-media-generation (visual) + content-research-analytics (riset/analitik) + process-orchestration-bots/power-pack-planner-swarm-automation (schedule).
