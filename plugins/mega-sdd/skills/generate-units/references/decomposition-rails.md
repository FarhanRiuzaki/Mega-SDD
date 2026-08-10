# generate-units — decomposition & dependency rails

## Contents
- Flow-step → artifact derivation (Step 2.2)
- Dependency-graph emission + cycle rejection (Step 4)
- Module assignment (Step 4.5)
- Squad assignment (Step 5)
- ID allocation (Step 6)
- Render test for view-bearing units (Step 9)
- UI contract for view-bearing units (Step 9.b)
- Adversarial test review pass (Step 9.5)

Loaded by `generate-units/SKILL.md` for the decomposition/grouping/ID/test steps. The emitted YAML for every halt named here is in the halt-protocol reference (see the skill router's "Specialist references"); this file names the trigger condition only.

## Flow-step → artifact derivation (Step 2.2)

Do NOT decompose flows at module granularity only. For each USER flow (`F-U-*`) in `04-flows.md`, enumerate its **input-accepting state-transition steps** — every numbered step (including signals in its sub-bullets, e.g. `workflow_state → SUBMITTED`) that accepts a payload to advance state (submit / review / approve / reject / confirm / dispatch / apply / finalize / enrich / examine / resubmit per the active pack's `## Flow-artifact derivation` `flow_signal`). The set of per-step input-validation artifacts a module unit ships **equals** the set of input-accepting steps its flow enumerates — no more, no fewer:

- **One artifact per step, not one per controller.** A 5-stage maker-checker flow needs 5 Form Requests (Laravel) / 5 serializers (DRF) / 5 validation schemas (Express) — list each in the unit's `## Target files`. Listing only `Store…Request` + `CraApprove…Request` while the flow has 5 input steps is the exact under-decomposition the validator flags (proven: 8 missing per-stage Form Requests in the tradefinance Phase-2 run).
- **Drop conditional scaffold artifacts with no gating flow.** A generic CRUD scaffolder emits an `edit`/update view for every resource, but a maker-checker entity advanced through workflow transitions has no update/PUT flow step — so that view is a dead stub. Do NOT list a conditional artifact (active pack `## Conditional scaffold artifacts` `artifact_glob`) in `## Target files` unless a flow step matches its `requires_flow_endpoint` (proven: 6 dead `edit.blade.php` stubs in the same run).

The artifact kinds + paths are read from the active framework pack — never hardcode a stack here. `mega-sdd:execute-bolts` is BLOCKED by `validate-flow-coverage.sh` (`.flow-coverage-state.json` status FAIL) until every input-accepting step maps to an artifact and no dead scaffold remains; this prose is the design rationale, the validator is the enforcement. (Defense-in-depth alongside `validate-flow-coverage.sh`.)

## Dependency-graph emission + cycle rejection (Step 4)

**Principle**: emit `depends_on` ONLY when there is concrete evidence of unit coupling. Conservative defaults previously over-emitted deps, forcing sequential execution where units could parallelize. Tighter rules maximize parallelism by default; user can add deps manually when implicit ordering matters.

**Emit `depends_on: U-X` ONLY IF** at least one is true:

a. **File overlap**: target unit modifies a file the dependent unit creates OR reads from
   - Source: `target_files` set comparison; if intersection non-empty AND ordering matters → emit dep
   - Example: U-002 modifies `app/Models/User.php`; U-001 creates that file → U-002 depends_on U-001
b. **Symbol cross-reference**: dependent unit's body Anchors cite a symbol planned by target unit
   - Source: parse `## Anchors` for symbol names; cross-reference target unit's `target_files` + planned outputs
c. **Migration Notes reference**: extend unit's Migration notes ADD/KEEP/REMOVE explicitly references a symbol another unit creates
d. **Vault dependency declaration**: vault section explicitly orders flows (e.g., `04-flows.md §F-U-002` says "after F-U-001 complete")
e. **Module-level blocked_by**: unit's module has explicit `blocked_by: [<other-module>]` AND other module has units that target same files
f. **SPLIT chain edge (Step 2.5 mandate)**: the verify/create pair emitted by a NEW+IMPLEMENTED SPLIT — the `create` half MUST depend_on the `verify` half so the existing implementation is certified BEFORE new code can perturb it. This edge is evidence class (f) by construction (same source claim-set), even though the pair's target_files are disjoint — without it the pair parallelizes and the verify assertions race the new code.

**DO NOT emit** `depends_on` for:
- Same vault section / same module — implicit ordering not guaranteed
- Conceptual sequencing without file overlap
- "Logical" precedence without target_files evidence

Effect: units default to parallel-eligible unless concrete coupling exists.

**Flag override**:
- `--strict-deps` (default ON) — apply above rules conservatively
- `--loose-deps` — pre-strict conservative deps (over-emit; sequential bias) for legacy parity
- `--no-deps` — emit zero `depends_on`; assume all parallel (USE WITH CAUTION; for testing)

Then:
- Build DAG from semantic deps (per above).
- **Reject cycles.** If detected, halt `cycle_detected` and instruct user to restructure vault sections.
- **Reject cross-squad direct deps in multi-squad mode.** After Step 5 (squad assignment) completes, walk every `depends_on` edge and verify both endpoints have the same `squad:`. If a `depends_on` edge crosses squads, halt `cross_squad_dep_invalid`.
- **Validate interface references.** For each unit with `consumes_interfaces` or `produces_interfaces`, verify each listed interface ID resolves to an existing `<vault>/interfaces/<id>.md` file. Dangling references halt `interface_ref_missing`.

## Module assignment (Step 4.5)

Semantic grouping layer ABOVE atomic units (units stay atomic; modules group related units per domain/flow/component). The modules-layer schema (auto-derivation, `modules.yaml` format, why modules ≠ bigger units) is in the modules-schema reference listed in the skill router.

- **Load `_meta/modules.yaml`** if present
- **Auto-derive** when absent: scan vault sections (`## F-U-*` flows, `## D-*` ADRs by domain cluster, named components in `02-architecture.md`); write `_meta/modules.yaml.auto` (note `.auto` suffix; user renames to lock in)
- **KB module-graph seed (legacy-rebuild vaults):** when `00-index.md` §Implementation Notes carries `kb_module_graph: <path>` (written by generate-intent's KB sub-mode), read that `module-dependency-graph.md` FIRST and seed the auto-derivation from its module list + dependency edges — the extraction already computed the grouping; don't re-derive it blind. KB edges are a SEED for `blocked_by` declarations, not evidence: every cross-module `depends_on` still requires the concrete-coupling evidence rule below. Absent/unreadable path → fall through to plain auto-derivation silently.
- **For each unit candidate**: match `vault_source` against `module.vault_sections` patterns; assign `unit.module = <module-id>`
- **Unassigned units** → `module: M-unassigned` (fallback); emit chat warning if ≥10% of units unassigned
- **Cross-module dependency validation**: every unit `depends_on` edge crossing module boundary requires explicit `blocked_by` declaration in the dependent module's modules.yaml entry. Cycle through Step 4 if module DAG has cycle (halt `module_cycle_detected`); missing `blocked_by` → halt `cross_module_dep_invalid`.

Backward compat: vaults without modules → all units get `module: M-default` (single implicit module); `_index.md` falls back to flat list.

## Squad assignment (Step 5)

Load `_meta/squads.yaml` if present.

**If file absent OR single squad declared:**
- Single-squad / no-squad mode active
- All units get `squad: default` (or field omitted)
- Skip all multi-squad validations

**If ≥2 squads declared:**
- Per `generate-intent/references/squad-partition.md` routing rules (cross-skill ref), assign `squad:` to each unit based on its `vault_source` and the relevant layer/feature tags.
- For each candidate unit:
  - Determine primary layer from its `vault_source` (e.g., a unit derived from `02-architecture.md#backend` → layer `backend`)
  - Match against squad ownership rules with precedence: `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`
  - Set `squad: <matched-id>`
- **Unrouted units**: emit warning (not halt) and assign `squad: default` so execution can proceed. User should refine `squads.yaml` and re-run.
- **Ambiguous routing** (two squads claim same artifact at same precedence level): halt `cross_squad_ambiguous`.

## ID allocation (Step 6)

Stable scheme:
- Sort candidates topologically
- Number U-001, U-002, ...
- On `--refresh`: re-number from scratch
- On default re-run: preserve IDs of unchanged units by content hash

## Render test for view-bearing units (Step 9 — code-delivery slice D)

If any `target_files` path matches the active framework pack `## Test patterns` → `detail_view_glob` (a detail/show view, e.g. `resources/views/**/show.blade.php`), the unit MUST ALSO carry a `type: render` acceptance_test built from the pack `detail_view_render` template (factory-create the model, GET the detail route, assert 200 + assert a real display field renders). A route-200 smoke test does NOT satisfy this — empty-model / null-field render crashes slip through. The deterministic `validate-unit-spec.sh` emits `render_test_missing` and the PreToolUse render-test gate (Branch 6) blocks `mega-sdd:execute-bolts` if it is absent; this prose is defense-in-depth. Packs that declare no `## Test patterns` → no render obligation (stack declared no detail-view convention).

## UI contract for view-bearing units (Step 9.b — code-delivery slice F)

A unit is **view-bearing** when any `target_files` path matches the active framework pack `## UI quality signatures` → `view_glob` (a renderable view; pack omits the section → no view convention → skip this step, no contract). For each view-bearing unit, attach a `## UI contract` section to the unit body so the bolt subagent renders a production-grade view, not raw scaffold. Every entry is GROUNDED in the vault (`04-flows.md` steps + states, `02-architecture` entities/fields, the design-system signals in `01-context`/`starterkit-context.yaml`) — **never invented**. If a needed source is absent (e.g. no design system for required colors/states), record it as an Open Question per `generate-intent/references/vault-contract.md`; do NOT default a value (anti-hallucination rail).

```yaml
## UI contract
label_map:                       # human label per displayed field — from 02-architecture field names + 01-context copy; NEVER a Str::title(column) like "Customer Id"
  customer_id: "Customer"
  created_at: "Created"
fk_display:                      # FK column => the related entity's display field, resolved via the relation (pack `## Relation derivation`); never render the raw id
  customer_id: "customer.name"
  branch_id: "branch.name"
value_formatting:                # money/number/date/status formatting — from field types in 02-architecture
  amount: "currency (2dp, thousands sep)"
  status: "human label + badge (map enum -> label from flow states)"
  created_at: "human date (null-safe placeholder)"
required_states:                 # the states this view MUST handle — DERIVED from the flow (04-flows.md), not boilerplate
  - empty       # list with zero rows (grounded: flow allows an empty collection)
  - loading     # async fetch/action present in the flow
  - error       # failure branch present in the flow (surface via the project notification idiom)
  - pending     # workflow item mid-process (maker-checker / multi-stage flow) -> show human status label
grounded_in: ["04-flows.md F-U-003 step 2", "02-architecture §Widget"]   # citations (anti-halu)
design_system_ref: "vault.design_system"   # present ONLY when the vault carries a design_system block (vault-contract.md §design_system); propagates the resolved style/palette/a11y (+ its source) to the bolt so the view renders on-system, not generic. Omit when absent.
```

- `required_states` is the load-bearing, flow-derived part: include only the states the flow actually produces (a read-only view with no async has no `loading`; a single-stage flow has no `pending`). The execute-bolts `ui_ux` slice injects the design tokens + a linter-clean view exemplar + `plugins/mega-sdd/references/ui-design-heuristics.md`, and `validate-dispatch-prompt.sh` asserts the emitted prompt carries them — this UI contract is the unit-spec-stage complement (what to render) to that execution-stage enrichment (how the project renders it).
- Provenance: mark `_grounded: true` only when every entry cites a vault source; otherwise emit the gap as an OQ. Do NOT fabricate labels, statuses, formatting rules, or states the vault does not establish.

## Adversarial test review pass (Step 9.5 — closes audit D4-006)

Closes audit Pattern F structural risk: acceptance_test authored by the SAME LLM pass as the unit body inherits the same blind spots. Per ACM FSE 2025: "Never trust AI to both generate and validate."

For each unit just authored in Step 9, run the adversarial review using the prompt template in the adversarial-test-prompt reference (listed in the skill router):

**Default mode (main-thread self-re-prompt):**

1. Re-prompt with the template's Default-mode framing. Same LLM, different role context = QA engineer reviewing the unit's test for blind spots.
2. Adversarial pass returns YAML `adversarial_review:` block with `gaps_identified[]` + `coverage_verdict`.
3. Merge per the template's gap-merge logic:
   - `coverage_verdict: strong` AND no gaps → mark `_authored_by: adversarial-reviewed (no gaps)`
   - Non-empty gaps → append `proposed_additional_assertion` to acceptance_test; mark `_authored_by: adversarial-reviewed (+N gaps merged)`
   - `coverage_verdict: weak` AND no gaps (incoherent) → keep original; mark `_authored_by: adversarial-review-failed (kept original; manual review recommended)`. Log warning.

**Opt-in subagent mode (`--adversarial-subagent` flag OR unit `risk: high`):**

Dispatch a separate subagent for the adversarial review using the template's opt-in subagent mode. Separate LLM context = stronger blind-spot coverage at cost of one extra dispatch per unit. Marked `_authored_by: independent-llm`.

**Skip mode (`--no-adversarial-review` flag):**

Preserves pre-review behavior. Sets `_authored_by: same-pass`. Use for debug / regression testing only — NOT recommended for production unit generation.

**Regenerate behavior:**

When `generate-units --regenerate` re-encounters a unit:
- If existing unit has `_authored_by: human` → PRESERVE acceptance_test untouched (user-edited; do not overwrite)
- Otherwise → rewrite per Step 9 + run Step 9.5 adversarial review

**Provenance written to unit frontmatter:**

```yaml
acceptance_test:
  _authored_by: adversarial-reviewed (+2 gaps merged)   # provenance
  - type: test
    command: "..."
    expects: ""            # literal output substring, or EMPTY (exit-0 criterion) — never a description
  - type: test             # gap 1 merged from adversarial pass
    command: "..."
    expects: ""
  - type: test             # gap 2 merged from adversarial pass
    command: "..."
    expects: ""
```
