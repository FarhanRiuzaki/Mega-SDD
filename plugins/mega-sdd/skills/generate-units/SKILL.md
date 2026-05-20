---
name: generate-units
version: 1.4.0
description: Decompose a (bound-)vault into atomic AI-executable unit specs per `references/unit-schema.md`. Each unit = one PR-sized bolt. (v1.2+, Iter 1) Reads `binding.md` Implementation State Map to assign `task_type: create | verify` per unit. (v1.3+, Iter 3) Emits polished AI-coding-prompt-shape units — Anchors mandatory when binding evidence exists, Anti-patterns drawn from binding+KB, Hard rules parseable grammar, Implementation steps as directive prose. Builds dependency graph; rejects cycles. Triggers — "generate units", "vault to units", "bikin units", "pecah vault jadi unit", "dev tasks dari vault", or paraphrases.
---

# Generate-Units

Turns intent into actionable atomic specs for AI dev execution.

**Announce at start:** "I'm using the generate-units skill to decompose the vault into atomic units."

## When to use

- After `bind-codebase` produced bound-vault (brownfield) OR directly after `generate-intent` (greenfield)
- `orchestrate-flow` auto-routes to this after vault is ready
- User explicit: `/mega-sdd:generate-units <bound-vault>`

## Inputs

- Bound-vault OR vault path (positional, required)
- Flags: `--refresh` (re-number IDs from scratch), `--max-complexity=small|medium` (split anything bigger), `--auto`

## Output

`<vault>/units/U-001.md`, `U-002.md`, ... per `references/unit-schema.md`. Also writes `<vault>/units/_index.md` with dependency graph.

## Procedure

1. **Load vault.** Read 7 files + vault.json. If bound-vault path provided, also read binding.md.

2. **Identify unit candidates.** Walk vault sections (02-architecture, 04-flows, 03-data-model). Each implementable artifact (a component, endpoint, schema migration, etc.) becomes a candidate unit.

2.5. **Determine task_type per candidate (v1.2+, Iter 1).**

   If bound-vault has `binding.md` with Implementation State Map (v1.2+), assign `task_type` per the table below. If no Implementation State Map (greenfield OR pre-v1.2 binding) → every candidate is `create`.

   For each candidate unit, find the binding claims it derives from (via vault claim → binding C-XXX mapping). Aggregate their states:

   | Bound claim states (Iter 1 set: IMPLEMENTED / NEW / UNKNOWN) | Unit task_type |
   |---|---|
   | All NEW, or no binding | `create` |
   | All IMPLEMENTED with `confidence: high` | `verify` |
   | Mix of NEW + IMPLEMENTED | SPLIT — emit one `create` unit for NEW claims, one `verify` unit for IMPLEMENTED claims; chain via `depends_on` so verify runs first |
   | Any UNKNOWN (regardless of confidence) | `create` (conservative default per DESIGN-OQ-1) — surface a note in unit body: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed." |
   | Mix of CONFIRMED + CONFLICT | Halt — binding gate should have blocked already; report inconsistency |

   `verify` unit specifics (enforced by `references/unit-schema.md` §Per-task_type contracts):
   - `target_files` is empty OR all entries `operation: none`
   - `acceptance_test` carries assertions that prove existing implementation still works
   - Body's `## Implementation steps` is ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
   - Body's `## Anchors` section is MANDATORY — cite the file:line where the implementation lives (from binding's `anchor` field)
   - Estimated complexity: small

   `extend` is in the schema (forward-compat for Iter 2/3) but **Iter 1 does not auto-emit it**. UNKNOWN states default to `create` (safer). A user who wants `extend` semantics in Iter 1 must edit the unit frontmatter and fill Migration notes manually.

3. **Group + atomize.** For each candidate:
   - If estimated change < 300 LOC and touches ≤ 5 files → single unit
   - If larger → split into N units with explicit `depends_on` chain
   - If a unit needs an OQ resolved → mark in body as "TBD: <OQ-ID>" + add to acceptance criteria

4. **Resolve dependency graph.**
   - Build DAG from semantic deps (entity before flow that uses it, schema migration before code that depends on column)
   - **Reject cycles.** If detected, halt and instruct user to restructure vault sections.
   - **(v1.1+) Reject cross-squad direct deps in multi-squad mode.** After Step 5
     (squad assignment) completes, walk every `depends_on` edge and verify both
     endpoints have the same `squad:`. If a `depends_on` edge crosses squads,
     halt with `cross_squad_dep_invalid` (see §halt-protocol).
   - **(v1.1+) Validate interface references.** For each unit with
     `consumes_interfaces` or `produces_interfaces`, verify each listed
     interface ID resolves to an existing `<vault>/interfaces/<id>.md` file.
     Dangling references halt with `interface_ref_missing`.

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: cycle_detected
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    cycle_path: [U-001, U-002, ..., U-001]  # node sequence forming the cycle
  next_action: "Restructure vault sections so unit dependencies form a DAG (no back-edges)"
