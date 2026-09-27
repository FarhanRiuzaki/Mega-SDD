# Scenario 4 — Legacy Rebuild

**Time**: varies with the census — extraction cost scales with the module count (a single-module legacy extracts on the main thread with zero subagents; a multi-module legacy runs batches of parallel module agents), plus bolt execution (~1-3 min per bolt)
**Goal**: Extract knowledge from a legacy codebase, then rebuild on a different tech stack with all domain knowledge preserved.

This is mega-sdd's biggest scenario. Real-world example: legacy PHP trade-finance system → modern Laravel rebuild.

The path is `extract-intelligence` (legacy code → knowledge base) → `plan --kb` (knowledge base → vault + units) → `execute-bolts` (units → commits). A legacy directory never goes through the lane router: a rebuild always takes the spec pipeline.

> **The concept guide** for this whole journey — why each act exists, plus the handoff (doc-pack + UAT evidence) and life-after-rebuild (sync) acts this walkthrough only touches — is [`docs/mega-sdd/revamp-journey.md`](../../docs/mega-sdd/revamp-journey.md). It predates 9.0: where it names `generate-intent --kb`, `bind-codebase` and `generate-units`, 9.0 runs `plan --kb` and the per-unit JIT bind inside `execute-bolts`.

## Prerequisites

- Mega-sdd 9.0+ (`plan --kb`; the public surface is 3 verbs + 3 one-timers — the front door `/mega-sdd` replaces the old typed stage commands)
- Legacy codebase available — ANY size works: the census excludes logs/backups/data by construction, and completeness is contracted to the code files it enumerates (a 1-file engine fully covered by 1 PRD is 100% complete)
- New target project directory ready, scaffolded in the target stack
- `ast-grep` recommended: it builds the symbol index `plan` and the JIT bind use on the target scaffold

```bash
brew install ast-grep
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
- The target already carries code (the Laravel scaffold) → `plan --mode=existing`, picked by the engine, not asked

Chain proposal (3 phases, one confirmation):

```
Proposed pipeline (--deep):
  1. extract-intelligence ~/projects/legacy-system/ --out=~/projects/rebuild-target/.mega-sdd/  ← census-scaled (script census + per-module agents)
  2. plan --kb=~/projects/rebuild-target/.mega-sdd/knowledge-base/ --lite --mode=existing        ← vault + units, one phase
  3. execute-bolts --all --lite                                                                    ← variable (bolt count × ~1-3 min each)

Total: scales with module count + bolt count
Halts may re-engage you (extract-intelligence quality gates, plan coverage gaps, business OQs, binding CONFLICTs, Hard Rule violations).

[Run] [Edit] [Cancel]
```

Click **Run**. Under the chain, extraction runs with `--auto` — per-batch confirmations are skipped; quality-gate failures still halt. There is no scan phase and no bind phase: GROUND (a script) already matched the target's framework pack and built the symbol index, and binding happens per unit inside `execute-bolts`.

No scaffold yet? Then the proposed chain stops after `plan --kb`, with no `execute-bolts` hop. Scaffold the new stack afterwards and run `/mega-sdd --resume` to reach `execute-bolts`.

## Step 2 — Phase 1: Extract intelligence (census-scaled)

Extract-intelligence is census-contracted: a script derives the completeness contract, then ONE `domain-extractor` agent extracts each module (no fixed pipeline — cost scales with the census):

```
▶ Phase 1 of 3: invoking extract-intelligence
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

✓ Phase 1 of 3: extract-intelligence → 7 module PRDs + README + data-mutation-policy
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

**Worth doing before the rebuild spec — answer the legacy questions while they are fresh.** At hand-off, extract-intelligence offers two things:

- **Resolve-oq KB mode**: "Mau jawab OQ-nya sekarang?" walks each module PRD's §6 Open Questions. An answer given here lands in the vault already resolved, with the stakeholder answer and its provenance carried verbatim.
- **The architecture advisor**, when the target architecture is still undecided. It produces an ADR; `plan --kb` consumes it only when its status is `accepted`.

