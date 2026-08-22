# v7 Fase 4 — checkpoint R4 + R2a (BERHENTI: bukti membalik estimasi scoping)

**Status: R5 + R4 + R2a SHIPPED (CI hijau, tracer terukur per R). R2b–R2e / R1 / R3 SENGAJA TIDAK dilanjutkan — bukti implementasi membalik asumsi target agregat; keputusan re-scope = user (rambu standing "bukti baru yang membalik keputusan → berhenti dan laporkan").**

## Angka (tracer statis yang sama, `benchmarks/results/optimized/context-v7-pre-fase4.json` sebagai before)

| R | Objek | Before | After | Δ terukur | Estimasi scoping | Rasio |
|---|---|---:|---:|---:|---:|---|
| R5 | trace T01/T07 re-derivasi + lane T10 baru | — | baseline terekam | (prasyarat angka) | — | — |
| R4 | execute-bolts loading contract (T10 bolts-per-unit) | 50.397 | **46.573** | **−3.951 (−7,8%)** | −5–8k | ~70% dari batas bawah |
| R2a | vault-contract split (T01 intent) | 113.394* | **112.210** | **−1.057 (−0,9%)** | −8–10k | **~12% dari estimasi** |

\* T01 pasca-R4, dikoreksi +127 tok noise dokumentasi jalur-A (baris runbook model-tiers). T07 −1.079 serupa. Semua angka = chars÷4 tracer statis, 0 missing path.

## Apa yang dikerjakan

- **A-path (tugas kecil yang diizinkan):** `report-token-cost.sh --price-table=<yaml>` (biaya berbobot harga gateway; token tanpa harga DIHITUNG dan DIBERI FLAG lower-bound, tidak pernah diestimasi) + `--vault=` (tabel per-bolt `model_used`/`escalated_from`). Runbook step 4. Menunggu tabel harga gateway dari user.
- **R4:** `batch-and-fanout.md` jadi KONDISIONAL (multi-unit saja); drift-check per-bolt + detail B2 pindah verbatim ke `halts-and-handoff.md` (owner tunggal, batch ref = pointer tanpa kopi). SKILL 47,0→41,4 KB via pointer+ringkasan ke owner yang sudah memuat kontennya (hard-rule-scan/halts-and-handoff/context-enrichment); §Specialist references = kontrak load eksplisit termasuk lane `verify` (tanpa code-gates/hard-rule-scan/batch). Rail utuh; pin `OVERWRITES the artifact` dipertahankan di SKILL (s7a).
- **R2a:** `vault-contract.md` dibelah di GARIS LOAD: `vault-core.md` = kontrak lane default (schema/OQ/constitution/boilerplate/id-stability); `vault-contract.md` = overlay kondisional (Starterkit-binding `--scan` + Multi-scope). ~30 situs referrer di-re-key; test repin ke path owner baru; sweep 6d/3d DIPERLUAS mencakup vault-core.

## Bukti yang membalik (kenapa berhenti di sini)

1. **Estimasi scoping sistematis terlalu tinggi.** Dua titik data searah: R4 mendarat ~70% dari batas bawah estimasi; R2a mendarat ~12% dari estimasinya. Penyebab kelasnya sama: audit read-only menghitung byte per-section, tapi **konten operatif lane ternyata jauh lebih besar dari dugaan** — contoh konkret R2a: "Step 3 tidak butuh 4 dari 7 section" benar untuk Step 3, tapi lane yang sama menulis `constitution.md` di Step 3.4, jadi lane default tetap butuh ~85% file. Kelas kesalahan: **estimasi per-section ≠ estimasi per-lane**.
2. **Target agregat 182k→≤135k (−25%) kemungkinan besar TIDAK tercapai lewat sisa R.** Butuh ~47k pemotongan; R4+R2a menghasilkan ~5k. Sisa item (review-panel dispatcher-core, chain-execution diagnostics, generation-guide sectioning, binding-contract express-half, R1 dedup ~17KB, R3 tabel ~17KB) memakai metode estimasi yang sama yang baru saja terbukti inflasi 1,4–8×. Proyeksi jujur sisa item: ~8–15k tambahan, bukan ~40k.
3. **Aturan per-R tetap terpenuhi** (setiap R terukur turun; tidak ada revert). Yang berubah bukan "apakah R bekerja" tapi "apakah target fase realistis" — itu keputusan gate user, bukan keputusan implementasi.

## Opsi untuk gate (keputusan lo)

- **(i) Lanjut R2b–R3 dengan target direvisi** (mis. agregat −8–10% realistis; tiap R tetap wajib terukur turun). Item bernilai tertinggi berikutnya menurut inspeksi langsung (bukan estimasi audit): review-panel §risk-signals+capture-ladder → ref kondisional (~−1,5k bolts), chain-execution diagnostics keluar spine (~−1–2k sync).
- **(ii) Tutup Fase 4 sekarang** dengan R5+R4+R2a sebagai hasil (~−5k/pipeline + kontrak load eksplisit + pengukuran jujur), sisa item masuk backlog berlabel "estimasi terbukti inflasi".
- **(iii) Ganti kelas lever:** bukti 3 fase terakhir menunjukkan pemotongan besar datang dari **script-ification** (emit-fsd 4,1k = lane terbersih) bukan dari restrukturisasi md — kandidat: porsi §Tier selection yang sudah diimplementasi `resolve-review-tier.sh` diperlakukan seperti `context-enrichment.md` (spec 0-token).

Semua commit hari ini CI hijau; suite penuh dua tree per commit. Leg scm menunggu push user via VPN.
