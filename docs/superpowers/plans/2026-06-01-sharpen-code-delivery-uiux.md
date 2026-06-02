# Sharpen Code Delivery (Decomposition Reasoning + UI/UX) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or subagent-driven-development to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make mega-sdd code delivery sharper — flow-step→artifact decomposition reasoning, cross-unit consistency, and UI/UX quality — enforced by tech-agnostic validators (universal core + framework-pack-declared signatures), each fixture-verified against the `new-tradefinance-import` git history.

**Architecture:** Each slice ships a deterministic validator (clone of `validate-handoff-binding-units.sh` / `validate-starterkit-conformance.sh`) reading stack-specific signatures from the active framework-convention pack, wired via the existing PostToolUse-detect + PreToolUse-block pattern, with sharpened SKILL prose as defense-in-depth. No hardcoded stack assumptions in any validator. No edits to the tradefinance repo (fixture only).

**Tech Stack:** bash + python3 validators; markdown skill bodies + framework-convention packs; Claude Code hooks (pre-tool-use / post-tool-use); pytest-free shell fixtures under `tests/fixtures/`.

**Traces to:** `docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md`

---

## File Structure

**Shared infra (Task 0):**
- Create `plugins/mega-sdd/scripts/_lib/resolve-framework-pack.sh` — resolve active pack file(s) from `starterkit-context.yaml` / `codebase-map.md`, honoring `extends:` chain. Reused by all validators.

**Framework-pack schema (per-slice additive):**
- Modify `plugins/mega-sdd/references/framework-conventions/_template.md` — add the section schema for each slice.
- Modify `_universal.md` — universal defaults where they generalize (relation-derivation, cross-cutting concern detection).
- Modify `laravel.md` + `laravel-base-26.md` — concrete signatures (proven vs tradefinance fixture).

**Validators (one new file per slice A,B,C,E,F; extend existing for D,G):**
- Create `validate-flow-coverage.sh` (A) → `.flow-coverage-state.json`
- Create `validate-sibling-consistency.sh` (B) → `.sibling-consistency-state.json`
- Create `validate-cross-cutting-registration.sh` (C) → `.cross-cutting-state.json`
- Modify `validate-unit-spec.sh` (D) — parse `acceptance_test`, require `render` kind for view-bearing units
- Create `validate-ui-quality.sh` (E) → `.ui-quality-blockers.json`
- Create `validate-dispatch-prompt.sh` (F) → `.dispatch-prompt-state.json`
- Modify `validate-vault-oqs.sh` (G) — operator-surface / Design-Source-OQ check

**Hooks:**
- Modify `plugins/mega-sdd/hooks/pre-tool-use` — Branches 5/6/7 (A flow-coverage, B sibling-consistency, E ui-quality) block `mega-sdd:execute-bolts`; D routes through existing unit-spec blocker if needed.
- Modify `plugins/mega-sdd/hooks/post-tool-use` — Style-A dispatch for each new validator on its file globs.

**Skill bodies:**
- Modify `generate-units/SKILL.md` (A: Step 2 derivation; B: Step 12.x sibling sweep; D: Step 9 render test; F: UI contract)
- Modify `execute-bolts/SKILL.md` (C: per-sibling post-flight; E: UI contract prose; F: un-exclude design_tokens at :260 + view few-shot)
- Modify `generate-intent/SKILL.md` (G: operator-UX capture + Design-Source OQ)
- Modify `references/unit-schema.md` (D: add `render` to acceptance_test enum)

**Fixtures:**
- Create `tests/fixtures/code-delivery/<slice>/` — minimal reproductions mirroring each defect, + a `verify.sh` per slice that runs the validator against the fixture and asserts FLAG/PASS.

---

## Fixture commit map (tradefinance — verification only, never edited)

| Slice | Defect | Pre-repair evidence | Post-repair commit |
|---|---|---|---|
| A | 8 missing Form Requests | current units list FRs only Store+CraApprove | `cdde29d` |
| A | 6 dead `edit.blade.php` | current units list `edit.blade.php` in target_files | `0e4ae78` |
| B | divergent branch-scoping + missing `branch()` | unit specs U-021 (`via lc_id`) vs U-017/019 (direct); no `branch()` | `abe8d9b` |
| C | 5 models missing `addGlobalScope()` | pre-`2bdfc1b` model files | `2bdfc1b` |
| D | empty-model show / branch `—` / null-timestamp | no per-module render test | `4e0b485`,`abe8d9b`,`390fdd0` |
| E | raw scaffold UI | `bf950ef` LC views (Controller-title, "Customer Id", raw UUID) | `a07704a` |
| F | tokens excluded from dispatch | `execute-bolts/SKILL.md:260` exclusion | (n/a — plugin-internal) |
| G | operator-UX/design-source not captured | tradefinance vault has workflow flows, no inbox/decision/timeline reqs, no Design-Source OQ | (n/a — capture miss) |

