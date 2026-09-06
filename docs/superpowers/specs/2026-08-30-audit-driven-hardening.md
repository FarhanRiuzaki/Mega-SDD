# Spec — hardening dari audit lapangan (tiga tranche)

**Tanggal**: 2026-08-30
**Riset**: `research/2026-08-30-field-audit-triage.md` (triage) atas `HOST-AS400/.mega-sdd/AUDIT-PIPELINE.md` (audit 36 unit / 117 commit).
**Goal user**: "skills … on point dan objektif, hemat token dan cepat" — akurasi dulu, lalu token, lalu mekanisme yang membuat yang akurat tidak bisa dilewati.
**Doktrin**: gates > rules > hooks; "prose that says HALT enforces nothing". Setiap perubahan di bawah ini adalah **mekanisme**, bukan kalimat.

Prinsip pengukuran: sebuah gate yang **tidak pernah bisa gagal** (0 fail atas N evaluasi, counterfactual "dihapus" tidak menghilangkan deteksi) tidak dibayar lagi sebagai gate. Sebuah gate yang **menangkap defect** tapi jarang jalan dibuat tidak bisa dilewati.

---

## 1. Tranche 1 — akurasi gratis, nol surface baru (rilis 7.9.0)

### 1.1 F-09 — dispatch `bolt-implementer` ikut ke gate aggregator

**Terukur**: gate execute-bolts menyala **1×** (09:41) dalam run 117 commit; 22–25 unit mendarat sesudahnya tanpa satu evaluasi gate pun. Sekali menyala, ia memaksa backfill 11 unit tanpa bukti, menangkap scope U-019 yang under-declared, dan orphan U-008 (D-04). Akar: `hooks.json` matcher `Skill|Bash|Edit|Write` — `Agent` **sengaja dikecualikan** dengan asumsi "gated phase = Skill-dispatch only"; run lapangan menjalankan sprint via dispatch manual (HANDOFF) dan asumsi itu adalah prosa.

**Mekanisme**:
- `hooks.json` PreToolUse matcher → `Skill|Bash|Edit|Write|Agent`.
- Fast path (pure shell, 0 fork): `Agent` yang stdin-nya tidak memuat `bolt-implementer` → `exit 0`. Setiap Agent call lain di setiap proyek tetap gratis.
- Python extraction: `tool_name == "Agent"` → `SUBAGENT_TYPE`.
- Sebelum `case "$TOOL_NAME"`: `Agent` + `SUBAGENT_TYPE ∈ {mega-sdd:bolt-implementer, bolt-implementer}` dipetakan ke `TOOL_NAME=Skill`, `SKILL_NAME=mega-sdd:execute-bolts`, `GATE_MODE=in-run`. Branch Skill berjalan **identik** (arming `chain_engaged`, predictive preflight, handoff, factory ledger, aggregator).
- **Semantik in-run** (`GATE_MODE=in-run`) — supaya wave kedua dan fix-round tidak false-deny:
  - **B2 batch-suite dilewati**. Kontrak B2 = "a code-bearing bolt RUN must leave a green full-suite result" — batas run, bukan batas bolt. Tetap menahan di Skill entry (`--all`, `--sprint=n`).
  - **Issue B1 / B4 / orphan untuk unit in-flight dibuang** sebelum verdict. In-flight ⇔ `bolts/U-XXX/dispatch-prompt.md` ada ∧ (`postflight.json` absen ∨ lebih tua dari dispatch-prompt). Postflight adalah artefak TERAKHIR pipeline per unit; dispatch-prompt adalah yang PERTAMA — jendela di antaranya adalah unit yang sah sedang berjalan (commit sudah ada, panel/fix-round/evidence belum). Unit yang tidak in-flight (termasuk dispatch hand-typed tanpa dispatch-prompt) tetap dievaluasi penuh — persis kelas yang D-04 tangkap.
  - Predikat in-flight = satu fungsi `vault_layouts.inflight_units(cwd)`, dipakai juga oleh rel §1.3. Satu definisi, dua konsumen.
- Pesan deny menyebut subjek: `bolt-implementer dispatch (gated as mega-sdd:execute-bolts, in-run)`.

