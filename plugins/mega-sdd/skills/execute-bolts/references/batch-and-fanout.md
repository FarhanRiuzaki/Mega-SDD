# execute-bolts — Batch + fan-out execution

Procedures for executing more than one unit: `--all`, `--per-squad`, `--squad=<id>`, `--module=<id>`, plus the per-bolt lightweight drift check.

## Contents
- `--all`
- `--per-squad`
- `--module=<id>` + `module_blocked_by` halt
- `--squad=<id>` + `cross_squad_interface_draft` halt
- Per-bolt lightweight drift check
- Batch completion — final full-suite gate (B2)

## `--all`

1. Topologically sort units by `depends_on`.
2. Execute in order (default sequential).
3. On `--parallel`: the **main-thread controller** groups units with no shared dependency and dispatches them **concurrently** — multiple `bolt-implementer` Agent calls in one message — each unit still running the full review panel (`bolt-implementer` → the parallel blind lenses per `review-panel.md`). This is **depth-1** (the controller stays in the main thread; it never forks a sub-controller that would then need to dispatch the bolt agents — that would be depth-2, which the runtime forbids). `subagent-driven-development` is an optional *technique* hint, not a nested dispatch.
4. On any failure: halt the entire `--all` run (no skip-ahead).

## `--per-squad`

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with an informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `/mega-sdd:generate-intent` to add squad config, or use plain `/mega-sdd:execute-bolts --all` for single-squad."
2. **Read the squad list.** Build a list of declared squad IDs.
3. **Main-thread squad loop (NOT a squad subagent).** The controller stays in the main thread and runs each squad's units through the per-unit panel flow directly (depth-1) — see `squad-subagent.md`. A forked squad subagent would have to dispatch the bolt agents = depth-2 (forbidden) and would silently lose the review panel.
4. **Parallelize across squads.** Independent units — including units from different squads — are dispatched **concurrently** (multiple `bolt-implementer` Agent calls in one message), bounded by an in-flight cap. Same mechanism as `--all --parallel`; `--per-squad` only changes the filter + the consolidation.
5. **Consolidate the report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

## `--module=<id>` + `module_blocked_by` halt

1. **Load `_meta/modules.yaml`.** If absent BUT `_meta/modules.yaml.auto` exists → instruct: "review `_meta/modules.yaml.auto` and promote it: `mv _meta/modules.yaml.auto _meta/modules.yaml`". If neither exists → halt: "`--module=` requires `_meta/modules.yaml`. Run `/mega-sdd:generate-units` (Step 4.5 auto-derives `modules.yaml.auto`), review, then promote it."
2. **Validate `<id>` exists** in declared modules.
3. **Check blocked_by**: for each `blocked_by` entry, verify that module is `status: completed` (per memory). Incomplete → halt `module_blocked_by` listing pending prerequisites.
4. **Filter units**: working set = units where `module: <id>` AND not yet completed.
5. **Topologically sort** within the module by `depends_on`.
6. **Proceed** with sequential or `--parallel` execution on the filtered set.
7. **After all units complete**: probe the module's DoD checklist (`modules.yaml.modules[<id>].dod`). Surface incomplete DoD items in chat; the user marks them via `/mega-sdd:list-modules --mark-dod=<module>` or edits modules.yaml manually.

```yaml
blocker:
  type: module_blocked_by
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    requested_module: M-leave-mgmt
    blocked_by_modules: [M-auth]
    blocker_status: M-auth has 2/5 units complete
  next_action: "Complete the prerequisite module first via /mega-sdd:execute-bolts --module=M-auth"
```

## `--squad=<id>` + `cross_squad_interface_draft` halt

1. **Load `_meta/squads.yaml`.** If absent → halt: "`--squad=` requires `_meta/squads.yaml`. This flag is only valid in multi-squad mode."
2. **Validate `<id>` exists** in declared squads. If not → halt with the list of valid IDs.
3. **Filter units.** Working set = units where `squad: <id>` matches.
4. **Verify consumed interfaces lockable.** For each unit in the working set, read `consumes_interfaces`. For each listed interface, read its frontmatter `status`. If ANY status is `draft` → halt `cross_squad_interface_draft`.
5. **Proceed** with normal sequential or `--parallel` execution on the filtered working set.

```yaml
blocker:
  type: cross_squad_interface_draft
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    consumed_interface_id: api-leave-request-submit
    producer_squad: squad-be
    interface_status: draft
  next_action: "Producer squad must lock the interface before consumer bolts can execute. Edit interfaces/<id>.md frontmatter: status: locked, locked_at: YYYY-MM-DD. Re-run execute-bolts."
```

> Under `--parallel` / `--per-squad`, the main-thread controller explicitly re-invokes the project-wide quality validators after each batch. This is **defense-in-depth**, not a fix for an invisible write: PostToolUse already fires on bolt-agent writes (AUDIT L1), but the explicit re-scan makes the gate state deterministic regardless of concurrent write ordering. This is the §Parent-thread post-flight re-scan obligation described in the Hard-Rule-scan ref (listed in SKILL.md).