Because the tradefinance repo may not always be present, each slice ALSO gets a self-contained `tests/fixtures/code-delivery/<slice>/` reproduction so the suite runs standalone. The tradefinance run is the cross-check when available.

---

## Task 0: Shared pack-resolution helper

**Files:**
- Create: `plugins/mega-sdd/scripts/_lib/resolve-framework-pack.sh`
- Test: `tests/fixtures/code-delivery/_lib/verify.sh`

- [ ] **Step 1: Write the failing fixture test**

Create `tests/fixtures/code-delivery/_lib/verify.sh`: a fixture dir with `.mega-sdd/codebase/starterkit-context.yaml` declaring `framework_pack: laravel-base-26`, assert `resolve-framework-pack.sh --cwd=<fixture>` prints the resolved pack chain `laravel-base-26.md laravel.md _universal.md` (extends order, most-specific first).

- [ ] **Step 2: Run, expect FAIL** (`bash tests/fixtures/code-delivery/_lib/verify.sh` → "resolve-framework-pack.sh not found").

- [ ] **Step 3: Implement** `resolve-framework-pack.sh`:
  - Args `--cwd=<root> [--section=<name>] [--quiet]`. Source `resolve-project-root.sh`.
  - Read `<root>/.mega-sdd/codebase/starterkit-context.yaml` key `framework_pack:` (fallback: `codebase-map.md` frontmatter `framework:`; fallback `_universal`).
  - Resolve pack file under `plugins/mega-sdd/references/framework-conventions/<pack>.md`; follow `extends:` frontmatter recursively; print the chain most-specific-first.
  - With `--section=<name>`: print the merged section body across the chain (most-specific wins on key conflict). Exit 0; exit 3 if no pack resolvable (callers treat as SKIP).
  - Pack root is relative to the plugin (`$(dirname "$0")/../../references/framework-conventions`).

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** `feat(scripts): add framework-pack resolver helper for tech-agnostic validators`

---

## Task A: Flow-step → artifact derivation + scaffold-filter  *(decomposition)*

**Files:**
- Create: `plugins/mega-sdd/scripts/validate-flow-coverage.sh`
- Modify: `_template.md` (+`## Flow-artifact derivation`, `## Conditional scaffold artifacts`), `_universal.md` (universal note), `laravel.md` (form-request + edit-view signatures)
- Modify: `generate-units/SKILL.md` (Step 2 sub-step), `pre-tool-use` (Branch 5), `post-tool-use` (dispatch on unit-file Write/Edit)
- Test: `tests/fixtures/code-delivery/flow-coverage/{good,bad}/` + `verify.sh`

**Pack section (laravel.md fill):**
```yaml
## Flow-artifact derivation
  endpoint_kinds:
    - flow_signal: '(?i)\b(submit|review|approve|reject|confirm|dispatch|apply|finalize|enrich)\b'   # input-accepting transition step
      required_artifact: form-request
      path_glob: app/Http/Requests/**/*.php
      naming: '{Action}{Module}Request'
## Conditional scaffold artifacts
  - artifact_glob: 'resources/views/**/edit.blade.php'
    requires_flow_endpoint: '(?i)\b(update|edit|put|patch)\b'
```

**Validator contract** (`.flow-coverage-state.json`):
```json
{ "status": "PASS|FAIL|SKIP", "validator": "flow-coverage", "ts": "...",
  "missing_artifacts": [ {"flow_step":"F-U-008 step 2 (spvReview)","expected":"form-request app/Http/Requests/**","module":"lc-amendment"} ],
  "dead_scaffold": [ {"artifact":"resources/views/lc-amendment/edit.blade.php","reason":"no update/PUT flow step"} ],
  "summary": "...", "next_action": "..." }
```
Logic (python heredoc, clone `validate-handoff-binding-units.sh` skeleton): SKIP if no `Flow-artifact derivation` section in active pack. Else: parse `04-flows.md` of the active vault for steps matching each `flow_signal`; for each, assert ≥1 unit `target_files` has a path matching `required_artifact.path_glob`; collect misses. For each `Conditional scaffold artifacts` entry, find units listing `artifact_glob` in `target_files`; if no flow step matches `requires_flow_endpoint` → `dead_scaffold`. `status=FAIL` if any miss/dead. Exit 0/1/2.

