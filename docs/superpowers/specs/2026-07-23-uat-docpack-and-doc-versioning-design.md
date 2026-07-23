# UAT doc-pack + document versioning — design spec

**Date:** 2026-07-23
**Status:** Approved by user (brainstorm session, 4 shaping decisions locked)
**Scope:** Two features shipped as one coherent change set: (A) a 4th team document — the UAT test-script doc-pack `emit-uat` — and (B) a script-owned document-versioning engine applied to all four emitted docs (PRD, FSD, SIT, UAT). Plus (C) the plumbing both need.

---

## 1. Context and research grounding

The emission pipeline today ships three doc-packs (`emit-prd`, `emit-fsd`, `emit-sit`) on the shared 8-step spine in `references/emission-engine.md`, dispatched via `/mega-sdd:emit <doc>`. Doc control is the script-owned stamp written by `scripts/refresh-doc-stamps.sh` with exactly three fields (`maturity`, `position`, `generated_at`). **Document versioning does not exist**: no revision numbers, no revision-history table, no baselining, no per-emission archive; docs are overwritten in place at `<vault>/<doc>/<DOC>.md`. Template frontmatter `version:` mirrors the *source* (vault) version, not the doc revision.

The design below is grounded in (verified during the research phase, primary sources):

- **ISO/IEC/IEEE 29119-3:2021** — Clause 5 common information for all test documentation: unique identifier, issuing organization, approval authority, **change history**, **status**. Test Case Specification (8.3): per-case unique ID, objective, priority, traceability, preconditions, inputs, expected results, actual-result placeholders. Test Procedure Specification (8.4).
- **IEEE 829-2008** — Level Test Case (cl. 11) and Level Test Procedure (cl. 12) field outlines; document identifier + change-history requirements (8.1.1, 8.3.2): sequential version numbers from first approved version, status draft/reviewed/corrected/final.
- **ISTQB CTFL v4.0.1 §4.5.2–4.5.3 + CT-AcT v1.0** — acceptance criteria as test conditions; acceptance test cases derived from them; traceability requirement; business-language, non-technical UAT reporting.
- **SEOJK 21/SEOJK.03/2017 Lampiran §2.3.1.5 (OJK)** — SIT is performed by the developer; UAT is the final test by **end users**; UAT may start only after the developer's **berita acara SIT**; a user-approved **berita acara UAT** is mandatory before implementation.
- **Industry template intersection** (6 independent templates incl. regulated Veeva/Veracity Logic, Smartsheet PDF, BrowserStack, Ybug): ID, scenario, preconditions, test data, numbered step actions, expected result, actual result, Pass/Fail/Blocked status, tester, date, defect ref, evidence ref, per-case signature attestation.
- **Versioning conventions** — classic doc control (0.x drafts → 1.0 first approved; minor bump = no re-approval, whole-number bump = approval event; revision table Version|Author|Date|Changes); Veeva Vault status lifecycle (Draft → Approved/Effective → Superseded); FDA/IEC 62304 docs-as-code analysis: git is an acceptable audit trail **but** auditors expect a visible, in-document version-history table *generated from git*, never hand-maintained; Keep a Changelog: curated one-line entries, not raw commit logs.

## 2. Decisions locked with the user

1. **UAT doc scope** — one document: test scripts + compact RTM + berita acara UAT page (SIT sign-off pattern). Not a full UAT pack (no separate plan/summary-report docs).
2. **Versioning design** — hybrid script-owned: `version` + `status` stamp fields, visible auto-generated "Riwayat Revisi" table, 0.x auto-bump per emission, 1.0/2.0 minted only by a human-run approval flag. Applies to **all four** docs.
3. **Scenario basis** — **1:1 per vault flow `F-*`**, IDs `UAT-NNN` aligned with SIT's `TS-NNN`.
4. **Excel render** — real `.xlsx` written with **python3 stdlib only** (zipfile + OOXML XML; zero new dependencies). CSV and openpyxl were considered and rejected (CSV: not a real Excel format, locale/delimiter issues; openpyxl: new pip dependency).

