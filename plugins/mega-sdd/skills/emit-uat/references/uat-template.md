# UAT Template — Bank-Style User Acceptance Test Script

> **Canonical structure: 4 sections + the §5 automated-evidence annex (6.10.0).** Consumed by `emit-uat/SKILL.md` Step 3 (assembly).
> Table / scenario-scaffold / RTM / berita-acara content comes VERBATIM from the script-written fragment
> `<vault>/uat/.uat-scaffold.md` (`build-uat-scaffold.sh`); the `{{section-N-narrative}}` slots and the §2
> step rows (replacing each `<!-- uat-steps:UAT-NNN -->` marker) are the ONLY model-written content
> (Indonesian + English technical terms).

## Contents

- Document control header
- Section 1 — Ruang Lingkup & Kriteria
- Section 2 — Skenario UAT
- Section 3 — Matriks Traceability (RTM)
- Section 4 — Berita Acara UAT
- Section 5 — Lampiran Eksekusi Otomatis (pre-UAT, script-owned)
- Slot semantics
- Drift callout format

## Document control header (always emitted, not numbered)

```markdown
---
title: "{{project_name}} — User Acceptance Test (UAT) Script"
version: "{{vault_version}}"   # Versi sumber (vault) — versi DOKUMEN hidup di doc-control stamp + Riwayat Revisi
date: "{{generation_date_iso}}"
classification: "Internal"
maturity: "{{uat_maturity}}"  # draft | ready-for-uat | signed-off — draft saat emit; rung atas human-set
mega_sdd_version: "{{plugin_version}}"
---

# {{project_name}} — UAT Test Script

**Maturity:** {{uat_maturity}} · **Tanggal:** {{generation_date_human}} · **Source vault:** `{{vault_path}}` (sha256: `pending`)

---
```

The `pending` token on the `**Source vault:**` line is stamped with sha256 of `<vault>/vault.json`
by `build-citation-map.sh --doc=uat` (SKILL Step 4.6). The model fills NO sha256 slot anywhere.
`{{uat_maturity}}` is ALWAYS `draft` at emit (the model never self-promotes); the `version` / `status`
fields + the **Riwayat Revisi** region are inserted/refreshed by `refresh-doc-stamps.sh` (SKILL Step 6),
never typed by the model.

## Section 1 — Ruang Lingkup & Kriteria

```markdown
## 1. Ruang Lingkup & Kriteria

{{section-1-narrative}}

{{section-1-fragment}}
```

`{{section-1-fragment}}` = the `<!-- uat-scaffold:§1 -->` block VERBATIM (flows-in-scope table +
entry-criteria table incl. the SEOJK berita-acara-SIT row + exit-criteria table + citation footer).
When the scaffold printed `WARN_SIT`, the `{{section-1-narrative}}` opens with the SIT-not-executed
callout block quote (see `references/uat-sections.md §Section 1`).

## Section 2 — Skenario UAT

```markdown
## 2. Skenario UAT

{{section-2-narrative}}

{{section-2-fragment}}
```

`{{section-2-fragment}}` = the `<!-- uat-scaffold:§2 -->` block — one `### UAT-NNN` block per F-* flow:
metadata table + Mermaid diagram verbatim + DoD items verbatim + the step-table skeleton. The model replaces
each `<!-- uat-steps:UAT-NNN -->` marker with numbered step rows — the step-row grammar (Aksi/Expected wording,
the exact placeholder literals, row shape, numbering, Pending-row rule) is OWNED by `references/uat-sections.md
§Section 2`; this template adds no rules of its own.

## Section 3 — Matriks Traceability (RTM)

```markdown
## 3. Matriks Traceability (RTM)

{{section-3-narrative}}

{{section-3-fragment}}
```

`{{section-3-fragment}}` = the `<!-- uat-scaffold:§3 -->` block VERBATIM (Flow ↔ UAT ↔ TS ↔ unit traceability
matrix + citation footer). The `Status UAT` column stays the placeholder LITERAL `__________` — the model never
fills it (a filled cell = `RTM_FILLED` violation, SKILL Step 4.7).

## Section 4 — Berita Acara UAT

```markdown
## 4. Berita Acara UAT

{{section-4-narrative}}

{{section-4-fragment}}
```

`{{section-4-fragment}}` = the `<!-- uat-scaffold:§4 -->` block VERBATIM: the info table, outstanding-defects
skeleton, the Go/No-Go decision line (`**Keputusan:** [ ] Go · [ ] No-Go`), and per-scope bank-style sign-off
table(s) with placeholder-LITERAL body rows (`__________` cells; `[ ] Diterima · [ ] Ditolak` status).
**The model never fills a cell, never resolves the decision, never adds a defect row** — enforced by
`build-uat-scaffold.sh --check-execution` (SKILL Step 4.7). This is a HUMAN approval record (paper-out).

```markdown
## 5. Lampiran — Eksekusi Otomatis (pre-UAT)

{{annex_eksekusi_otomatis}}
```

Grammar OWNED by `references/uat-sections.md §Section 5` — this template adds no rules of its own. The slot
is ALWAYS present and ALWAYS filled: at assembly the model types EXACTLY the placeholder literal
`_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._` (the same fixed-literal
class as `(sha256: pending)`); ONLY `build-uat-e2e.sh --annex` may ever produce table content, and
`check_execution` byte-compares the whole §5 body against a recompute (`ANNEX_FORGED`). Underscore slot
name is header-style, deliberate (the section slots' hyphen convention marks narrative+fragment PAIRS;
the annex has no narrative slot).

## Slot semantics

All `{{slot_name}}` markers MUST be filled (frontmatter + header + narrative slots) or replaced by their
fragment block. A leftover `{{slot}}` after assembly = halt `quality_gate_failed:template_slot_unfilled`
(SKILL Step 4.5 in-skill grep — the UAT lane's slot scan; `validate-fsd-slots.sh` stays FSD-scoped per
`plugins/mega-sdd/references/emission-engine.md §P5 seams`).

Slot inventory:

- Header / frontmatter: `{{project_name}}`, `{{vault_version}}`, `{{generation_date_iso}}`, `{{uat_maturity}}`,
  `{{plugin_version}}`, `{{generation_date_human}}`, `{{vault_path}}`.
- Per-section (model narrative + verbatim fragment): `{{section-1-narrative}}` / `{{section-1-fragment}}`,
  `{{section-2-narrative}}` / `{{section-2-fragment}}`, `{{section-3-narrative}}` / `{{section-3-fragment}}`,
  `{{section-4-narrative}}` / `{{section-4-fragment}}`.
- Annex (script-owned, no narrative): `{{annex_eksekusi_otomatis}}` — model fills ONLY with the placeholder
  literal; table content comes exclusively from `build-uat-e2e.sh --annex`.

## Drift callout format

```markdown
> ⚠ **Updated since last emit** — `<source_path>` was sha256 `<old-prefix>`, now `<new-prefix>`. Section regenerated.
```

Inserted as block quote BEFORE the affected section. Prefixes come from `check-citation-drift.sh --doc=uat`
output verbatim, never model-recalled.
