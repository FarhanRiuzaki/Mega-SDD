# SIT Template — Bank-Style System Integration Test Document

> **Canonical 5-section structure.** Consumed by `emit-sit/SKILL.md` Step 3 (assembly).
> Table/scenario/evidence/sign-off content comes VERBATIM from the script-written fragment
> `<vault>/sit/.sit-evidence.md` (`build-sit-evidence.sh`); the `{{section-N-narrative}}` slots
> are the ONLY model-written prose (Indonesian + English technical terms).

## Contents

- Document control header
- Section 1 — Ruang Lingkup Uji
- Section 2 — Skenario Uji
- Section 3 — Matriks Test Case
- Section 4 — Bukti Eksekusi
- Section 5 — Sign-off
- Slot semantics
- Drift callout format

## Document control header (always emitted, not numbered)

```markdown
---
title: "{{project_name}} — System Integration Test (SIT)"
version: "{{vault_version}}"
date: "{{generation_date_iso}}"
classification: "Internal"
maturity: "{{sit_maturity}}"  # planned | partial | executed — script-derived (build-sit-evidence.sh)
mega_sdd_version: "{{plugin_version}}"
---

# {{project_name}} — SIT

**Maturity:** {{sit_maturity}} · **Tanggal:** {{generation_date_human}} · **Source vault:** `{{vault_path}}` (sha256: `pending`)

---
```

The `pending` token on the `**Source vault:**` line is stamped with sha256 of `<vault>/vault.json`
by `build-citation-map.sh --doc=sit` (SKILL Step 4.6). The model fills NO sha256 slot anywhere.

## Section 1 — Ruang Lingkup Uji

```markdown
## 1. Ruang Lingkup Uji

{{section-1-narrative}}

{{section-1-fragment}}
```

`{{section-1-fragment}}` = the `<!-- sit-evidence:§1 -->` block VERBATIM (flows-in-scope table +
module DoD + citation footer).

## Section 2 — Skenario Uji

```markdown
## 2. Skenario Uji

{{section-2-narrative}}

{{section-2-fragment}}
```

`{{section-2-fragment}}` = the `<!-- sit-evidence:§2 -->` block VERBATIM — one `### TS-NNN` block per
F-* flow: Mermaid diagram verbatim + DoD items verbatim as expected outcomes.

## Section 3 — Matriks Test Case

```markdown
## 3. Matriks Test Case

{{section-3-narrative}}

{{section-3-fragment}}
```

`{{section-3-fragment}}` = the `<!-- sit-evidence:§3 -->` block VERBATIM (TC ↔ TS ↔ F-id ↔ unit
traceability matrix + citation footer).

## Section 4 — Bukti Eksekusi

```markdown
## 4. Bukti Eksekusi

{{section-4-narrative}}

{{section-4-fragment}}
```

`{{section-4-fragment}}` = the `<!-- sit-evidence:§4 -->` block VERBATIM (§4.1 acceptance rows,
§4.2 manual-pending rows, §4.3 postflight verdicts, §4.4 batch-suite line + citation footer).
`[Pending — bolt U-XXX belum dieksekusi]` rows stay AS-IS — absence of evidence is content, never
replaced.

## Section 5 — Sign-off

```markdown
## 5. Sign-off

{{section-5-narrative}}

{{section-5-fragment}}
```

`{{section-5-fragment}}` = the `<!-- sit-evidence:§5 -->` block VERBATIM: per-scope bank-style
table(s) with placeholder-LITERAL body rows (`__________` cells; `[ ] Diterima · [ ] Ditolak`
status). **The model never fills a cell** — enforced by `build-sit-evidence.sh --check-signoff`
(SKILL Step 4.7).

## Slot semantics

All `{{slot_name}}` markers MUST be filled (narrative slots) or replaced by their fragment block.
A leftover `{{slot}}` after assembly = halt `quality_gate_failed:template_slot_unfilled`
(SKILL Step 4.5 in-skill grep — the SIT lane's slot scan; `validate-fsd-slots.sh` stays FSD-scoped
per `plugins/mega-sdd/references/emission-engine.md §P5 seams`).

## Drift callout format

```markdown
> ⚠ **Updated since last emit** — `<source_path>` was sha256 `<old-prefix>`, now `<new-prefix>`. Section regenerated.
```

Inserted as block quote BEFORE the affected section. Prefixes come from
`check-citation-drift.sh --doc=sit` output verbatim, never model-recalled.