---

## 3. Design A — the `emit-uat` doc-pack

### 3.1 Lane contract

- Skill `skills/emit-uat/` (SKILL.md + `references/uat-sections.md` + `references/uat-template.md`), doc-pack v1.0.0, on the mandatory 8-step spine.
- Dispatch: `/mega-sdd:emit uat`.
- Outputs in `<vault>/uat/`: `UAT.md`, `UAT.pdf` (md2pdf GitHub-style, never LaTeX), `UAT-v<version>.xlsx`, `.citation-map.json`, `.uat-scaffold.md` (sidecar, script-generated fragments).
- Language: Indonesian business narrative + Indonesian section headers (SIT precedent); Tier-1 structural tokens stay English (`Pass`/`Fail`/`Blocked`, IDs, `[Source: …]`, enum values). Interactive prompts carry keterangan.
- Mermaid hard rule applies: each scenario carries its flow's Mermaid diagram **verbatim** (never redrawn, never prose-only).

### 3.2 UAT.md structure (4 sections)

**Header** — template frontmatter (title, source/vault version, date, classification) + script-owned doc-control stamp + revision-history region (Design B) + Dokumen Referensi table (PRD / FSD / SIT paths + their doc versions) + test cycle + UAT window + environment rows as placeholder literals.

- **§1 Ruang Lingkup & Kriteria** — scope narrative (model, from vault); **entry criteria** table whose rows include "Berita acara SIT tersedia" (SEOJK gate) as a placeholder-literal checkbox; exit criteria table. The scaffold script probes SIT's doc-control stamp: if `SIT.md` is missing or its maturity ≠ `executed`, the skill surfaces a **warning callout** in §1 (not a halt — preparing UAT scripts early is legitimate).
- **§2 Skenario UAT** — one block per vault flow `F-*`, ID `UAT-NNN` numbered in the same order as SIT's `TS-NNN`. Per block: business scenario name, linked FR id(s) + `F-id`, priority, preconditions, test data, flow Mermaid verbatim, then the step table:

  `| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |`

  - **Aksi**: model-written business-language steps derived from the flow's nodes (translation, each step traceable to a node — no invented steps).
  - **Expected Result**: DoD items carried **verbatim** (source-cited).
  - **Actual Result / Status / Defect / Bukti**: placeholder literals forever (`__________`, `[ ] Pass · [ ] Fail · [ ] Blocked`). Filled by humans during execution, never by the tool.
  - Per-script footer: Tester / Tanggal / Tanda tangan placeholder rows (+ optional reviewer row).
- **§3 Matriks Traceability (RTM)** — fully script-generated, carried verbatim: `| FR | Flow (F-id) | UAT | TS (SIT) | Status |` with Status as placeholder literal.
- **§4 Berita Acara UAT** — sign-off page, placeholder literals only: nama, peran, tanda tangan, tanggal, outstanding defects table, keputusan `[ ] Go · [ ] No-Go`. Mirrors SEOJK §2.3.1.5's mandatory user-approved berita acara.

### 3.3 Scaffold + gate script: `scripts/build-uat-scaffold.sh`

Follows the `build-sit-evidence.sh` precedent (script computes; model narrates).

- **Default mode** — writes `<vault>/uat/.uat-scaffold.md`: per-flow scenario skeletons (IDs, titles, F-id, linked FRs via the unit↔flow mapping, Mermaid verbatim, DoD list, empty step-table skeleton with placeholder execution columns, tester footer), the §3 RTM table, the §4 berita acara skeleton, and the §1 criteria skeletons + SIT-maturity probe result. Fragments are delimited (`<!-- uat-scaffold:§N -->`) and carried verbatim into UAT.md, except §2's `Aksi` cells and per-section narrative, which the model writes.
- **`--check-execution` mode** (Step 4.7 gate) — deterministic scan of the assembled UAT.md: any filled `Actual Result`/`Status`/`Defect`/`Bukti` cell, filled tester footer, or filled berita-acara row ⇒ nonzero exit ⇒ halt **`execution_fabricated`** (`source_skill: emit-uat`). The tool can never fabricate a UAT execution record. Multi-scope aware.

