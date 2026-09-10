# P0.4 — Audit titik interaksi (W1.1): di mana chain berhenti menunggu manusia, dan apa nasibnya di W1

**Tanggal:** 2026-09-10 · **Head:** `08b05d2` (7.31.0) · **Mandat:** implementasi v8 owner 2026-09-10 §P0.4 + workstream W1 zero-idle (spec `docs/superpowers/specs/2026-09-10-v8-fused-pipeline-design.md` §7).
**Aturan klasifikasi (owner, tidak dinego):** **TETAP BLOCKING** hanya `CONFLICT` (`bind_conflict`), `hard_rule_violated`, dan OQ **P1 business** (`oq_business_p1_unresolved`/`oq_blocker`). Sisanya **BATCH** (dilipat ke SATU ask terjadwal — ujung PLAN, atau konfirmasi awal bila pra-chain) atau **DEFER** (dicatat + resurface di laporan akhir; chain lanjut). Budget W1: happy-path 3-screen = **tepat 2 titik**, klinik ≤ 3.
**Sumber:** sensus read-only (agent Explore, 41 situs `AskUserQuestion`, 80+ halt id, 30 situs checkpoint) — path relatif `plugins/mega-sdd/`. Sensus sengaja hanya melaporkan perilaku *as written*; klasifikasi di file ini adalah keputusan desain W1 dan **berhenti di gate** (implementasi = P1.4).

**Definisi operasional supaya "DEFER" tidak dibaca sebagai melemahkan gate:** DEFER untuk sebuah gate deterministik berarti gate itu **tetap menyala dan tetap memblokir unit itu** (evidence tidak ditulis, dependents ikut ter-blok via `depends_on`), yang berubah hanya *chain tidak parkir menunggu manusia* — unit dikarantina, wave lanjut, semuanya muncul di laporan akhir dengan satu pertanyaan per item. Rambu keras owner (acceptance dieksekusi, B1–B4, whitelist, CONFLICT, hard-rule pre/postflight) utuh.

## A. Happy-path 3-screen xs greenfield hari ini → target W1

