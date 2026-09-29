# Scenario 2 — PRD-Driven Feature

**Time**: ~30 minutes (Part A) · Part B takes several times longer
**Goal**: Build a feature in an existing project starting from a written PRD.

You'll use the [sample clinic PRD](sample-prd-clinic.md) on an existing Next.js project.

- **Part A**: the default route. A PRD on an app that already has code takes the **assisted lane**. That is plain Claude Code, plus ONE batched ask for the PRD's business decisions before coding and ONE blind review after.
- **Part B**: the **guarded lane** (`--guarded`). The spec pipeline plans units against your existing code and binds each unit's claims to that code just before it runs.

## Prerequisites

- Mega-sdd installed ([install check](README.md#before-you-start--install-check))
- Existing Next.js project (or similar — mega-sdd works with PHP, TypeScript, Python, Go, Rust)
- Recommended for Part B: `ast-grep` installed. It builds the symbol index that `plan` uses to see your existing code.

## Step 0 — Setup (both parts)

```bash
# Use your existing project, OR scaffold one:
cd ~/projects/my-clinic-system

# Verify it has some existing code
ls app/ src/ lib/

# Save the sample PRD to your project root
cp /path/to/mega-sdd/tests/scenarios/sample-prd-clinic.md ./prd-clinic.md
```

## Part A — the default route (assisted lane)

### Step A1 — Kick off mega-sdd

```
/mega-sdd ./prd-clinic.md
```

The front door runs `scripts/route-lane.sh` first (read-only, zero model tokens). On an existing app with this PRD, four signals fire:

```
lane: assisted (signals: existing_code, spec_open_items, security_surface, multi_flow) · naik ke pipeline: /mega-sdd ./prd-clinic.md --guarded `mega-sdd-trace:assisted`
```

| Signal | Evidence |
|---|---|
| `existing_code` | ≥10 git-tracked source files: an app, not a scaffold |
| `spec_open_items` | the 6 items under `§Clinic.6 Open Questions` |
| `security_surface` | auth, password, role, session, token… (≥2 distinct words outside out-of-scope lines) |
| `multi_flow` | `derive-project-scale.sh` rates the PRD `standard`, not `xs` |

There is no vault, no units and no `.mega-sdd/` writes, and no chain confirmation: the request is the go-ahead. The procedure is `plugins/mega-sdd/references/direct-lane.md`.

### Step A2 — ONE batched ask, before any code

Claude sorts the PRD's open questions first:

- **Technical** items are Claude's to decide. `OQ-CLINIC-005` (deployment target) and `OQ-CLINIC-006` (schedule-grid licence) are picked, the reason is cited, and both are listed as decisions in the final report.
- **Business** items are yours. `OQ-CLINIC-001` to `-004` (privacy regime, name visibility, cancellation window, sick-doctor handling) arrive in ONE `AskUserQuestion`, at most 4 questions. Each option carries a one-line keterangan; the recommended option is marked and "Defer" is always offered:

```
OQ-CLINIC-002 [P1] [business]:
  "Should patients see other patients' names in any schedule view?"

  ○ No — show only "Booked" for taken slots (recommended)
      keterangan: privacy-safe; relaxing it later is a UI change only
  ○ Yes — show names
      keterangan: only if the clinic explicitly wants it; check with privacy counsel
  ○ Defer
      keterangan: build with the conservative default, record it as an assumption
```

With more than 4 business items, the rest keep a stated conservative default and are listed. In a headless run, with no `AskUserQuestion`, Claude takes the most conservative, easiest-to-revert option for each and records it as an assumption. It never invents a business rule.

### Step A3 — Build, commit, delivery check

Claude implements in the main session and follows your repo's own conventions: `CLAUDE.md`, `AGENTS.md` and the existing code. It meets the delivery bar (a test per criterion through `npm test`, time zones pinned, the build passes with an empty env, every page reachable) and commits. Then it runs `delivery-check.sh` on a fresh copy of HEAD until:

```
delivery-check @ 7d41e0a (/Users/you/projects/my-clinic-system)
  D1 PASS scripts.test = vitest run
  D2 PASS npm test (TZ=UTC) exit 0
  D3 PASS npm test (TZ=Pacific/Kiritimati) exit 0
  D4 PASS npm run build on a fresh checkout, empty env: exit 0
  D5 PASS every static page route (6) is linked from another source file
VERDICT: PASS
```

### Step A4 — ONE blind review

After the check passes, Claude dispatches ONE read-only `general-purpose` agent. Its prompt contains only:

- the gateway trace line `mega-sdd-trace:assisted-review`;
- the PRD path and the commit range `<base>..HEAD`;
- the scope: unmet acceptance criteria, authorization enforced only in the UI, unvalidated input, secrets in code, data-integrity races such as double-booking or lost updates.

It does **not** get Claude's notes or criteria table, so it judges the code, not the claims. Findings come back as `severity | file:line | issue`. Claude fixes every Critical and Important finding, re-runs delivery-check and commits. Minor findings are reported, not fixed.

### Step A5 — The result contract

Same shape as every lane (illustrative):

```
| AC      | Criterion                                             | Status | Test                                      |
|---------|-------------------------------------------------------|--------|-------------------------------------------|
| AC-001  | Booking a free slot creates a booked appointment…     | ✓      | tests/booking.test.ts › books free slot   |
| AC-002  | No double-book (picker + unique constraint)           | ✓      | tests/booking.test.ts › concurrent insert |
| …       | …                                                     | …      | …                                         |
| AC-007  | WCAG 2.2 AA on every page                             | ✓      | e2e/a11y.spec.ts › axe on every route     |

delivery-check: VERDICT: PASS (9e02b17 — after the review fixes)
Review: 0 Critical · 1 Important (fixed: staff route checked role only in the UI) · 2 Minor (listed)

Assumptions & decisions:
- OQ-CLINIC-001: Defer → conservative default (no reason-for-visit text in emails) — your answer
- OQ-CLINIC-002: No names — your answer
- OQ-CLINIC-005 (tech): self-hosted + croner — repo already runs a Node server (package.json:12)
…

Commits: …
```

Every criterion in `§Clinic.5` appears in the table, with its status and the test that covers it.

## Part B — the guarded lane (spec pipeline on existing code)

Use it when the team needs the spec, the per-unit binding and the bolt evidence as an audit trail, or wants the FSD/SIT/UAT documents afterwards. The honest trade-off comes from a brownfield PRD with seeded spec-vs-code traps (n=3 per arm, `research/2026-09-27-brownfield-results.md`): the guarded pipeline surfaced the same 5/5 traps as plain Claude Code at about 6× the cost. Its value is the traceability, not better code.

### Step B1 — Ask for the pipeline

```
/mega-sdd ./prd-clinic.md --guarded
```

GROUND runs first, as a script in seconds with zero model tokens: `derive-state.sh`, the framework-pack match and the symbol index. You get ONE confirmation for the whole chain:

```
Proposed pipeline (--deep):
  1. plan ./prd-clinic.md --lite --mode=existing → context.md + units/
  2. execute-bolts --all --lite                  → bolts/ (JIT bind per unit → bolts/U-XXX/binding.json) + delivery-check

Halts may re-engage you mid-chain (test failures, business OQ
resolutions, hard-rule violations, dedup ambiguity, recommendation
reviews). Otherwise runs end-to-end silently with progress indicators.

[Run] [Edit] [Cancel]
```

There is no scan phase and no bind phase. Binding happens per unit, when `execute-bolts` starts (the up-front bind) and again before each unit's task.

### Step B2 — Phase 1: `plan` reads the PRD and your code

`plan` writes the layout-3 vault into `.mega-sdd/vaults/<slug>/`: `context.md`, `constitution.md`, `vault.json` and `units/`. Because `--mode=existing`, it types every unit against the symbol index:

| Symbol-index lookup for what the unit would build | `task_type` | What the unit carries |
|---|---|---|
| hit, and the PRD demands a change | `extend` | `## Anchors` (`file:line`), `## Claims`, `## Migration notes` (REMOVE / KEEP / ADD from the PRD-vs-code delta) |
| hit, code already does it | `verify` | `## Anchors`; no code change allowed |
| miss | `create` | a `must-not-exist` claim for each new file |

The open questions are handled as in Part A, but inside `plan`:

- tech OQs are **decided** by the AI, labelled and cited;
- P1 business OQs come in `plan`'s ONE batched ask (≤4 questions);
- an unanswered P1 business OQ stays `blocking`, and its units stay blocked at bolts.

```
▶ Phase 1 of 2: invoking plan (./prd-clinic.md --lite --mode=existing)
✓ Phase 1 of 2: plan → status: completed, items: 12 units, blocked: 0

Module breakdown:
  M-auth (3 units)         — extends the existing user/staff model for patient + staff roles
  M-booking (4 units)      — new Appointment + Service models + booking flow
  M-reminders (2 units)    — reminder sweep + email for the 24-hour reminder
  M-admin (3 units)        — doctor/receptionist schedule views
```

Inspect a unit that extends existing code:

```bash
cat .mega-sdd/vaults/<slug>/units/U-001.md
```

Illustrative, and Laravel-shaped. On the Next.js sample expect `src/db/schema.ts`, a Drizzle migration and `tests/…test.ts`:

```markdown
---
id: U-001
title: Extend User model with patient fields
context_source: context.md#Data-model
prd_source: prd-clinic.md#clinic-4-data-model
task_type: extend                        # ← symbol-index hit + the PRD demands new fields
grounding_confidence: HIGH
module: M-auth
target_files:
  - path: app/Models/User.php
    operation: modify
  - path: database/migrations/2026_05_21_add_patient_fields_to_users.php
    operation: create
  - path: tests/Unit/PatientUserTest.php
    operation: create
acceptance_test:
  - type: test
    command: ./vendor/bin/phpunit --filter=PatientUserTest
    expects: "OK ("                       # a literal substring phpunit prints on success; an empty expects is flagged acceptance_expects_missing (fails plan Step 5)
---

## Anchors
- app/Models/User.php:12 — existing User model
- database/migrations/2014_10_12_create_users_table.php:14 — base schema

## Claims
- C-U001-01 "User model exists with email + password" — expect: app/Models/User.php:User
- C-U001-02 "base users migration exists" — expect: database/migrations/2014_10_12_create_users_table.php — must-exist

## Hard rules
- DO NOT modify database/migrations/2014_10_12_create_users_table.php

## Migration notes
- **ADD**: phone (string, nullable), role (enum: patient/doctor/receptionist)
- **KEEP**: email, password, name, created_at, updated_at
- **REMOVE**: (none)
```

The unit states which fields to ADD (phone, role) and which to KEEP (email, password). The Hard rule keeps the bolt away from the base migration. The claims are a **contract**, not a verdict: `plan` never writes CONFIRMED or CONFLICT.

### Step B3 — Phase 2: `execute-bolts` (JIT bind, then bolts)

Before any task runs, the up-front bind binds every pending unit just in time (each task re-binds its unit again):

- `derive-unit-claims.sh` collects the claims;
- `write-unit-binding.sh`, the only writer, records a verdict per claim in `bolts/U-XXX/binding.json`. The script verdicts filesystem claims on disk and symbol claims against the symbol index. Free-text claims go through a fixed evidence ladder that never confirms by absence.

A CONFLICT, meaning the code contradicts the unit's claim, blocks **that unit**: `derive-exec-plan.sh` quarantines it at run start. The others proceed, and its dependents are skipped with the reason.

```
▶ Phase 2 of 2: invoking execute-bolts (--all --lite)
  jit_bind: units 4 · fs_claims 9 · symbol_claims 3 · text_claims 0
▶ Bolt 1/12: U-001 "Extend User model with patient fields"
✓ Bolt 1/12: U-001 → done in 1m23s, 0 retries, confidence 0.92, anchors 2/2 ✓, commit 8a3f2e1
…
✓ execute-bolts batch complete: 12/12 done, 0 halted
```

Each bolt is one atomic commit that:

- implements ONE unit and has passing tests;
- touches nothing outside its `target_files` whitelist (the B3 whitelist observer checks the commit);
- passed the L0 gates and the detect-after scans (Hard-rule post-flight, acceptance); ONE blind review of the whole run range closes the run.

The chain ends with `delivery-check.sh` and the same result contract as Part A: criterion → test table, the `VERDICT:` line of the last commit, and the assumptions and decisions (the AI's tech decisions and your OQ answers).

### Step B4 — Verify

```bash
git log --oneline -15
# one commit per unit

bun run db:migrate            # drizzle-kit migrate
bun test && bunx playwright test
bun dev
```

Want the tool-agnostic `AGENTS.md` export? Say "emit agents.md" (the chain skips it by default). Team documents: `/mega-sdd:emit fsd|sit|uat`.

## Common pitfalls

### Assisted: the ask arrives with 4 questions and you know only 2 answers

Pick "Defer" for the others. Claude builds with the stated conservative default and lists it as an assumption, so you can revisit it later.

### Guarded: a unit halts on `binding_conflict`

The code contradicts what the unit expected. Example:

```yaml
blocker:
  type: binding_conflict
  details:
    unit_id: U-004
    binding: .mega-sdd/vaults/<slug>/bolts/U-004/binding.json
    conflicts:
      - id: C-U004-02
        kind: text
        expect: "Staff auth uses Better Auth sessions"
        anchor: src/auth.ts:8
        evidence: "Auth uses Auth.js / NextAuth (existing pattern)"
        suggested_action: KEEP_CODE
        suggested_action_rationale: "NextAuth is wired into every staff route today"
```

The resolution codes:

- **KEEP_VAULT** — the code must change to follow the spec: migrate to Better Auth.
- **KEEP_CODE** — the spec is updated to match the code: keep NextAuth.
- **DEFER** — becomes an OQ the unit carries.
- **SPLIT** — the claim is broken into sub-claims.

Say "resolve open questions --binding" (it routes to resolve-oq). A converging `--deep` chain enters it on its own; add `--no-converge` if you want to review CONFLICTs yourself. The verdict is recorded through `write-unit-binding.sh --resolve`, never by editing `binding.json` by hand. Then `/mega-sdd --resume`.

### Guarded: a bolt halts on `hard_rule_violated`

A bolt modified a locked file. The check runs after the fact: the bolt commit has already landed, the post-flight scan halts the run, and the B1 gate blocks every further `execute-bolts` until the flagged commit is fixed forward or reverted.

```yaml
blocker:
  type: hard_rule_violated
  details:
    unit_id: U-001
    violated_rule: "DO NOT modify database/migrations/2014_10_12_create_users_table.php"
    evidence: "File modified during bolt; sha256 changed"
```

Options:

1. Revert with `git revert <bolt-commit>` (or fix forward), then re-run the post-flight scan.
2. Edit the unit: change the Hard rule, or move the logic to a new migration.

There is no accept-risk path. The B1 gate stays closed until a passing `postflight.json` is recorded.

### Guarded: `grounding_confidence: LOW` units

Review them before the bolts run: add `--stop-after=plan`, read the units, then `/mega-sdd --resume`. The usual reasons are a vague PRD claim, an absent symbol index (install `ast-grep`), or anchors pointing at files that don't exist. Fix the PRD or the unit, then re-plan with `plan ./prd-clinic.md --lite --regenerate`, which keeps units authored by hand.

## What you learned

- A PRD on an existing app takes the assisted lane by default: one batched business ask before coding, one blind review after, and the delivery check.
- Tech questions are decided and cited by the AI; business questions are always yours.
- `--guarded` plans units against your code (`create` / `extend` / `verify` from the symbol index, `extend` with explicit ADD / KEEP / REMOVE) and binds each unit's claims just before it runs. A CONFLICT stops only that unit.
- Every lane ends with the same result contract.

## Next scenario

→ [Scenario 3 — Field-level extension](scenario-3-field-extension.md): the specific case where the PRD says X fields and the code has Y.
