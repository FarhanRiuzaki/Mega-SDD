# Leftover sweep 2026-09-06 — sisaan yang lolos dari rilis-rilis sebelumnya (7.29.1)

**Trigger:** owner — "beresin kerjaan-kerjaan atau sisaan yang ga ketangkep" (sesi Fable 5.1, setelah 7.29.0 CI hijau).
**Rambu:** Evidence-First rule (2026-09-05) tetap berlaku — sisaan ≠ fitur baru. Yang masuk hitungan: (a) klaim "sudah" / janji follow-up yang ternyata belum benar di HEAD, (b) defect/inkonsistensi kode-dok, (c) referensi gantung (file/flag/script yang tak ada atau tak tracked), (d) keputusan on-record yang belum dibangun, (e) kerja belum dikomit. Yang BUKAN sisaan: ide baru, item REJECTED/PARKED/VOID, moat gate.

## Metode

1. **Scout inline** — git status, sitasi `research/*.md` gantung, ledger open (audit efisiensi §P2, doc-audit item 2–5, hardening §2.4/§3.5, morning-proposals, triage tim, spec size-weighted).
2. **Workflow 8 finder independen** (ledger-open · dangling-refs · version-drift · recent-release-residue · test-ci-residue · code-stale · changelog-promises · skill-doc-drift) → 96 temuan mentah → merge 91 item unik → 3 lensa refutasi per item (already-closed / closed-decision / evidence-repro) → klasifikasi fix terkecil.
3. **Fix single-author** (pelajaran adversarial rounds: tulis satu tangan, fan-out hanya baca/verifikasi). Setiap replacement = exact-match tunggal (skrip batch abort kalau 0 atau >1 match) — verifikasi teks sumber sebelum edit adalah bagian dari fix.
4. Suite dua tree (mirror discovery CI) → commit → CI.

> Catatan jujur: fase verifikasi workflow (91 item × 3 lensa = 273 agen) kena session limit di tengah jalan — 27 item dapat verdict (20 lengkap 3 lensa, 7 sebagian), ±64 item TIDAK terverifikasi lensa (agen error, bukan refuted). Setiap edit di bawah gue verifikasi sendiri dari teks sumber sebelum diaplikasikan (exact-match tunggal). Rekonsiliasi hasil lensa yang ada: §Addendum.

## Yang dibereskan (7.29.1)

### Kode (perilaku)
| Item | Bukti | Fix |
|---|---|---|
| `validate-preflight.sh` `vault_present_for_oq` (FATAL) menuntut `03-open-questions.md` | layout-2 = `constraints.md`, legacy = `06-constraints.md`; tak ada layout yang punya file itu → check ini salah di setiap vault nyata saat resolve-oq di-chain | predikat layout-aware (+ nama kuno tetap diterima, fail-open); `predictive-checks.md` ikut |
| Rule 4b (7.29.0) menulis `defer_to: binding` tanpa syarat | kontrak `resolve-oq §Defer targets`: `binding` hanya sah di brownfield (`implementation_mode: existing` + sinyal repo); greenfield = `stakeholder` saja | 4b: `binding` brownfield / `stakeholder` greenfield (mesin auto-defer express); spec §2 diamandemen |
| 5 tipe halt dipancarkan tapi tak terdaftar | `bind_inputs_missing` (bind Step 0), `unit_oq_trace_missing` (MOAT-CRITICAL), `cross_module_dep_invalid`, `module_cycle_detected` (generate-units), `ambiguous_spec` (bolt-implementer) — nol di enum registry / family / taxonomy | terdaftar terse; harness family-split cap b1 32300→33600, b2 13500→14000 (preseden 7.11.0) |
| `.gitignore` negasi tree plugin | CHANGELOG lama klaim "negation for plugins/mega-sdd/tests/**/*.test.md is kept" — `git check-ignore` membuktikan file di tree plugin ter-ignore | `!plugins/mega-sdd/tests/**/*.test.md` |
| ~~`build-prd-core.sh` §6 / `build-fsd-core.sh` §10 baca `03-open-questions.md`~~ | **DIBATALKAN lensa closed-decision:** v6 spec §P4.2 AC3 "legacy-name fallback still honored" + nama itu nyata di vault Iter 53 (CHANGELOG-ARCHIVE:2713) | dikembalikan utuh (`git checkout`); test-5e tetap menguji jalur legacy |
| Dead code | `_word_hit`/`body_l` (resolve-review-tier, tergantikan `_word_hit_in` 7.8), `normalize_token` (validate-flow-coverage) | dihapus |

