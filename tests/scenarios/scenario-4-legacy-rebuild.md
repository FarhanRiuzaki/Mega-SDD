# Scenario 4 — Legacy Rebuild

**Time**: ~4 hours wall-clock (mostly idle while extract-intelligence runs in waves)
**Goal**: Extract knowledge from a legacy codebase, then rebuild on a different tech stack with all domain knowledge preserved.

This is mega-sdd's biggest scenario. Real-world example: legacy PHP trade-finance system → modern Laravel rebuild.

## Prerequisites

- Mega-sdd v3.8.0+
- Legacy codebase available (at least 50-100 files; ideally 500+ for meaningful extraction)
- New target project directory ready
- `tree-sitter` + `ast-grep` recommended for both legacy scan + new build
- Patience — extract-intelligence is the longest phase (~3 hours for 500-file legacy)

```bash
brew install tree-sitter ast-grep ripgrep jd
command -v tree-sitter && command -v ast-grep && echo "✓ ready"
```

## Setup

Two paths in this scenario:

**Path A**: legacy at `~/projects/legacy-system/`; rebuild at `~/projects/rebuild-target/`

**Path B**: monorepo with `legacy/` and `rebuild/` siblings

We'll use Path A for clarity.

```bash
mkdir -p ~/projects/rebuild-target
cd ~/projects/rebuild-target
git init

# Scaffold new framework target (e.g., Laravel)
composer create-project laravel/laravel:^11.0 ./
git add . && git commit -m "baseline: empty Laravel scaffold"
```

## Step 1 — Kick off extraction + rebuild

```
/mega-sdd:auto ~/projects/legacy-system/ --out=~/projects/rebuild-target/.mega-sdd/
```

Mega-sdd detects:
- Input is directory with code files → legacy codebase
- `--out` provided → output goes there
- No existing vault at target → starts from extract-intelligence

Chain proposal (6 phases for legacy rebuild):

```
Proposed pipeline (--deep):
  1. extract-intelligence ~/projects/legacy-system/ --out=~/projects/rebuild-target/.mega-sdd/  ← ~3 hours
  2. generate-intent --kb=~/projects/rebuild-target/.mega-sdd/knowledge-base/                    ← ~30 min
  3. scan-codebase ~/projects/rebuild-target/                                                     ← ~5 min
  4. bind-codebase                                                                                  ← ~15 min
  5. generate-units                                                                                  ← ~20 min
  6. execute-bolts --per-squad --parallel                                                            ← variable (bolt count × ~1-3 min each)

Total estimated: 4-6 hours
Halts may re-engage you (extract-intelligence quality gates, bind conflicts, Hard Rule violations).

[Run] [Edit] [Cancel]
```

Click **Run**. Walk away for a few hours — Phase 1 will run in the background.

## Step 2 — Phase 1: Extract intelligence (~3 hours, idle)

Mega-sdd's extract-intelligence runs 5 waves of parallel-subagent extraction:

```
▶ Phase 1 of 6: invoking extract-intelligence
  Wave 0 (prep): skeleton dirs created
  Wave 1 (foundation): 3 parallel agents → 00-overview/, 30-data-model/, 20-workflows/cross-cutting
    ~30 min wall-clock
  Wave 2 (masters): 4 parallel agents → 10-domains/master entities + reference data + regulatory
    ~40 min wall-clock
  Wave 3 (workflows): 5 parallel agents → 10-domains/transactional workflows + 40-business-rules/gotchas
    ~60 min wall-clock
  Wave 4 (integrations): 3 parallel agents → 50-integrations/ + reporting/monitoring
    ~30 min wall-clock
  Wave 5 (synthesis): main thread → 99-rebuild-architecture/ + README + critical findings
    ~30 min wall-clock

✓ Phase 1 of 6: extract-intelligence → 35 MD files + README + critical findings
   ~700 OQs identified (categorized: business / tech / scan-resolvable)
   ~2400 source citations to legacy code
   Quality gates: 5/5 passed
```

What you have now: a comprehensive knowledge base at `~/projects/rebuild-target/.mega-sdd/knowledge-base/`:

```
.mega-sdd/knowledge-base/
├── README.md                    — master nav + critical findings + OQ roll-up
├── 00-overview/                 — system-purpose, glossary, classification, actors-and-roles
├── 10-domains/                  — 1 file per business domain (11-section template)
├── 20-workflows/                — cross-cutting workflows (state machines)
├── 30-data-model/               — conceptual ERD + entities
├── 40-business-rules/           — regulatory + operational + hidden gotchas
├── 50-integrations/             — external contracts (conceptual)
└── 99-rebuild-architecture/     — suggested-erd / system-flow / dependency-graph / phasing
```

