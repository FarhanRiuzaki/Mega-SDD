---
name: generate-units
version: 1.1.0
description: Decompose a (bound-)vault into atomic AI-executable unit specs per `references/unit-schema.md`. Each unit = one PR-sized bolt. Builds dependency graph; rejects cycles. Triggers — "generate units", "vault to units", "bikin units", "pecah vault jadi unit", "dev tasks dari vault", or paraphrases.
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

## Anti-hallucination rails

- Every unit MUST cite vault source (file:section).
- No unit may touch files outside its `target_files` (enforced at bolt time).
- No unit may have empty `acceptance_test`.
- Unit body MUST NOT invent functionality not present in vault.
- OQs surface explicitly as "TBD" — never silently fabricated.
- (v1.1+) `depends_on` is intra-squad only; cross-squad coupling MUST route through interface notes.
- (v1.1+) Interface references resolve to existing files; no fabricated interface IDs.

## Halt conditions

- Dependency cycle detected → halt, restructure required
- Unit needs target_files but vault doesn't specify → halt, vault refinement needed
- Bound-vault has unresolved CONFLICTs → refuse, instruct binding re-run
- `vault.json` missing → halt, vault corruption
- (v1.1+) Cross-squad direct dependency in `depends_on` → halt, route via interface
- (v1.1+) `consumes_interfaces` or `produces_interfaces` references missing file → halt, author interface first
- (v1.1+) Two squads claim same artifact at same precedence level → halt, refine squads.yaml

## Hand-off

- "Generated N units. Suggested next: `/mega-sdd:execute-bolts --all` to execute in order, or `/mega-sdd:execute-bolts U-001` to start with the first."
