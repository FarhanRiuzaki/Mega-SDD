# Scenario 4 — Legacy Rebuild

**Time**: varies with the census — extraction cost scales with the module count (a single-module legacy extracts on the main thread with zero subagents; a multi-module legacy runs batches of parallel module agents), plus bolt execution (~1-3 min per bolt)
**Goal**: Extract knowledge from a legacy codebase, then rebuild on a different tech stack with all domain knowledge preserved.

This is mega-sdd's biggest scenario. Real-world example: legacy PHP trade-finance system → modern Laravel rebuild.

> **The concept guide** for this whole journey — why each act exists, plus the handoff (doc-pack + UAT evidence) and life-after-rebuild (sync) acts this walkthrough only touches — is [`docs/mega-sdd/revamp-journey.md`](../../docs/mega-sdd/revamp-journey.md).

## Prerequisites

- Mega-sdd v7.6+ (census-contracted extract-intelligence; the public surface is 3 verbs + 3 one-timers — the front door `/mega-sdd` replaces the old typed stage commands)
- Legacy codebase available — ANY size works: the census excludes logs/backups/data by construction, and completeness is contracted to the code files it enumerates (a 1-file engine fully covered by 1 PRD is 100% complete)
- New target project directory ready
- `ast-grep` recommended for both legacy scan + new build

```bash
brew install ast-grep ripgrep jd
command -v ast-grep && echo "✓ ready"
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
/mega-sdd ~/projects/legacy-system/ --out=~/projects/rebuild-target/.mega-sdd/
```

The front door detects:
- Input is directory with code files, no vault → legacy codebase
- `--out` provided (REQUIRED for this lane) → KB goes to `<out>/knowledge-base/`
- No existing vault at target → starts from extract-intelligence

Chain proposal (5 phases — the **express spine** is the default, so no separate scan phase; add `--classic` if you want the full `codebase-map.md` lane, which inserts scan-codebase before bind):

```
Proposed pipeline (--deep):
  1. extract-intelligence ~/projects/legacy-system/ --out=~/projects/rebuild-target/.mega-sdd/  ← census-scaled (script census + per-module agents)
  2. generate-intent --kb=~/projects/rebuild-target/.mega-sdd/knowledge-base/                    ← ~30 min
  3. bind-codebase --express                                                                       ← ~15 min
  4. generate-units                                                                                  ← ~20 min
  5. execute-bolts --all --parallel                                                                  ← variable (bolt count × ~1-3 min each)

Total: scales with module count + bolt count
Halts may re-engage you (extract-intelligence quality gates, bind conflicts, Hard Rule violations).

[Run] [Edit] [Cancel]
```

Click **Run**. Under the chain, extraction runs with `--auto` — per-batch confirmations are skipped; quality-gate failures still halt.

## Step 2 — Phase 1: Extract intelligence (census-scaled)

Extract-intelligence is census-contracted: a script derives the completeness contract, then ONE `domain-extractor` agent extracts each module (no fixed pipeline — cost scales with the census):

```
▶ Phase 1 of 5: invoking extract-intelligence
  Census (script, main thread): derive-extract-census.sh → census.json
    code files + sha256 + stacks + entry points + module proposal
    (logs/backups/data excluded by construction)
  Module split confirmation (only when >1 module proposed):
    Proposed: cif-customer · facility-credit · import-lc · swift-messaging ·
              monitoring · reporting · reference-data
    [Pakai pecahan ini] [Ubah] [Stop]
  Per-module extraction: 1 domain-extractor agent per module, ≤5 in flight per batch
    batch 1 gates pass → [Lanjut batch berikutnya] [Review output dulu] [Stop]  (skipped under --auto)
    batch 2 gates pass → …
  Synthesis (main thread): README.md roll-up (+ ## ERD + ## System Flow) +
    data-mutation-policy.md (≥1 [LOCKED] claim found)
  Completeness gate: validate-extract-census.sh → PASS
    (every census file claimed exactly once + cited; 6 sections per PRD; flows Mermaid)

✓ Phase 1 of 5: extract-intelligence → 7 module PRDs + README + data-mutation-policy
   Open Questions rolled up in README (P1 business / P2 tech / P3)
   Inline path:line citations to legacy code throughout
```

The census itself is a script, not a model pass — the field replay clocked it at 0.13s on a 1,270-file legacy directory (3 live code files; the other 1,267 were logs/backups the census excluded). That single-module case skipped the confirmation AND the subagents entirely: extraction ran on the main thread with **zero dispatches**.

What you have now: a PRD-kontrak knowledge base at `~/projects/rebuild-target/.mega-sdd/knowledge-base/`:

```
.mega-sdd/knowledge-base/
├── census.json                  — script-derived completeness contract (code files + sha256)
├── README.md                    — roll-up + nav: module quick-reference (recommended rebuild
│                                  order), ## ERD + ## System Flow (multi-module),
│                                  ## Critical Findings, OQ roll-up
├── modules/
│   └── <domain>.prd.md          — ONE PRD-kontrak per module, 6 sections:
│                                  1. Purpose / 2. Business Rules / 3. Flow (Mermaid WAJIB) /
│                                  4. Data In/Out / 5. Edge Cases & Gotchas / 6. Open Questions
└── data-mutation-policy.md      — ONLY when ≥1 [LOCKED] claim exists
```

Marker discipline: confidence is **default-verified** — a cited claim with NO marker is verified; only `[INFERRED]` (single source path) and `[OPEN]` (gap requiring stakeholder) are tagged. Orthogonally, mutability tiers `[LOCKED]/[INTENT]/[ARTIFACT]` carry the revamp contract. Citations are inline (`path:line`) right after each claim.

## Step 3 — Phase 2: Generate intent from KB (~30 min)

```
▶ Phase 2 of 5: invoking generate-intent --kb=.mega-sdd/knowledge-base/
```

Mode B with KB sub-mode. The skill detects the grammar (`census.json` present → PRD-kontrak lane) and reads the KB README (Reengineering Opportunities + Mutability Tier Distribution + module quick-reference) plus every `modules/*.prd.md` as PRD-equivalent source. Q&A (≤10 questions) extracts project shape, tech preferences, modes.

For legacy rebuild, typical answers:
- Project shape: web-app
- Implementation mode: existing (we have Laravel scaffold)
- Tech stack: Laravel 11 + MySQL (target stack)
- Mode-migration: legacy PHP → Laravel
- Output mode: compact

