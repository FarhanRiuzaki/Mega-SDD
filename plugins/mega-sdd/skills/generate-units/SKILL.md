---
name: generate-units
version: 2.7.1
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
- Flags:
  - `--refresh` (re-number IDs from scratch)
  - `--max-complexity=small|medium` (split anything bigger)
  - `--auto`
  - `--adversarial-subagent` (v2.7.0+, Iter 47) — for Step 9.5 adversarial test review, dispatch a SEPARATE subagent per unit instead of main-thread self-re-prompt. Stronger blind-spot coverage at cost of one extra dispatch per unit. Auto-set for any unit with frontmatter `risk: high`.
  - `--no-adversarial-review` (v2.7.0+, Iter 47) — SKIP Step 9.5 adversarial test review entirely. Sets every generated unit's `acceptance_test._authored_by: same-pass`. **DISCOURAGED** — preserves pre-Iter-47 D4-006 blind-spot risk. Use for debug / regression testing only.
  - `--regenerate` (v2.7.0+, Iter 47) — rewrite existing unit files. PRESERVES units with `acceptance_test._authored_by: human` (user-edited; do not overwrite). Other units rewritten per Step 9 + 9.5.

## Output

`<vault>/units/U-001.md`, `U-002.md`, ... per `references/unit-schema.md`. Also writes `<vault>/units/_index.md` with dependency graph.

## Procedure

0.5. **Defensive pre-flight check (v2.1+, Iter 8).**

   Per `references/defensive-generation.md` §Step 0.5. Probe upstream artifacts before vault parsing:

   - `codebase-map.md` presence (current dir / repo root / vault parent)
   - `binding.md` presence (vault-bound/ or vault parent)
   - vault.json `implementation_mode` (greenfield | existing)

   Decision matrix:
   - Both present → ✅ proceed (HIGH grounding confidence)
   - Both absent + greenfield → ✅ proceed (MEDIUM confidence — expected)
   - Both absent + existing → ⚠️ INTERACTIVE prompt: (1) auto-run scan-codebase + bind-codebase (recommended) (2) proceed with LOW confidence (3) cancel
   - codebase-map present, binding absent + existing → ⚠️ INTERACTIVE prompt: (1) run bind-codebase first (recommended) (2) proceed with MEDIUM confidence (3) cancel
   - codebase-map absent, binding present → warn (stale binding); proceed MEDIUM

   On "auto-run upstream": invoke scan-codebase / bind-codebase (per orchestrate-flow auto-route pattern); return to Step 1 after they complete (halts in upstream skills propagate normally).

   `--no-defensive` flag skips this step entirely (back to v2.0 behavior). `--auto` flag in chain mode defaults to safest option (auto-run upstream).

1. **Load vault.** Read 7 files + vault.json. If bound-vault path provided, also read binding.md.

2. **Identify unit candidates.** Walk vault sections (02-architecture, 04-flows, 03-data-model). Each implementable artifact (a component, endpoint, schema migration, etc.) becomes a candidate unit.

