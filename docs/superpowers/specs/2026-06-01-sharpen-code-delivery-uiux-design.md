# Spec — Sharpen Code Delivery: Decomposition Reasoning + UI/UX Quality (tech-agnostic)

**Date:** 2026-06-01
**Status:** Approved (design); implementation in progress on `feat/sharpen-code-delivery-uiux`
**Traces to:** `docs/superpowers/audits/2026-06-01-code-delivery-uiux-deep-audit.md` (structural audit) + the `new-tradefinance-import` Phase-2 real-run evidence (fixture).
**Author partner:** Farhan Riuzaki

---

## 0. Problem (evidence-grounded)

The pipeline runs well through spec generation, but **code delivery is the weak link** — UI/UX quality is inconsistent and the flow→file decomposition reasoning is shallow. Proven from the `new-tradefinance-import` Phase-2 run:

- **Module-altitude decomposition.** `generate-units` derives units at MODULE granularity with citation-style grounding, but never derives **flow-STEP → artifact** nor runs a **cross-unit consistency pass**. Every post-generation repair lives *below* the module boundary: 8 missing per-stage Form Requests (`cdde29d`), 6 dead `edit.blade.php` stubs (`0e4ae78`), divergent branch-scoping across siblings + missing relations (`abe8d9b`), inbox coverage gap for a born-mid-flow entity (`af49ede`).
- **Fan-out divergence** ("LC is always the survivor"): the golden exemplar module is built correctly, siblings diverge. Signatures: *5-of-6 (golden survived) = fan-out divergence; all-6-identical = scaffolder/template defect.*
- **Execution-fidelity miss** (NOT a spec gap): BranchScoped trait was in all 5 sibling specs — bolts forgot the `addGlobalScope()` registration (`2bdfc1b`). Belongs at execution, not decomposition.
- **UI quality is a coin-flip, not a floor.** U-009 and U-026 had *equally UI-silent specs*; U-009 shipped clean, U-026 shipped raw scaffold (titles `"…Controller List"`, labels `"Customer Id"`, raw UUID FKs, no formatting/states/a11y). ~3,500 lines of operator UX (Decision Card, approval inbox, audit timeline) were hand-built post-generation because **capture never modeled the primary user task.**

## 1. Design principles (non-negotiable)

1. **Tech-stack-agnostic.** Laravel is the *example and fixture*, never the contract. Every fix has a **universal reasoning core** (operates on vault / units / flows / architecture — stack-neutral) plus **stack-specific signatures declared in the framework-convention pack** (`references/framework-conventions/`). A validator that hardcodes `.blade.php` / `@section` / `Str::title` is wrong — those live in `laravel.md` as declared signatures the universal validator reads. Adding a stack = adding a pack, never editing a validator.
2. **Validator-first; prose is defense-in-depth.** The plugin's documented failure mode is skill-body prose the model no-ops (4× at Iter 64/65/66a/67). Each fix ships a **deterministic validator/hook** as the enforcement, with sharpened SKILL prose riding along — never prose alone.
3. **Fixture-verified definition-of-done.** Each validator's acceptance test is the tradefinance git history: **run against the pre-repair state → MUST flag the exact defect; run against the post-repair state → MUST pass.** The current Phase-2 units are live test input (they still list `edit.blade.php`; FRs only on Store+CraApprove).
4. **Graceful degradation.** A pack that does not declare a section → the dependent validator SKIPs that check (writes `status: SKIP`), exactly like the existing no-starterkit / no-vault SKIPs. No stack is ever blocked for lacking a signature it never declared.
5. **Reuse the existing wiring.** Clone `validate-handoff-binding-units.sh` (blocking) / `validate-starterkit-conformance.sh` (file-check). Each validator OWNS one state file, OVERWRITE-NOT-APPEND. Blocking = a PreToolUse branch reads the state file `status`. Project root via `_lib/resolve-project-root.sh`.
6. **Honest Fork-A enforcement boundary.** Two enforcement shapes exist and the spec uses each where it actually bites:
   - **Spec-time block (slices A, B, D):** the validator runs on the *units* (Write/Edit of unit files via PostToolUse) and a PreToolUse branch blocks the next `mega-sdd:execute-bolts` if `status: FAIL`. This is a true pre-execution block — the offending units must be fixed before bolts run.
   - **Post-write detect-and-block-next (slices C, E):** the validator runs on Write/Edit of *generated source* (model/view files). Fork A cannot un-write a file a bolt subagent just wrote mid-turn (that is Fork-B mid-turn intervention). So enforcement is: detect on Write/Edit → write the blocker state file → the next gated Skill invocation (`execute-bolts` for the next unit, or a re-validate) is blocked, AND the violation is surfaced loudly in the dispatch contract the *current* bolt reads. This is the strongest honest Fork-A enforcement; we do NOT claim a mid-bolt hard stop.

## 2. Framework-pack schema extension (the tech-agnostic backbone)

New declared sections added to `_template.md` (the contract), with universal defaults documented in `_universal.md` where they generalize, and concrete signatures filled in `laravel.md` / `laravel-base-26.md` (proven against tradefinance). Each section is OPTIONAL; absence → dependent validator SKIPs.

