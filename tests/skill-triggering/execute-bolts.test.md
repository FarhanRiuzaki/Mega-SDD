# execute-bolts Trigger Test

## Trigger cases

### E1: Explicit unit ID
- **Prompt:** `/mega-sdd:execute-bolts U-001`
- **Expect:** Skill invoked

### E2: --all
- **Prompt:** `/mega-sdd:execute-bolts --all`
- **Expect:** Skill invoked with topo-sort over all units

### E3: Indonesian
- **Prompt:** `jalanin unit semua`
- **Expect:** Skill invoked

## Pre-flight checks

### P1: No superpowers installed (v7.4.0 — no vendored fallback exists)
- **Setup:** uninstall superpowers
- **Expect:** the default run uses the built-in inline loop (`references/inline-run.md` (c)); under `--agents` dispatch proceeds on the first-class agents; NO halt, NO install demand

### P2: Superpowers installed
- **Setup:** real install present
- **Expect:** implementer may use its technique skills; dispatch path unchanged (first-class agents)

## Behavior

Mode: the default run is inline (BI1, BI2, BI4); BI3, BJ1, BH0, BH4–BH8, AC1–AC4 and EB-SK* exercise the per-unit path and run with `--agents` (dispatch-shaping flags do nothing without it).

### BJ1: JIT bind at pre-flight 3.9 (`--agents`) — the CONFLICT gate closes per unit
- **Setup:** a wave of U-003 + U-004 (U-005 `depends_on: [U-004]`); U-004's `## Claims` expects `POST /api/orders` to use Bearer auth, the code uses session cookies
- **Expect:**
  - `derive-unit-claims.sh --units=U-003,U-004` (ONE call per wave) → `write-unit-binding.sh` per unit (the sole writer) → `bolts/U-003/binding.json` + `bolts/U-004/binding.json`; a wave with zero symbol/text claims is reported as costing zero model tokens
  - `validate-handoff-binding-units.sh --units=…` drops `conflict_unresolved` for U-004 → halt `binding_conflict` (ALWAYS STOP for U-004; one-screen shape: the claim, the code reality with `file:line`, KEEP_VAULT / KEEP_CODE / SPLIT)
  - U-003 proceeds; U-005 is skipped with the reason; no verdict is ever hand-written and `binding.json` is never edited (hook-guarded)
  - the PreToolUse gate re-runs the validator with `--units=U-004` on any `bolt-implementer` dispatch — a hand dispatch cannot bypass it
  - resolution via `resolve-oq --binding` (`write-unit-binding.sh --resolve=<claim-id>=<ACTION> --by=user`)

### BI1: the default run executes every unit in this session from a generated plan
- **Setup:** a layout-3 vault with U-001..U-004; U-003 has an open CONFLICT, U-004 `depends_on: [U-003]`
- **Prompt:** `/mega-sdd --guarded` (forwarded as `execute-bolts --all --lite`); `/mega-sdd --guarded --inline` (forwarded as `execute-bolts --all --lite --inline`) behaves identically — `--inline` is a no-op alias
- **Expect:**
  - the announce line ends with `mega-sdd-trace:execute-bolts`
  - `derive-exec-plan.sh --pending` → `rebind-units.sh --units=<pending>` → `derive-exec-plan.sh`: U-003 `binding_conflict`, U-004 `depends_on_quarantined` in ONE `Karantina:` chat line; the plan names U-001, U-002 only
  - no `bolt-implementer` dispatch, no panel; each task re-binds (a CONFLICT there → `write-unit-quarantine.sh`, dependents skipped, the run continues), tests first, commits with the canonical trailers, then commits its evidence (`chore(sdd): evidence U-XXX`)
  - ONE blind review of `run_base..HEAD` (no `.mega-sdd/` in its package, the trace line on its own line), `delivery-check.sh` `VERDICT: PASS`, the run-boundary gate with `--conflict-bypass-scan` exits 0 before the result contract

### BI2: the inline run never launders a CONFLICT
- **Setup:** as BI1, the model commits U-003 anyway, then re-binds it (the commit created the file the CONFLICT claimed)
- **Expect:** the run-boundary gate FAILS `closed_conflict` for U-003 (and U-004 via U-003 if committed); the result is never reported done; the remedy offered is `resolve-oq --binding` (the human decides the closed episode) — never another re-bind

### BI3: `--agents` keeps the per-unit path
- **Prompt:** `/mega-sdd --guarded --agents` (forwarded as `execute-bolts --all --lite --agents`)
- **Expect:** pre-flight 3.9 JIT bind per wave, one `bolt-implementer` dispatch per unit + the risk-tiered review panel (BJ1, BH0 apply); no `_exec-plan-*.md` is written. `--agents --inline` together → a one-line usage error, nothing runs