**Biaya**: satu evaluasi aggregator per dispatch bolt (sub-detik macOS; Windows CrowdStrike ~detik) vs bolt ~25 mnt. Agent call non-bolt: 0 fork.

**Test** `tests/hooks/agent-dispatch-gate.test.sh`: (a) `Agent` non-bolt → tanpa output, 0 python; (b) `Agent bolt-implementer` pada fixture ber-moat-FAIL → deny identik dengan Skill `execute-bolts`; (c) in-run: unit in-flight tanpa postflight TIDAK memblokir dispatch-nya sendiri; unit non-in-flight tanpa evidence MEMBLOKIR; (d) B2 FAIL memblokir Skill entry tapi tidak in-run; (e) arming: dispatch Agent menulis `chain_engaged`.

### 1.2 F-06 — `DO_NOT_MODIFY`: touched-set primer, snapshot jadi catatan; guard `mv` ditutup

**Terukur**: 6 halt `DO_NOT_MODIFY` sepanjang run, **semuanya false positive** (sibling unit mengubah `app.ts` secara sah), 0 true positive; pemulihan resminya `mv preflight.json preflight.stale.json` — lolos guard karena regex `mv` hanya mencocokkan argumen kedua; 15 baseline lain kini basi laten (recompute berikutnya false-fail 15 unit).

**Mekanisme** (`scripts/_lib/postflight_rules.py scan_unit`, cabang `DO_NOT_MODIFY`):
```
if unit_commits:            # PRIMER: apakah commit unit INI menyentuh path?
    ok = path not in touched
    ev = "bolt commits did not touch <path>" | "bolt commit touched <path>"
    if snapshot present and sha now != snapshot:   # catatan, bukan verdict
        ev += " (note: sha256 differs from the preflight baseline — changed outside this unit's commits)"
elif snapshot present:      # pre-commit working-tree mode (tidak ada commit unit)
    ok = sha now == snapshot   (byte-identik dengan sebelumnya)
else:
    cannot verify → fail    (tidak berubah)
```
Rename tetap terlihat: `walk_unit_commits` mencatat `git mv locked new` sebagai `D old` (S7-HARDRULES-6, tidak berubah). Laundering via commit tanpa identitas unit ditangkap B2 out-of-band (D-03), bukan oleh snapshot.

Guard: `\bmv\s+[^|;&]*($PROTECTED)` — posisi argumen mana pun. `cp` tetap destinasi saja (menyalin artefak keluar = membaca).

Dokumen yang menyatakan "snapshot precedence" (CLAUDE.md, header `run-preflight-scan.sh`, header test guard) dikoreksi. Refusal exit 7/8 penulis baseline **tetap** (belt-and-braces; tidak ada alasan membuka).

**Test** `tests/postflight-evidence/test-do-not-modify-touched-set.sh`: sibling commit mengubah locked path setelah baseline U-001 → recompute U-001 **pass** (dengan note); commit U-001 sendiri menyentuh → **fail**; tanpa commit unit + snapshot → semantik lama. `test-preflight-guard.sh` +1 kasus: `mv preflight.json preflight.stale.json` → deny.

### 1.3 F-16 — rel commit selama bolt in-flight

**Terukur**: wave berjalan di satu working tree; commit BLOCKER `bc221b8` menyapu 1.031 baris test setengah-jadi milik U-022/U-029; `git commit --amend` 11× (sekali menyapu 8 file); 6/9 bolt-report sprint tengah melaporkan noise sibling. 7.7.0 membalik default `--all` ke wave **tanpa rel** — paparan naik.

