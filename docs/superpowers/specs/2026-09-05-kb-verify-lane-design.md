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
   verifier = acceptance item (suite hanya menguji jalur deterministik). Suite
   menguji: writer contract + 3 halt type + wiring (agent/SKILL/tier row).
   **ACCEPTANCE PASSED 2026-09-05 (live, sonnet, blind, body agent verbatim +
   READ ALSO rpg-as400):** fixture RPG dengan 3 WRONG ditanam (truncation
   dibilang rounding di [LOCKED]; guard `IFNE` kebalik; matriks negasi ketuker)
   + 1 rule kontrol benar → verifier menangkap **3/3 WRONG dengan evidence
   benar, wrong_load_bearing=3, NOL false positive**, plus 2 IMPRECISE sah yang
   tidak ditanam (input NDAYS terlewat; klaim kadens §7 melampaui bukti).
   Biaya 84,8k token / ~2 menit (di bawah patokan 150-220k/modul). End-to-end:
   VERIFY REPORT → write-verify-state (FAIL) → census gate `claim_verify_failed` ✓.
4. Role model-tier baru: `extract-intelligence-verify` (row 23, sonnet).
5. xs single-module: verifier TETAP dispatch (penulis tidak memeriksa dirinya).

## Amendemen Fase 4 (7.26.0, saat implementasi)

1. **verified_count DIPENSIUNKAN dari kontrak frontmatter** (underivable di grammar
   implicit-verified = permukaan drift murni); `intent_count` didefinisikan ulang =
   marker [INTENT] EKSPLISIT (script-derived, kb_output exact-check).
2. **Enumerator**: `code_enum.py` ketambahan lane `LEGACY_EXTS` (rpg/rpgle/sqlrpgle/
   dds/pf/lf/cl/cobol) via `include_legacy=True` — census memakainya, symbol index
   TIDAK (ast-grep tanpa grammar stack itu); ekstensi di-match case-insensitive.
   Ekspor AS400 tanpa ekstensi (Qrpgsrc.XXX) tetap butuh census manual — dicatat jujur.
3. **Site-census v1 = keluarga rpg saja** (WRITE/UPDAT/EXCPT glued + CALL literal,
   kolom-7 dikecualikan); stack lain tercatat "no idiom support" — bukan hijau diam.
   Coverage = sitasi exact ±2 baris atau dalam range a-b; sitasi shorthand `:NNN`
   tanpa path TIDAK dihitung (memang tak machine-verifiable — fix: tulis path:line).
4. **Rollup recount** = 2 klaim parseable (Total row Mutability + split/total OQ);
   README format custom → advisory note, bukan tebakan.
5. **Probe** = `(probe-glob: <pattern>)` glob-only v1, relatif project root / legacy
   root; advisory murni (`oq_answerable_from_disk`), tidak pernah FAIL.
6. **Idiom rpg-as400** = `references/legacy-idioms/rpg-as400.md` + kolom RPG di
   MASTER STACK IDIOM TABLE — BUKAN pack framework-conventions (itu untuk stack
   target rebuild; ini cara MEMBACA legacy). READ ALSO line di dispatch extractor
   + verifier saat stacks ∩ {rpg,rpgle,rpg-copy,dds}.
7. **Live proof di KB Host (sandbox)**: rollup_mismatch menangkap persis LOCKED
   5-vs-4 + split OQ 9/20/11-vs-12/18/10 (recount lane F); site_uncovered 12 —
   termasuk #CRTFLT:125/144/182/201 (4 site float lane E) dan tltran:1438 (site
   CFTPNT ke-4). Deteksi audit kini deterministik.

## Amendemen Fase 5 (7.27.0, saat implementasi)

1. **`depends_on` TIDAK di-rename** (konsumen: build-graph, kb_output, bind) —
   semantiknya dipertegas "references, cycle sah"; field BARU `rebuild_after`
   (subset acyclic) jadi sumber build order README. Census gate:
   `rebuild_order_invalid` (unknown module / bukan subset / cycle, DFS 3-warna).
2. **AC-for-LOCKED = FAIL** (`ac_missing_for_locked`): tiap baris BR ber-[LOCKED]
   wajib ≥1 `AC-<BR-id>-n` (oracle golden-master) atau `blocked-by-OQ` eksplisit.
   Deteksi deterministik dari baris tabel; [LOCKED] di luar baris BR tidak
   membebankan AC.
3. **§7 Run & Recovery** wajib hanya untuk `classification: workflow`
   (via `missing_sections`); kb_output tetap cek 1-6 (census yang punya aturan §7).
4. **3 advisory baru** (tidak pernah FAIL): `undeclared_reference` (sitasi file
   modul lain tanpa depends_on — kelas 5 edge lane F), `rule_needs_decision_table`
   (≥3 konektor boolean di sel Rule), `flow_names_artifact_component` (token
   uppercase di baris [ARTIFACT] muncul di §3 — kelas FNDCUR).
5. **Rail klaim-negatif** = prosa di extractor ("negative claim menyebut scope
   sweep-nya") + verifier ("uji scope, bukan cuma huruf; unscoped negative =
   IMPRECISE minimal") — tidak ada validator (undetectable deterministik).
6. Decision-table & register AC: bentuk di template §2; mandat = prosa +
   advisory, bukan FAIL (bentuk prosa yang benar tidak bisa dibedakan mesin).

## Tranche C — cost (RESOLUSI 2026-09-05: C1 VOID by prior decision)

- **C1 DIBATALKAN** — investigasi menemukan `TOKEN-COST-REPORT.md` 0-byte bukan bug:
  writer token-cost DIHAPUS SADAR di v7.3.0 (`bfdf996`, amandemen
  `research/2026-08-22-v7-amend-no-observability.md` + `-no-telemetry.md`, final +
  retroaktif: "mega-sdd tidak membangun telemetry/monitoring apa pun — domain AI
  gateway"). Artefak di Host = sisa cache plugin versi lama (obat pencegahnya =
  resep headless update yang sudah dipegang tim mega-code). Membangun ulang = 
  reversal keputusan owner — TIDAK dilakukan tanpa keputusan eksplisit baru.
- **C2 tetap valid sebagai target list** (main-thread turn gendut, generate-intent,
  ronde resolve-oq) tapi jalur ukurnya = **data AI gateway kantor** (model/token/
  biaya per request, difilter `mega-sdd-trace:` yang di-restore gate7b) atau tracer
  maintainer di `benchmarks/` — bukan instrumentation runtime baru. Blocked on
  ekspor data gateway dari field run; buka gate C2 saat angkanya ada.

## Standing policy (CLAUDE.md release checklist)

Perubahan grammar/layout producer ⇒ sweep konsumen terdaftar (validator, glob analyze,
renderer, reader `generate-intent --kb`/bind) sebelum rilis.

## Versions

Fase 1+2 → 7.24.0 · Fase 3 → 7.25.0 · Fase 4 → 7.26.x · Fase 5 & C per item.
marketplace.json match tiap bump. Suite penuh per rilis.
