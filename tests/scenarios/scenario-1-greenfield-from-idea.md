# Scenario 1 — Greenfield from Idea

**Time**: ~15 minutes
**Goal**: Run mega-sdd end-to-end on a fresh idea (no PRD, no existing code). Get a working Next.js feature shipped with passing tests.

You'll start with just a sentence ("build a clinic appointment system") and end with committed code + passing tests.

## Prerequisites

- Mega-sdd installed ([install check](README.md#before-you-start--install-check))
- Empty (or new) Next.js project (or just an empty directory — `bunx create-next-app` not strictly required for this scenario; mega-sdd can scaffold structure)
- Recommended: `ast-grep` installed (optional; precision boost)

```bash
# Verify install
command -v ast-grep && echo "✓ ready"
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
/mega-sdd --greenfield "build a clinic appointment system for a small medical clinic — patients self-book, doctors view schedules, email reminders 24 hours before appointment"
```

(Without `--greenfield`, a `no_starterkit_detected` confirmation comes first — the flag skips that question upfront.)

Mega-sdd detects:
- Input is quoted free-text → Mode B brief
- No existing code → greenfield
- No vault → starts from `generate-intent`

You'll see a chain proposal:

```
Proposed pipeline (--deep):
  1. generate-intent --from-prompt "build a clinic appointment system..."
  2. generate-units                                  → atomic implementation units
  3. execute-bolts --all --parallel                  → code commits per unit

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
- Tech stack preference? → **Next.js 16 + Bun + PostgreSQL** (or accept defaults)
- Output mode? → **compact** (recommended for first run)
- Auth approach? → **Better Auth**

Answer based on the [sample PRD](sample-prd-clinic.md) if you want exact reproduction. Or improvise — mega-sdd accepts your choices.

After Q&A, mega-sdd writes vault to `.mega-sdd/vaults/clinic-app/` (or similar slug):
- `vault.md` — frontmatter lock scalars + Overview/Architecture/Decisions
- `model.md` — entities
- `flows.md` — Mermaid flows + DoD
- `constraints.md` — constraints + the one authored `## Open Questions` home (`[origin:]` tokens)
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
Say "resolve open questions" to walk these interactively.
```

Say "resolve open questions" (or let the halted chain invoke resolve-oq itself). Walks each P1 OQ:

```
OQ-FL-002 [P1] [business / blocking]:
  "Should patients see other patients' names in schedule view?"
  
  Recommendation: No — show only "Booked" for occupied slots (recommended)
  Rationale: Privacy default; common pattern for booking systems.
  Fallback-if-wrong: If clinic explicitly wants visible names (small-team
    practice), revisit with privacy lawyer.
  Confidence: HIGH
  
  Options:
    1. No — show "Booked" only (recommended)
    2. Yes — show names
    3. Defer (revisit later)
```

Pick (1). The resolution lands in the vault (`constraints.md ## Open Questions`, status: resolved). Resume:

```
/mega-sdd --resume
```

Chain continues.

## Step 5 — Phase 2: generate-units

After OQ resolution, mega-sdd generates atomic units. For clinic system, expect ~12-15 units:

```
▶ Phase 2 of 3: invoking generate-units
✓ Phase 2 of 3: generate-units → 14 units
```

Mega-sdd auto-invokes lint + analyze. Each unit:
- Atomic (~1 PR-sized commit; <300 LOC)
- Has Anchors citing Next.js patterns
- Has acceptance_test (Vitest/Playwright)
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

Mega-sdd auto-runs `execute-bolts --all --parallel` (single squad in this scenario — `--per-squad` needs ≥2 squads):

```
▶ Phase 3 of 3: invoking execute-bolts (using wave plan)
  Wave 1 (5 parallel): U-001 U-002 U-003 U-004 U-005
  ✓ Wave 1 complete in 4 min
  Wave 2 (5 parallel): U-006 U-007 U-008 U-009 U-010
  ✓ Wave 2 complete in 5 min
  Wave 3 (4 parallel): U-011 U-012 U-013 U-014
  ✓ Wave 3 complete in 4 min
✓ Phase 3 of 3: execute-bolts → 14/14 bolts complete (0 halts, 13 min total)
```

Total wall-clock for execution: ~13 minutes (vs ~40 min sequential).

## Step 7 — Verify

```bash
# Check committed work
git log --oneline -20

# Run all tests
bun test && bunx playwright test
# Or if Next.js not scaffolded yet, mega-sdd will have run via superpowers TDD
# in isolated environment

# Tool-agnostic export: run "generate AGENTS.md" on demand if you want it
```

You should see:
- 14 atomic commits (one per unit)
- All Vitest/Playwright tests passing
- If you want the tool-agnostic `AGENTS.md` export, run "generate AGENTS.md" on demand (auto-emit is classic-spine only)

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
- Test runner not installed (run `bun add -d vitest @playwright/test`)
- Database not migrated (run `bun run db:migrate`)
- Test references file that doesn't exist (unit may be missing target_file dependency)

Resolve, then `/mega-sdd --resume`.

### Wall-clock longer than 15 min

Acceptable for greenfield. Optimization targets:
- Run with `--parallel` (already default in `auto` chain via wave plan)
- Skip non-essential phases via `--stop-after=generate-units` if you want to review units before bolts

## What you learned

- `/mega-sdd` runs the FULL pipeline from a single sentence
- Auto-detect handles greenfield (no PRD, no code)
- Weighted routing + batched OQs keep interaction minimal
- Anti-halu rails fire on real issues; auto-continues otherwise
- ONE command + minimal interaction = working code with tests

## Next scenario

→ [Scenario 2 — PRD-driven feature](scenario-2-prd-driven-feature.md): start from a real PRD file.