**Mekanisme** (hook, Bash branch, sebelum fast-exit GUARD_SKIP):
- Python fold (sudah ada untuk Bash) mengevaluasi regex bentuk berbahaya per segmen perintah (kutipan dibuang dulu; heredoc dipotong di `<<`): `git add -A|--all|.`, `git commit -a|-am|--all|--amend`, `git stash [push|save]`, `git reset --hard`. Emit `WAVE_HAZARD=1` (0 fork tambahan).
- Shell: `WAVE_HAZARD=1` → satu python memanggil `vault_layouts.inflight_units(root)`; ≥1 unit in-flight → **deny** dengan daftar unit + remediasi ("stage by explicit pathspec: `git add <path>…`; commit `-m` tanpa `-a`; jangan `--amend`/`stash`/`reset --hard` selama bolt berjalan").
- Fast path tier-S: fragmen `--amend`, `-A`, `--all`, `stash`, `--hard`, `commit -a`, `add .` masuk daftar substring → sesi un-armed pun membayar satu python hanya pada bentuk itu (kasus nyata: sesi kedua di worktree yang sama).
- Plugin-dev mode (CWD = repo plugin) → rel off, seperti guard lain.
- Kontrak agen `bolt-implementer.md` langkah 6: stage by pathspec (`target_files` ∪ extras yang kamu buat), never `-A/-a/.`; never `--amend`/`stash`. `batch-and-fanout.md` §valves: controller pun commit ber-pathspec.

Yang TIDAK dibangun: worktree per bolt sebagai default (`--worktree` sudah ada sebagai opt-in; memaksanya = biaya `cd`/install deps per bolt untuk setiap proyek — belum diukur).

**Test** `tests/wave-rail/test-wave-commit-rail.sh`: fixture 1 unit in-flight → `git add -A` deny, `git add src/a.ts` allow, `git commit -am` deny, `git commit -m` allow, `git commit --amend` deny, `git stash` deny, `git stash pop` allow, `git reset --hard` deny, pesan commit berisi kata `add .`/`-a` di dalam kutipan TIDAK deny; postflight lebih baru dari dispatch → `git add -A` allow; sesi un-armed + hazard → tetap deny (fragmen); plugin-dev → allow.

### 1.4 Dokumentasi & versi
- `CLAUDE.md` plugin: matcher + kalimat precedence; `docs/mega-sdd/architecture.md` matcher; header hook.
- CHANGELOG 7.9.0; plugin.json + marketplace.json 7.9.0; SKILL execute-bolts 2.41.0 (reference berubah).

---

## 2. Tranche 2 — potong token, nol deteksi hilang (rilis 7.10.0)

### 2.1 F-30 — emisi dispatch bersyarat
- `reuse-index.yaml` line: hanya bila file ada (builder sudah tahu absen — 36/36 omission tercetak).
- `kb_anti_patterns` / `historical_memory` omission lines: hapus (residu skema lama / v7.3.0).
- Blok Anti-context DB/host (±3,7 KB): emit hanya bila `target_files` unit menyentuh lapisan yang dilindungi (glob per target; frontend murni tidak menerima blok DB).
- Ukur: byte T1 per dispatch sebelum/sesudah di 36 dispatch lapangan; jumlah dispatch yang T1-nya melewati cap (≥5 → target 0) sehingga cascade T2 tidak lagi memangkas `symbol_slice`/`design_slice`.

### 2.2 F-01(a) — directive keluar dari status gate
- `postflight.json`: `status` = fungsi rule **mesin** saja; directive dilaporkan di `attested_by` (string atestasi + `attested_at`), tidak ikut `ok_all`.
- Gate B1 membaca `status`; directive tanpa atestasi = `directive_unverified` **advisory** (surfaced, non-gating).
- Carry-forward tetap; prefix "carried" tidak lagi bertumpuk (idempoten).
- Counterfactual terukur: 0 deteksi hilang (256 directive, 0 fail sepanjang run).
- Generate-units: advisory `hard_rules_directive_ratio` bila directive > 80% — mendorong rule ke produksi v1/v2. Bukan gate.

### 2.3 F-31 — artefak tanpa konsumen → **DITOLAK untuk tranche ini (diukur 2026-08-30)**
Sensus di plugin: `_index.md` dirujuk 13 file (analyze, orchestrate-flow, generate-intent/units), `ai-consumer-guide.md` punya pembaca (generate-intent self-check) + 3 pin test (sudah di-diet di spec boilerplate-diet), `modules.yaml.auto` dibaca `query-graph.sh` + pin 5d. "Tanpa konsumen" benar di RUN lapangan (tidak ada skrip yang membacanya di run itu), tidak benar di plugin. Implementer tidak pernah membaca ketiganya → biaya token per bolt **nol**. Menghapus = sweep prosa 3 skill + 5 pin untuk hemat byte vault yang tidak dibaca siapa pun di jalur panas. Tidak dibangun. 6 validator SKIP-struktural di aggregator: tetap (sub-detik, paralel).

