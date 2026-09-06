# Audit dokumentasi — docs harus 1:1 dengan v7.5.0

Setelah v7.0.0→7.5.0 (routing S/M/L, vault 4-file, observability hilang, surface 3+3 command, hooks 6 event dispatch langsung, spawn diet) hampir pasti banyak dokumen yang masih menceritakan plugin yang sudah tidak ada. Tugas: audit SEMUA permukaan dokumentasi terhadap kode di HEAD, perbaiki sampai 1:1, dengan metode klaim-per-klaim — bukan baca-rapikan.

## Metode (per file)

1. **Ekstrak klaim yang bisa diverifikasi**: nama command/flag/skill/agent/hook/file/path, angka (jumlah skill, event, file vault, spawn), perilaku ("X auto-jalan saat Y"), contoh output/snippet.
2. **Verifikasi tiap klaim terhadap kode** (grep/ls/eksekusi bila murah): command ada? flag dikenali? file ada di path itu? angka benar? snippet masih valid?
3. **Perbaiki**: klaim salah → tulis ulang sesuai kenyataan; fitur yang dihapus → hilangkan (bukan strikethrough); fitur baru v7 yang belum terdokumentasi (S/M/L default S, `--weight`, vault 4-file + `[origin:]`, `chain_engaged`, auto-aware notice, census "selesai", `auto_verify_on_edit`, cascade `model_tiers: auto`, `parallel_max`, gateway-contract) → pastikan punya rumah di dok yang tepat.
4. Laporkan per file: jumlah klaim dicek / salah / diperbaiki.

## Permukaan yang diaudit (urutan prioritas)

| Permukaan | Perhatian khusus |
|---|---|
| Root `README.md` | Quick start, tabel command (3 verb + 3 one-timer — bukan 8), pipeline diagram, bare-verb wrapper |
| `plugins/mega-sdd/README.md` | Tabel command, "What's in this folder" (skills 21? agents 8? hooks 6 event), defense-in-depth 8 lapis masih akurat?, bagian yang masih menyebut memory/telemetry/advisor/slice/vendored/tree-sitter |
| `plugins/mega-sdd/CLAUDE.md` + root `CLAUDE.md` | Kontrak & invariant kontributor — ini yang dibaca sesi AI berikutnya; paling berbahaya kalau drift |
| `tests/scenarios/` (13 walkthrough) | Ini muka untuk dev baru kantor. Tiap scenario: command yang diketik masih ada? output yang dijanjikan masih berbentuk itu (vault 4-file!)? Scenario yang memakai fitur terhapus (memory review, slice, advisor) → tulis ulang atau hapus dari chooser table. Minimal satu scenario (greenfield klinik) di-REPLAY beneran, bukan hanya dibaca |
| `references/*.md` yang dibaca saat run | paths.md (layout 4-file), halt-protocol/halt-families (halt yang sudah tidak ada?), reading-map, project-config (key config yang masih hidup saja), model-tiers (row-22 amendment, cascade), output-language, upgrade-from-old-version (+§7.x), gateway-contract |
| `docs/mega-sdd/*` | Dok yang dipindah Fase 5 — pointer dari plugin masih benar? |
| `.claude-plugin/plugin.json` description + marketplace.json | Sudah dibetulkan di Fase 5 — cek ulang saja |

## Yang TIDAK diubah

- `research/` dan `docs/superpowers/specs/` yang berstempel tanggal = **rekaman sejarah**, bukan dokumentasi hidup. Jangan ditulis ulang. Kalau sebuah spec menggambarkan perilaku yang sudah berubah, cukup satu baris stempel di atasnya: `> Superseded by vX.Y — lihat <dok hidup>` — hanya bila ada risiko dibaca sebagai kebenaran saat ini.
- CHANGELOG = append-only.

## Rambu

- Sumber kebenaran = kode di HEAD, bukan ingatan dan bukan dok lain (dok yang saling mengutip bisa sama-sama salah).
- Docs-only push → CI path filter jalan; tapi kalau replay scenario menemukan BUG kode (bukan dok), berhenti dan lapor — jangan perbaiki kode di seri dok.
- Satu commit per permukaan (README root, README plugin, CLAUDE.md, scenarios, references, docs/) supaya bisa direview terpisah.
- Penutup: laporan `research/<tanggal>-doc-audit.md` — tabel file × klaim-dicek × salah × diperbaiki + daftar temuan bug kode (kalau ada) untuk gate berikutnya. Bump TIDAK perlu (docs-only), kecuali plugin.json description berubah → patch version.
