# UAT Section Mapping — Source Artifact → UAT Section

> **Per-section: source artifact(s), extraction rules, citation format, missing-source placeholders.**
> Consumed by `emit-uat/SKILL.md` Step 2 (per-section emission loop). This file is the UAT doc-pack's
> **section map** for the shared emission engine (`plugins/mega-sdd/references/emission-engine.md`
> §What a doc-pack supplies).
>
> **The prime directive:** every table, RTM row, berita-acara cell, and sign-off table is produced by
> `scripts/build-uat-scaffold.sh` into `<vault>/uat/.uat-scaffold.md` and included **VERBATIM**
> (delimiters `<!-- uat-scaffold:§N -->` … `<!-- /uat-scaffold:§N -->`). The model contributes the
> per-section Indonesian narrative AND — the **ONE sanctioned in-fragment edit** — replaces each
> `<!-- uat-steps:UAT-NNN -->` marker with step rows. This is what makes the UAT record unfakeable:
> execution results, RTM status, and sign-off never pass through model text generation.

## Contents

- Maturity ladder (always draft at emit)
- Multi-scope rules (decision 10)
- Section 1 — Ruang Lingkup & Kriteria
- Section 2 — Skenario UAT
- Section 3 — Matriks Traceability (RTM)
- Section 4 — Berita Acara UAT
- Citation notes
- Drift callouts

## Maturity ladder (always draft at emit)

The UAT maturity ladder is `draft → ready-for-uat → signed-off`. `build-uat-scaffold.sh` ALWAYS prints
`maturity=draft` (its stdout `uat-scaffold: maturity=draft …` line) and the fragment header stamps
`maturity: draft`. That verdict IS the doc's maturity at emit; the model never computes or overrides it.

The upper rungs are HUMAN-set only, via `refresh-doc-stamps.sh --maturity=ready-for-uat|signed-off`
(mirrors the SIT §5 / PRD `reviewed`→`final` precedent). A model that self-promotes past `draft`
fabricates an approval state — the worst failure in a bank UAT context. The model passes `--maturity=draft`
in SKILL Step 6 and nothing higher; it NEVER passes `--approve`.

## Multi-scope rules (decision 10, locked)

ONE merged UAT for a multi-scope project: `--vaults=<v1>,<v2>` → `build-uat-scaffold.sh --vault=<v1> --vault=<v2>`.

- Ids carry the scope when the vault's `vault.json scope_metadata.id` is set: `UAT-BE-001` (aligned 1:1 with
  `TS-BE-001` from the SIT). Plain `UAT-NNN` / `TS-NNN` for a single unscoped vault.
- §1/§3 tables gain a leading `Scope` column; §4 emits one sign-off table PER scope (`### Sign-off — Scope <ID>`).
- The merged doc lands in the FIRST vault's `uat/` dir.

UAT numbering: 1:1 from `F-*-NNN` — the flow's numeric part when unique within the vault; ordinal fallback
on a numeric collision (deterministic, script-owned — IDENTICAL to SIT's TS derivation so `UAT-NNN ↔ TS-NNN`
pair 1:1).

## Section 1 — Ruang Lingkup & Kriteria

**Slot:** `{{section-1-narrative}}` + fragment block §1
**Source:** `<vault>/04-flows.md` (F-* flows in scope) + the SIT doc-control maturity probe (`<vault>/sit/SIT.md`)
**Fragment carries:** the flows-in-scope table (UAT ↔ TS ↔ F-id ↔ judul ↔ tipe) + the entry-criteria table
(incl. the SEOJK berita-acara-SIT gate row + the probed SIT maturity) + the exit-criteria table + citation footer.
**Narrative (model):** 2–4 kalimat Indonesia — cakupan uji (flow apa saja, scope mana), siapa yang mengeksekusi
(tim bisnis, bahasa non-teknis, bukan pengembang), dan status entry gate SEOJK.
**SIT-not-executed callout:** when the scaffold printed a `WARN_SIT` line (SIT maturity absent or ≠ `executed`),
PREPEND this block quote to the narrative verbatim:

```markdown
> ⚠ **SIT belum executed** — SEOJK 21/2017 §2.3.1.5: UAT hanya boleh dimulai setelah berita acara SIT diterima dari pengembang. Dokumen ini boleh DISIAPKAN lebih awal, tetapi eksekusi menunggu gate tersebut.
```

**Missing source:** fragment emits `[Pending — vault/04-flows.md belum berisi flow F-* — jalankan generate-intent dulu]` — keep verbatim.

## Section 2 — Skenario UAT

**Slot:** `{{section-2-narrative}}` + fragment block §2
**Source:** `<vault>/04-flows.md` — one `### UAT-NNN` block per `F-*-NNN` flow (1:1)
**Fragment carries per UAT scenario:** heading `### UAT-NNN — <judul> (F-id)`, a metadata table (Flow / Unit
terkait / Prioritas / Prasyarat / Data uji), the flow's **Mermaid diagram VERBATIM** (the Mermaid-flows hard
rule extends to UAT — never redrawn, never prose-ified), the flow's **DoD items VERBATIM** as expected outcomes,
an empty step-table skeleton, and a placeholder tester footer (`**Pelaksana:** … **Tanggal eksekusi:** …`).

**The ONE model edit — replace each `<!-- uat-steps:UAT-NNN -->` marker with numbered step rows:**

