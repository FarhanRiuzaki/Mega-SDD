# Scenario 1 — Greenfield from Idea

**Time**: ~15 minutes
**Goal**: Run mega-sdd end-to-end on a fresh idea (no PRD, no existing code). Get a working Laravel feature shipped with passing tests.

You'll start with just a sentence ("build a clinic appointment system") and end with committed code + passing tests.

## Prerequisites

- Mega-sdd installed ([install check](README.md#before-you-start--install-check))
- Empty (or new) Laravel 11 project (or just an empty directory — `composer create-project` not strictly required for this scenario; mega-sdd can scaffold structure)
- Recommended: `tree-sitter` + `ast-grep` installed (optional; precision boost)

```bash
# Verify install
command -v tree-sitter && command -v ast-grep && echo "✓ ready"
```

## Step 1 — Create empty project dir

```bash
mkdir ~/playground/clinic-app
cd ~/playground/clinic-app
git init
```

## Step 2 — Kick off mega-sdd auto

In Claude Code session at the new dir:

```
/mega-sdd:auto "build a clinic appointment system for a small medical clinic — patients self-book, doctors view schedules, email reminders 24 hours before appointment"
```

Mega-sdd detects:
- Input is quoted free-text → Mode B brief
- No existing code → greenfield
- No vault → starts from `generate-intent`

You'll see a chain proposal:

```
Proposed pipeline (--deep):
  1. generate-intent --from-prompt "build a clinic appointment system..."
  2. generate-units                                  → atomic implementation units
  3. execute-bolts --all                             → code commits per unit

Halts may re-engage you mid-chain (test failures, business OQ resolutions,
hard-rule violations, dedup ambiguity, recommendation reviews). Otherwise
runs end-to-end silently with progress indicators.

[Run] [Edit] [Cancel]
```

Click **Run**.

## Step 3 — Phase 1: generate-intent Q&A

Mega-sdd opens an interactive Q&A (≤10 questions) to extract concrete spec from your one-sentence brief. You'll be asked things like:

- Project shape? → **web-app**
- Implementation mode? → **new** (greenfield)
- Tech stack preference? → **Laravel 11 + MySQL** (or accept defaults)
- Output mode? → **compact** (recommended for first run)
- Auth approach? → **Laravel Sanctum**

Answer based on the [sample PRD](sample-prd-clinic.md) if you want exact reproduction. Or improvise — mega-sdd accepts your choices.

After Q&A, mega-sdd writes vault to `.mega-sdd/vaults/clinic-app/` (or similar slug):
- `00-index.md` — navigation + OQ roll-up
- `01-overview.md` through `06-constraints.md` — 7-file spec
- `vault.json` — manifest

You'll see chat output:
```
✓ Phase 1 of 3: generate-intent → 9 OQs (3 P1 business, 4 P2 tech, 2 P3 refinement)
```

## Step 4 — Phase 1.5: Resolve P1 business OQs

If any P1 business OQs exist, mega-sdd pauses chain with:

```
⏸ Phase 1 paused: 2 P1 business OQs need resolution.
  OQ-FL-002: Should patients see other patients' names? (privacy)
  OQ-CN-001: HIPAA/GDPR compliance scope?
Run: /mega-sdd:resolve-oq to walk these interactively.
```

Run `/mega-sdd:resolve-oq`. Walks each P1 OQ:

```
OQ-FL-002 [P1] [business / blocking]:
  "Should patients see other patients' names in schedule view?"
  
  Recommendation: No — show only "Booked" for occupied slots (recommended)
  Rationale: Privacy default; common pattern for booking systems.
  Source: ~/.mega-sdd/memory/patterns.md §privacy-booking (3/3 past projects)
  Fallback-if-wrong: If clinic explicitly wants visible names (small-team
    practice), revisit with privacy lawyer.
  Confidence: HIGH
  
  Options:
    1. No — show "Booked" only (recommended)
    2. Yes — show names
    3. Defer (revisit later)
```

Pick (1). Memory writes decision. Resume:

```
/mega-sdd:auto --resume
```

Chain continues.

## Step 5 — Phase 2: generate-units

After OQ resolution, mega-sdd generates atomic units. For clinic system, expect ~12-15 units:

```
▶ Phase 2 of 3: invoking generate-units
✓ Phase 2 of 3: generate-units → 14 units
  [auto] lint-units: 13 HIGH | 1 MEDIUM | 0 LOW grounding; anchors 14/14 verified
  [auto] analyze-parallelism: max width 5 | speedup 2.8x | wave plan ready
```

Mega-sdd auto-invokes lint + analyze (Iter 13 consolidation). Each unit:
- Atomic (~1 PR-sized commit; <300 LOC)
- Has Anchors citing Laravel patterns
- Has acceptance_test (PHPUnit)
- Has Hard Rules (ast-grep YAML if v2 grammar installed)
- Has grounding_confidence: HIGH (with full context)

Inspect units:

```bash
ls .mega-sdd/vaults/clinic-app/units/
# U-001.md, U-002.md, ... U-014.md, _index.md
```

`_index.md` shows units grouped by module:
- M-auth (3 units)
- M-booking (4 units)
- M-reminders (2 units)
- M-admin-schedule (3 units)
- M-data-model (2 units)

## Step 6 — Phase 3: execute-bolts

Mega-sdd auto-runs `execute-bolts --per-squad --parallel` (single squad mode in this scenario):

```
▶ Phase 3 of 3: invoking execute-bolts (using wave plan)
  Wave 1 (5 parallel): U-001 U-002 U-003 U-004 U-005
  ✓ Wave 1 complete in 4 min
  Wave 2 (5 parallel): U-006 U-007 U-008 U-009 U-010
  ✓ Wave 2 complete in 5 min
  Wave 3 (4 parallel): U-011 U-012 U-013 U-014
  ✓ Wave 3 complete in 4 min
✓ Phase 3 of 3: execute-bolts → 14/14 bolts complete (0 halts, 13 min total)
  [auto] list-modules: 5/5 modules completed; DoD all passing
  [auto] emit-agents-md: AGENTS.md updated at repo root
```

Total wall-clock for execution: ~13 minutes (vs ~40 min sequential).

## Step 7 — Verify

```bash
# Check committed work
git log --oneline -20

# Run all tests
./vendor/bin/phpunit
# Or if Laravel not scaffolded yet, mega-sdd will have run via superpowers TDD
# in isolated environment

# View tool-agnostic export
cat AGENTS.md
```

You should see:
- 14 atomic commits (one per unit)
- All PHPUnit tests passing
- `AGENTS.md` at root with project overview, build commands, test commands, conventions

## Step 8 — Memory review (if pending)

```
📋 Final summary:
   Phases: 3/3 completed
   Quality: HIGH across all units
   Memory: 1 learning suggestion pending → /mega-sdd:memory review
```

If memory pending:

```
/mega-sdd:memory review
```

Walks any pending learning suggestions (e.g., "OUTPUT_MODE: compact picked 1/1 times — make default?"). User accepts/rejects.

## Common pitfalls

### Pipeline halts during Q&A

If you skip too many questions, mega-sdd flags vault as too-vague (lots of OQs). Either:
- Answer the questions more concretely
- Accept and resolve as P1 OQs in Step 4

### Phase 3 halts on test_fail

A bolt's acceptance test failed 3 times. Read the bolt-report:

```bash
cat .mega-sdd/vaults/clinic-app/bolts/U-XXX/bolt-report.md
```

Common causes:
- PHPUnit not installed (run `composer require --dev phpunit/phpunit`)
- Database not migrated (run `php artisan migrate`)
- Test references file that doesn't exist (unit may be missing target_file dependency)

Resolve, then `/mega-sdd:auto --resume`.

### Wall-clock longer than 15 min

Acceptable for greenfield. Optimization targets:
- Run with `--parallel` (already default in `auto` chain via wave plan)
- Skip non-essential phases via `--stop-after=generate-units` if you want to review units before bolts

## What you learned

- `/mega-sdd:auto` runs the FULL pipeline from a single sentence
- Auto-detect handles greenfield (no PRD, no code)
- Memory + recommendations help with OQs
- Anti-halu rails fire on real issues; auto-continues otherwise
- ONE command + minimal interaction = working code with tests

## Next scenario

→ [Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md): start from a real PRD file.
