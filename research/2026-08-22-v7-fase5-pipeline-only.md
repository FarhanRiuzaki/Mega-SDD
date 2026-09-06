# Fase 5 — "pipeline only": potong semua yang bukan langkah pipeline

Pipeline yang dipertahankan, dan hanya ini:

```
PRD / idea / legacy dir
  → generate-intent / extract-intelligence   (vault, KB)
  → bind-codebase (express)                   (binding, CONFLICT gate)
  → generate-units                            (units)
  → execute-bolts + review panel              (kode + acceptance test + L0 gates)
  → emit sit / uat (+ Playwright e2e) / prd / fsd / agents-md  (dokumen + test script)
  → sync / diff-vault / detect-drift / resolve-oq             (loop hidup: kode berubah, PRD berubah, OQ)
```

Uji pisau v2: **"Apakah ini langkah di rantai di atas, gate anti-halu untuk langkah itu, atau prasyarat langsungnya (pack framework, parser, template)?"** Tidak → potong. Kategori "nice to have", "fallback", "standalone", "maintenance kenyamanan", "belajar dari run" tidak lolos.

## Urutan

Setelah R4 commit dan setelah amandemen observability (7.2.0) mendarat, SEBELUM R2 — karena sebagian reference yang R2/R1/R3 mau pangkas mungkin hilang seluruhnya di sini (jangan diet file yang akan dihapus).

## Kandidat — verdict awal gue, lo verifikasi dengan grep konsumen (bukan asumsi)

| Permukaan | Ukuran | Verdict gue | Alasan / syarat |
|---|---|---|---|
| `skills/memory` + `commands/memory.md` + `memory-write.sh` + instincts | 57 KB + script | **HAPUS** | learning-from-runs = observability-adjacent; bukan langkah pipeline |
| `skills/_vendored` (superpowers fallback: executing-plans, subagent-driven-dev, TDD, worktrees) + `sync-vendored.sh` | 49 KB | **HAPUS** | fallback teknik; execute-bolts sudah punya agent + panel sendiri. Kalau ada instruksi yang masih merujuk ke vendored, inline-kan yang benar-benar dipakai (maks beberapa baris), bukan pertahankan folder |
| `skills/slice-design` + `commands/slice.md` | 6 KB + refs | **HAPUS** | standalone UI slicing "works without a vault, never writes vault" — by definition bukan pipeline |
| `references/design-intelligence` | 164 KB | **PANGKAS ke yang dipakai design-reviewer lens** | konsumen yang sah hanya lens design di panel bolts. Sisanya (product-style-map, typography pairings, palette) hapus kalau tidak dibaca lens. Kalau lens hanya butuh `modern-baseline` + `ux-rules`, sisanya pergi |
| `skills/scan-codebase` (classic lane) | 184 KB | **HAPUS lane klasik; pertahankan hanya producer `reuse-index.yaml` + symbol index** | express adalah spine default dan "needs no map". Codebase-map emission, engine ladder tree-sitter, deep-scan cache, `probe-scan-engine.sh`, `derive-codebase-map.sh`, `validate-codebase-map.sh` ikut pergi kalau express tidak membacanya. Kalau ada konsumen express yang ternyata baca map → laporkan, jangan shim |
| `skills/install-deps` + `detect-os.sh`, `probe-tool.sh`, `fix-windows-path.sh` + `_lib/windows_path.py` + `references/tooling-install.md` | 42 KB + ±600 L | **PANGKAS** | prasyarat pipeline (ast-grep, playwright) sah, tapi bentuknya harus minimal: satu command yang menjalankan install per OS + verifikasi. PATH-repair Windows: pertahankan hanya kalau terbukti dipakai fleet kantor (lo tahu jawabannya) |
| `commands/update-plugin.md`, `commands/migrate-paths.md` | kecil | **KEEP sementara** | migrate-paths wajib selama dual-layout satu minor cycle; update-plugin = ops plugin, kecil. Review ulang saat fallback layout-1 dicabut |
| `references/fork-a-recovery-map.md`, `upgrade-from-old-version.md`, `reading-map.md`, `shared-snapshot-schema.md` | ±45 KB | **PINDAH ke `docs/`** atau hapus | dokumen maintainer/migrasi, bukan reference yang dibaca skill saat run. Kalau tidak ada skill yang me-Read, keluar dari `references/` |
| `references/starterkit-context-schema.md` | 21 KB | KEEP (keputusan Fase 2, konsumen hidup) | — |
| `references/lib-patterns` (django/laravel) | 25 KB | KEEP **jika** scan extractors tetap; ikut nasib scan-codebase | — |
| `skills/graph`, `skills/analyze` | kecil | KEEP | graph = source knowledge untuk sync/bind; analyze = consistency report pipeline. Tapi analyze: hapus rung yang hanya observability (sudah di amandemen) |
| `publish-artifacts.sh` | 297 L | KEEP | output dokumen ke gateway kantor = langkah emit |
| `skills/emit-*`, `build-uat-xlsx.sh`, `md2pdf.sh`, `capture-views.sh` | — | KEEP | deliverable dokumen/test script/e2e + render check |
| `agents/phase-advisor.md` + `build-advisor-bundle.sh` + flag `--advisor` | — | **HAPUS** | opt-in, satu konteks opus tambahan per gate, dan gate bind/OQ sudah deterministik. Kalau suatu hari dibutuhkan, itu fitur baru dengan gate sendiri |

## Prinsip "efisien & tidak berat" — ini yang diukur, bukan jumlah file

1. **Yang dimuat per lane** (markdown SKILL + references yang di-Read) — tracer T01/T07/T10. Setiap permukaan yang dihapus harus terlihat di angka ini atau di daftar file-yang-tidak-lagi-di-load.
2. **Spawn per tool call dan per session-start** — tier S tetap 0 fork; session-start ≤ 8 fork; chain armed: hapus validator PostToolUse yang hanya early-warning (aggregator PreToolUse sudah recompute at gate — temuan audit Fase 0 #2). Kalau sebuah validator tidak dibaca gate mana pun dan tidak menulis artefak, dia pergi.
3. **Konteks subagent** — panel review tier `minimal`/`standard` harus jadi default nyata; `full` hanya saat sinyal risiko. Lens prompt hanya membawa slice yang dipakai (sudah ada; verifikasi tidak regresi).
4. **Jumlah halt/konfirmasi per chain** — setiap AskUserQuestion yang bukan keputusan bisnis (OQ business, CONFLICT) dipertanyakan; kalau jawabannya selalu sama, jadikan default.
5. Target setelah Fase 4 + Fase 5: pipeline 1-unit ≤ 120k token (dari 182k), sesi bug-fix tier S = 0 overhead, chain sync tanpa pertanyaan selain CONFLICT.

## Aturan eksekusi

- Hasil audit = satu tabel: permukaan, konsumen nyata (grep, bukan prose), verdict, blast radius. Berhenti di gate; gue putuskan item "TANYA".
- Hapus = hapus utuh (skill, command, script, references, tests, baris README/CHANGELOG/CLAUDE.md); zero-phantom grep kedua tree.
- Tidak boleh memecah gate anti-halu; skill-triggering tests hijau; tracer T01/T07/T10 diulang sesudahnya (baseline Fase 4 diperbarui).
- Bump 7.3.0 (breaking: surface removed). Satu commit per permukaan supaya bisa di-bisect.