Both are offers, never automatic. To take them inside a chain, add `--stop-after=extract-intelligence`, answer, then `/mega-sdd --resume`.

## Step 3 — Phase 2: `plan --kb` (vault + units in one phase)

```
▶ Phase 2 of 3: invoking plan (--kb=.mega-sdd/knowledge-base/ --lite --mode=existing)
```

`plan` detects the KB grammar: `census.json` is present, so this is the PRD-kontrak lane. It treats the KB as **analysis input, not a 1:1 spec**: code and ERD may change as long as the reengineering goals are met, unless a `[LOCKED]` rule requires preservation. It reads the source once, in order:

- the README: Reengineering Opportunities, the Mutability Tier Distribution, and the module quick-reference with its recommended rebuild order;
- `data-mutation-policy.md`: which entities and fields keep their legacy shape;
- every `modules/*.prd.md`, one module per self-slice.

There is no pre-plan Q&A: the target stack comes from the scaffold, not from a questionnaire.

It writes the layout-3 vault into `.mega-sdd/vaults/<slug>/`:

- `context.md`, `constitution.md`, `vault.json`;
- `units/` with `prd_source:` pointing at the module PRD heading each unit implements.

The vault pins its source like any PRD pin. `prd_path` is `<kb>/README.md`, and `prd_sha256` is the sha256 of `<kb>/census.json`, so the pin moves when a legacy file or the extraction changes.

Each KB claim is routed by its markers:

| KB marker | Where it lands |
|---|---|
| cited + `[LOCKED]` | `context.md ## Constraints`, verbatim (legacy field name, type, rule preserved) + a Hard rule candidate |
| cited + `[INTENT]` / untagged | `context.md ## Flows` as an outcome — the rebuild has design freedom |
| cited + `[ARTIFACT]` | an Open Question, default "discard unless preservation is required" |
| `[INFERRED][LOCKED]` | one confirmation question (high stakes), default "keep as LOCKED" |
| `[INFERRED][INTENT]` | `## Flows` with an "INFERRED — confirm in dev" note |
| `[INFERRED][ARTIFACT]` | skipped; logged to `.mega-sdd/_diagnostics/kb-skipped-artifacts.md` |
| `[OPEN]` | an Open Question |
| a §6 OQ already answered in KB mode | an OQ born resolved, answer + provenance carried verbatim |

KB gotchas become unit **Anti-patterns** by default. A gotcha is promoted to a machine-checked **Hard rule** only when it is cited (verified) AND mechanically detectable, and its anchor file exists in the target. `[INFERRED]` and `[OPEN]` items are never promoted.

Before it returns, `validate-plan-coverage.sh --kb=<kb>` checks the KB's requirement headings. Every censused heading of every module PRD needs a unit whose `prd_source` names it, an open OQ carrying `[covers: <kb>/modules/<module>.prd.md#<slug>]`, or a module-qualified line in `context.md ## Coverage exclusions`. A gap halts `plan_coverage_gap`, and while the vault's coverage entry is missing, FAIL or stale the bolts hop is refused.

```
✓ Phase 2 of 3: plan → status: completed, items: 47 units, blocked: 0

Modules:
  M-cif-customer     (8 units)   — customer master CRUD + RBAC
  M-facility-credit  (7 units)   — credit facility master + sublimits
  M-import-lc        (12 units)  — LC issuance + amendment + payment workflow
  M-swift-messaging  (5 units)   — MT700/MT202/MT103 generation
  M-monitoring       (4 units)   — LC monitoring + MT message monitoring
  M-reporting        (6 units)   — PSAK/SIMODIS/SIUL regulatory reports
  M-reference-data   (3 units)   — bank/branch/currency/holiday tables
  M-auth-rbac        (2 units)   — Sanctum auth + role middleware (extend the scaffold's User model)
```

Because `--mode=existing`, units that touch the scaffold's own code are typed from the symbol index: the Laravel `User` model is a hit, so its unit is `extend` with Migration notes. Everything else is `create`.

## Step 4 — The ONE batched ask: P1 business OQs

A legacy rebuild produces many questions (expect ~30 OQs here). `plan` sorts them before anyone is asked:

