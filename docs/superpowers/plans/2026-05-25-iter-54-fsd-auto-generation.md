# Iter 54 FSD Auto-Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `mega-sdd:emit-fsd` skill that auto-generates Hybrid Confluence FSD (Markdown + PDF) from vault/units/bolts artifacts with anti-hallucination citation discipline.

**Architecture:** New markdown-driven skill following `emit-agents-md` anatomy (SKILL.md + 4 reference files); 10 FSD sections each grounded on specific vault artifacts with sha256-stamped citations stored in `.citation-map.json`; PDF rendered via pandoc + xelatex/tectonic with HTML fallback; auto-invoked at end of `/mega-sdd:auto` pipeline (skip via `--no-fsd`); per-vault output (cross-scope consolidation deferred).

**Tech Stack:** Markdown (skill body + references), LaTeX (pandoc template), YAML (styling config), JSON (citation map), Bash (predictive checks).

**Spec source:** `docs/superpowers/specs/2026-05-25-iter-54-fsd-auto-generation-design.md`

**Versions:** Plugin `3.36.0 → 3.37.0` (MINOR — new skill); `orchestrate-flow 3.4.0 → 3.5.0` (MINOR — new diagnostic surface); new skill `emit-fsd 1.0.0`.

---

## File Structure (responsibility map)

**Create (6 files):**

| File | Responsibility |
|---|---|
| `plugins/mega-sdd/skills/emit-fsd/SKILL.md` | Main procedure (~200 lines): preflight, mode detect, per-section emission loop, citation-map.json write, pandoc bridge, handoff emission |
| `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md` | Canonical 10-section Hybrid Confluence template structure with placeholder slot markers |
| `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` | Per-section: source artifact path(s) + extraction rules + citation format |
| `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml` | Default styling YAML with all keys + inline comments documenting overrides |
| `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex` | LaTeX template for PDF (A4, cover page, TOC, footer, table styling) |
| `plugins/mega-sdd/commands/emit-fsd.md` | Slash command wrapper (~30 lines, follows emit-agents-md.md pattern) |

**Modify (7 files):**

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` | Step 6 diagnostics table +1 row; Step 7 final summary +1 line (FSD emission line); version 3.4.0 → 3.5.0 |
| `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` | + §emit-fsd preflight checks (3 entries) |
| `plugins/mega-sdd/commands/auto.md` | Document `--no-fsd` flag in flags table |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | version 3.36.0 → 3.37.0 |
| `CHANGELOG.md` | + [3.37.0] entry with Iter 54 release notes |
| `plugins/mega-sdd/README.md` | + v3.37.0 What's new entry; folder layout +1 line for emit-fsd skill |
| `README.md` | version refs 3.36.0 → 3.37.0 |

---

## Task 1: Scaffold emit-fsd skill directory + minimal SKILL.md

**Files:**
- Create: `plugins/mega-sdd/skills/emit-fsd/SKILL.md`
- Create: `plugins/mega-sdd/skills/emit-fsd/references/` (directory)

- [ ] **Step 1.1: Verify parent path exists**

Run: `ls plugins/mega-sdd/skills/ | grep emit-agents-md`
Expected: `emit-agents-md` (confirms we're in the right plugin layout)

- [ ] **Step 1.2: Create skill scaffold with frontmatter + section anchors**

Create `plugins/mega-sdd/skills/emit-fsd/SKILL.md` with:

```markdown
---
name: emit-fsd
version: 1.0.0
description: Generate a Hybrid Confluence-format FSD (Functional Specification Document) — Markdown + PDF — from a mega-sdd vault. Grounded on actual vault/units/bolts/binding artifacts with sha256-stamped citation discipline per `.citation-map.json`. Mode auto-detect: pre-development (vault only) vs post-development (vault + bolts). PDF via pandoc + xelatex/tectonic; HTML fallback when LaTeX absent; markdown-only when pandoc absent. Triggers — "generate FSD", "emit FSD", "buat FSD", "FSD untuk confluence", or paraphrases.
---

# Emit-FSD — Functional Specification Document Generator

**Announce at start:** "I'm using the emit-fsd skill to generate the FSD from the current vault."

## When to use

- "generate FSD" / "emit FSD" / "buat FSD" / "FSD untuk confluence"
- Pre-development sign-off: after generate-intent stabilizes the vault, before bolts run
- Post-development as-built record: after execute-bolts completes
- Re-emission on PRD revision (diff-vault) or OQ resolution (resolve-oq)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `references/paths.md` priority order)
- `--mode={pre-dev|post-dev|auto}` (default: `auto` — detect from CWD state)
- `--no-pdf` (markdown-only; useful when pandoc/LaTeX absent)
- `--styling=<path-to-yaml>` (override default `FSD.styling.yaml`)
- `--sections=<comma-list>` (emit subset; e.g., `--sections=1,2,5,7,8,10`)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/fsd/
├── FSD.md                      # source markdown (10-section Hybrid Confluence template)
├── FSD.pdf                     # rendered PDF via pandoc (absent if pandoc/LaTeX unavailable)
├── FSD.styling.yaml            # styling config (generated on first run; preserved on re-emit)
└── .citation-map.json          # vault-section → FSD-section citation trace
```

## Pre-flight checks

1. **vault_present_for_fsd**: `test -f <vault-path>/vault.json` — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only)
3. **pandoc_latex_engine_present**: `command -v xelatex || command -v tectonic` — warn if absent (degraded to HTML fallback)

Full preflight catalog: `mega-sdd:orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks.

## Procedure

(filled in subsequent tasks — see plan)

## Halt protocol

(filled in Task 6)

## Handoff emission (v1.0.0+, Iter 54)

(filled in Task 6)
```

- [ ] **Step 1.3: Verify file structure**

Run: `ls plugins/mega-sdd/skills/emit-fsd/`
Expected: `SKILL.md  references/` (directory created implicitly via Step 1.2 since we'll add files there next)

Run: `mkdir -p plugins/mega-sdd/skills/emit-fsd/references`
Expected: no output (idempotent)

- [ ] **Step 1.4: Commit scaffold**

```bash
git add plugins/mega-sdd/skills/emit-fsd/SKILL.md
git commit -m "scaffold(iter-54): emit-fsd skill skeleton

Frontmatter + section anchors per emit-agents-md anatomy. Procedure body
filled in subsequent tasks per
docs/superpowers/plans/2026-05-25-iter-54-fsd-auto-generation.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Write fsd-template.md (canonical 10-section template)

**Files:**
- Create: `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md`

- [ ] **Step 2.1: Create template reference**

Create `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md`:

````markdown
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
## Functional Specification Document

**Version:** {{vault_version}} · **Date:** {{generation_date_human}} · **Classification:** {{styling.classification}}
**Mode:** {{emit_mode_label}} · **Source vault:** `{{vault_path}}` (sha256: `{{vault_sha256_short}}`)

---

[TOC]

---
```

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

[Source: units/{{unit_id}}.md (sha256: {{unit_sha256_short}})]
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

[Source: vault/02-functional.md:L{{fr_line_start}}-L{{fr_line_end}} (sha256: {{vault_02_sha256_short}})]
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
- [¹] `<source_path>:L<start>-L<end>` (sha256: `<sha-short>`)
- [²] `<source_path>:L<start>-L<end>` (sha256: `<sha-short>`)
```

Cross-referenced from `.citation-map.json` for auditability.

## Drift callout format (when re-emit detects sha256 change)

```markdown
> ⚠ **Updated since last emit** — `<source_path>` was sha256 `<old-prefix>`, now `<new-prefix>`. Section regenerated.
```

Inserted as block quote BEFORE the regenerated section content.
````

- [ ] **Step 2.2: Verify file size + content**

Run: `wc -l plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md`
Expected: 150-200 lines

Run: `grep -c "{{section-" plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md`
Expected: ≥ 20 (slot markers across all 10 sections)

- [ ] **Step 2.3: Commit template**

