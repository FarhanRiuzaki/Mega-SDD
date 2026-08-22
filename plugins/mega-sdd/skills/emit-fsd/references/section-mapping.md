# Section Mapping — Source Artifact → FSD Section

> **Per-section: source artifact path(s), extraction rules, citation format.**
> **EXECUTED BY `scripts/build-fsd-core.sh`** — the deterministic
> builder runs every rule below in one spawn and writes `FSD.md` pre-filled;
> the model reviews (delete/reformat-only authority) and never re-derives a
> section by hand. Editing a rule here MUST be mirrored in the builder — the
> two are one contract (the 2a routing-table lesson: this file DOCUMENTS what
> the script executes).
> Every slot in `fsd-template.md` MUST have an extraction rule here.
>
> **§6 amendment (5e):** the old "de-dup if both sources mention same
> constraint (prefer constitution)" was model judgment; the builder instead
> emits BOTH sources under labeled sub-blocks (`_Dari 02-functional §NFR:_` /
> `_Dari constitution [LOCKED]:_`) — over-complete + labeled is deterministic,
> and a duplicate is not fabrication.
>
> This file is the FSD doc-pack's **section map** for the shared emission engine
> (`plugins/mega-sdd/references/emission-engine.md` §What a doc-pack supplies) —
> the engine spine is doc-agnostic; every FSD-specific extraction rule lives here.

## Contents

- Source-of-truth priority
- Mode determination (Step 0 in SKILL.md)
- Section 1 — Overview
- Section 2 — Goals & Non-Goals
- Section 3 — Stakeholders / Owners
- Section 4 — User Stories
- Section 5 — Functional Requirements
- Section 6 — Non-Functional Requirements
- Section 7 — Design / Architecture
- Section 8 — API & Data Contracts
- Section 9 — Test Plan & UAT
- Section 10 — Risks & Open Issues
- Citation slot extraction
- Citation map schema
- Drift detection

## Source-of-truth priority

1. **Vault files** (`<vault>/00-index.md`, `01-overview.md`, ..., `vault.json`) — declarative intent
2. **Binding** (`<vault>/binding.md`, `<vault>-bound/` OR `bound-vault/`) — code-validated state
3. **Codebase map** (`<project>/.mega-sdd/codebase/codebase-map.md`) — actual codebase facts
4. **Units** (`<vault>/units/U-NNN.md`) — decomposition
5. **Bolts** (`<vault>/bolts/U-NNN/bolt-report.md`) — execution results

## Mode determination (Step 0 in SKILL.md)

```
IF <vault>/bolts/ exists AND has ≥1 U-*/bolt-report.md → mode = post-dev
ELIF <vault>/units/ exists AND has ≥1 U-*.md → mode = pre-dev (with breakdown)
ELSE → mode = pre-dev (vault-only)
```

User override: `--mode=pre-dev` OR `--mode=post-dev` forces regardless of CWD state.

## Section 1 — Overview

**Slot:** `{{section-1-content}}`
**Source:** `<vault>/01-overview.md` §Purpose/§Product + §Scope/§Target users (the generate-intent template emits §Product/§Problem/§Success criteria/§Out of Scope — the builder accepts BOTH vocabularies, numbered headings tolerated)
**Extraction:** Read entire §Purpose|§Product block + §Scope|§Target-users block; preserve markdown formatting; strip vault-internal anchors.
**Citation:** `[¹] Source: vault/01-overview.md:L<purpose_start>-L<scope_end> (sha256: pending)`
**Missing source:** emit `[Pending — vault/01-overview.md not yet generated]`

## Section 2 — Goals & Non-Goals

**Slots:** `{{section-2-goals-content}}`, `{{section-2-non-goals-content}}`
**Source:** `<vault>/01-overview.md` §Goals/§Success criteria + §Non-Goals/§Out of Scope (both vocabularies accepted)
**Extraction:** Per §Goals: extract bulleted/numbered list as-is. Per §Non-Goals: same.
**Citation:** inline footnote per sub-section.
**Missing source:** emit per sub-section `[Pending — vault/01-overview.md §Goals not yet generated]`