- [ ] **Step 1:** Write `tests/fixtures/code-delivery/flow-coverage/bad/` — a vault `04-flows.md` with 3 input-accepting steps + a unit listing only 1 Form Request and an `edit.blade.php` with no update flow. `verify.sh` asserts validator FLAGS 2 missing FRs + 1 dead stub.
- [ ] **Step 2:** Run → FAIL (validator missing).
- [ ] **Step 3:** Add pack sections (`_template.md` schema + `laravel.md` fill + `_universal.md` note). Implement `validate-flow-coverage.sh`.
- [ ] **Step 4:** Run fixture → validator FLAGS exactly the 2 FRs + 1 stub. Add `good/` fixture (all endpoints covered, no dead stub) → PASS.
- [ ] **Step 4b (tradefinance cross-check):** if `/Users/.../new-tradefinance-import` present, run validator `--cwd=` against it on the current (still-broken) units → asserts it flags the 8 FRs + 6 `edit.blade.php` stubs; against `cdde29d`+`0e4ae78` tree → fewer/zero. (Read-only; do not modify the repo.)
- [ ] **Step 5:** Wire PostToolUse Style-A dispatch (unit-file globs) + PreToolUse Branch 5 (block `execute-bolts` on `.flow-coverage-state.json` status FAIL). Add generate-units Step 2 derivation prose (defense-in-depth, cites this validator). Bump `generate-units` version.
- [ ] **Step 6:** Commit `feat(decomp): flow-step→artifact derivation + scaffold-filter gate (tech-agnostic, fixture-verified)`

---

## Task B: Cross-unit sibling-consistency  *(decomposition)*

**Files:**
- Create: `validate-sibling-consistency.sh`
- Modify: `_template.md` (+`## Cross-cutting concerns`, `## Relation derivation`), `_universal.md` (FK→accessor default + generic concern shape), `laravel.md`/`laravel-base-26.md` (branch-scoping concern, belongsTo derivation)
- Modify: `generate-units/SKILL.md` (Step 12.x sibling sweep), `pre-tool-use` (Branch 6), `post-tool-use`
- Test: `tests/fixtures/code-delivery/sibling-consistency/{good,bad}/`

**Pack section:**
```yaml
## Cross-cutting concerns
  - concern: branch-scoping
    applies_when: 'has_column:branch_id'
    spec_obligation: 'unit lists trait BranchScoped AND a branch() relation in Hard rules/Target files'
    registration_signature: 'addGlobalScope\(new BranchScoped'    # for slice C
## Relation derivation
  fk_to_accessor:
    rule: '{singular}_id => belongsTo accessor `{singular}` (camelCase)'
```
`_universal.md`: `fk_to_accessor` default `{singular}_id ⇒ accessor {singular}` applies to all stacks; concern detection (group siblings by `module`/`scope`, compare `spec_obligation` declarations) is universal.

**Validator** (`.sibling-consistency-state.json`): SKIP if no `Cross-cutting concerns`. Group units by `module`+`scope`. For each concern, find sibling units whose models match `applies_when` (read data-model/units for the column); assert ALL declare `spec_obligation` (string-match the obligation tokens in unit body); divergence → `inconsistent[]`. For each FK column in a unit's model, assert the derived accessor is declared → `missing_relations[]`. FAIL on any.

- [ ] **Step 1:** Fixture `bad/`: 3 sibling units sharing `branch_id`, one declares `via lc_id` instead of the trait, none declare `branch()`. Assert validator flags 1 divergence + 3 missing relations.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Pack sections + implement validator.
- [ ] **Step 4:** Fixture flags exactly those; `good/` (uniform) → PASS.
- [ ] **Step 4b:** tradefinance cross-check vs current units → flags branch-scoping divergence + missing `branch()`.
- [ ] **Step 5:** Wire PostToolUse + PreToolUse Branch 6. generate-units Step 12.x sibling-consistency sweep prose. Bump version.
- [ ] **Step 6:** Commit `feat(decomp): cross-unit sibling-consistency gate (shared-concern coherence + relation derivation)`