```bash
git add plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md
git commit -m "feat(iter-54): emit-fsd fsd-template.md canonical 10-section Hybrid Confluence

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Write section-mapping.md (artifact → section extraction rules)

**Files:**
- Create: `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md`

- [ ] **Step 3.1: Create section mapping reference**

Create `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md`:

````markdown
# Section Mapping — Source Artifact → FSD Section

> **Per-section: source artifact path(s), extraction rules, citation format.**
> Consumed by `emit-fsd/SKILL.md` Step 4 (per-section emission loop).
> Every slot in `fsd-template.md` MUST have an extraction rule here.

## Source-of-truth priority

1. **Vault files** (`<vault>/00-index.md`, `01-overview.md`, ..., `vault.json`) — declarative intent
2. **Binding** (`<vault>/binding.md`, `<vault>-bound/` OR `bound-vault/`) — code-validated state
3. **Codebase map** (`<project>/.mega-sdd/codebase/codebase-map.md`) — actual codebase facts
4. **Units** (`<vault>/units/U-NNN.md`) — decomposition
5. **Bolts** (`<vault>/bolts/U-NNN/bolt-report.md`) — execution results

## Mode determination (Step 0 in SKILL.md)

```
IF bolts/ directory exists AND has ≥1 bolt-report.md → mode = post-dev
ELIF units/ directory exists AND has ≥1 U-*.md → mode = pre-dev (with breakdown)
ELSE → mode = pre-dev (vault-only)
```

User override: `--mode=pre-dev` OR `--mode=post-dev` forces regardless of CWD state.

## Section 1 — Overview

**Slot:** `{{section-1-content}}`
**Source:** `<vault>/01-overview.md` §Purpose + §Scope
**Extraction:** Read entire §Purpose block + §Scope block; preserve markdown formatting; strip vault-internal anchors.
**Citation:** `[¹] Source: vault/01-overview.md:L<purpose_start>-L<scope_end> (sha256: <short>)`
**Missing source:** emit `[Pending — vault/01-overview.md not yet generated]`

## Section 2 — Goals & Non-Goals

**Slots:** `{{section-2-goals-content}}`, `{{section-2-non-goals-content}}`
**Source:** `<vault>/01-overview.md` §Goals + §Non-Goals
**Extraction:** Per §Goals: extract bulleted/numbered list as-is. Per §Non-Goals: same.
**Citation:** inline footnote per sub-section.
**Missing source:** emit per sub-section `[Pending — vault/01-overview.md §Goals not yet generated]`

## Section 3 — Stakeholders / Owners

**Slot:** `{{section-3-stakeholders-table}}`
**Source priority:**
1. `<vault>/_meta/squads.yaml` (if present, v1.1+ multi-squad vaults)
2. `<vault>/vault.json.stakeholders[]` (when populated)
3. `<vault>/vault.json.author` field (fallback — single-author project)

**Extraction:**
- From squads.yaml: emit one row per squad: `{squad.role} | {squad.lead_name} | {squad.responsibility}`
- From vault.json.stakeholders[]: emit one row per entry: `{role} | {name} | {responsibility}`
- Fallback: emit single row `Author | {vault.author} | Project owner`

**Citation:** `[¹] Source: vault/_meta/squads.yaml` OR `vault.json` (sha256: <short>)
**Missing source:** emit single row with `Author | (unspecified — vault.json.author missing) | Project owner` + warning callout above table.

## Section 4 — User Stories

**Slot:** `{{section-4-user-stories-content}}`
**Source:** `<vault>/units/U-NNN.md` (all units, sorted by U-ID ascending)
**Extraction per unit:**
- `as_a`: from unit frontmatter `user_story.as_a` field; if absent, derive from `unit.scope` (e.g., "API consumer" for BE-scope unit, "End user" for FE-scope)
- `i_want`: from `unit.title` or frontmatter `user_story.i_want`
- `so_that`: from `unit.business_value` or frontmatter `user_story.so_that`; if absent, leave `(unspecified)`
- `acceptance_test_summary`: 1-line condensation of `unit.acceptance_test.command` + expected outcome

**Citation:** per-story footer `[Source: units/U-NNN.md (sha256: <short>)]`
**Missing source (no units/):** emit `[Pending — units/ directory not yet generated. Run /mega-sdd:generate-units after vault stabilizes.]`

## Section 5 — Functional Requirements

**Slots:** `{{section-5-fr-table}}`, `{{section-5-fr-details}}`
**Source:** `<vault>/02-functional.md` — every FR-NNN heading
**Extraction:**
- Parse markdown headings matching `^#{2,3}\s+FR-\d+` pattern
- Per FR: extract title (text after FR-NNN), description (body until next heading), priority (look for `**Priority:**` line; default `MEDIUM`)
- Status determination:
  - mode=pre-dev: status = `Specified`
  - mode=post-dev: status = lookup units that reference this FR (via `unit.implements_claim` or `unit.vault_source`), aggregate bolt status:
    - All referenced bolts `completed` → `Implemented`
    - Any bolt `halted_*` → `In Progress (halted)`
    - No referencing units → `Specified (no unit)`
- Binding verdict: scan `binding.md` for claim line matching FR-id; extract CONFIRMED/CONFLICT/OQ verdict
- Unit IDs: list `unit.id` of every unit that references this FR

**Table row format:** `| FR-NNN | <title> | <priority> | <status> |`

**Detail block:** emit per-FR detail block from `fsd-template.md` Section 5 template.

**Citation:** per-FR `[Source: vault/02-functional.md:L<start>-L<end> (sha256: <short>)]`
**Missing source:** emit `[Pending — vault/02-functional.md not yet generated]`

## Section 6 — Non-Functional Requirements

**Slots:** `{{section-6-performance-content}}`, `{{section-6-security-content}}`, `{{section-6-availability-content}}`, `{{section-6-other-constitution-content}}`
**Source priority:**
1. `<vault>/02-functional.md` §NFR (if section exists)
2. `<vault>/_meta/constitution.md` LOCKED clauses (filter by category: performance / security / availability / compliance)

**Extraction:**
- From 02-functional NFR section: extract per sub-category
- From constitution.md: filter LOCKED clauses by category tag; extract clause body
- De-dup if both sources mention same constraint (prefer constitution.md as canonical)

**Citation:** `[¹] vault/02-functional.md §NFR` AND/OR `[²] vault/_meta/constitution.md §LOCKED:<category>`
**Missing source:** per sub-category emit `(not specified)` line; do NOT halt.

## Section 7 — Design / Architecture

**Slots:** `{{section-7-entities-content}}`, `{{section-7-modules-content}}`, `{{section-7-binding-confirmed-content}}`
**Source priority:**
1. `binding.md` §Confirmed Claims (post-binding state)
2. `codebase-map.md` §Entities + §Modules (raw codebase facts)
3. `<vault>/04-design.md` (if vault has design doc — older vaults may not)

**Extraction:**
- Entities: from codebase-map.md §Entities table — emit as nested list (entity name + 1-line description)
- Modules: from codebase-map.md §Modules table — emit as table with `Module | Path | Responsibility`
- Confirmed Claims: from binding.md `## Confirmed Claims` section — emit each as bulleted item with `[C-NNN]` ID prefix

**Citation:** per source `[¹] binding.md:L<line>` AND `[²] codebase-map.md §Entities (sha256: <short>)`
**Missing source:** if binding.md absent → emit `[Pending — binding.md not yet generated. Run /mega-sdd:bind-codebase.]`; if codebase-map absent → `[Pending — codebase-map.md not yet generated. Run /mega-sdd:scan-codebase.]`

## Section 8 — API & Data Contracts

**Slots:** `{{section-8-api-table}}`, `{{section-8-entities-content}}`
**Source:** `codebase-map.md` §Public interfaces table

**Extraction:**
- Read §Public interfaces table (columns: endpoint/function, signature, source file:line, last_scanned_sha256 per Iter 46)
- Emit table rows: `| {name} | {signature} | {source_path}:L{line} |`
- Append entities content: nested list of all entities from §Entities (sha256-stamped per row)

**Citation:** per row `[Source: codebase-map.md §Public interfaces:L<line> (sha256: <Last_Scanned_Sha256>)]`
**Missing source:** emit `[Pending — codebase-map.md not yet generated]`

## Section 9 — Test Plan & UAT

**Slots (pre-dev mode):** `{{section-9-pre-dev-table}}`
**Slots (post-dev mode):** `{{section-9-post-dev-table}}`, `{{section-9-acceptance-concerns-content}}`

**Pre-dev extraction:**
- For each unit: emit row `| {unit_id} | {acceptance_test.command} (expects: {acceptance_test.expected}) | Pending |`

