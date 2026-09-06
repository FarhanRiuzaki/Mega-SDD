# Jawaban 4 pertanyaan terbuka Fase 5 → eksekusi di sesi segar

v7.3.1 diterima (user-prompt-submit pure-shell nol spawn + S9b hening di CWD non-SDD = persis bentuk minimal yang gue mau; keputusan mengecilkan kalimat anchor daripada menaikkan cap juga benar). Tabel penempatan diterima; dua bukti pembalik (shared-snapshot-schema dibaca saat run; codebase-map dibaca intent Mode A) diterima sebagai fakta.

## Jawaban

| № | Pertanyaan | Keputusan |
|---|---|---|
| 2 | `slice-design` → extras sekarang atau hapus | **HAPUS.** `mega-sdd-extras` dibuat nanti hanya kalau ada pemakai nyata yang minta; jangan bangun plugin kedua untuk fitur tanpa pemakai. |
| 3 | Design-Source OQ tetap fitur? | **YA, tetap.** Itu rail anti-halu untuk unit UI (sumber desain tidak ada → OQ, bukan tebakan), dan `design_system` di vault dikonsumsi design lens. Nasib `product-style-map.yaml` (dan file design-intelligence lain) ditentukan **hanya** oleh grep konsumen: dibaca `design-reviewer` / generate-intent saat run → tetap; tidak → hapus. Default hapus. |
| 4 | Starterkit-first Mode A hidup/mati | **HIDUP** — ini mandat gue yang masih berlaku ("starterkit itu wajib ada; jika tidak ada baru greenfield"). Konsekuensi untuk bedah scan: pertahankan **subset minimum** codebase-map yang dibaca intent Mode A (`--scan=`) + pack-detection bind + reuse-index/symbol-index producer. Lane klasik di luar subset itu (engine ladder tree-sitter, deep-scan cache, probe-scan-engine, emisi section map yang tidak dibaca siapa pun) dihapus. Kalau setelah grep ternyata subset ≈ seluruh scan, **berhenti dan lapor**, jangan bedah paksa — keep utuh lebih baik daripada shim. |
| 14 | Kalkulator price-table di `benchmarks/` | **TIDAK.** Biaya = gateway. Hapus; catatan metodologinya cukup hidup di `research/2026-08-22-model-routing-ab-results.md`. |

## Eksekusi (sesi segar, satu commit per permukaan, bisectable)

Urutan sesuai kaki tabel lo. Per commit: suite penuh kedua tree + CI; zero-phantom grep; skill-triggering hijau; 7 rail lindung utuh. Tutup dengan tracer ulang (baseline 7.3.x), bump **7.4.0**, laporan before/after (skills/commands/scripts/hooks/baris + T01/T07/T10 + spawn tier-S). Lalu berhenti di gate Fase 6 (audit script-ification, read-only).

Leg scm: gue push dari VPN.