---

## Task C: Per-sibling post-flight cross-cutting registration scan  *(execution)*

**Files:**
- Create: `validate-cross-cutting-registration.sh`
- Modify: `execute-bolts/SKILL.md` (post-flight per-sibling prose), `post-tool-use` (dispatch on source-model Write/Edit), `pre-tool-use` (Branch 7: block NEXT `execute-bolts` if `.cross-cutting-state.json` FAIL — honest Fork-A detect-and-block-next per spec §1.6)
- Reuses pack `## Cross-cutting concerns.registration_signature` (from Task B)
- Test: `tests/fixtures/code-delivery/cross-cutting/{good,bad}/`

**Validator** (`.cross-cutting-state.json`): SKIP if no concerns with `registration_signature`. For each generated source file matching a concern's model criteria (`applies_when`), assert the `registration_signature` regex is present in the file → `missing_registration[]`. FAIL on any. (Operates on written SOURCE, not units — this is the execution-fidelity check.)

- [ ] **Step 1:** Fixture `bad/`: 5 model files with `branch_id` + `use BranchScoped` but missing `addGlobalScope(new BranchScoped`. Assert validator flags 5.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement validator (reads pack `registration_signature`).
- [ ] **Step 4:** Fixture flags 5; `good/` (registered) → PASS.
- [ ] **Step 4b:** tradefinance cross-check vs pre-`2bdfc1b` tree → flags 5; vs `2bdfc1b` → PASS.
- [ ] **Step 5:** Wire PostToolUse (model-file globs from pack file-location) + PreToolUse Branch 7. execute-bolts post-flight prose: scan each fanned-out sibling, not once. Bump version.
- [ ] **Step 6:** Commit `feat(exec): per-sibling post-flight cross-cutting registration scan`

---

## Task D: Render-test-per-module gate  *(execution+gate)*

**Files:**
- Modify: `references/unit-schema.md` (add `render` to `acceptance_test` kinds), `_template.md`/`laravel.md` (`## Test patterns.detail_view_render`)
- Modify: `validate-unit-spec.sh` (parse `acceptance_test`; require ≥1 `render` for units with detail-view target_files; route FAIL to block)
- Modify: `generate-units/SKILL.md` (Step 9), `execute-bolts/SKILL.md` (emit the render test)
- Test: `tests/fixtures/code-delivery/render-test/{good,bad}/`

**Pack section (laravel):**
```yaml
## Test patterns
  detail_view_render:
    template: |
      $m = {Model}::factory()->create();
      $this->get(route('{resource}.show', $m))->assertOk()->assertSee((string) $m->{display_field});
    test_glob: tests/Feature/**/*Test.php
```

**Validator delta:** in `validate-unit-spec.sh`, when a unit's `target_files` include a detail view (pack `view_glob` show-view), require an `acceptance_test` entry with `kind: render`; absent → issue `render_test_missing`. Route this issue into a blocker (so it bites) — write to `.unit-spec-state.json` and add a PreToolUse read (or reuse Branch 5/6 family on execute-bolts).

- [ ] **Step 1:** Fixture `bad/`: a unit with a `show.blade.php` target and no `render` acceptance_test. Assert validator flags `render_test_missing`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Add `render` to unit-schema enum + pack `Test patterns`; extend `validate-unit-spec.sh` to parse acceptance_test + emit the issue.
- [ ] **Step 4:** Fixture flags it; `good/` (has render test) → PASS.
- [ ] **Step 4b:** tradefinance cross-check: current module units lack render tests → flagged.
- [ ] **Step 5:** Route the FAIL to block execute-bolts (extend existing unit-spec wiring or Branch family). generate-units Step 9 + execute-bolts emission prose. Bump versions.
- [ ] **Step 6:** Commit `feat(gate): require detail-view render test per view-bearing unit`

---

## Task E: UI scaffold-tells quality gate  *(gate)*

**Files:**
- Create: `validate-ui-quality.sh` → `.ui-quality-blockers.json`
- Modify: `_template.md` (+`## UI quality signatures`), `laravel-base-26.md` (Vuexy scaffold tells + required elements)
- Modify: `pre-tool-use` (Branch 8: block execute-bolts on FAIL), `post-tool-use` (Style-A dispatch on view-file Write/Edit), `execute-bolts/SKILL.md` (positive UI obligations in dispatch contract — defense-in-depth)
- Test: `tests/fixtures/code-delivery/ui-quality/{good,bad}/`