**Post-dev extraction:**
- For each unit + matching bolt-report:
  - Result: `bolt_status` field from bolt-report (completed / halted_*)
  - Bolt commit: extract from bolt-report `Generated by mega-sdd execute-bolts ...` provenance trailer OR `git log --oneline -1 <bolts/U-NNN/>` first match
  - Emit row `| {unit_id} | {acceptance_test.command} | {result_emoji} {bolt_status} | {commit_sha_short} |`
- Acceptance concerns: aggregate `acceptance_test_concern:` fields from each bolt-report (Iter 47 + Iter 53 consumer) — emit per-bolt list

**Citation:** per row `[Source: bolts/{unit_id}/bolt-report.md (commit: {sha_short})]`
**Missing source:**
- pre-dev mode + no units → row says `Pending — units/ not yet generated`
- post-dev mode + no bolts for a unit → row says `Pending — bolt not yet executed for {unit_id}`

## Section 10 — Risks & Open Issues

**Slots:** `{{section-10-oq-table}}`, `{{section-10-bolt-concerns-content}}`, `{{section-10-out-of-scope-content}}`
**Source:**
1. `<vault>/03-open-questions.md` (or `vault.json.open_questions[]`) — filter where `status != resolved`
2. Bolt-reports `acceptance_test_concern:` aggregated (Iter 53 consumer surface)
3. `<vault>/01-overview.md` §Non-Goals (out-of-scope items)

**Extraction:**
- OQs: per unresolved OQ emit row `| {oq_id} | {question} | {priority} | {category} |`
- Bolt concerns: per concern emit `**{unit_id}:** {concern_text} (raised by {bolt_subagent_id})`
- Out-of-scope: extract from 01-overview §Non-Goals (re-used from Section 2 but reformatted as risk-framing)

**Citation:** per source `[¹] vault/03-open-questions.md` AND `[²] bolts/<unit_id>/bolt-report.md` AND `[³] vault/01-overview.md §Non-Goals`
**Missing source:** empty arrays emit `(none)`; do NOT halt.

## Citation map schema

`<vault>/fsd/.citation-map.json`:

```json
{
  "schema_version": "1.0",
  "emitted_at": "2026-05-25T10:30:00Z",
  "emitted_by": "emit-fsd v1.0.0",
  "vault_sha256": "abc...",
  "mode": "pre-dev" | "post-dev",
  "sections": [
    {
      "fsd_section": "5.FR-007",
      "source_path": "vault/02-functional.md",
      "source_lines": "L78-92",
      "source_sha256": "def...",
      "emitted_text_sha256": "ghi..."
    }
  ],
  "missing_sources": [
    {"section": "9", "expected_source": "bolts/", "reason": "pre-dev mode"}
  ]
}
```

## Drift detection

On re-emit:
1. Read prior `.citation-map.json` (if exists)
2. For each prior citation entry: compute current sha256 of `source_path`
3. If current ≠ prior → flag section for drift callout

Drift callout text inserted as block quote BEFORE regenerated section (per fsd-template.md drift callout format).
````

- [ ] **Step 3.2: Verify section coverage**

Run: `grep -c "^## Section " plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md`
Expected: 10 (one mapping rule per FSD section)

Run: `grep "Missing source:" plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md | wc -l`
Expected: 10 (every section has missing-source handling)

- [ ] **Step 3.3: Commit section mapping**

```bash
git add plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md
git commit -m "feat(iter-54): emit-fsd section-mapping.md artifact extraction rules

Per-section: source artifact path(s), extraction rules, citation format,
missing-source handling. Citation map schema + drift detection algorithm.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Write styling-config.yaml (default styling + override schema)

**Files:**
- Create: `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml`

- [ ] **Step 4.1: Create default styling YAML**

Create `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml`:

```yaml
# emit-fsd default styling config
# Consumed by emit-fsd/SKILL.md Step 5 (pandoc command assembly)
# Generated on first run at <vault>/fsd/FSD.styling.yaml; user edits preserved on re-emit.

# === Document metadata ===

company_name: "Your Company"               # appears on cover page
project_name: null                          # NULL → derived from vault.json.project_name
classification: "Internal"                  # "Internal" | "Confidential" | "Public"

# === Cover page ===

logo_path: null                             # NULL → no logo. Set to relative path like "./assets/logo.png"
                                            # Logo rendered 200px wide, top-left of cover.
cover_subtitle: "Functional Specification Document"

# === Typography ===

font_family: "Arial"                        # "Arial" | "Helvetica" | "Times" | "Calibri" | "Roboto"
font_size_pt: 11                            # body text size; cover/headings scaled relative
line_spacing: 1.15                          # 1.0 (tight) - 2.0 (double)

# === Color ===

accent_color: "#003366"                     # primary heading color + table header background
                                            # ID corporate default: navy blue #003366
                                            # Alternates: #c41e3a (banking red), #1a5d1a (green)

# === Page layout ===

page_size: "A4"                             # "A4" | "Letter"
margin_top_cm: 2.5
margin_bottom_cm: 2.5
margin_left_cm: 2.5
margin_right_cm: 2.5

# === Sections to include ===

include_sections: "all"                     # "all" OR list, e.g., [1, 2, 5, 7, 8, 10]
                                            # Useful for stakeholder-specific FSD subsets

# === Citations + drift ===

include_citation_footnotes: true            # set false for cleaner output (drops [¹] markers)
include_drift_callouts: true                # set false to suppress ⚠ callouts on re-emit
include_provenance_trailer: true            # set false to hide "Generated by mega-sdd vX.Y.Z" footer

# === Footer ===

footer_text: "{{classification}} — {{project_name}} FSD"   # template vars resolved at emit-time
footer_page_numbers: true

# === Misc ===

table_header_shading: true                  # subtle gray shade on first row of tables
toc_depth: 3                                # H1, H2, H3 in TOC (4 includes H4)
emit_watermark: true                        # "DRAFT" diagonal watermark in pre-dev mode; absent in post-dev

# === ID corporate convenience presets (uncomment to apply) ===

# preset: banking_indonesia
#   company_name: "PT XYZ"
#   classification: "Confidential"
#   font_family: "Arial"
#   accent_color: "#003366"
#   footer_text: "Rahasia — {{project_name}}"
#   logo_path: "./assets/bank-logo.png"

# preset: telco_indonesia
#   font_family: "Helvetica"
#   accent_color: "#c41e3a"
#   classification: "Internal"
```

- [ ] **Step 4.2: Verify YAML is parseable**

Run: `python3 -c "import yaml; yaml.safe_load(open('plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml'))"`
Expected: no output (parse success)

- [ ] **Step 4.3: Commit styling config**

```bash
git add plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml
git commit -m "feat(iter-54): emit-fsd styling-config.yaml default + overrides

Includes ID corporate convenience presets (banking_indonesia, telco_indonesia)
as commented examples.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Write pandoc-template.tex (LaTeX styling)

**Files:**
- Create: `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex`

- [ ] **Step 5.1: Create LaTeX template**

Create `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex`:

