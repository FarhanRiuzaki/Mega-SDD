# generate-units Trigger + Behavior Test

## Trigger cases

### GU1: Explicit
- **Prompt:** `/mega-sdd:generate-units ./vaults/v1-bound`
- **Expect:** Skill invocation

### GU2: Indonesian
- **Prompt:** `pecah vault jadi unit`
- **Expect:** Skill invocation

### GU3: Auto-route from flow (after bind)
- **Setup:** bound-vault exists, no units/ dir
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** Flow proposes generate-units

## Behavior

### B1: Greenfield vault → units with empty binding_refs
- **Setup:** vault.json has `mode: greenfield`, no bound-vault
- **Expect:** units generated with `binding_refs: []`

### B2: Brownfield bound-vault → units cite binding
- **Setup:** bound-vault with binding.md (10 CONFIRMED, 2 OQ)
- **Expect:**
  - Units cite C-XXX in `binding_refs`
  - Units affected by OQs have "TBD: OQ-XXX" in body
  - target_files populated from binding evidence

### B3: Cycle rejection
- **Setup:** vault structured such that U-001 depends on U-002 and vice versa
- **Expect:** halt with cycle message

### B4: Atomicity enforcement
- **Setup:** vault section that would produce >300 LOC
- **Expect:** split into U-XXX, U-XXX.1, U-XXX.2 with explicit deps

### B5: Acceptance test mandatory
- **Setup:** unit candidate with no obvious test
- **Expect:** generator inserts placeholder test command + halt with prompt to confirm, OR halts entirely

### B6 (v1.1+): Single-squad / no-squad mode = current behavior
- **Setup:** vault has no `_meta/squads.yaml` file
- **Expect:** units generated without `squad:` field (or with `squad: default`); no cross-squad validations run; behavior identical to v1.0

### B7 (v1.1+): Multi-squad assignment per partition rules
- **Setup:** vault has `_meta/squads.yaml` declaring 3 squads (squad-be, squad-fe-web, squad-integrations) with layer-based partition; vault flows include F-U-001 (user/web), F-B-003 (backend), and a flow touching Stripe (component owned by integrations)
- **Expect:** F-U-001 unit gets `squad: squad-fe-web`; F-B-003 unit gets `squad: squad-be`; Stripe-touching unit gets `squad: squad-integrations`

### B8 (v1.1+): Cross-squad depends_on rejected
- **Setup:** generate-units would produce a unit U-FE-007 that depends_on U-BE-012 (different squad)
- **Expect:** halt with `cross_squad_dep_invalid` blocker YAML; next_action mentions routing via interface

### B9 (v1.1+): Dangling interface reference rejected
- **Setup:** a unit declares `consumes_interfaces: [does-not-exist]` (no `<vault>/interfaces/does-not-exist.md`)
- **Expect:** halt with `interface_ref_missing` blocker YAML

### B10 (v1.1+): Ambiguous routing detected
- **Setup:** two squads both declare `owns_layers: [backend]` in squads.yaml; vault has backend flow F-B-001
- **Expect:** halt with `cross_squad_ambiguous` blocker YAML listing both claiming squads

## Task-type assignment (v1.2+, Iter 1)

### TT1: All NEW claims → create unit
- **Setup:** bound-vault binding.md Implementation State Map has all claims for this candidate as `state: NEW`
- **Expect:** unit emitted with `task_type: create`, all `target_files.operation: create`

### TT2: All IMPLEMENTED claims → verify unit
- **Setup:** all claims for this candidate are `state: IMPLEMENTED, confidence: high`, with concrete anchors
- **Expect:**
  - Unit emitted with `task_type: verify`
  - `target_files` empty OR all `operation: none`
  - Body has `## Anchors` section with the binding anchors cited
  - `## Implementation steps` is the single line: "No code changes. Run acceptance tests against existing implementation at <anchor>."
  - `acceptance_test` asserts existing behavior, not new behavior

### TT3: Mix of NEW + IMPLEMENTED → SPLIT
- **Setup:** candidate covers 2 claims: one IMPLEMENTED (existing read endpoint), one NEW (new write endpoint)
- **Expect:**
  - Two units emitted: one `task_type: verify` for IMPLEMENTED claim, one `task_type: create` for NEW claim
  - `depends_on` chain set so verify runs first

### TT4: UNKNOWN state → conservative `create`
- **Setup:** candidate has at least one claim with `state: UNKNOWN` (any confidence)
- **Expect:**
  - Unit emitted with `task_type: create` (conservative default per DESIGN-OQ-1)
  - Body has a note: "Binding marked one or more claims as UNKNOWN (anchor: ...). Verify manually whether this work is needed."

### TT5: verify unit missing anchor → downgrade to create
- **Setup:** binding has `state: IMPLEMENTED` but anchor field is empty/null
- **Expect:** unit downgraded to `task_type: create`; halt-or-warn surfaced (binding gap)

