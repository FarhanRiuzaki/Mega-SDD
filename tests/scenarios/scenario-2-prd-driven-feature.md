# Scenario 2 — PRD-Driven Feature

**Time**: ~30 minutes
**Goal**: Build a feature in an existing project starting from a written PRD.

You'll use the [sample clinic PRD](sample-prd-clinic.md) on an existing Next.js project. Mega-sdd will scan the codebase, bind PRD claims against it, and generate units that respect existing patterns.

## Prerequisites

- Mega-sdd installed ([install check](README.md#before-you-start--install-check))
- Existing Next.js project (or similar — mega-sdd works with PHP, TypeScript, Python, Go, Rust)
- Recommended: `tree-sitter` + `ast-grep` installed for AST precision

## Step 1 — Setup

```bash
# Use your existing project, OR scaffold one:
cd ~/projects/my-clinic-system

# Verify it has some existing code
ls app/ routes/ database/

# Save the sample PRD to your project root
cp /path/to/mega-sdd/tests/scenarios/sample-prd-clinic.md ./prd-clinic.md
```

## Step 2 — Kick off mega-sdd

```
/mega-sdd ./prd-clinic.md
```

Mega-sdd detects:
- Input is `.md` file → PRD Mode A
- Existing code present → brownfield
- No vault → starts from `generate-intent`
- Express spine (default): GROUND already ran as a script (framework pack + symbol index) — no scan phase; add `--classic` for the full `codebase-map.md` lane

Chain proposal:

```
Proposed pipeline (--deep):
  1. generate-intent ./prd-clinic.md
  2. bind-codebase --express                  → binding.md + bound vault
  3. generate-units                           → atomic units with field-level diff
  4. execute-bolts                            → code commits per unit

Halts may re-engage you on conflicts, business OQs, hard-rule violations.

[Run] [Edit] [Cancel]
```

## Step 3 — Generate-intent reads the PRD

Mega-sdd extracts vault from PRD. Most info auto-parsed; minimal Q&A. Outputs:
- 7 vault files
- ~8 OQs (per PRD's "Open questions" section + auto-classifier additions)

```
✓ Phase 1 of 4: generate-intent → vault: 9 OQs (4 P1 business, 3 P2 tech, 2 P3)
```

## Step 4 — Resolve P1 business OQs

Mega-sdd surfaces context-aware recommendations. For PRD's listed OQs:

```
OQ-001 [P1] [business / blocking]:
  "Do we need to comply with patient data privacy regulations (HIPAA / GDPR)?"
  
  ⚠️ High-stakes business OQ. Review carefully.
  
  No confident recommendation (no project memory for this domain yet).
  
  Options:
    1. Yes — HIPAA-compliant (US clinic)
    2. Yes — GDPR-compliant (EU clinic)
    3. No — non-regulated jurisdiction
    4. Defer to legal team
```

Pick based on your context. Memory writes decision; future similar OQs in this project will reference this.

After all P1 resolved:

```
✓ Phase 1 resumed: all P1 business OQs resolved (4 resolved)
```

## Step 5 — Scan codebase + bind

Mega-sdd inspects existing code:

```
  Found: 47 classes, 142 methods, 12 routes, 6 models
  Test framework: vitest + playwright
  Naming: PascalCase classes; kebab-case routes
```

Then binding:

```
▶ Phase 2 of 4: invoking bind-codebase --express
✓ Phase 2 of 4: bind-codebase → 28 claims, 0 conflicts
  Implementation State Map:
    NEW: 22 (greenfield additions for new feature)
    IMPLEMENTED: 4 (existing User model, Auth middleware)
    PARTIAL_FIELDS_MISSING: 2 (existing models need new fields)
    UNKNOWN: 0
  Tech-OQ auto-resolved (scan): 3 (test framework, naming convention, error format)
  Tech-OQ recommendations surfaced: 1 (Better Auth vs Auth.js)
```

Two PARTIAL_FIELDS_MISSING claims signal the field-level diff the binding pass catches — e.g., your existing User model has `email + password` but PRD adds `phone` for patient role.

## Step 6 — Generate units with module grouping

```
▶ Phase 3 of 4: invoking generate-units
✓ Phase 3 of 4: generate-units → 12 units
  [auto] lint-units: 11 HIGH | 1 MEDIUM | 0 LOW grounding; anchors 28/28 verified
  [auto] analyze-parallelism: max width 4 | speedup 2.4x

Module breakdown:
  M-auth (3 units)         — extends existing User model for patient role
  M-booking (4 units)      — new Appointment + Service models + booking flow
  M-reminders (2 units)    — Mailable + scheduled job for 24-hour reminders
  M-admin (3 units)        — Doctor/Receptionist auth flows + schedule views
```

Inspect units that extend existing code:

```bash
cat .mega-sdd/vaults/<slug>/units/U-001.md
```

You'll see:

```markdown
---
id: U-001
title: Extend User model with patient fields
module: M-auth
task_type: extend                        # ← key: PARTIAL_FIELDS_MISSING
vault_source: 03-data-model.md#Patient
grounding_confidence: HIGH
target_files:
  - path: app/Models/User.php
    operation: modify
  - path: database/migrations/2026_05_21_add_patient_fields_to_users.php
    operation: create
  - path: tests/Unit/PatientUserTest.php
    operation: create
---

## Migration notes
- **ADD**: phone (string, nullable), role (enum: patient/doctor/receptionist)
- **KEEP**: email, password, name, created_at, updated_at
- **REMOVE**: (none)

## Anchors
- app/Models/User.php:12 — existing User model
- database/migrations/2014_10_12_create_users_table.php:14 — base schema

## Hard rules
\`\`\`yaml
id: do-not-modify-existing-users-cols
language: php
rule:
  pattern: $$$
  inside:
    file: database/migrations/2014_10_12_create_users_table.php
fix: forbidden
message: Base users table is locked; new fields go in separate migration
\`\`\`
```

The unit knows exactly what fields to ADD (phone, role) while preserving existing (email, password). Bolt won't accidentally rewrite the base table.

## Step 7 — Execute bolts

```
▶ Phase 4 of 4: invoking execute-bolts --per-squad --parallel
  Wave 1 (4 parallel): U-001 U-005 U-008 U-010
  ✓ Wave 1 complete
  Wave 2 (3 parallel): U-002 U-006 U-009
  ✓ Wave 2 complete
  Wave 3 (3 parallel): U-003 U-007 U-011
  ✓ Wave 3 complete
  Wave 4 (2 sequential): U-004 U-012
  ✓ Wave 4 complete
✓ Phase 4 of 4: execute-bolts → 12/12 complete (0 halts; 8 min total)
  [auto] list-modules: 4/4 modules completed
  [auto] emit-agents-md: AGENTS.md regenerated
```

Atomic git commits, one per unit. Each commit:
- Implements ONE specific feature
- Has passing tests
- Doesn't touch files outside its target_files whitelist
- Hard Rules validated pre/post-flight

## Step 8 — Verify

```bash
git log --oneline -15
# Shows 12 atomic commits

bun run db:migrate            # drizzle-kit migrate
# Applies the patient fields migration

bun test && bunx playwright test
# All tests pass (new + existing)

bun dev
# Visit / — clinic app live
```

Open `AGENTS.md` — tool-agnostic export listing project shape, test commands, conventions, key decisions.

## Common pitfalls

### Phase 3 halts on bind_conflict

PRD says X, code says Y, mega-sdd can't reconcile automatically.

Example:

```yaml
blocker:
  type: bind_conflict
  details:
    conflicts:
      - id: C-007
        vault_claim: "Staff auth uses Better Auth sessions"
        codebase_reality: "Auth uses Auth.js / NextAuth (existing pattern)"
        suggested_resolutions:
          - KEEP_CODE — preserve existing NextAuth session auth
          - KEEP_VAULT — migrate to Better Auth
          - SPLIT — keep NextAuth for now; migrate to Better Auth in a follow-up
```

Say "resolve open questions --binding" (routes to resolve-oq; a converging `--deep` chain also enters it itself). Walks each conflict interactively. Pick KEEP_VAULT if PRD trumps code; KEEP_CODE if existing pattern is canonical; SPLIT for nuanced cases.

After resolution: `/mega-sdd --resume`.

### Phase 5 halts on hard_rule_violated

A bolt modified a locked file. Detect-after: the bolt commit already landed; the post-flight scan halts the run and the B1 gate blocks every further `execute-bolts` until the flagged commit is fixed-forward or reverted.

```yaml
blocker:
  type: hard_rule_violated
  details:
    unit_id: U-001
    violated_rule: "DO NOT modify database/migrations/2014_10_12_create_users_table.php"
    evidence: "File modified during bolt; sha256 changed"
```

Options:
1. Revert: `git checkout database/migrations/2014_10_12_create_users_table.php` + re-run unit
2. Edit unit: change Hard Rule OR move logic to new migration
3. Force: say "execute bolts U-001 --force" (accepts risk)

### grounding_confidence: LOW units

If the chain lint pass shows LOW units, review them before bolts. Reasons:
- Vault claim too vague
- Codebase-map gaps (some files not indexed)
- Anchors point to non-existent file

Fix vault, then say "bind vault to code" + "generate units --refresh".

## What you learned

- PRD-driven flow detects existing code + binds against it
- PARTIAL_FIELDS_MISSING catches field-level gaps automatically
- Modules group units semantically (M-auth, M-booking, etc.)
- Hard Rules protect existing code from unintended changes
- Per-squad + per-wave parallelism speeds up execution

## Next scenario

→ [Scenario 3 — Field-level extension](scenario-3-field-extension.md): the specific case where PRD says X fields and code has Y.