## Section 3 — Stakeholders / Owners

**Slot:** `{{section-3-stakeholders-table}}`
**Source priority:**
1. `<vault>/_meta/squads.yaml` (if present; multi-squad vaults)
2. `<vault>/vault.json.stakeholders[]` (when populated)
3. `<vault>/vault.json.author` field (fallback — single-author project)

**Extraction:**
- From squads.yaml: emit one row per squad: `{squad.role} | {squad.lead_name} | {squad.responsibility}`
- From vault.json.stakeholders[]: emit one row per entry: `{role} | {name} | {responsibility}`
- Fallback: emit single row `Author | {vault.author} | Project owner`

**Citation:** `[¹] Source: vault/_meta/squads.yaml` OR `vault.json` (sha256: pending)
**Missing source:** emit single row with `Author | (unspecified — vault.json.author missing) | Project owner` + warning callout above table.

## Section 4 — User Stories

**Slot:** `{{section-4-user-stories-content}}`
**Source:** `<vault>/units/U-NNN.md` (all units, sorted by U-ID ascending)
**Extraction per unit:**
- `as_a`: from unit frontmatter `user_story.as_a` field; if absent, derive from `unit.scope` (e.g., "API consumer" for BE-scope unit, "End user" for FE-scope)
- `i_want`: from `unit.title` or frontmatter `user_story.i_want`
- `so_that`: from `unit.business_value` or frontmatter `user_story.so_that`; if absent, leave `(unspecified)`
- `acceptance_test_summary`: 1-line condensation of `unit.acceptance_test.command` + expected outcome

**Citation:** per-story footer `[Source: units/U-NNN.md (sha256: pending)]`
**Missing source (no units/):** emit `[Pending — units/ directory not yet generated. Run generate-units after vault stabilizes.]`

## Section 5 — Functional Requirements