### 2.4 Hasil Tranche 2 (7.10.0)
- **F-01(a) SHIPPED**: `ok_all` dari rule mesin saja; `_looks_pass` melewati rule directive; writer mencatat `directives:{total,attested,unverified}` dan exit 0 pada directive tak-teratestasi; carry-forward idempoten; `hard_rules_directive_advisory` di `.unit-spec-state.json` (>80%, ≥5 rule). Pin lama (D0, M-05a, r1-4, r2-2) di-repin ke kontrak baru.
- **F-30 SHIPPED sebagian**: reuse-index T1 line kondisional (36/36 lapangan menunjuk file absen), pointer KB T3 = root yang ada (path `10-domains/` mati 36/36), 2 omission struktural keluar dari appendix prompt (tetap di stdout), tracker dipadatkan. Golden corpus di-regen.
- **F-30 item 3 (blok Anti-context DB/host bersyarat per lapisan `target_files`) — DITUTUP TANPA DIBANGUN (dicatat 7.29.1):** putusan 7.28.0 (size-weighted §1b) berlaku — entri `DO NOT MODIFY` = proteksi field [LOCKED], bukan diet; unit "frontend murni" tetap bisa menyentuh field DB-LOCKED lewat jalur kode bersama, jadi omission bersyarat = proteksi bersyarat. Pengukuran byte T1 (§5) ditunda ke field run berikutnya — tidak ada instrumen in-plugin (no-observability v7.3.0); dibuka lagi hanya dengan bukti lapangan.
- **DITOLAK dengan angka**: grouping `(source:)` per grup di Anti-context — ~1,2 KB/dispatch vs rail label-per-entri (7 pin + 2 parser). Pemangkasan `design_slice` (−6 KB unit UI) BUKAN item diet: salinan lens-input sengaja teks terpotong yang sama (satu kontrak implementer↔reviewer) → milik F-15.
- **Koreksi klaim audit**: cascade T2 dipicu `cap_t2` atas konsumsi T2 saja — T1 tidak pernah dipotong dan tidak mendorong cascade; memadatkan Anti-context (T1) = diet token murni, bukan lever akurasi.

---

## 3. Tranche 3 — yang bagus jadi wajib (rilis 7.11.0)

### 3.1 F-07 — gate `panel-evidence`
Unit yang router-nya `standard`/`full` (dari `resolve-review-tier.sh`, dipersistenkan §3.4) wajib punya `findings.json` ber-skema (`schema: 1`, `written_by: merge-panel-findings.sh`) sebelum postflight-nya sah. Gate di aggregator (state `.bolt-panel-state.json`, re-derive). L0 (`l0-results.json`) wajib untuk unit code-bearing; ditulis SEKALI — edit tangan = forged.

### 3.2 F-08 — `findings.json` masuk guard
Daftar PROTECTED + FP_GUARD + fragmen fast-path: `bolts/[^\s]*findings\.json` dan `l0-results\.json`. Sole-writer menjadi mekanisme, bukan kalimat.

### 3.3 F-18 — `expects` wajib
`run-acceptance-tests.sh`: entri `type: test` dengan `expects` kosong → `acceptance_expects_missing` (halt baru, registered); `validate-unit-spec.sh` menolak saat generate. `output_head` 500 B → 2 KB + `tail` 500 B sehingga angka pass/fail terekam.

### 3.4 F-26 — stempel provenance
Semua writer artefak (`preflight/postflight/acceptance/findings/l0/_batch-suite`) + file state: `plugin_version` (dibaca dari `plugin.json` di plugin root), `written_at`, `duration_ms` bila mengeksekusi. `resolve-review-tier.sh` menulis `bolts/U-XXX/review-tier.json` (`tier`, `lenses[]`, `signals_fired`) — konsumen: F-07, bolt-report, audit berikutnya.

---

