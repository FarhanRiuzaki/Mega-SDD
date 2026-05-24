# Iter 45 — Saga Compensating Actions Design

**Status:** Approved (autonomous execution)
**Source:** Iter 38 audit Queue #5 (D3-009 + D3-003 pattern D)
**Plugin:** v3.29.0 → v3.30.0 (MINOR — partial-state.json schema bump 1.0 → 2.0; new --rollback flag)
**Estimated effort:** ~2-3hr (markdown-driven; less than 5hr audit estimate)

---

## §1 — Problem

Audit Pattern D ("No saga-style compensating actions") — D3-009 + D3-003:

mega-sdd uses **forward-only resume** for partial bolt execution. If a bolt crashes mid-step, `partial-state.json` captures STATE (what was done), not COMPENSATING ACTIONS (how to undo it). On `--resume`, execute-bolts re-attempts the failing step — fine for idempotent steps (file write); problematic for non-idempotent steps (composer dep add, migration run, external API call).

**Example failure mode:**
1. Bolt step 1: `composer require laravel/cashier` → composer.lock dirty
2. Bolt step 2: write `database/migrations/2026_05_25_subscriptions.php` → file created
3. Bolt step 3: write `app/Http/Controllers/SubscriptionController.php` → CRASH mid-write
4. `partial-state.json` captures `current_step: step-3`
5. User runs `--resume` → execute-bolts retries step 3 → succeeds
6. BUT: if step 1 had a different unintended side effect (e.g., composer require pulled in wrong version), retry doesn't catch it; partial composer state persists

**Audit finding:** "Plugin uses forward-only resume pattern; no compensating action specification means partial writes can compound on resume." (D3-009)