```
## Flow-artifact derivation            # slice A
  endpoint_kinds:                      # how a flow "step" that accepts input maps to a required artifact
    - flow_signal: <regex/keywords identifying an input-accepting state-transition step in 04-flows>
      required_artifact: <artifact-kind, e.g. form-request | serializer | form-object | validation-schema>
      path_glob: <where that artifact lives>
  # Laravel: input-accepting transition → Form Request at app/Http/Requests/**

## Conditional scaffold artifacts       # slice A (anti dead-stub)
  - artifact_glob: <e.g. resources/views/**/edit.blade.php>
    requires_flow_endpoint: <endpoint-kind that must exist for this artifact to be valid, e.g. update|PUT>
  # if no flow step matches requires_flow_endpoint → artifact is a dead stub; flag it

## Cross-cutting concerns               # slices B, C
  - concern: <id, e.g. branch-scoping | soft-delete | audit | authz-bypass>
    applies_when: <model/unit signal, e.g. has column branch_id>
    spec_obligation: <what the UNIT must declare — checked by sibling-consistency, slice B>
    registration_signature: <runtime call the BOLT must emit — checked post-flight, slice C>
  # Laravel branch-scoping: applies_when has branch_id; spec_obligation "lists BranchScoped trait + branch() relation"; registration_signature "addGlobalScope(new BranchScoped) in booted()"

## Relation derivation                  # slice B
  fk_to_accessor: <rule: FK column {x}_id ⇒ relation accessor name + kind>
  # universal default: {singular}_id ⇒ belongsTo accessor `{singular}`

## Test patterns                        # slice D
  detail_view_render:
    template: <stack test snippet that GETs the detail route and asserts a real field renders>
  # Laravel: $this->get(route('{resource}.show',$m))->assertOk()->assertSee($m->{field})

## UI quality signatures                # slice E
  view_glob: <e.g. resources/views/**/*.blade.php>
  scaffold_stub_glob: <path of the generator stub, for min-delta diff>   # optional
  scaffold_tells:                       # raw generator output that must NOT ship
    - id: <name>
      regex: <pattern>
      message: <why it's wrong>
  required_elements:                    # must be present in a non-trivial view
    - id: <name>
      regex: <pattern>
      message: <what's missing>
  # Laravel/Vuexy fills: title-is-Controller, label-is-Column-Id, raw-uuid-fk, money-without-format,
  #   native-alert; required: layout-extends, responsive-breakpoint, aria/label

## Component pattern category           # slice F (extends file-location for few-shot)
  view_component:
    location: <e.g. resources/views/**>
    exemplar_selection: linter-clean | idiom-score   # NOT [0]
```

`bind-codebase` already injects pack-derived Hard Rules into `binding.md §Suggested Unit Hard Rules`; these new sections are consumed by the validators directly (which re-resolve the active pack from `starterkit-context.yaml` / `codebase-map.md`) and, where they produce unit obligations, surfaced through the same binding→units channel.

## 3. The seven slices

Each slice = **validator(s) + pack-schema fill + sharpened SKILL prose + test fixture + fixture-proof + atomic commit.** Stage tag = the stage that actually failed.

### Slice A — Flow-step → artifact derivation + scaffold-filter  *(stage: decomposition / generate-units)*
- **Universal core:** parse `04-flows` for input-accepting state-transition steps; assert each maps to a `required_artifact` in some unit's `target_files`; assert each conditional scaffold artifact in `target_files` has its `requires_flow_endpoint` present in the flows (else dead stub).
- **Enforcement:** `validate-flow-coverage.sh` → `.flow-coverage-state.json`; wired BLOCKING on `mega-sdd:execute-bolts` via a new PreToolUse branch (units are the input; block bolts if coverage fails).
- **Prose:** generate-units Step 2 gains a flow-step→artifact derivation sub-step; the set of per-step artifacts a module unit ships = the set of endpoints its flow enumerates (no more, no fewer).
- **Fixture proof:** against current Phase-2 units → flags 8 missing Form Requests + 6 dead `edit.blade.php` stubs.

### Slice B — Cross-unit sibling-consistency  *(stage: decomposition / generate-units)*
- **Universal core:** group sibling units (same `module`/`scope`, structurally analogous models); for each pack `cross-cutting concern` whose `applies_when` matches, assert all siblings declare the same `spec_obligation`; assert FK columns have the `Relation derivation` accessor.
- **Enforcement:** `validate-sibling-consistency.sh` → `.sibling-consistency-state.json`; BLOCKING on execute-bolts.
- **Prose:** generate-units new Step 12.x sweep — reason about sibling models *together*; one consistent mechanism per shared concern.
- **Fixture proof:** flags divergent branch-scoping (direct vs `via lc_id` vs bare) + missing `branch()` relations across siblings.