```

**Structured halt per `vault-contract.md §halt-protocol` (v1.1+):**

```yaml
blocker:
  type: cross_squad_dep_invalid
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    dependency_id: U-YYY
    dependency_squad: squad-be
  next_action: "Cross-squad direct depends_on is not allowed. Route the coupling through an interface note: producer squad declares produces_interfaces, consumer squad declares consumes_interfaces. See interfaces/_index.md."
```

```yaml
blocker:
  type: interface_ref_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    missing_interface_id: api-leave-request-submit
    referenced_in: consumes_interfaces
  next_action: "Create interfaces/api-leave-request-submit.md from interface-note.template.md, fill the contract, and re-run generate-units."
```

```yaml
blocker:
  type: cross_squad_ambiguous
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    artifact: F-U-007
    artifact_kind: flow
    claimed_by_squads: [squad-fe-web, squad-mobile]
    matched_via: owns_layers
  next_action: "Two squads claim ownership at the same precedence level. Refine _meta/squads.yaml so exactly one squad matches this artifact, then re-run generate-units."
```

5. **Squad assignment (v1.1+).** Load `_meta/squads.yaml` if present.

   **If file absent OR single squad declared:**
   - Single-squad / no-squad mode active
   - All units get `squad: default` (or field omitted)
   - Skip all multi-squad validations below

   **If ≥2 squads declared:**
   - Per `references/squad-partition.md` routing rules, assign `squad:` to each
     unit based on its `vault_source` and the relevant layer/feature tags.
   - For each candidate unit:
     - Determine primary layer from its `vault_source` (e.g., a unit derived
       from `02-architecture.md#backend` → layer `backend`)
     - Match against squad ownership rules with precedence:
       `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`
     - Set `squad: <matched-id>`
   - **Unrouted units**: emit warning (not halt) and assign `squad: default` so
     execution can proceed. User should refine `squads.yaml` and re-run.
   - **Ambiguous routing** (two squads claim same artifact at same precedence
     level): halt with `cross_squad_ambiguous` (see §halt-protocol additions).

6. **Allocate IDs.** Stable scheme:
   - Sort candidates topologically
   - Number U-001, U-002, ...
   - On `--refresh`: re-number from scratch
   - On default re-run: preserve IDs of unchanged units by content hash

7. **Fill `target_files` whitelist.**
   - Greenfield: list expected files (from vault component definitions)
   - Brownfield: list bound-vault citations (specific file paths from binding)
   - If a unit can't determine target_files: halt — vault too vague

8. **Fill `existing_interfaces`.**
   - Brownfield only: pull from binding manifest CONFIRMED entries for the targeted files
   - Greenfield: empty (no existing interfaces)

9. **Fill `acceptance_test`.**
   - At least one `type: test` entry (mandatory)
   - Generate test command stub matching detected test framework from codebase-map (greenfield: pick sensible default)
   - Add `type: manual` for user-visible flows

10. **Write each unit file** using `references/templates/unit.md` as the body template.

11. **Write `_index.md`** with:
    - Total unit count
    - Dependency DAG (Mermaid graph)
    - Suggested execution order (topological)

12. **Audit log.** Append to `vault.json`: `{ "event": "units_generated", "at": "...", "count": N }`.

12.4. **Polished-prompt render pass (v1.3+, Iter 3).**

   After all units written but BEFORE the dedup check, sweep each unit and validate the prompt-shape contract per `references/unit-schema.md`:

   a. **Anchors presence rule**:
      - `task_type: verify` OR `task_type: extend` → `## Anchors` section MUST have ≥1 entry. Missing → halt `unit_underspecified`.
      - `task_type: create` AND ≥1 `binding_refs` entry pointing to a related pattern → `## Anchors` MUST have ≥1 entry citing the closest pattern. Missing → halt `unit_underspecified`.
      - `task_type: create` AND fully greenfield (no binding) → Anchors section optional.

   b. **Hard rules grammar parse**: each line under `## Hard rules` MUST match one of the 5 grammar productions in `references/unit-schema.md` §Hard rule grammar. Unparseable line → halt `hard_rule_unparseable` with the offending line + which production failed.

   c. **Directive prose check on Implementation steps**:
      - Extract the body of `## Implementation steps`
      - If body is pure bullet list (no sentence >15 words detected) → emit WARNING (not halt) in chat: "Unit U-XXX Implementation steps is bullet-only. Consider directive prose for AI coding consumption."
      - For `task_type: verify`: the single-line "No code changes..." sentence is acceptable as-is (special case).

   d. **Migration notes rule**:
      - `task_type: extend` → `## Migration notes` MUST exist AND have all three sub-lists (REMOVE / KEEP / ADD) populated (any can be `none` but must be present). Missing → halt `unit_underspecified`.
      - `task_type: create` OR `task_type: verify` → `## Migration notes` section MUST be absent.

   e. **Anti-patterns harvesting (suggestion, not requirement)**:
      - If binding has CONFLICTs or KB has gotchas in domains this unit covers → suggest filling `## Anti-patterns` section with the relevant items
      - Auto-populate from `binding.md` "## Suggested Unit Hard Rules" (Iter 3 addition in bind-codebase) and KB `## 9. Edge Cases & Gotchas` sections when applicable
      - Anti-patterns are guidance only — no halt if absent

   **Halt YAML format:**

   ```yaml
   blocker:
     type: unit_underspecified
     emitted_at: <ISO8601 timestamp>
     emitted_by: generate-units
     details:
       unit_id: U-XXX
       missing_sections: [Anchors, Migration notes]
       reason: "task_type=extend requires Anchors AND Migration notes; both missing"
     next_action: "Re-run generate-units OR manually populate the missing sections."
   ```

