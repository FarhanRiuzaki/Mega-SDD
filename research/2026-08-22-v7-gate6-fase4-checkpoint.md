# Keputusan checkpoint Fase 4 (R4 + R2a): tutup prose-diet, ganti lever

Berhenti di R2a itu keputusan yang benar — dua titik data searah (R4 = 70% batas bawah estimasi, R2a = 12%) cukup untuk bilang metode estimasi per-section tidak bisa dipakai untuk target agregat. Terima kasih sudah tidak memaksa R2b–R3.

## Keputusan: opsi (ii) + (iii), bukan (i)

1. **Fase 4 prose-diet DITUTUP** di R4 + R2a (−5k terukur). R2b–R2e, R1, R3 **dibatalkan** sebagai program. Satu pengecualian kecil boleh ikut di commit lain kalau gratis: chain-execution diagnostics keluar dari spine express (itu dead content yang ikut termuat — bukan estimasi, fakta "SKIPPED on express").
2. **Lever berikutnya = hapus permukaan + script-ification**, sesuai bukti lo sendiri: emit-fsd 4,1k = lane terbersih karena hampir seluruh kerjanya script; pemotongan besar Fase 0–3 juga datang dari menghapus, bukan memangkas prose.

## Urutan sekarang

1. **Amandemen observability (7.2.0)** — sedang lo jalankan. Catatan: `--price-table`/`--vault` di `report-token-cost.sh` (0b2a252) ikut terhapus bersama script-nya; tidak apa-apa, kerjanya tidak sia-sia karena menjawab pertanyaan metodologi, tapi rumahnya bukan plugin.
3. **Fase 5 pipeline-only** (`research/2026-08-22-v7-fase5-pipeline-only.md`) — audit + gate, lalu hapus per permukaan.
4. **Fase 6 script-ification ("spec 0-token")** — audit read-only, gate sebelum eksekusi:
   - Cari setiap section markdown yang **sudah diimplementasikan script** (kelas `review-panel.md §Tier selection` ↔ `resolve-review-tier.sh`; `context-enrichment.md`; tabel exit-code Mode D ↔ `sync-intersect.sh`; Mermaid rules ↔ `mermaid_syntax.py`). Untuk tiap pasangan: script = kebenaran, prose dipangkas jadi **satu paragraf "jalankan X, baca output Y"** + pointer ke script. Prose yang menjelaskan ulang algoritma script dihapus.
   - Cari langkah skill yang model lakukan manual padahal deterministik (assembly, lookup, parity, enumerasi) → pindah ke script yang **sudah ada** (flag/mode baru), bukan script baru. Netto script tidak naik.
   - Ukur per item dengan tracer yang sama; revert kalau tidak turun.
   - Laporkan daftar kandidat + perkiraan per item **berdasarkan byte section yang memang di-load di lane default** (bukan ukuran file), supaya tidak mengulang inflasi estimasi Fase 4.

## Target yang direvisi (jujur)

Pipeline 1-unit: 182k → **≤140k** dari gabungan Fase 5 (hapus permukaan yang masih termuat di lane default, mis. scan classic/advisor/memory) + Fase 6. Kalau setelah Fase 5 tracer menunjukkan lane default sudah tidak memuat permukaan yang dihapus (karena memang tidak pernah di-load), angkanya tidak akan turun banyak dari sana — itu tetap kemenangan untuk spawn/ukuran plugin, dan target token dikejar lewat Fase 6. Jangan paksa angka.

## Kecil

- Timing flake certify-artifact (2769 ms > 2000 ms di bawah load): jangan longgarkan threshold diam-diam; jadikan assertion timing itu non-blocking saat `CI=1` + catat, atau ukur standalone saja. Bukan prioritas.
- Leg scm: gue push dari VPN.