Each file marker-disciplined: `[VERIFIED]` (cross-referenced ≥2 source files), `[INFERRED]` (single source), `[OPEN]` (gap requiring stakeholder).

## Step 3 — Phase 2: Generate intent from KB (~30 min)

```
▶ Phase 2 of 6: invoking generate-intent --kb=.mega-sdd/knowledge-base/
```

Mode B with KB sub-mode. Skill reads KB README + relevant domain files as PRD-equivalent source. Q&A (≤10 questions) extracts project shape, tech preferences, modes.

For legacy rebuild, typical answers:
- Project shape: web-app
- Implementation mode: existing (we have Laravel scaffold)
- Tech stack: Laravel 11 + MySQL (target stack)
- Mode-migration: legacy PHP → Laravel
- Output mode: compact

Vault written to `.mega-sdd/vaults/<slug>/`. Expect ~30 OQs (lots of business + regulatory questions from KB's `[OPEN]` items).

```
✓ Phase 2 of 6: generate-intent → 30 OQs (12 P1 business, 10 P2 tech, 8 P3)
  + Auto-Classification Review section in 00-index.md (5 tech OQs flagged for review)
```

## Step 4 — Phase 2.5: Resolve P1 business OQs (~30 min)

Often the biggest time in legacy rebuild — stakeholders need to decide:
- Which legacy gotchas to preserve vs fix
- Which regulatory constraints still apply
- How to handle data migration cutover

Run `/mega-sdd:resolve-oq`. Walks each P1 with KB-derived recommendations:

```
OQ-CN-005 [P1] [business / blocking]:
  "Should we preserve legacy CFKDDL typo behavior in customer-update endpoint?
   (KB §10-domains/10-cif-customer.md §Gotcha 9)"
  
  ⚠️ High-stakes business OQ.
  
  Recommendation: NO — fix the typo; correct field is "CFKDHL" (recommended)
  Rationale: KB marks the typo as [VERIFIED] critical finding. Legacy
    silently corrupted 3% of customer updates per audit log analysis.
  Source: docs/knowledge-base/10-domains/10-cif-customer.md §Gotcha 9
  Fallback-if-wrong: If downstream systems depend on bug, add adapter
    layer to translate; do not propagate corruption.
  Confidence: HIGH
  
  Options:
    1. NO — fix typo (recommended)
    2. YES — preserve legacy bug
    3. Defer to operations team
```

Pick + memory captures. Resume:

```
/mega-sdd:auto --resume
```

## Step 5 — Phase 3-4: Scan + bind (~20 min)

```
▶ Phase 3 of 6: invoking scan-codebase ~/projects/rebuild-target/
✓ Phase 3 of 6: scan-codebase → engine: tree-sitter, precision: ast
  Empty Laravel scaffold detected; minimal symbols (User model + base controllers)

▶ Phase 4 of 6: invoking bind-codebase
✓ Phase 4 of 6: bind-codebase → 87 claims, 0 conflicts
  Implementation State Map:
    NEW: 85 (greenfield-ish; building new on Laravel)
    IMPLEMENTED: 2 (Laravel's built-in User model + Auth scaffold)
    PARTIAL_FIELDS_MISSING: 0
  KB consultation: 700+ items consulted (KB markers feed into recommendations)
```

Greenfield-ish — most claims are NEW since target is empty Laravel.

## Step 6 — Phase 5: Generate units (~20 min)

```
▶ Phase 5 of 6: invoking generate-units
✓ Phase 5 of 6: generate-units → 47 units in 8 modules
  [auto] lint-units: 44 HIGH | 3 MEDIUM | 0 LOW | anchors 89/89 verified
  [auto] analyze-parallelism: max width 7 | speedup 3.2x

Modules:
  M-cif-customer     (8 units)   — customer master CRUD + RBAC
  M-facility-credit  (7 units)   — credit facility master + sublimits
  M-import-lc        (12 units)  — LC issuance + amendment + payment workflow
  M-swift-messaging  (5 units)   — MT700/MT202/MT103 generation
  M-monitoring       (4 units)   — LC monitoring + MT message monitoring
  M-reporting        (6 units)   — PSAK/SIMODIS/SIUL regulatory reports
  M-reference-data   (3 units)   — bank/branch/currency/holiday tables
  M-auth-rbac        (2 units)   — Sanctum auth + role middleware (extends Laravel scaffold)
```

47 units is substantial but manageable. PageRank suggested target_files for each unit; binding citations referenced KB sections.

## Step 7 — Phase 6: Execute bolts (~1-3 hours)

```
▶ Phase 6 of 6: invoking execute-bolts --per-squad --parallel
  Squad partition: single squad (no _meta/squads.yaml declared); intra-squad parallel
  
  Wave 1 (7 parallel): U-001 U-008 U-015 U-022 U-030 U-038 U-045
  ✓ Wave 1 complete in 12 min
  Wave 2 (7 parallel): U-002 U-009 U-016 U-023 U-031 U-039 U-046
  ✓ Wave 2 complete in 14 min
  ...
  Wave 9 (1 final): U-047
  ✓ Wave 9 complete in 3 min

✓ Phase 6 of 6: execute-bolts → 47/47 complete (3 halts resolved; total ~2 hr)
  [auto] list-modules: 8/8 modules completed
  [auto] emit-agents-md: AGENTS.md generated

📋 Final summary:
   Phases: 6/6 completed
   Quality: HIGH grounding throughout
   Parallelism: 3.2x speedup (real wall-clock 2 hr vs sequential ~6.5 hr)
   Memory: 4 learning suggestions pending → /mega-sdd:memory review
```

## Step 8 — Verify

```bash
cd ~/projects/rebuild-target

git log --oneline | wc -l
# ~50 commits (baseline + 47 bolts + maybe a few resolve-oq commits)

php artisan migrate
./vendor/bin/phpunit
# All tests passing

php artisan serve
# Visit / — rebuild functional with all legacy domain logic preserved
```

Check the AGENTS.md tool-agnostic export:

```bash
cat AGENTS.md
# Project overview, build commands, test commands, architecture overview,
# key decisions, open questions, mega-sdd interop notes
```

## What you accomplished

- Extracted 35-file knowledge base from legacy (no manual archaeology)
- Generated forward-looking vault preserving regulatory + domain context
- Resolved 12 P1 business OQs with KB-derived recommendations
- Built 47 atomic units with explicit citations to legacy patterns
- Executed all units in parallel waves
- Preserved `[VERIFIED]` knowledge; flagged `[INFERRED]` for review; surfaced `[OPEN]` as OQs

Total wall-clock: ~4-5 hours, of which ~3 hours is idle (extract waves running in background).

## Common pitfalls

### Extract-intelligence wave halt

Quality gate failed twice. Read the wave-N failure message:

```yaml
blocker:
  type: quality_gate_failed
  details:
    wave: 3
    failed_check: "Citations < 5 per domain file"
    retries_attempted: 2
```

Options:
- Re-dispatch wave with `/mega-sdd:auto --resume` (Iter 6 checkpoints let it re-run only that wave)
- Manually inspect the partial output; if good enough, accept gap with `--allow-gaps` flag (loses some rigor)

### Generate-intent --kb produces too many OQs

If 30+ OQs feels overwhelming:
- P1 business → triage carefully; these need stakeholder
- P2 tech → most auto-resolve at bind-codebase via scan mode
- P3 refinement → defer to next milestone via `--allow-deferred`

### Bolt halt on hard_rule_violated in legacy-rebuild

Likely cause: unit attempted to replicate a legacy gotcha that's in Anti-patterns. Mega-sdd correctly halted. Resolve by editing unit's Hard rules OR reverting the offending change.

### Memory growth concerns

After legacy rebuild, your memory directories have significant content:

```bash
du -sh .mega-sdd/memory/ ~/.mega-sdd/memory/
# Project: ~5MB; User: ~500KB
```

This is normal. To clean up old runs:

```bash
/mega-sdd:memory prune --older-than=90d
```

## What you learned

- Legacy rebuild is mega-sdd's biggest+highest-value scenario
- extract-intelligence does the archaeology in parallel waves (not 3 hours of manual reading)
- KB markers (`[VERIFIED]/[INFERRED]/[OPEN]`) carry knowledge into vault systematically
- Field-level + module + squad layers all work together
- One command + ~4 hours = legacy domain knowledge → working rebuild

## Next scenario

→ [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md): partition work across teams.
