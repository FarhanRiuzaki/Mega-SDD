# Scenario 3 — Field-Level Extension

**Time**: ~20 minutes
**Goal**: Add a missing field to an existing model. Demonstrates Iter 8's PARTIAL_FIELDS_MISSING auto-detection — the "PRD says (nip, nama, password), code has (nip, password), skill should know to add `nama`" use case.

## Prerequisites

- Mega-sdd v3.40.0+
- Existing PHP/Laravel project with at least one model + endpoint
- `tree-sitter` + `ast-grep` installed (required for field-level diff; otherwise falls back to binary state)

```bash
brew install tree-sitter-cli ast-grep
command -v tree-sitter && command -v ast-grep && echo "✓ ready"
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

## Step 1 — Run mega-sdd auto

```
/mega-sdd:auto ./prd-login-extension.md
```

Chain proposal: 5 phases (generate-intent → scan → bind → units → bolts). Click **Run**.

## Step 2 — Watch the field-level magic

After `bind-codebase` completes:

```
▶ Phase 3 of 5: invoking bind-codebase
✓ Phase 3 of 5: bind-codebase → 2 claims, 0 conflicts
  Implementation State Map:
    C-001 (POST /api/login endpoint exists)            | CONFIRMED | IMPLEMENTED | LoginController.php:12 | high
    C-002 (POST /api/login accepts {nip, nama, password}) | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:15 | high
                                                                              field_diff: ADD: [nama] · KEEP: [nip, password] · REMOVE: []
```

The KEY moment: bind-codebase detected that **endpoint exists but is missing the `nama` field**. PARTIAL_FIELDS_MISSING state with explicit field diff.

## Step 3 — Generated unit knows EXACTLY what to do

```
▶ Phase 4 of 5: invoking generate-units
✓ Phase 4 of 5: generate-units → 1 unit
  [auto] lint-units: 1 HIGH grounding | anchors 2/2 verified
```

Inspect the unit:

```bash
cat .mega-sdd/vaults/login-extension/units/U-001.md
```

You'll see:

```markdown
---
id: U-001
title: Add nama field to login endpoint
module: M-auth
task_type: extend                                # ← from PARTIAL_FIELDS_MISSING state
vault_source: 04-flows.md#POST-login
grounding_confidence: HIGH
target_files:
  - path: app/Http/Controllers/Api/LoginController.php
    operation: modify
  - path: tests/Feature/LoginExtensionTest.php
    operation: create
---

## Goal
Extend POST /api/login to validate against patient `nama` field in
addition to existing nip + password.

## Context (read first)
PRD requires three-field validation: nip + nama + password. Existing
endpoint only validates two fields. Per Iter 8 PARTIAL_FIELDS_MISSING
analysis, add `nama` to validated input; reject when name doesn't
match stored user.name (case-insensitive).

## Anchors
- app/Http/Controllers/Api/LoginController.php:15 — existing validation rules
- app/Http/Controllers/Api/LoginController.php:18 — existing credential check
- app/Models/User.php:8 — User model with name attribute

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
id: do-not-modify-token-generation
language: php
rule:
  pattern: |
    $token = $user->createToken($$$);
  inside:
    file: app/Http/Controllers/Api/LoginController.php
  not:
    matches:
      pattern: $$$createToken('login')$$$
message: Token generation logic locked
\`\`\`

\`\`\`yaml
id: response-shape-locked
language: php
rule:
  pattern: |
    return response()->json(['error' => $$$], 401);
fix: forbidden-when-modified
message: 401 response format preserved (security: no field disclosure)
\`\`\`

## Implementation steps

First, open LoginController.php and add 'nama' to the validation rules
at line 15 — append 'nama' => 'required|string' to the existing array.

Then, after the password Hash::check on line 18, add a case-insensitive
name comparison. If `strtolower($validated['nama'])` does NOT equal
`strtolower($user->name)`, return the SAME 401 response as wrong password
— per PRD security requirement (no field disclosure).

The Hash::check and token generation logic must NOT change. Hard Rules
above enforce this at bolt time.

## Acceptance criteria

- POST /api/login with correct nip + nama + password → 200 + token
- POST with wrong nama (correct other fields) → 401 + generic error
- POST with wrong password (correct other fields) → 401 + same generic error
- POST missing nama → 422 validation error
- Existing tests for nip+password still pass

## Out of scope
- Updating frontend forms (different unit)
- Email notification on failed login (different feature)
```