2.5. **Determine task_type per candidate (v1.2+, Iter 1).**

   If bound-vault has `binding.md` with Implementation State Map (v1.2+), assign `task_type` per the table below. If no Implementation State Map (greenfield OR pre-v1.2 binding) → every candidate is `create`.

   For each candidate unit, find the binding claims it derives from (via vault claim → binding C-XXX mapping). Aggregate their states:

   | Bound claim states (v1.7+ set: IMPLEMENTED / PARTIAL_FIELDS_MISSING / PARTIAL_FIELDS_SURPLUS / NEW / UNKNOWN) | Unit task_type |
   |---|---|
   | All NEW, or no binding | `create` |
   | All IMPLEMENTED with `confidence: high` | `verify` |
   | **PARTIAL_FIELDS_MISSING** (v2.1+, Iter 8) — code missing fields from claim | `extend` with Migration notes auto-populated from binding's `field_diff`: ADD/KEEP/REMOVE lists |
   | **PARTIAL_FIELDS_SURPLUS** (v2.1+, Iter 8) — code has fields not in claim | `extend` with HUMAN REVIEW interactive prompt (could be feature drift, vault gap, legacy deprecation, or rename) |
   | **PARTIAL_FIELDS_BOTH** (v2.1+, Iter 8) — both directions diff | strong warning; surface interactive prompt; usually signals semantic mismatch needing vault update OR code triage |
   | Mix of NEW + IMPLEMENTED | SPLIT — emit one `create` unit for NEW claims, one `verify` unit for IMPLEMENTED claims; chain via `depends_on` so verify runs first |
   | Any UNKNOWN (regardless of confidence) | `create` (conservative default per DESIGN-OQ-1) — surface a note in unit body: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed." |
   | Mix of CONFIRMED + CONFLICT | Halt — binding gate should have blocked already; report inconsistency |

   `verify` unit specifics (enforced by `references/unit-schema.md` §Per-task_type contracts):
   - `target_files` is empty OR all entries `operation: none`
   - `acceptance_test` carries assertions that prove existing implementation still works
   - Body's `## Implementation steps` is ONE line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
   - Body's `## Anchors` section is MANDATORY — cite the file:line where the implementation lives (from binding's `anchor` field)
   - Estimated complexity: small

   `extend` was forward-compat-only in Iter 1 (deferred PARTIAL state). **Iter 8 (v2.1+) activates auto-emission** for `PARTIAL_FIELDS_*` states with Migration notes populated from binding's `field_diff` column. UNKNOWN states still default to `create` (conservative — no field-diff signal available).

   **Migration notes auto-population from binding field_diff (Iter 8):**

   When binding state is PARTIAL_FIELDS_MISSING:
   - **ADD** sub-list = `field_diff.ADD` from binding (missing fields to add)
   - **KEEP** sub-list = `field_diff.KEEP` (shared fields; bolt MUST NOT modify their behavior)
   - **REMOVE** sub-list = (empty)

   When binding state is PARTIAL_FIELDS_SURPLUS:
   - **ADD** sub-list = (empty)
   - **KEEP** sub-list = `field_diff.KEEP`
   - **REMOVE** sub-list = `field_diff.REMOVE` with CAUTION note
   - INTERACTIVE prompt fires: user decides if surplus is feature drift / vault gap / legacy / rename

   When binding state is PARTIAL_FIELDS_BOTH:
   - Both lists populated; HUMAN REVIEW mandatory before bolt
   - Strong warning in unit body

3. **Group + atomize.** For each candidate:
   - If estimated change < 300 LOC and touches ≤ 5 files → single unit
   - If larger → split into N units with explicit `depends_on` chain
   - If a unit needs an OQ resolved → mark in body as "TBD: <OQ-ID>" + add to acceptance criteria

4. **Resolve dependency graph (v2.3+ Iter 12 — stricter `depends_on` emission).**

   **Principle**: emit `depends_on` ONLY when there is concrete evidence of unit coupling. Conservative defaults previously over-emitted deps, forcing sequential execution where units could parallelize. Tighter rules maximize parallelism by default; user can add deps manually when implicit ordering matters.

   **Emit `depends_on: U-X` ONLY IF** at least one is true:

   a. **File overlap**: target unit modifies a file the dependent unit creates OR reads from
      - Source: `target_files` set comparison; if intersection non-empty AND ordering matters → emit dep
      - Example: U-002 modifies `app/Models/User.php`; U-001 creates that file → U-002 depends_on U-001
   b. **Symbol cross-reference**: dependent unit's body Anchors cite a symbol planned by target unit
      - Source: parse `## Anchors` for symbol names; cross-reference target unit's `target_files` + planned outputs
   c. **Migration Notes reference**: extend unit's Migration notes ADD/KEEP/REMOVE explicitly references a symbol another unit creates
   d. **Vault dependency declaration**: vault section explicitly orders flows (e.g., `04-flows.md §F-U-002` says "after F-U-001 complete")
   e. **Module-level blocked_by** (Iter 11): unit's module has explicit `blocked_by: [<other-module>]` AND other module has units that target same files

   **DO NOT emit** `depends_on` for:
   - Same vault section / same module — implicit ordering not guaranteed
   - Conceptual sequencing without file overlap
   - "Logical" precedence without target_files evidence

   Effect: units default to parallel-eligible unless concrete coupling exists.

   **Flag override**:
   - `--strict-deps` (default ON in v2.3+) — apply above rules conservatively
   - `--loose-deps` — pre-v2.3 conservative deps (over-emit; sequential bias) for legacy parity
   - `--no-deps` — emit zero `depends_on`; assume all parallel (USE WITH CAUTION; for testing)

   - Build DAG from semantic deps (per above)
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

4.5. **Module assignment (v2.2+, Iter 11).**

   Per `references/modules-schema.md`. Semantic grouping layer ABOVE atomic units (units stay atomic; modules group related units per domain/flow/component).

   - **Load `_meta/modules.yaml`** if present
   - **Auto-derive** when absent: scan vault sections (`## F-U-*` flows, `## D-*` ADRs by domain cluster, named components in `02-architecture.md`); write `_meta/modules.yaml.auto` (note `.auto` suffix; user renames to lock in)
   - **For each unit candidate**: match `vault_source` against `module.vault_sections` patterns; assign `unit.module = <module-id>`
   - **Unassigned units** → `module: M-unassigned` (fallback); emit chat warning if ≥10% of units unassigned
   - **Cross-module dependency validation**: every unit `depends_on` edge crossing module boundary requires explicit `blocked_by` declaration in the dependent module's modules.yaml entry. Cycle through Step 4 if module DAG has cycle.

   Backward compat: v3.4 vaults without modules → all units get `module: M-default` (single implicit module); `_index.md` falls back to flat list.

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

