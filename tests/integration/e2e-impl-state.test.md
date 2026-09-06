# E2E: Implementation-State Classification → Task-Type Units (Iter 1)

> **Prose walkthrough, not CI (note added 7.29.1).** The `./fixtures/e2e-*-fixture/` paths are illustrative — they were never committed; run the same steps with your own PRD. The typed `/mega-sdd:auto` form was removed at 6.0.0: use `/mega-sdd <prd> --deep` and `/mega-sdd --resume`.

End-to-end integration test for the Iter 1 flow: brownfield project with mixed existing/new functionality. Validates the full chain `scan-codebase → bind-codebase → generate-units` produces the right mix of `create` and `verify` units.

## Fixture

**Repo state**:
- Existing Laravel project at `./fixtures/e2e-impl-state-fixture/`
- Already implemented:
  - `User` model (`app/Models/User.php`) with fields: `id`, `name`, `email`, `created_at`, `updated_at`
  - `UserController@index` and `UserController@show` (read endpoints) — routes registered in `routes/api.php`
  - Test file `tests/Feature/UserApiTest.php` with passing tests for the read endpoints
- NOT yet implemented:
  - `UserController@store` (create endpoint)
  - `audit_log` table + AuditLogController (entire new feature)

**PRD/vault**:
- vault claims:
  - C-001: User entity with fields id, name, email
  - C-002: `GET /api/users` (list) endpoint
  - C-003: `GET /api/users/{id}` (show) endpoint
  - C-004: `POST /api/users` (create) endpoint
  - C-005: New `audit_log` entity with fields id, action, user_id, timestamp
  - C-006: `POST /api/audit-log` (create) endpoint

## Test steps

### Step 1: scan-codebase
**Run:** `/mega-sdd:scan-codebase ./fixtures/e2e-impl-state-fixture`
**Expect:** `codebase-map.md` includes:
- §2 lists `UserController@index`, `UserController@show`, `User` model
- §3 lists `User` entity with the 5 fields above
- §4 lists `GET /api/users` and `GET /api/users/{id}`
- Audit-log artifacts NOT present (correctly)

### Step 2: bind-codebase
**Run:** `/mega-sdd:bind-codebase ./fixtures/e2e-impl-state-fixture/vault`
**Expect** in `binding.md`:

| Claim ID | Verdict | State | Anchor | Confidence |
|---|---|---|---|---|
| C-001 (User entity) | CONFIRMED | IMPLEMENTED | app/Models/User.php:N | high |
| C-002 (GET list) | CONFIRMED | IMPLEMENTED | UserController.php:N + routes/api.php:N | high |
| C-003 (GET show) | CONFIRMED | IMPLEMENTED | UserController.php:N + routes/api.php:N | high |
| C-004 (POST create) | OQ → NEW | NEW | — | n/a |
| C-005 (audit_log entity) | OQ → NEW | NEW | — | n/a |
| C-006 (audit-log POST) | OQ → NEW | NEW | — | n/a |

- bound-vault produced (no CONFLICTs)
- `## Implementation State Map` section present in binding.md

### Step 3: generate-units
**Run:** `/mega-sdd:generate-units ./fixtures/e2e-impl-state-fixture/vault-bound`
**Expect units produced**:

- **U-001** `task_type: verify` covering C-001, C-002, C-003:
  - target_files: empty (or `operation: none`)
  - Anchors section cites `app/Models/User.php:N`, `app/Http/Controllers/UserController.php:N`, `routes/api.php:N`
  - Implementation steps: single line "No code changes. Run acceptance tests against existing implementation at app/Http/Controllers/UserController.php."
  - acceptance_test runs `php artisan test --filter=UserApiTest` (or equivalent existing test command)

- **U-002** `task_type: create` covering C-004:
  - target_files: `app/Http/Controllers/UserController.php` (operation: modify — adding store method), `routes/api.php` (operation: modify — adding route), `tests/Feature/UserApiTest.php` (operation: modify — adding store test case)
  - Note: this is `create` task_type but target_files have `modify` operations because the unit is adding to EXISTING files — that's OK in Iter 1 (the `extend` task_type is reserved for Iter 2 when PARTIAL state activates)

- **U-003** `task_type: create` covering C-005, C-006:
  - target_files: new files `app/Models/AuditLog.php`, `app/Http/Controllers/AuditLogController.php`, `database/migrations/YYYY_MM_DD_create_audit_log_table.php`, `tests/Feature/AuditLogTest.php` (all `operation: create`)
  - normal create-unit shape

**Expect _index.md** lists 3 units with dependency graph: U-001 has no deps; U-002 has no deps; U-003 has no deps. (All independent — parallelizable.)

## Negative cases

### N1: User adds spurious vault claim that matches existing file by coincidence
- **Setup:** vault claim C-007: "Create utility function `formatName()` in `app/Models/User.php`"; codebase-map shows file exists but no such function
- **Expect:** Implementation State Map: C-007 → `UNKNOWN` (file exists, symbol missing)
- generate-units: unit for C-007 → `task_type: create`, target_files entry `app/Models/User.php` with `operation: modify`
- Iter 1 does NOT trigger dedup_ambiguous because operation is `modify`, not `create`

### N2: Vault wants to recreate a fully-implemented file
- **Setup:** vault claim C-008: "Create `app/Models/User.php` with fields..." but User.php already exists
- **Expect:**
  - Implementation State Map: C-008 → `IMPLEMENTED` (entity match)
  - generate-units: emits `task_type: verify` for C-008 (per TT2)
  - NO dedup_ambiguous halt (verify path bypasses the create-on-existing-file trap)

### N3: Binding gap forces dedup_ambiguous
- **Setup:** vault claim C-009: "Create `routes/web.php` with login route"; routes/web.php exists in codebase-map but binding fails to classify (codebase-map §4 doesn't list the route, but §1 lists the file)
- **Expect:**
  - Implementation State Map: C-009 → `NEW` (binding gap: route not in §4)
  - generate-units: unit emitted with `task_type: create`, target_files `routes/web.php` (operation: create)
  - **Dedup check (step 12.5)** triggers: target_files all exist in codebase-map §1 with operation: create
  - HALT with `dedup_ambiguous` blocker — user manually resolves (likely: rename target or change operation to modify or fix the binding gap)

## Pass criteria

All steps succeed in fresh runs. binding.md has Implementation State Map populated correctly. Unit task_types match the table above. No silent rewrites. Dedup blocker fires on N3 fixture and halts cleanly with actionable next_action.