The unit is COMPLETE and CONTEXTUAL. Bolt knows:
- Exactly which file (LoginController.php)
- Exactly which line (15 for validation, 18 for check)
- What field to add (`nama`)
- What to preserve (token gen, response shape)
- What NOT to do (change error message, expose field)

## Step 4 — Execute bolt

```
▶ Phase 5 of 5: invoking execute-bolts
  Pre-flight: snapshot LoginController.php sha256, snapshot token gen pattern
  Running superpowers TDD...
  ✓ Test added (tests/Feature/LoginExtensionTest.php)
  ✓ Implementation: nama field validated in LoginController.php
  Post-flight: Hard Rule do-not-modify-token-generation → PASS (token gen unchanged)
  Post-flight: response-shape-locked → PASS (401 response preserved)
  ✓ Commit: "feat: validate nama field on POST /api/login (extend)"
✓ Phase 5 of 5: execute-bolts → 1/1 complete
```

## Step 5 — Verify

```bash
git log --oneline -2
# baseline + "feat: validate nama field on POST /api/login (extend)"

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

Without Iter 8 PARTIAL_FIELDS_MISSING detection, alternative outcomes would have been:

| Without Iter 8 | What would happen | Problem |
|---|---|---|
| Treat as IMPLEMENTED | task_type=verify, no code change | nama field never added (silent gap) |
| Treat as NEW | task_type=create, rebuild whole login | Duplicates existing code; conflict |
| Manual prompting needed | User has to write detailed prompt | Slow; error-prone |

With Iter 8: skill DETECTS the gap, generates an extend unit that knows exactly what to ADD vs KEEP vs REMOVE. Bolt's prompt is precise. No "ngawang".

## Common pitfalls

### Field-level diff not firing

Check `codebase-map.md` frontmatter:

```bash
head -10 .mega-sdd/codebase/codebase-map.md
```

Need `precision_tier: ast` (tree-sitter engine). If `precision_tier: regex`, field-level analysis disabled; falls back to v1.6 binary (IMPLEMENTED or NEW).

Install tree-sitter + re-run scan-codebase:

```bash
brew install tree-sitter-cli
/mega-sdd:scan-codebase --engine=tree-sitter
/mega-sdd:bind-codebase
/mega-sdd:generate-units --refresh
```

### Hard rule violation in pre-flight

If you wrote your unit's Hard rules manually and bolt fails:

```yaml
blocker:
  type: hard_rule_violated
  details:
    unit_id: U-001
    violated_rule: "response-shape-locked"
    evidence: "Pattern modified during bolt"
```

Either:
- Adjust Hard Rule (rule too strict)
- Revert code change (`git checkout app/Http/Controllers/Api/LoginController.php`)
- Edit unit + re-run bolt

### Existing tests fail after extension

Sometimes adding new field validation breaks tests that expected old behavior. Mega-sdd's acceptance_test should catch this in TDD cycle. If not:

```bash
# Run all tests, not just new ones
./vendor/bin/phpunit

# Update old tests to include nama field if appropriate
# OR if PRD explicitly says don't break BC: adjust unit's Migration notes
```

## What you learned

- Iter 8 PARTIAL_FIELDS_MISSING auto-detects field gaps between PRD and code
- Generated unit's Migration notes EXPLICITLY list ADD / KEEP / REMOVE
- Hard rules preserve untouched logic (token gen, error response format)
- bolt's prompt is contextually precise — no "ngawang"
- Single PRD update + single auto command + ONE atomic commit = feature done

## Next scenario

→ [Scenario 4 — Legacy rebuild](scenario-4-legacy-rebuild.md): biggest scenario; legacy codebase → KB → vault → new framework.