| # | Titik (urutan hari ini) | file:line | Fire hari ini | Klasifikasi W1 | Mekanisme W1 |
|---|---|---|---|---|---|
| 1 | Konfirmasi chain di front door (Run/Edit/Cancel) | `commands/mega-sdd.md:120`, `:74`; glos `orchestrate-flow/SKILL.md:78` | **1, selalu** | **BATCH** (titik #1) | Tetap satu; predictive preflight (`orchestrate-flow/SKILL.md:61`) sudah mendahuluinya → semua kegagalan struktural pra-chain (baris C-1) ikut tampil di layar ini. |
| — | orchestrate-flow Step 6 konfirmasi ulang | `orchestrate-flow/SKILL.md:63` | 0 (ownership `:78`) | — | Sudah di-suppress; pin test W1 memastikan tetap 0. |
| 2 | Retrofit bridge PRD tanpa `scopes:` (+ menu diff) | `generate-intent/references/setup-flow.md:179`, `:180` | **0–2** (PRD tulisan tangan biasanya tanpa `scopes:`; tanpa carve-out `--auto`) | **DEFER** | Di `--auto`/`--lite`: PRD tanpa `scopes:` = single-scope **direkam** (`scope_inferred: single` di vault.json + baris laporan), retrofit ditawarkan di laporan akhir. Tidak pernah bertanya. |
| 3 | PROJECT_SHAPE confirm bila confidence LOW | `generate-intent/SKILL.md:125`; carve-out `auto-and-handoff.md:26` | **0–1** (model-judged) | **DEFER** | Rekam shape terpilih + confidence + alternatif di vault.json/laporan; tidak pernah bertanya di jalur auto. |
| 4 | Batched ask OQ P1 business (≤4/call) | `orchestrate-flow/references/routing-rules.md:52`; `resolve-oq/SKILL.md:54,62`; `interactive-walk.md:123,125` | **1** (⌈N/4⌉) | **BLOCKING** (titik #2) | Tetap — inilah satu-satunya ask substansi. W1 memindahkannya ke **ujung PLAN** (setelah units tertulis, sebelum bolts) dan **melipat L0 toolchain (#5) ke call yang sama**. |
| 4b | Follow-up Defer/OOS per OQ (2 pertanyaan) | `interactive-walk.md:440`, `:495`; `auto-memory-handoff.md:23` | +1 per jawaban Defer/OOS | **BATCH** | Sub-pertanyaan (`defer_to`, alasan) dilipat sebagai opsi/field di call yang sama; default `defer_to` dari tier (`stakeholder` greenfield, rule 4b) **direkam**, bukan ditanya terpisah. |
| — | OQ P2/P3 tech auto-defer | `resolve-oq/SKILL.md:55-56` | 0 (RECORDED) | DEFER (sudah) | Tidak berubah. |
| 5 | Keputusan L0 toolchain (0 linter + 0 formatter) | `execute-bolts/SKILL.md:63` | **0–1** sekali per repo | **BATCH** → ke #4 | Probe GROUND sudah tahu sebelum PLAN selesai (`.l0-toolchain-probe.json`); pertanyaan jadi item di ask #4. Repo tanpa OQ P1: ask #4 tetap satu call berisi item L0 saja (atau default `na` direkam bila `--lite` dan owner memilih itu — keputusan P1.4). |
| — | Propose-and-confirm (`test_fail`/`hard_rule_violated`/`pbt`) | `execute-bolts/references/halt-recovery.md:54,82` | 0 di happy path | lihat C | — |
| — | Drift gate HIGH override | `orchestrate-flow/references/chain-execution.md:201` | 0 (nol drift) | **DEFER** | Rekam ke `PENDING-SYNC.md` + laporan; tanpa ask mid-chain. |
| 6 | Baris resurface OQ deferred | `orchestrate-flow/SKILL.md:92` | 1 baris, 0 prompt | DEFER (sudah) | Tetap; jadi bagian laporan akhir. |

**Total hari ini:** 2 pasti + 0–4 kondisional + 1/jawaban Defer. **Target W1:** **tepat 2** (chain confirm + satu batched ask ujung PLAN), kondisional = 0 by construction. Pin test P1.4: replay skenario 3-screen → `AskUserQuestion` count == 2.

## B. Semua situs `AskUserQuestion` (41) × klasifikasi

| # | Situs | file:line | Per-item? | W1 |
|---|---|---|---|---|
| 1 | orchestrate-flow Step 6 chain confirm | `orchestrate-flow/SKILL.md:63` | sekali | BATCH (#1; suppressed by ownership) |
| 2 | Front door ambiguitas vault ownership (≥2 vault) | `commands/mega-sdd.md:53` | sekali, jarang | BATCH → #1 (opsi di layar konfirmasi) |
| 3 | Adoption DEMOTE confirm | `commands/mega-sdd.md:46`; `halt-families/flow.md:71` | per artefak | BATCH → #1 (lane adopsi, pra-chain) |
| 4 | generate-intent output path (+ folder non-empty) | `setup-flow.md:30`, `:49` | sekali | DEFER default slug; **folder non-empty tetap BLOCKING-destruktif** (bukan interaksi chain: fail-fast pra-chain, masuk #1 via preflight) |
| 5–7 | IMPLEMENTATION_MODE / PRD_STATUS / OUTPUT_MODE | `setup-flow.md:68,84,98` | sekali | DEFER (sudah default `--auto`; nilai direkam) |
| 8 | Squad partition loop | `setup-flow.md:110-133` | per squad | BATCH → satu ask di ujung PLAN hanya bila `_meta/squads.yaml` absen DAN PRD menyebut ≥2 squad; default single-squad direkam |
| 9 | Scope picker multi-scope | `setup-flow.md:174`; `scope-picker.md:35` | sekali | BATCH → #1 (front door sudah punya picker `commands/mega-sdd.md:78-98`) |
| 10–11 | Retrofit bridge + review | `setup-flow.md:179,180`; `legacy-retrofit-prompt.md:116` | sekali (+per-scope) | DEFER (A-2) |
| 12 | PROJECT_SHAPE confirm | `generate-intent/SKILL.md:125` | sekali | DEFER (A-3) |
| 13 | Figma tanpa MCP/screenshot | `generate-intent/SKILL.md:124,141` | sekali | BATCH → #1: preflight mendeteksi URL Figma + MCP absen sebelum chain; tanpa itu = DEFER (UI = OQ, never invent — rail utuh) |
| 14 | Mode B brief walk ≤10 pertanyaan | `from-prompt-mode.md:84` | per pertanyaan | BATCH → SATU call multi-pertanyaan (≤4 per call, sisanya lahir OQ deferred) — lane Mode B saja |
| 15 | generate-units 7.6 collision | `generate-units/SKILL.md:86` | per unit | DEFER (sudah: `--auto` safest default; direkam di unit + laporan) |
| 16 | 13.5 constitution rules offer | `generate-units/SKILL.md:120` | sekali | DEFER (sudah: queued notice) |
| 17 | execute-bolts 3.8 L0 toolchain | `execute-bolts/SKILL.md:63` | sekali per repo | BATCH → #4 (A-5) |
| 18 | Propose-and-confirm bridge | `halt-recovery.md:54,82`; `propose-and-confirm-prompt.md:31,116,144` | per bolt yang halt | lihat C per halt: `hard_rule_violated` BLOCKING (tetap propose+confirm, satu layar); `test_fail`/`pbt_property_violated` DEFER (karantina unit + proposal fix di laporan akhir) |
| 19 | migrate-rules Step 4 | `migrate-rules.md:10,25` | sekali | BATCH → #1 (lane maintenance) |
| 20–23 | resolve-oq Step 0 vault / lock / resume / scope | `resolve-oq/SKILL.md:47,49,52`; `interactive-walk.md:31` | sekali | DEFER (sudah default di express; **lock 🔒 tetap BLOCKING** — bukan happy path, artefak dikunci manusia) |
| 24 | resolve-oq per-OQ prompt (batched ≤4) | `resolve-oq/SKILL.md:62`; `interactive-walk.md:123,125` | per OQ | **BLOCKING** untuk P1 business (#2); P2/P3 DEFER (sudah) |
| 25–26 | Defer / OOS follow-up | `interactive-walk.md:440,495` | per OQ | BATCH → ke #2 (A-4b) |
| 27 | `--binding` CONFLICT resolve | `binding-mode.md:61` | per CONFLICT | **BLOCKING** (CONFLICT) — di v8 dipanggil dari halt `binding_conflict` saat dispatch |
| 28 | Rekomendasi (auto-accept ≥0.80) | `recommendation-context.md:126,135,192` | per OQ | DEFER bila `--auto-accept` + confidence ≥ min (sudah); sisanya = #2 |
| 29 | Plan/Act MAJOR + `--act` | `chain-execution.md:99` | sekali | BATCH → #1 (flag-driven) |
| 30 | Drift gate HIGH override | `chain-execution.md:201` | per batch | DEFER (A) |
| 31 | `--mark-dod` per item | `diagnostics-procedures.md:167` | per item | BATCH (lane eksplisit; satu call multi-item) |
| 32 | Architecture advisor pilih arsitektur | `references/architecture-advisor.md:47,83` | batched | BATCH → ujung PLAN (sudah batched) |
| 33–34 | diff-vault uncommitted / conflict walk | `diff-vault/SKILL.md:50,69`; `report-format.md:138` | per conflict | BATCH → satu call lane diff-vault (sudah: `--auto` → `diff_conflict` envelope) |
| 35–36 | extract census split / per-batch continue | `extract-intelligence/SKILL.md:82,126` | per batch | BATCH → satu confirm awal + DEFER per-batch continue (lane legacy, luar spine) |
| 37 | install-deps batch confirm | `install-deps/SKILL.md:91-170` | sekali | BATCH (sudah satu batch) |
| 38 | emit-uat e2e | `emit-uat/SKILL.md:122` | sekali | DEFER (default: tulis fixme spec; tawarkan di laporan) |
| 39 | emit-agents-md tanpa marker | `emit-agents-md/SKILL.md:80` | sekali | DEFER |
| 40 | migrate-paths per move | `commands/migrate-paths.md:16-36` | per move | BATCH (`--auto-confirm` sudah ada; dry-run default) |
| 41 | update-plugin dormant versions | `commands/update-plugin.md:79` | sekali | BATCH (sudah ONCE) |

## C. Halt (per family) × klasifikasi — enforcement tidak berubah, hanya *kapan manusia ditanya*

| Kelas | Halt id (file:line di `references/halt-protocol.md` + family) | W1 | Mekanisme |
|---|---|---|---|
| **BLOCKING (3 kelas owner)** | `bind_conflict` (:180; `bind.md:11`; hook `.validation-blockers.json`), `hard_rule_violated` (:209; `bolts.md:39`; recompute `run-postflight-scan.sh`), `oq_business_p1_unresolved`/`oq_blocker` (:251/:151; `flow.md:63`) | **TETAP** | Satu layar: apa berhenti · satu pertanyaan · opsi (KEEP_VAULT/KEEP_CODE/SPLIT; Apply/Alt/Reject; jawaban OQ). v8: `bind_conflict` dipancarkan sebagai `binding_conflict` di dispatch (Appendix C4). |
| **BATCH → konfirmasi awal (#1)** (fail-fast pra-chain, sudah/harus ditangkap `validate-preflight.sh --predictive` `orchestrate-flow/SKILL.md:61`) | `no_starterkit_detected` (:252), `dep_missing` runner (:171; pre-flight 3.5 `execute-bolts/SKILL.md:60`), `pkg_mgr_not_found` (:250), `prd_path_missing` (:156), `scope_not_declared_in_prd` (:158), `bind_inputs_missing` (:181), `framework_pack_missing/cycle/unparseable` (:176-178), `predictive_check_failed` (:243), `model_tier_unknown` (:246, soft), `adoption_demote_confirm` (:253) | BATCH | Semua diketahui sebelum fase model pertama → tampil di layar konfirmasi #1 (predictive preflight sudah menjalankan sebagian; sisanya ditambahkan ke katalog `predictive-checks.md` di P1.4). Bukan interaksi mid-run. |
| **BATCH → ask ujung PLAN (#2)** | `delta_too_large` (:153), `diff_conflict` (:152) — lane diff-vault; `oq_recommend_*`/`oq_tech_missing_mode`/`oq_scan_missing_query` (:154,:159,:160,:179 — validator `validate-vault-oqs.sh`, fix by writer, bukan manusia) | BATCH | Validator OQ = self-fix loop writer (bukan ask); diff-vault = satu call lane. |
| **DEFER — karantina unit, wave lanjut, laporan akhir** (gate tetap memblokir unit + dependents; evidence tidak pernah dipalsukan) | L0: `secret_in_code` (:218), `sast_critical_finding` (:219), `dep_not_found` (:220), `build_broken` (:227); B1–B4: `postflight_evidence_missing` (:224), `batch_suite_red`/`_gate_missing` (:222-223), `whitelist_violation` (:229), `acceptance_evidence_missing`/`acceptance_red` (:225-226), `acceptance_expects_missing` (:215), `panel_evidence_missing`/`l0_evidence_missing` (:213-214), `bolt_artifacts_missing` (:232); panel: `review_critical_unresolved` (:221); implementer: `test_fail` (:234, setelah retry budget), `pbt_property_violated` (:207), `ambiguous_spec` (:200), `provenance_missing` (:203), `self_assessment_missing` (:205), `scope_creep_detected` (:231), `bolt_repeated_partial_failure` (:202), `dispatch_prompt_too_large` (:201), `anchor_missing` (:228), `hard_rule_unparseable/unanchored/mixed_grammar` (:187,:216,:233), `commit_rejected_by_hook` (:230), `module_blocked_by`/`sprint_blocked_by` (:210-211), `cross_squad_interface_draft` (:195) | DEFER | Unit → `status: quarantined` + alasan + halt envelope verbatim di `bolts/U-XXX/`; dependents di-skip dengan alasan; laporan akhir = tabel karantina + **satu pertanyaan per unit** (retry / fix manual / drop). Batch suite B2 tetap run-boundary. **Catatan kandidat BLOCKING tambahan untuk owner:** `constitution_drift_detected` (:240, "audit-significant"), `bolt_introduces_locked_drift` (:204 — kontradiksi index vs `halt-recovery.md:75`), `review_critical_unresolved` (:221) — aturan owner tidak memasukkannya; diklasifikasi DEFER *loud* (baris pertama laporan), **butuh konfirmasi owner** kalau mau tetap blocking. |
| **DEFER — generate-units/intent (unit tidak ditulis, sisanya lanjut)** | `unit_underspecified` (:188), `starterkit_rule_citation_missing` (:185), `unit_oq_trace_missing` (:192), `dedup_ambiguous` (:186), `cycle_detected`/`module_cycle_detected`/`cross_module_dep_invalid` (:189-191), `cross_squad_*` (:193-194), `interface_ref_missing` (:196), `prd_retrofit_low_confidence`/`prd_no_scopes_block_user_rejected_retrofit` (:157,:155), `constitution_drift_detected` di 12.4 | DEFER | Unit yang gagal validator dicatat (+ `validate-plan-coverage.sh` P1.3 menutup lubang coverage); PLAN tetap emit sisanya; ask #2 memuat ringkasannya. DAG cycle = PLAN self-fix loop dulu (writer), baru DEFER. |
| **C1 self-resolve (bukan interaksi)** | `partial_state_corrupt` (:208), `verify_unit_writable` (:217), `mode_migrate` (:242), `invalid_handoff` (:244, hook), `memory_in_use` (:241) | — | Tidak berubah. |
| **Lane lain (luar spine)** | scan `deep_scan_*` (:168-170), extract `quality_gate_failed` (:164), emit subtypes (:261-266), `install_failed` (:249), `drift_framework_mismatch` (:239), `handoff_*`/`artifact_missing` (:244-248), `convergence_max_reached` (:254), `phase_stuck`/`anti_spin` (:255-256) | DEFER / BATCH per lane | Emit + install = satu call lane; factory ledger cap = DEFER loud (sudah "ALWAYS-STOP at cap" — jadi laporan akhir, bukan tunggu mid-run). |

## D. Temuan sampingan sensus (bukan klasifikasi; bukti untuk P1.4)

1. **Kelas ke-6 `--auto` yang tidak dinamai taksonomi audit:** C1 self-resolve (5 halt; kontrak `halt-protocol.md:24-28`) — bukan titik interaksi.
2. **`bolt_introduces_locked_drift` kontradiktif:** `halt-protocol.md:204`/`bolts.md:23` "eligible for propose-and-confirm override" vs `halt-recovery.md:75` NOT eligible. Perlu satu kebenaran di P1.4.
3. **`dedup_ambiguous` + `unit_oq_trace_missing` = halt moat-adjacent tanpa backing deterministik by name** (0 hit `hooks/pre-tool-use` + `scripts/`; enforcement by class via `.validation-blockers.json`). `CLAUDE.md` menyebut "hook-enforced" — akurat by class, tidak by name; dokumentasi perlu bilang begitu.
4. **Hanya 3 halt propose-and-confirm by default** (`halt-recovery.md:57-59`); 16 explicit always-pure-pause (`:62-76`); sisanya pause by default (`:98`) — artinya hari ini hampir semua halt bolt = parkir menunggu manusia = sumber idle yang W1 serang.
5. **Retrofit bridge tanpa carve-out `--auto`** (`setup-flow.md:179-180`) = titik kondisional terbesar di happy path PRD tulisan tangan (0–2 ask).
6. `bind-codebase` **secara struktural tidak bisa bertanya** (`SKILL.md:11,130`) — klaim brief "Tech-OQ ACCEPT/OVERRIDE di bind" salah; keputusan itu di resolve-oq.

## E. Yang diusulkan untuk P1.4 (implementasi W1; gate owner)

1. Pindahkan ask OQ P1 business ke **ujung PLAN** (setelah units tertulis) dan lipat: L0 toolchain (#5), Defer/OOS sub-field (#4b), squad-partition bila perlu, ringkasan unit DEFER → **satu `AskUserQuestion` ≤4 item**; ≥5 item = ⌈N/4⌉ call berturut, disclosed.
2. Carve-out `--auto`/`--lite` untuk retrofit bridge + PROJECT_SHAPE low-confidence → **rekam, jangan tanya**.
3. Karantina unit sebagai status resmi (`unit-schema.md` `status: quarantined` + alasan) + tabel karantina di `_summary.md`/laporan akhir dengan satu pertanyaan per unit; dependents skip beralasan. Gate/hook tidak diubah.
4. Halt BLOCKING satu layar (template `propose-and-confirm-prompt.md` dipangkas ke: apa berhenti · satu pertanyaan · opsi).
5. Pin test: replay 3-screen happy path → tepat 2 `AskUserQuestion`; `idle_ratio` run P5 < 20 % (ekstraktor v2 sudah menghitungnya).
6. Keputusan owner yang dibutuhkan: tiga kandidat BLOCKING tambahan (baris C DEFER-loud) — tetap DEFER sesuai aturan, atau dikecualikan. **DIPUTUSKAN 2026-09-10 (runbook otonom + klasifikasi runner, spec F10):** `review_critical_unresolved` → DEFER/karantina; `bolt_introduces_locked_drift` dan `constitution_drift_detected` (lane detect-drift) TETAP BLOCKING sebagai CONFLICT-like (grounding). §D-2 ditutup: override-only, never propose-and-confirm, di semua dok.