### 3.5 Hasil Tranche 3 (7.11.0)
- **F-07 SHIPPED**: kunci obligasi = `review-tier.json` (ditulis `resolve-review-tier.sh --write` saat dispatch — preseden B4, bolt lama = advisory); `validate-bolt-artifacts.sh --panel-scan` → `.bolt-panel-state.json`; halt `panel_evidence_missing` (tier ≠ minimal tanpa ledger ber-`written_by: merge-panel-findings.sh`) + `l0_evidence_missing` (tanpa `l0-results.json` ber-`written_by: run-code-gates.sh`); `run-code-gates.sh --write` menulis rekaman L0 sendiri; aggregator memblokir (in-run: unit in-flight dibuang), Stop lane mendeteksi.
- **F-08 SHIPPED**: `findings.json`, `l0-results.json`, `review-tier.json` masuk guard Bash + Write/Edit (kedua salinan regex + FP_GUARD); writer resmi lolos karena perintahnya tidak menyebut nama file.
- **F-18 SHIPPED (per unit, in-run)**: `acceptance_expects_missing` dari `validate-unit-spec.sh`; gate hanya pada dispatch unit itu sendiri (id unit dibaca dari pointer dispatch), tidak pernah di batas run; writer mencatat `expects_missing` + `output_tail`.
- **F-26 SHIPPED (artefak)**: `_lib/plugin_meta.py`; `plugin_version` + `written_at` (+ `duration_ms` acceptance) di semua artefak bukti + `review-tier.json` + `.bolt-panel-state.json`. Belum: file state validator lain (re-derive tiap gate; bukan blind spot audit).
- Registry: 3 halt baru (enum, family, canonical list, taxonomy always-stop); tripwire ukuran dinaikkan sebatas entri terse (32300 / 13500 B) dengan alasan di test.

## 4. Yang ditolak / ditunda (tercatat di riset §2)
F-01(b) per-rule attestation (×5–11 beban), gate pack-driven (ukur setelah F-14), F-03 (spec sendiri), F-04/F-05 (spec sendiri), F-12 (setelah ledger), backlog r2–r3.

## 6. F-14 — pack proyek yang benar-benar resolve (rilis 7.12.0, SHIPPED)

**Terukur**: run lapangan menulis `.mega-sdd/packs/elysia.md`; tidak ada satu pun konsumen yang membacanya. Resolver hanya melihat root plugin; matcher GROUND hanya membaca manifest root (dependency `elysia` ada di `apps/api/package.json`); `state.json` ditulis pra-git dan tidak pernah diregenerasi; `ground.sh` mencari di dua direktori lain. Akibat: 36/36 dispatch `_universal`, 5 gate pack-driven SKIP sepanjang run → **tidak bisa dinilai** (bukan "tidak berguna").

**Mekanisme**: root pack proyek kanonis `<root>/.mega-sdd/packs/`; resolver membaca root proyek dulu (shadowing nama sama, `extends:` lintas root) dan menjalankan matcher **live** (implementasi yang sama dengan step 3, bukan sniff kedua) bila tidak ada sumber nama; input cache = dir pack proyek + file-nya + manifest root & workspace satu tingkat. `state_probes`: pack proyek dibaca dulu (prioritas 50), `probe_workspace_manifests()` (`apps/* packages/* services/* libs/*`) hanya untuk matcher. `ground.sh` ikut. Test: `tests/audit-hardening/test-f14-project-pack.sh`.

**Yang dibuka**: pengukuran 5 gate pack-driven di run berikutnya. Keputusan hapus/pertahankan tetap menunggu angka.

## 5. Pengukuran setelah tranche
- T1: jumlah evaluasi gate per run (target: ≥1 per dispatch bolt); FP `DO_NOT_MODIFY` (target 0 pada replay 36 unit); commit sapu (target 0).
- T2: byte T1 per dispatch; jumlah `status: fail` postflight yang berasal dari rule mesin vs directive (target: directive 0 dari verdict).
- T3: unit tanpa `findings.json` di tier ≥ standard (target 0); `expects` kosong (target 0).
Run lapangan berikutnya di HOST-AS400 (atau proyek berikutnya) adalah before/after pertama yang teramati; 7.8.0 adalah baseline.
