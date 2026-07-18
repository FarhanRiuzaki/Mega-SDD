# FSD Template — Hybrid Confluence Format

> **Canonical 10-section structure.** Consumed by `emit-fsd/SKILL.md` Step 4 (per-section emission loop).
> Each section has: section header, slot marker `{{section-N-content}}`, citation footer slot `{{section-N-citations}}`.
> Section content is filled at emit-time from source artifacts per `section-mapping.md`.

**Document control header (always emitted, not numbered):**

```markdown
---
title: "{{project_name}} — Functional Specification Document"
version: "{{vault_version}}"
date: "{{generation_date_iso}}"
classification: "{{styling.classification}}"
author: "{{vault_author}}"
mode: "{{emit_mode}}"  # pre-development | post-development
mega_sdd_version: "{{plugin_version}}"
---

# {{project_name}}
## Contents

- Functional Specification Document
- Section 1 — Overview
- 1. Overview
- Section 2 — Goals & Non-Goals
- 2. Goals & Non-Goals
- Section 3 — Stakeholders / Owners
- 3. Stakeholders & Owners
- Section 4 — User Stories
- 4. User Stories
- Section 5 — Functional Requirements
- 5. Functional Requirements
- Section 6 — Non-Functional Requirements
- 6. Non-Functional Requirements
- Section 7 — Design / Architecture
- 7. Design & Architecture
- Section 8 — API & Data Contracts
- 8. API & Data Contracts
- Section 9 — Test Plan & UAT
- 9. Test Plan & UAT
- 9. Test Plan & UAT
- Section 10 — Risks & Open Issues
- 10. Risks & Open Issues
- Slot semantics
- Citation footer format
- Drift callout format (when re-emit detects sha256 change)

## Functional Specification Document

**Version:** {{vault_version}} · **Date:** {{generation_date_human}} · **Classification:** {{styling.classification}}
**Mode:** {{emit_mode_label}} · **Source vault:** `{{vault_path}}` (sha256: `pending`)

---

[TOC]

---
```

The `pending` token on the `**Source vault:**` line is special-cased by `scripts/build-citation-map.sh` (SKILL.md Step 4.6): it is stamped with sha256 of `<vault>/vault.json`. The model fills no sha256 slot anywhere — every stamp is authored as the literal `pending`.

## Section 1 — Overview

```markdown
## 1. Overview

{{section-1-content}}

{{section-1-citations}}
```

## Section 2 — Goals & Non-Goals

```markdown
## 2. Goals & Non-Goals

### 2.1 Goals
{{section-2-goals-content}}

### 2.2 Non-Goals
{{section-2-non-goals-content}}

{{section-2-citations}}
```

## Section 3 — Stakeholders / Owners

```markdown
## 3. Stakeholders & Owners

| Role | Name | Responsibility |
|---|---|---|
{{section-3-stakeholders-table}}

{{section-3-citations}}
```

## Section 4 — User Stories

```markdown
## 4. User Stories

{{section-4-user-stories-content}}

{{section-4-citations}}
```

Per-story emit format:

```markdown
### US-{{unit_id_short}} — {{unit_title}}

**As a** {{as_a}}
**I want** {{i_want}}
**So that** {{so_that}}

**Acceptance Criteria:**
{{acceptance_test_summary}}

[Source: units/{{unit_id}}.md (sha256: pending)]
```

## Section 5 — Functional Requirements

```markdown
## 5. Functional Requirements

| FR ID | Description | Priority | Status |
|---|---|---|---|
{{section-5-fr-table}}

### FR Details

{{section-5-fr-details}}

{{section-5-citations}}
```

Per-FR detail format:

```markdown
#### FR-{{fr_id}} — {{fr_title}}

{{fr_description}}

- **Priority:** {{fr_priority}}
- **Status:** {{fr_status}} ({{status_evidence}})
- **Bound by:** {{binding_verdict}} (per `binding.md` claim {{claim_id}})
- **Implemented in:** {{unit_ids_csv}} ({{bolt_status_summary}})

[Source: vault/02-functional.md:L{{fr_line_start}}-L{{fr_line_end}} (sha256: pending)]
```

## Section 6 — Non-Functional Requirements

```markdown
## 6. Non-Functional Requirements

### 6.1 Performance
{{section-6-performance-content}}

### 6.2 Security
{{section-6-security-content}}

### 6.3 Availability
{{section-6-availability-content}}

### 6.4 Other Constitution Constraints
{{section-6-other-constitution-content}}

{{section-6-citations}}
```

## Section 7 — Design / Architecture

```markdown
## 7. Design & Architecture

### 7.1 System Entities
{{section-7-entities-content}}

### 7.2 Module Map
{{section-7-modules-content}}

### 7.3 Confirmed Claims (from binding)
{{section-7-binding-confirmed-content}}

{{section-7-citations}}
```

## Section 8 — API & Data Contracts

```markdown
## 8. API & Data Contracts

### 8.1 Public Interfaces

| Endpoint / Function | Signature | Source |
|---|---|---|
{{section-8-api-table}}

### 8.2 Data Model (Entities)

{{section-8-entities-content}}

{{section-8-citations}}
```

## Section 9 — Test Plan & UAT

**Pre-development mode emits:**

```markdown
## 9. Test Plan & UAT

> Mode: **Pre-development draft.** UAT scenarios derived from unit acceptance tests; execution pending.

| Unit | Acceptance Test | UAT Status |
|---|---|---|
{{section-9-pre-dev-table}}

{{section-9-citations}}
```

**Post-development mode emits:**

```markdown
## 9. Test Plan & UAT

> Mode: **Post-development as-built.** Results from `bolts/U-NNN/bolt-report.md`.

| Unit | Acceptance Test | Result | Bolt Commit |
|---|---|---|---|
{{section-9-post-dev-table}}

### 9.1 Self-assessment Concerns

{{section-9-acceptance-concerns-content}}

{{section-9-citations}}
```

## Section 10 — Risks & Open Issues

```markdown
## 10. Risks & Open Issues

### 10.1 Unresolved Open Questions

| OQ ID | Question | Priority | Category |
|---|---|---|---|
{{section-10-oq-table}}

### 10.2 Acceptance-Test Concerns

{{section-10-bolt-concerns-content}}

### 10.3 Out-of-Scope Items

{{section-10-out-of-scope-content}}

{{section-10-citations}}
```

---

## Slot semantics

All `{{slot_name}}` markers MUST be filled OR explicitly stamped `[Pending — <source> not yet generated]` per anti-hallucination rule (see SKILL.md §Anti-hallucination). Empty slots are a SKILL bug → halt `quality_gate_failed`.

## Citation footer format

```markdown
**Sources for this section:**
- [¹] `<source_path>:L<start>-L<end>` (sha256: `pending`)
- [²] `<source_path>:L<start>-L<end>` (sha256: `pending`)
```

Stamped by `scripts/build-citation-map.sh` before PDF render (SKILL.md Step 4.6) — the literal `pending` tokens become real 12-char sha256 prefixes computed from file bytes; the model never writes hash characters. Cross-referenced from `.citation-map.json` (script-written, schema 2.0) for auditability.

## Drift callout format (when re-emit detects sha256 change)

```markdown
> ⚠ **Updated since last emit** — `<source_path>` was sha256 `<old-prefix>`, now `<new-prefix>`. Section regenerated.
```

Inserted as block quote BEFORE the regenerated section content. `<old-prefix>`/`<new-prefix>` come from `scripts/check-citation-drift.sh` output (`DRIFT <section> <path> <old12> <new12>` — SKILL.md Step 2), never model-recalled.