```latex
% emit-fsd pandoc PDF template
% Consumed by emit-fsd/SKILL.md Step 5: pandoc --template=<this-file>
% Variables (${var}) resolved from FSD.md frontmatter + FSD.styling.yaml

\documentclass[$if(papersize)$$papersize$paper$else$a4paper$endif$,$if(fontsize)$$fontsize$$else$11pt$endif$]{article}

% --- Geometry ---
\usepackage[
  top=$if(margin_top_cm)$${margin_top_cm}cm$else$2.5cm$endif$,
  bottom=$if(margin_bottom_cm)$${margin_bottom_cm}cm$else$2.5cm$endif$,
  left=$if(margin_left_cm)$${margin_left_cm}cm$else$2.5cm$endif$,
  right=$if(margin_right_cm)$${margin_right_cm}cm$else$2.5cm$endif$
]{geometry}

% --- Fonts ---
\usepackage{fontspec}
\setmainfont{$if(font_family)$$font_family$$else$Arial$endif$}

% --- Color ---
\usepackage[dvipsnames]{xcolor}
\definecolor{accent}{HTML}{$if(accent_color)$$accent_color_hex$$else$003366$endif$}

% --- Headings ---
\usepackage{titlesec}
\titleformat{\section}{\Large\bfseries\color{accent}}{\thesection}{1em}{}
\titleformat{\subsection}{\large\bfseries\color{accent}}{\thesubsection}{1em}{}
\titleformat{\subsubsection}{\normalsize\bfseries\color{accent}}{\thesubsubsection}{1em}{}

% --- Tables ---
\usepackage{longtable,booktabs,array}
\usepackage{colortbl}
$if(table_header_shading)$
\definecolor{tableheader}{HTML}{E8E8E8}
$endif$

% --- Hyperlinks ---
\usepackage[colorlinks=true,linkcolor=accent,urlcolor=accent,citecolor=accent]{hyperref}

% --- Header / Footer ---
\usepackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyfoot[L]{\small\color{gray}$footer_text$}
$if(footer_page_numbers)$
\fancyfoot[R]{\small\color{gray}Page \thepage}
$endif$
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0.4pt}

% --- Watermark (pre-dev draft) ---
$if(emit_watermark)$
\usepackage{draftwatermark}
\SetWatermarkText{DRAFT}
\SetWatermarkScale{4}
\SetWatermarkColor[gray]{0.92}
$endif$

% --- Line spacing ---
\usepackage{setspace}
\setstretch{$if(line_spacing)$$line_spacing$$else$1.15$endif$}

% --- TOC ---
\usepackage{tocloft}
\setcounter{tocdepth}{$if(toc_depth)$$toc_depth$$else$3$endif$}

% --- Document ---
\begin{document}

% === Cover page ===
\begin{titlepage}
\centering
\vspace*{2cm}

$if(logo_path)$
\includegraphics[width=4cm]{$logo_path$}\par\vspace{1cm}
$endif$

{\Large\bfseries\color{accent} $company_name$\par}
\vspace{0.5cm}
{\huge\bfseries $project_name$\par}
\vspace{0.3cm}
{\Large $cover_subtitle$\par}
\vspace{2cm}

\begin{tabular}{rl}
\textbf{Version:} & $vault_version$ \\
\textbf{Date:} & $generation_date_human$ \\
\textbf{Classification:} & $classification$ \\
\textbf{Mode:} & $emit_mode_label$ \\
\textbf{Source vault sha256:} & \texttt{$vault_sha256_short$} \\
\end{tabular}

\vfill
{\small\color{gray}Generated by mega-sdd v$mega_sdd_version$\par}
\end{titlepage}

% === TOC ===
\tableofcontents
\newpage

% === Body (pandoc fills $body$ from FSD.md after YAML frontmatter strip) ===
$body$

\end{document}
```

- [ ] **Step 5.2: Verify LaTeX template structure**

Run: `grep -c "^\\\\section\|^\\\\subsection\|^\\\\usepackage" plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex`
Expected: ≥ 10 (template has structure)

Run: `grep -c "\\\$\\\$\|\\\$body\\\$\|\\\$if(" plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex`
Expected: ≥ 15 (pandoc variables present)

- [ ] **Step 5.3: Commit LaTeX template**

```bash
git add plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex
git commit -m "feat(iter-54): emit-fsd pandoc-template.tex LaTeX styling

A4, cover page, TOC, footer, table shading, watermark, draft mode support.
Variables resolved from FSD.md frontmatter + FSD.styling.yaml at emit-time.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Fill emit-fsd SKILL.md main procedure

**Files:**
- Modify: `plugins/mega-sdd/skills/emit-fsd/SKILL.md` (replace placeholder Procedure/Halt protocol/Handoff sections)

- [ ] **Step 6.1: Read current SKILL.md to find placeholders**

Run: `grep -n "filled in" plugins/mega-sdd/skills/emit-fsd/SKILL.md`
Expected: 3 matches (Procedure, Halt protocol, Handoff emission)

- [ ] **Step 6.2: Replace `## Procedure` section**

Find in SKILL.md:
```markdown
## Procedure

(filled in subsequent tasks — see plan)
```

Replace with:
````markdown
## Procedure

### Step 0: Mode detection

Inspect CWD state per `references/section-mapping.md §Mode determination`:

```
IF <vault>/bolts/ exists AND has ≥1 U-*/bolt-report.md → mode = post-dev
ELIF <vault>/units/ exists AND has ≥1 U-*.md → mode = pre-dev (with breakdown)
ELSE → mode = pre-dev (vault-only)
```

User flag `--mode={pre-dev|post-dev|auto}` overrides detection. `auto` (default) uses detection result.

Emit detected mode + reasoning to chat: `"FSD mode: <mode> (detected via: <CWD state evidence>)"`.

### Step 1: Read styling config

1. Check `<vault>/fsd/FSD.styling.yaml` — if exists, load.
2. Else, copy `references/styling-config.yaml` to `<vault>/fsd/FSD.styling.yaml` and load.
3. If `--styling=<path>` flag passed, load that path instead (overrides both).
4. Resolve template variables: `project_name` from `vault.json.project_name` if styling has null; `vault_version` from `vault.json.vault_version`; `generation_date_*` from current ISO8601.

### Step 2: Read prior citation map (drift detection)

1. Check `<vault>/fsd/.citation-map.json` — if exists, parse as `prior_citation_map`.
2. Else, `prior_citation_map = null` (first emit; no drift to detect).

### Step 3: Per-section emission loop

For each section N in 1-10 (filter by `styling.include_sections` if not "all"):

a. Look up extraction rules in `references/section-mapping.md §Section N`.
b. For each declared source artifact: check existence + read content + compute sha256.
c. Apply extraction rules to produce slot content.
d. If any source artifact absent: emit `[Pending — <source> not yet generated]` placeholder per anti-hallucination rule.
e. Compute `emitted_text_sha256` of slot content.
f. Compare `source_sha256` vs `prior_citation_map.sections[].source_sha256` (if applicable):
   - Mismatch → flag section for drift callout; insert callout block quote BEFORE section content
   - Match → no callout
   - First emit (no prior) → no callout
g. Append entry to in-memory `citation_map.sections[]`.
h. Substitute slot in `references/fsd-template.md §Section N` template.

### Step 4: Assemble FSD.md

1. Start from `references/fsd-template.md` (full template).
2. For each `{{slot_name}}` marker: replace with computed slot content from Step 3.
3. Add YAML frontmatter at top (per fsd-template.md §Document control header) with resolved styling + vault metadata.
4. Write to `<vault>/fsd/FSD.md`.

### Step 5: Render PDF via pandoc

1. Check `pandoc` availability:
   - Absent → skip Step 5; log warning to chat: `"⚠ pandoc not installed — skipping PDF render. Run: brew install pandoc"`; proceed to Step 6.
2. Check LaTeX engine:
   - `xelatex` present → engine = xelatex
   - `tectonic` present → engine = tectonic
   - Neither → fallback to HTML output: `pandoc <vault>/fsd/FSD.md -o <vault>/fsd/FSD.html --standalone --self-contained`; log warning: `"⚠ no LaTeX engine — emitted FSD.html instead of FSD.pdf. Print-to-PDF from browser. Install: brew install tectonic"`; proceed to Step 6.
3. Run pandoc:
   ```bash
   pandoc <vault>/fsd/FSD.md \
     -o <vault>/fsd/FSD.pdf \
     --template=plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex \
     --pdf-engine=<engine> \
     --toc \
     --toc-depth=<styling.toc_depth> \
     --variable=<styling-key>=<value>... \
     --listings
   ```
4. On pandoc non-zero exit: emit halt `quality_gate_failed` with subtype `pdf_render_failed`, details `{pandoc_stderr_tail: <last 500 chars>}`; STOP.
5. On success: log `"✓ FSD.pdf rendered (<N> pages, <size_kb>KB)"`.

### Step 6: Write citation map

Write `<vault>/fsd/.citation-map.json` with `citation_map` assembled in Step 3, per `references/section-mapping.md §Citation map schema`.

### Step 7: Emit handoff (when --auto flag)

Per `mega-sdd:orchestrate-flow/references/handoff-contract.md`, emit handoff YAML in chat (NOT to file — chat-block semantics per Iter 43 fix-forward).

See §Handoff emission below for template.

### Step 8: Summary to user (always)

Emit chat summary:

