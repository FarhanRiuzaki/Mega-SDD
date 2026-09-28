# Scenario 3 — Field-Level Extension

**Time**: ~20 minutes
**Goal**: Add a missing field to an existing endpoint — the "PRD says (nip, nama, password), code has (nip, password), the tool should know to add `nama`" use case. Part A shows the default route; Part B shows how the guarded pipeline turns that gap into an explicit ADD / KEEP / REMOVE contract.

## Prerequisites

- Mega-sdd 9.0+
- Existing PHP/Laravel project with at least one model + endpoint
- `ast-grep` installed for Part B: it builds the symbol index `plan` uses to see the existing endpoint. Without it `plan` cannot tell `extend` from `create`; see the pitfalls.

```bash
brew install ast-grep
command -v ast-grep && echo "✓ ready"
```

## Setup — minimal example

For demo purposes, create this minimal Laravel project (or skip if you have one):

```bash
mkdir ~/demo/login-extension && cd $_
composer create-project laravel/laravel:^11.0 ./

# Create LoginController with INCOMPLETE field set (missing `nama`)
cat > app/Http/Controllers/Api/LoginController.php << 'EOF'
<?php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class LoginController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'nip' => 'required|string',
            'password' => 'required|string',
        ]);

        $user = User::where('nip', $validated['nip'])->first();
        if (!$user || !Hash::check($validated['password'], $user->password)) {
            return response()->json(['error' => 'Invalid credentials'], 401);
        }

        $token = $user->createToken('login')->plainTextToken;
        return response()->json(['token' => $token]);
    }
}
EOF

# Route
echo "Route::post('/api/login', [App\\Http\\Controllers\\Api\\LoginController::class, 'store']);" >> routes/api.php

# Commit baseline
git add . && git commit -m "baseline: login endpoint with nip + password (missing nama)"
```

## PRD for the extension

Save as `./prd-login-extension.md`:

```markdown
# PRD — Extend Login with Patient Name

Update existing login endpoint to also accept patient name. Some clinics
require name verification at login (per regulatory requirement OQ-001
resolved 2026-05-15).

## Required fields for POST /api/login

The endpoint accepts THREE fields:
- `nip` — patient ID (existing)
- `nama` — patient name (NEW; must match patient record)
- `password` — credential (existing)

## Behavior

If `nama` doesn't match user's stored name (case-insensitive):
- Return 401 same as wrong password
- Do not reveal which field was wrong (security)

All other login behavior unchanged.

## Out of scope

- Backfilling existing users' `nama` (assume already populated)
- Multi-language name matching
- Nickname support
```

## Part A — the default route (assisted lane)

### Step A1 — Run mega-sdd

```
/mega-sdd ./prd-login-extension.md
```

The router (`scripts/route-lane.sh`, read-only) sees a real app, because a Laravel skeleton alone is well over 10 tracked source files:

```
lane: assisted (signals: existing_code, multi_flow) · naik ke pipeline: /mega-sdd ./prd-login-extension.md --guarded `mega-sdd-trace:assisted`
```

The PRD has no open items, so there is no question round. Assisted adds its batched ask only when the spec has open items.

### Step A2 — Claude extends the endpoint in the main session

Claude reads the PRD and lists its criteria. It then opens `LoginController.php`, adds `nama` to the validation array and adds the case-insensitive name check that returns the **same** 401 as a wrong password. Token generation and `Hash::check` stay as they are. It writes `tests/Feature/LoginExtensionTest.php` with one test per criterion, runs the full suite and commits.

### Step A3 — Delivery check and blind review

Claude runs `delivery-check.sh`. It checks Node projects, keyed on `package.json` at HEAD. This Laravel app ships a Vite `package.json` with no `test` script, so the check reports `D1 FAIL` even though phpunit is green. See **delivery-check on a Laravel app** under the pitfalls; on this stack the report quotes the phpunit run instead.

Then ONE blind review agent reads the PRD and the commit range, without Claude's notes. Its fixed scope is unmet criteria, UI-only authorization, unvalidated input, secrets in code and data-integrity races. The PRD's "do not reveal which field was wrong" is one of the criteria it checks. Critical and Important findings are fixed and committed.

