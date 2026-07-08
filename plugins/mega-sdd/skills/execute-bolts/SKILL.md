---
name: execute-bolts
version: 2.19.0
description: Executes one or more units into code commits (bolts). Bridges to superpowers (executing-plans, subagent-driven-development, test-driven-development) with a vendored fallback. Runs a Hard Rule pre-flight + post-flight scan that validates each unit's `## Hard rules` against codebase state and HALTS the run on any violation. Use when the user says "execute bolts", "run units", "implement units", "jalanin unit", "eksekusi bolt", or paraphrases.
---

# Execute-Bolts

The terminal phase of the SDD pipeline — turns units into code. It is also an anti-hallucination gate: every unit's `## Hard rules` are validated against the real codebase before and after the bolt. **Commit topology (one truth):** the `bolt-implementer` subagent commits after its tests pass; the controller's L0 gates, review panel, and post-flight Hard-rule scan run **after that commit** (detect-after). A violation therefore never claims the code is "uncommitted" — it records the failure (`postflight.json` / halt YAML), blocks further bolts via the PreToolUse gates, and the remediation is fix-forward or revert of the flagged commit.

**Announce at start:** "I'm using the execute-bolts skill to implement units via the mega-sdd bolt agents (parallel review panel)."

> **Instruction language:** this skill reasons in English. Code, commit messages, and provenance trailers are emitted verbatim against the codebase.

## When to use

- After `generate-units` wrote `<vault>/units/U-*.md`.
- User explicit: `/mega-sdd:execute-bolts <unit-id>` or `--all`.
- `orchestrate-flow` auto-routes here once units are ready.

## Inputs

- Unit path OR unit ID OR `--all` (positional).
- **Flags:**
  - `--parallel` — the main-thread controller dispatches independent units concurrently (multiple `bolt-implementer` Agent calls in one message), each still running the review panel. **Overlap rail:** before dispatch, pairwise-compare the batch's `target_files`; units whose whitelists INTERSECT are never in the same parallel wave — they serialize (silent data race on a shared file is worse than slower execution). Depth-1: the controller never forks a sub-controller (`subagent-driven-development` is an optional technique hint, not a nested dispatch).
  - `--worktree` — isolate each bolt in a git worktree.
  - `--max-retries=N` — default 3.
  - `--dry-run` — walk steps, do not commit.
  - `--force` — re-execute completed units / proceed on a dirty tree.
  - `--auto` — non-interactive (emit handoff YAML; participate in the memory layer).
  - `--per-squad` — fan out across all squads in `_meta/squads.yaml`. The main-thread controller runs each squad's units (filtered by its `squad:` field) through the per-unit panel flow, parallelizing independent units across squads via concurrent `bolt-implementer` dispatch (depth-1; NO squad subagent — see `references/squad-subagent.md`).
  - `--review-panel=minimal|standard|full|auto` — force the review-panel tier; default `auto` (risk-based selection per `references/review-panel.md`). Forcing `minimal` on a unit with risk signals logs a warning in the bolt-report — never silent.
  - `--no-code-gates` — skip the L0 toolchain + SAST gates for this run (logged in the bolt-report). The secret scan and new-dep existence check ALWAYS run — no flag disables them (per `references/code-gates.md`).
  - `--no-full-suite` — **DISCOURAGED** escape hatch that skips the batch-completion full-suite gate for THIS run (broken/absent project test command only). Logged in `_summary.md` + handoff `notes.full_suite_skipped: true`; the PreToolUse gate still blocks the next run until a green `_batch-suite.json` covers the newest code commit — never silent.
  - `--squad=<id>` — filter units to one squad (human-team handoff). Halts on `cross_squad_interface_draft` if a consumed interface is still draft.
  - `--module=<id>` — filter units to one module (per `generate-units/references/modules-schema.md`); topo-sort within module. Halts on `module_blocked_by` if a prerequisite module is incomplete.
  - `--hard-rule-grammar=v1|v2` — force the Hard-rule grammar; default `auto` (detect from YAML presence under `## Hard rules`).
  - `--no-pbt` — skip Property-Based Testing validation (example-test-only behaviour).
  - `--no-empty-commits` — skip the bolt-report-only commit for `task_type: verify` units with no changes (per the verify-unit special path).
  - `--no-drift-check` — opt out of the end-of-chain detect-drift auto-gate (per `references/halts-and-handoff.md` / `../orchestrate-flow/references/chain-execution.md`).
  - `--resume` — resume a partially-completed bolt from `<vault>/bolts/U-XXX/partial-state.json` (forward-only from `current_step`).
  - `--rollback <unit-id-or-vault-path>` — saga compensating actions: replay `rollback_hints[]` in reverse to undo a crashed bolt.
  - `--memory-off` — disable memory reads + writes.