### Slice C — Per-sibling post-flight cross-cutting scan  *(stage: execution / execute-bolts)*
- **Universal core:** at post-flight, for each pack cross-cutting concern with a `registration_signature`, scan each committed sibling file for the signature; missing → halt before commit.
- **Enforcement:** extend execute-bolts post-flight scan (already exists) to iterate per-sibling; `validate-cross-cutting-registration.sh` → `.cross-cutting-state.json`.
- **Prose:** execute-bolts post-flight section — cross-cutting Hard Rules proven on the exemplar are scanned PER fanned-out module, not once.
- **Fixture proof:** against pre-`2bdfc1b` state → flags 5 models missing `addGlobalScope()`.

### Slice D — Render-test-per-module gate  *(stage: execution+gate / execute-bolts + generate-units)*
- **Universal core:** every unit whose `target_files` include a detail view must carry an `acceptance_test` of kind `render` derived from the pack `Test patterns.detail_view_render`; bolt must emit it; validator asserts presence.
- **Enforcement:** add `render` to the `acceptance_test` schema; `validate-unit-spec.sh` (existing, detection) extended + routed BLOCKING for view-bearing units.
- **Prose:** generate-units Step 9 (acceptance_test) + execute-bolts test emission.
- **Fixture proof:** the absence of such a test correlates with the branch `—` / empty-model show / null-timestamp crashes (`abe8d9b`/`4e0b485`/`390fdd0`) — one render test catches all three.

### Slice E — UI scaffold-tells quality gate  *(stage: gate / new hook)*
- **Universal core:** `validate-ui-quality.sh` scans touched view files (pack `view_glob`) for pack `scaffold_tells` (must be absent) + `required_elements` (must be present) + optional min-delta vs `scaffold_stub_glob`.
- **Enforcement:** `.ui-quality-blockers.json` + new PreToolUse Branch 8 blocking `mega-sdd:execute-bolts` (slice E shipped as Branch 8; flow-coverage took Branch 5); PostToolUse Style-A dispatch on Write|Edit of view files.
- **Prose:** execute-bolts dispatch contract gains positive UI obligations (defense-in-depth).
- **Fixture proof:** against pre-polish LC view (`bf950ef`) → flags Controller-title + "Customer Id" + raw UUID; against post-polish (`a07704a`) → passes.

### Slice F — UI design-contract + design-token enrichment + frontend-design injection + UI few-shot  *(stage: enrichment / generate-units + execute-bolts)*
- **Universal core:** generate-units attaches a UI contract (label map, FK→display resolution, formatting, required empty/loading/error states — all grounded in vault flows/design-system, never invented) to any unit with view `target_files`; execute-bolts un-excludes `design_tokens` at `SKILL.md:260`, injects them + a UI exemplar few-shot (selected linter-clean, not `[0]`; e.g. the clean U-009) + frontend-design design heuristics as hook-injected TEXT (not a prose Skill-invoke).
- **Enforcement:** `validate-dispatch-prompt.sh` asserts a UI unit's emitted dispatch prompt actually carries tokens + exemplar (makes the enrichment durable, not no-op-able).
- **Prose:** execute-bolts T2 slice builder (un-exclude tokens, add view/component category to the Iter 76 code-slice).
- **Fixture proof:** dispatch prompt for a UI unit must contain design tokens + a view exemplar.

### Slice G — Operator-workflow-UX capture + Design-Source OQ  *(stage: capture / generate-intent)*
- **Universal core:** when PRD/KB flows exhibit a maker-checker / multi-stage-approval / workflow pattern, generate-intent models the operator-facing surface (worklist/inbox, decision affordance, human-readable state labels, audit timeline) as first-class requirements grounded in the flows — NOT invented. When UI components exist but `HAS_TOKENS/HAS_A11Y/HAS_VOICE_BRAND` are all false, emit a high-priority **Design-Source OQ** (do NOT relax the anti-hallucination rail).
- **Enforcement:** `validate-vault-oqs.sh` (existing) extended — if the vault has a workflow/maker-checker flow but no operator-surface requirement and no Design-Source OQ → FAIL.
- **Prose:** generate-intent flow/UX capture section.
- **Fixture proof:** a maker-checker vault must carry inbox/decision/timeline requirements or a Design-Source OQ (the tradefinance vault carried neither — that is the captured miss).

## 4. Verification strategy

The tradefinance repo is the **fixture only** — its `app/` is never edited (already repaired by the author). For each slice the test harness:
1. Identifies the pre-repair git state (the commit that introduced the defect or the current-units-still-broken state).
2. Runs the new validator against that state → asserts it FLAGS the documented defect.
3. Runs against the post-repair commit → asserts PASS.
4. Adds a minimal self-contained fixture under `tests/fixtures/` mirroring the defect shape (so the suite is reproducible without the external repo).

## 5. Non-goals

- No edits to `new-tradefinance-import` source.
- No relaxation of the anti-hallucination rail (slice G adds an OQ, never a defaulted WCAG/Material value).
- No new runtime dependency (validators are bash + python3, per existing convention).
- Fork-B control-plane items (implicit re-plan detection, lazy-load enforcement) remain parked.

## 6. Versioning

MAJOR-adjacent (new skills behavior + new hook branch). Bump `plugin.json` and touched skill `version:` frontmatter; CHANGELOG entry referencing this spec. New pack sections are additive/back-compatible (optional, SKIP on absence).