### BI4: the close re-binds a leftover own_wip CONFLICT
- **Setup:** a resumed run: U-011's own test file was untracked with its provenance header at the task's re-bind (CONFLICT `own_wip`); the unit then committed and finished its evidence
- **Expect:** (d)6 `derive-exec-plan.sh --rebind-wip` (before the run evidence commit) prints `rebound: ["U-011"]`, U-011's binding re-reads CONFIRMED and the `chore(sdd): evidence run` commit carries it, so the (d)7 gate sees it; (d)8 `--retire` then re-binds nothing. Had that re-bind left another CONFLICT, `--rebind-wip` exits 1 (`scope: close`) naming it, a `Close: halt` ledger line keeps it named, `--retire` refuses too and nothing is retired — the human decides it via `resolve-oq --binding`; re-invoking `execute-bolts` resumes at (d)4 (`Close: reviewed`), never a second review
- **`--dry-run`:** the plan is shown, then `--retire --dry-run` removes it and re-binds nothing

### BH0: BOLTS gate deny → 3.9b (state anchor, 8.8.0)
- **Setup:** a lite wave already bound at 3.9; before the next dispatch a teammate commit lands in U-002's anchored file
- **Expect:** the `bolt-implementer` dispatch is DENIED `binding_stale` naming the path; the controller runs `rebind-units.sh --units=U-002` (3.9b), rebuilds `dispatch-prompt.md` with `build-dispatch-prompt.sh`, and re-dispatches — it never edits `binding.json`, never runs `git stash`, and a second deny at the same HEAD (`rebind_exhausted`) goes to quarantine, not to another 3.9b

### BH1: target_files whitelist enforced
- **Setup:** unit has `target_files: [src/foo.ts]`; implementation step tries to edit `src/bar.ts`
- **Expect:** halt before write

### BH2: Test failure → retry → halt
- **Setup:** unit with always-failing test
- **Expect:** 3 retries, then halt + bolt-report with failure details

### BH3: --dry-run does not commit
- **Setup:** any valid unit
- **Prompt:** `/mega-sdd:execute-bolts U-001 --dry-run`
- **Expect:** procedure walks; no `git commit` calls; bolt-report still written marked status=preview

### BH4 (v1.1+): --per-squad requires multi-squad config
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:** halt with informative message: `--per-squad` requires ≥2 squads in `_meta/squads.yaml` (a migrated multi-squad vault — `plan` never authors one); suggest plain `execute-bolts --all`

### BH5 (v1.1+): --per-squad runs every squad from the main thread
- **Setup:** migrated vault with 3 declared squads, units assigned across squads (e.g., 4 BE + 3 FE + 2 integrations)
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:**
  - NO squad-level subagent: the controller stays in the main thread and walks each squad's units through the per-unit panel flow directly (depth-1 — `references/batch-and-fanout.md §--per-squad` + `references/squad-subagent.md`); only `bolt-implementer` / review-lens agents are dispatched, one per unit / lens
  - Independent units from different squads dispatch concurrently, bounded by `parallel_max`
  - The controller consolidates the report into a per-squad table after all units complete (N squads, M units, K commits, halts with squad attribution)

### BH6 (v1.1+): --squad=<id> filters and runs single squad
- **Setup:** vault with 3 squads; user runs on their FE laptop
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** only units where `squad: squad-fe-web` execute; BE and integrations units skipped; bolts written only for FE units

### BH7 (v1.1+): --squad=<id> halts on draft consumed interface
- **Setup:** FE unit U-FE-002 declares `consumes_interfaces: [api-x]`; `interfaces/api-x.md` has `status: draft`
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** halt with `cross_squad_interface_draft` blocker; next_action names producer squad

### BH8 (v1.1+): --per-squad combined with --parallel
- **Setup:** vault with 2 squads; each has internally independent units
- **Prompt:** `/mega-sdd:execute-bolts --per-squad --parallel`
- **Expect:** still no squad-level subagent — the main-thread loop dispatches independent units (across BOTH squads) concurrently as `bolt-implementer` agents in one message, bounded by `parallel_max` (independent = no `depends_on` edge AND pairwise-disjoint `target_files`); no resource collision (different working sets); the report is one consolidated per-squad table

## Hard Rule pre-flight + post-flight (v1.2+, Iter 3)

### HR1: Pre-flight snapshot persisted
- **Setup:** unit U-001 has `## Hard rules` with 2 rules: `DO NOT modify src/Models/User.php` + `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`
- **Expect:**
  - Pre-flight runs before bolt execution
  - `<vault>/bolts/U-001/preflight.json` exists with sha256 of User.php + signature snapshot of authenticateUser
  - Bolt proceeds to executing-plans

