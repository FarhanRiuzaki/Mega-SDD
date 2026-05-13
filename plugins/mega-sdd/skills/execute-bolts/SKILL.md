---
name: execute-bolts
version: 1.0.0
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
