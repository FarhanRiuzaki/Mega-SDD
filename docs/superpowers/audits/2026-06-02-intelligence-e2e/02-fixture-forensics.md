# Fixture Forensics — mega-sdd reasoning failures (new-tradefinance-import, Phase 2)

**Date:** 2026-06-02
**Fixture (READ-ONLY):** `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/new-tradefinance-import`
**Method:** reproduced each failure from the fixture's `.mega-sdd/` artifacts + the human *repair commits* (each repair = an intelligence gap the pipeline should have caught). Every finding carries `enforceable: Y/N` and a verdict on whether an **existing Iter-78 gate** already covers it — and, critically, whether it would have caught **THIS fixture's specific defect** prospectively (at decomposition/gate time, before the human repair).

**Framing (Fork A):** only Claude Code hooks + deterministic validator scripts enforce anything; SKILL.md prose can be silently no-op'd. So for each gap the operative question is: *what OUTPUT SIGNATURE in an artifact reveals it, and can a deterministic validator detect that signature?*

The 6 Phase-2 workflow modules are structurally analogous siblings: Import LC issuance (U-026, the exemplar), Document Examination (U-027), LC Amendment (U-028), Payment Settlement (U-029), Counter-Balance (U-030), Reverse Amendment (U-031). LC issuance is consistently the best-served ("the survivor"); the divergence repairs land on the other five.

---

## Failure #1 — Fan-out divergence ("LC is always the survivor")

**Reproduced evidence**
- **4e0b485** `fix(controllers): rename show() params to match Route::resource URI segments` — 5 non-LC `show()` methods used param names (`$amendment`, `$examination`, `$payment`, `$event`, `$reversal`) that did NOT match the route URI segment, so Laravel injected an *empty* model. Every field rendered `—`, the workflow decision card showed "No transitions configured for state ." **LC alone survived** because `$letterOfCredit` matched `{letter_of_credit}` via camelCase — a coincidence, not a decision.
- **2bdfc1b** `register BranchScoped global scope on 5 Phase 2 LC models` — 5 sibling models carried `branch_id` and the scope rules existed, but the bolt never added `addGlobalScope(new BranchScoped)` in `booted()`. Silent cross-branch authorization leak. LC (U-017, the exemplar) had it.
- **abe8d9b** `add missing branch() relation to 3 Phase 2 models` — 3 siblings stored `branch_id` but never declared the `belongsTo(Branch)` accessor the show views dereference. LC + Amendment + Reverse were complete.
- **af49ede** `close inbox coverage gap for amendment + doc_exam` — amendment + doc_exam never created `workflow_assignments` rows, so they were invisible in the cross-module Approval Inbox. LC + payment surfaced correctly. (See NEW finding for the deeper concern.)

**Responsible phase:** `execute-bolts` (per-sibling fidelity drift) — the exemplar U-026 was implemented richly; the sibling bolts dropped cross-cutting obligations the exemplar carried. Decomposition (`generate-units`) is the upstream enabler: it never declared the shared obligations on the sibling units, so each bolt re-derived them independently and diverged.

**Root-cause reasoning gap:** when work fans out across structurally-analogous siblings, the pipeline has no notion of "what the exemplar does, every sibling must do the same way." Cross-cutting concerns (branch scope, FK relation accessor, the read endpoint) collapse toward the one well-served entity; the rest get under-served with no reasoning that explains the divergence.

**Enforceable output-signature:** (a) group units by structural analogy (`module`/`scope`); for each cross-cutting concern whose `applies_when` matches, assert every sibling declares the same `spec_obligation` (decomposition); (b) scan generated source — a model carrying the column but missing the `registration_signature` is a divergence (execution).

`enforceable: Y`