```
FSD generated (<mode>):
  Sections: <N>/<10> emitted (<excluded_count> excluded per --sections OR include_sections)
  Citations: <N> source-grounded entries
  Drift callouts: <N> sections changed since last emit
  PDF: <path OR "skipped (pandoc absent)" OR "fallback HTML (LaTeX absent)">
  Suggested next: <Confluence upload OR re-emit after diff-vault OR no action>
```

## Halt protocol

Per `mega-sdd:generate-intent/references/vault-contract.md §halt-protocol`. emit-fsd emits these halts:

- `dep_missing` — `vault_present_for_fsd` predictive check fails (no vault.json found)
- `quality_gate_failed` with subtype `pdf_render_failed` — pandoc exits non-zero in Step 5.3
- `quality_gate_failed` with subtype `template_slot_unfilled` — internal bug: a `{{slot}}` marker in fsd-template.md has no extraction rule in section-mapping.md (impossible if reference files are consistent; defensive check)

No new halt types added by emit-fsd; all halts reuse existing taxonomy.

## Handoff emission (v1.0.0+, Iter 54)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit handoff YAML at end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: emit-fsd
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/fsd/FSD.md>
    - <absolute path to <vault>/fsd/FSD.pdf>     # OR FSD.html if LaTeX absent; OR absent line if pandoc absent
    - <absolute path to <vault>/fsd/.citation-map.json>
    - <absolute path to <vault>/fsd/FSD.styling.yaml>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "FSD emitted; upload <vault>/fsd/FSD.pdf to Confluence per corporate workflow."
  blockers: []   # populated on quality_gate_failed
  metrics:
    sections_emitted: <int>          # NEW v1.0.0+, Iter 54
    sections_excluded: <int>         # NEW v1.0.0+, Iter 54 (per --sections / include_sections filter)
    citations_count: <int>           # NEW v1.0.0+, Iter 54 (total citations in .citation-map.json)
    drift_callouts_count: <int>      # NEW v1.0.0+, Iter 54 (sections changed since last emit; 0 on first emit)
    mode: <"pre-dev" | "post-dev">   # NEW v1.0.0+, Iter 54
    pdf_emitted: <true | false>      # NEW v1.0.0+, Iter 54
    fallback_format: <null | "html" | "markdown">  # NEW v1.0.0+, Iter 54 (when pandoc/LaTeX absent)
  scope:                             # OPTIONAL per Iter 28 — when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256>
```

Status `halted` on `quality_gate_failed`. Required ONLY under `--auto`.

## Memory layer

Out of scope for Iter 54. emit-fsd does NOT participate in mega-sdd memory layer (no reads, no writes). FSD generation is deterministic from vault state; no learning needed.

## Anti-hallucination rails

1. EVERY section text MUST trace to a source artifact via `.citation-map.json` entry
2. Missing source MUST emit `[Pending — <source> not yet generated]` — NEVER fabricate content
3. Slot markers `{{slot_name}}` MUST all be filled OR explicitly placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`
4. sha256 stamps in citations MUST be computed at emit-time (not cached) — drift detection depends on freshness
5. Drift callouts MUST surface in PDF — silent regeneration would hide content changes from reviewers
````

- [ ] **Step 6.3: Verify procedure body length**

Run: `wc -l plugins/mega-sdd/skills/emit-fsd/SKILL.md`
Expected: 180-220 lines (full skill body)

Run: `grep -c "^### Step\|^## " plugins/mega-sdd/skills/emit-fsd/SKILL.md`
Expected: ≥ 14 (8 procedure steps + 6 section headers)

- [ ] **Step 6.4: Commit SKILL.md procedure**

```bash
git add plugins/mega-sdd/skills/emit-fsd/SKILL.md
git commit -m "feat(iter-54): emit-fsd SKILL.md main procedure

8-step procedure: mode detect → styling load → prior-map read → per-section
emission loop → FSD.md assembly → pandoc PDF render → citation map write →
handoff emit. Plus halt protocol, handoff template, anti-hallucination rails.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Create slash command wrapper

**Files:**
- Create: `plugins/mega-sdd/commands/emit-fsd.md`

- [ ] **Step 7.1: Read existing emit-agents-md command for pattern**

Run: `cat plugins/mega-sdd/commands/emit-agents-md.md`
Expected: ~30-line markdown command wrapper that invokes the skill.

- [ ] **Step 7.2: Create emit-fsd.md following same pattern**

Create `plugins/mega-sdd/commands/emit-fsd.md`:

```markdown
---
description: Generate Hybrid Confluence FSD (Markdown + PDF) from vault/units/bolts with anti-hallucination citations
argument-hint: "[vault-path] [--mode=pre-dev|post-dev|auto] [--no-pdf] [--styling=<path>] [--sections=<csv>]"
---

# Emit FSD

Generate Functional Specification Document grounded on actual vault/units/bolts state with sha256-stamped citations.

## Usage

```bash
/mega-sdd:emit-fsd                                # default: auto-detect vault + mode
/mega-sdd:emit-fsd ./vault                        # explicit vault path
/mega-sdd:emit-fsd --mode=pre-dev                 # force pre-development mode
/mega-sdd:emit-fsd --mode=post-dev                # force post-development mode
/mega-sdd:emit-fsd --no-pdf                       # markdown only (no pandoc/LaTeX needed)
/mega-sdd:emit-fsd --sections=1,2,5,7,8,10        # emit subset for stakeholder-specific FSD
/mega-sdd:emit-fsd --styling=./my-styling.yaml    # custom styling override
```

## Output

```
<vault>/fsd/
├── FSD.md                      # Markdown source (10 Hybrid Confluence sections)
├── FSD.pdf                     # Rendered PDF (Hybrid Confluence template via pandoc)
├── FSD.styling.yaml            # Editable styling config (preserved across re-emits)
└── .citation-map.json          # Auditable citation trace
```

## Modes

- **pre-dev** (auto when no bolts/): prescriptive FSD for stakeholder sign-off; section 9 = "TBD pending execution"
- **post-dev** (auto when bolts/ present): as-built FSD with actual test results + per-FR implementation status

## Requirements

- Vault must exist (`<vault>/vault.json` present)
- For PDF: `pandoc` + `xelatex` OR `tectonic` (predictive checks warn if absent — degrades to HTML or markdown-only)

## Invokes

Invokes `mega-sdd:emit-fsd` skill. Auto-invoked at end of `/mega-sdd:auto` pipeline (skip via `--no-fsd`).

## See also

- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` — full procedure
- `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md` — canonical 10-section structure
- `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml` — styling overrides
```

- [ ] **Step 7.3: Verify command structure**

Run: `head -5 plugins/mega-sdd/commands/emit-fsd.md`
Expected: starts with `---` frontmatter block

Run: `grep -c "^## " plugins/mega-sdd/commands/emit-fsd.md`
Expected: ≥ 5 (Usage, Output, Modes, Requirements, Invokes, See also)

- [ ] **Step 7.4: Commit slash command**

```bash
git add plugins/mega-sdd/commands/emit-fsd.md
git commit -m "feat(iter-54): /mega-sdd:emit-fsd slash command wrapper

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Wire predictive-checks.md (3 new checks)

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` (add new section)

- [ ] **Step 8.1: Read existing predictive-checks structure**

Run: `grep -n "^## " plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: existing per-skill sections (scan-codebase, bind-codebase, etc.)

- [ ] **Step 8.2: Add emit-fsd preflight checks section**

In `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`, find the section that starts with `## memory preflight checks` (last existing section before `---` separator) and INSERT BEFORE the `---`:

```markdown
## emit-fsd preflight checks (v3.5.0+, Iter 54)

- **check_id: `vault_present_for_fsd`**
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "emit-fsd requires a vault. Run /mega-sdd:generate-intent first."
  fatal: yes
  predicts_halt: dep_missing (chain order error)

- **check_id: `pandoc_installed`**
  command: `command -v pandoc`
  expected: exit 0
  on_fail: "pandoc not installed; emit-fsd will produce FSD.md only (no PDF render). Install: brew install pandoc (macOS) / apt install pandoc (Debian/Ubuntu) / dnf install pandoc (Fedora)"
  fatal: no
  predicts_halt: (no halt; degraded output — markdown-only)

- **check_id: `pandoc_latex_engine_present`**
  command: `command -v xelatex || command -v tectonic`
  expected: exit 0
  on_fail: "no LaTeX engine found; pandoc PDF render needs xelatex (brew install --cask basictex / apt install texlive-xetex) OR tectonic (brew install tectonic — recommended, lighter, ~50MB vs ~2GB BasicTeX). Falls back to FSD.html for browser print-to-PDF."
  fatal: no
  predicts_halt: (no halt; degraded — HTML fallback)
```

