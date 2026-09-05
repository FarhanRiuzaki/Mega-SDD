# Spec — KB trustworthiness: validator migration + verify lane (+ cost tranche)

**Riset:** `research/2026-09-05-hostas400-kb-audit.md` (audit lapangan, 88 sitasi spot-check) +
`research/2026-09-05-megasdd-skillgap-analysis.md` (issue→skill-gap matrix). Owner "gass"
2026-09-05 atas rencana dua tranche: (a) akurasi, (b) cost measured-first.

**Pemicu:** KB Host-AS400 drift (marker counts, roll-up, 8 klaim WRONG) sementara
`CONSISTENCY-REPORT` bilang PASS — root cause: extract revamp 7.6.0 ganti layout
(`knowledge-base/modules/*.prd.md`) + grammar (6 section, implicit-verified) tapi
validator KB tidak dimigrasi → 4 surface SKIP "no applicable files" selamanya.

## Prinsip

- Moat tidak disentuh: census gate, citation discipline, halt taxonomy, mutability tiers.
- Gates > rules > hooks: semua tambahan = validator/gate di analyze & extract handoff,
  ZERO tambahan hot-path PreToolUse.
- Dual-grammar back-compat (pola revamp 7.6): layout legacy `10-domains/…` tetap
  tervalidasi dengan schema lama; layout `modules/*.prd.md` dengan schema baru.
- Tech-agnostic: idiom AS400/RPG masuk pack, bukan skill body.
- Cost: instrument dulu, potong belakangan; angka tanpa breakdown tidak boleh jadi dasar cut.

## Tranche A — akurasi

### Fase 1 (P0-1) — migrasi validator KB ke grammar modules/

1. `run-analyze.sh`: discovery KB menambah `knowledge-base/modules/*.prd.md` di
   applicability + file-list + loop kb (legacy paths dipertahankan).
2. `validate-kb.sh` — deteksi grammar per file (path `modules/*.prd.md` ATAU frontmatter
   `generated_by: mega-sdd:extract-intelligence` + `## 1.` heading) → arm schema baru:
   - **output**: 6 section `## 1.`–`## 6.` (bukan 11); counts: `inferred_count` vs body
     `[INFERRED]`, `open_count` vs jumlah entri `- OQ-` di §6, `locked_count`/`artifact_count`
     vs body marker; `verified_count` TIDAK direcompute (konvensi implicit-verified —
     dilaporkan `unverifiable_by_design`, bukan FAIL); `depends_on` resolution tetap.
   - **citations**: tiap entri `source_files` frontmatter tersitasi ≥1 di body (recompute
     analyze-time dari kontrak census).
   - **flows**: §3 fence mermaid + `_lib/mermaid_syntax.py` (share jalur legacy).
   - **markers**: `[INFERRED]` tanpa basis `(dasar` → issue; `[OPEN]` di body tanpa OQ di §6 → issue.
3. Pin tests baru `tests/kb-validators/` + golden negatif dari fixture bergaya Host
   (counts drift KETANGKEP, 6-section valid TIDAK divonis incomplete).

### Fase 2 (P0-2) — SKIP-honesty

`run-analyze.sh` aggregate: tiap validator KB punya subject-glob deklaratif; subjek ADA
di tree tapi validator melapor 0 applicable → baris `MISCONFIGURED` (FAIL aggregate),
bukan SKIP diam. Berlaku minimal untuk keluarga kb_* (yang subject-nya derivable).

### Fase 3 (P0-3) — claim-verify lane di extract-intelligence

Subagent reviewer read-only per modul (pola panel execute-bolts: blind, findings-only,
severity-graded) SETELAH per-module quality gate: 100% klaim `[LOCKED]` + money-class,
sample N sitasi lain → grade EXACT/IMPRECISE/WRONG. WRONG di load-bearing → re-dispatch
modul 1×, gagal lagi → halt `quality_gate_failed`. Hasil ditulis deterministik
(`.verify-state.json`) dan dibaca `validate-extract-census.sh`. Fixture seeded-error
(inversion kelas TLXGTN) wajib ketangkep. Biaya diukur per modul (patokan audit:
±150-220k token/modul).

### Fase 4 (P1)

Counts machine-derived (REPORT BACK tanpa angka tak-terverifikasi) + rollup-recount README;
site-census (WRITE/CALL-site obligasi via idiom pack) di `validate-extract-census.sh`;
OQ `probe:` + advisory `oq_answerable_from_disk`; **pack `rpg-as400`**
(fixed-format opcode-nempel, kolom-7 dead code, IFNE-inversion checklist, indicator reuse,
data area, RETRN-stateful, REF/REFFLD chasing, probe encoding non-UTF8).

### Fase 5 (P2, gate sendiri per item)

`depends_on` → `references`+`rebuild_after`; decision-table mandate; AC layer golden-master;
section kontrak operasional; rail klaim-negatif; flow-br-lint advisory.

## Amendemen Fase 3 (7.25.0, saat implementasi)

1. **Scope enforcement dipertegas**: yang deterministik di gate = state ada +
   verdict PASS + LOCKED coverage (recompute dari body) + sample floor
   `min(8, jumlah sitasi)` (recompute). "Money-class 100%" tidak bisa
   direcompute → kewajiban prosa di body agent (sekarang ada mata kedua yang
   memeriksanya — itu perbaikannya vs pra-7.25).
2. **Writer deterministik** `scripts/write-verify-state.sh` (bukan controller
   hand-write JSON): parse blok `VERIFY REPORT`, tolak report inkonsisten
   (wrong=0 tapi ada finding WRONG, dsb.). Terbukti saat menulis test:
   seed under-scoped (locked_checked=0 vs PRD ber-[LOCKED]) DITOLAK gate —
   recompute bekerja.
3. **Seeded-error live**: fixture inversion kelas TLXGTN yang DITANGKAP model
   verifier = acceptance item di field extraction berikutnya (suite hanya bisa
   menguji jalur deterministik; presedennya = fork A/B). Suite menguji: writer
   contract + 3 halt type + wiring (agent/SKILL/tier row).
4. Role model-tier baru: `extract-intelligence-verify` (row 23, sonnet).
5. xs single-module: verifier TETAP dispatch (penulis tidak memeriksa dirinya).

## Tranche C — cost (measured-first, gate terpisah)

- **C1:** fix `TOKEN-COST-REPORT.md` 0 byte (state JSON terisi, report kosong) + pastikan
  window mencakup fase extraction (hari ini `by_skill` tidak memuat extract sama sekali).
- **C2:** dengan breakdown nyata, serang turn gendut (main-thread 4,6M cw / generate-intent
  4,1M / resolve-oq ~570k per ronde) — tiap lever di-gate owner; moat & recompute-at-gate
  tidak dioptimasi.

## Standing policy (CLAUDE.md release checklist)

Perubahan grammar/layout producer ⇒ sweep konsumen terdaftar (validator, glob analyze,
renderer, reader `generate-intent --kb`/bind) sebelum rilis.

## Versions

Fase 1+2 → 7.24.0 · Fase 3 → 7.25.0 · Fase 4 → 7.26.x · Fase 5 & C per item.
marketplace.json match tiap bump. Suite penuh per rilis.