7.5. **PageRank target_files suggestions (v2.0+, Iter 6).**

   When `codebase-map.md` frontmatter has `precision_tier: ast` (tree-sitter scan, Iter 6 Swap #1):

   - Build/load symbol-reference graph per `references/pagerank-targeting.md` §Algorithm
   - For each unit, compute personalized PageRank with seed = current `target_files` + binding citations
   - Surface top-K (default K=5) non-seed file suggestions in unit body's `## PageRank suggestions` section
   - User reviews + manually promotes to `target_files` frontmatter (NEVER silent rewrite per anti-halu)

   Skipped when `precision_tier: regex` or `--skip-pagerank` flag set. Falls back to v1.5 behavior (binding-only target_files).

   Symbol graph cached at `<vault>/.internal/symbol-graph.json` (v3.4+ canonical per paths.md) per scan-codebase run; reused across all units.

7.6. **Per-unit target_files collision check (v2.1+, Iter 8).**

   Per `references/defensive-generation.md` §Step 7.6. Before writing each unit:

   For EACH `target_files` entry where `operation: create`:
   1. Probe path existence (fs check OR codebase-map §1)
   2. If file does NOT exist → proceed normally (true create)
   3. If file EXISTS:
      - If binding has IMPLEMENTED state for related claim → INTERACTIVE prompt:
        ```
        "Target `<path>` already exists. Binding state: IMPLEMENTED.
         Options for unit U-XXX:
           1. Convert to `verify` (no code change) (recommended)
           2. Convert to `extend` (modify; fill Migration notes)
           3. Rename target file
           4. Force `create` (overwrite — DANGEROUS)
           5. Skip this unit"
        ```
      - If binding state PARTIAL_FIELDS_* or NEW or UNKNOWN → INTERACTIVE prompt with `extend` as recommended default

   **Prompt frequency control**:
   - Prompts fire ONLY on genuine collision (file exists + task_type=create)
   - Same-session memory: previous picks default future similar collisions
   - `--auto` flag suppresses interactive — picks safest default (`extend`)
   - `--collision-policy=<extend|verify|skip|prompt>` flag overrides for batch behavior

7.7. **Load starterkit-context.yaml + derive starterkit-specific Anchors and Hard Rules per unit (v2.6.0+, Iter 32).**

   Runs AFTER Step 7.6 (target_files finalized) and BEFORE Step 8 (existing_interfaces). Starterkit relevance computation depends on `unit.target_files` being fully populated.

   ### Step 7.7.a — Resolve starterkit-context.yaml

   ```
   Path: <project>/.mega-sdd/codebase/starterkit-context.yaml

   IF file absent:
     → log "starterkit-context unavailable; emit framework-pack-only Anchors"
     → set every unit's frontmatter `starterkit_context_consumed: false`
     → SKIP Steps 7.7.b - 7.7.e
   IF file present:
     → parse YAML
     → IF parse fails: log warning; treat as absent; proceed as above
     → IF starterkit_context.partial == true: note which slices are missing (partial_slices: [...])
     → proceed to Step 7.7.b
   ```

   ### Step 7.7.b — Compute starterkit relevance per unit

   For each unit being generated, inspect `unit.target_files` (finalized by Steps 7, 7.5, 7.6) and unit body content. Determine which starterkit slices apply:

   ```
   starterkit_relevance = []

   IF any target_file matches:
     resources/views/**, resources/js/**, resources/css/**, public/css/**, public/js/**
   THEN starterkit_relevance += ["ui_ux"]
      (skip if starterkit_context.ui_ux missing OR ui_ux in partial_slices)

   IF any target_file matches app/Http/Controllers/**
   AND unit body mentions any of: "auth", "login", "register", "logout", "password", "session"
   THEN starterkit_relevance += ["auth"]
      (skip if auth missing)

   IF any target_file matches app/Http/Middleware/** OR app/Policies/**
   OR unit body mentions any of: "role", "permission", "gate", "policy", "Spatie\\Permission"
   THEN starterkit_relevance += ["rbac"]
      (skip if rbac missing)

   IF any target_file path appears in any libs[].usage_hint[]
   THEN starterkit_relevance += ["libs"]
      (skip if libs missing)
   ```

   Empty `starterkit_relevance: []` is a valid result for units that don't intersect any starterkit slice. In that case, skip Steps 7.7.c + 7.7.d for that unit.

   ### Step 7.7.c — Derive starterkit Anchors per unit

   For each unit with `starterkit_relevance` non-empty, append starterkit-specific anchors to `unit.anchors[]` (same structure as KB/binding anchors from Step 12.3 per-anchor verification):

   ```
   IF "ui_ux" in starterkit_relevance:
     add anchor: <starterkit_context.ui_ux.layout_file>   (e.g., resources/views/layouts/app.blade.php)
     IF starterkit_context.ui_ux.component_dir exists:
       add anchor: <starterkit_context.ui_ux.component_dir>   (e.g., resources/views/components/)

   IF "auth" in starterkit_relevance:
     add anchor: <file path of starterkit_context.auth.user_model class>   (e.g., app/Models/User.php)
     IF starterkit_context.auth.routes.login != "":
       add anchor: routes/auth.php (or routes/web.php if auth.php absent)

   IF "rbac" in starterkit_relevance:
     IF starterkit_context.rbac.middleware contains entries:
       add anchor: app/Http/Middleware/<middleware-class>.php for each middleware alias
     add anchor: app/Providers/AuthServiceProvider.php

   IF "libs" in starterkit_relevance:
     for each lib in starterkit_context.libs whose usage_hint overlaps unit.target_files:
       add the lib's usage_hint[0] file as an anchor (first hint file)
   ```

   Anchors append to `unit.anchors[]` alongside KB/binding anchors from prior steps. Deduplicate paths if a file is anchored multiple times.

   ### Step 7.7.d — Derive starterkit Hard Rules per unit (with mandatory citation)

   For each unit with `starterkit_relevance` non-empty, append starterkit-specific Hard Rules to `unit.hard_rules[]`. Follows the same shape as framework pack rules from Step 12.4.5 — EVERY rule MUST include an explicit `citation:` field referencing `starterkit-context.yaml §<path>`.

   **Template format for each rule:**

   ```
   - text: "<rule text>"
     citation: "starterkit-context.yaml §<path>"
     source: starterkit-context.yaml
   ```

   **UI/UX-relevant unit examples (when "ui_ux" in starterkit_relevance):**

   ```
   - text: "MUST extend `<starterkit_context.ui_ux.layout_extends>` (e.g., layouts.app) in all Blade views generated by this unit"
     citation: "starterkit-context.yaml §ui_ux.layout_extends"

   - IF starterkit_context.ui_ux.notification_lib == "sweetalert2":
       - text: "MUST use SweetAlert2 for confirmations and notifications (NEVER native alert() or window.confirm())"
         citation: "starterkit-context.yaml §ui_ux.notification_lib"

   - FOR EACH idiom in starterkit_context.ui_ux.idioms:
       - text: "MUST follow starterkit idiom: <idiom>"
         citation: "starterkit-context.yaml §ui_ux.idioms"

     (Examples — emitted only if idiom is empirically present per ui-ux-extractor):
     - "use document.addEventListener('DOMContentLoaded', ...) over $(document).ready"
     - "responsive mobile-first (sm/md/lg breakpoints)"
   ```

   **Auth-relevant unit examples (when "auth" in starterkit_relevance):**

   ```
   - text: "MUST use auth guard '<starterkit_context.auth.guard>' (e.g., sanctum or web)"
     citation: "starterkit-context.yaml §auth.guard"

   - text: "MUST reference User model `<starterkit_context.auth.user_model>` not generic Auth::user()::class"
     citation: "starterkit-context.yaml §auth.user_model"

   - IF "2fa" in starterkit_context.auth.features:
       - text: "Two-factor authentication is enabled in this starterkit; auth flows MUST respect 2fa challenge state"
         citation: "starterkit-context.yaml §auth.features"
   ```

   **RBAC-relevant unit examples (when "rbac" in starterkit_relevance):**

   ```
   - IF starterkit_context.rbac.lib == "spatie/permission":
       - text: "MUST use Spatie/permission middleware: route()->middleware('role:<role>') OR middleware('permission:<perm>')"
         citation: "starterkit-context.yaml §rbac.middleware"

       - text: "MUST reference Spatie\\Permission\\Models\\Role for role queries (NOT custom Role models)"
         citation: "starterkit-context.yaml §rbac.role_model"
   ```

   **Libs-relevant unit examples (when "libs" in starterkit_relevance):**

   ```
   FOR EACH lib in starterkit_context.libs whose usage_hint overlaps unit.target_files:
     - text: "MUST use existing starterkit library `<lib.name>` v<lib.version> for <lib.category> functionality, NOT a competing alternative"
       citation: "starterkit-context.yaml §libs (name: <lib.name>)"
   ```

   ### Step 7.7.e — Update unit frontmatter

   For each unit (even those with empty starterkit_relevance):

   ```yaml
   ---
   unit_id: U-001
   # ... existing frontmatter ...
   starterkit_context_consumed: <true | false>     # NEW v2.6.0+, Iter 32
   starterkit_relevance: [<list of applicable slices>]   # NEW v2.6.0+, Iter 32; may be empty list
   ---
   ```

   Also append `starterkit-context.yaml` as a citation source in the unit's §Citations footer section (only if starterkit_context_consumed: true).

8. **Fill `existing_interfaces`.**
   - Brownfield only: pull from binding manifest CONFIRMED entries for the targeted files
   - Greenfield: empty (no existing interfaces)

9. **Fill `acceptance_test`.**
   - At least one `type: test` entry (mandatory)
   - Generate test command stub matching detected test framework from codebase-map (greenfield: pick sensible default)
   - Add `type: manual` for user-visible flows
   - Per Iter 47 (v2.7.0+): this is the FIRST PASS — adversarial review runs in Step 9.5 below

9.5. **Adversarial test review pass (v2.7.0+, Iter 47 — closes audit D4-006)**

Closes Iter 38 audit Pattern F structural risk: acceptance_test authored by the SAME LLM pass as the unit body inherits the same blind spots. Per ACM FSE 2025: "Never trust AI to both generate and validate."

For each unit just authored in Step 9, run the adversarial review per `references/adversarial-test-prompt.md`:

**Default mode (main-thread self-re-prompt):**

1. Re-prompt with adversarial framing (see `references/adversarial-test-prompt.md` §Default mode). Same LLM, different role context = QA engineer reviewing the unit's test for blind spots.
2. Adversarial pass returns YAML `adversarial_review:` block with `gaps_identified[]` + `coverage_verdict`.
3. Merge per `references/adversarial-test-prompt.md §Gap merge logic`:
   - `coverage_verdict: strong` AND no gaps → mark `_authored_by: adversarial-reviewed (no gaps)`
   - Non-empty gaps → append `proposed_additional_assertion` to acceptance_test; mark `_authored_by: adversarial-reviewed (+N gaps merged)`
   - `coverage_verdict: weak` AND no gaps (incoherent) → keep original; mark `_authored_by: adversarial-review-failed (kept original; manual review recommended)`. Log warning.

**Opt-in subagent mode (`--adversarial-subagent` flag OR unit `risk: high`):**

Dispatch a separate subagent for the adversarial review per `references/adversarial-test-prompt.md §Opt-in subagent mode`. Separate LLM context = stronger blind-spot coverage at cost of one extra dispatch per unit. Marked `_authored_by: independent-llm`.

**Skip mode (`--no-adversarial-review` flag):**

Preserves pre-Iter-47 behavior. Sets `_authored_by: same-pass`. Use for debug / regression testing only — NOT recommended for production unit generation.

**Regenerate behavior:**

When `generate-units --regenerate` re-encounters a unit:
- If existing unit has `_authored_by: human` → PRESERVE acceptance_test untouched (user-edited; do not overwrite)
- Otherwise → rewrite per Step 9 + run Step 9.5 adversarial review

**Provenance written to unit frontmatter:**

```yaml
acceptance_test:
  _authored_by: adversarial-reviewed (+2 gaps merged)   # provenance per Iter 47
  - type: test
    description: "..."
    command: "..."
  - type: test
    description: "<gap 1 merged from adversarial pass>"
    command: "..."
  - type: test
    description: "<gap 2 merged from adversarial pass>"
    command: "..."
```

10. **Write each unit file** using `references/templates/unit.md` as the body template.

**v2.5.4+ Iter 29 scope propagation (P1-3 audit fix)**: When vault.json contains a `scope` field (v1.12+ multi-scope vault per Iter 28), every unit's frontmatter MUST include:

```yaml
scope: <vault.scope_metadata.id>           # e.g., "BE", "MW", "FE"
scope_name: <vault.scope_metadata.name>    # e.g., "Backend API"
```

This enables downstream skills (execute-bolts, multi-squad routing) to verify they're operating in the correct scope context. Omit both fields when vault has no scope (legacy single-vault back-compat).

11. **Write `_index.md`** with:
    - Total unit count + **module count (v2.2+)**
    - **Grouped by module** (v2.2+) — per module section: name, status (X/Y complete), priority, DoD checklist, units table (ID, title, task_type, depends_on, status); `M-unassigned` group rendered if non-empty with warning
    - Per-module dependency DAG (Mermaid graph) — units within module
    - Cross-module dependency graph — high-level
    - Suggested execution order (topological within + across modules)
    - Backward compat: when only `M-default` exists → fall back to flat unit list (v3.4 behavior)

12. **Post-write validation + audit (the 12.x sub-procedures below run in declared order, then step 13 logs).**

12.3. **Per-anchor verification (v2.1+, Iter 8 — renumbered v2.5.1 Iter 25; runs FIRST as precondition check before constitution inject + render).**

   Per `references/defensive-generation.md` §Step 12.4.5. For each Anchor entry in each unit's `## Anchors` section:

   1. Parse `<file>:<line-range> — <description>` format
   2. Probe file existence (fs OR codebase-map §1)
   3. Apply outcome:
      - **File MISSING + greenfield unit** → WARNING in unit body footer (HTML comment): "anchor aspirational for new file; verify before bolt"
      - **File MISSING + brownfield unit** → stronger WARNING: "anchor points to non-existent file; binding may be incomplete; review"
      - **File EXISTS, line out of bounds** → WARNING: "anchor line-range may have drifted; current file has N lines"
      - **File EXISTS, line valid** → ✓ verified

   Anchor warnings are SOFT — they do NOT halt generation. Anchors can be aspirational (especially for new files in `create` units). Warnings surface visually in chat output + unit body footer so user can review.

12.4. **Inject constitution clauses (v2.4+, Iter 17 — renumbered v2.5.1 Iter 25).**

   Per `generate-intent/references/vault-contract.md` §constitution.

   For each unit, read `<vault>/constitution.md` + identify clauses relevant to the unit's:
   - target_files paths (matches §A clauses for files in those paths)
   - task_type (different clauses apply for create vs extend vs verify)
   - module (per `_meta/modules.yaml` if multi-module)
   - vault_source (clauses referenced in that vault section)

   Inject relevant clauses into the unit's `## Hard rules` section:

   ```yaml
   id: constitution-A-001
   language: <unit's primary language>
   message: "All API endpoints MUST use Sanctum auth middleware (constitution §A-001)"
   rule:
     pattern: |
       Route::$$$('/api/$$$', $$$)
     not:
       inside:
         pattern: |
           ->middleware(['auth:sanctum', $$$])
   ```

   Format:
   - Rule `id` prefix `constitution-` + clause ID
   - `message` cites clause source
   - Pattern detection: convert clause text to ast-grep YAML when feasible; fall back to text-match grep when not
   - Severity: `error` (constitution clauses are non-negotiable; halts bolt commit if violated)

   **Anti-halu rails**:
   - Constitution clauses NEVER silently apply — surface in unit body for user review
   - Clauses that can't translate to ast-grep grammar are flagged in unit body as `## Constitution warnings` informational section (not Hard Rule)
   - Anti-pattern (§D) clauses always inject as Anti-patterns (informational), not Hard Rules (machine-validated), unless mechanically detectable per Iter 6 DESIGN-OQ-6
   - Constitution version + hash tracked: if constitution drifts between unit generation and bolt execution → halt `constitution_drift_detected`

12.4.5. **Framework pack provenance citation (v2.5.1+, Iter 25 — propagates Iter 23 framework pack into unit body).**

   When `binding.md` §Suggested Unit Hard Rules contains rules sourced from framework pack (introduced by bind-codebase Step 2.8), emit each pack-derived Hard Rule into the unit's `## Hard rules` section WITH explicit provenance citation. Tools consuming the unit must see WHICH framework pack rule applies (audit trail, debugging, override decisions).

   Format inside unit's `## Hard rules` section:

   ```yaml
   - id: framework-pack-naming-001
     source: "framework-conventions/laravel-base-26.md §Hard Rules — UUID PK enforcement"
     framework: laravel-base-26
     framework_pack_version: 1.0  # framework_version_range when last_verified_against passed
     message: "Domain entity migrations MUST use UUID primary key per starterkit convention"
     severity: error
     rule:
       pattern: |
         $table->id()
       inside:
         pattern: |
           Schema::create($_, function (Blueprint $table) { $$$ })
   ```

   Aggregate in unit body:

   ```markdown
   ## Framework pack source

   Conventions enforced from: `plugins/mega-sdd/references/framework-conventions/laravel-base-26.md` (v1.0, extends `laravel.md` extends `_universal.md`)
   Rules pulled into this unit's Hard Rules: N (see §Hard rules for line-level enforcement)
   ```

   **Anti-halu rails**:
   - Framework pack rules NEVER silently apply — citation mandatory so user can audit + override
   - Rules whose `path_glob` doesn't match this unit's `target_files` are SKIPPED (not all pack rules apply to every unit)
   - When pack `extends:` chain → cite the SPECIFIC pack file the rule lives in (not the chain head), so override edits are traceable

12.5. **Polished-prompt render pass (v1.3+, Iter 3 — renumbered v2.5.1 Iter 25).**

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

   f. **Starterkit citation check (v2.6.0+, Iter 32)**:

      ```
      IF unit.frontmatter.starterkit_context_consumed == true:
        FOR EACH hard_rule in unit.hard_rules:
          IF hard_rule.source == "starterkit-context.yaml" AND hard_rule.citation field is missing or empty:
            → HALT `starterkit_rule_citation_missing`
            → emit blocker YAML:
                type: starterkit_rule_citation_missing
                source_skill: generate-units
                details:
                  unit_id: <U-XXX>
                  rule_text: "<text of offending rule>"
                  missing_citation: "starterkit-context.yaml §<expected path>"
                  rule_index: <index of rule in hard_rules[]>
                next_action:
                  type: edit_unit
                  suggested_args: ["<U-XXX>"]
                  hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #<index>"
            → do NOT write the unit; halt is ALWAYS STOP
      ```

      This rail enforces that every starterkit-derived Hard Rule includes its citation — mirrors existing "every Hard Rule needs a Citation" rail (Step 12.4.5) extended to starterkit-derived rules.

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

12.6. **Deduplication check (v1.2+, Iter 1 — renumbered v2.5.1 Iter 25).**

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

13. **Audit log.** Append to `vault.json`: `{ "event": "units_generated", "at": "...", "count": N }`. Runs last so the event reflects all post-write validation outcomes.

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
- (v2.0+, Iter 6) PageRank symbol-graph suggestions surface as informational `## PageRank suggestions` body section; NEVER auto-added to target_files. User must manually promote.
- (v2.0+, Iter 6) Symbol graph requires `precision_tier: ast` in codebase-map; skipped gracefully on regex tier.
- (v2.1+, Iter 8) Defensive pre-flight auto-detects missing upstream artifacts; offers auto-route (no death-by-prompts in clean chains).
- (v2.1+, Iter 8) Per-unit target_files collision triggers INTERACTIVE prompt ONLY when file exists + task_type=create (otherwise silent). Prompts cap-limited by `--collision-policy` batch flag.
- (v2.1+, Iter 8) `PARTIAL_FIELDS_*` states from bind-codebase v1.7+ auto-populate Migration notes from binding's `field_diff` — bolt knows EXACTLY which fields to add/keep/remove.
- (v2.1+, Iter 8) `grounding_confidence: HIGH | MEDIUM | LOW` field in unit frontmatter reflects upstream + anchor + collision verification.
- (v2.1+, Iter 8) Anchor warnings are SOFT — visible in chat + body footer but do NOT halt. Anchors can be aspirational for new files in `create` units.
- (v2.2+, Iter 11) Module assignment is derived from `vault_source` matching against `_meta/modules.yaml`. Unmatched units → `M-unassigned` (warning); never silently grouped.
- (v2.2+, Iter 11) Cross-module dependencies require explicit `blocked_by` declaration in modules.yaml; violation → halt `cross_module_dep_invalid`.
- (v2.2+, Iter 11) Module DAG validated for cycles same as unit DAG. `module_cycle_detected` halt if cycle found.
- (v2.3+, Iter 12) `depends_on` emission STRICT by default — only emitted with concrete evidence (file overlap, symbol cross-ref, Migration notes ref, vault declaration, module blocked_by). Maximizes parallelism eligibility; user explicitly adds deps when implicit ordering matters.
- (v2.3+, Iter 12) `--strict-deps` (default) | `--loose-deps` (legacy bias) | `--no-deps` (assume all parallel; testing only) flags available.
- (v2.6.0+, Iter 32) `starterkit_context:` YAML file consumed read-only in Step 7.7; NEVER modified by generate-units. starterkit_context_consumed frontmatter flag set based on file presence only — never inferred.
- (v2.6.0+, Iter 32) Starterkit-derived Hard Rules MUST cite `starterkit-context.yaml §<path>` explicitly. Citation is machine-checked in Step 12.5.f. Missing citation → halt `starterkit_rule_citation_missing` (ALWAYS STOP — not a soft warning).
- (v2.6.0+, Iter 32) Starterkit relevance computed from `unit.target_files` paths + unit body text only. NEVER fabricate relevance for domains not matched by the rules in Step 7.7.b.
- (v2.6.0+, Iter 32) When `starterkit_context.partial == true`, skip Anchors + Hard Rules for slices listed in `partial_slices:`. Degrade to framework-pack-only for missing slices; do NOT guess absent slice content.

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
- (v2.6.0+, Iter 32) Starterkit-derived Hard Rule missing mandatory Citation field → halt `starterkit_rule_citation_missing` — ALWAYS STOP

### `starterkit_rule_citation_missing` (v2.6.0+, Iter 32) — ALWAYS STOP

Emitted by Step 12.5.f polished-prompt render pass when a unit's starterkit-derived Hard Rule lacks the mandatory `Citation: starterkit-context.yaml §<path>` field.

```yaml
type: starterkit_rule_citation_missing
source_skill: generate-units
details:
  unit_id: <U-XXX>
  rule_text: "<text of offending rule>"
  missing_citation: "starterkit-context.yaml §<expected path>"
  rule_index: <int>
next_action:
  type: edit_unit
  suggested_args: ["<U-XXX>"]
  hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #<index>"
```

Recovery: user edits unit to add citation; re-runs Step 12.5 polished-prompt render pass.

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
  blockers: []   # populated on cycle/cross-squad/dedup/unit_underspecified/hard_rule_unparseable/starterkit_rule_citation_missing
  metrics:
    items_processed: <N units>
    items_blocked: 0
    units_with_starterkit_anchors: <int>       # NEW v2.6.0+, Iter 32 (count of units that gained starterkit Anchors)
    units_with_starterkit_rules: <int>         # NEW v2.6.0+, Iter 32 (count of units that gained starterkit Hard Rules)
  scope:                                       # v2.5.4+ Iter 29 (P1-3) — omit block when vault has no scope field
    id: <vault.scope_metadata.id>
    name: <vault.scope_metadata.name>
    sibling_scopes: <vault.scope_metadata.sibling_scopes_in_prd>
    prd_sha256: <vault.prd_sha256>
  starterkit_context:                          # NEW v2.6.0+, Iter 32 — passthrough from scan-codebase + generate-units metrics; omit block when starterkit-context.yaml absent
    reused: false
    framework: laravel
    auth_lib: sanctum
    rbac_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    units_with_starterkit_anchors: 12          # NEW metric (mirrors metrics block above)
    units_with_starterkit_rules: 8             # NEW metric (mirrors metrics block above)
    # Consumer (v2.7.1+, Iter 53 wiring closure): orchestrate-flow Step 6.b.ix cross-checks
    # units_with_starterkit_rules > 0 against starterkit-context.yaml `starterkit_context.partial:` flag.
    # If rules > 0 AND partial == true → halt `quality_gate_failed` subtype `starterkit_metrics_inconsistent`
    # (rules pulled from incomplete framework slice — may cite missing conventions). Pre-Iter-53 these
    # metrics were producer-only emission with no downstream consumer.
```

Status `halted` on `cycle_detected` / `cross_squad_dep_invalid` / `interface_ref_missing` / `cross_squad_ambiguous` / `dedup_ambiguous` / `unit_underspecified` / `hard_rule_unparseable` / `starterkit_rule_citation_missing`. Required ONLY under `--auto`.

**v2.5.4+ Iter 29 (P1-3)**: `scope:` block is included in handoff YAML when vault.json has `scope` field, per `orchestrate-flow/references/handoff-contract.md` v3.20+ contract (line 44). Omit the entire `scope:` block when vault is legacy single-scope.

## Memory layer (v1.5+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Reads

| What | Source | How used |
|---|---|---|
| Past Hard Rule violations on similar units | `<vault>/.memory/bolt-outcomes.json` (passed via handoff `metadata.memory_context.vault_outcomes_relevant`) | When generating a unit with Hard Rules pulled from binding suggestions: if rule was violated AND reverted ≥3 times → DOWNGRADE the rule to Anti-pattern (informational) per learning-rules.md §2.3 |
| Project decision history | `<project>/.mega-sdd/memory/decisions.md` | When generating unit's `## Anti-patterns` section: include past CONFLICT KEEP_CODE files as "don't modify" Anti-patterns (informational guidance, NOT machine-validated Hard Rules) |
| Classifier override patterns | `<vault>/.memory/classifier-accuracy.json` | When unit derives from a vault OQ that was overridden by user, surface in unit's `## Context` as note: "this OQ was reclassified manually; original heuristic may not match" |

### Writes

This skill does NOT write to memory directly. Unit generation is read-mostly; bolt-time outcomes (success / Hard Rule violation / acceptance test results) are written by `execute-bolts` to `<vault>/.memory/bolt-outcomes.json`.

### Anti-halu rails

- Memory consultation surfaces in unit body (Anti-patterns section or Context note); never modifies frontmatter without user review
- Downgraded Hard Rules (memory-derived) cite the violation history in Anti-pattern line
- `--memory-off` disables memory reads; units fall back to binding-only suggestions