**Existing Iter-78 gate?** YES — `validate-sibling-consistency.sh` (slice B, decomposition) + `validate-cross-cutting-registration.sh` (slice C, execution). Both packs cite these exact commits.
**Would it have caught THIS defect?**
- **2bdfc1b: YES.** Slice C is **schema-driven** — `applies_when has_column:branch_id` is evaluated against the *migrations*, not the model spec. The 5 models whose tables carry `branch_id` but whose source lacks `addGlobalScope(new BranchScoped)` are flagged independently of what the unit specs say. This is the cleanest prospective catch.
- **abe8d9b: NO (by slice B), CONDITIONAL (by slice D).** Slice B's `relation_derivation` is **spec-driven** — it fires only when a unit *declares* the FK column. Verified: the workflow units U-026–U-031 do NOT declare `branch_id` (it appears only in master-data units U-023/24/25), so slice B's relation check never triggers on them. The catch falls to slice D — but abe8d9b is the WEAK member of the render-test catch. Unlike 4e0b485 (empty model → *every* field renders '—' → any assertion fails), abe8d9b is null-safe (`$model->branch?->name` → only the *branch* field renders '—', other fields render fine). So slice D catches abe8d9b **iff the render test's `display_field` is the branch relation**; if the unit's render test asserts a non-branch field, abe8d9b slips BOTH slice B and slice D. Note the contrast with 2bdfc1b: slice C is schema-driven so it DOES fire independently of any spec. (The laravel pack §Test patterns note lumps all three commits as render-test catches; abe8d9b is the optimistic member.)
- **4e0b485: YES, indirectly (slice D).** No route-binding-specific check exists, but laravel.md §Test patterns names 4e0b485 as a render-test catch: the empty-model injection makes `assertSee($m->{display_field})` fail. See Failure #2.

---

## Failure #2 — Module-altitude decomposition (units at the wrong altitude)

**Reproduced evidence**
- **cdde29d** `write 8 missing per-stage Form Requests` — 8 controller transition methods accepted bare `Illuminate\Http\Request`. The modules were decomposed as ONE unit per 6-stage workflow (U-026 = "Import LC Issuance module (6-stage flow)"), so per-stage validation obligations stayed *implicit inside one coarse unit* and were silently dropped. Sibling stages that happened to get a dedicated FR were inconsistent with those that didn't.
- **The read/detail endpoint was never decomposed at all.** Grep across every Phase-2 unit spec: **no unit mentions `show()`**. The units enumerate transition methods (`store`/`spvReview`/`craApprove`/`dispatchSwift`…) and list `show.blade.php` among target files, but the `show()` controller method — its param name, its eager-loads — has no spec home. The bolt improvised it per-module → directly produced 4e0b485 (empty-model show) and abe8d9b (un-eager-loaded `branch`).
- **Systematic LOC under-sizing.** U-026/U-027 declare `loc_budget: 350`/`320`; the U-027 bolt-report ships **~470 LOC**. Consistent under-estimation is an altitude-misjudgment tell — the unit is carrying more sub-artifacts than its altitude acknowledges.

**Responsible phase:** `generate-units`.

**Root-cause reasoning gap:** decomposition operates at *module* altitude, not *endpoint/stage* altitude. A 6-stage maker-checker module enumerates more input-accepting transition steps (each needing its own Form Request) and more endpoints (the read/show detail view) than the single coarse "module" unit makes explicit. Sub-artifacts that have no unit to live in get dropped or improvised.

**Enforceable output-signature:** (a) parse each flow into per-step blocks; every input-accepting transition step must derive its required artifact (one Form Request per action) and be covered by some unit's target-files (flow→artifact coverage); (b) every view-bearing unit that ships a `show.blade.php` must declare a structured detail-view render test (factory-create model → GET show route → assert 200 → assert a real display field renders).

`enforceable: Y`

**Existing Iter-78 gate?** PARTIALLY.
- Per-stage Form Request gap (**cdde29d**): covered by `validate-flow-coverage.sh` (slice A). The laravel pack's §Flow-artifact derivation cites this exact defect (8 missing FRs); its `endpoint_kinds.flow_signal` regex matches submit/review/approve/confirm/dispatch/apply/finalize/enrich and requires one Form Request per action. **Would catch THIS defect: YES** prospectively.
- Read/show endpoint absence + LOC under-sizing: covered by `validate-unit-spec.sh` slice D (`render_test_missing`). Verified two ways: (1) U-026–U-031 each list `show.blade.php` in target files but **none declares a show render test** — slice D flags all six prospectively; (2) the PreToolUse hook **Branch 6** (`hooks/pre-tool-use` lines 366–387) BLOCKS `execute-bolts` filtered precisely on `halt_type == 'render_test_missing'` — i.e. it is opted into the blocking filter per the Iter-78.1 EXTENSION-gate invariant, not advisory. The render test is what actually surfaces 4e0b485 at gate time (and abe8d9b conditionally). **Would catch 4e0b485: YES (blocking, confirmed).**
- **GAP that remains:** no gate reasons about *altitude itself* — i.e. "this unit is too coarse; split the 6-stage module into stage-level units." The current gates catch the *symptoms* (missing FR, missing render test) but not the root altitude misjudgment. A LOC-budget-vs-flow-step-count ratio check ("unit covers N input steps but declares one budget/one test surface") could flag coarse units directly. `enforceable: Y` (new, see recommendations) — but the symptom gates already neutralize the observed damage, so this is lower priority.