- [ ] **Step 8.3: Verify new section added**

Run: `grep -c "emit-fsd preflight" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: 1

Run: `grep -c "check_id: \`" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: previous count + 3

- [ ] **Step 8.4: Commit predictive-checks update**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md
git commit -m "feat(iter-54): + emit-fsd preflight checks (vault/pandoc/latex)

3 new checks: vault_present_for_fsd (fatal), pandoc_installed (warn),
pandoc_latex_engine_present (warn — HTML fallback).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Wire orchestrate-flow Step 6 diagnostics + version bump

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (Step 6 diagnostics table, version bump)

- [ ] **Step 9.1: Bump version**

Find in `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`:
```
version: 3.4.0
```

Replace with:
```
version: 3.5.0
```

- [ ] **Step 9.2: Extend Step 6 diagnostics table**

Find the diagnostics table line:
```markdown
   | After all phases complete | `emit-agents-md` (per `commands/emit-agents-md.md`, respecting `config.yaml defaults.emit_agents_md: true|false`) | `AGENTS.md` (or `.mega-sdd.md` sibling) written at repo root |
```

INSERT NEW LINE immediately AFTER it:
```markdown
   | After all phases complete | `emit-fsd` (per `commands/emit-fsd.md`, respecting `--no-fsd` flag on `auto`/`orchestrate-flow`) | `<vault>/fsd/FSD.pdf` (+ FSD.md, .citation-map.json) written; chain summary: "FSD emitted: N sections, M citations, mode: <pre-dev\|post-dev>" |
```

- [ ] **Step 9.3: Verify table extended**

Run: `grep -c "emit-fsd\|emit-agents-md" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
Expected: ≥ 2 (existing emit-agents-md row + new emit-fsd row)

- [ ] **Step 9.4: Commit orchestrate-flow update**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
git commit -m "feat(iter-54): orchestrate-flow Step 6 auto-integrate emit-fsd

Adds emit-fsd to auto-integrated diagnostics table. Skip via --no-fsd on
/mega-sdd:auto or /mega-sdd:orchestrate-flow. Version 3.4.0 → 3.5.0.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: Update auto.md command to document --no-fsd

**Files:**
- Modify: `plugins/mega-sdd/commands/auto.md`

- [ ] **Step 10.1: Read current auto.md flags section**

Run: `grep -n "no-lint\|no-analyze\|no-modules-summary\|no-agents-md" plugins/mega-sdd/commands/auto.md`
Expected: existing skip flags documented; new flag follows same style

- [ ] **Step 10.2: Add --no-fsd flag documentation**

Find in `plugins/mega-sdd/commands/auto.md` the line documenting `--no-agents-md`:
```markdown
- `--no-agents-md` — skip auto AGENTS.md emission at end of chain
```

INSERT NEW LINE immediately AFTER it:
```markdown
- `--no-fsd` — skip auto FSD generation at end of chain (Iter 54 — `/mega-sdd:emit-fsd` not auto-invoked)
```

- [ ] **Step 10.3: Verify flag added**

Run: `grep -c "no-fsd\|no-agents-md" plugins/mega-sdd/commands/auto.md`
Expected: ≥ 2

- [ ] **Step 10.4: Commit auto.md update**

```bash
git add plugins/mega-sdd/commands/auto.md
git commit -m "feat(iter-54): /mega-sdd:auto + --no-fsd skip flag

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 11: Smoke test against existing vault (manual verification)

**Files:**
- No file modifications; verification only.

**Test vault:** use any existing vault in user's project. If none locally, instruct user to provide path.

- [ ] **Step 11.1: Identify test vault**

Run: `find . -name "vault.json" -not -path "*/node_modules/*" 2>/dev/null | head -3`
Expected: at least 1 vault.json path. If empty, halt — request user provide test path.

Save first match as `TEST_VAULT_DIR=$(dirname <first-match>)`.

- [ ] **Step 11.2: Verify predictive checks pass**

Run: `test -f $TEST_VAULT_DIR/vault.json && echo "✓ vault present" || echo "✗ vault missing"`
Expected: `✓ vault present`

Run: `command -v pandoc >/dev/null && echo "✓ pandoc available" || echo "⚠ pandoc absent — will fallback to markdown-only"`
Expected: either output is acceptable (the skill handles both cases).

- [ ] **Step 11.3: Dry-run the skill body (manual trace)**

Read `plugins/mega-sdd/skills/emit-fsd/SKILL.md` §Procedure.

For each Step 0-8: trace through the logic against `$TEST_VAULT_DIR`:
- Step 0 (Mode detect): inspect `$TEST_VAULT_DIR/bolts/` and `$TEST_VAULT_DIR/units/` to determine mode
- Step 1 (Styling): would create `$TEST_VAULT_DIR/fsd/FSD.styling.yaml` from defaults
- Step 2 (Prior map): `$TEST_VAULT_DIR/fsd/.citation-map.json` does not exist on first run
- Step 3 (Per-section): for each section 1-10, check existence of source artifacts per section-mapping.md
- Step 4 (Assemble): would produce FSD.md
- Step 5 (PDF): conditional on pandoc availability
- Step 6 (Citation map): writes JSON
- Step 7 (Handoff): skipped unless --auto

Document trace result in working notes (not committed): which sections would be populated, which would emit `[Pending — ...]`.

- [ ] **Step 11.4: Run actual skill (via /mega-sdd:emit-fsd)**

Run: `/mega-sdd:emit-fsd $TEST_VAULT_DIR`
Expected: skill invocation succeeds; produces files in `$TEST_VAULT_DIR/fsd/`.

Verify outputs:

```bash
ls $TEST_VAULT_DIR/fsd/
```

Expected: `FSD.md`, `FSD.styling.yaml`, `.citation-map.json` (and `FSD.pdf` if pandoc+LaTeX present; OR `FSD.html` if pandoc only; OR no extra file if pandoc absent).

- [ ] **Step 11.5: Verify FSD.md structure**

Run: `grep -c "^## " $TEST_VAULT_DIR/fsd/FSD.md`
Expected: ≥ 10 (one heading per FSD section, possibly more with subsections)

Run: `grep -c "\[Source:\|\[Pending — " $TEST_VAULT_DIR/fsd/FSD.md`
Expected: ≥ 1 (citations or pending placeholders present)

Run: `grep -c "{{" $TEST_VAULT_DIR/fsd/FSD.md`
Expected: 0 (no unfilled slot markers — all replaced)

- [ ] **Step 11.6: Verify citation-map.json schema**

Run: `python3 -c "import json; m = json.load(open('$TEST_VAULT_DIR/fsd/.citation-map.json')); print('schema:', m['schema_version'], 'mode:', m['mode'], 'sections:', len(m['sections']))"`
Expected: `schema: 1.0 mode: pre-dev|post-dev sections: N` (N ≥ 1)

- [ ] **Step 11.7: Drift detection re-run**

Touch a vault source file (e.g., add a blank line to `<vault>/01-overview.md`).

Run: `/mega-sdd:emit-fsd $TEST_VAULT_DIR`
Expected: skill detects sha256 change; emits drift callout in regenerated section 1.

Verify:
```bash
grep -c "Updated since last emit" $TEST_VAULT_DIR/fsd/FSD.md
```
Expected: ≥ 1 (drift callout present)

Revert the touch: `git checkout $TEST_VAULT_DIR/01-overview.md` (or remove the blank line manually).

- [ ] **Step 11.8: Record smoke test result**

NO commit at this task — verification only. If any step fails, fix the bug in the appropriate task (Task 1-10) and re-run that task's verification.

If all steps pass: proceed to Task 12.

---

## Task 12: Atomic release commit (plugin version bump + CHANGELOG + READMEs)

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `plugins/mega-sdd/README.md`
- Modify: `README.md`

- [ ] **Step 12.1: Bump plugin.json version**

In `plugins/mega-sdd/.claude-plugin/plugin.json`:

