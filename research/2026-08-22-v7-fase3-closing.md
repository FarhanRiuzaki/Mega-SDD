# v7 Fase 3 — catatan penutup (vault layout-2)

**Status: SHIPPED — 6 commit, semua CI GitHub hijau; №3 DITUTUP (dibatalkan, keputusan user); leg scm menyusul via VPN kantor (user).**
Gate: [gate2-close](2026-08-21-v7-gate2-close.md) (contoh disetujui + 4 tambahan + urutan (a)–(e) + rambu). Contoh: [fase3-vault-example](2026-08-22-v7-fase3-vault-example.md).

## Commit + CI

| Commit | Isi | CI |
|---|---|---|
| (a) | parser + dual-layout read: `vault_layout()` marker-gated, lock frontmatter-first (L4: frontmatter legacy TIDAK bocor), grammar `[origin: file#anchor]` → vault.json (`DERIVED_OQ`), locator dual-probe vault-oqs + flow-coverage; fixture v2 + 15 arm | 32567808879 ✅ |
| (b) | re-key konsumen SATU commit: deriver (identitas vault.md\|00-index, OQ terpusat fail-loud, `vault_layout: 2` derived), **hard-header contract exit 2 menyebut header** di deriver + ledger (DOC_CODE filename→section, atribusi per-baris, id-set parity), run-analyze, hook `*/flows.md`, validate-kb, vault-oqs corpora, certify, 4 builder emisi via `resolve_doc` + sitasi basename resolved; 15→28 arm | 32568890427 ✅ |
| (c) | `migrate-paths --vault-layout` (DRY-RUN DEFAULT, `--apply`): relokasi verbatim, lock → frontmatter, OQ terpusat + origin stamp per-source-doc, residu pindah UTUH, ceremony DROPPED+DINAMAI, unit doc-name rewrite (line anchor TIDAK disentuh), derive, pesan WAJIB full re-bind, dirty refusal, idempoten; fixture klinik + 16 arm m1–m9 (derive parity before==after) | 32569600610 ✅ |
| (d) | generation layout-2 default: 4 template baru (hard anchors, constraints.md bracket wajib + [origin:]), 7 template lama dihapus (relokasi — anti-halu generik HANYA di ai-consumer-guide, p2a repinned); generation-guide/vault-contract/SKILL; prose re-key **~250 situs / ~50 file** (canonical layout-2 + legacy diparentesiskan di titik routing) | 32571035195 ✅ |
| (e) | paths.md §Vault layout (tabel mapping + resep migrasi + kontrak hard-header), upgrade-to-7.0.0, README | 32571527423 ✅ |
| (b-fix) | konsumen PATTERN-scoped yang lolos grep literal: make-bound (copy set `0[0-6]-*` + SRC_RE), state_probes (`_vault_docs()` — klaim audit "filename-agnostic" hanya benar untuk probe vault.json), run-analyze files.vault_oqs, build-locked-index, vault-flow-staging; + bukti penutup | 32572215175 ✅ |

Suite per commit: full kedua tree hijau (230 → **233**: +test-vault-layout2, +test-vault-layout-migration, +test-blackbox-layout2).

## Bukti penutup gate

**(i) Blackbox e2e klinik layout-2 sampai units** — `tests/blackbox/test-blackbox-layout2.sh` (standing, CI-discovered): seed 7-file klinik → migrate --apply → derive (layout 2, 4 entities, 3 flows) → claims-ledger (kode AR/CN/DC/DM/FL/MODE, source = 4 file baru) → validator LIVE (Mermaid mandate + vault-oqs di flows.md/constraints.md) → binding `vault_source: model.md:NN`/`flows.md:NN` → **CONFLICT gate FIRED di layout-2** (make-bound refuse exit 2 → resolve → bound/ berisi 4 doc + BIND annotation di flows.md) → unit `vault_source: flows.md:F-U-001` PASS validate-unit-spec → flow-coverage menemukan vault. Bonus jujur: mandat Mermaid MENANGKAP node tanpa quote di fixture gue sendiri (Rule 1) — konten dibetulkan, validator benar.

**(ii) Ukuran (angka, sesuai permintaan):**
| Ukur | 7-file | 4-file | Delta |
|---|---|---|---|
| Vault klinik (fixture, 00-index ringkas) | 6.951 B (~1.737 tok) | 6.181 B (~1.545 tok) | **−11%** |
| Template generation (ceiling ceremony) | 31.072 B (~7.768 tok) | 17.829 B (~4.457 tok) | **−42%** |

Fixture −11% adalah LOWER bound — 00-index fixture sengaja ringkas; vault hasil generate template lama membawa ±8K ceremony 00-index, jadi vault nyata mendekati angka template. Permukaan OQ: 8 → 2.

**(iii) Tier-S ulang:** utuh — S17 no-signal 0 fork, S18 SDD+index 8 fork, 19/19 arm; layout-2 tidak menambah satu fork pun di tier S.

## Keputusan bentuk (deviation dari contoh, disclosed)

Contoh yang disetujui menaruh `changelog:`/`sources:`/`auto_classification_review:` sebagai YAML frontmatter. Implementasi menaruh **hanya `vault_layout` + 6 lock scalar (+prd_source/locked_at/locked_by/kb_module_graph) di frontmatter**; Changelog / Source documents / Auto-Classification Review / Glossary pindah sebagai **SECTION md verbatim** di vault.md. Alasan: migrasi mentranskode md authored sembarang ke YAML = risiko korupsi (anti-fabrikasi), dan konsumen grammar changelog (resolve-oq resume, diff-vault bump) tetap membaca bentuk `### vN.N` yang sama. §5.3 Amendemen 2 ("Lock values → YAML frontmatter") terpenuhi persis.

## Pelajaran standing

1. **Grep nama-literal TIDAK menangkap konsumen pattern-scoped** (`0[0-6]-*.md` glob/regex, `\d{2}-` SRC_RE) — saudara pelajaran `--include=*.sh`; sweep wajib dua pass: literal + pattern (`0\[0-6\]`, `d{2}-`).
2. Klaim audit "filename-agnostic (verified)" bisa benar untuk satu probe (vault.json) dan salah untuk probe sebelahnya (doc glob) di file yang sama — verifikasi per-callsite, bukan per-file.
3. Anchor-set section attribution (unknown H2 TIDAK menutup section) memungkinkan merge tanpa demosi heading — konten pindah verbatim, grounding terjaga.
4. Validator sendiri = reviewer fixture terbaik: mandat Mermaid menolak fixture yang gue tulis; jangan pernah melonggarkan validator untuk meloloskan fixture.

## Sisa (bukan blocker)

- **Dual-layout read = SATU minor cycle** (floor v5.9.0 kantor) — pencabutan fallback legacy adalah keputusan minor berikutnya, dengan telemetry.
- Vault legacy existing TIDAK dipaksa migrasi — `migrate-paths --vault-layout` opsional (resep di upgrade doc §7.0.0), full re-bind wajib setelahnya.
- Leg scm: user push via VPN kantor.
- Fase 4 (markdown diet, metrik token per lane) = gate terpisah.