- **Technical OQs are decided by the AI**, labelled, cited and reversible (`→ **Resolved v<X.Y>** (AI decision, <date>): <pick>`), and listed in the report.
- **P1 business OQs** go into ONE `AskUserQuestion` with at most 4 questions: the 4 with the largest unit blast radius. Stakeholders have to decide things like:
  - which legacy gotchas to preserve and which to fix;
  - which regulatory constraints still apply;
  - how to handle the data-migration cutover.

```
OQ-CN-005 [P1] [business]:
  "Should we preserve legacy CFKDDL typo behavior in customer-update endpoint?
   (KB modules/cif-customer.prd.md §5 Edge Cases & Gotchas, entry 9)"

  [1] NO — fix the typo; the correct field is "CFKDHL" (recommended)
      keterangan: the KB records the typo as a cited Critical Finding
      (do-not-replicate); legacy silently corrupted 3% of customer updates
      per audit log analysis. If downstream systems depend on the bug,
      add an adapter layer — do not propagate the corruption.
  [2] Defer — the customer-update units stay blocked at bolts
  [3] Out of scope
  — Other: free text (e.g. "YES — preserve legacy bug")
```

Pick. The answer lands in `context.md ## Open Questions`, and the customer-update units carry it: here as an Anti-pattern, "Don't replicate the CFKDDL typo", citing the KB entry.

**The P1 business OQs past the first four stay `blocking`.** They are listed in the report, and the units that need them stay blocked at bolts: the chain pauses with `oq_business_p1_unresolved`. Walk them with resolve-oq (say "jawab OQ list" / "resolve open questions") before or during the bolts. The AI never answers a business OQ for you.

## Step 5 — Phase 3: `execute-bolts --all --lite`

For each wave, pre-flight 3.9 binds the units just in time. `derive-unit-claims.sh` collects the claims and `write-unit-binding.sh` writes one `bolts/U-XXX/binding.json` per unit:

- on a near-empty scaffold most claims are `create` targets that must not exist yet, checked on disk at zero model tokens;
- symbol claims (the scaffold's `User` model) are checked against the symbol index;
- free-text claims go through the evidence ladder. The KB is consulted **only when the code evidence is silent**, and it never overrides a code CONFLICT: a `[VERIFIED][LOCKED]` claim diverging from the code is a HIGH-severity CONFLICT.

A CONFLICT blocks that unit only. Its dependents are skipped with the reason, and the rest proceed.

```
▶ Phase 3 of 3: invoking execute-bolts (--all --lite)
  Wave 1 (7 parallel — `parallel_max: 7` in .mega-sdd/config.yaml; the default cap is 4): U-001 U-008 U-015 U-022 U-030 U-038 U-045
  ✓ Wave 1 complete in 12 min
  Wave 2 (7 parallel): U-002 U-009 U-016 U-023 U-031 U-039 U-046
  ✓ Wave 2 complete in 14 min
  ...
  Wave 9 (1 final): U-047
  ✓ Wave 9 complete in 3 min

✓ Phase 3 of 3: execute-bolts → 47/47 complete (3 halts resolved; total ~2 hr)
```

(Independent units are topped up as soon as their dependencies land, so wave boundaries are approximate.) Each bolt went through the `bolt-implementer` agent, a risk-tiered review panel, the Hard-rule pre/post-flight scans and the whitelist check.

The chain summary ends with the **result contract**, the same in every lane:

- the acceptance-criterion → test table;
- the delivery-check verdict;
- the assumptions and decisions: the AI's tech decisions and every stakeholder answer, each with its source.

On a Laravel target, read the delivery-check note in Step 6.

## Step 6 — Verify

```bash
cd ~/projects/rebuild-target

git log --oneline | wc -l
# ~48 commits (baseline + 47 bolts; resolve-oq edits the vault — commit those yourself)

php artisan migrate
./vendor/bin/phpunit
# All tests passing

php artisan serve
# Visit / — rebuild functional with all legacy domain logic preserved
```

**delivery-check on a Laravel target:** the check reads `package.json` at HEAD. Laravel's Vite `package.json` has no `test` script, so D1 reports FAIL regardless of phpunit. Run `./vendor/bin/phpunit` and `npm run build` on a fresh clone and quote them in the report ([Scenario 3 → pitfalls](scenario-3-field-extension.md#delivery-check-on-a-laravel-app)).

Want the AGENTS.md tool-agnostic export? Say "emit agents.md" (the chain skips it by default):

```bash
cat AGENTS.md
# Project overview, build commands, test commands, architecture overview,
# key decisions, open questions, mega-sdd interop notes
```

## Step 7 — Hand off + keep it alive

The rebuild isn't delivered until the team documents exist and the vault stays in sync with moving code:

```
/mega-sdd:emit fsd     # Confluence-ready FSD (md + PDF, sha256-stamped citations)
/mega-sdd:emit uat     # UAT doc — then let it generate + run the Playwright evidence lane
/mega-sdd:sync         # any time the code moves after "done" (hotfix, manual edit, git pull)
```

The why and the full hand-off/maintenance acts: [`docs/mega-sdd/revamp-journey.md`](../../docs/mega-sdd/revamp-journey.md) §Babak 3–4.

## What you accomplished

- Extracted a census-contracted PRD-kontrak knowledge base from legacy (no manual archaeology — every code file claimed + cited, or an honest OQ)
- Turned it into a forward-looking vault + 47 atomic units in one `plan --kb` phase, preserving regulatory + domain context
- Answered the top P1 business OQs in one batched ask, and walked the rest with resolve-oq
- Executed all units in parallel waves, each unit bound just in time against the target code
- Kept cited claims verified-by-default; flagged `[INFERRED]` for review; surfaced `[OPEN]` as OQs; carried `[LOCKED]/[INTENT]/[ARTIFACT]` into Constraints, Hard rules / Anti-patterns and ERD freedom

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

### `plan --kb` produces too many OQs

If 30+ OQs feels overwhelming:
- P1 business → only 4 reach the batched ask; the rest stay blocking until a stakeholder answers (resolve-oq). Triage them carefully.
- Tech OQs → already decided by the AI inside `plan`, labelled and cited. Review the list in the report and reverse any decision you disagree with.
- `[ARTIFACT]` OQs → default "discard". Confirm them; don't agonise.
- Many of these can be answered earlier, in KB mode right after extraction (Step 2).

### `plan` halts on `plan_coverage_gap`

A module PRD heading has no unit whose `prd_source` names it, and no open OQ carrying `[covers: …]` for it. Add the unit, raise the OQ, or declare it in `context.md ## Coverage exclusions` (`- <module>.prd.md#"<heading>" — <reason>`). Never patch the census to make the gap disappear.

### Bolt halt on hard_rule_violated in legacy-rebuild

Likely cause: the unit attempted to replicate a legacy gotcha that the KB marked as a verified, mechanically detectable Hard rule. Mega-sdd correctly halted. Fix forward or revert the offending change (the B1 gate stays closed until a passing post-flight is recorded), or edit the unit's Hard rules if the rule is wrong.

## What you learned

- Legacy rebuild is mega-sdd's biggest scenario, and its value is the audit trail from legacy code to rebuilt code, not a claim of better code
- extract-intelligence does the archaeology census-first: a script derives the completeness contract, one agent per module extracts (a single-module legacy runs on the main thread, zero subagents), and a deterministic gate proves every code file is claimed + cited
- `plan --kb` reads the KB as analysis input: `[LOCKED]` is preserved verbatim, `[INTENT]` becomes an outcome with design freedom, `[ARTIFACT]` defaults to discard, and every module heading is covered by a unit or an OQ
- Units are bound just in time against the target code, the KB only speaks when the code is silent, and a CONFLICT stops only its unit
- One command = legacy domain knowledge → working rebuild, at a cost that scales with the legacy's actual code — not its log folder

## Next scenario

→ [Scenario 5 — Multi-squad parallel](scenario-5-multi-squad-parallel.md): what still works for multi-squad vaults (authoring retired in 9.0).