### 3.4 Maturity ladder

`draft` (model-set at every emit) → `ready-for-uat` (human-set) → `signed-off` (human-set). The model always stamps `draft` — self-promoting would be a fabricated approval state (PRD precedent).

### 3.5 Multi-scope

`--vaults=csv` mirrors SIT: ONE merged UAT in the first vault's `uat/`, IDs `UAT-<SCOPE>-NNN`, Scope column in §3/Rekap, per-scope berita acara tables in §4. Ships in v1 so UAT numbering stays aligned with merged-SIT `TS-<SCOPE>-NNN` from day one.

### 3.6 Excel render: `scripts/build-uat-xlsx.sh`

- python3 **stdlib only** (`zipfile` + minimal OOXML: workbook, worksheets with inline strings, basic styles). No pip dependencies.
- Runs **after** the `--check-execution` gate and **after** the doc-control/version stamp (it needs the doc version), parsing the assembled UAT.md's delimited regions.
- Workbook: sheet **Rekap** (all scenarios: ID, judul, FR, tester/tanggal/status blank), sheet **RTM**, one sheet per `UAT-NNN` (scenario header block + full step table with empty execution columns). Styling floor: bold header row, sensible column widths, frozen header row.
- Output `UAT-v<version>.xlsx` — the filename carries the doc version from `.doc-history.json`, so every emission produces a **new** file and a tester-filled workbook is never clobbered. If the target filename already exists, the script refuses and warns (the skill surfaces: rename/remove manually to regenerate); it never overwrites.
- Render failure or refusal is **warn-only** for the emission (PDF/mmdc precedent) — the md remains canonical.

---

## 4. Design B — document versioning engine (all four docs)

### 4.1 State sidecar: `<vault>/<doc>/.doc-history.json`

Docs are overwritten in place, so history must live outside the doc. Script-owned JSON:

```json
{
  "schema": 1,
  "doc": "fsd",
  "version": "0.3",
  "status": "draft",
  "history": [
    { "version": "0.1", "date": "<ISO8601>", "actor": "emit (model-run)", "commit": "<git short hash>", "note": "Emisi awal" },
    { "version": "1.0", "date": "<ISO8601>", "actor": "Nama, Peran", "commit": "<git short hash>", "note": "Approved", "event": "approval" }
  ]
}
```

### 4.2 `refresh-doc-stamps.sh` extensions (stays the single owner of doc control)