**Pack section (laravel-base-26):**
```yaml
## UI quality signatures
  view_glob: 'resources/views/**/*.blade.php'
  scaffold_tells:
    - id: title-is-controller
      regex: "@section\\('title',\\s*'[^']*Controller"
      message: "Page title leaks the Controller class name (raw scaffold)"
    - id: label-is-column-id
      regex: ">\\s*[A-Z][a-z]+ Id\\s*<"
      message: "Field label is a Str::title(column) like 'Customer Id' (humanize/relabel)"
    - id: raw-uuid-fk
      regex: "\\{\\{\\s*\\$[a-zA-Z_]+->[a-z_]+_id\\s*(\\?\\?|\\}\\})"
      message: "Foreign key rendered as raw id; resolve to a human label via the relation"
    - id: money-without-format
      regex: "\\{\\{\\s*\\$[a-zA-Z_]+->(amount|total|price|balance)\\s*(\\?\\?|\\}\\})"
      message: "Money field printed without number_format/currency"
    - id: native-alert
      regex: "\\b(alert|confirm|prompt)\\s*\\("
      message: "Native JS dialog instead of the project notification idiom (e.g. SweetAlert)"
  required_elements:
    - id: layout-extends
      regex: "@extends\\(|x-(app-)?layout|<x-layouts"
      message: "View does not extend the app layout"
    - id: responsive
      regex: "\\b(col-(sm|md|lg|xl)-|row\\b)"
      message: "No responsive grid classes"
```

**Validator** (`.ui-quality-blockers.json`): SKIP if no `UI quality signatures`. For each touched view file (pack `view_glob`): FAIL if any `scaffold_tells.regex` matches; FAIL if a non-trivial view (>N lines) is missing any `required_elements.regex`. Emit `violations[{file,id,message,line}]`.

- [ ] **Step 1:** Fixture `bad/`: a Blade view with `@section('title','LetterOfCreditController List')`, `>Customer Id<`, `{{ $model->customer_id ?? '-' }}`, `{{ $model->amount ?? '-' }}`. Assert validator flags all 4 tells.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Pack section + implement validator (clone starterkit-conformance file-scan shape).
- [ ] **Step 4:** Fixture flags 4 tells; `good/` (humanized labels, resolved FKs, number_format, layout+responsive) → PASS.
- [ ] **Step 4b:** tradefinance cross-check: `git show bf950ef:resources/views/letter-of-credit/show.blade.php` piped to validator → flags; `git show a07704a:...` → passes. (Use a temp file; never write into the repo.)
- [ ] **Step 5:** PostToolUse Style-A dispatch (view globs) + PreToolUse Branch 8. execute-bolts dispatch-contract positive UI obligations. Bump version.
- [ ] **Step 6:** Commit `feat(gate): UI scaffold-tells quality gate (pack-declared signatures, 5th emit_block)`

---

## Task F: UI design-contract + design-token enrichment + frontend-design inject + UI few-shot  *(enrichment)*