### HR2: Hard rule violated — DO_NOT_MODIFY
- **Setup:** unit U-002 has `DO NOT modify src/Models/User.php`; bolt's implementation steps modify User.php
- **Expect:**
  - Pre-flight snapshot captured (sha256 = X)
  - executing-plans runs, modifies User.php
  - acceptance tests pass
  - Post-flight: new sha256 ≠ snapshot
  - HALT with `hard_rule_violated` blocker YAML
  - Detect-after: the bolt commit already landed; the B1 gate blocks every further `execute-bolts` until fixed-forward or reverted (code is NOT left uncommitted)
  - bolt-report.md has `status: halted_postflight` with violation list

### HR3: Hard rule violated — DO_NOT_ADD_DEPS
- **Setup:** unit U-003 has `DO NOT add new package.json dependencies`; bolt adds a new dependency to package.json
- **Expect:** post-flight diff detects new top-level dep entry; HALT with `hard_rule_violated`; violation evidence quotes added entry

### HR4: Hard rule violated — SIGNATURE_RULE
- **Setup:** unit U-004 has `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`; bolt modifies the function to add a `twoFactor?: string` parameter
- **Expect:** signature re-extract shows extra param; HALT with violation evidence quoting old vs new signature

### HR5: Hard rule violated — FILE_PRESENCE_RULE
- **Setup:** unit U-005 has `file src/Models/AuditLog.php MUST exist after bolt`; bolt forgets to create the file (or deletes it)
- **Expect:** post-flight probe shows file missing; HALT with violation

### HR6: Hard rule violated — NAMING_RULE
- **Setup:** unit U-006 has `file:src/api/*.ts MUST follow kebab-case naming`; bolt creates `src/api/auditLog.ts` (camelCase)
- **Expect:** post-flight scans new files matching glob; auditLog.ts fails kebab-case regex; HALT with violation listing the file

### HR7: Hard rule unparseable → halt at pre-flight
- **Setup:** unit U-007 has `## Hard rules` with an unrecognized rule: `forbid users from x`
- **Expect:** pre-flight halts BEFORE bolt execution with `hard_rule_unparseable` listing the offending line + the 5 expected grammar productions

### HR8: Hard rule unanchored — function not in tracked source
- **Setup:** unit U-008 has `function doesNotExist MUST preserve signature: () => void`; no tracked source file defines a symbol with that name
- **Expect:** pre-flight halts with `hard_rule_unanchored`; rule references a symbol that can't be snapshotted

### HR9: Verify-unit special path
- **Setup:** unit U-009 with `task_type: verify`, empty target_files, Anchors cite existing implementation, acceptance_test runs existing test suite
- **Expect:**
  - Pre-flight passes (no Hard rules required for verify; if present, parsed normally)
  - Skip executing-plans (no code to write)
  - Run acceptance tests
  - Skip post-flight Hard rule scan
  - Commit only bolt-report.md (or skip commit on `--no-empty-commits`)

### HR10: All clean — bolt proceeds normally
- **Setup:** unit U-010 has Hard rules; bolt's implementation respects all rules
- **Expect:**
  - Pre-flight snapshot taken
  - executing-plans runs
  - acceptance tests pass
  - Post-flight: all rules clean (snapshot matches / new files conform / file presence verified)
  - Commit proceeds
  - postflight.json shows all rules `status: passed`

### HR11: Multiple rules, one violated → halt
- **Setup:** unit U-011 has 3 Hard rules; bolt violates one
- **Expect:** post-flight detects 1 violation; HALT with `hard_rule_violated` listing all 3 rules in evidence (passed + failed); bolt-report.md captures per-rule status

## Attempt cap — the retry budget is hook-enforced (v2.53.0+)

### AC1: the budget is persisted at dispatch, never counted by the controller
- **Setup:** `execute-bolts U-003 --max-retries=2`
- **Expect:** the router call forwards the flag — `resolve-review-tier.sh --unit … --write --max-retries=2` — and `bolts/U-003/review-tier.json` carries `retry_budget: 2`, `retry_budget_source: flag`. The controller keeps NO attempt counter of its own and never writes `attempts.json`.

### AC2: `gate: "halt"` from the merge script ends the loop before a doomed dispatch
- **Setup:** fix round 2 of 2 just merged; a Critical is still open; `merge-panel-findings.sh` prints `"budget_left":0,"gate":"halt"`
- **Expect:** NO further `bolt-implementer` dispatch is built; the controller writes the `review_critical_unresolved` halt YAML (`retries_attempted` = `attempts.json` `dispatches` − 1) + the bolt-report `## Review panel` section and stops the unit (quarantine when the halt class allows).

