# Spec — unit granularity coarsening + cohesion advisory (7.20.0)

**Research:** `research/2026-09-01-sprint-subagent-granularity.md` (masukan tim 2026-09-01:
"1 subagent per sprint isi 5 unit yang relate"). Verdict riset: sprint-SUBAGENT = REJECT on
the record (depth-1 runtime limit, preseden `squad-subagent.md`; context decay ~80 turn/unit;
saving ≈ 0 karena dispatch sudah pointer-based) — lever yang benar ada di HULU: ukuran unit.
Owner gas 2026-09-01 dengan angka konservatif; contoh nyata dari tim nanti jadi kalibrasi.

## Goal

3 unit kecil yang berantai bisa lahir (atau di-merge) sebagai 1 unit yang lebih gemuk →
1 subagent, 1 commit, 1 review panel — semua gate per-unit tetap utuh karena unit tetap
satuan kontraknya. Merge menang HANYA pada unit berantai (chained); unit independen se-wave
sudah paralel sejak 7.7.0 dan merge justru menserialisasi — heuristik advisory menarget
rantai saja.

## B — knob coarsening di generate-units

1. **Flag** `--max-complexity=small|medium|large` (extend enum; `large` baru).
   Semantik Step 3 (Group + atomize):
   - `medium` (DEFAULT, tidak berubah): < 300 LOC dan ≤ 5 files → single unit.
   - `large`: < **600 LOC** dan ≤ **8 files** → single unit ("story-sized"; buat tim yang
     review-nya per story). Angka konservatif — kalibrasi ulang setelah contoh tim masuk.
   - `small`: authoring judgment lebih ketat (tidak diberi angka; perilaku lama).
   Threshold tetap **authoring judgment — advisory, tanpa validator** (kontrak
   `unit-schema.md §Atomicity` tidak berubah kelasnya).
2. **Config** `.mega-sdd/config.yaml` → `unit_granularity: fine|coarse`
   (fine→small, coarse→large; absen→medium). **Precedence: flag > config > default** —
   pola yang sama dengan `--model-tier` (spec 2026-08-22 per-unit model routing).
3. **Plumbing:** TIDAK ada flag baru — enum extension menumpang flag yang sudah ada
   (satu-satunya surface = SKILL.md line flags; grep 2026-09-01: nol routing row / test pin).
   Config dibaca inline oleh skill di resolve-granularity (pola `render_html: off`).

## C — cohesion advisory di lint-units

Tambahan satu check di `diagnostics-procedures.md §lint-units Step 3` (cross-unit,
deterministik, read-only):

- **Merge-candidate (cohesion)** — flag sebuah rantai `depends_on` LINEAR dengan ≥2 unit
  yang SEMUANYA memenuhi: (a) `module:` sama; (b) `task_type: create|extend` (verify tidak
  dihitung — no-code, murah); (c) `target_files` ≤ 2 per unit; (d) tanpa `## Hard rules`;
  (e) tanpa `properties:` (PBT); (f) rantai self-contained — tidak ada unit luar-rantai yang
  `depends_on` unit tengah rantai (merge tidak mengubah bentuk DAG bagi unit lain; dependent
  pada KEPALA/EKOR rantai boleh).
- Emisi: `merge_candidate: U-00X..U-00Z — N unit kecil berantai se-module; merge = 1 bolt +
  1 panel, gabungan diperkirakan masih ≤ threshold. Remedy: --regenerate --max-complexity=large,
  atau edit manual lalu re-run lint.`
- Kelas: **ADVISORY selamanya** — never a halt, never auto-merge (propose-first; preseden
  moat-takeout + delta lane). Masuk Step 4 recommendations seperti temuan lain.

## Yang TIDAK berubah (rails)

- Eksekusi tetap per-unit: bolt-implementer + review panel + pre/postflight + acceptance
  per unit. Tidak ada "sprint subagent" — ditolak on the record di riset (E1–E3).
- Default granularity tetap medium/300 LOC — blast radius review per bolt adalah alasan
  threshold itu ada; coarse = opt-in.
- ID-stability contract (`--refresh`/`--reconcile`, content-hash) tidak tersentuh; merge
  manual/regenerate memakai jalur yang sudah ada.

## Tests (repo-root `tests/unit-granularity/`)

Pin: (A) enum 3 nilai + semantik large 600/8 di SKILL.md; (B) config key + precedence line;
(C) default 300/5 tidak bergeser; (D) unit-schema tetap menyebut advisory-no-validator +
knob; (E) advisory merge_candidate lengkap dengan 6 kriteria + never-halt/never-auto-merge;
(F) guard preseden: `squad-subagent.md` masih memuat "NEVER forks a squad subagent"
(rasional depth-1 yang juga menolak sprint-subagent).

## Versions

generate-units 2.24.0→2.25.0 · orchestrate-flow (ref edit) bump patch · plugin 7.19.0→7.20.0
(marketplace.json match).