Find:
```json
  "version": "3.36.0",
```

Replace with:
```json
  "version": "3.37.0",
```

- [ ] **Step 12.2: Add CHANGELOG entry**

In `CHANGELOG.md`, find the existing top entry:
```markdown
## [3.36.0] - 2026-05-25
```

INSERT BEFORE it:

```markdown
## [3.37.0] - 2026-05-25

### Iter 54 — FSD Auto-Generation (new skill `emit-fsd`)

**New feature — corporate FSD deliverable.** User feedback after real-project use: "di kantor gue wajib FSD sebagai confluence, bisa ga skill ini generate FSD secara otomatis. dan fsd nya akurat". Iter 54 adds dedicated FSD emitter skill grounded on actual vault/units/bolts/binding state — no fabrication, all citations sha256-stamped, drift detection on re-emit.

**Pipeline addition:**

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield)
  → generate-units → execute-bolts → emit-agents-md → emit-fsd (NEW Iter 54)
```

**New skill: `mega-sdd:emit-fsd` (v1.0.0)**

- **Trigger:** standalone (`/mega-sdd:emit-fsd [vault]`) + auto-invoked at end of `/mega-sdd:auto` pipeline (skip via `--no-fsd`)
- **Output:** `<vault>/fsd/FSD.md` + `<vault>/fsd/FSD.pdf` + `<vault>/fsd/FSD.styling.yaml` + `<vault>/fsd/.citation-map.json`
- **PDF rendering:** pandoc + xelatex (or tectonic) for PDF; HTML fallback when LaTeX absent; markdown-only fallback when pandoc absent (predictive checks warn user)
- **Template:** Hybrid Confluence Atlassian template — 10 sections: Overview, Goals & Non-Goals, Stakeholders & Owners, User Stories, Functional Requirements, Non-Functional Requirements, Design & Architecture, API & Data Contracts, Test Plan & UAT, Risks & Open Issues

**Mode auto-detection:**

| CWD state | Mode | Section behavior |
|---|---|---|
| Vault only (no units, no bolts) | `pre-dev` | Sections 1-8 + 10 populated; section 9 = "TBD pending execution" |
| Vault + units (no bolts) | `pre-dev` (with breakdown) | Section 4 from units; section 9 = "Specified pending execution" |
| Vault + units + bolts | `post-dev` | All 10 sections; section 9 = actual UAT results + as-built per-FR status |

User override via `--mode={pre-dev|post-dev|auto}` flag.

**Anti-hallucination guarantee (the "akurat" claim):**

- Every FSD section text traces to source artifact via `.citation-map.json`
- Source artifacts cited with file path + line range + sha256 stamp (computed at emit-time)
- Missing source → emit `[Pending — <source> not yet generated]` placeholder; NEVER fabricate
- Slot markers `{{slot_name}}` all filled OR explicitly placeholdered (empty slot = halt `quality_gate_failed:template_slot_unfilled`)
- Re-emit detects sha256 changes; inserts ⚠ "Updated since last emit" callout in PDF before regenerated sections (auditability for reviewers)

**Source-of-truth mapping per section:**

| FSD Section | Source artifact |
|---|---|
| 1. Overview | `vault/01-overview.md` §Purpose + §Scope |
| 2. Goals & Non-Goals | `vault/01-overview.md` §Goals + §Non-Goals |
| 3. Stakeholders & Owners | `vault/_meta/squads.yaml` + `vault.json` author |
| 4. User Stories | `units/U-NNN.md` frontmatter |
| 5. Functional Requirements | `vault/02-functional.md` FR-NNN entries |
| 6. Non-Functional Requirements | `vault/02-functional.md §NFR` + `vault/_meta/constitution.md` |
| 7. Design & Architecture | `binding.md` §Confirmed Claims + `codebase-map.md` §Entities/Modules |
| 8. API & Data Contracts | `codebase-map.md` §Public interfaces (with `Last_Scanned_Sha256` per Iter 46) |
| 9. Test Plan & UAT | `bolts/U-NNN/bolt-report.md` acceptance_test result + self-assessment |
| 10. Risks & Open Issues | `vault/03-open-questions.md` unresolved OQs + bolt `acceptance_test_concerns` (Iter 53) |

**Styling customization** (per-project override at `<vault>/fsd/FSD.styling.yaml`):

- `company_name`, `logo_path`, `classification` (Internal/Confidential/Public)
- `font_family`, `font_size_pt`, `accent_color`, `page_size` (A4/Letter)
- `include_sections` (subset for stakeholder-specific FSDs)
- `include_citation_footnotes`, `include_drift_callouts`, `include_provenance_trailer`
- ID corporate convenience presets: `banking_indonesia`, `telco_indonesia`

**Predictive checks added (3, all in `orchestrate-flow/references/predictive-checks.md`):**

- `vault_present_for_fsd` — fatal (predicts `dep_missing`)
- `pandoc_installed` — warn (degrades to markdown-only)
- `pandoc_latex_engine_present` — warn (degrades to HTML fallback)

**orchestrate-flow extension (v3.4.0 → v3.5.0):**

- Step 6 auto-integrated diagnostics table +1 row for emit-fsd
- Skip via `--no-fsd` flag on `/mega-sdd:auto` or `/mega-sdd:orchestrate-flow`

**Files created (6):**
- `plugins/mega-sdd/skills/emit-fsd/SKILL.md` (~200 lines)
- `plugins/mega-sdd/skills/emit-fsd/references/fsd-template.md` (10-section canonical template)
- `plugins/mega-sdd/skills/emit-fsd/references/section-mapping.md` (extraction rules per section)
- `plugins/mega-sdd/skills/emit-fsd/references/styling-config.yaml` (default styling + override schema)
- `plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex` (LaTeX template)
- `plugins/mega-sdd/commands/emit-fsd.md` (slash command wrapper)

**Files modified (7):**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — Step 6 diagnostics table + version bump
- `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — 3 new checks
- `plugins/mega-sdd/commands/auto.md` — `--no-fsd` flag doc
- `plugins/mega-sdd/.claude-plugin/plugin.json` — 3.36.0 → 3.37.0
- `CHANGELOG.md` — this entry
- `plugins/mega-sdd/README.md` — version refs + What's new
- `README.md` (root) — version bump

**Out of scope (deferred):**

- **Iter 55+**: Cross-scope FSD consolidation (`/mega-sdd:emit-fsd --consolidate=BE,MW,FE`)
- **Iter 56+**: Confluence REST API direct push (with auth handling)
- **Iter 57+**: FSD-to-FSD diff tool (`/mega-sdd:diff-fsd v1.pdf v2.pdf`)
- **Iter 58+**: Indonesian translation pass
- **Iter 59+**: Strict-citation mode (`--strict-citation` halts on any drift)

**Standing directives applied:**

- **simplifikasi**: 1 new skill (with 4 reference files + 1 command) + 3 surface touches in existing files; no new halt types (reuses `quality_gate_failed` + `dep_missing`); no runtime code
- **flawless**: producer (emit-fsd) + consumer (orchestrate-flow Step 6 + predictive-checks) ship same iter — atomic
- **reuse-first**: extends emit-agents-md skill anatomy (analog pattern), Iter 33 predictive-checks pattern (3 new entries), Iter 13 auto-integrated diagnostics pattern (extension), citation discipline from binding.md (sha256 + line ranges), Iter 53 acceptance_test_concerns consumer (section 10 Risks)

**Skill version bumps:**
- New skill `emit-fsd` 1.0.0 (initial release)
- `orchestrate-flow` 3.4.0 → 3.5.0 (MINOR — new diagnostic surface)

**Plugin v3.36.0 → v3.37.0** (MINOR — new skill, backward-compatible: existing pipelines unchanged; skip flag works for users who don't want FSD).

**Pattern reinforced:** every user-feedback-driven feature (this iter) AND every audit-finding-driven feature (prior iters) both follow the same atomic-iter discipline. Cumulative-iter session pattern (advisor + code-reviewer validation gate every 3-4 iters) still applies for Iter 55+ when more features queued.

**Audit source:** user feedback during real-project test ("di kantor gue wajib FSD sebagai confluence"). Brainstorming session 2026-05-25 with single-user-approval per design section.

---

```

- [ ] **Step 12.3: Update plugin/mega-sdd/README.md folder layout + What's new**