External research (audit-cited):
- [Saga Pattern (microservices.io)](https://microservices.io/patterns/data/saga.html)
- [Compensating Transactions (Microsoft Azure)](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction)

---

## §2 — Design

### Schema extension: partial-state.json v2.0

Bump `schema_version: "1.0"` (Iter 30 baseline) → `"2.0"` (Iter 45). Add `rollback_hints[]` array.

```json
{
  "schema_version": "2.0",
  "bolt_id": "U-007",
  "started_at": "2026-05-25T10:00:00Z",
  "current_step": "step-3-write-controller",
  "current_step_status": "crashed | partial | succeeded",
  "files_modified": [
    {"path": "...", "sha256_before": "...", "sha256_after": "..."}
  ],
  "last_test_result": "...",
  "last_action": "...",

  // NEW v2.0 — Iter 45
  "rollback_hints": [
    {
      "step_id": "step-1-add-dep",
      "step_type": "composer_dep_added",
      "evidence": "added 'laravel/cashier': '^15.0' to composer.json:42; composer.lock regenerated",
      "compensating_action": "composer remove laravel/cashier --no-update && git checkout composer.json composer.lock",
      "idempotent": false,
      "applied_at": null
    },
    {
      "step_id": "step-2-write-migration",
      "step_type": "file_created",
      "evidence": "created database/migrations/2026_05_25_100000_create_subscriptions_table.php (47KB)",
      "compensating_action": "rm database/migrations/2026_05_25_100000_create_subscriptions_table.php",
      "idempotent": true,
      "applied_at": null
    },
    {
      "step_id": "step-3-write-controller-interrupted",
      "step_type": "file_partially_written",
      "evidence": "wrote 234 of estimated 800 lines to app/Http/Controllers/SubscriptionController.php before crash",
      "compensating_action": "git checkout HEAD -- app/Http/Controllers/SubscriptionController.php (revert to HEAD)",
      "idempotent": true,
      "applied_at": null
    }
  ]
}
```

### Step type taxonomy (canonical rollback library)

Bolt subagent classifies each significant step into one of these types when writing partial-state.json:

| step_type | Typical compensating_action template | Idempotent? |
|---|---|---|
| `file_created` | `rm <path>` | ✓ |
| `file_modified` | `git checkout HEAD -- <path>` (revert to last commit) | ✓ |
| `file_partially_written` | same as `file_modified` (revert to HEAD) | ✓ |
| `file_deleted` | `git checkout HEAD -- <path>` (restore from HEAD) | ✓ |
| `composer_dep_added` | `composer remove <pkg> --no-update && git checkout composer.json composer.lock` | ✗ (composer cache may persist) |
| `composer_dep_removed` | `git checkout composer.json composer.lock && composer install` | ✗ |
| `npm_dep_added` | `npm uninstall <pkg> && git checkout package.json package-lock.json` | ✗ |
| `npm_dep_removed` | similar | ✗ |
| `migration_executed` | `php artisan migrate:rollback --step=1` (if Laravel) OR equivalent | ✗ (DB state) |
| `migration_created` | `rm <migration-file>` | ✓ |
| `external_api_call` | `(none — manual review required)` + log warning | ✗ |
| `test_command_run` | `(none — read-only)` | ✓ |
| `git_commit` | `git reset --hard HEAD~1` (DANGEROUS — only if commit was THIS bolt's) | ✗ |
| `git_branch_created` | `git branch -D <branch>` | ✓ |

Bolt subagent prompt (`bolt-dispatch-prompt.md`) instructs: "as you complete each step, append a `rollback_hint` entry to your bolt-report.md self-assessment `## Rollback hints` section with these fields: `step_id, step_type (from taxonomy), evidence, compensating_action, idempotent`. execute-bolts harvests these into partial-state.json on crash."

### `--rollback` flag (NEW)

New execute-bolts flag: `--rollback <bolt-id-or-vault-path>`. Reads `<vault>/bolts/U-XXX/partial-state.json` v2.0; if `rollback_hints[]` present, prompts user with reverse-order list:

```
Rolling back partial bolt U-007 (3 compensating actions):

  3. file_partially_written: git checkout HEAD -- app/Http/Controllers/SubscriptionController.php  [idempotent ✓]
  2. file_created: rm database/migrations/2026_05_25_100000_create_subscriptions_table.php  [idempotent ✓]
  1. composer_dep_added: composer remove laravel/cashier --no-update && git checkout composer.json composer.lock  [idempotent ✗ — composer cache may persist]

Apply these actions in reverse order (3 → 2 → 1)?
  [Y] proceed (records applied_at: <ISO8601> per action)
  [N] cancel; review partial-state.json manually
  [I] interactive (prompt before each action)
```

Per-action confirmation defaults to safe for non-idempotent ops. Applied actions get `applied_at:` timestamp written back to partial-state.json (so partial rollback can be resumed).

### Compensating action emission contract (skill-author rule)

Updates to `bolt-dispatch-prompt.md` instruct the bolt subagent:
- Track each significant step (file write, dep add, migration, etc.)
- At end of each step, append `rollback_hint` to bolt-report.md `## Rollback hints` section
- If bolt crashes, execute-bolts harvests this section + writes partial-state.json v2.0
- If bolt completes successfully, rollback_hints section is INFORMATIONAL only (no rollback needed; clean commit landed)

### Halt path (extends partial_state_corrupt from Iter 40)

If partial-state.json v2.0 parse succeeds BUT `rollback_hints[]` is malformed (missing required fields, unknown step_type) → emit existing `partial_state_corrupt` halt with `details.malformed_hints: [<which entries>]`. Iter 40 halt semantics extended; no new halt type.

### Backward compatibility

v1.0 partial-state.json (Iter 30 baseline; no `rollback_hints[]`):
- `--resume` still works (current forward-only behavior)
- `--rollback` errors with "no rollback hints in partial-state.json v1.0 — manual review required; consider `git status` + `git diff HEAD` to inspect crash state"
- New bolt writes always emit v2.0 schema (one-time migration)

---

## §3 — Surface updates

| Surface | Change |
|---|---|
| `execute-bolts/SKILL.md` | + Step taxonomy + `--rollback` flag in Inputs + extend §Partial-state contract with v2.0 schema + new step taxonomy; bump 2.8.0 → 2.9.0 |
| `execute-bolts/references/bolt-dispatch-prompt.md` | + `## Rollback hints` self-assessment section (bolt subagent must populate during execution) |
| `references/shared-snapshot-schema.md` | (consult — does it document partial-state.json schema? If yes, update to v2.0) |

---

## §4 — Version bumps

- `plugin.json`: 3.29.0 → **3.30.0** (MINOR — schema bump + new flag + new self-assessment field)
- `execute-bolts` SKILL.md: 2.8.0 → **2.9.0** (MINOR)

---

## §5 — Out of scope

- **Auto-rollback on crash:** user-initiated only; auto-rollback risks compounding errors on non-idempotent steps
- **Cross-bolt saga:** rollback scope = single bolt (U-XXX); batch-level rollback would compound risk
- **DB schema introspection for migration_executed:** rollback_hint says "php artisan migrate:rollback --step=1" but doesn't verify the most-recent migration was actually THIS bolt's; user accepts this risk per per-action confirmation
- **External API compensation:** rollback_hint = "(none — manual review required)" — explicit non-coverage

---

## §6 — Standing directives applied

- **simplifikasi:** 1 audit Pattern → 1 iter; schema bump + 1 new flag + 1 self-assessment section in 2 files
- **flawless:** producer (bolt subagent emits hints) + consumer (execute-bolts harvests on crash + applies on --rollback) ship in-iter; v1.0 readers gracefully degrade
- **reuse-first:** extends existing partial-state.json (Iter 30) + extends existing bolt-dispatch-prompt.md self-assessment section pattern + reuses existing partial_state_corrupt halt for malformed hints (no new halt type)