12.5. **Deduplication check (v1.2+, Iter 1).**

   After all units written, sanity-check `task_type: create` units against the Implementation State Map:

   - For each `task_type: create` unit where EVERY `target_files` entry's path is already present in codebase-map §1 (Top-level structure / file tree) AND its operation is `create`:
     - This signals a likely mistake — the unit wants to create a file that already exists.
     - Halt with structured `dedup_ambiguous` blocker (per DESIGN-OQ-2). NEVER silent-rewrite.

   **Halt YAML:**

   ```yaml
   blocker:
     type: dedup_ambiguous
     emitted_at: <ISO8601 timestamp>
     emitted_by: generate-units
     details:
       unit_id: U-XXX
       conflicting_paths: [src/foo.ts, tests/foo.test.ts]
       reason: "Unit task_type=create but all target_files already exist in codebase-map. Implementation State Map did not classify these claims as IMPLEMENTED — possible binding gap OR genuine intent to overwrite."
       suggested_resolutions:
         - "If existing files are unrelated (name collision), rename the unit's target_files."
         - "If existing files SHOULD be modified, edit unit frontmatter: task_type=extend + fill Migration notes."
         - "If existing files SHOULD be replaced (rebuild scenario), confirm intent and re-run with --force-overwrite (NOT YET IMPLEMENTED — pause and consult human)."
     next_action: "Resolve manually then re-run /mega-sdd:generate-units."
   ```

## Anti-hallucination rails

- Every unit MUST cite vault source (file:section).
- No unit may touch files outside its `target_files` (enforced at bolt time).
- No unit may have empty `acceptance_test`.
- Unit body MUST NOT invent functionality not present in vault.
- OQs surface explicitly as "TBD" — never silently fabricated.
- (v1.1+) `depends_on` is intra-squad only; cross-squad coupling MUST route through interface notes.
- (v1.1+) Interface references resolve to existing files; no fabricated interface IDs.
- (v1.2+, Iter 1) `task_type` is assigned ONLY from binding's Implementation State Map. Never inferred from vague heuristics. UNKNOWN state → conservative `create` default.
- (v1.2+, Iter 1) `verify` units MUST have a concrete `anchor` from binding; missing anchor → downgrade to `create`.
- (v1.2+, Iter 1) Dedup check halts with `dedup_ambiguous` — NEVER silent-rewrites a unit's task_type.
- (v1.3+, Iter 3) Anchors section is MANDATORY when binding evidence exists (per task_type rules). Missing → halt `unit_underspecified`.
- (v1.3+, Iter 3) Hard rules grammar is parseable (5 closed grammar types). Unparseable rule → halt `hard_rule_unparseable`. NEVER silently skip.
- (v1.3+, Iter 3) Anti-patterns drawn from binding CONFLICTs + KB gotchas; suggestion only (not halt-condition).

## Halt conditions

- Dependency cycle detected → halt, restructure required
- Unit needs target_files but vault doesn't specify → halt, vault refinement needed
- Bound-vault has unresolved CONFLICTs → refuse, instruct binding re-run
- `vault.json` missing → halt, vault corruption
- (v1.1+) Cross-squad direct dependency in `depends_on` → halt, route via interface
- (v1.1+) `consumes_interfaces` or `produces_interfaces` references missing file → halt, author interface first
- (v1.1+) Two squads claim same artifact at same precedence level → halt, refine squads.yaml
- (v1.2+, Iter 1) `verify` unit task_type assigned but binding's `anchor` field is empty → halt, binding gap
- (v1.2+, Iter 1) Dedup check finds a `create` unit whose target_files all exist → halt with `dedup_ambiguous`
- (v1.3+, Iter 3) Unit missing required `## Anchors` (verify/extend), `## Migration notes` (extend), or required structure → halt `unit_underspecified`
- (v1.3+, Iter 3) Hard rule line cannot be parsed against 5-grammar set → halt `hard_rule_unparseable`

## Hand-off

- "Generated N units. Suggested next: `/mega-sdd:execute-bolts --all` to execute in order, or `/mega-sdd:execute-bolts U-001` to start with the first."

## Handoff emission (v1.4+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: generate-units
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to units/ directory>
    - <absolute path to units/_index.md>
  next_action:
    suggested_skill: mega-sdd:execute-bolts
    suggested_args: ["--all", "--auto"]
    rationale: "Units generated; execute via bolts."
  blockers: []   # populated on cycle/cross-squad/dedup/unit_underspecified/hard_rule_unparseable
  metrics:
    items_processed: <N units>
    items_blocked: 0
```

Status `halted` on `cycle_detected` / `cross_squad_dep_invalid` / `interface_ref_missing` / `cross_squad_ambiguous` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable`. Required ONLY under `--auto`.