- **Aksi** — business language derived 1:1 from the flow's Mermaid nodes/edges: one step per meaningful node or
  edge, in execution order, in non-technical Indonesian. NEVER an invented step, never a step that has no node.
- **Expected Result** — the flow's DoD items VERBATIM (the same DoD text the fragment carries under "Expected
  outcome"); distribute the relevant DoD item to the step it verifies, or restate the DoD item verbatim.
- **Execution cells are EXACT placeholder LITERALS** (the model fills NONE):
  - Actual Result / Defect / Bukti = `__________`
  - Status = `[ ] Pass · [ ] Fail · [ ] Blocked`
- **Numbering** — from `1` per scenario (each UAT-NNN block restarts at 1).
- **Row shape** (7 cells, matching `| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |`):
  `| 1 | <Aksi> | <Expected Result> | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |`
- **Pending row rule** — a flow with no derivable steps (no Mermaid AND/OR no DoD to turn into steps) → emit
  exactly ONE row whose Aksi cell is `[Pending — flow <F-id> belum punya diagram/DoD untuk diturunkan]`; the
  Expected Result cell may restate the honest gap, and the execution cells STILL carry the exact placeholders above.

**Narrative (model):** 1–2 kalimat pembuka bagian (cara membaca skenario; bahwa langkah diturunkan dari flow
Mermaid + DoD; bahwa kolom eksekusi diisi tester MANUSIA). TIDAK per-scenario — the UAT blocks are self-contained.
**Missing source:** a flow without a Mermaid body → fragment's `[Pending — diagram Mermaid untuk F-X belum ada …]`;
without DoD → the `[Pending — Definition of Done …]` line. Keep those verbatim; the Pending step row covers derivation.

## Section 3 — Matriks Traceability (RTM)

**Slot:** `{{section-3-narrative}}` + fragment block §3 (VERBATIM — no edits)
**Source:** `<vault>/04-flows.md` + each unit's `vault_source:` F-id (unit ↔ flow join)
**Fragment carries:** one row per flow joining `Flow (F-id) ↔ Judul ↔ UAT ↔ TS (SIT) ↔ Unit terkait ↔ Status UAT`;
the **Status UAT cell is a placeholder LITERAL** (`__________`) — filled by hand during execution, never by the model.
**Narrative (model):** 1–2 kalimat — apa itu RTM, bagaimana traceability F-id ↔ UAT ↔ TS dibaca, dan bahwa kolom
Status UAT diisi saat pelaksanaan.
**Missing source:** no flows → fragment's `[Pending — belum ada flow F-* untuk RTM]`. Keep verbatim.
A model-filled Status UAT cell = fabricated record → deterministic `RTM_FILLED` violation (SKILL Step 4.7).

## Section 4 — Berita Acara UAT

**Slot:** `{{section-4-narrative}}` + fragment block §4 (VERBATIM — no edits)
**Source:** none — **paper-out** (mirrors SIT §5 / SEOJK §2.3.1.5). The fragment emits the info table
(Proyek / Periode UAT / Test cycle / Referensi SIT), an outstanding-defects skeleton, the Go/No-Go decision line
(`**Keputusan:** [ ] Go · [ ] No-Go`), and one bank-style sign-off table per scope
(`| Peran | Nama | Tanggal | Tanda tangan | Status |`) whose body rows are placeholder LITERALS:

- Nama / Tanggal / Tanda tangan: `__________`
- Status: `[ ] Diterima · [ ] Ditolak`
- Default roles: UAT Lead, Business Owner, Product Owner

**A model-filled berita-acara / sign-off cell, a filled defect row, an altered info value, or a resolved
`Keputusan` is a FABRICATED RECORD** — enforced deterministically: `build-uat-scaffold.sh --check-execution`
(SKILL Step 4.7 gate + re-emission guard in Step 0) FAILs with `BA_FILLED` / `SIGNOFF_FILLED` / `SIGNOFF_SHAPE` /
`BA_SECTION_MISSING` lines + Indonesian keterangan. Keputusan Go/No-Go + outstanding defects are decided and
written by HUMANS during execution; SEOJK: the user-approved berita acara UAT is mandatory before implementation.
**Narrative (model):** 1–2 kalimat — tabel diisi TANGAN oleh penanggung jawab saat/ setelah pelaksanaan; keputusan
Go/No-Go + outstanding defects dituangkan manusia; baris placeholder tidak boleh diisi digital.

## Citation notes

- The fragment already carries per-section `**Sources for this section:**` footers with `(sha256: \`pending\`)`
  literals — `build-citation-map.sh --doc=uat` (SKILL Step 4.6) stamps them and writes `<vault>/uat/.citation-map.json`.
  §4 (berita acara) cites no source artifacts — it is a human approval record (paper-out).
- `[Pending — …]` markers land in the map's `missing_sources[]` (script-derived; surfaced by orchestrate-flow's final summary).

## Drift callouts

On re-emit, `check-citation-drift.sh --doc=uat` lines (`DRIFT`/`GONE`) mark sections for a callout block quote
BEFORE the section content, using the script's `old12`/`new12` verbatim (same format as
`emit-fsd/references/fsd-template.md §Drift callout format`). Typical UAT drift: `04-flows.md` changed after the
last emit (scenarios / RTM stale) or a unit's `vault_source:` re-mapped (traceability superseded).
