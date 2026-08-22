# A/B per-unit model routing — hasil pilot (klinik, bolts-lane)

**Status: PILOT SELESAI — kriteria ship TIDAK terpenuhi pada metrik terdefinisi; default TETAP `inherit`. Berhenti di gate.**
Kode v7.1.0 shipped (a)/(b)/(c) — CI hijau; A/B ini murni keputusan flip default.

## Desain eksekusi (deviasi dari rencana end-to-end, disclosed)

Scope dipersempit ke **bolts-lane** (3 unit × 2 arm): routing HANYA menyentuh dispatch implementer — fase intent/bind/units identik antar arm, menjalankannya dua kali menambah biaya tanpa sinyal. Playground disposable = vault klinik layout-2 (hasil migrate fixture) + 3 unit seeded dengan tier router berbeda; dispatch prompt dari `build-dispatch-prompt.sh` asli; implementer = subagent general-purpose dengan kontrak bolt ringkas (bukan agent plugin — fidelity pilot, disclosed). **Arm A** = tanpa param model (inherit → sesi ini = Fable 5, frame "sesi operator model kuat"). **Arm B** = param model dari `resolve-review-tier.sh` (U-101 verify→haiku, U-102 standard→sonnet, U-103 auth/full→opus). Token = `subagent_tokens` yang dilaporkan harness (terukur, bukan estimasi).

## Hasil

| Unit (router B) | Arm A: inherit=Fable | Arm B: routed | Δ token B vs A |
|---|---|---|---|
| U-101 verify → **haiku** | 49.627 tok · 4 tools · 54 dtk | 37.654 · 5 · 34 dtk | **−24%** |
| U-102 standard → **sonnet** | 54.727 · 10 · 103 dtk | 65.382 · 13 · 125 dtk | **+19%** |
| U-103 auth/full → **opus** | 55.338 · 10 · 124 dtk | 75.428 · 21 · 373 dtk | **+36%** |
| **Total** | **159.692** | **178.464** | **+11,8% (LEBIH BOROS)** |

**Kualitas:** 6/6 acceptance PASS (re-run independen oleh controller), 0 pelanggaran whitelist, semua commit mendarat. Satu delta kualitas: arm A (Fable) **menangkap inkonsistensi spec di seed gue sendiri** (title unit menyebut "specialty", grep acceptance mengecek "role") dan mencatatnya sebagai `acceptance_test_concern`; arm B (haiku) lolos tanpa menandai. **Cascade: 0 trigger** (tidak ada kegagalan) — nol data eskalasi.

**Probe presedens (pertanyaan desain §0c) — TERJAWAB:** `model_used` verbatim dari system prompt tiap implementer arm B = "Claude Haiku 4.5", "Sonnet 5", "Opus 5 (1M context)" — **param `model` runtime menang dan bekerja untuk ketiga alias**; varian agent file tidak dibutuhkan di build ini. Catatan sisa: pilot memakai general-purpose (tanpa pin frontmatter model) — interaksi param vs frontmatter `model:` pada CUSTOM agent (bolt-implementer `inherit`) masih butuh satu probe di sesi dengan plugin terpasang.

## Verdict terhadap kriteria ship

- **"Hemat token ≥25%" — GAGAL** pada metrik sebagaimana didefinisikan (raw token): arm B +11,8%. Model lebih murah ≠ token lebih sedikit — sonnet/opus butuh LEBIH BANYAK iterasi tool daripada Fable untuk tugas yang sama (13 vs 10; 21 vs 10), dan opus 3× lebih lambat wall-time.
- **"Kualitas panel setara" — SETARA di acceptance (6/6)**, dengan satu edge ke arm A (spec-concern yang tertangkap). n terlalu kecil untuk klaim kualitas kuat.
- **Temuan metodologis yang penting untuk gate:** metrik "token total" salah proxy ketika model beda HARGA. Yang relevan untuk kantor adalah **biaya berbobot harga** ($/MTok per model di gateway) — haiku/sonnet per-token jauh lebih murah, jadi +11,8% token bisa tetap = penghematan biaya besar. Gue TIDAK menghitung angka biaya di sini karena harga per model di gateway kantor bukan fakta yang gue pegang — mengarangnya = fabrikasi.

## Rekomendasi (keputusan lo di gate)

1. **Default tetap `inherit`** (sudah shipped begitu) — tidak ada dasar flip.
2. Kalau routing tetap menarik: definisikan ulang kriteria ship dalam **biaya berbobot harga gateway** + jalankan A/B skala lebih besar (n≥10 unit, sesi operator sonnet/opus sebagai baseline arm A yang representatif kantor, agent plugin asli) — runbook probe sudah di `model-tiers.md §v7.1 office rollout`.
3. Data pilot menyarankan varian selektif yang murah: **haiku-untuk-verify saja** (satu-satunya sel yang hemat token MENTAH −24%) — bisa diuji terpisah tanpa cascade.

Batas pilot: n=3, satu run per sel (tanpa varians), baseline Fable (bukan sesi kantor tipikal), implementer non-plugin-agent, cascade tak teruji. Semua angka = terukur dari harness, bukan estimasi.