### TT6: No Implementation State Map → all create (backward compat)
- **Setup:** binding.md is pre-v1.2 — no Implementation State Map section
- **Expect:**
  - All units assigned `task_type: create` (current behavior)
  - No regression vs v1.1

### TT7: Dedup halt — create unit conflicts with existing files
- **Setup:** unit with `task_type: create` has target_files `[src/foo.ts, tests/foo.test.ts]`; codebase-map §1 already lists both files; the Implementation State Map didn't flag the corresponding claims as IMPLEMENTED (binding gap)
- **Expect:** halt with `dedup_ambiguous` blocker YAML; unit NOT silently rewritten
- **Halt YAML:** `type: dedup_ambiguous`, `conflicting_paths: [...]`, `suggested_resolutions: [...]`

### TT8: extend type not auto-emitted in Iter 1
- **Setup:** binding has only IMPLEMENTED + NEW + UNKNOWN states (no Iter 2 PARTIAL signal)
- **Expect:** NO unit emitted with `task_type: extend`. extend is reserved for Iter 2/3 auto-emission. User who needs extend semantics in Iter 1 must edit unit frontmatter manually.

## Polished-prompt render pass (v1.3+, Iter 3)

### PP1: Anchors mandatory for verify
- **Setup:** binding has IMPLEMENTED claim → candidate becomes `task_type: verify`; generate-units forgets to populate Anchors
- **Expect:** Step 12.4 render pass detects missing Anchors; HALT with `unit_underspecified` listing missing_sections: [Anchors]

### PP2: Anchors mandatory for extend
- **Setup:** user-edited unit with `task_type: extend` (manual override in Iter 1); Anchors empty
- **Expect:** render pass halts with `unit_underspecified`

### PP3: Hard rules grammar validated
- **Setup:** unit with Hard rules line `please don't break stuff`
- **Expect:** render pass halts with `hard_rule_unparseable`; expected_grammar lists the 5 productions

### PP4: Migration notes required for extend
- **Setup:** `task_type: extend` unit; Migration notes section absent OR has only 2 of 3 sub-lists
- **Expect:** halt `unit_underspecified` with missing_sections: [Migration notes]

### PP5: Migration notes forbidden outside extend
- **Setup:** `task_type: create` unit accidentally has Migration notes section
- **Expect:** halt `unit_underspecified` (section disallowed for this task_type)

### PP6: Directive prose check — warning only
- **Setup:** `task_type: create` unit with Implementation steps as pure bullet checklist (no sentence >15 words)
- **Expect:** render pass emits WARNING in chat ("low directive density"); does NOT halt; unit still written

### PP7: Verify unit single-line implementation steps
- **Setup:** `task_type: verify` unit with the special single-line "No code changes..." Implementation steps
- **Expect:** directive prose check PASSES (special case allowed); no warning

### PP8: Anti-patterns auto-population from binding
- **Setup:** binding.md "## Suggested Unit Hard Rules" has Anti-patterns entry for the unit's vault_source
- **Expect:** generate-units auto-fills the unit's `## Anti-patterns` section with the suggestion (informational; not validated)

### PP9: Hard rules auto-population from binding
- **Setup:** binding.md "## Suggested Unit Hard Rules" has Hard rule entry `DO NOT modify app/Models/User.php` for the unit's vault_source
- **Expect:** generate-units auto-fills the unit's `## Hard rules` with this rule; line is parseable per grammar (passes render-pass check)

## Defensive generation (v2.1+, Iter 8)

### DG1: Pre-flight detects missing upstream artifacts
- **Setup:** brownfield vault (`mode=existing`); no codebase-map.md; no binding.md
- **Run:** `/mega-sdd:generate-units ./vault/`
- **Expect:** INTERACTIVE prompt — "Brownfield vault but upstream artifacts missing. Options: (1) auto-run scan-codebase + bind-codebase first (recommended) / (2) proceed with LOW confidence / (3) cancel"
- User picks (1) → skill invokes scan-codebase + bind-codebase via auto-route; returns to generate-units Step 1

### DG2: Pre-flight skipped for clean greenfield
- **Setup:** greenfield vault; no codebase-map (expected); no binding (expected)
- **Expect:** NO prompt; proceeds directly to Step 1 with MEDIUM grounding confidence (no codebase context expected)

### DG3: PARTIAL_FIELDS_MISSING auto-extends with Migration notes
- **Setup:** binding has C-LOGIN-1 state=PARTIAL_FIELDS_MISSING with field_diff: ADD=[nama], KEEP=[nip, password], REMOVE=[]
- **Run:** generate-units
- **Expect:**
  - Unit emitted with `task_type: extend`
  - Migration notes auto-populated:
    - ADD: `nama` field — new validated input on POST /api/login
    - KEEP: `nip`, `password` (existing logic preserved)
    - REMOVE: (none)
  - `grounding_confidence: HIGH` in frontmatter
  - `grounding_evidence.binding_state_summary: { PARTIAL_FIELDS_MISSING: 1 }`

