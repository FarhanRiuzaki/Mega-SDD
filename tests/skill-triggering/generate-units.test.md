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

## Pass criteria

All triggers fire. Behavior checks pass. No unit generated without valid frontmatter per unit-schema.md. Task-type assignment (TT1-TT8) follows generate-units §2.5 + §12.5 per Iter 1. Polished-prompt render pass (PP1-PP9) follows §12.4 per Iter 3 spec. Anchors mandatory + Hard rules parseable + Migration notes structural rules + directive prose guidance — all enforced.
