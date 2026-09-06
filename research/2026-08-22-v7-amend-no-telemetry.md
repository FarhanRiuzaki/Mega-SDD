# Amandemen keputusan: mega-sdd TIDAK membangun telemetry/monitoring apa pun — itu domain AI gateway

Prinsip baru, berlaku mundur ke semua keputusan sebelumnya: **mega-sdd hanya berisi hal yang langsung membantu dev menyusun PRD → vault → units → bolts → dokumen.** Monitoring token, biaya, telemetry, cost report — semua sudah ditangani AI gateway kantor. Plugin tidak boleh menduplikasinya.

## Yang dicabut dari keputusan gue sebelumnya

1. **`--price-table` / kolom `model_used` di `report-token-cost.sh`** (gate-5) — DIBATALKAN. Jangan dibangun.
2. **Tier B "token-cost KEEP kurus"** (gate-0) — DIBALIK menjadi **HAPUS**: `report-token-cost.sh`, leg token-cost di `run-analyze.sh`, `TOKEN-COST-REPORT.md`, marker hook yang hanya melayani itu (`turn_end_marker`, `subagent_end_marker`, `ref_loaded`, `.turn-usage-cursor-*`), `telemetry.jsonl` + rotasinya, `telemetry-schema.md`, `--no-telemetry` flag dan `defaults.telemetry` config, `.compaction-snapshot` kalau hanya telemetry, `hook-debug.log`. Sweep kedua test tree; test yang hanya menguji telemetry ikut dihapus.
3. **Pilot lapangan routing** (gate-5) — tetap, tapi datanya dari **AI gateway** (model, token, biaya per request sudah ada di sana, difilter via trace tag), bukan dari telemetry plugin. Tidak ada kode baru di jalur A.

## Yang TETAP, karena ini kontrak gateway atau bukti dev, bukan monitoring

- Tag `mega-sdd-trace:<skill>` / `mega-sdd-trace:turn` — itu cara gateway memfilter sesi mega-sdd; kontrak milik gateway, pertahankan persis.
- `model_used` / `escalated_from` di **bolt-report** — audit trail keputusan routing per unit (bukti dev, satu baris), bukan telemetry. Tetap.
- `signals_fired` di bolt-report — sama, audit trail panel tier.
- Evidence artifacts anti-halu (preflight/postflight/acceptance/batch-suite/uat result.json) — bukan telemetry, jangan disentuh.

## Uji pisau untuk kasus abu-abu (pakai ini, jangan tanya gue lagi)

"Kalau file/script/marker ini hilang, apakah ada **gate anti-halu** yang bolong, atau ada **artefak dev** (vault/unit/bolt/dokumen) yang tidak bisa dibuat?" Tidak dua-duanya → hapus. Observability, cost, usage, dashboard, compaction advisor, context-% advisor → hapus; gateway yang punya.

## Eksekusi

Satu seri commit terpisah SEBELUM R4 (supaya R4 mengukur lane yang sudah bersih): audit cepat dengan uji pisau di atas → daftar hapus dengan alasan satu baris → hapus → zero-phantom grep → test kedua tree hijau → tracer T10/T01/T07 diulang (angka baseline Fase 4 diperbarui kalau berubah). Laporkan before/after, lalu lanjut R4.