**Slots:** `{{section-5-fr-table}}`, `{{section-5-fr-details}}`
**Source priority (P4 repair — modern-first via legacy-first-hit):**
1. `<vault>/02-functional.md` — every FR-NNN heading (the legacy vault generation; wins when the file exists)
2. `<vault>/04-flows.md` — every `### F-*` flow heading (the MODERN vault generation — today's generate-intent emits no 02-functional.md; the flows + per-flow DoD are its functional enumeration, the same substrate SIT builds from). Description = the flow's Definition-of-Done bullets; **priority stays an honest `—`** (flows carry no Priority field — never default one).
**Extraction (legacy branch):**
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

**Citation:** per-FR `[Source: vault/02-functional.md:L<start>-L<end> (sha256: pending)]` — or `vault/04-flows.md:L<start>-L<end>` on the flows branch
**Missing source (NEITHER file yields rows):** emit `[Pending — vault/02-functional.md (legacy) / vault/04-flows.md not yet generated]`

## Section 6 — Non-Functional Requirements

**Slots:** `{{section-6-performance-content}}`, `{{section-6-security-content}}`, `{{section-6-availability-content}}`, `{{section-6-other-constitution-content}}`
**Source priority:**
1. `<vault>/02-functional.md` §NFR (if section exists — the legacy generation)
2. `<vault>/06-constraints.md` `## Non-functional requirements` table (the MODERN generation — P4 repair; rows keyword-routed per category, an unmatched row lands in Other, never dropped; labeled `_Dari 06-constraints §Non-functional requirements:_`)
3. `<vault>/_meta/constitution.md` LOCKED clauses (filter by category: performance / security / availability / compliance)

**Extraction:**
- From 02-functional NFR section: extract per sub-category
- From the 06-constraints table: keyword-route each row (performance/latency/throughput · security/auth/encrypt · availability/uptime/sla; ID + EN keywords) into the matching slot
- From constitution.md: filter LOCKED clauses by category tag; extract clause body
- ~~De-dup if both sources mention same constraint (prefer constitution.md as canonical)~~ **AMENDED (5e, see header):** both sources are emitted under labeled sub-blocks — deterministic, duplicates are not fabrication

**Citation:** `[¹] vault/02-functional.md §NFR` AND/OR `[²] vault/06-constraints.md` AND/OR `[³] vault/_meta/constitution.md §LOCKED:<category>`
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

**Citation:** per source `[¹] binding.md:L<line>` AND `[²] codebase-map.md §Entities (sha256: pending)`
**Missing source:** if binding.md absent → emit `[Pending — binding.md not yet generated. Run bind-codebase.]`; if codebase-map absent → `[Pending — codebase-map.md not yet generated. Run scan-codebase.]`

## Section 8 — API & Data Contracts

**Slots:** `{{section-8-api-table}}`, `{{section-8-entities-content}}`
**Source:** `codebase-map.md` §Public interfaces table

**Extraction:**
- Read §Public interfaces table (columns: endpoint/function, signature, source file:line, last_scanned_sha256)
- Emit table rows: `| {name} | {signature} | {source_path}:L{line} |`
- Append entities content: nested list of all entities from §Entities (sha256-stamped per row)

**Citation:** per row `[Source: codebase-map.md §Public interfaces:L<line> (sha256: pending)]` — the model never transcribes `Last_Scanned_Sha256` values; the stamp is computed by the script from `codebase-map.md` bytes
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
- Acceptance concerns: aggregate `acceptance_test_concern:` fields from each bolt-report — emit per-bolt list

**Citation:** per row `[Source: bolts/{unit_id}/bolt-report.md (commit: {sha_short})]`
**Missing source:**
- pre-dev mode + no units → row says `Pending — units/ not yet generated`
- post-dev mode + no bolts for a unit → row says `Pending — bolt not yet executed for {unit_id}`

## Section 10 — Risks & Open Issues

**Slots:** `{{section-10-oq-table}}`, `{{section-10-bolt-concerns-content}}`, `{{section-10-out-of-scope-content}}`
**Source:**
1. `<vault>/03-open-questions.md` (or `vault.json.open_questions[]`) — filter where `status != resolved`
2. Bolt-reports `acceptance_test_concern:` aggregated
3. `<vault>/01-overview.md` §Non-Goals (out-of-scope items)

**Extraction:**
- OQs: per unresolved OQ emit row `| {oq_id} | {question} | {priority} | {category} |`
- Bolt concerns: per concern emit `**{unit_id}:** {concern_text} (raised by {bolt_subagent_id})`
- Out-of-scope: extract from 01-overview §Non-Goals (re-used from Section 2 but reformatted as risk-framing)

**Citation:** per source `[¹] vault/03-open-questions.md` AND `[²] bolts/<unit_id>/bolt-report.md` AND `[³] vault/01-overview.md §Non-Goals`
**Missing source:** empty arrays emit `(none)`; do NOT halt.

## Citation slot extraction

Each FSD section in `fsd-template.md` has a `{{section-N-citations}}` slot (10 total — one per section). The citation slot aggregates ALL source paths + line ranges + sha256 stamps used by that section into a formatted footer block.

**Extraction rule (per section N):**

1. Collect the source citations section N used during Step 3 (every source path + line range cited by that section's body).
2. De-duplicate by `source_path` (multiple FR entries in section 5 may cite the same vault/02-functional.md).
3. Emit footer block:

   ```markdown
   **Sources for this section:**
   - [¹] `<source_path>:L<start>-L<end>` (sha256: `pending`)
   - [²] `<source_path>:L<start>-L<end>` (sha256: `pending`)
   ```

   Stamps are placeholders at authoring time; `scripts/build-citation-map.sh` replaces them with real 12-char hashes and writes the map (SKILL.md Step 4.6). The model never writes hash characters.

4. If section has zero citations (e.g., section 9 in pre-dev mode with no bolts, section 6 NFR when nothing specified): emit:

   ```markdown
   **Sources for this section:** _(no source artifacts cited — see [Pending] markers above for missing sources)_
   ```

5. If `styling.include_citation_footnotes: false` → emit empty string (slot suppressed per styling override).

**Halt path:** a citation whose path resolves to no existing file is caught deterministically at SKILL.md Step 4.6 — `build-citation-map.sh` exits 1 → halt `quality_gate_failed:citation_unresolvable` (never a prose-trusted defensive check). A slot with no extraction rule at all remains `quality_gate_failed:template_slot_unfilled` (Step 4.5).

**Previously:** `fsd-template.md` declared 10 `{{section-N-citations}}` slot markers but `section-mapping.md` had NO extraction rule for them. Result before fix:
- Best case: skill body halt `template_slot_unfilled` on every FSD emit (defensive)
- Worst case: literal `{{section-1-citations}}` placeholder ships to PDF
- Worst-worst case: bolt subagent invents content to fill the slot (anti-halu rail break)

Closed by the extraction rule above.

## Citation map schema

`<vault>/fsd/.citation-map.json` — SCRIPT-WRITTEN by `scripts/build-citation-map.sh` (SKILL.md Step 4.6); the model never authors or edits this file:

```json
{
  "schema_version": "2.0",
  "emitted_at": "2026-07-19T10:30:00Z",
  "emitted_by": "emit-fsd via scripts/build-citation-map.sh",
  "vault_sha256": "abc...",
  "mode": "pre-dev" | "post-dev",
  "sections": [
    {
      "fsd_section": "5.FR-007",
      "source_path": "vault/02-functional.md",
      "resolved_path": ".mega-sdd/vaults/v1/02-functional.md",
      "source_lines": "L78-L92",
      "source_sha256": "def...",
      "emitted_text_sha256": "ghi..."
    }
  ],
  "missing_sources": [
    {"section": "9", "expected_source": "bolts/", "reason": "pre-dev mode"}
  ]
}
```

Schema 2.0 notes (v1.4.0 — every hash originates from `hashlib.sha256` over actual file bytes inside the script):

- `source_path` keeps the AS-CITED display form; `resolved_path` (new) is the project-root-relative path the hash was actually computed over (resolution order: `vault/`-prefix → vault → project → codebase-map).
- An unresolvable citation gets `source_sha256: null` + `unresolved: true` (and the script exits 1 → `citation_unresolvable` halt).
- `emitted_text_sha256` = sha256 of the raw byte-slice of that FSD section AFTER stamping (redefined under the 2.0 bump; no consumer existed for the 1.0 meaning).
- `emitted_by` includes the script name.
- `missing_sources[]` shape `{section, expected_source, reason}` unchanged — script-derived from the `[Pending — …]` markers in FSD.md (consumer: orchestrate-flow `chain-execution.md` final summary).
- `--sections` subset re-emit: the map reflects only the sections present in FSD.md (exact parity with pre-2.0 behavior; no merge-prior carry-forward).

## Drift detection

On re-emit (SKILL.md Step 2): run `bash <plugin-root>/scripts/build-citation-map.sh --check-drift --vault=<vault> --cwd=<project-root>` and consume ONLY its output lines — the model does not read the map:

- `DRIFT <section> <path> <old12> <new12>` / `GONE <section> <path> <old12>` → flag that section for a drift callout, using `old12`/`new12` in the callout text
- `UNVERIFIED <section> <path>` → informational (a prior entry that cannot be re-verified — e.g. a legacy schema-1.0 display-form path that no longer resolves); no callout
- `NO_PRIOR` / `PRIOR_UNREADABLE` → first emit; no callouts
- no output → nothing drifted

Drift callout text inserted as block quote BEFORE regenerated section (per fsd-template.md drift callout format).
