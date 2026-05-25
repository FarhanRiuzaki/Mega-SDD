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