In `plugins/mega-sdd/README.md`, find:
```markdown
├── .claude-plugin/plugin.json    # plugin manifest (v3.36.0)
```

Replace with:
```markdown
├── .claude-plugin/plugin.json    # plugin manifest (v3.37.0)
```

Find the line:
```markdown
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.2.3)
```

INSERT NEW LINE immediately AFTER it:
```markdown
│   ├── emit-fsd/                 # Confluence FSD generator (v1.0.0) — NEW Iter 54
```

Find the `## What's new` heading. INSERT BEFORE the existing `### v3.36.0 (Iter 53, minor)` entry:

```markdown
### v3.37.0 (Iter 54, minor) — FSD Auto-Generation (new skill `emit-fsd`)

User-driven feature after real-project field test. Corporate Confluence FSD is mandatory deliverable; previously generated manually outside mega-sdd. Iter 54 adds dedicated FSD emitter skill grounded on actual vault/units/bolts/binding state with anti-hallucination citation discipline.

**New skill `mega-sdd:emit-fsd` (v1.0.0):**

- Generates Hybrid Confluence-format FSD (Markdown + PDF via pandoc + xelatex/tectonic)
- 10 canonical sections (Overview, Goals, Stakeholders, User Stories, FRs, NFRs, Design, API/Data, UAT, Risks)
- Mode auto-detect: pre-development (vault only) vs post-development (vault + bolts) from CWD state
- Anti-hallucination: every section text traces to source artifact via `.citation-map.json` (sha256-stamped); missing sources emit `[Pending — X not yet generated]` placeholder, NEVER fabricate
- Drift detection: re-emit on changed sources inserts ⚠ "Updated since last emit" callout
- ID corporate styling defaults (A4, Arial 11pt, navy accent, classification stamp, draft watermark in pre-dev mode); per-project override via `<vault>/fsd/FSD.styling.yaml`

**Trigger:** standalone (`/mega-sdd:emit-fsd [vault]`) + auto-invoked at end of `/mega-sdd:auto` (skip via `--no-fsd`).

**Output:** `<vault>/fsd/FSD.pdf` (+ FSD.md, FSD.styling.yaml, .citation-map.json). User uploads PDF manually to Confluence per corporate workflow.

**Plugin v3.36.0 → v3.37.0** (MINOR — new skill; backward-compatible).

```

- [ ] **Step 12.4: Update root README.md version**

In `README.md`, find:
```markdown
**Plugin:** `mega-sdd` · **Version:** 3.36.0 · **License:** MIT
```

Replace with:
```markdown
**Plugin:** `mega-sdd` · **Version:** 3.37.0 · **License:** MIT
```

Find:
```markdown
├── plugins/mega-sdd/                       # the plugin itself (v3.36.0)
```

Replace with:
```markdown
├── plugins/mega-sdd/                       # the plugin itself (v3.37.0)
```

- [ ] **Step 12.5: Verify all version refs aligned**

Run: `grep -rn "3\.36\.0" plugins/mega-sdd/README.md README.md plugins/mega-sdd/.claude-plugin/plugin.json CHANGELOG.md 2>/dev/null | grep -v "→ 3\.37\.0\|3\.36\.0]" | head -5`
Expected: empty (no remaining stale refs; older changelog entries still cite 3.36.0 in their "## [3.36.0]" header — those are intentional history).

- [ ] **Step 12.6: Commit atomic release**

```bash
git add CHANGELOG.md README.md plugins/mega-sdd/.claude-plugin/plugin.json plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
release(iter-54): mega-sdd v3.37.0 — FSD Auto-Generation (new skill emit-fsd)

User-driven feature after real-project field test. Corporate Confluence FSD
mandatory deliverable; previously generated manually outside mega-sdd. New
emit-fsd skill produces Hybrid Confluence FSD (Markdown + PDF) grounded on
actual vault/units/bolts/binding state.

New skill: mega-sdd:emit-fsd v1.0.0
  Triggers: standalone /mega-sdd:emit-fsd + auto-invoked at end of /mega-sdd:auto
  Skip auto via --no-fsd flag
  10 sections, sha256-stamped citations, drift detection
  PDF via pandoc + xelatex/tectonic (HTML fallback / markdown-only graceful degrade)
  Mode auto-detect: pre-dev (vault only) vs post-dev (vault + bolts)

Files: 6 new + 7 modified
Skill bumps: emit-fsd 1.0.0 (new), orchestrate-flow 3.4.0 → 3.5.0
Plugin v3.36.0 → v3.37.0 (MINOR — new skill, backward-compatible)

Reuse-first: emit-agents-md skill anatomy, Iter 33 predictive-checks pattern
(3 new checks), Iter 13 auto-integrated diagnostics extension, citation
discipline from binding.md, Iter 53 acceptance_test_concerns consumer.

Anti-hallucination: every FSD section traces to source artifact via
.citation-map.json; missing source emits [Pending — X] placeholder;
sha256-stamped at emit-time for drift detection on re-emit.

Spec: docs/superpowers/specs/2026-05-25-iter-54-fsd-auto-generation-design.md
Plan: docs/superpowers/plans/2026-05-25-iter-54-fsd-auto-generation.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12.7: Push to remote**

```bash
git push origin main
```

Expected: `ok main` (push succeeds)

---

## Self-Review (writing-plans skill checklist)

**1. Spec coverage:**
- §1 Goal → Tasks 1-12 (skill ships)
- §2 Non-Goals → not implemented (deferred per spec §13)
- §3 User-facing surfaces → Tasks 1, 6, 7, 9 (skill + auto-invoke + slash command)
- §4 Skill anatomy → Tasks 1-6 (all 6 files created)
- §5 Output structure → Task 6 (Step 1, Step 4, Step 6 of SKILL.md procedure produce 4 files)
- §6 10 FSD sections → Task 3 (section-mapping.md covers all 10)
- §7 Mode auto-detection → Task 6 (Step 0 of SKILL.md procedure)
- §8 Anti-hallucination mechanism → Task 6 (Anti-hallucination rails section in SKILL.md)
- §9 Predictive preflight checks → Task 8 (all 3 added)
- §10 Styling & customization → Task 4 (full styling-config.yaml) + Task 5 (LaTeX template uses styling vars)
- §11 Integration with existing skills → Task 9 (orchestrate-flow Step 6) + Task 10 (auto.md)
- §12 Implementation scope → all 12 tasks (release in Task 12)
- §13 Out of scope → not implemented (intentional deferral)
- §14 Success criteria → Task 11 (smoke test verifies all 10 success criteria)

**Spec coverage: 100% — every requirement has a task.**

**2. Placeholder scan:**
- "(filled in subsequent tasks — see plan)" in SKILL.md Task 1 → replaced in Task 6 (intentional placeholder during scaffolding)
- No "TBD" / "TODO" / "implement later" / "add appropriate handling" patterns in any task body
- All code blocks complete (Markdown content, YAML config, LaTeX template, Bash commands)

**Placeholder scan: clean.**

**3. Type consistency:**
- `<vault-path>` placeholder used consistently (input arg + output paths in §5 of spec and Tasks 6, 7, 11)
- `mode = pre-dev | post-dev` enum consistent across spec, SKILL.md procedure, section-mapping.md, handoff metrics, CHANGELOG
- `quality_gate_failed` halt type reused (no new halt types introduced — confirmed in Task 6 Halt protocol section)
- `acceptance_test_concerns` field name (from Iter 53) consistent with reference in Task 6 + spec §10 + section-mapping.md §Section 10
- File path conventions (`<vault>/fsd/...`) consistent across all references

**Type consistency: clean.**

**Plan ready for execution.**

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-iter-54-fsd-auto-generation.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch fresh subagent per task, two-stage review (spec compliance + code quality) after each, fast iteration. Best for: long plan with independent tasks (which this is — 12 mostly-independent tasks).

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Best for: short plan or when you want to read every change yourself before commit.

**Recommendation: Subagent-Driven** — Iter 54 is mostly independent tasks (only Tasks 6, 9, 10, 12 have minor dependencies on prior tasks; rest can be parallelized conceptually though we'll execute serial for atomic-iter discipline). Subagent dispatch keeps main-thread context clean for Iter 55+ planning afterward.

Which approach?
