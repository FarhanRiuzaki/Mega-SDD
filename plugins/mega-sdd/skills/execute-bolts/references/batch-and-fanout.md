# execute-bolts — Batch + fan-out execution

Procedures for executing more than one unit: `--all`, `--per-squad`, `--squad=<id>`, `--module=<id>`.

> **Load condition (v7 R4):** load this file ONLY when the invocation is multi-unit — `--all`, `--parallel`, `--per-squad`, `--squad=`, or `--module=`. A single-unit run never needs it: the per-bolt drift check and the B2 full-suite gate (which apply to every invocation) live in `halts-and-handoff.md`.

## Contents
- `--all` (sprints)
- `--sprint=<n>` + `sprint_blocked_by` halt
- `--per-squad`
- `--module=<id>` + `module_blocked_by` halt
- `--squad=<id>` + `cross_squad_interface_draft` halt

## `--all`

**The sprint plan is DERIVED, never authored (spec 2026-08-29 Fase 2).** Run `bash <plugin>/scripts/analyze-parallelism.sh <vault> --format=json` once at the start of an `--all` run (one bounded spawn; the same deterministic DAG math the analyze surface already uses). Its `waves[]` array IS the sprint sequence — sprint N = `waves[N-1]` — and it also carries `depth`, `max_width`, `critical_path`, `parallelism_speedup`, and `blocks` (transitive downstream count per unit, for the sprint summary + triage ordering). **Do not hand-derive the layering and do not write a second producer**: a `derive-sprint-plan.sh` was specified and then rejected precisely because this script already emits the plan. A plan that references a unit not on disk, or misses one that is, is STALE — re-run it (log one line); never dispatch from a plan that disagrees with `units/`.

**Show the plan before executing** — one Mermaid diagram (`--format=mermaid`, project hard rule: every generated flow is Mermaid, never ASCII or prose) plus one line per sprint (`Sprint N: <count> units — <module list>`). On `--sprint-checkpoint` the same summary is re-printed at each boundary with what landed.

