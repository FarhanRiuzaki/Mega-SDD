# Replay lapangan — extract PRD-kontrak vs baseline wave (kelas MTConvert)

Tanggal: 2026-08-26 · Spec: `docs/superpowers/specs/2026-08-26-extract-revamp-contract-design.md` §Urutan langkah 2 (replay + ukur) · Engine at `ae3c54d`.

## Setup

Legacy nyata: copy lokal MTConvert (project kantor yang memicu keluhan "lama +
generate yang ga perlu") — 1.270 file di direktori, isinya 1.225 log + 27 data
backup + tumpukan salinan manual; kode hidup 3 file PHP / 3.223 baris. Output
extraction ditulis ke scratchpad (konten tidak masuk repo). Pipeline dijalankan
persis seperti SKILL v2.0.0 memerintahkan: census → (1 module → tanpa
pertanyaan, tanpa subagent) → ekstraksi main-thread → synthesis → gate.

## Hasil terukur

| Metrik | Baseline wave (desain lama) | PRD-kontrak (run ini) |
|---|---|---|
| Subagent dispatch | 15 dispatch / 6 wave (fixed, berapapun ukuran) | **0** (xs = main thread) |
| Anggaran token dispatch terdokumentasi | ~535K | ~0 (tidak ada dispatch) |
| Waktu script census/prep | Wave 0 skeleton + enumerasi + builder statis | **0,13 dtk** (`derive-extract-census.sh`, 1.270 → 3 file) |
| Gate kelengkapan | Scorecard advisory (tanpa cek cakupan-file) | **PASS 0,05 dtk** — 3/3 file claimed + cited, 6 seksi, Mermaid tokenizer |
| Artefak output | Tree bernomor (≥15 file minimum by construction) | **3 file** (module PRD + README + data-mutation-policy) |
| Referensi grammar yang dimuat engine | 58,9 KB (wave-dispatch 32,6 + schema 26,3) | **16,8 KB** (prd-kontrak-template) — −71% |
| Spawn proses (relevan CrowdStrike kantor) | 15 dispatch + builder 2× + gate grep per wave | 3 invokasi script + grep gate per module |

Yang TIDAK berubah dan memang tak bisa dibanding lintas-desain: biaya model
membaca 3.223 baris kode legacy — inheren untuk grammar mana pun.

## Gate yang terbukti hidup di run ini

1. **Census exclusion by construction** — 1.225 log + `.bak`/`.TXT` tidak pernah masuk; `index - before log.php` (backup ber-ekstensi `.php`) MASUK census dan ditangani jujur: di-claim module, dibaca sebagai konteks, tercatat di §5 sebagai temuan duplikasi — tanpa heuristik deteksi-backup (ditolak spec sebagai gimmick).
2. **Secret-scan** ×3 file: 0 temuan — PRD menyitir lokasi kredensial (`index.php:13-25`) tanpa membawa nilainya. Sumber legacy sendiri memuat kredensial produksi hardcoded; gate inilah alasannya.
3. **kb-leak-scan advisory loop** — tangkapan pertama: 6 bocoran nama engine DB di prosa; diperbaiki ke vocabulary tech-agnostic → re-scan 0. Sitasi inline (`index.php:210`) TIDAK false-positive (exemption token sitasi bekerja).
4. **Census gate** menolak dulu (fixture uji), lalu PASS — unclaimed/uncited/missing-section/flow-non-Mermaid semua terbukti FAIL di suite (25+34 pin).

## Kualitas output (spot-check jujur)

PRD tunggal memuat: 9 business rules bersitasi (4 [LOCKED] — kontrak format
pesan + kunci join), flow Mermaid, 6 gotcha (temuan nyata: jalur kirim FTP
sudah mati ter-comment; die() tanpa rollback; tiga salinan logika yang bisa
drift), 3 OQ dengan prioritas (P1: keputusan bisnis nasib jalur FTP).
data-mutation-policy teremisi karena [LOCKED] ada — konsumen
build-dispatch-prompt membacanya di rumah baru (KB root) tanpa perubahan
kontrak heading.

## Verdict

Target spec tercapai pada kelas project yang memicu keluhan: **1 file kode →
1 PRD, nol wave, nol subagent, gate kelengkapan deterministik** — dan
kelengkapan justru NAIK dari baseline (baseline tidak pernah punya cek
cakupan-file terhadap enumerasi; sekarang itulah definisi "selesai").
Pembanding wall-clock kantor (CrowdStrike, ~220ms/spawn) menyusul di field run
user — prediksi terukur: pengurangan spawn dispatch 15→0 mendominasi.

## Catatan untuk field run kantor

- Jalankan `/mega-sdd <dir-legacy>` seperti biasa — front door me-rutekan ke extract-intelligence v2.0.0; butuh plugin ≥7.6.0.
- KB numbered-tree lama di project lain TETAP terbaca (dual-grammar di generate-intent/bind/analyze); tidak perlu re-extract kecuali mau grammar baru.
- Advisory `kb-leak-scan` kini baca stacks dari `census.json`.