**Files:**
- Modify: `execute-bolts/SKILL.md` (un-exclude `design_tokens` at :260; add view/component category to the Iter-76 code-slice; inject frontend-design heuristics text for `ui_ux` units)
- Modify: `generate-units/SKILL.md` (attach UI contract — label map / FK→display / formatting / required states — to view-bearing units, grounded in vault flows+design-system)
- Modify: `scan-codebase/SKILL.md` + `references/codebase-map-schema.md` (add `view`/`component` pattern category; `exemplar_selection: linter-clean`)
- Create: `validate-dispatch-prompt.sh` → `.dispatch-prompt-state.json` (assert a `ui_ux` unit's emitted dispatch-prompt.md carries design tokens + a view exemplar)
- Modify: `post-tool-use` (dispatch on `bolts/**/dispatch-prompt.md` Write)
- Create: `plugins/mega-sdd/references/ui-design-heuristics.md` — the stack-agnostic design-quality guidance text injected for UI units (the frontend-design bridge as INJECTED CONTEXT, not a Skill-invoke)
- Test: `tests/fixtures/code-delivery/dispatch-prompt/{good,bad}/`

- [ ] **Step 1:** Fixture `bad/`: a `ui_ux` unit dispatch-prompt.md missing tokens + exemplar. Assert `validate-dispatch-prompt.sh` flags `tokens_not_injected` + `exemplar_missing`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Edit `execute-bolts/SKILL.md:260` to INCLUDE `design_tokens` in the `ui_ux` slice (within the ≤8KB T2 budget, add to truncation cascade as a mid-priority item, NOT first-dropped); add view/component category to the code-slice loop (currently controller-only at ~:347); add the `ui-design-heuristics.md` injection for `ui_ux` units. Add the `view`/`component` pattern category to scan-codebase + schema with `exemplar_selection: linter-clean`. Add generate-units UI-contract attachment for view-bearing units. Implement `validate-dispatch-prompt.sh`.
- [ ] **Step 4:** Fixture flags; `good/` (tokens + exemplar present) → PASS.
- [ ] **Step 5:** PostToolUse dispatch on dispatch-prompt.md. Bump versions (execute-bolts, generate-units, scan-codebase).
- [ ] **Step 6:** Commit `feat(enrich): inject design tokens + UI exemplar few-shot + frontend-design heuristics for UI units`

---

## Task G: Operator-workflow-UX capture + Design-Source OQ  *(capture)*

**Files:**
- Modify: `generate-intent/SKILL.md` (detect maker-checker/workflow flow pattern → model operator surface: worklist/inbox, decision affordance, human state labels, audit timeline as first-class requirements grounded in flows; emit Design-Source OQ when UI components exist but design-system flags all false — DO NOT relax the anti-hallucination rail)
- Modify: `validate-vault-oqs.sh` (if vault has a workflow/maker-checker flow but no operator-surface requirement AND no Design-Source OQ → FAIL)
- Modify: `references/vault-contract.md` (document the operator-surface + Design-Source OQ rule)
- Test: `tests/fixtures/code-delivery/operator-ux/{good,bad}/`

- [ ] **Step 1:** Fixture `bad/`: a vault `04-flows.md` with a multi-stage approval flow, no inbox/decision/timeline requirement in `02-architecture`, no Design-Source OQ in `vault.json`. Assert validator flags `operator_surface_missing`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Extend `validate-vault-oqs.sh` (detect workflow flow signal; require operator-surface req or OQ). generate-intent prose: capture operator surface + emit Design-Source OQ. vault-contract.md doc.
- [ ] **Step 4:** Fixture flags; `good/` (has inbox/decision/timeline reqs OR a Design-Source OQ) → PASS.
- [ ] **Step 4b:** tradefinance cross-check: the Phase-2 vault has workflow flows but no operator surface/OQ → flagged.
- [ ] **Step 5:** Bump generate-intent version.
- [ ] **Step 6:** Commit `feat(capture): model operator-workflow UX + Design-Source OQ (anti-halu preserved)`

---

## Task H: Integration + release

- [ ] **Step 1:** Run ALL `tests/fixtures/code-delivery/**/verify.sh` → all PASS (each validator flags its bad/ + passes its good/).
- [ ] **Step 2:** Run `tests/skill-triggering/` + existing `tests/hooks/` smoke (ensure no regression in pre-tool-use/post-tool-use parsing; the new branches don't break existing ones).
- [ ] **Step 3:** `bash plugins/mega-sdd/hooks/pre-tool-use < <(echo a sample Skill payload)` sanity for each new branch (PASS state → no block; FAIL state → block JSON).
- [ ] **Step 4:** Bump `plugin.json` version (MINOR→ new gates) + update `CHANGELOG.md` referencing the spec; update `plugins/mega-sdd/CLAUDE.md` Fork-A recovery map (these new validators are shipped [HOOK-VALIDATE] slices).
- [ ] **Step 5:** Commit `chore(release): bump version + CHANGELOG for code-delivery sharpening`

---

## Self-review notes
- **Spec coverage:** A↔§3 Slice A; B↔B; C↔C; D↔D; E↔E; F↔F; G↔G; pack schema ↔ §2; Fork-A boundary ↔ §1.6; verification ↔ §4. No gap.
- **Anti-hallucination guard:** G adds an OQ, never a defaulted value (spec §5). F injects only SOURCED tokens/exemplars (from starterkit-context.yaml / real component files), never invented.
- **Tech-agnostic guard:** every validator SKIPs when its pack section is absent; all stack signatures live in packs. Laravel fills are proven against the fixture; a new stack = a new pack.