- **New stamp fields**: `version`, `status` (`draft` | `approved`) appended to the FIELDS tuple. Back-compat: existing stamps gain the fields on next refresh; docs with no sidecar are initialized lazily.
- **New flags**:
  - `--bump --change-note="…"` — emission event: minor-bump (`0.1` on first emission, `0.2`, …; `1.1` after an approval), append a history row (actor `emit (model-run)`, commit from `git rev-parse --short HEAD`, note required), set `status=draft`.
  - `--approve --approver="Nama, Peran"` — human-run governance event: mint the next whole version (`0.x → 1.0`, `1.x → 2.0`), `status=approved`, append row with `"event": "approval"`. Never invoked by the model on its own initiative — same doctrine as PRD `reviewed`/`final`.
  - Refresh calls without `--bump`/`--approve` (e.g. orchestrate-flow's `--position`-only chain-boundary refreshes) leave version/status/history untouched.
- **Visible "Riwayat Revisi" table** — rendered by the script from the sidecar into a script-owned delimited region (`<!-- mega-sdd:revision-history -->` … `<!-- /mega-sdd:revision-history -->`) placed immediately after the doc-control comment: `| Versi | Tanggal | Oleh | Perubahan |`, latest first. The model never types this region; templates carry the empty delimiter pair. Idempotent, atomic, byte-identical no-op when unchanged — same guarantees as the existing stamp.
- This satisfies 29119-3 Clause 5 (identifier, change history, status) and the audit expectation of a visible, auto-generated version history; hand-maintained numbers are explicitly rejected.

### 4.3 Change-note discipline

The note is **derived, not free prose**: the emitting skill composes it from the `check-citation-drift.sh` output (e.g. `"Regenerasi §2, §5 — 3 sumber berubah"`; first emission `"Emisi awal"`). Rule recorded in `emission-engine.md` alongside the anti-halu rails.

### 4.4 Integration

- Every emit skill's final stamp step becomes `refresh-doc-stamps.sh --doc=<doc> --maturity=<…> --generated-at=<now> --bump --change-note="<derived>"`.
- Frontmatter `version:` fields are **unchanged** — they mirror the source/vault version. The doc revision lives in the stamp + Riwayat Revisi + xlsx filename. `uat-template.md` labels the frontmatter field "Versi sumber (vault)" to preempt confusion; existing templates keep their current label (no churn).
- `emission-engine.md` documents versioning as part of the stamp step of the spine and updates the doc-pack registry.

---

## 5. Design C — plumbing

- `commands/emit.md`: dispatch row `uat` → `mega-sdd:emit-uat`; no-arg maturity listing probes the fourth path.
- `commands/mega-sdd.md` (`<prd|fsd|sit|uat>` at both enumeration points) and `skills/using-mega-sdd/SKILL.md` (routing census + trigger keywords: UAT, test script, skrip uji, berita acara).
- `references/emission-engine.md`: registry row + maturity-ladder registry + versioning rules.
- `references/paths.md`: add `uat/` (and the missing `prd/`, `sit/` siblings) to the canonical vault tree; fix the stale `pandoc + LaTeX` comment at paths.md:48 (md2pdf is the standard).
- Tests: update `tests/derived-artifacts/test-p3-emission-parity.sh` (FSD template gains the revision-history delimiter pair); new tests for `refresh-doc-stamps.sh` version/approve semantics, `build-uat-scaffold.sh` (scaffold + `--check-execution` gate), and `build-uat-xlsx.sh` (valid xlsx: unzippable, expected sheets, refuses overwrite). Blackbox pipeline stage if applicable.
- No new hooks (in-skill slot scan + sidecar script gates — SIT/PRD precedent). No deprecated alias needed (new doc).
- `plugin.json` + `marketplace.json` bump **minor** and stay in lockstep.

## 6. Out of scope (explicit)

- Separate UAT plan / UAT summary-report documents (fast-follow candidates if real need appears).
- Git-tag baselines + archived approved PDF snapshots ("Hybrid + git-tag baselines" option — deferred).
- Excel render for SIT's §3 TC matrix (the xlsx writer is built reusable-shaped, but no SIT lane in v1).
- Reading filled xlsx back into the pipeline (execution-result ingestion) — UAT results return via berita acara, on paper.

## 7. Acceptance criteria

1. `/mega-sdd:emit uat` on a vault with flows + units produces `UAT.md` + `UAT.pdf` + `UAT-v0.1.xlsx` + `.citation-map.json`, with §2 1:1 per `F-*`, IDs aligned to SIT `TS` numbering, all execution columns placeholder-literal.
2. `build-uat-scaffold.sh --check-execution` exits nonzero on any filled execution/berita-acara cell (halt `execution_fabricated`); clean doc passes.
3. `UAT-v0.1.xlsx` opens in Excel/LibreOffice: Rekap + RTM + per-scenario sheets, bold frozen headers, empty execution columns; a second emission writes `UAT-v0.2.xlsx` and never touches v0.1; existing target ⇒ refuse + warn.
4. After any full emission of any of the four docs: stamp carries `version` + `status`, sidecar `.doc-history.json` gains one row, and the rendered doc shows the Riwayat Revisi table with the derived change note.
5. `refresh-doc-stamps.sh --approve --approver="X, QA Lead"` mints 1.0/2.0 + `status=approved`; the next emission returns status to `draft` with a minor bump. `--position`-only refreshes change nothing version-related.
6. FSD emission parity test updated and green; full test suites (both trees) green; SIT maturity probe missing/≠executed yields the §1 warning callout, not a halt.