Vault written to `.mega-sdd/vaults/<slug>/`. Expect ~30 OQs (lots of business + regulatory questions from the module PRDs' `[OPEN]` items).

```
✓ Phase 2 of 5: generate-intent → 30 OQs (12 P1 business, 10 P2 tech, 8 P3)
  + Auto-Classification Review section in vault.md (5 tech OQs flagged for review)
```

## Step 4 — Phase 2.5: Resolve P1 business OQs (~30 min)

Often the biggest time in legacy rebuild — stakeholders need to decide:
- Which legacy gotchas to preserve vs fix
- Which regulatory constraints still apply
- How to handle data migration cutover

The chain halts on P1 business OQs and invokes the resolve-oq skill (or say "jawab OQ list" / "resolve open questions" to enter it yourself). It walks each P1 with KB-derived recommendations:

```
OQ-CN-005 [P1] [business / blocking]:
  "Should we preserve legacy CFKDDL typo behavior in customer-update endpoint?
   (KB modules/cif-customer.prd.md §5 Edge Cases & Gotchas, entry 9)"
  
  ⚠️ High-stakes business OQ.
  
  Recommendation: NO — fix the typo; correct field is "CFKDHL" (recommended)
  Rationale: the KB records the typo as a cited Critical Finding (do-not-replicate).
    Legacy silently corrupted 3% of customer updates per audit log analysis.
  Source: .mega-sdd/knowledge-base/modules/cif-customer.prd.md §5 Edge Cases & Gotchas
  Mutability tier: [LOCKED] (regulatory citation: BI Reg 23/2/2021 §4 — field validation rule)
  → Pack-aware Hard Rule emitted into all customer-update units
  Fallback-if-wrong: If downstream systems depend on bug, add adapter
    layer to translate; do not propagate corruption.
  Confidence: HIGH
  
  Options:
    1. NO — fix typo (recommended)
    2. YES — preserve legacy bug
    3. Defer to operations team
```

Pick; the resolution lands in the vault. Resume:

```
/mega-sdd --resume
```

## Step 5 — Phase 3: Bind (~15 min, express spine)

The GROUND step already ran as a script (framework pack matched from `composer.json`, symbol index built — zero model tokens), so the chain goes straight to bind:

```
▶ Phase 3 of 5: invoking bind-codebase --express
✓ Phase 3 of 5: bind-codebase → 87 claims, 0 conflicts
  Implementation State Map:
    NEW: 85 (greenfield-ish; building new on Laravel)
  Mutability tier distribution (from KB):
    [LOCKED]: 12 claims (regulatory + integration contracts)
    [INTENT]: 68 claims (outcome-only; rebuild has design freedom)
    [ARTIFACT]: 7 claims (discarded — legacy implementation accidents)
  Framework pack loaded: laravel-base-26.md (11 Hard Rules emitted into Suggested Unit Hard Rules)
    e.g., UUID PK enforcement, BaseController extension, DOMContentLoaded JS init, SweetAlert2 dialogs
    IMPLEMENTED: 2 (Laravel's built-in User model + Auth scaffold)
    PARTIAL_FIELDS_MISSING: 0
  KB consultation: module PRDs consulted as secondary ground truth (mutability tiers feed the recommendations)
```

Greenfield-ish — most claims are NEW since target is empty Laravel.

## Step 6 — Phase 4: Generate units (~20 min)

```
▶ Phase 4 of 5: invoking generate-units
✓ Phase 4 of 5: generate-units → 47 units in 8 modules

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

47 units is substantial but manageable. target_files came from binding citations (which referenced KB module PRDs); at bolt time each dispatch carried its symbol_slice of nearby existing code.

## Step 7 — Phase 5: Execute bolts (~1-3 hours)

```
▶ Phase 5 of 5: invoking execute-bolts --all --parallel
  Squad partition: single squad (no _meta/squads.yaml declared); intra-squad parallel
  
  Wave 1 (7 parallel): U-001 U-008 U-015 U-022 U-030 U-038 U-045
  ✓ Wave 1 complete in 12 min
  Wave 2 (7 parallel): U-002 U-009 U-016 U-023 U-031 U-039 U-046
  ✓ Wave 2 complete in 14 min
  ...
  Wave 9 (1 final): U-047
  ✓ Wave 9 complete in 3 min

✓ Phase 5 of 5: execute-bolts → 47/47 complete (3 halts resolved; total ~2 hr)

📋 Final summary:
   Phases: 5/5 completed
   Quality: HIGH grounding throughout
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

Want the AGENTS.md tool-agnostic export? Run "generate AGENTS.md" on demand (auto-emit is classic-spine only):

```bash
cat AGENTS.md
# Project overview, build commands, test commands, architecture overview,
# key decisions, open questions, mega-sdd interop notes
```

## Step 9 — Hand off + keep it alive

The rebuild isn't delivered until the team documents exist and the vault stays in sync with moving code:

```
/mega-sdd:emit fsd     # Confluence-ready FSD (md + PDF, sha256-stamped citations)
/mega-sdd:emit uat     # UAT doc — then let it generate + run the Playwright evidence lane
/mega-sdd:sync         # any time the code moves after "done" (hotfix, manual edit, git pull)
```

The why and the full hand-off/maintenance acts: [`docs/mega-sdd/revamp-journey.md`](../../docs/mega-sdd/revamp-journey.md) §Babak 3–4.

## What you accomplished

- Extracted a census-contracted PRD-kontrak knowledge base from legacy (no manual archaeology — every code file claimed + cited, or an honest OQ)
- Generated forward-looking vault preserving regulatory + domain context
- Resolved 12 P1 business OQs with KB-derived recommendations
- Built 47 atomic units with explicit citations to legacy patterns
- Executed all units in parallel waves
- Kept cited claims verified-by-default; flagged `[INFERRED]` for review; surfaced `[OPEN]` as OQs; carried `[LOCKED]/[INTENT]/[ARTIFACT]` into Hard Rules + ERD freedom

Total wall-clock: dominated by bolt execution + your OQ decisions. Extraction cost tracks the census, not a fixed pipeline — the field replay ran a single-module legacy with zero dispatches; a multi-module legacy costs one agent per module, in batches.

## Common pitfalls

### Extract-intelligence module gate halt

The SAME module's quality gate failed twice. Read the failure message:

```yaml
blocker:
  type: quality_gate_failed
  emitted_by: extract-intelligence
  details:
    module: import-lc
    module_prd: modules/import-lc.prd.md
    failed_check: "§5 Edge Cases & Gotchas < 3 entries (workflow-module minimum)"
    retries_attempted: 2
```

(The registry files this under subtype `module_quality_threshold_unmet`.) The halt surfaces the gate output verbatim and asks with keterangan: **Re-scope module** (pecah/gabung ulang module ini lalu re-dispatch) / **Re-prompt** (re-dispatch sekali lagi dengan arahan tambahan) / **Abort** (berhenti; KB partial disimpan — module PRD yang sudah lolos tetap di disk). There is no auto-resume after Abort: the next run starts again from the census (idempotent). Full walkthrough: [Scenario 6](scenario-6-recovery-from-halt.md).

### Generate-intent --kb produces too many OQs

If 30+ OQs feels overwhelming:
- P1 business → triage carefully; these need stakeholder
- P2 tech → most auto-resolve at bind-codebase via scan mode
- P3 refinement → auto-deferred on the express chain; the chain summary re-surfaces the id list

### Bolt halt on hard_rule_violated in legacy-rebuild

Likely cause: unit attempted to replicate a legacy gotcha that's in Anti-patterns. Mega-sdd correctly halted. Resolve by editing unit's Hard rules OR reverting the offending change.

## What you learned

- Legacy rebuild is mega-sdd's biggest+highest-value scenario
- extract-intelligence does the archaeology census-first: a script derives the completeness contract, one agent per module extracts (a single-module legacy runs on the main thread, zero subagents), and a deterministic gate proves every code file is claimed + cited
- Default-verified citations + `[INFERRED]/[OPEN]` markers + `[LOCKED]/[INTENT]/[ARTIFACT]` tiers carry knowledge into the vault systematically
- Field-level + module + squad layers all work together
- One command = legacy domain knowledge → working rebuild, at a cost that scales with the legacy's actual code — not its log folder

## Next scenario

→ [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md): partition work across teams.