---

## Failure #3 — UI coin-flip (clean UI vs raw scaffold, no explaining reason)

**Reproduced evidence**
- **a07704a** `Phase 2 module UI/UX polish (QW1-QW6)` — humanized 24 views: removed `*Controller` page titles, relabeled `Customer Id`→`Customer`, resolved raw FK echoes, formatted money, dropped native `alert()/confirm()`. The pre-polish blob (bf950ef, the LC `show.blade.php`) shipped `>Customer Id<` / `>Branch Id<` labels, raw `{{ $model->customer_id ?? '-' }}` FK echoes, unformatted `{{ $model->amount }}`, and native `alert(...)` — i.e. even the exemplar shipped raw scaffold until hand-polished.
- **Smoking gun — the bolt self-reported it.** U-027 bolt-report: *"resources/views/lc-document-examination/{index,create,edit,show}.blade.php — scaffold kept; UI polish deferred."* The bolt agent KNEW it shipped raw scaffold and said so in plain text — and the pipeline accepted the commit anyway. There was no gate between "bolt admits raw scaffold" and "commit lands."

**Responsible phase:** `execute-bolts` (ships unpolished scaffold) — but the deeper gap is the *absence of a gate* that reads generated view files. The divergence has no reasoning behind it: whether a view got polished was a coin-flip on bolt diligence, not a decision.

**Root-cause reasoning gap:** there was zero deterministic UI quality signal. "UI is responsive/polished" lived only as prose in unit specs (`Blade views MUST be responsive`), which the bolt can no-op. No artifact-level check distinguished a clean view from `make:controller-acl` scaffold output.

**Enforceable output-signature:** scan generated view files for raw-scaffold "tells" (title-is-controller, label-is-column-id, raw-uuid-fk, money-without-format, native-alert) and for required elements on non-trivial views. Any tell match = FAIL.

`enforceable: Y`

**Existing Iter-78 gate?** YES — `validate-ui-quality.sh` (slice E). The laravel pack's §UI quality signatures declares exactly these 5 tells and cites bf950ef→a07704a as the proving delta.
**Would it have caught THIS defect: YES.** The five tells are derived directly from the bf950ef LC show blob; the U-027 "scaffold kept" views would trip `title-is-controller` + `label-is-column-id` + `raw-uuid-fk`. This is the strongest existing coverage of the three known failures.

---

## NEW reasoning failure found in the fixture — Shared side-effect parity (the Approval-Inbox gap)

**Reproduced evidence: af49ede** `close inbox coverage gap for amendment + doc_exam`.
The cross-module Approval Inbox surfaces work by reading `workflow_assignments` rows. Two of four modules created **zero** assignment rows, so their items were invisible:
- **amendment (CRITICAL):** `lc_amendments` never had a `branch_id` column → `WorkflowEngine::transition()` resolved `branch_id=null` → `advanceAssignments()` silently skipped the insert (its gate requires `branchId !== null`). An amendment sat at Forward2 with a transition row but ZERO assignment rows — invisible.
- **doc_exam (CRITICAL):** its `store()` intentionally fired no `engine.transition()` (the row is born at Forward1) → `advanceAssignments()` was never invoked → no assignment row written.

**Why this is distinct from Failure #1:** the inbox-surfacing side-effect (`workflow_assignments` write) IS a declared flow step — `04-flows.md` §line 380: *"Update workflow_assignments (current_state, assigned_to_role for next stage)"* — and the vault DOES model an operator worklist (so `validate-vault-oqs.sh` slice's operator-surface check passes). But the side-effect is a **shared cross-cutting obligation that fires inside transition handlers**, and each module wired it (or failed to) independently. It is neither a "concern-on-a-column" (slice B/C only know branch-scoping) nor a missing endpoint (slice A). It's a *shared-mechanism parity* gap: "every workflow module's create/transition path must produce the inbox-surfacing artifact the same way."