1. Consume `waves[]` as the sprint sequence (topological order by `depends_on`).
2. **Execute sprint by sprint — wave execution is the DEFAULT on `--all`** (v7.7: a 30-unit vault 10 sprints deep pays 30 bolt-times sequentially and 10 wave-times in sprints; measured speedup 3.0×). `--sequential` opts out to one-unit-at-a-time — the correct choice when the project's suite is not concurrency-safe and `--worktree` is not available. `--parallel` remains valid on non-`--all` multi-unit filters, where the default is still off.
3. Wave dispatch (the default on `--all`, and what `--parallel` selects elsewhere): the **main-thread controller** groups units with no shared dependency and dispatches them **concurrently** — multiple `bolt-implementer` Agent calls in one message — each unit still running the full review panel (`bolt-implementer` → the parallel blind lenses per `review-panel.md`). **Overlap rail (independence = BOTH conditions):** no `depends_on` edge between them AND pairwise-disjoint `target_files` — units whose whitelists intersect are never in the same wave; they serialize (a silent data race on a shared file is worse than slower execution). This is **depth-1** (the controller stays in the main thread; it never forks a sub-controller that would then need to dispatch the bolt agents — that would be depth-2, which the runtime forbids). `subagent-driven-development` is an optional *technique* hint, not a nested dispatch.
   - **Wave plan consumption (chain runs — `docs/superpowers/specs/2026-07-30-token-and-latency-optimization.md` §2a).** When the chain's analyze-parallelism auto-run has already put the `--format=json` wave plan in context (`chain-execution.md` diagnostics row), its `waves` array IS the `depends_on` topological layering — consume it instead of re-deriving the grouping, and **skip the §`--all` start-of-run spawn** (same script, same verdict — running it twice buys nothing). The **overlap rail above is applied HERE regardless**, per wave, at dispatch time: the plan never carries it, so a stale or hand-edited plan cannot bypass it. A standalone `--parallel` run (no plan in context) computes its own grouping exactly as before. A plan that references a unit no longer on disk, or misses one that is, is STALE — discard it and re-derive (log one line); never dispatch from a plan that disagrees with `units/`. Within a consumed wave, **dispatch only units not yet completed** (per the unit-selection rules in SKILL.md — completed units are skipped, `superseded` skipped with a warning, `stale` eligible): the plan layers ALL units, including already-bolted ones on a resume.
   - **In-flight cap.** Wave dispatch is bounded by an in-flight cap (default **5** concurrent `bolt-implementer` agents — the same bound `--per-squad` uses): a wave wider than the cap dispatches in cap-sized slices, each slice completing its review tail before the next slice. Unbounded fan-out is never dispatched — each in-flight bolt later fans out its own panel lenses, and the platform's concurrent-task comfort zone is finite.
   - **Per-unit gate ranges under a wave.** Concurrent implementers commit into the same branch, so wave commits INTERLEAVE — `wave-base..wave-head` is NOT any single unit's range. The bolt commit is atomic per unit (SKILL.md pre-flight 3) and carries the canonical identity (`bolt-contract.md §Commit message format` — the same anchor B1/B3/B4 key on), so **each unit's L0 gate run scans its OWN commit: `--base=<its-commit>^ --head=<its-commit>`** — under sequential execution this is exactly the shipped `bolt-base..new-head`; under a wave it is what keeps a sibling's secret from being attributed to this unit. A panel re-dispatch under `--parallel` scans the unit's own commit SET (the original bolt commit AND each fix commit, one gate call per commit, results merged) — the original commit stays in the record (the re-scan rule's purpose per `code-gates.md`) without sweeping sibling commits that landed in between.
   - **Same-tree concurrency valves.** Disjoint `target_files` (the overlap rail) removes content races; the shared git INDEX is still a brief contention point — a transient `index.lock` failure during a concurrent commit is retried briefly by the implementer (agent contract), never reported as BLOCKED. Acceptance-test runs inside a wave share project test state (a test DB, fixtures, caches): on a project whose suite is not concurrency-safe, run the batch with `--worktree` (per-bolt isolation) or drop `--parallel` at the chain's Edit step — a false red from shared test state is a `test_fail` halt the wave semantics then honor.
   - **Wave boundary = review boundary.** The next wave dispatches only after every unit in the current wave has completed its detect-after pipeline (L0 gates → panel merged clean → post-flight). Never pipeline unit N+1 against unit N's review tail.
4. On any failure: halt the entire `--all` run (no skip-ahead). Under `--parallel` this maps to the wave boundary: when any unit in the in-flight wave records a failure (implementer BLOCKED, an L0 blocking halt, `review_critical_unresolved`, a post-flight violation), **complete the detect-after pipeline for every unit already dispatched in that wave** — their commits have already landed; abandoning them would leave landed commits with no verdict trail (and trip the B1/B2/B4 gates at the next invocation anyway) — then **dispatch no further unit and no further wave**. "No skip-ahead" = never START new work past a failure; it never meant discard verdicts on work already committed. A sibling's own panel re-dispatch (fix-forward on its already-landed commit, within its retry cap) IS part of completing its pipeline — remediation of started work, not new work; new UNITS never dispatch after a recorded failure.

## `--sprint=<n>` + `sprint_blocked_by` halt

Runs exactly ONE sprint — the human-paced lane, for a team that reviews at each dev stage rather than letting 30 units roll.

1. **Derive the plan** (`analyze-parallelism.sh --format=json`, per §`--all`). `n` is 1-indexed into `waves[]`; `n` outside `1..total_waves` → usage error, never a silent clamp.
2. **Check the prerequisite sprints.** Every unit in `waves[0..n-2]` must be complete (per the unit-selection rules in SKILL.md — `superseded` counts as satisfied, `stale` does NOT). Any incomplete → **halt `sprint_blocked_by`**.
3. **Execute `waves[n-1]`** exactly as one wave of `--all` — same overlap rail, same in-flight cap, same per-unit gate ranges, same per-unit review panel. A sprint is a wave with a name; it is NOT a weaker execution mode.
4. **Stop at the boundary** and print the sprint summary (units landed, advisory findings, gate results, elapsed, and `blocks` for anything that failed — a blocked foundation unit is a different problem from a blocked leaf).

```yaml
blocker:
  type: sprint_blocked_by
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    requested_sprint: 4
    incomplete_prerequisites:
      - sprint: 3
        units: [U-004]
  next_action: "Complete the earlier sprint first: execute-bolts --sprint=3 (or --all, which walks every sprint in order)."
```

## `--per-squad`

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with an informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `generate-intent` to add squad config, or use plain `execute-bolts --all` for single-squad."
2. **Read the squad list.** Build a list of declared squad IDs.
3. **Main-thread squad loop (NOT a squad subagent).** The controller stays in the main thread and runs each squad's units through the per-unit panel flow directly (depth-1) — see `squad-subagent.md`. A forked squad subagent would have to dispatch the bolt agents = depth-2 (forbidden) and would silently lose the review panel.
4. **Parallelize across squads.** Independent units — including units from different squads — are dispatched **concurrently** (multiple `bolt-implementer` Agent calls in one message), bounded by an in-flight cap. **Independent = no `depends_on` edge AND pairwise-disjoint `target_files`** — cross-squad units carry no dependency edges by design, so the whitelist-overlap check is the ONLY thing standing between two squads and a silent clobber of a shared file (routes, config). Same mechanism as `--all --parallel`; `--per-squad` only changes the filter + the consolidation.
5. **Consolidate the report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

## `--module=<id>` + `module_blocked_by` halt

1. **Load `_meta/modules.yaml`.** If absent BUT `_meta/modules.yaml.auto` exists → instruct: "review `_meta/modules.yaml.auto` and promote it: `mv _meta/modules.yaml.auto _meta/modules.yaml`". If neither exists → halt: "`--module=` requires `_meta/modules.yaml`. Run `generate-units` (Step 4.5 auto-derives `modules.yaml.auto`), review, then promote it."
2. **Validate `<id>` exists** in declared modules.
3. **Check blocked_by**: for each `blocked_by` entry, verify that module is `status: completed` (per memory). Incomplete → halt `module_blocked_by` listing pending prerequisites.
4. **Filter units**: working set = units where `module: <id>` AND not yet completed.
5. **Topologically sort** within the module by `depends_on`.
6. **Proceed** with sequential or `--parallel` execution on the filtered set.
7. **After all units complete**: probe the module's DoD checklist (`modules.yaml.modules[<id>].dod`). Surface incomplete DoD items in chat; the user marks them via `list-modules --mark-dod=<module>` or edits modules.yaml manually.

```yaml
blocker:
  type: module_blocked_by
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    requested_module: M-leave-mgmt
    blocked_by_modules: [M-auth]
    blocker_status: M-auth has 2/5 units complete
  next_action: "Complete the prerequisite module first via execute-bolts --module=M-auth"
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

> The per-bolt drift check and the B2 batch-completion full-suite gate apply to EVERY invocation (single-unit included) and therefore live in `halts-and-handoff.md` (§Per-bolt drift check, §Batch completion — full-suite gate (B2)) — this file deliberately carries no copy.
