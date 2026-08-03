# execute-bolts — Partial-state, resume + saga rollback

How a crashed bolt is recorded, resumed forward-only, and (optionally) rolled back via saga compensating actions.

## Contents
- Partial-state contract (v2.0 schema)
- Step-type canonical taxonomy
- Resume-time integrity check + `partial_state_corrupt` halt
- Saga compensating actions (`--rollback`)
- `--rollback` flow
- Out of scope

## Partial-state contract (v2.0 schema)

If a bolt subagent crashes mid-execution, write `<vault>/bolts/U-XXX/partial-state.json` (a JSON snapshot of bolt progress + side-effects, fields below):

- `schema_version: "2.0"`.
- `bolt_id`, `started_at`, `current_step`, `current_step_status` (enum: `crashed | partial | succeeded`).
- `files_modified[]`: each `{path, sha256_before, sha256_after}`.
- `last_test_result`, `last_action`.
- **`rollback_hints[]`**: harvested from `bolt-report.md` `## Rollback hints`. Each entry: `{step_id, step_type (taxonomy below), evidence (1-line what happened), compensating_action (literal shell command OR "(none — manual review required)"), idempotent (bool), applied_at (null until --rollback runs the action)}`.

`--resume` reads the partial-state and re-executes forward-only from `current_step` (doesn't start from zero). After 3 partial-state attempts → halt `bolt_repeated_partial_failure`.

## Step-type canonical taxonomy

The bolt subagent classifies each significant step into one of these when emitting a rollback hint to `bolt-report.md`:

| step_type | Compensating action template | Idempotent? |
|---|---|---|
| `file_created` | `rm <path>` | ✓ |
| `file_modified` | `git checkout HEAD -- <path>` | ✓ |
| `file_partially_written` | `git checkout HEAD -- <path>` | ✓ |
| `file_deleted` | `git checkout HEAD -- <path>` | ✓ |
| `composer_dep_added` | `composer remove <pkg> --no-update && git checkout composer.json composer.lock` | ✗ (composer cache may persist) |
| `composer_dep_removed` | `git checkout composer.json composer.lock && composer install` | ✗ |
| `npm_dep_added` | `npm uninstall <pkg> && git checkout package.json package-lock.json` | ✗ |
| `npm_dep_removed` | similar | ✗ |
| `migration_created` | `rm <migration-file>` | ✓ |
| `migration_executed` | `php artisan migrate:rollback --step=1` (Laravel) OR equivalent | ✗ (DB state) |
| `external_api_call` | `(none — manual review required)` | ✗ |
| `test_command_run` | `(none — read-only)` | ✓ |
| `git_commit` | `git reset --hard HEAD~1` (DANGEROUS — only if the commit was THIS bolt's) | ✗ |
| `git_branch_created` | `git branch -D <branch>` | ✓ |

## Resume-time integrity check + `partial_state_corrupt` halt

Before consuming partial-state, attempt a JSON parse. On parse failure → emit halt `partial_state_corrupt` with details `{partial_state_path: <absolute>, parse_error: <first 200 chars of exception>, corrupt_backup_path: "<path>.corrupt-<ISO8601>"}`; ALWAYS STOP. Resolution: rename the corrupt file to the suggested `.corrupt-<ISO8601>` path for forensics; re-run `--resume` (will start fresh now that the corrupt file is moved aside) OR run without `--resume` to restart the bolt batch.

**Malformed rollback_hints check:** if the v2.0 file parses but `rollback_hints[]` entries are missing required fields OR reference an unknown `step_type` → emit halt `partial_state_corrupt` with details `{..., malformed_hints: [<entry indices + reason>]}` (reuses the same halt envelope; no new halt type). Resolution: inspect `bolt-report.md` to reconstruct hints OR proceed with `--resume` (forward-only, no rollback) accepting the risk.

```yaml
# Example partial_state_corrupt envelope:
type: partial_state_corrupt
source_skill: execute-bolts
details:
  partial_state_path: "<vault>/bolts/U-007/partial-state.json"
  parse_error: "json.decoder.JSONDecodeError: Expecting ',' delimiter: line 4 column 18 (char 87)"
  corrupt_backup_path: "<vault>/bolts/U-007/partial-state.json.corrupt-2026-05-25T14:32:00Z"
next_action: "Rename partial-state.json to the suggested corrupt_backup_path (preserves forensics) then re-run `execute-bolts U-007 --resume` (will start fresh — corrupt file moved aside). Likely cause: bolt subagent crashed mid-write to partial-state.json (rare); inspect corrupt content for a skill-author bug."
```

## Saga compensating actions (`--rollback`)

Forward-only `--resume` retries failing steps but cannot undo non-idempotent prior steps (composer dep adds, migrations, external API calls). `--rollback` applies the `rollback_hints[]` captured in partial-state.json v2.0 in reverse order with per-step confirmation.

**Bolt subagent contract** (the dispatch-prompt template's §Rollback hints, listed in SKILL.md): for each significant step (file write / dep add / migration / etc.), the bolt subagent appends to `bolt-report.md` `## Rollback hints`:

```yaml
- step_id: step-1-add-dep
  step_type: composer_dep_added
  evidence: "added 'laravel/cashier': '^15.0' to composer.json:42; composer.lock regenerated"
  compensating_action: "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock"
  idempotent: false
```

On crash: execute-bolts harvests this section + writes the `rollback_hints[]` array into partial-state.json v2.0. On `--rollback`: applies actions in reverse order with per-action confirmation (default safe for non-idempotent).

## `--rollback` flow

1. Read `<vault>/bolts/U-XXX/partial-state.json`.
2. If `schema_version: "1.0"` → error: "No rollback hints in v1.0 partial-state.json. Manual review required (`git status` + `git diff HEAD`)."
3. If `schema_version: "2.0"` AND `rollback_hints[]` present → display the reverse-order list with idempotency markers:

   ```
   Rolling back partial bolt U-007 (3 compensating actions):

     3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
     2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
     1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

   Apply in reverse order (3 → 2 → 1)?
     [I] interactive — prompt before each action (DEFAULT — safe for non-idempotent steps)
     [Y] batch-apply all actions including non-idempotent (DANGEROUS — composer/migration removes happen without per-step confirmation)
     [N] cancel; review partial-state.json manually
   ```

   **Default = `[I] interactive`** — non-idempotent compensating actions (composer dep removes, migration rollbacks) NEVER auto-run without per-step user approval.

4. After each action runs: write `applied_at: <ISO8601>` back to partial-state.json (so partial rollback can be resumed).
5. If all actions complete: rename partial-state.json to `.rolled-back-<ISO8601>` for forensics; the bolt slot is now clean.

## Out of scope

- Auto-rollback on crash (user-initiated only; auto-rollback compounds non-idempotent errors).
- Cross-bolt saga (rollback scope = single bolt U-XXX; batch-level is too risky).
- DB introspection for `migration_executed` rollback (the hint says "rollback last migration"; the user accepts the risk via per-action confirmation).