### Dok/komentar yang menceritakan mekanisme yang sudah mati
- **Fan-out PostToolUse (№D 7.5.0)** — ±30 situs: header 5 validator `[PostToolUse-validate]`, 9 string `next_action` "re-save (PostToolUse re-validates)", hooks/pre-tool-use (`PostToolUse-written state`, `SIX` states, `five` scans → six), hooks/stop, hooks/post-tool-use header (matcher Read|Skill|Bash… → Write|Edit), hooks/user-prompt-submit ("ENTIRE job is one echo" padahal ada baris 2 census №G), run-analyze.sh, build-dispatch-prompt.sh + execute-bolts SKILL + bolt-dispatch-prompt (klaim hook memicu validate-dispatch-prompt per builder call → advisory di analyze V16), validate-fsd-slots `pdf_render_failed` "needs PostToolUse Bash matcher" (VOID), label dispatch di validate-kb/ui-quality/unit-spec/dispatch-prompt, `Telemetry-only` state.
- **Lane memori (7.3.0)** — using-mega-sdd "memory review", install-deps rail 1/6 + rationale handoff `--force-recheck` (mengajarkan flag no-op), resolve-oq interactive-walk "memory row", fixture REC7–REC10 + OF-MT1/2, scenario-6.
- **Vendored/tree-sitter (7.4.0)** — execute-bolts SKILL ×2, bolt-implementer "legacy fallback executor", `tree-sitter-integration.md`, 9 header query ast-grep, `sync-ui-ux.sh` (product-style-map.yaml + generator), `check-dep-authorization.sh`, CONTRIBUTING §Testing.
- **Vault 7-file** — generate-intent SKILL ":9 7 markdown files", generate-units, bind-codebase + binding-contract, resolve-oq, vault-core; "six lock scalars" → + `project_scale` (6 situs).
- **7.29.0 pengajar belum sinkron** — Glossary "MUST" ×5 tanpa carve-out xs, template vault.md tanpa stub `Auto-deferred (project_scale: xs)`, self-check tanpa butir xs; review-panel field `unit_tier`; bolt-dispatch-prompt tanpa pointer §XS.
- **iter-classifier** PARKED ×4 vs REMOVED (referensinya sendiri).
- **Angka/surface** — CLAUDE.md "five" artifact gate (tujuh dienumerasi di kalimat yang sama), emit args, CLI pin 2.1.233 masuk checklist; README "30 packs" (25); model-tiers "20 rows" (15); CONTRIBUTING 4+4 verb (3+3); upgrade guide "CURRENT target 7.6.x" + bagian 7.7–7.29 baru; install-deps enum `yum` + daftar manager; front door Step 7→8, "matcher excludes Agent" (F-09), bare `references/X.md` ×5; orchestrate-flow snapshot rows diberi sumber `probes.*`; halt-protocol path terpotong; project-config +`render_html`/`unit_granularity`; analyze §Domain-rule gap check dual-grammar; unit-schema contoh path KB; domain-extractor "machine-parsed" (tak ada parser).
- **Kepemilikan konfirmasi** (audit 2026-09-05 §SIMPLIFY) — Step 6 orchestrate-flow.
- **Spec/riset** — 7.3.1 dapat entri CHANGELOG; weighted-routing §7.7; hardening §2.4 F-30 item 3 ditutup (proteksi bukan diet); morning-proposals stempel (b)/(d)/Wave-5; balasan tim follow-up angka; 7.0.0 ":follow-up minors" + path suite; 7.28/7.29 "Skill version moves".

### Tests
- session-start +r5/r6 (pin C1-at-GROUND + no-vault-writes yang hilang bersama telemetry-range.test.sh — 7.0.0 mengklaim pin itu ada).
- project-scale +pin 12 sapuan korpus (klaim "12 file nol false-xs" → pin 18 dok).
- test-md2pdf SKIP lantang + CI pasang pandoc → asersi byte-identical moat benar-benar jalan di CI.
- ss-parity marker dari `WRAPPER_VERSION`; repin "eight" hook → six; "five" scan → six (+ `--panel-scan`); golden xs 18142→18174; pagerank pesan; auto.test.md AL1; integration ×4 header; wrapper kosong compaction/learning-loop dihapus; anchor core re-baseline 3846→3844 (tercatat).

### Repo
- 22 catatan `research/` yang disitasi dok/hook/test/CHANGELOG tapi belum dikomit → `8d1f913`.

## Yang SENGAJA tidak dibangun (dan kenapa)

