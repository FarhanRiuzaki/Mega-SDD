---
name: execute-bolts
version: 1.1.0
description: Execute one or more units to produce code commits (bolts). Bridges to superpowers (executing-plans, subagent-driven-development, test-driven-development) with vendored fallback. Triggers — "execute bolts", "run units", "implement units", "jalanin unit", "eksekusi bolt", or paraphrases.
---

# Execute-Bolts

The terminal phase of the SDD pipeline — turns units into code.

**Announce at start:** "I'm using the execute-bolts skill to execute units via superpowers."

## When to use

- After `generate-units` wrote `<vault>/units/U-*.md`
- User explicit: `/mega-sdd:execute-bolts <unit-id>` or `--all`
- `orchestrate-flow` auto-routes after units are ready

## Inputs

- Unit path OR unit ID OR `--all` (positional)
- Flags:
  - `--parallel` — dispatch independent units via subagent-driven-development
  - `--worktree` — isolate each bolt in a git worktree
  - `--max-retries=N` — default 3
  - `--dry-run` — walk steps, do not commit
  - `--force` — re-execute completed units
  - `--auto` — non-interactive
  - `--per-squad` — (v1.1+) fan out across all squads declared in `_meta/squads.yaml`. Spawns one Claude subagent per squad via `subagent-driven-development`; each subagent filters units by their `squad:` field and runs in parallel.
  - `--squad=<id>` — (v1.1+) filter units to a single squad. For human-team handoff: a dev team runs this on their own laptop to process only their squad's units. Halts on `cross_squad_interface_draft` if any consumed interface is still draft.

## Pre-flight checks

1. **Superpowers detection.** Per `references/superpowers-bridge.md` order:
   - Real install? → use plugin namespace
   - Vendored fallback ready? → use local paths
   - Neither? → halt with install instructions

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: dep_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    required_skills:
      - executing-plans
      - subagent-driven-development
      - test-driven-development
      - using-git-worktrees
    missing_real: <list of skills not found in real superpowers install>
    missing_vendored: <list of skills not found in _vendored/>
    install_command: "/plugin install superpowers"
  next_action: "Install superpowers (recommended) OR run: bash plugins/mega-sdd/scripts/sync-superpowers.sh"
```

2. **Unit validity.** For each target unit:
   - Frontmatter parses and matches `unit-schema.md`
   - `target_files` non-empty
   - `acceptance_test` has ≥1 `type: test` entry
   - `depends_on` references resolve (no dangling)

3. **Repo state.** Working tree clean (or `--force` to proceed). Bolts produce commits, so dirty state could be lost.

## Procedure (per unit)

Follow `references/superpowers-bridge.md` per-unit flow.

For `--all`:
1. Topologically sort units by `depends_on`
2. Execute in order (default sequential)
3. On `--parallel`: group units with no shared dependency; dispatch group as subagent batch via `subagent-driven-development`
4. On any failure: halt entire `--all` run (no skip-ahead)

For `--per-squad` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `/mega-sdd:generate-intent` to add squad config, or use plain `/mega-sdd:execute-bolts --all` for single-squad."
2. **Read squad list.** Build a list of squad IDs declared.
3. **For each squad, dispatch a Claude subagent** per `references/squad-subagent.md`. Subagents run in parallel via `Agent(run_in_background: true)`.
4. **Wait for all subagents** to complete or halt. Each subagent reports back its bolt-report list + halt status.
5. **Consolidate report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

For `--squad=<id>` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent → halt: "`--squad=` requires `_meta/squads.yaml`. This flag is only valid in multi-squad mode."
2. **Validate `<id>` exists** in declared squads. If not → halt with list of valid IDs.
3. **Filter units.** Build the working set = units where `squad: <id>` matches.
4. **Verify consumed interfaces lockable.** For each unit in the working set, read `consumes_interfaces`. For each listed interface, read its frontmatter `status`. If ANY status is `draft` → halt with `cross_squad_interface_draft`.
5. **Proceed with normal sequential or `--parallel` execution** on the filtered working set.

## Halt protocol

Per `references/bolt-contract.md` failure modes. Always emit blocker YAML on halt:

```yaml
blocker:
  unit: U-XXX
  cause: <category>
  details: <verbatim error / test output>
  next_action: <retry | edit unit | manual fix>
```

When retries exhaust for a unit's acceptance test, emit:

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: test_fail
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    retries_attempted: <N, default 3>
    test_command: <exact command run>
    last_failure_output: |
      <verbatim output of last failing test invocation>
    files_touched:
      - <list of files touched during the attempts>
  next_action: "Review bolt-report.md; edit unit acceptance criteria, fix code manually, or skip via --force"
```

**Structured halt per `vault-contract.md §halt-protocol` (v1.1+):**

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

## Anti-hallucination rails

- target_files whitelist enforced at every step
- existing_interfaces preserved (verified by tests)
- No auto-bypass of pre-commit hooks
- No --force commits or push to remote
- OQ in unit body → prompt user before bolt finalizes

## Outputs

Per unit:
- Code commits (1+) on current branch
- `<vault>/bolts/U-XXX/bolt-report.md`

Global:
- Update `<vault>/vault.json` changelog: `{ "event": "bolt_completed", "unit": "U-XXX", "commits": [...] }`

## Hand-off

After last unit:
- Suggest `/mega-sdd:detect-drift` to verify all bolts honored the vault
- Show summary: N units done, M failed, P skipped