### Step A4 — The result contract

```
| Criterion                                             | Status | Test                                                   |
|-------------------------------------------------------|--------|--------------------------------------------------------|
| correct nip + nama + password → 200 + token           | ✓      | LoginExtensionTest::test_login_with_matching_nama      |
| wrong nama → 401, same generic error                  | ✓      | LoginExtensionTest::test_wrong_nama_is_generic_401     |
| wrong password → 401, same generic error              | ✓      | LoginExtensionTest::test_wrong_password_unchanged      |
| missing nama → 422                                    | ✓      | LoginExtensionTest::test_missing_nama_is_422           |
| existing nip + password tests still pass              | ✓      | ./vendor/bin/phpunit (full suite)                      |

delivery-check: D1 FAIL (Vite package.json, no test script) — see pitfalls; phpunit: OK (N tests)
Assumptions & decisions: strtolower on both sides (PRD: "case-insensitive"; multi-language matching is out of scope)
Commits: …
```

(Illustrative.)

## Part B — the guarded lane (the gap as an explicit contract)

```
/mega-sdd ./prd-login-extension.md --guarded
```

Chain proposal: 2 phases — `plan ./prd-login-extension.md --lite --mode=existing` → `execute-bolts --all --lite`. There is no scan phase and no bind phase. Click **Run**.

### Step B1 — `plan` sees the existing endpoint

`plan` queries the symbol index for what the unit would build (`query-symbol-index.sh --name=LoginController`). It finds a hit, and the PRD demands a change to that code, so the unit is typed **`extend`**. Its `## Migration notes` are written from the PRD-vs-code delta: the field set the PRD states, against the field set at the hit's anchor.

```
▶ Phase 1 of 2: invoking plan (./prd-login-extension.md --lite --mode=existing)
✓ Phase 1 of 2: plan → status: completed, items: 1 unit, blocked: 0
```

Inspect the unit:

```bash
cat .mega-sdd/vaults/login-extension/units/U-001.md
```

You'll see (illustrative):

```markdown
---
id: U-001
title: Add nama field to login endpoint
context_source: context.md#F-S-001
prd_source: prd-login-extension.md#required-fields-for-post-api-login
task_type: extend                                # ← symbol-index hit + the PRD demands a change
grounding_confidence: HIGH
module: M-auth
target_files:
  - path: app/Http/Controllers/Api/LoginController.php
    operation: modify
  - path: tests/Feature/LoginExtensionTest.php
    operation: create
acceptance_test:
  - type: test
    command: ./vendor/bin/phpunit --filter=LoginExtension
    expects: "OK ("                              # literal phpunit success substring; an empty expects halts acceptance_expects_missing
---

## Goal
Extend POST /api/login to validate against patient `nama` field in
addition to existing nip + password.

## Context (read first)
PRD requires three-field validation: nip + nama + password. Existing
endpoint only validates two fields (see the Migration notes delta); add
`nama` to validated input; reject when name doesn't match stored
user.name (case-insensitive).

## Anchors
- app/Http/Controllers/Api/LoginController.php:15 — existing validation rules
- app/Http/Controllers/Api/LoginController.php:19 — existing credential check (Hash::check)
- app/Models/User.php:8 — User model with name attribute

## Claims
- C-U001-01 "LoginController::store validates nip + password" — expect: app/Http/Controllers/Api/LoginController.php:store
- C-U001-02 "User model exposes name" — expect: app/Models/User.php:User

## Migration notes
- **ADD**:
  - 'nama' => 'required|string' validation rule
  - Case-insensitive comparison: strtolower($validated['nama']) === strtolower($user->name)
  - Failure case returns same 401 response (no field disclosure)
- **KEEP**:
  - nip validation (unchanged)
  - password validation (unchanged)
  - Hash::check call (unchanged)
  - Token generation (unchanged)
- **REMOVE**: (none)

## Hard rules
\`\`\`yaml
id: response-shape-locked
language: php
files: ["**/app/Http/Controllers/Api/LoginController.php"]
rule:
  pattern: "response()->json(['error' => $MSG], $CODE)"
  not:
    pattern: "response()->json(['error' => 'Invalid credentials'], 401)"
message: 401 response format preserved (security: no field disclosure)
\`\`\`

## Implementation steps

First, open LoginController.php and add 'nama' to the validation rules
at line 15 — append 'nama' => 'required|string' to the existing array.

Then, after the password Hash::check on line 19, add a case-insensitive
name comparison. If `strtolower($validated['nama'])` does NOT equal
`strtolower($user->name)`, return the SAME 401 response as wrong password
— per PRD security requirement (no field disclosure).

The Hash::check and token generation logic must NOT change. Hard Rules
above enforce this at bolt time.

## Acceptance criteria

Acceptance criteria are the frontmatter `acceptance_test:` entries (authoritative).
- POST /api/login with correct nip + nama + password → 200 + token
- POST with wrong nama (correct other fields) → 401 + generic error
- POST with wrong password (correct other fields) → 401 + same generic error
- POST missing nama → 422 validation error
- Existing tests for nip+password still pass

## Out of scope
- Updating frontend forms (different unit)
- Email notification on failed login (different feature)
```