**Responsible phase:** `generate-units` (no unit declares the assignment-row obligation as a shared concern) → manifested in `execute-bolts` (per-module divergence: LC/payment wired it, amendment/doc_exam did not).

**Root-cause reasoning gap:** the pipeline reasons about per-unit artifacts but not about *shared runtime side-effects that must hold uniformly across a sibling set*. The inbox is a fan-out consumer; if one producer drops the row, the consumer silently under-serves — the same collapse-toward-survivor shape as Failure #1, but on a runtime side-effect rather than a static declaration.

**Enforceable output-signature:** the existing `cross_cutting_concerns` schema can express this WITHOUT a new validator. Add a concern, e.g.:
```yaml
- concern: inbox-surfacing
  applies_when: 'flow_step:Update workflow_assignments'   # or has_column on a workflow table
  spec_obligation: '\bworkflow_assignments\b'             # unit must name the side-effect (slice B)
  registration_signature: 'workflow_assignments|advanceAssignments'  # source must write it (slice C)
  registration_target_glob: 'app/Http/Controllers/**/*.php'
  registration_source_glob: 'app/**/WorkflowEngine.php'
```
Slice B would then assert every workflow-module unit declares the assignment-row obligation; slice C would assert each module's transition path actually writes it. NO new validator needed — only a pack-declared concern.

`enforceable: Y` (reuses existing slice-B/C machinery; the gap is a *missing pack concern declaration*, not a missing gate).

**Existing Iter-78 gate?** NO concern covers it today. The laravel pack declares exactly ONE cross-cutting concern (`branch-scoping`); `validate-vault-oqs` only checks the operator surface *exists in the vault*, not that each module *populates* it. So af49ede is currently uncovered by any gate — but closeable by a one-concern pack addition, no validator code change.

---

## Summary table

| # | Failure | Phase | Repair commit(s) | enforceable | Existing Iter-78 gate | Catches THIS defect? |
|---|---|---|---|---|---|---|
| 1 | Fan-out divergence | execute-bolts (+ generate-units) | 4e0b485, 2bdfc1b, abe8d9b | Y | sibling-consistency (B) + cross-cutting-registration (C) | 2bdfc1b YES (C, schema-driven, blocks); 4e0b485 YES (D, blocking confirmed via Branch 6); abe8d9b CONDITIONAL (B won't fire/spec-driven; D catches only if render test's display_field is branch-derived) |
| 2 | Module-altitude decomposition | generate-units | cdde29d, (show absent) | Y | flow-coverage (A) + render-test via unit-spec (D) | cdde29d YES (A); show/branch YES (D); altitude-ratio gap remains |
| 3 | UI coin-flip | execute-bolts | a07704a (bf950ef baseline) | Y | ui-quality (E) | YES — strongest coverage |
| NEW | Shared side-effect parity (inbox) | generate-units → execute-bolts | af49ede | Y (reuse B/C via new pack concern) | NONE today | NO — closeable by 1 pack concern, no new validator |

## Recommendations (priority order, no new validator scripts)
1. **Add `inbox-surfacing` cross-cutting concern to the laravel pack** (NEW finding) — reuses slice B + C; zero validator code. Highest leverage: closes a CRITICAL silent-invisibility class with one YAML block.
2. **CONFIRMED (no action needed): slice D blocks.** Verified the PreToolUse hook Branch 6 (`hooks/pre-tool-use` lines 366–387) gates `execute-bolts` on `halt_type == 'render_test_missing'` — opted into the blocking filter per the Iter-78.1 EXTENSION-gate invariant. It is the load-bearing (and blocking) catch for 4e0b485. **Residual risk to close:** the render-test template asserts ONE `display_field`; to also catch abe8d9b (null-safe branch '—'), the pack's `detail_view_render` template should assert a *relation-derived* field (e.g. `$m->branch->name`) on units that carry an FK, not just a scalar — otherwise abe8d9b slips both B and D.
3. **(Lower priority) altitude-ratio check** in `generate-units` / a decomposition gate: flag a unit that covers N input-accepting flow steps but declares a single coarse loc_budget / one test surface — catches the root altitude misjudgment directly rather than its symptoms.