### DG4: PARTIAL_FIELDS_SURPLUS triggers interactive prompt
- **Setup:** binding has state=PARTIAL_FIELDS_SURPLUS with field_diff: ADD=[], KEEP=[order_id, items], REMOVE=[legacy_ref]
- **Expect:** INTERACTIVE prompt with options:
  - (1) Feature drift — vault is incomplete (suggest update vault)
  - (2) Legacy deprecation — REMOVE `legacy_ref` is intentional cleanup (extend with REMOVE)
  - (3) Field rename — `legacy_ref` was renamed (specify new name)
  - (4) Vault correct as-is — code has fields vault explicitly excludes (extend with REMOVE)
- User pick determines Migration notes content

### DG5: Per-unit collision INTERACTIVE prompt
- **Setup:** unit U-007 candidate has target_files `[app/Http/Controllers/UserController.php]` with `operation: create`; binding has IMPLEMENTED state for related claim; file exists on disk
- **Expect:** INTERACTIVE prompt:
  - "Target file `app/Http/Controllers/UserController.php` already exists. Binding marked claim IMPLEMENTED with high confidence."
  - Options: (1) Convert to `verify` (recommended) / (2) Convert to `extend` / (3) Rename / (4) Force `create` overwrite (DANGEROUS) / (5) Skip
- User picks (1) → unit converted to verify; target_files cleared; acceptance_test populated

### DG6: Anchor verification — file missing = WARNING (not halt)
- **Setup:** unit has Anchor `app/Http/Controllers/AuditLogController.php:1 — existing pattern`; file does not exist
- **Expect:**
  - WARNING in unit body footer: `<!-- ⚠️ Anchor warning: app/Http/Controllers/AuditLogController.php:1 file not found; anchor may be aspirational -->`
  - Unit STILL written (no halt)
  - `grounding_evidence.anchors_verified: 0/1` in frontmatter

### DG7: Grounding confidence label visible in chat output
- **Setup:** generate 3 units with varying confidence
- **Expect chat lines:**
  ```
  ✓ U-001 generated (task_type: verify, grounding: HIGH, anchors: 3/3 verified, target_files: 0 modify)
  ✓ U-002 generated (task_type: extend, grounding: HIGH, anchors: 2/2 verified, target_files: 2 modify + 0 create)
  ⚠️ U-003 generated (task_type: create, grounding: LOW, anchors: 0/2 verified — 2 aspirational, target_files: 4 create)
  ```

### DG8: --no-defensive flag disables Iter 8 steps
- **Run:** `/mega-sdd:generate-units ./vault/ --no-defensive`
- **Expect:**
  - Step 0.5 skipped (no pre-flight prompt)
  - Step 7.6 skipped (no per-unit collision prompt)
  - Step 12.4.5 skipped (no anchor verification)
  - Behavior identical to v2.0 (Iter 6)
  - All units get `grounding_confidence: LOW` (no defensive evidence)

### DG9: --auto + --deep mode picks safest defaults silently
- **Run:** invoked under `orchestrate-flow --deep` (autonomous chain)
- **Expect:**
  - Pre-flight auto-routes scan + bind without prompt
  - Per-unit collision defaults to `extend` (no prompt)
  - Anchor warnings emitted but no halt
  - User reviews after chain ends via unit-by-unit inspection

### DG10: --collision-policy flag overrides batch behavior
- **Run:** `/mega-sdd:generate-units ./vault/ --collision-policy=verify`
- **Expect:** All target_files collisions auto-convert to `verify` task_type without prompts; useful for "I trust binding; just give me verify units for everything existing"

## Pass criteria

All triggers fire. Behavior checks pass. No unit generated without valid frontmatter per unit-schema.md. Task-type assignment (TT1-TT8) follows generate-units §2.5 + §12.5 per Iter 1. Polished-prompt render pass (PP1-PP9) follows §12.4 per Iter 3 spec. Defensive generation (DG1-DG10) follows `references/defensive-generation.md` per Iter 8 — auto-detect upstream, per-unit collision interactive prompts, anchor warnings (soft), PARTIAL_FIELDS_* auto-extends with Migration notes populated from field_diff, grounding_confidence label visible in frontmatter + chat. Anchors mandatory + Hard rules parseable + Migration notes structural rules + directive prose guidance — all enforced.

---

## Iter 32 — Starterkit-aware unit generation cases (v2.6.0+)

### GU-SK1 — Unit gains starterkit Anchors + Hard Rules with Citations