- **Unit selection (living-vault lifecycle):** units with `status: superseded` are SKIPPED with a one-line warning (claim no longer exists); units with `status: stale` are ELIGIBLE for re-execution (treated as not-yet-completed — the sync lane's "stale/new units only" semantics). Absent `status` = legacy behavior unchanged.
  - `--force-skip-postflight` — **DISCOURAGED** escape hatch that skips the ast-grep Hard Rule **postflight** validation for THIS run only. Use only when the ast-grep binary is broken or a known false-positive pattern blocks otherwise-valid work; document the reason in the bolt-report self-assessment. It does **NOT** downgrade the rail — BLOCKING remains BLOCKING per the plugin's "no bypassing anti-hallucination" rule. Any use is logged in the handoff YAML `notes.postflight_skipped: true` and surfaces in `<vault>/bolts/_summary.md`; a follow-up bolt re-run WITHOUT the flag is required before drift-detect / merge.

> ⚠️ **Anti-bypass policy.** `--force-skip-postflight` exists for operational continuity (broken tool / known false-positive), NOT to ship code that fails Hard Rules; BLOCKING remains BLOCKING and any use is logged in the handoff YAML + `_summary.md`. Repeated unauthorized use is treated as a constitution violation (§B Security) per `../bind-codebase/references/constitution-and-oq.md`.

## Pre-flight checks (skeleton)

Each check below can HALT before any code is written. Snapshot formats, grammar detail, and full halt YAMLs → `references/hard-rule-scan.md`.

1. **Superpowers bridge.** Detect per `references/superpowers-bridge.md`: real install → plugin namespace; else vendored fallback in `_vendored/`; else **halt `dep_missing`** with install instructions (the dispatch fails closed when neither executing-plans / subagent-driven-development / test-driven-development is available).
2. **Unit validity.** For each target unit: frontmatter parses + matches `unit-schema.md`; `target_files` non-empty (EXCEPT `task_type: verify`, which requires empty / `operation: none`); `acceptance_test` has ≥1 `type: test` entry; `depends_on` references resolve (no dangling). A `task_type: verify` unit with any `target_files` carrying `operation: create | modify | delete` → **halt `verify_unit_writable`** (verify units are read-only — verified, never written).
3. **Repo state.** Working tree clean (or `--force`). Bolts produce commits, so a dirty tree could lose work. Each bolt is an **atomic commit** with a provenance trailer (see the per-unit procedure). Repo mid-rebase/merge → STOP: resolve the git state first. Probe worktree-safely via `git rev-parse --git-path rebase-merge` / `--git-path MERGE_HEAD` (in a linked worktree `.git` is a FILE and the state lives under `.git/worktrees/<name>/` — never test the literal `.git/...` path).
3.5. **Test framework present.** Probe the manifest/lockfile for the project's test runner (phpunit/pest, jest/vitest, pytest, go test, cargo test, rspec/minitest — per the detected ecosystem). Absent → **halt `dep_missing`** naming the runner + install command. NEVER proceed by fabricating "green" tests against a runner that doesn't exist — TDD without a runner is fiction.
3.6. **Commit-path expectations.** If the repo has client-side commit hooks (probe `$(git rev-parse --git-path hooks)/pre-commit` — worktree-safe — plus husky/lefthook config) note it; when a bolt's commit is REJECTED by such a hook → **halt `commit_rejected_by_hook`** with the hook output verbatim — never retry with `--no-verify` (forbidden plugin-wide). `commit.gpgsign=true` and signing fails → same halt shape, cause `commit_signing_unavailable`.
4. **Hard Rule pre-flight scan.** For each unit with a non-empty `## Hard rules` section, detect grammar (YAML blocks → v2 ast-grep; bulleted lines → v1; **mixed → halt `hard_rule_mixed_grammar`**), validate each rule (**unparseable → halt `hard_rule_unparseable`**, NEVER silently skip a rule), and capture a deterministic pre-flight snapshot to `<vault>/bolts/U-XXX/preflight.json` for the post-flight diff. v2 grammar with no ast-grep on PATH → **halt `dep_missing`**; a `SIGNATURE_RULE` referencing a symbol absent from the codebase-map → **halt `hard_rule_unanchored`** (cannot validate what doesn't exist). Grammar table, snapshot JSON, and halt YAMLs → `references/hard-rule-scan.md`.
5. **PBT citation pre-flight.** When a unit has a non-empty `properties:` field, each `properties[].cites` must resolve to a real vault section / entity / constitution clause → else **halt `pbt_citation_invalid`**. Full PBT flow → `references/halt-recovery.md` (load only when a halt fires or a `properties:` unit is batched).

## Procedure (per unit)

Follows `references/superpowers-bridge.md` per-unit flow — the default executor is the first-class **`mega-sdd:bolt-implementer`** agent, followed by the **L0 code gates** (deterministic floor: repo-own format/lint/typecheck, secret scan, SAST, new-dep existence — per `references/code-gates.md`; `secret_in_code` / `sast_critical_finding` / `dep_not_found` **halt before the panel**), then the **review panel**: a risk-tiered set of read-only lenses (**spec-reviewer**, **code-quality-reviewer**, **security-reviewer**, **standards-reviewer**) dispatched **in parallel and blind** with the L0 results in each prompt, merged in the controller per `references/review-panel.md` (spec ❌ or any Critical → re-dispatch within the retry cap). Superpowers technique skills are an optional enhancement, vendored fallback otherwise. Gate steps in **bold**:

0. **Create the bolt artifact dir — deterministic, FIRST.** Run `mkdir -p <vault>/bolts/U-XXX/` as the literal first action for the unit, **before** pre-flight/dispatch. The folder MUST exist even for an empty-`## Hard rules` unit, a `task_type: verify` unit, an early pre-flight halt, or a `--auto`/`--parallel` run — do NOT rely on a later file-write to auto-create it (that is the prose-only gap that drops the folder when the controller is terse). Every per-unit artifact (`preflight.json`, `dispatch-prompt.md`, `bolt-report.md`) is written into this dir; the `bolt-implementer` agent writes code/tests/commit, NOT this dir — the controller owns it.
1. **Pre-flight: parse + snapshot Hard rules** (per Pre-flight check 4).
2. **Build the tiered dispatch prompt** (Step 4.5 below) and dispatch the first-class **`mega-sdd:bolt-implementer`** agent — it implements the unit into `target_files` (whitelisted), writes + runs the acceptance test **failing-first** (TDD, via the vendored `test-driven-development` technique when present), and **commits the bolt** (`feat(U-XXX): …` carrying the `Unit:` + `SDD-PROVENANCE:` trailers per `references/bolt-contract.md`). **This commit is the antecedent for every detect-after gate below** — L0, the panel, and post-flight all run against the landed commit, never a working-tree preview.
   - **2.5 — Positive UI obligations (defense-in-depth).** When a `target_files` path is a view file (matches the active framework pack `## UI quality signatures` → `view_glob`), the generated view MUST be fit for a human operator, not a raw scaffold dump: no `scaffold_tells` (human page title, humanized labels, foreign keys resolved to the related record's label, money formatted, project notification idiom instead of native `alert`/`confirm`), and every `required_element` (extend the app layout, responsive grid that works at 375px and desktop). This prose is defense-in-depth — `validate-ui-quality.sh` runs PostToolUse on every view write and the PreToolUse ui-quality gate blocks the next `execute-bolts` on a scaffold tell / missing element. Packs with no `## UI quality signatures` section are exempt (gate SKIPs).
   - **Render-test emission (defense-in-depth).** If the unit ships a detail/show view (matches pack `## Test patterns` → `detail_view_glob`), the implementer emits the `type: render` acceptance_test from the pack `detail_view_render` template (factory-create the model, GET the detail route, assert 200 AND assert a real display field renders — not a bare route-200 smoke test). The unit's render acceptance_test (authored by generate-units) is the contract. Defense-in-depth — `validate-unit-spec.sh` (`render_test_missing`) + the PreToolUse render-test gate already block any view-bearing unit lacking it.
3. **L0 code gates** (deterministic floor: repo-own format/lint/typecheck, secret scan, SAST, new-dep existence — per `references/code-gates.md`) run against the landed commit; `secret_in_code` / `sast_critical_finding` / `dep_not_found` **halt before the panel**.
4. **Review panel** — the risk-tiered read-only lenses (spec-reviewer, code-quality-reviewer, security-reviewer, standards-reviewer, + design-reviewer for UI units) dispatched **in parallel and blind** with the L0 results in each prompt, merged in the controller per `references/review-panel.md`; spec ❌ or any Critical → re-dispatch within the retry cap (cap exhausted → **halt `review_critical_unresolved`**).
5. **Post-flight: re-validate Hard rules against the just-committed bolt** (detect-after — the implementer already committed; gate below), then write `bolt-report.md` into the Step 0 dir — frontmatter MUST include `target_hashes:` (sha256 per target file, computed from the just-committed content; the living-vault staleness anchor per `references/halts-and-handoff.md §Outputs detail`). **MANDATORY:** a completed unit with no `<vault>/bolts/U-XXX/bolt-report.md` is invalid — the Stop-hook handoff validator halts `bolt_artifacts_missing` when an `emitted_by: execute-bolts` `status: completed` handoff lists no `bolts/` artifact.

### Step 4.5 — Tiered context enrichment per bolt

Per `references/bolt-dispatch-prompt.md` (template) + `references/context-enrichment.md` (assembly logic). Total dispatch prompt budget ≤9KB target, **hard cap 12KB → halt `dispatch_prompt_too_large`** (a progressive T2 budget tracker truncates disposable sections first; the halt fires only when non-truncatable `constitution_clauses` alone exceed budget).

- **TIER 1 (always, ≤2KB):** unit body, halt vocabulary, self-assessment template, **atomic commit discipline reminder, anti-context block, provenance trailer template**, and an acceptance-test-provenance NOTE when the test was weakly authored, the reuse-index path (always) + reuse_candidates hint.
- **TIER 2 (conditional, ≤10KB, budget-tracked):** depends_on summaries, framework pack rules (glob-filtered), constitution clauses, KB anti-patterns, historical memory, the **starterkit context slice** + §patterns + reference code exemplar (auto-injected per unit per `starterkit_relevance`; emits `deep_scan_cache_corrupt` soft halt on a corrupt cache; machinery → `references/starterkit-enrichment.md`, loaded ONLY when `.mega-sdd/codebase/starterkit-context.yaml` exists), confidence labels, validation hints, the reuse slice (filtered reuse-index entries). Section-priority truncation cascade (constitution clauses NEVER dropped) → `references/context-enrichment.md`.
- **TIER 3 (reference-only):** full upstream reports, constitution, KB files, memory, framework pack — read on demand, never embedded.
- The assembled prompt is written to `<vault>/bolts/U-XXX/dispatch-prompt.md` for provenance. **Anti-halu rails:** every T2 inclusion cites its source; the anti-context block is populated from real data (never invented); self-assessment confidence is numeric `0.0–1.0`; a provenance trailer is MANDATORY in every modified file (post-flight verifies it — missing → **halt `provenance_missing`**).

### Post-flight Hard Rule validation (the safety net — gate)

After the implementer reports DONE (its commit already landed — see the commit topology above), run the post-flight scan via **`scripts/run-postflight-scan.sh --cwd=<root> --unit=U-XXX`** — the deterministic writer that executes each rule in the unit's `## Hard rules` against real git/filesystem state (v2: `ast-grep scan` — any match against a forbidden pattern = VIOLATED; v1: per-rule commit-touch / dep-diff / naming / signature / presence checks; framework-pack rules validate identically and surface `framework_pack_source`) and records `<vault>/bolts/U-XXX/postflight.json` itself. The artifact is hook-guarded against direct writes and the common programmatic write paths — a hand-written postflight.json is rejected as a forged verdict (best-effort deny; see the B1 threat note below). Per-rule mechanics + snapshot formats → `references/hard-rule-scan.md`.

**Violation handling — HALT (detect-after).** ANY rule violated → emit the `hard_rule_violated` blocker YAML (violated_rule + evidence), write `bolt-report.md` with `status: halted_postflight` listing violations, and STOP the run. The violating code is already **committed** (the implementer commits before the scan) — the honest remediation is: fix the code forward (or `git revert` the bolt commit), then re-run `run-postflight-scan.sh` so a passing artifact is recorded; the B1 gate blocks every further `execute-bolts` until then. `--force-skip-postflight` does not change this contract; it only skips the ast-grep step for one run and is logged per the anti-bypass policy above.

After the post-flight scan passes (or a confirmed fix is applied), and **before the unit is accepted as done**, a per-bolt lightweight drift check compares each modified `target_file` to the vault's expected state; drift on a LOCKED entity → **halt `bolt_introduces_locked_drift`** (pure-pause; override-only — NEVER propose-and-confirm: the fix-proposer template refuses LOCKED files by contract); drift on INTENT/ARTIFACT → logged + continue. Detail → `references/batch-and-fanout.md`.

### Self-assessment + provenance gate

Every `bolt-report.md` MUST carry a `bolt_self_report` YAML block (numeric `confidence`, certain/uncertain decisions, retry history) → missing → **halt `self_assessment_missing`**. Post-flight also verifies the provenance trailer in every modified file → missing → **halt `provenance_missing`**. `bolt_self_report` and the trailer format → `references/halts-and-handoff.md`.

**Post-flight evidence is enforced, not prose (B1).** A committed `create`/`extend` bolt whose unit has a non-empty `## Hard rules` MUST carry `<vault>/bolts/U-XXX/postflight.json` (`status: pass`; every `rules[].verdict: pass`, or `attested` for `directive`-typed rules) — written by `scripts/run-postflight-scan.sh` and hook-guarded against direct writes plus the common programmatic write paths (redirect/tee/cp/mv, python open-for-write / `write_text`, `dd of=`, `install`). The Stop hook AND the execute-bolts gate itself re-run `validate-bolt-artifacts.sh --postflight-scan`; the PreToolUse aggregator blocks the next `execute-bolts` with **`postflight_evidence_missing`** if a Hard-rule bolt committed with no passing postflight evidence — the scan can no longer be silently skipped or satisfied by a naive hand-written artifact. The validator reads the unit's content **at the bolt commit** (`git show`), so retroactively blanking `## Hard rules` or flipping `task_type` cannot erase the obligation. (Verify units are exempt — they skip post-flight.) **Threat note (honest):** unlike the re-derived gate STATES (overwritten from ground truth at the gate), the gate *reads* this artifact's recorded status rather than recomputing the scan — so the guard against forgery is the hook's best-effort write-verb deny, NOT a cryptographic guarantee. A filesystem-owning agent using an unenumerated write verb is out of the moat's drift/shortcut threat model; recompute-the-scan-at-gate is the durable hardening (backlog).

### verify-unit special path

`task_type: verify` units run a simplified flow: pre-flight asserts `target_files` is empty / all `operation: none` (else **halt `verify_unit_writable`**); skip `executing-plans`; run acceptance tests; skip the post-flight Hard-rule scan (no changes to validate); commit only the bolt-report (or skip the commit on `--no-empty-commits`).

## Batch + fan-out execution

`--all` (topo-sort by `depends_on`; sequential, or `--parallel` groups independent units; **any failure halts the whole run, no skip-ahead**), `--per-squad`, `--squad=<id>`, and `--module=<id>` each have a procedure, plus the per-bolt drift check. Squad fan-out, module gating, the `cross_squad_interface_draft` / `module_blocked_by` halts, and the parallel parent-thread post-flight re-scan → `references/batch-and-fanout.md`.

### Batch completion — final full-suite gate (the safety net for cross-bolt regressions)

**After the last committed code-bearing bolt of the invocation** (single OR batch — a lone bolt can break a sibling), run the project's **FULL** test suite — the runner detected at pre-flight check 3.5, **with NO per-unit scope filter** — exactly once, and write `<vault>/bolts/_batch-suite.json` (`status: green|red`, counts, `head_sha`, `units[]`, `bypass_commits[]`). This is the safety net the scoped per-bolt acceptance tests cannot provide: a later bolt (or an out-of-band edit) silently breaking an earlier bolt's contract only shows up when the *whole* suite runs.

- **RED → halt `batch_suite_red`**: the batch is NOT complete; emit the blocker with the failing test names; leave the tree for review (do not auto-revert); do not emit a `status: completed` handoff.
- **Out-of-band bypass guard:** before the verdict, scan commits in the **batch window only** (from the invocation's base SHA — recorded at batch start — to HEAD, **excluding** this run's own bolt commits) for any commit that touched a unit's `target_files` yet carries no `SDD-PROVENANCE` trailer; record them in `_batch-suite.json.bypass_commits[]` and surface in `_summary.md`. A non-empty list forces the suite to run even on an otherwise-skippable invocation. Bound to the window — an unscoped `git log` would flag every pre-SDD commit.
- **Skipped only for:** `--dry-run`, a run that committed zero code (verify-only / all-skipped → no gate required), or `--no-full-suite` (DISCOURAGED escape hatch — logged in `_summary.md` + handoff `notes.full_suite_skipped: true`, never silent).
- **Enforcement (not prose):** the Stop hook runs `validate-bolt-artifacts.sh --batch-suite-gate` each turn end; the PreToolUse aggregator **blocks the next `execute-bolts`** when no green `_batch-suite.json` covers the newest code commit — a bolt OR an out-of-band edit (`batch_suite_gate_missing`) — or the recorded suite is RED (`batch_suite_red`). The hook VERIFIES the artifact; it never runs the suite. Procedure detail → `references/batch-and-fanout.md`; design → `docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md`.

## Partial-state, resume + saga rollback

A crashed bolt writes `<vault>/bolts/U-XXX/partial-state.json` (v2.0 schema: `current_step`, `files_modified[]`, `rollback_hints[]`). `--resume` re-executes forward-only from `current_step` (3 partial attempts → **halt `bolt_repeated_partial_failure`**); a corrupt or malformed-hints file → **halt `partial_state_corrupt`** (rename aside, then re-run). `--rollback` replays `rollback_hints[]` in reverse with per-action confirmation (default safe for non-idempotent ops). Schema, step-type taxonomy, resume integrity checks, and the rollback flow → `references/partial-state-and-saga.md`.

## Halt protocol + propose-and-confirm

Always emit a blocker YAML on halt (per `references/bolt-contract.md`). Exhausted acceptance-test retries → `test_fail`; a stale consumed interface → `cross_squad_interface_draft`; the batch-completion full suite ends RED → `batch_suite_red` (and the PreToolUse gate blocks the next run with `batch_suite_red` / `batch_suite_gate_missing` until a green `_batch-suite.json` covers the newest code commit). Eligible halts (`test_fail`, `hard_rule_violated`, `pbt_property_violated`) may dispatch an AI fix-proposer (propose-and-confirm UX) per `references/propose-and-confirm-prompt.md`; structural / business / config halts always pure-pause. Full halt YAMLs, the eligibility table, the propose-and-confirm dispatch contract + config override, the new-halt-types table, and the Property-Based Testing flow → `references/halt-recovery.md` — load it ONLY when a halt actually fires (or a `properties:` unit is in the batch); the blocker envelope + the canonical bolt-halt enum stay in `references/halts-and-handoff.md`.

## Anti-hallucination rails

- `target_files` whitelist enforced at THREE layers: the dispatch prompt forbids out-of-whitelist writes (rules tier), the review panel checks scope (judgment tier), and the **deterministic B3 whitelist observer** (`validate-bolt-artifacts.sh --whitelist-scan`, Stop-hook + gate-time) diffs each bolted unit's COMMITTED paths against `target_files` ∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, test files) — escaped paths block the next `execute-bolts` with `whitelist_violation`. Existing interfaces preserved (verified by tests).
- No auto-bypass of pre-commit hooks; no `--force` commits or pushes to remote.
- An OQ in a unit body → prompt the user before the bolt finalizes.
- The **Hard Rule pre-flight snapshot is mandatory** when `## Hard rules` is non-empty — NEVER skip it to save time. **Post-flight validation is detect-after (the implementer's commit already landed): violations halt the run, gate every further bolt, and the remediation is fix-forward or revert of the flagged commit** — never a claim that the code is uncommitted. Unparseable rules halt at pre-flight — NEVER silently skip a rule whose grammar isn't recognized.
- There is no `--skip-preflight` flag; the pre-flight scan is the contract. Memory consultation NEVER bypasses pre/post-flight Hard-rule validation.
- Starterkit slice constraints are honoring obligations: when the T2 starterkit section is present, the bolt MUST extend the named layout, use the named notification lib, and use only the listed libs (violations rejected at post-flight).

## Outputs

Per unit: a `<vault>/bolts/U-XXX/` dir (created deterministically at Procedure Step 0 — MANDATORY, one per executed unit); code commit(s) on the current branch (skipped for `task_type: verify` with no changes); `bolt-report.md` (MANDATORY); `preflight.json` + `postflight.json` (Hard-rule snapshots/results for audit, when `## Hard rules` is non-empty). Per batch: a single `<vault>/bolts/_batch-suite.json` (full-suite gate result — written once after the last code-bearing bolt). Global: a `bolt_completed` entry appended to `<vault>/vault.json` changelog. When `vault.json` carries a `scope`, the bolt-report header includes `scope` / `scope_name` for multi-squad traceability. Compact streaming progress + the aggregate `<vault>/bolts/_summary.md` format → `references/halts-and-handoff.md`.

## Hand-off

After the last unit: suggest `/mega-sdd:detect-drift` to verify the bolts honored the vault; show a summary (N done, M failed, P skipped). Under `--auto`, emit the handoff YAML (artifacts one-line-per-bolt with NO range shorthand; `starterkit_context` + `metrics` incl. `acceptance_test_concerns`; conditional `scope:` block) and participate in the memory layer. End-of-chain phase advancement (multi-phase rebuild), the full handoff YAML schema, and the memory-layer read/write tables → `references/halts-and-handoff.md`.

## Specialist references (load on demand)

- `references/superpowers-bridge.md` — dispatch order (first-class `agents/` by default; superpowers optional), the review-panel per-unit flow, whitelist enforcement, bolt-report schema.
- `references/review-panel.md` — the parallel blind lens panel: tier selection (risk signals), blind dispatch protocol, merge + severity gate, cost notes.
- `references/code-gates.md` — L0 deterministic floor: toolchain detection (detect-never-impose), secret/SAST/new-dep gates + their halt YAMLs, blocking-vs-advisory split, panel injection, `code_gates:` config.
- `references/hard-rule-scan.md` — Hard Rule pre/post-flight: grammar detection (v1/v2), snapshot + `preflight.json` formats, per-rule post-flight checks, cross-cutting-registration + parent-thread re-scan, and the `hard_rule_*` / `verify_unit_writable` halt YAMLs.
- `references/hard-rule-grammar-v2.md` — the v2 (ast-grep YAML) Hard-rule grammar + installation guidance.
- `references/context-enrichment.md` — Step 4.5 tiered prompt assembly: T1/T2/T3 contents, the T2 budget tracker + truncation cascade, the reuse slice, the Map §6 fallback, and the Design slice (greenfield pipe).
- `references/starterkit-enrichment.md` — the starterkit-slice read/build/§patterns/code-slice/inject machinery + slice truncation order; load ONLY when `<project>/.mega-sdd/codebase/starterkit-context.yaml` exists (absent → skip; the Map §6 fallback in `context-enrichment.md` applies).
- `references/bolt-dispatch-prompt.md` — the canonical bolt-subagent dispatch prompt template (T1/T2/T3 sections the assembly populates).
- `references/partial-state-and-saga.md` — partial-state v2.0 schema, step-type taxonomy, `--resume` integrity checks, `partial_state_corrupt` halt, and the `--rollback` saga flow.
- `references/batch-and-fanout.md` — `--all` / `--per-squad` / `--squad` / `--module` procedures, per-bolt drift check, and the `cross_squad_interface_draft` / `module_blocked_by` halts.
- `references/squad-subagent.md` — per-squad main-thread fan-out protocol (filter + consolidation; depth-1, no squad subagent).
- `references/propose-and-confirm-prompt.md` — the AI fix-proposer subagent prompt template.
- `references/halts-and-handoff.md` — halt protocol (blocker envelope), streaming + `_summary.md` formats, outputs detail, handoff YAML + the canonical bolt-halt enum + end-of-chain phasing, and the memory layer.
- `references/halt-recovery.md` — full halt YAMLs (`test_fail`, `review_critical_unresolved`), propose-and-confirm UX + config, new-halt-types table, and the Property-Based Testing flow; load ONLY when a halt fires or a `properties:` unit is batched.
- `references/bolt-contract.md` — bolt failure modes + the canonical blocker YAML envelope.

## Related skills

Units come from `generate-units` (unit schema, modules schema, PBT integration, adversarial-test provenance). Bridges to superpowers `executing-plans` / `subagent-driven-development` / `test-driven-development`. Halt envelope + handoff template: `references/halts-and-handoff.md` (operative; base schema + routing index in `../orchestrate-flow/references/handoff-contract.md`). The anti-bypass policy cites the bind-codebase constitution clauses. After a clean batch the detect-drift auto-gate runs (DEFAULT-ON in the chain; `--no-drift-check` opts out per `references/halts-and-handoff.md`); standalone runs can invoke `/mega-sdd:detect-drift` manually.