## Per-bolt lightweight drift check

After post-flight Hard Rule validation passes (or a proposed-and-confirmed fix is applied), AND BEFORE commit, run a quick scope-filtered drift scan vs the vault:

a. Read `vault.json` scope (if a multi-scope vault) OR skip the scope filter.
b. For each file in the unit's `target_files` modified this bolt:
   - Compare current state vs the vault's expected state (from `binding.md` anchors when present).
   - Detect name drift, type drift, behavior drift (per detect-drift categories).
c. If drift is detected on a LOCKED entity (per `data-mutation-policy.md`) → halt `bolt_introduces_locked_drift` (eligible for propose-and-confirm OR override).
d. If drift is detected on an INTENT/ARTIFACT entity → log to `bolt-report.md` `## Drift introduced` + continue (will surface at the batch-end detect-drift gate).
e. If no drift → log "✓ Drift check: clean" to `bolt-report.md`.

Compact streaming reflects this:

```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
```

OR (drift detected):

```
└─ Post-flight: Hard Rules ✓ | PBT ✓ | ⚠️ Drift: order.amount type changed (LOCKED — will halt at gate)
```

## Batch completion — final full-suite gate (B2)

The per-bolt acceptance command is **scoped** to that unit; nothing re-runs the *whole* project suite. A later bolt — or an out-of-band edit that bypassed the bolt flow — can silently break an earlier bolt's contract and the batch still reports `completed`. The batch-completion gate closes that hole. Design: `docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md`.

**When:** once, after the **last committed code-bearing bolt** of the invocation (single bolt or `--all`/`--parallel`/`--per-squad`/`--module` batch). Skipped only for `--dry-run`, a zero-code-commit run (verify-only / all-skipped), or `--no-full-suite` (logged, never silent).

**Run the FULL suite, unscoped.** Use the test runner detected at pre-flight check 3.5 with **no per-unit filter** — e.g. `yarn test` / `pytest` / `go test ./...` / `cargo test`, NOT `yarn test <one-file>`. Capture pass/fail/todo counts.

**Out-of-band bypass guard (before the verdict).** Record the invocation's base SHA at batch start. Scan `git log <base>..HEAD` **excluding this run's own bolt commits**; for each commit, `git show --name-only` and flag any that touched a file listed in some unit's `target_files` yet whose message carries no `SDD-PROVENANCE` trailer. List them in `bypass_commits[]`. Bounding to the batch window is mandatory — an unscoped scan flags every pre-SDD commit in history. A non-empty list does not by itself halt (the full-suite run is the real gate) but forces the suite to run even on an otherwise-skippable invocation, and is surfaced in `_summary.md`.

**Write `<vault>/bolts/_batch-suite.json`:**

```json
{ "command": "<full-suite command>", "status": "green|red",
  "passed": N, "failed": N, "todo": N,
  "head_sha": "<git HEAD at run>", "ran_at": "<iso8601>",
  "units": ["U-001", "U-002"], "bypass_commits": [], "source": "execute-bolts" }
```

**Verdict.** `status: red` → **halt `batch_suite_red`**: emit the blocker with the failing test names, leave the tree for review (do not auto-revert), do not emit a `status: completed` handoff. `status: green` → the batch is complete.

**Enforcement (the gate is real, not prose).** The Stop hook runs `validate-bolt-artifacts.sh --batch-suite-gate` every turn end (detection-only). The PreToolUse aggregator blocks the **next** `execute-bolts` when no green `_batch-suite.json` covers the newest **code commit** (`batch_suite_gate_missing` — missing or stale: a code change landed after the last full-suite run, decided via `git merge-base --is-ancestor <newest-code-commit> <gate.head_sha>`) or the recorded suite is RED (`batch_suite_red`). The hook **verifies the artifact; it never runs the suite** (200s+ suites in a hook would cripple every turn). The freshness anchor is the newest commit touching a **code file** (outside `.mega-sdd/`, excluding pure-docs `.md`/`.rst`) **regardless of subject** — so an out-of-band edit (a hotfix, a manual change, a `git pull`) that touches source after a green suite DOES trip the gate (`out_of_band: true`); a docs/markdown-only commit does not. The gate *activates* only once a code-bearing `(bolt): U-XXX` commit exists (no bolting yet ⇒ nothing to gate).

**Sync lane.** After `orchestrate-flow --sync` reconciles an out-of-band edit, it re-runs the full suite and writes `_batch-suite.json` with `source: sync` — this is the catch for the *post*-batch out-of-band edit the within-batch gate has already passed. (The `SYNC-REPORT.md` terminal emission is owned separately by the sync-report work; it *consumes* this artifact, it does not re-run the suite.)