**Setup:**
- Vault at `.mega-sdd/vaults/my-app/` with bound binding.md
- `.mega-sdd/codebase/starterkit-context.yaml` exists with:
  - `auth.lib: sanctum`, `auth.user_model: "App\\Models\\User"`
  - `ui_ux.layout_extends: "layouts.app"`, `ui_ux.notification_lib: sweetalert2`
  - `ui_ux.idioms: ["use document.addEventListener('DOMContentLoaded', ...) over $(document).ready", "responsive mobile-first (sm/md/lg breakpoints)"]`
- Vault includes a feature "Add user CRUD page" targeting `resources/views/users/index.blade.php`, `app/Http/Controllers/UserController.php`, `routes/web.php`

**Trigger:** `/mega-sdd:generate-units .mega-sdd/vaults/my-app`

**Expected:**
- Step 4 framework pack loaded (laravel-base-26.md)
- Step 7.7.a: starterkit-context.yaml loaded successfully
- Step 7.7.b: For the user-CRUD unit, `starterkit_relevance = [ui_ux, auth, libs]`:
  - ui_ux: target_files include `resources/views/**`
  - auth: target_files include `app/Http/Controllers/**` AND body mentions "user"
  - libs: target_files overlap with usage_hint of sanctum + sweetalert2
- Step 7.7.c: unit.anchors[] gains:
  - `resources/views/layouts/app.blade.php`
  - `app/Models/User.php`
  - `resources/views/components/`
- Step 7.7.d: unit.hard_rules[] gains (at minimum):
  - `{text: "MUST extend layouts.app ...", citation: "starterkit-context.yaml §ui_ux.layout_extends"}`
  - `{text: "MUST use SweetAlert2 for confirmations and notifications ...", citation: "starterkit-context.yaml §ui_ux.notification_lib"}`
  - `{text: "MUST follow starterkit idiom: use document.addEventListener('DOMContentLoaded', ...) over $(document).ready", citation: "starterkit-context.yaml §ui_ux.idioms"}`
  - `{text: "MUST follow starterkit idiom: responsive mobile-first (sm/md/lg breakpoints)", citation: "starterkit-context.yaml §ui_ux.idioms"}`
  - `{text: "MUST use auth mechanism 'session' (lib: sanctum) ...", citation: "starterkit-context.yaml §auth.mechanism"}`
- Step 7.7.e: unit.frontmatter gains:
  - `starterkit_context_consumed: true`
  - `starterkit_relevance: [ui_ux, auth, libs]`
- Unit footer §Citations section appends: `starterkit-context.yaml`
- Step 12.5 citation check PASSES (all starterkit-derived rules have citations)

### GU-SK2 — Greenfield vault (no starterkit-context.yaml) degrades gracefully

**Setup:**
- Vault at `.mega-sdd/vaults/greenfield-app/`
- `.mega-sdd/codebase/starterkit-context.yaml` does NOT exist (greenfield project)
- Vault has same feature spec as GU-SK1

**Trigger:** `/mega-sdd:generate-units .mega-sdd/vaults/greenfield-app`

**Expected:**
- Step 7.7.a: file absent → log "starterkit-context unavailable; emit framework-pack-only Anchors"
- Steps 7.7.b - 7.7.d SKIPPED
- Step 7.7.e: every unit's frontmatter gets `starterkit_context_consumed: false`, `starterkit_relevance: []`
- Unit.anchors[] populated from framework pack + binding (NO starterkit-specific anchors)
- Unit.hard_rules[] populated from framework pack only (NO starterkit-derived rules)
- NO halt emitted
- Step 12.5 citation check passes (no starterkit rules to validate)

### GU-SK3 — Missing citation triggers halt

**Setup:**
- Vault as GU-SK1 (starterkit-context.yaml present)
- Generated unit body (after Step 7.7) somehow contains a Hard Rule with `source: starterkit-context.yaml` but no `citation:` field (simulated: inject test fixture that bypasses Step 7.7.d's citation enforcement)

**Trigger:** generate-units Step 12.5 runs polished-prompt render pass

**Expected:**
- Step 12.5 citation check identifies the offending rule
- Halt `starterkit_rule_citation_missing` emitted with full envelope:
  ```yaml
  type: starterkit_rule_citation_missing
  source_skill: generate-units
  details:
    unit_id: U-003
    rule_text: "<text>"
    missing_citation: "starterkit-context.yaml §<path>"
    rule_index: 4
  next_action:
    type: edit_unit
    suggested_args: ["U-003"]
    hint: "Append 'Citation: starterkit-context.yaml §<path>' to Hard Rule #4"
  ```
- Unit U-003 is NOT written; pipeline STOPS (always-stop)
- Other units already-validated may have been written (partial completion is acceptable per existing generate-units halt semantics)