### AC3: the hook denies a dispatch past the budget — the controller does not retry it
- **Setup:** a controller that lost count after a compaction dispatches a 4th implementer for a unit with `retry_budget: 2`
- **Expect:** PreToolUse DENIES (`attempt-cap` … `review_critical_unresolved`, reason names count / budget / source / open finding ids + keterangan). The controller treats it as the terminal halt — it never re-dispatches, never edits `attempts.json` / `review-tier.json` (both are in the anti-self-bypass set), and tells the user the reset is theirs (delete `attempts.json`, or raise `max_retries:`).

### AC4: lane lite + `unit_tier: xs` → budget 1
- **Expect:** `retry_budget: 1`, `retry_budget_source: xs-lite` — one verifier round, then quarantine; an explicit `--max-retries=N` on the run still wins.

## Pass criteria

All triggers fire, pre-flight gates behave, the JIT bind verdicts every unit by script and an open CONFLICT closes only its own unit (BJ1), whitelist + retry/halt protocol works. The retry budget is a mechanism (AC1-AC4): the hook counts, the controller never does. Hard Rule pre/post-flight (HR1-HR11) follows §4 (pre-flight) + §Post-flight Hard Rule validation. Violations NEVER silent — post-flight is detect-after (the bolt commit already landed): the run HALTS, the B1 gate blocks every further `execute-bolts` until the flagged commit is fixed-forward or reverted.

---

## Iter 32 — Starterkit slice injection cases (v2.7.0+)

Legacy cache only: `.mega-sdd/codebase/starterkit-context.yaml` was written by the pre-9.0 deep scan and has no 9.0 producer, and `starterkit_relevance` was stamped by the pre-9.0 unit generator (`plan` does not write it). The builder still reads an existing file; absent → the slice is skipped entirely.

### EB-SK1 — T2.3 slice injection: UI-touching unit gets ui_ux + libs slices

**Setup:**
- Unit U-007 has `target_files: ["resources/views/users/index.blade.php", "app/Http/Controllers/UserController.php"]`
- Unit frontmatter: `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` exists from a pre-9.0 scan (`auth.lib: sanctum`, `ui_ux.layout_extends: layouts.app`, `ui_ux.notification_lib: sweetalert2`, libs incl. sweetalert2)

**Trigger:** `/mega-sdd:execute-bolts U-007`

**Expected:**
- Step 4.5.b-starterkit (Read): starterkit-context.yaml loaded; `unit.starterkit_relevance` read as `[ui_ux, libs]`
- Step 4.5.b-starterkit (Build slice): slice built with:
  - `slice.ui_ux` populated (layout_extends, notification_lib, idioms)
  - `slice.libs` filtered to libs whose usage_hint overlaps target_files
  - `slice.auth` ABSENT (not in starterkit_relevance)
  - `slice.rbac` ABSENT
- Step 4.5.b-starterkit (Inject): bolt-dispatch-prompt T2.3 section populated with:
  - "UI/UX: extends=layouts.app, notification=sweetalert2, idioms=[use document.addEventListener...; responsive mobile-first...]"
  - "Libs in scope: sweetalert2@11.x (used in: resources/js/app.js, ...)"
  - NO "Auth:" line
  - NO "RBAC:" line
- T2.3 slice size ≤2KB (verify via byte count of injected section)
- Bolt subagent dispatched with prompt containing T2.3 section
- Bolt's generated code (verified via post-flight) uses `@extends('layouts.app')` and `Swal.fire(...)` patterns (matches starterkit)

### EB-SK2 — Slice exceeds 2KB budget → truncation order applies → halt if still over

**Setup:**
- Unit U-008 with `starterkit_relevance: [ui_ux, libs]`
- `.mega-sdd/codebase/starterkit-context.yaml` has:
  - ui_ux.idioms: 20 entries (large)
  - libs[]: 100 entries, 60 of which overlap U-008's target_files

**Trigger:** `/mega-sdd:execute-bolts U-008`

**Expected:**
- Step 4.5.b-starterkit (Build slice): initial slice exceeds 2KB
- Truncation step 1: libs[] truncated to top 10 by relevance score (overlap count)
- If still >2KB: idioms[] truncated to top 3
- IF still >2KB: halt `dispatch_prompt_too_large` (existing Iter 30 halt) emitted; bolt NOT dispatched; chain stops
- IF ≤2KB after truncation: bolt dispatched with truncated slice; T2.3 section ≤2KB
- Truncation event logged in execute-bolts metrics: `slice_truncated_count: 1`, `slice_truncation_levels: [libs, idioms]`
