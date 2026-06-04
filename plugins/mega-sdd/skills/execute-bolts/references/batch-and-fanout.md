# execute-bolts — Batch + fan-out execution

Procedures for executing more than one unit: `--all`, `--per-squad`, `--squad=<id>`, `--module=<id>`, plus the per-bolt lightweight drift check.

## Contents
- `--all`
- `--per-squad`
- `--module=<id>` + `module_blocked_by` halt
- `--squad=<id>` + `cross_squad_interface_draft` halt
- Per-bolt lightweight drift check

## `--all`

1. Topologically sort units by `depends_on`.
2. Execute in order (default sequential).
3. On `--parallel`: group units with no shared dependency; dispatch the group as a subagent batch via `subagent-driven-development`.
4. On any failure: halt the entire `--all` run (no skip-ahead).

## `--per-squad`

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with an informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `/mega-sdd:generate-intent` to add squad config, or use plain `/mega-sdd:execute-bolts --all` for single-squad."
2. **Read the squad list.** Build a list of declared squad IDs.
3. **For each squad, dispatch a Claude subagent** per the per-squad subagent dispatch protocol (listed in SKILL.md). Subagents run in parallel via `Agent(run_in_background: true)`.
4. **Wait for all subagents** to complete or halt. Each subagent reports back its bolt-report list + halt status.
5. **Consolidate the report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

## `--module=<id>` + `module_blocked_by` halt

1. **Load `_meta/modules.yaml`.** If absent → halt: "`--module=` requires `_meta/modules.yaml`. Auto-derive via `/mega-sdd:generate-units --derive-modules` first."
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

> Under `--parallel` / `--per-squad`, the parent thread must explicitly re-invoke the project-wide quality validators after each batch (the subagent's writes are invisible to the parent's PostToolUse). This is the §Parent-thread post-flight re-scan obligation described in the Hard-Rule-scan ref (listed in SKILL.md).

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
