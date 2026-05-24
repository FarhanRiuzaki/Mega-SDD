# mega-sdd

Spec-driven AI development pipeline for [Claude Code](https://claude.com/claude-code). PRD or idea → vault → atomic units → tested commits with anti-hallucination at every handoff.

**Version:** 3.18.1 · **License:** MIT

> 📖 Full documentation + user-facing scenarios at the repo root. See [`../../README.md`](../../README.md) + [`../../tests/scenarios/`](../../tests/scenarios/).

## Quick start

```bash
# Install
/plugin marketplace add https://gitlab.com/airnd1/grand-design-spec.git
/plugin install mega-sdd
/plugin install superpowers   # recommended

# Optional native binaries (precision boost):
brew install tree-sitter ast-grep ripgrep jd
# OR
cargo install tree-sitter-cli ast-grep ripgrep
go install github.com/josephburnett/jd@latest

# Then in any project:
/mega-sdd:auto ./prd.md
```

That's it. Full install matrix: [`references/tooling-install.md`](./references/tooling-install.md).

## First-time user? Start with a scenario

| Scenario | When | Time |
|---|---|---|
| [Greenfield from idea](../../tests/scenarios/scenario-1-greenfield-from-idea.md) | Brand new; minimum viable demo | 15 min |
| [PRD-driven feature](../../tests/scenarios/scenario-2-prd-driven-feature.md) | Have PRD; existing project | 30 min |
| [Field-level extension](../../tests/scenarios/scenario-3-field-extension.md) | Add field to existing model | 20 min |
| [Legacy rebuild](../../tests/scenarios/scenario-4-legacy-rebuild.md) | Legacy → new framework | 4 hours |
| [Multi-squad parallel](../../tests/scenarios/scenario-5-multi-squad-parallel.md) | Multi-team coordination | 45 min |
| [Recovery from halt](../../tests/scenarios/scenario-6-recovery-from-halt.md) | Bolt halted; need to recover | 15 min |

## What's in this folder

```
plugins/mega-sdd/
├── .claude-plugin/plugin.json    # plugin manifest (v3.30.0)
├── skills/                       # 13 skills + _vendored/
│   ├── using-mega-sdd/           # anchor skill (auto-injected) (v1.2.1)
│   ├── memory/                   # memory + self-learning (v1.2.1)
│   ├── emit-agents-md/           # AGENTS.md flatten (v1.2.3)
│   ├── extract-intelligence/     # legacy → knowledge-base (v1.4.0)
│   ├── generate-intent/          # PRD/brief/KB → vault (v1.10.0)
│   ├── scan-codebase/            # tree-sitter AST scan (v2.4.2)
│   ├── bind-codebase/            # validation gate + field diff (v1.9.2)
│   ├── generate-units/           # atomic decomposition (v2.5.3)
│   ├── execute-bolts/            # superpowers TDD bridge (v2.4.1)
│   ├── orchestrate-flow/         # lifecycle router (v2.3.2)
│   ├── resolve-oq/               # OQ resolver + recommendations (v0.9.0)
│   ├── detect-drift/             # code vs vault (v1.2.1)
│   ├── diff-vault/               # PRD revision + jd patches (v1.2.1)
│   └── _vendored/                # superpowers fallback
├── commands/                     # 20 slash commands (1 primary + 19 advanced)
│   ├── auto.md                   # ⭐ THE command
│   ├── generate-intent.md, scan-codebase.md, bind-codebase.md, generate-units.md, execute-bolts.md
│   ├── extract-intelligence.md, orchestrate-flow.md, resolve-oq.md, diff-vault.md, detect-drift.md
│   ├── memory.md, emit-agents-md.md
│   ├── lint-units.md, analyze-parallelism.md, list-modules.md    # [auto-invoked by /mega-sdd:auto]
│   ├── migrate-rules.md, migrate-paths.md                         # one-off maintenance
│   └── update-plugin.md
├── references/
│   ├── paths.md                  # canonical folder layout (Iter 10)
│   └── tooling-install.md        # optional native binaries install matrix (Iter 14)
├── hooks/                        # SessionStart hook
├── scripts/                      # sync-superpowers + memory-migrations/
├── CLAUDE.md                     # AI-agent contributor guidelines
└── LICENSE
```

## Pipeline (one-line)

```
[legacy → extract-intelligence] → brief/PRD → generate-intent → (scan + bind for brownfield) → generate-units → execute-bolts → emit-agents-md
```

Wrapped by `/mega-sdd:auto` for autonomous end-to-end execution with single upfront confirmation. Diagnostics (lint, analyze, modules, emit) AUTO-INVOKED at appropriate phases per Iter 13 consolidation. Halt-protocol preserved across all iters.

## What's new

### v3.30.0 (Iter 45, minor) — Saga Compensating Actions (`--rollback` flag + partial-state v2.0)

Closes Iter 38 audit Pattern D (D3-009 + D3-003) — replaces forward-only resume with saga-pattern compensating actions. Crashed bolts can now be cleanly rolled back instead of compounding partial writes.

**Problem:** mega-sdd used forward-only resume. On `--resume`, execute-bolts retried the failing step but couldn't undo non-idempotent prior steps (composer dep adds, migrations, external API calls). Partial writes compounded on subsequent runs.

**Solution:**

1. **partial-state.json schema bump v1.0 → v2.0** — adds `rollback_hints[]` array. Each entry: `{step_id, step_type, evidence, compensating_action, idempotent, applied_at}`.

2. **Canonical step_type taxonomy (14 types)** — `file_created` / `file_modified` / `file_partially_written` / `composer_dep_added` / `migration_executed` / `external_api_call` / etc. Each maps to a default compensating action template + idempotency flag.

3. **`--rollback <unit-id>` flag (NEW)** — reads partial-state.json v2.0 + applies `rollback_hints[]` in reverse order with per-action confirmation. Non-idempotent actions get safe-default confirmation. Applied actions stamp `applied_at:` so partial rollback can be resumed.

4. **Bolt subagent contract** — bolt-dispatch-prompt.md gets new `## Rollback hints` self-assessment section. Bolt subagent appends hint per significant step during execution. On crash: execute-bolts harvests hints into partial-state.json.

5. **Backward compat** — v1.0 partial-state.json (Iter 30 baseline) → `--rollback` errors gracefully ("no rollback hints; manual review via `git status` + `git diff HEAD`"). `--resume` still works.

**Reused halt:** malformed `rollback_hints[]` entries trigger existing `partial_state_corrupt` halt (Iter 40) with `malformed_hints:` detail. No new halt type.

**External research cited:** Saga Pattern (microservices.io) + Compensating Transactions (Microsoft Azure).

**Skill bumps:**
- `execute-bolts` 2.8.0 → 2.9.0 (MINOR — schema bump + new flag + new self-assessment section)

**Plugin v3.29.0 → v3.30.0** (MINOR — schema bump + new flag).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-45-saga-compensating-actions-design.md`

### v3.29.0 (Iter 44, minor) — T2 Running Budget Tracker + Progressive Truncation

Closes Iter 38 audit Queue #4 (D1-003) — replaces aspirational 5KB T2 soft cap + single 10KB halt with running byte tracker + progressive section-level truncation cascade. Every bolt dispatch benefits.

**Problem (audit D1-003):** T2 5KB soft cap was documented but never enforced. The only enforcement was the 10KB hard cap (halt-or-pass binary). Complex units silently exceeded T2 budget, ballooning context until they tripped the hard cap. Audit estimate: 15-30% T2 size reduction for complex units once progressive truncation enforced.

**Solution:**

1. **Running budget tracker** (NEW — Step 4.5.a.5) tracks `consumed_t2 / cap_t2 / remaining_t2` as each T2 section loads. Truncation triggered BEFORE next section overflows budget, not after.

2. **8-tier section priority for truncation** — sections ordered from MOST disposable (validation_hints / historical_memory / kb_anti_patterns) to MOST critical (constitution_clauses NEVER truncates). Each section has explicit truncation cascade with drop floor.

3. **Soft-budget warnings (NEW)** — exceeding 5KB target now logs a warning + applies truncation; only `dispatch_prompt_too_large` halt fires when constitution_clauses alone exceeds budget (true config issue).

4. **Truncation provenance to subagent** — bolt-dispatch-prompt.md gets new `### T2 budget tracker` section listing `truncations_applied`. Subagent instructed: "if your self-assessment references truncated information, mark confidence: MEDIUM and note the truncation."

**Skill bumps:**
- `execute-bolts` 2.7.3 → 2.8.0 (MINOR — new Step 4.5.a.5 + new bolt-dispatch-prompt section)

**Plugin v3.28.1 → v3.29.0** (MINOR — new optimization step + new self-assessment field).

**Spec:** `docs/superpowers/specs/2026-05-25-iter-44-t2-running-budget-tracker-design.md`

### v3.28.1 (Iter 43, patch) — Fix-Forward: handoff_missing semantics, schema doc, savings accuracy

**Release-blocker fix.** A code-quality review of Iters 39-42 surfaced a critical regression in Iter 40's `handoff_missing` halt (would fire on every auto run because the file-existence check pointed at a path no skill actually writes). Plus: starterkit-context-schema.md was left at v1.0 docs while scan-codebase v2.7.0 writes v2.0; Iter 42 CHANGELOG savings estimates were inverted/optimistic.

**Fixed (critical):**
- `handoff_missing` (orchestrate-flow v3.2.1+) semantics corrected: now scans sub-skill's **chat output** for an inline `handoff:` YAML block (per actual skill emission convention) instead of `test -f` on a hardcoded path. Halt envelope gains `chat_tail_excerpt: <last 500 chars>` field for diagnosis. Iter 40 production-correct again.
- `handoff-contract.md` Emission contract section added: documents that skills emit handoff YAML inline in chat (last assistant message). File-write to `<vault>/.internal/checkpoints/` is OPTIONAL (replay/audit); chat-block is the authoritative source.
- `starterkit-context-schema.md` bumped to v2.0 to match scan-codebase v2.7.0 producer. Adds `cache_signatures:` block + per-slice invalidation matrix table + legacy v1.0 backward-compat note.

**Fixed (medium):**
- `partial_state_corrupt` canonical path in vault-contract.md corrected: `<vault>/bolts/U-XXX/partial-state.json` (matches execute-bolts §Partial-state contract emit example).
- Iter 42 cache savings claims corrected: actual savings are 25% (PHP dep edit — composer.lock invalidates auth+rbac+libs), 50% (JS dep edit — package.lock invalidates ui_ux+libs), 75% (single lib-pattern file edit). Earlier CHANGELOG bullets were inverted/imprecise.

**Skill bumps:**
- `orchestrate-flow` 3.2.0 → 3.2.1 (semantics correction)

**Plugin v3.28.0 → v3.28.1** (PATCH — fix-forward audit closure stack).

### v3.28.0 (Iter 42, minor) — Deep-Scan Manifest Pre-Parse + Per-Slice Cache

Closes Iter 38 audit Queue #3 (D1-002 + D2-003) — eliminates redundant manifest reads + replaces whole-file cache invalidation with per-slice signatures. Every project pipeline benefits.

**Change 1 (D1-002): Manifest pre-parse** — `scan-codebase` Step 10.5.1.5 (NEW). Main thread parses `composer.json` + `package.json` ONCE, injects `manifest_facts` struct into all 4 deep-scan subagent prompts via `<MANIFEST_FACTS>` placeholder. Subagents instructed: "do NOT re-read manifest files; manifest_facts is authoritative."

- **Net savings:** ~9-24KB per scan (4 subagents × ~2-6KB saved per subagent context)
- **External research:** subagent-token pattern (Sathish Raju Medium) — "pass analytical outputs, not raw data"

**Change 2 (D2-003): Per-slice cache (schema v2.0)** — `scan-codebase` Step 10.5.1 + 10.5.3 reworked. Each of 4 slices (auth, rbac, ui_ux, libs) tracks its own `signature_sha256` (composed from slice-relevant inputs: lock file + framework_pack section + lib-pattern file). On scan:
  - Full cache hit (no slices stale) → reuse entire prior YAML
  - Partial cache hit (1-3 slices stale) → dispatch only stale subagents; consolidator merges fresh + cached
  - Full cache miss (all slices stale or no prior YAML) → dispatch all 4 (current behavior)

- **Net savings (incremental edits):** 1-3 subagent dispatches saved per minor edit (~25-75% wasted compute eliminated)
- **External research:** real-time codebase indexing (cocoindex-io) — "per-file invalidation via hash"
- **Backward compat:** v1.0 `cache_key:` schema treated as fully-stale (auto-migrates to v2.0 `cache_signatures:` on next write)

**Skill bumps:**
- `scan-codebase` 2.6.3 → 2.7.0 (MINOR — new Step 10.5.1.5 + cache schema bump)

**Spec:** `docs/superpowers/specs/2026-05-25-iter-42-deep-scan-manifest-preparse-and-per-slice-cache-design.md`

**Plugin v3.27.1 → v3.28.0** (MINOR — new optimization step + cache schema bump).

### v3.27.1 (Iter 41, patch) — Halt Taxonomy Sync Sweep

Reconciles the canonical halt registry (`vault-contract.md §halt-protocol`) with all halts actively emitted by skills and tracked by orchestrate-flow. Closes Iter 38 audit priority 2 (registry drift).

**Pre-sweep state:**
- Enum had 37 halt types
- Orchestrate-flow taxonomy referenced 39 halt types
- **9 halts emitted by skills + listed in orchestrate-flow were missing from canonical enum** (any consumer validating envelopes would reject them)
- 5 halts in enum were missing from orchestrate-flow taxonomy (orchestrator couldn't decide auto-loop vs ALWAYS-STOP behavior)

**Post-sweep state:**
- Enum: 46 halts (+9 reconciled)
- Description list: 37 bulleted entries (+9 with provenance: producer skill + iter + resolution)
- Orchestrate-flow taxonomy: 44 entries (+5 reconciled)

**Halts added to enum + description (9):**
`dedup_ambiguous` (generate-units), `hard_rule_unparseable` (generate-units), `hard_rule_violated` (execute-bolts), `memory_schema_mismatch` (memory), `prd_no_scopes_block_user_rejected_retrofit` (generate-intent, Iter 28), `prd_path_missing` (diff-vault, Iter 29), `prd_retrofit_low_confidence` (generate-intent, Iter 28), `quality_gate_failed` (extract-intelligence), `scope_not_declared_in_prd` (generate-intent, Iter 28).

**Halts added to orchestrate-flow ALWAYS-STOP taxonomy (5):**
`oq_blocker` (canonical envelope; coexists with orch-level alias `oq_business_p1_unresolved`), `cross_squad_ambiguous`, `cycle_detected`, `interface_ref_missing`, `pbt_citation_invalid` (Iter 39 oversight closure).

**No new skills, no new halts.** All halts already existed in code; sweep makes the registry match reality. Closes Iter 38 audit D3-006 (taxonomy sync).

**Plugin v3.27.0 → v3.27.1.**

### v3.27.0 (Iter 40, minor) — Silent-Failure Path Closure (3 new halts)

Closes 3 silent-failure paths surfaced by Iter 38 audit (priority 1, robustness D3). All 3 fire as ALWAYS-STOP halts at the exact failing boundary instead of leaking into cryptic downstream errors.

**New halts:**

- `handoff_missing` (orchestrate-flow v3.2.0+) — sub-skill exited without emitting handoff YAML at the expected path. Previously orchestrator either proceeded with empty state OR failed downstream with file-not-found; now halts at the boundary with `last_known_step` hint.
- `artifact_missing` (orchestrate-flow v3.2.0+) — handoff YAML lists `artifacts: [paths]` but one or more paths fail `test -f` / `test -d`. Previously next-stage consumer skill failed with cryptic file-not-found; now halts at producer boundary with explicit `missing_paths: [...]` list.
- `partial_state_corrupt` (execute-bolts v2.7.3+) — `--resume` mode found partial-state.json fails JSON parse. Previously silent overwrite with fresh state (hidden recovery loss); now halts with `corrupt_backup_path` suggestion for forensics.

**4-surface taxonomy sync (per Iter 33+Iter 31 propagation directive):**

- `vault-contract.md` enum + descriptions: 3 new entries
- `orchestrate-flow/SKILL.md` ALWAYS-STOP halt taxonomy: 3 new rows
- `orchestrate-flow/SKILL.md` Procedure: 2 new validation steps (`b.0` handoff presence, `b.vii` artifact existence)
- `handoff-contract.md`: documents orchestrator-side detection for both checks
- `execute-bolts/SKILL.md` §Partial-state contract: resume-time integrity check added

**Skill bumps:**
- `orchestrate-flow` 3.1.2 → 3.2.0 (MINOR — new procedure steps + new halts emitted)
- `execute-bolts` 2.7.2 → 2.7.3 (PATCH — new error path; same procedure)

**Why MINOR (not PATCH):** Chains that previously silently-passed corrupt/missing state now halt explicitly. Existing user workflows that depend on "silent recovery" behavior will see new halts. Documented as expected-behavior change.

**Plugin v3.26.3 → v3.27.0.** Spec: `docs/superpowers/specs/2026-05-25-iter-40-silent-failure-path-closure-design.md`.

### v3.26.3 (Iter 39, patch) — Quick Audit Closure Pass (5 immediate wins)

Closes 5 P1/HIGH findings from `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`. All atomic doc/contract fixes; no behavior changes.

**What changed:**

- **D4-001 layer count**: plugin README header `(13 layers)` → `(15 layers)` + added layer 14 (predictive preflight from Iter 33 F2) + layer 15 (handoff schema validation from Iter 33 F3+F4). Root README line 406 stale `13-layer pipeline defense above` → `15-layer pipeline defense above`.
- **D3-010 --max-cycles default**: SKILL.md was documenting `default 5` in 2 spots while `commands/orchestrate-flow.md` said `default 3`. Canonicalized to **3** (one canonical default) — matches user-facing slash command help.
- **D3-007 --force-skip-postflight**: undocumented escape hatch now formally surfaced in `execute-bolts/SKILL.md ## Inputs` with WARNING block citing anti-bypass policy (CLAUDE.md). Logged in handoff YAML via `notes.postflight_skipped: true`.
- **D3-004 pbt_citation_invalid halt**: added to `vault-contract.md §halt-protocol` enum + canonical description. Emitted by execute-bolts v2.4+ (Iter 20) when a PBT property `Cites: §Decision-D-NNN` references a non-existent ADR.

**Skill bumps:**
- `execute-bolts` 2.7.1 → 2.7.2 (+ `--force-skip-postflight` flag)
- `orchestrate-flow` 3.1.1 → 3.1.2 (canonical max-cycles=3)

**Why this matters:** Iter 38 audit surfaced 37 optimization findings across 4 dimensions (token / performance / robustness / output quality). These 5 are the immediate wins with <40min total time-to-ship. Higher-effort closures (priority 1: silent-failure path) land in Iter 40.

**Plugin v3.26.2 → v3.26.3** (PATCH — pure doc/contract fixes; no skill behavior changes).

### v3.26.2 (Iter 37, patch) — Scenarios Coverage + README Audit

mega-sdd now ships **scenarios for all user-facing features through Iter 35**, plus README audit for 1:1 accuracy with current state.

**What changed:**

- **NEW scenarios:** 
  - `tests/scenarios/scenario-10-phased-rebuild-walkthrough.md` — phased legacy rebuild tutorial (Iter 35 phase discoverability)
  - `tests/scenarios/scenario-11-model-tier-override.md` — model tier override tutorial (Iter 34)
- **Scenarios chooser** (`tests/scenarios/README.md`) — now lists all 11 scenarios + upgrade-guide pointer
- **README audit** — fixed stale "13-layer anti-hallucination" header (now 15-layer per Iter 33 F3+F4 additions); fixed stale v3.18.1 reference; normalized "What's new" structure

**Why this matters:** field-test feedback — users coming to mega-sdd needed walkthroughs for the Iter 34/35 features. Now every iter has either a scenario OR a reference doc serving as tutorial.

**Plugin v3.26.1 → v3.26.2** (PATCH — pure documentation; no skill behavior changes).

### v3.26.1 (Iter 36, patch) — Upgrade-from-old-version guide

For users coming from older mega-sdd versions: see `plugins/mega-sdd/references/upgrade-from-old-version.md`. Consolidates compat matrix + migration commands + halt recovery + decision tree (Path A regenerate vs Path B preserve). Documentation-only patch; no behavior change.

### v3.26.0 (Iter 35) — Reading Map + Phase Discoverability

mega-sdd now tells you **where to look at each pipeline stage** + **what phase your vault represents**.

**What changed:**

- **NEW: `plugins/mega-sdd/references/reading-map.md`** — user-facing guide indexed by pipeline stage. "After stage X, look at file Y at location Z." ⭐ marks primary entry-point per stage.
- **Phase fields in `vault.json`** — `phase` + `phase_total`. Surfaces at top of `00-index.md §Phase context`: "Phase 1 of 3" + upcoming phases + next-phase command.
- **`generate-intent --phase=N` flag** — bootstrap Phase 2/3+ vaults from the same KB. Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for the plan.
- **End-of-chain hint** — execute-bolts + orchestrate-flow surface "Phase 1 complete. Phase 2 next: run `/mega-sdd:generate-intent --kb=<KB> --phase=2`" when applicable.

**Why this matters:**

Before: vault only contained Phase 1; user had to know `suggested-phasing.md` existed deep in the KB. Now: vault tells you the phase + how to get to next phase. No more "where's Phase 2?" friction.

**Audit closure:** all mega-sdd-generated files live under `.mega-sdd/` or `~/.mega-sdd/` (verified). AGENTS.md at repo root is INTENTIONAL (tool-interop standard). One stale doc line fixed in scan-codebase.

**Plugin v3.25.0 → v3.26.0.**

See [docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md](../../docs/superpowers/specs/2026-05-24-iter-35-reading-map-and-phase-discoverability-design.md) for full design.

### v3.25.0 (Iter 34) — Dynamic Model Selection

mega-sdd now picks the **best model per subagent dispatch** instead of inheriting the caller's model. Curated catalog maps 17 named subagent roles to tier (haiku / sonnet / opus) with explicit rationale per entry.

**What changed:**
- **Catalog at `plugins/mega-sdd/references/model-tiers.md`** — 17 roles + tier + rationale + selection rubric
- **orchestrate-flow Step 2.8** — resolves override chain (CLI flag > project config > user preference > catalog default); emits `metadata.model_tiers:` in handoff
- **3 opus + 12 sonnet + 2 haiku** distribution by design (sonnet-dominant)

**Why this matters:**
Before: every subagent dispatch silently inherited the main thread's model. Opus for everything (expensive) OR inconsistent (depending on caller). No way to express "this synthesis needs opus" vs "this probe scoring is fine on haiku".

After: catalog explicit. extract-intelligence wave-5 (holistic synthesis) → opus. intelligence-audit-probe (0-3 scoring) → haiku. Most fuzzy-classification work → sonnet. User can override any role at any level (CLI / project / user).

**Override examples:**
```bash
# CLI: cheap reviews this run
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md

# Project: team prefers cheaper synthesis
# <project>/.mega-sdd/config.yaml:
model_tiers:
  extract-intelligence-wave-5: sonnet
```

**Plugin v3.24.0 → v3.25.0.**

See [docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md](../../docs/superpowers/specs/2026-05-24-iter-34-dynamic-model-selection-design.md) for full design.

### v3.24.0 (Iter 33) — Flawless Seamless Intelligence

**Combined mega-iter:** orchestrator becomes intelligent + handoffs become flawless.

**What changed:**

Smart orchestrator:
- **F1 Memory-driven routing** — orchestrator now learns from past runs. After ≥3 successful runs of the same project shape, orchestrator recommends the proven chain (overriding default routing-rules.md). Fall-through silently for fresh projects.
- **F2 Predictive halt detection** — orchestrator runs lightweight preflight checks BEFORE invoking each skill in chain. Instead of "scan-codebase halted on dep_missing 8 min in", you see "before chain starts: tree-sitter not installed; install or use --engine=regex" — actionable upfront.

Solid handoffs:
- **F3 Schema validation gate** — every handoff YAML validated against handoff-contract.md at emission. Missing REQUIRED/CONDITIONAL field = `invalid_handoff` halt at producer side (immediate developer feedback, not silent consumer miss).
- **F4 Type-checked field propagation** — handoff-contract.md now declares TYPE annotations. Field type mismatch = `handoff_type_mismatch` halt. Prevents silent shape drift (e.g., scope.id being string in one skill but object in another).

**Phase A foundation:** closes 3 of Iter 31's audit areas (handoff YAML sweep + halt taxonomy sync + stale name sweep) to enable F3/F4 enforceability without breaking existing pipelines.

**Phase B audit:** `docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md` documents intelligence gaps across all 13 skills with prioritized Iter 34+ candidates.

**orchestrate-flow major bump v2.5.1 → v3.0.0:** new procedure steps + 4 new halts may stop chains where prior versions wouldn't (all backward-compat by default — fall-through on missing memory/checks/schema).

**Plugin v3.23.0 → v3.24.0.**

See [docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md](../../docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md) for full design.

### v3.23.0 (Iter 32) — Starterkit-Aware Deep Scan

mega-sdd now **automatically** captures your starterkit's actual auth/RBAC/UI-UX/library patterns and feeds them through the pipeline — no flags, no config.

**What changed:**
- `scan-codebase` v2.6.0+ runs a deep-scan stage automatically when a framework is detected. 4 parallel subagents read your manifests + actual code to extract: which auth lib (Sanctum/Breeze/Jetstream/Fortify/Passport), which RBAC lib (Spatie/permission/custom), which UI stack (Alpine/Livewire/Inertia + Tailwind/Bootstrap + SweetAlert/Toastr), and your full library inventory with usage hints.
- Output: `.mega-sdd/codebase/starterkit-context.yaml` — canonical structured context, cached via lock-file hashing (re-scan with unchanged deps is 0sec).
- `generate-units` v2.6.0+ reads the context and adds starterkit-specific Anchors and Hard Rules to each unit with mandatory citations. Your unit specs now know about `layouts.app`, `User` model FQCN, your Spatie middleware names, your SweetAlert2 component path.
- `execute-bolts` v2.7.0+ injects a relevant slice (≤2KB, per-unit) into the bolt-dispatch-prompt T2 tier. Bolts generate code that matches your starterkit by default — uses your layout, your notification lib, your auth guard.

**Why this matters:**
- Before: generated units used framework defaults; bolts produced code that didn't always match your starterkit's libs.
- After: your starterkit's choices propagate automatically. Standing prefs like SweetAlert2 + `document.addEventListener` over `$(document).ready` + responsive mobile-first flow into Hard Rules with citations — no per-session reminder needed.

**Autonomous by design:**
- Zero user flags. Zero config. Triggers automatically when `scan-codebase` detects a framework at MEDIUM+ confidence.
- Graceful degradation: subagent timeouts → partial output; all-fail → preserve prior cache + halt for retry; no framework detected → skip silently.

See [docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md](../../docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md) for the full design.

---

### v3.22.0 (Iters 17-30)

- **Iter 17 Constitution layer** — 8th vault file (`constitution.md`) with project-facing rules; clauses inject into bolt Hard Rules
- **Iter 18 Replay + PBT** — `/mega-sdd:replay <unit>` for regression detection; `properties:` field for invariant testing
- **Iter 19 Convergence loops** — `/mega-sdd:auto --converge` auto-recovers eligible halts using memory recommendations
- **Iter 20 Audit fixes** — closed 5 claim-vs-implementation gaps from Iter 17-19
- **Iter 21 Path-default hotfix** — all writer-side defaults flip to `.mega-sdd/` (no excuse); read-side back-compat preserved
- **Iter 22 KB-as-analysis philosophy** — 3-tier mutability classification (`[LOCKED]/[INTENT]/[ARTIFACT]`) orthogonal to existing confidence markers. KB drives reengineering recommendations, not 1:1 legacy mirror. `data-mutation-policy.md` + ERD Quality Rails. `generate-intent --kb` routes claims to vault per tier
- **Iter 23 Framework Convention Packs** — pluggable convention catalog at `references/framework-conventions/`. scan-codebase detects framework (Laravel/Django/Rails/Express/NestJS/FastAPI/etc.) → bind-codebase loads matching pack → framework-specific Hard Rules merged into Suggested Unit Hard Rules. Universal-good-practice fallback. v1.0 ships with `_universal.md` + `laravel.md` + `_template.md` for adding more
- **Iter 24 RECON / base-laravel-26 starterkit pack** — extracted user's Laravel 12 starterkit conventions (Vuexy + Jetstream + Spatie + Reverb + custom helpers/traits + CRUD generator + notification rule engine) into `laravel-base-26.md` (~600 lines, extends `laravel.md`). 11 Hard Rules + 11 forbidden patterns + project-specific idioms encoded as enforceable conventions. scan-codebase detects via Vuexy fingerprint
- **Iter 25 Audit closure** — closed 27 findings from v3.16.0 deep audit: completed Iter 21 hotfix across 6 commands + handoff-contract + memory schema + recommendation-context + checkpoint paths; fixed bind-codebase step sequence (duplicate 2.5 + dangling 2.10) + halt-conditions completion; fixed generate-units step jumble; propagated Iter 22 mutability to 6 consumer skills (bind, drift, resolve-oq, generate-units, agents-md, handoff); propagated Iter 23 framework pack to generate-units (provenance citation) + execute-bolts + AGENTS.md header; fixed 2 broken cross-references; updated scenario-4 to demo tier flow + starterkit detection
- **Iter 26 Verification closure** — closed 5 highest-leverage gaps from v3.17.0 verification audit: emit-agents-md output template now uses `{{vault_path}}` substitution (no more legacy paths in every AGENTS.md emitted); bind-codebase step 2.10 placed in linear sequence; generate-units 7.5/7.6 swap + audit log → step 13; diff-vault:318 cross-ref fixed; commands/orchestrate-flow.md refreshed for `--deep` + `--resume`; AGENTS.md schema gains PBT/replay/convergence header fields (P1-9)
- **Iter 27 Starterkit-first pipeline** — scan-codebase moves to FIRST phase when starterkit detected; vault generation becomes pack-aware via dual-citation format (Intent + Starterkit binding). Three modes: A (starterkit-first DEFAULT), B (framework universal fallback), C (explicit `--greenfield`). New halt `no_starterkit_detected` enforces opinion. Per user directive "starterkit itu wajib ada, jika tidak ada baru greenfield"
- **Iter 28 Multi-scope PRD picker** — canonical PRD/BRD format with `scopes:` frontmatter block enables deterministic scope detection. Each architect (BE/MW/FE) generates a vault scoped to ONLY their content. Interactive picker (cwd smart default + memory-driven recall + confirm-once). Legacy PRDs without frontmatter trigger AI-assisted retrofit bridge. No cross-scope orchestration — coordination remains human-driven (rapat antar arsitek). New `--scope=<id>` flag in `/mega-sdd:auto` + `/mega-sdd:generate-intent`. Governance artifact: `docs/templates/prd-template.md` for sharing with PMs as new SOP
- **Iter 29 v3.20.0 audit closure** — 13 findings closed from post-Iter-28 deep audit (`docs/superpowers/audits/2026-05-24-iter-28-v3.20.0-deep-audit.md`). Pattern was Iter 28 producer-only: generate-intent wrote scope to vault.json + handoff YAML, but ZERO downstream skills consumed it. Fix: scope propagation to 6 consumer skills (bind-codebase v1.9.3, generate-units v2.5.4, emit-agents-md v1.2.4, execute-bolts v2.4.2, detect-drift v1.2.2, resolve-oq v0.9.1). Also: diff-vault v1.3.0 implements prd_sha256 change detection (closed unimplemented spec claim). Orchestrate-flow v2.4.1 halt taxonomy gains 4 new entries (3 Iter 28 + 1 Iter 29). Generate-intent gains formal §Halt conditions section with full YAML envelope examples. Step 0.9 execution-order guard added (file order ≠ runtime order). agents-md-schema.md stale legacy vault paths fixed
- **Iter 30 execute-bolts seamless pipeline** — bolt subagent dispatched via tiered context enrichment (T1 always ≤2KB / T2 conditional ≤5KB / T3 reference-on-demand) per `references/bolt-dispatch-prompt.md`. Implements 10 AI-executor principles from spec (anti-context, confidence labels, past-failure intelligence, self-assessment vocabulary, halt vocabulary, validation hints, atomic discipline, provenance trailers, graceful partial-state). Plus seamless pipeline: compact streaming progress + aggregate `<vault>/bolts/_summary.md` + propose-and-confirm halt UX (AI fix proposer for test_fail / hard_rule_violated / pbt_property_violated; user single-click approve) + auto-drift gate DEFAULT-ON after batch (~6x faster via shared snapshot reuse) + DRIFT-REPORT.md `## Suggested next actions` with auto-handoff commands + convergence loops bridge bolt halts. New halts: dispatch_prompt_too_large, bolt_repeated_partial_failure, provenance_missing, self_assessment_missing, bolt_introduces_locked_drift

## Anti-hallucination defense (15 layers)

1. **Intent** — uncertain claims promote to Open Questions
2. **OQ classification** — business vs tech; tech auto-resolves
3. **Binding gate** — CONFLICT blocks
4. **Implementation state** — IMPLEMENTED / NEW / PARTIAL_FIELDS_MISSING / UNKNOWN
5. **Unit grounding** — target_files whitelist + acceptance_test + Anchors
6. **Hard Rules pre/post-flight** — ast-grep validates at bolt time
7. **AST-precise extraction** — tree-sitter (Aider pattern)
8. **Memory** — suggestion-only with audit log
9. **Drift detection** — code vs vault reconciliation
10. **Interface lock** — cross-squad consumed interfaces must be locked
11. **Mutability tier classification** — [LOCKED]/[INTENT]/[ARTIFACT] orthogonal to confidence (Iter 22)
12. **Constitution layer** — project invariants enforced as Hard Rules at bolt time (Iter 17)
13. **Framework convention packs** — laravel/django/rails/etc. conventions inject into Suggested Unit Hard Rules (Iter 23)
14. **Predictive preflight** — orchestrate-flow surfaces upcoming halts before they fire (Iter 33 F2)
15. **Handoff schema validation** — handoff YAML type-checked against handoff-contract.md per skill (Iter 33 F3+F4)

## Memory layer (v2.1+)

Three scopes of markdown + JSON memory persist context across sessions:

- `~/.mega-sdd/memory/` — USER (opt-in, cross-project)
- `<project>/.mega-sdd/memory/` — PROJECT (per-repo, git-trackable per-file)
- `<vault>/.memory/` + `<vault>/.internal/checkpoints/` — VAULT (per-vault, ephemeral)

Self-learning via threshold-based suggestions reviewed through `/mega-sdd:memory review`. Never auto-applied. Mandatory audit log + rollback path. Complementary to Claude Code's `auto memory`.

## Reuse-stable tooling (Iter 14)

Mega-sdd ADOPTS stable native binaries instead of building from scratch (all OPTIONAL with graceful fallback):

| Tool | Used by | Fallback |
|---|---|---|
| `tree-sitter` | scan-codebase (AST extraction) | regex |
| `ast-grep` | execute-bolts (Hard Rules v2) | v1 5-type grammar |
| `ripgrep` (`rg`) | scan-codebase / detect-drift / bind-codebase / lint-units | GNU grep |
| `jd` | diff-vault (canonical JSON/YAML patches) | manual Read+compare |
| `markdownlint-cli2` | lint-units (vault prose) | skill-internal heuristics |
| `gh` (GitHub CLI) | optional PR automation | manual PR by user |

See [`references/tooling-install.md`](./references/tooling-install.md) for one-command install per platform.

See the [root README](../../README.md) for diagrams, full command table, halt protocol, autonomy mechanics, migration guide.

## Contributing

Read [`CLAUDE.md`](./CLAUDE.md) first if you're an AI agent submitting a PR — anti-slop protocol applies. Every behavior change traces back to a spec doc in [`../../docs/superpowers/specs/`](../../docs/superpowers/specs/).

For human contributors: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md).

## License

MIT. Vendored superpowers skills retain their original MIT license — see [`skills/_vendored/ATTRIBUTION.md`](./skills/_vendored/ATTRIBUTION.md). Tree-sitter `.scm` query patterns adapted from [Aider](https://github.com/Aider-AI/aider) (Apache 2.0) — see `skills/scan-codebase/queries/`.
