# Amandemen (final, menggantikan `2026-08-22-v7-amend-no-telemetry.md`): observability DIHAPUS TOTAL

Keputusan: **mega-sdd = pipeline development saja** — PRD/idea → intent → vault → bind → units → bolts → review → test script / e2e (SIT/UAT + Playwright) → dokumen (PRD/FSD/SIT/UAT/AGENTS.md). Semua yang bersifat observability dihapus seluruhnya, bukan dikurus. Tidak ada pengecualian "kontrak gateway" — observability bukan tugas plugin ini.

## Hapus seluruhnya (bukan scope, bukan debounce — HAPUS)

- Telemetry: `telemetry.jsonl` + writer di semua hook + rotasi, `telemetry-schema.md`, `--no-telemetry`, `defaults.telemetry`, semua marker (`turn_end_marker`, `subagent_end_marker`, `skill_invoked`, `ref_loaded`, `halt_self_resolved`, dsb.), `.turn-usage-cursor-*`, `hook-debug.log`.
- Cost/usage: `report-token-cost.sh`, leg token-cost `run-analyze.sh`, `TOKEN-COST-REPORT.md`, semua flag/config terkait cost, benchmark/harness "token cost" yang bukan tracer context (tracer context-size untuk Fase 4 BOLEH tetap — itu alat rekayasa plugin, bukan observability runtime; taruh di `benchmarks/`, tidak pernah jalan saat dev pakai plugin).
- Advisor runtime: compaction advisor / context-% advisor di UserPromptSubmit, `.compaction-snapshot.json` + PreCompact hook kalau hanya untuk itu, staleness/usage notice yang bukan pipeline state.
- Trace tag `mega-sdd-trace:*` (turn, session, skill, subagent) — HAPUS, termasuk echo di UserPromptSubmit, kewajiban di announce line, dan di dispatch prompt. Deteksi governance v6.19.2 ("mega-code sessions MUST run mega-sdd") yang bergantung pada tag ini: hapus kontraknya dari plugin; kalau tim gateway masih butuh sinyal, itu dikerjakan di sisi gateway, bukan di plugin.
- `SubagentStop` hook kalau sisanya hanya telemetry → hapus event-nya dari `hooks.json`.
- Config `trace_tag`, `compaction_notice`, `staleness_notice`, `dirty_journal` kalau konsumennya ikut hilang. Dirty journal **tetap** hanya kalau masih dipakai `sync` untuk changed-set (itu pipeline); kalau tidak, hapus.
- Memory side lane (`memory/` skill + `memory-write.sh`, `instincts`, "learning suggestions") — ini observability-adjacent (belajar dari run). **Hapus** kecuali ada konsumen pipeline yang nyata; laporkan mana.
- Docs/README/CHANGELOG/CLAUDE.md: semua bagian observability dihapus, bukan diberi catatan "deprecated".

## Yang TETAP (pipeline)

- Semua gate anti-halu dan evidence artifacts-nya (preflight/postflight/acceptance/batch-suite/uat result.json).
- Bolt-report (`model_used`, `escalated_from`, `signals_fired`) — audit per unit, bagian dari artefak bolt.
- `publish-artifacts.sh` (publikasi dokumen ke gateway kantor) — itu output pipeline, bukan observability. Tetap, tapi cek tidak membawa payload telemetry.
- Front door status view (posisi pipeline, vault, OQ, binding) — itu state pipeline.
- Tracer context-size di `benchmarks/` untuk Fase 4 (alat maintainer, tidak dieksekusi saat pakai).

## Uji pisau (final)

"Kalau ini hilang, apakah ada gate anti-halu yang bolong, atau artefak dev (vault/unit/bolt/test script/e2e/dokumen) yang tidak bisa dibuat?" Tidak → hapus. Tidak ada kategori "kontrak pihak lain" yang mengecualikan.

## Eksekusi

Urutan: **selesaikan R4 dulu sampai commit + angka T10** (bedah yang sedang berjalan jangan diinterupsi), baru seri commit ini, SEBELUM R2. Isi seri: audit uji pisau → daftar hapus + alasan satu baris → hapus → zero-phantom grep (kedua test tree, hooks.json, CLAUDE.md, README, references) → test hijau → tracer T01/T07/T10 diulang sebagai baseline Fase 4 yang baru → bump 7.2.0 (breaking: observability removed). Laporkan before/after (file, baris, hook event yang tersisa, spawn session-start/tier-S), lalu lanjut R4.