| Item | Kelas | Alasan |
|---|---|---|
| `mega-sdd-extras` slice-design revive | needs-owner | keputusan 2026-08-23 ada, tapi audit 2026-09-05 + Evidence-First menaruh field run dulu; butuh reconfirm owner sebelum dibangun |
| `.claude/settings.local.json` modified | milik sesi lain | shared-worktree rule: jangan sentuh |
| `--skip-pagerank` / `--force-recheck` dihapus | closed-decision | ladder: numpang MAJOR berikut; hanya wording-nya diperbaiki |
| ~~`validate-bolt-artifacts.sh` `_parent_reqs`/`_obj_map`/`has_object` (prefetch tanpa pembaca)~~ | **REFUTED oleh bukti (2026-09-06 sore)** | pembacanya ada: `_lib/postflight_rules.py:571` `prefetch.has_object("%s^" % sha)` (fallback solo `rev-parse` :573) — finder cuma grep di file pemanggil, bukan di engine. Bukan sisaan; proposal batal |
| Rotasi CHANGELOG (3.980 baris / 229 versi vs aturan 2.000 / 30) | ~~decided-not-built~~ → **DONE** commit terpisah setelah 7.29.1 hijau (owner "gas" 2026-09-06): oldest 50% (v3.65.0–v5.2.2, 114 entri) → `CHANGELOG-ARCHIVE.md`; CHANGELOG tinggal 115 entri | aturan header-nya sendiri; CI parity hanya membaca tag teratas |
| REPORT BACK domain-extractor "machine-parsed" | no-evidence | parser tak ada dan tak ada konsumen — reword, bukan bangun parser |
| Fixture `tests/integration/*` yang tak pernah ada | manual walkthrough | header pengungkap + alias → front door; bukan mengarang fixture |
| Snapshot rows orchestrate-flow (`pending_p0_p1_count` dkk) | annotate | label digest, bukan key state.json — diberi sumber, bukan di-rename (blast radius routing) |
| Rule 4b "vakum di xs" (klaim finder) | refuted sebagian | rail anti-halu hanya menurunkan OQ `recommend` ke business; OQ `scan` tetap tech → 4b hidup; yang salah cuma target defer (diperbaiki) |

## Pelajaran

- **Sitasi tanpa komit = dok gantung buat semua clone.** Tiap sesi yang menulis `research/` sebagai keputusan gate harus `git add` file itu di commit yang menyitasinya.
- **Producer-grammar sweep berlaku ke pengajar juga:** konsekuensi xs (7.29.0) ditulis di 1 pengajar, 4 pengajar lain (self-check, template, SKILL tree, review-panel) masih bilang MUST. Sweep konsumen = termasuk file self-check/template.
- **Komentar ikut dihapus bersama mekanismenya.** Tiga penghapusan besar (7.3.0 memori, 7.4.0 vendored, 7.5.0 fan-out) meninggalkan ±60 kalimat yang masih menceritakan mekanisme lama — cari `grep` nama mekanisme sebelum menutup rilis penghapusan.
- **Batch edit per file harus kumulatif** (skrip pertama gue last-wins per file → separuh edit hilang; ketahuan dari grep residu, bukan dari "OK").

## Addendum — rekonsiliasi hasil lensa workflow

Workflow selesai 66 menit, 312 agen (125 selesai, 187 error session-limit). Hasil yang ADA:

| Hasil lensa | Item | Tindakan |
|---|---|---|
| **Refuted ≥2 lensa (killed sungguhan)** | #9 `--skip-pagerank` "5.x cycle" — closed decision: DEPRECATE next-major on record (audit 2026-09-05) | konsisten: hanya reword + repin test, tidak dihapus |
| **Refuted 1 lensa, bukti record kuat** | #16 baca `03-open-questions.md` di build-prd-core §6 — v6 spec §P4.2 AC3 "legacy-name fallback still honored", nama nyata di vault Iter 53 | **fix gue DIBATALKAN**: 5 file di-restore (`git checkout`), test-5e tetap menguji jalur legacy; predikat preflight tetap layout-aware + nama legacy diterima |
| **Refuted 1 lensa "already closed at HEAD"** | #2–#6 sitasi research untracked | benar — ditutup oleh `8d1f913` (commit gue sendiri, mendahului verifikasi) |
| **Confirmed 3 lensa** | #3–#8, #10–#12, #14, #17–#20, #22, #24–#25 (Step 6 ownership, iter-classifier, install-deps memori, SIX/PostToolUse hook comments, F-30 comment, balasan tim, morning-proposals, CONTRIBUTING ×2, resolve-oq bare ref, unit-schema, telemetry-range r5/r6) | semua di-fix di 7.29.1; klasifikasi lensa = `uncommitted-work` (fix sudah ada di working tree saat lensa membaca) |
| **Confirmed, needs-user-decision** | #18 `mega-sdd-extras` revive · #1 `.claude/settings.local.json` (sesi lain) | TIDAK disentuh — keputusan owner |
| **Confirmed sebagian (1–2 lensa, sisanya error)** | #13 F-30 item 3, #15 model-tiers, #21 CONTRIBUTING vault-contract, #23 analyze 40-business-rules, #26 weighted-routing §3.6, #27 halt-protocol path, #87 domain-extractor, #89 bare refs, #90 snapshot rows, #91 install-deps enum | di-fix; lensa yang sempat jalan tidak menolak |
| **Tidak terverifikasi lensa (agen error)** | #28–#86 (±60: versi/angka README-CLAUDE-CONTRIBUTING, pengajar xs, PostToolUse comments, dead code, test repins, tests.yml pandoc, .gitignore, integration fixtures, dst.) | di-fix atas verifikasi manual gue terhadap teks sumber + suite 246/246; **bukan** klaim "lolos lensa" |

Yang lensa temukan dan gue rekam: `has_object` (#65) — ternyata DIPAKAI di `postflight_rules.py:571`, finder salah scope grep → bukan sisaan; rotasi CHANGELOG (#28) — DIKERJAKAN sebagai commit terpisah setelah 7.29.1 hijau.
