# Product & Spec Workflows

**Category:** Engineering

**Load when:** PRD, to-issues, grill me, spec, user story, TDD, product requirement, breakdown task
Ubah obrolan jadi artefak yang bisa dieksekusi: idea kabur → di-"grill" jadi konkret → PRD → issues/tasks, plus TDD dan internal-comms. **Opsional.** Hulu-nya problem-shaping-decision-support (problem shaping), hilirnya software-engineering-coding (coding). Tool: `tools/prd.py`.

| Capability | Input → Output |
|---|---|
| Grill-Me | idea kabur → idea tajam (interogasi terstruktur) |
| To-PRD | percakapan → dokumen PRD |
| To-Issues | PRD → daftar issue/task ter-breakdown |
| TDD superpower | spec → test dulu → impl |
| Internal-Comms | konteks → komunikasi profesional |

---

## 1. Grill-Me — flesh out idea kabur

Operator punya idea setengah jadi. Jangan langsung iya — *grill* sampai konkret:

```
- Tanya yang TAJAM, satu per satu: "siapa user persisnya? masalah apa yang DIBAYAR buat solve?"
- Tantang asumsi: "kenapa ini, bukan [alternatif lebih simpel]?"
- Tarik ke spesifik: scope, sukses keliatan kayak apa, non-goals (yang SENGAJA gak dikerjain)
- Berhenti pas idea udah bisa di-PRD-kan. Jangan grill berlebihan (lihat problem-shaping-decision-support: jangan over-shape).
```

Beda dari problem-shaping-decision-support (shaping tujuan operasional umum) — Grill-Me khusus *idea produk/fitur* → siap jadi spec. Output: idea yang punya user, masalah, scope, sukses-metrik jelas.

## 2. To-PRD — percakapan → dokumen

```python
from prd import to_prd
doc = to_prd(conversation_or_notes, title="Fitur Referral")
# → markdown PRD: Problem · Goals · Non-Goals · Users · Requirements (P0/P1/P2) · Success Metrics · Risks · Open Questions
print(doc.markdown)
```

PRD bagus = ringkas tapi lengkap: masalah dulu (bukan solusi), goals terukur, non-goals eksplisit, requirement diprioritas (P0 wajib / P1 / P2), metrik sukses, risiko. Export via file-artifact-production (DOCX/PDF) kalau perlu format.

## 3. To-Issues — PRD → task breakdown

```python
from prd import to_issues
issues = to_issues(doc)   # → list {title, body, labels, estimate, depends_on}
# push ke GitHub/Linear/Jira via protocol-binding-service-bridge (API) atau output markdown checklist
```

Tiap issue: judul actionable (verb), acceptance criteria, estimasi kasar, dependency. Cukup kecil buat dikerjain dalam 1 sesi (selaras executive-function-neurodivergent task-breakdown). Urutkan by dependency → handoff ke software-engineering-coding buat eksekusi.

## 4. TDD superpower

```
1. SPEC → tulis test dari requirement DULU (test = spec yang eksekutabel)
2. RED  → jalankan, harus gagal (bukti test beneran nguji)
3. GREEN→ tulis kode minimal sampai test hijau
4. REFACTOR → rapikan, test tetap hijau
```

Test dulu = desain API dari sisi pemakai + jaring regresi otomatis. Combo agentic-eval-self-critique (Eval) + software-engineering-coding (impl) + compliance-ci-cd-code-migration (CI gate). Untuk migrasi (compliance-ci-cd-code-migration) TDD = pengaman wajib.

## 5. Internal-Comms — komunikasi profesional

Konteks teknis → komunikasi yang jelas buat audiens non-teknis/stakeholder: status update, incident report, decision memo, RFC. Prinsip: BLUF (bottom line up front), jujur soal risiko, satu CTA jelas. Komplemen humanizer-brand-voice (tone) tapi format profesional/korporat.

---

## Catatan
- Alur lengkap: idea → Grill-Me → To-PRD → To-Issues → software-engineering-coding (build, TDD) → compliance-ci-cd-code-migration (CI/deploy).
- PRD/issues = artefak, gak ada gate. Push ke tracker eksternal via protocol-binding-service-bridge.
- Combo: product-spec-workflows + problem-shaping-decision-support (shaping) + software-engineering-coding (coding) + file-artifact-production (export doc) + protocol-binding-service-bridge (push issues).