The unit is complete and in context. The bolt knows:
- exactly which file (LoginController.php) and which lines (15 for validation, 19 for the check);
- what field to add (`nama`);
- what to preserve (token generation, response shape);
- what NOT to do (change the error message, expose which field failed).

The `## Claims` lines are a **contract**, not a verdict. `plan` never writes CONFIRMED or CONFLICT; the verdicts come from the JIT bind in `execute-bolts`.

### Step B2 — `execute-bolts`: JIT bind, then the bolt

Pre-flight 3.9 re-checks the unit's claims against HEAD just before dispatch. `write-unit-binding.sh` is the only writer of `bolts/U-001/binding.json`, and here it verdicts everything from disk and the symbol index:

```
bolts/U-001/binding.json — CONFIRMED 7 · CONFLICT 0 · OQ 0
  C-U001-A01 fs_must_exist      LoginController.php               CONFIRMED  IMPLEMENTED
  C-U001-A02 fs_must_not_exist  tests/Feature/LoginExtensionTest  CONFIRMED  NEW
  C-U001-A03 fs_must_exist      LoginController.php:15            CONFIRMED  IMPLEMENTED
  C-U001-A04 fs_must_exist      LoginController.php:19            CONFIRMED  IMPLEMENTED
  C-U001-A05 fs_must_exist      app/Models/User.php:8             CONFIRMED  IMPLEMENTED
  C-U001-01  symbol             LoginController.php:store         CONFIRMED  IMPLEMENTED
  C-U001-02  symbol             app/Models/User.php:User          CONFIRMED  IMPLEMENTED
```

(Illustrative. The `A` claims are minted from the unit itself: `target_files` (modify ⇒ must exist, create ⇒ must not exist yet), then each `## Anchors` line (the file must exist and the line range must fit). The `## Claims` lines keep their own ids.)

If someone had changed `store()` since `plan` ran, the claim would come back CONFLICT and this unit would not run until a human decides (`resolve-oq --binding`). Then the bolt runs:

```
▶ Phase 2 of 2: invoking execute-bolts (--all --lite)
▶ Bolt 1/1: U-001 "Add nama field to login endpoint"
✓ Bolt 1/1: U-001 → done in 1m40s, 0 retries, confidence 0.93, anchors 3/3 ✓, commit 5c0e9d2
✓ Phase 2 of 2: execute-bolts → status: completed, items: 1/1 bolts, blocked: 0
```

The pre-flight snapshot, the TDD steps and the post-flight verdict (`response-shape-locked → PASS`) are written to `bolts/_summary.md` and `bolts/U-001/bolt-report.md`. They are printed in chat only when a stage fails. The chain then ends with the same result contract as Part A.

### Step B3 — Verify

```bash
git log --oneline -2
# baseline + "feat(U-001): Add nama field to login endpoint"

git diff HEAD~1 app/Http/Controllers/Api/LoginController.php
# Should show:
# +            'nama' => 'required|string',
# +
# +        if (strtolower($validated['nama']) !== strtolower($user->name)) {
# +            return response()->json(['error' => 'Invalid credentials'], 401);
# +        }
```

Run tests:

```bash
./vendor/bin/phpunit --filter=LoginExtension
# All passing
./vendor/bin/phpunit
# Existing tests still pass
```

## The "ngawang" prevention in action

What the guarded lane does with the gap, compared with the two wrong readings:

| Wrong reading | What would happen | What 9.0 does about it |
|---|---|---|
| Treat as already implemented | `task_type: verify`, no code change, `nama` never added (silent gap) | `plan` types `extend` because the PRD demands a change to the hit; a `verify` unit may not modify any file |
| Treat as new | `task_type: create`, rebuild the whole login, duplicate code | a `create` unit listing an existing file fails its `must-not-exist` claim at the JIT bind: CONFLICT `ALREADY_EXISTS`, and the unit doesn't run |
| Manual prompting | You write the detailed prompt yourself | the unit's Migration notes spell out ADD / KEEP / REMOVE |

Part A gets to the same code without the artefacts: Claude reads the controller directly. On this PRD the pipeline adds traceability (a unit, a binding verdict, bolt evidence), not a better diff. The brownfield benchmark found the same: guarded surfaced the same seeded traps as plain Claude Code, at about 6× the cost (`research/2026-09-27-brownfield-results.md`).

## Common pitfalls

### delivery-check on a Laravel app

`delivery-check.sh` checks Node projects: it reads `package.json` at HEAD and runs `npm test` / `npm run build` on a `git archive` copy. A stack with no `package.json` gets `D0 SKIP`, and you run that stack's own test and build commands. A Laravel app is caught in between: it ships a Vite `package.json` with a `build` script but no `test` script, so D1 reports FAIL. Pointing `scripts.test` at `php artisan test` does not help either, because the archive copy has no `vendor/`.

Until the check learns this stack, run `./vendor/bin/phpunit` (and `npm run build` if you ship Vite assets) on a fresh clone yourself. Quote both results in the report, next to the delivery-check line. Don't mark the run PASS on the delivery-check alone.

### Guarded: the unit comes out `create`, not `extend`

There was no symbol index, because `ast-grep` is absent. `plan`'s brownfield lookups miss, and it treats the repo as greenfield with one WARN line. The JIT bind then catches the damage: a `create` target that already exists is CONFLICT `ALREADY_EXISTS`, and the bolt halts `binding_conflict`. Install ast-grep, then re-run `/mega-sdd`, whose GROUND step rebuilds the symbol index, and re-plan:

```bash
brew install ast-grep
# in Claude Code:
#   "plan ./prd-login-extension.md --lite --regenerate"
#   /mega-sdd --resume
```

### Guarded: Hard rule violation at post-flight

If you wrote your unit's Hard rules manually and the bolt fails:

```yaml
blocker:
  type: hard_rule_violated
  details:
    unit_id: U-001
    violated_rule: "response-shape-locked"
    evidence: "Pattern modified during bolt"
```

Either:
- adjust the Hard rule (the rule was too strict);
- revert with `git revert <bolt-commit>` (or fix forward), then re-run the post-flight scan;
- edit the unit and re-run the bolt.

### Existing tests fail after extension

Adding a new validation field can break tests that expected the old behaviour. The per-criterion tests should catch this (the "existing tests still pass" criterion runs the full suite). If they don't:

```bash
# Run all tests, not just new ones
./vendor/bin/phpunit

# Update old tests to include nama field if appropriate
# OR if PRD explicitly says don't break BC: adjust unit's Migration notes
```

## What you learned

- A PRD on an existing app routes to assisted by default. Claude reads the code and extends it; the result contract reports every criterion with its test.
- `--guarded` turns the gap into an explicit contract. `plan` types the unit `extend` from a symbol-index hit, and the Migration notes list ADD / KEEP / REMOVE.
- `## Claims` are a contract. The JIT bind verdicts them against HEAD when `execute-bolts` runs, and a CONFLICT stops the unit (a run-start quarantine).
- Hard rules preserve untouched logic (token generation, error response format).
- delivery-check checks Node projects; on a Laravel app, quote the stack's own test run.

## Next scenario

→ [Scenario 4 — Legacy rebuild](scenario-4-legacy-rebuild.md): biggest scenario; legacy codebase → KB → `plan --kb` → new framework.
