# Iter 33 — Flawless Seamless Intelligence (Orchestrator + Handoffs)

**Status:** Design approved 2026-05-24
**Plugin target:** v3.23.0 → v3.24.0 (orchestrate-flow 2.5.1 → 3.0.0)
**Iter type:** Combined mega-iter (cleanup + audit + features) — ~28-33hr
**Predecessor context:**
- Iter 31 v3.22.0 full pipeline audit (`docs/superpowers/audits/2026-05-24-iter-31-v3.22.0-full-pipeline-audit.md`) — 179 findings, RED, mostly OPEN
- Iter 32 v3.23.0 starterkit-aware deep scan (`docs/superpowers/specs/2026-05-24-iter-32-starterkit-aware-deep-scan-design.md`) — shipped 2026-05-24

---

## Background and motivation

After 32 iterations, mega-sdd has 13 skills, a working pipeline, and a known 179-finding audit debt (Iter 31). User directive: "review and audit all the skill in this project. gue pengen semua proses itu seamless dan super intellegence" — refined to "and flawless. orchestratornya bisa pintar, dan punya hands-off yang solid".

The refined goal: the CENTER must hold — orchestrate-flow becomes a smart router/reasoner (not just pattern-matching), and handoff-contract becomes a rock-solid contract enforced by validation. Per-skill polish comes second; if the center is intelligent and the contract is bulletproof, the whole pipeline benefits.

This iter combines three traditionally-separate concerns into one mega-iter:
- **Phase A — Mechanical closure** of Iter 31 audit findings that affect orchestrator + handoff foundation. Without this cleanup, Phase C's stricter validation gate would regress every existing pipeline.
- **Phase B — Intelligence audit** with a NEW lens (smart-routing readiness, halt UX, predictive-halt potential, memory utilization, confidence-driven behavior, halt-recovery clarity) — different dimensions than Iter 31's correctness audit. Produces AUDIT-INTELLIGENCE.md that informs Phase C feature specifics.
- **Phase C — 4 intelligence features**: memory-driven routing + predictive halt detection (smart orchestrator) + schema validation gate + type-checked field propagation (solid handoffs).

The composition matters: Phase A first removes regression risk for Phase C's validation gate. Phase B middle gives high-signal findings on a clean baseline (not muddled by correctness debt). Phase C last builds on baseline + audit guidance.

---

## §1 Architecture overview

### 1.1 Three-phase composition

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase A — Mechanical closure (~7-8hr)                           │
│ Close 3 of Iter 31's top 5 areas (the orchestrator+handoff      │
│ foundation ones). Defer 2 areas to Iter 34.                     │
│   A1: Handoff YAML schema sweep (scope/mutability/constitution) │
│   A2: Orchestrate-flow halt taxonomy + vault-contract enum sync │
│   A3: Stale name sweep (source_skill enum + broken cross-refs)  │
│ Deliverable: clean baseline for Phase B audit + Phase C builds  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Phase B — Hybrid intelligence audit (~5-6hr)                    │
│   Deep audit: orchestrate-flow SKILL.md + handoff-contract.md   │
│     6 intelligence dimensions                                   │
│   Light per-skill probe: 1 question/skill (0-3 score)           │
│   Deliverable: AUDIT-INTELLIGENCE.md with prioritized gaps      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Phase C — 4 intelligence features (~12-15hr)                    │
│                                                                  │
│   Smart orchestrator:                                            │
│     F1. Memory-driven routing (orchestrator learns from past)    │
│     F2. Predictive halt detection (warns before invoking)        │
│                                                                  │
│   Solid handoffs:                                                │
│     F3. Schema validation gate (every handoff validated)         │
│     F4. Type-checked field propagation (no shape drift)          │
│                                                                  │
│ Each feature ships producer+consumer in-iter (no producer-only  │
│ debt per standing directive)                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
   Tests + scenario + CHANGELOG + release (~3-4hr)
```

### 1.2 Why this composition

- Phase A first: Phase C features need clean foundation. F3 schema validation gate would otherwise reject EVERY existing handoff because Iter 31 audit found 8 templates missing required blocks. Cleanup → gate becomes enforceable without regression.
- Phase B middle: with clean baseline, intelligence audit findings are HIGH-SIGNAL (not muddled by correctness gaps). Audit informs F1+F2 specifics (which routing patterns to detect; which halts to predict).
- Phase C last: features build on baseline + audit guidance.

### 1.3 Skill version bumps

| Skill | From | To | Reason |
|---|---|---|---|
| `orchestrate-flow` | 2.5.1 | **3.0.0** | MAJOR: 4 new features add new procedure steps; new halts may stop pipelines that previously continued; semver warrants major bump |
| `memory` | 1.2.1 | 1.3.0 | NEW schema: `routing-outcomes.md` for orchestrator learning |
| `generate-intent` | 1.12.0 | 1.13.0 | handoff-contract.md schema changes; 4 new halts in vault-contract type enum (synchronized) |
| `bind-codebase` | 1.9.3 | 1.9.4 | Phase A handoff YAML closure (patch) |
| `detect-drift` | 1.4.0 | 1.4.1 | Phase A handoff YAML closure |
| `diff-vault` | 1.3.0 | 1.3.1 | Phase A handoff YAML closure (+ artifact list fix) |
| `emit-agents-md` | 1.2.4 | 1.2.5 | Phase A handoff YAML closure |
| `execute-bolts` | 2.7.0 | 2.7.1 | Phase A scope: block verification (mostly already present from Iter 32) |
| `extract-intelligence` | 1.4.0 | 1.4.1 | Phase A handoff YAML closure |
| `generate-units` | 2.6.0 | 2.6.1 | Phase A scope: block verification |
| `resolve-oq` | 0.9.1 | 0.9.2 | Phase A handoff YAML closure |
| `scan-codebase` | 2.6.0 | 2.6.1 | Phase A scope: block verification |
| `using-mega-sdd` | 1.3.1 | 1.3.2 | Phase A path canonicalization in test fixture |

**Plugin:** v3.23.0 → v3.24.0 (minor — additive features; orchestrate-flow major bump is internal to the plugin)

### 1.4 Iter 31 areas DEFERRED to Iter 34 (NOT in this iter)

- Iter 31 Closure Area 3: `execute-bolts` Step 4.5 reorder + snapshot schema alignment (~3hr) — per-skill behavioral risk; not orchestrator-relevant
- Iter 31 Closure Area 5: Test fixture backfill — Iters 25-30 critical gaps (~4hr) — Iter 32 already added 12 trigger tests + 1 scenario; remaining gaps less critical

---

## §2 Phase A — Mechanical closure (~7-8hr)

Closes 3 of Iter 31's top 5 areas. Pick was made because these 3 are FOUNDATION for Phase C features — closing them removes regressions that would otherwise be triggered by Phase C's stricter schema gate.

### 2.1 Closure Area 1 — Handoff YAML schema sweep (~3hr)

Closes 12 P1 findings from Iter 31 Dim 3.

| Skill SKILL.md handoff template | Missing block(s) to add |
|---|---|
| `bind-codebase` | `scope:`, `mutability:`, `constitution:` |
| `detect-drift` | `scope:` |
| `diff-vault` | `scope:`, fix artifact list (VAULT-DIFF.md missing) |
| `execute-bolts` | `scope:` (claimed but absent per Iter 32 audit follow-up) |
| `generate-intent` | `scope:`, `mutability:` |
| `generate-units` | verify `scope:` already present per Iter 32 |
| `resolve-oq` | `scope:`, `items_blocked` metric |
| `scan-codebase` | verify `scope:` already present from Iter 32 alongside `starterkit_context:` |
| `handoff-contract.md` per-skill examples | add sections for diff-vault, emit-agents-md, resolve-oq, detect-drift (currently absent) |

Single atomic commit modifies all 8 SKILL.md files + handoff-contract.md.

### 2.2 Closure Area 2 — Halt taxonomy + vault-contract enum sync (~2hr)

Closes 13 P1 findings from Iter 31 Dim 4. 15 halt types added to BOTH orchestrate-flow ALWAYS-STOP list AND vault-contract type enum (synchronized commit pattern from Iter 32 Task 4):

```
bind_conflict_constitution_violation, framework_pack_missing, framework_pack_cycle,
framework_pack_unparseable, constitution_drift_detected, drift_framework_mismatch,
diff_conflict, memory_in_use, dispatch_prompt_too_large, bolt_repeated_partial_failure,
provenance_missing, bolt_introduces_locked_drift, self_assessment_missing, dep_missing,
oq_recommend_citation_invalid
```

Each gets ALWAYS-STOP entry + type enum entry + short description. Plus per-skill `Status halted on:` lines updated in handoff-contract.md to reference each halt at its emitting skill.

Single atomic commit modifies orchestrate-flow SKILL.md + vault-contract.md + handoff-contract.md.

### 2.3 Closure Area 4 — Stale name sweep (~2hr)

Critical for Phase C F4 type-checked propagation — stale names in `source_skill:` enum would otherwise be enforced as valid by validation gate. Must fix first.

| File | Replacement |
|---|---|
| `vault-contract.md` line 523 `source_skill:` enum | `grand-design-spec` → `generate-intent`, `vault-diff` → `diff-vault`, `drift-detect` → `detect-drift` |
| `vault-contract.md` §when-skills-must-regenerate lines 60/62/63 | Same renames |
| `vault-contract.md` prose lines 3, 508, 519 | `grand-design-spec` → `mega-sdd` |
| `from-prompt-mode.md` | `../grand-design-spec/` → `./` ; `../flow/` → `../../orchestrate-flow/` |
| `resolve-oq/SKILL.md` line 551 | `../grand-design-spec/references/vault-contract.md` → `../generate-intent/references/vault-contract.md` |
| `tests/skill-triggering/memory.test.md`, `e2e-memory-self-learning.test.md`, `resolve-oq.test.md`, `emit-agents-md.test.md`, `using-mega-sdd.test.md`, `scan-codebase.test.md` | `.mega-sdd-memory/` → `.mega-sdd/memory/` |
| `commands/scan-codebase.md` | `<repo-root>/codebase-map.md` → `.mega-sdd/codebase/codebase-map.md` |
| `emit-agents-md/SKILL.md` | config path `<project>/.mega-sdd/memory/config.yaml` → `<project>/.mega-sdd/config.yaml` |

Single atomic commit using grep-and-replace with confirmation; touches ~8 files.

### 2.4 Phase A delivery model

3 tasks, 3 atomic commits. After Phase A: clean baseline ready for Phase B audit + Phase C features.

---

## §3 Phase B — Hybrid intelligence audit (~5-6hr)

Different lens than Iter 31's correctness audit. Phase B asks: "is this SMART?" — not "is this WELL-FORMED?"

### 3.1 Deep audit — orchestrate-flow + handoff-contract.md

Single subagent (model: sonnet). Reads orchestrate-flow SKILL.md + 3 reference files + memory-schema.md + vault-contract.md + shared-snapshot-schema.md + starterkit-context-schema.md.

**6 intelligence dimensions** (each evaluated as STRONG / WEAK / ABSENT with evidence):

| Dim | Question | Examples of WEAK/ABSENT |
|---|---|---|
| **D1: Smart-routing readiness** | Does orchestrator consult memory before routing decisions, or always follow hardcoded routing-rules.md? | Hardcoded "starterkit + brownfield → scan-codebase first" ignores that project's last 5 runs had scan-codebase always producing empty starterkit-context (signal: skip deep-scan this time) |
| **D2: Handoff schema completeness** | Does handoff-contract.md schema cover EVERY field that propagates between skills? Are there orphan fields with no schema? | scope/mutability/constitution/pbt/cycles/replay all top-level — but no schema validation enforcement; producers can omit; consumers silently miss |
| **D3: Predictive-halt potential** | Does orchestrator preflight-check known halt preconditions BEFORE invoking skill, OR only react after halt fires? | scan-codebase halts on `dep_missing` (tree-sitter binary absent) — orchestrator could check `command -v tree-sitter` at routing-time and warn user upfront |
| **D4: Memory utilization** | Does orchestrator USE memory slices (memory_context, outcomes, patterns) to inform routing/recovery, or just pass-through to skills? | metadata.memory_context flows TO skills but orchestrator itself never reads memory to inform ITS OWN routing/cycle decisions |
| **D5: Confidence-score consumption** | Does orchestrator adjust behavior based on confidence scores in handoffs (framework.confidence, grounding_confidence, classifier-accuracy)? | scan-codebase reports framework.confidence=LOW — orchestrator currently routes the same regardless; could route to greenfield instead |
| **D6: Halt-recovery clarity** | When orchestrator surfaces a halt to user, is `next_action.hint` ACTIONABLE (concrete fix) or VAGUE ("review the unit")? | Many halts have hints like "edit the unit"; user has to figure out which fields, which lines, what change |

### 3.2 Light per-skill intelligence probe

Single subagent (model: sonnet). Asks ONE focused question across all 13 skills:

> "Does `<skill>` CONSUME memory/confidence/scope-context to inform its decisions, or just read/write mechanically?
>
> Score on 0-3:
> - **0**: mechanical only; no context-driven adaptation
> - **1**: reads context but doesn't significantly alter behavior
> - **2**: reads context AND adjusts ≥1 decision based on it
> - **3**: context-driven throughout; multiple decisions adapt"

For each skill: score + 1-sentence justification + 1 suggested intelligence upgrade.

### 3.3 Audit deliverable structure

`docs/superpowers/audits/2026-05-24-iter-33-intelligence-audit.md`:

```markdown
# Intelligence Audit Report — mega-sdd v3.24.0 (Iter 33, Phase B)

## Summary
[Overall verdict + count of WEAK/ABSENT findings + top 3 themes]

## Deep audit findings (6 dimensions × orchestrator + handoff-contract)

### D1: Smart-routing readiness
[STRONG | WEAK | ABSENT verdict + evidence + suggested intelligence pattern]

### D2 - D6 [similar]

## Per-skill intelligence scorecard (13 skills × 0-3 score)

| Skill | Score | Justification | Suggested upgrade |
|---|---|---|---|

## Cross-cutting patterns

[Patterns spanning ≥3 skills]

## Recommended Phase C feature design inputs

[How Phase B findings inform the 4 Phase C feature specs]

## Methodology notes
```

### 3.4 Phase B delivery

1 task: dispatch 2 parallel subagents (deep audit + per-skill probe), consolidate into single AUDIT-INTELLIGENCE.md, commit. ~5-6hr total wall-clock.

---

## §4 Phase C — 4 intelligence features (~12-15hr)

Each feature ships producer + consumer in-iter. Features sequenced so later ones build on earlier ones.

### 4.1 Feature F1: Memory-driven routing

**Goal:** orchestrator learns from past runs. "For THIS project shape (manifest fingerprint + scope + framework), past 5 runs converged faster when starterkit-first was used; route accordingly."

**Mechanism:**

New memory file at project scope: `<project>/.mega-sdd/memory/routing-outcomes.md`. Append-only log:

```markdown
# Routing Outcomes

> Append-only log of orchestrator routing decisions + outcomes.

## Schema

Per row: `<date> | <project-fingerprint> | <chain-used> | <duration-min> | <converged> | <halts-fired>`

## Entries

2026-05-24 | laravel-base-26+sanctum+spatie-permission | starterkit-first (scan→intent→bind→units→bolts) | 12 | yes | 0
2026-05-25 | laravel-base-26+sanctum+spatie-permission | starterkit-first | 8 | yes | 0
2026-05-26 | nextjs-app-router+nextauth | direct (intent→units→bolts) | 18 | no | 3
```

orchestrate-flow gains **Step 0.7 — Memory-informed routing preflight** (between existing Step 0 + Step 1):

```
0.7.a Compute project fingerprint: sha256(composer.json + package.json + framework_pack)[:16]
0.7.b Read .mega-sdd/memory/routing-outcomes.md; filter rows matching this fingerprint
0.7.c If ≥3 prior runs with consistent successful chain: recommend that chain as default
       (override routing-rules.md default, log reason)
0.7.d If prior runs show pattern of failures with specific chain: flag warning to user
0.7.e If no prior runs match fingerprint: fall through to routing-rules.md default
```

Post-run: orchestrate-flow appends new row (Step 6 — End-of-chain memory write).

**Files:**
- NEW: `plugins/mega-sdd/skills/memory/references/routing-outcomes.md` (schema doc)
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 0.7 + Step 6 memory write)
- MOD: `plugins/mega-sdd/skills/memory/SKILL.md` (+ §Memory layer §VAULT scope: add routing-outcomes.md row)
- MOD: `plugins/mega-sdd/references/paths.md` (+ row for `.mega-sdd/memory/routing-outcomes.md`)

**New halt:** `routing_outcome_corrupt` (SOFT — auto-invalidate + log; chain proceeds with default).

**Backward-compat:** when routing-outcomes.md absent OR no fingerprint match → fall through to routing-rules.md (no behavior change for fresh projects).

### 4.2 Feature F2: Predictive halt detection

**Goal:** orchestrator anticipates failure modes BEFORE invoking the failing skill. Instead of "scan-codebase halted on dep_missing 8 minutes in", user sees "before chain starts: tree-sitter not installed; install or use --engine=regex".

**Mechanism:**

New file: `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` — catalog of preflight checks per skill. Each entry:

```markdown
### scan-codebase preflight checks

- **check_id: `tree_sitter_present`**
  command: `command -v tree-sitter || command -v tree-sitter-cli`
  expected: exit 0
  on_fail: warn user "tree-sitter not installed; will fall back to regex engine"
  fatal: no
  predicts_halt: dep_missing

- **check_id: `framework_pack_present`**
  command: detect framework + check `references/framework-conventions/<framework>.md` exists
  expected: pack file exists
  on_fail: warn "no framework pack for <framework>; using universal fallback"
  fatal: no
  predicts_halt: framework_pack_missing

### bind-codebase preflight checks [...]
### execute-bolts preflight checks [...]
```

orchestrate-flow gains **Step 2.5 — Predictive preflight** (between Step 2 routing decision + Step 3 first-skill invocation):

```
2.5.a For each skill in computed chain:
       Read references/predictive-checks.md §<skill> entries
       Run each check (lightweight: bash command or file existence)
2.5.b Collect failures:
       - non-fatal → accumulate as warnings; show to user; chain proceeds
       - fatal → halt chain with predictive_check_failed envelope
2.5.c If user opted-in via --auto, fatal predictive halts STOP the chain (no auto-bypass)
```

**Files:**
- NEW: `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` (~150 LOC initial catalog covering 5-6 highest-leverage checks)
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 2.5 + handoff metrics `predictive_warnings_count` + `predictive_halts_count`)
- MOD: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ `predictive_check_failed` halt type)

**New halt:** `predictive_check_failed` (ALWAYS STOP — fires only when check marked `fatal: yes`).

**Backward-compat:** when predictive-checks.md absent → Step 2.5 logs "no predictive checks defined; skipping preflight"; chain proceeds.

### 4.3 Feature F3: Schema validation gate

**Goal:** every handoff YAML validated against `handoff-contract.md` schema at emission time. Eliminates "field claimed in skill body prose but missing in handoff template" pattern (iter-31 audit root cause).

**Mechanism:**

Convert handoff-contract.md schema to use explicit required/optional annotations:

```markdown
### `status:` (REQUIRED)
enum: completed | paused | halted

### `artifacts:` (REQUIRED)
array of absolute paths; non-empty if status==completed

### `scope:` (REQUIRED if vault has scope_metadata, OPTIONAL otherwise — conditional)
object: { id, name, sibling_scopes, prd_sha256 }
```

orchestrate-flow gains **Step 4.5 — Handoff validation gate** (at handoff reception):

```
4.5.a Receive handoff YAML from completed skill
4.5.b Parse YAML; if parse fails → halt invalid_handoff
4.5.c Validate against handoff-contract.md §schema:
       - REQUIRED fields present? If not → halt invalid_handoff with field_name in details
       - Conditional REQUIRED fields: evaluate condition; if condition met but field missing → halt
       - Field types match schema? (deferred to F4)
4.5.d Validation pass → propagate handoff to next skill
```

**Files:**
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (REQUIRED/OPTIONAL/CONDITIONAL annotations on every field)
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 4.5)
- MOD: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ `invalid_handoff` halt type)

**New halt:** `invalid_handoff` (ALWAYS STOP — producer-side error caught immediately).

**Backward-compat:** Phase A handoff sweep ensures all 8 affected skill SKILL.md handoff YAML templates have required fields. F3 enforceability depends on Phase A.

### 4.4 Feature F4: Type-checked field propagation

**Goal:** handoff-contract.md defines TYPES for every field. Orchestrator validates types at propagation. Prevents silent shape drift.

**Mechanism:**

Extend F3's REQUIRED/OPTIONAL annotations with TYPE annotations:

```markdown
### `scope:` (REQUIRED if vault has scope_metadata)
TYPE: object {
  id: string (enum: BE | FE | MW | ...)
  name: string
  sibling_scopes: array<string>
  prd_sha256: string (sha256 hex)
}

### `status:` (REQUIRED)
TYPE: enum (completed | paused | halted)

### `mutability:` (REQUIRED if mutability-tier data)
TYPE: object {
  tier_distribution: object {
    LOCKED: int (≥0)
    INTENT: int (≥0)
    ARTIFACT: int (≥0)
  }
  locked_claims_touched: array<string>
  artifact_discards_proposed: int (≥0)
}
```

orchestrate-flow Step 4.5.c gets type-check sub-step (4.5.c.i):

```
4.5.c.i For each field present in handoff YAML:
         - Lookup TYPE in handoff-contract.md schema
         - Validate value matches TYPE
         - On type mismatch → halt handoff_type_mismatch with field_name + expected_type + actual_type
```

**Files:**
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` (TYPE annotations extending F3)
- MOD: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (+ Step 4.5.c.i)
- MOD: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` (+ `handoff_type_mismatch` halt type)

**New halt:** `handoff_type_mismatch` (ALWAYS STOP — schema violation caught immediately).

**Backward-compat:** strict-mode only when handoff-contract.md schema explicitly declares TYPE. Fields without TYPE annotation bypass type check (warn-only log). Gradual rollout.

### 4.5 Phase C delivery sequencing

| Task | Feature | Depends on | Wall-clock |
|---|---|---|---|
| C1 | F1 Memory-driven routing | Phase A | ~3hr |
| C2 | F2 Predictive halt detection | Phase A | ~3hr |
| C3 | F3 Schema validation gate | Phase A | ~3hr |
| C4 | F4 Type-checked field propagation | C3 (extends C3's annotations) | ~3hr |

C1+C2+C3 independent; C4 MUST run after C3.

---

## §5 Halt protocol + testing + risks

### 5.1 New halt types (4 total across Phase C)

All synchronized across 4 surfaces in ONE COMMIT per Phase (Phase A Task A2 pattern from Iter 32 Task 4):

| Halt type | Severity | Emitted by | Recovery |
|---|---|---|---|
| `predictive_check_failed` | ALWAYS STOP | orchestrate-flow (F2) | User fixes precondition (install missing dep, add framework pack) then re-runs |
| `invalid_handoff` | ALWAYS STOP | orchestrate-flow (F3) | Producer skill author fixes handoff template; immediate developer feedback |
| `handoff_type_mismatch` | ALWAYS STOP | orchestrate-flow (F4) | Producer skill author fixes type emission; surfaces silent shape drift early |
| `routing_outcome_corrupt` | SOFT | orchestrate-flow (F1) | routing-outcomes.md parse fails; auto-invalidate + log; chain proceeds |

Plus Phase A Task A2 adds 15 previously-unregistered halts to orchestrate-flow taxonomy + vault-contract enum (closing iter-31 P1 findings).

### 5.2 Halt YAML envelope (canonical schema only)

All 4 new halts MUST emit canonical envelope (source_skill + type + details + next_action) — NOT legacy `emitted_by`/`emitted_at` shape that iter-31 audit flagged.

Example:
```yaml
type: invalid_handoff
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  missing_field: "scope.id"
  field_required_because: "vault has scope_metadata"
  handoff_file: "<vault>/.internal/checkpoints/2026-05-24-bind-codebase.handoff.yaml"
next_action:
  type: edit_skill_template
  hint: "Edit plugins/mega-sdd/skills/bind-codebase/SKILL.md §Handoff emission YAML template to include scope: block per handoff-contract.md schema"
```

### 5.3 Audit-pattern prevention checklist

| Iter-31 pattern | Iter 33 prevention |
|---|---|
| Halt in skill but absent from orchestrate-flow taxonomy | All 4 new halts + 15 Iter 31 halts MUST appear in orchestrate-flow `## Halt types` section before merge (Phase A Task A2 + Phase C feature commits) |
| Halt in skill but absent from vault-contract type enum | Same — synchronized to vault-contract enum in same commit |
| Handoff YAML claim in prose but field missing in template | Phase A Task A1 closes this; Phase C F3 prevents recurrence by validation gate |
| Producer-only ship | F1/F2/F3/F4 each ship producer + consumer in-iter |
| Stale skill name fossils | Phase A Task A3 sweeps all known fossils |
| Test fixtures zero coverage | Test cases shipped per feature in Phase C tasks (§5.4) |

### 5.4 Testing strategy

**Trigger tests (12 new cases across 4 files):**

| File | New cases | Coverage |
|---|---|---|
| `tests/skill-triggering/orchestrate-flow.test.md` | OF-MR1, OF-MR2 (memory-driven routing override + no-prior-runs fallback); OF-PH1, OF-PH2 (predictive check warn + fatal halt); OF-VG1, OF-VG2 (schema validation gate pass + invalid_handoff halt); OF-TC1, OF-TC2 (type-check pass + handoff_type_mismatch halt) | 8 cases — F1-F4 happy + sad paths |
| `tests/skill-triggering/memory.test.md` | M-RO1 (routing-outcomes append on chain end); M-RO2 (routing-outcomes schema mismatch → routing_outcome_corrupt) | 2 cases — F1 memory schema |
| `tests/skill-triggering/scan-codebase.test.md` | SC-PH1 (predictive tree_sitter_present check warn) | 1 case — F2 catalog |
| `tests/skill-triggering/bind-codebase.test.md` | BC-PH1 (predictive binding_input_complete check) | 1 case — F2 catalog |

**Scenario test:** `tests/scenarios/scenario-9-flawless-seamless-intelligence.md` — full pipeline integration validates routing-outcomes.md write/read, predictive check upfront warning, schema validation gate halt, type check halt.

**Field test:** user runs `/mega-sdd:auto` on `/Users/farhanriuzaki/SunnyGo/2026/AIRND2026/Project/base-laravel-26`. First run writes routing-outcomes.md; second run consults it (cache hit on chain choice); predictive checks surface setup issues upfront.

### 5.5 Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Phase A closure (~7-8hr) finds more issues than Iter 31 estimated | Medium | Hard time-box Phase A at 8hr; defer unfixed items to Iter 34 with new finding IDs |
| F3 schema validation gate breaks existing pipelines | High if Phase A skipped; Low if Phase A completes | Phase A IS the prerequisite. Plan acceptance: F3 enables strict mode AFTER Phase A passes verification |
| F4 type checks too strict; legitimate handoffs fail | Medium | Fields without TYPE annotation bypass type check (warn-only log). Strict only on annotated fields. Gradual rollout |
| F1 over-recommends past chain when project shape changed | Medium | Fingerprint includes manifest hash — meaningful changes auto-invalidate cache. Only stable fingerprint matches trigger recommendation |
| F2 catalog becomes stale as skills evolve | Medium | predictive-checks.md OWNED by orchestrate-flow; iter that touches a skill MUST update its predictive checks (codified in plan acceptance) |
| Mega-iter scope (~30hr) overruns | Medium-High | 3-phase atomic structure allows partial ship: Phase A alone = useful; A+B = useful; A+B+C = ideal |
| orchestrate-flow v3.0.0 major bump is breaking | Low | All new behaviors additive (default-off for breaking parts; new halts only fire when feature triggers). Backward-compat preserved |
| Scope creep during Phase B audit | Medium | Phase C feature set LOCKED to 4 (chosen in Q2). Phase B findings beyond those 4 → Iter 34 candidate list |
| Phase B subagent dispatch failure | Low-Medium | Only 2 subagents (vs Iter 31's 13). Auto-retry once; on second failure, ship partial audit + flag |

### 5.6 Plugin version bump justification

`orchestrate-flow` 2.5.1 → **3.0.0** (major):
- Step 0.7 (memory-informed routing) — behavior change for ALL chains
- Step 2.5 (predictive preflight) — behavior change
- Step 4.5 (validation gate) — STRICT validation can halt where prior versions wouldn't
- 4 new halt types — chain may halt where prior versions wouldn't

These are backward-compatible by default (fall-through on missing memory/predictive-checks/schema). But "may halt where prior versions wouldn't" warrants major bump per semver.

Plugin v3.23.0 → v3.24.0 (minor — additive features at plugin level).

---

## Acceptance criteria

1. Plugin version bumped 3.23.0 → 3.24.0 with full CHANGELOG entry
2. orchestrate-flow v2.5.1 → v3.0.0 (major bump justified)
3. Phase A: 8 skill SKILL.md handoff YAML templates have required blocks (scope/mutability/constitution per applicability)
4. Phase A: 15 previously-unregistered halt types added to both orchestrate-flow taxonomy AND vault-contract enum in synchronized commit
5. Phase A: zero stale skill names (grand-design-spec/vault-diff/drift-detect/flow) in source_skill enums or test fixtures
6. Phase B: AUDIT-INTELLIGENCE.md written covering 6 dimensions + 13-skill scorecard
7. Phase C F1: routing-outcomes.md schema defined; orchestrate-flow Step 0.7 reads + Step 6 writes; memory schema doc updated
8. Phase C F2: predictive-checks.md catalog covers ≥5 highest-leverage checks; orchestrate-flow Step 2.5 fires on every chain
9. Phase C F3: handoff-contract.md every field annotated REQUIRED/OPTIONAL/CONDITIONAL; orchestrate-flow Step 4.5 validates; invalid_handoff halt registered
10. Phase C F4: handoff-contract.md every field annotated with TYPE; orchestrate-flow Step 4.5.c.i type-checks; handoff_type_mismatch halt registered
11. 4 new halt types synchronized across 4 surfaces (SKILL.md + vault-contract + orchestrate-flow + handoff-contract) in single commits per feature
12. 12 new trigger test cases + 1 scenario test + field test on base-laravel-26 all shipped in-iter
13. Anti-halu rails: validation gate is producer-side enforcement; type-check distinguishes annotated vs unannotated fields; memory-driven routing fall-through when no prior data

---

## Out of scope (deferred to Iter 34+)

- Iter 31 Closure Area 3: execute-bolts Step 4.5 reorder + snapshot schema alignment (~3hr) — per-skill behavioral; not orchestrator-relevant
- Iter 31 Closure Area 5: Test fixture backfill remaining gaps — Iter 32 already added 12 tests; remainder less critical
- Per-skill intelligence upgrades from Phase B per-skill probe (those become Iter 34+ candidates per priority)
- F1 cross-vault learning (each vault learns independently; no shared routing-outcomes pool)
- F2 dynamic check catalog updates (catalog is hand-curated; auto-derived catalog deferred)
- F3 deep-nested field validation (top-level + 1 level nesting only this iter; deeper nesting deferred)
- F4 cross-field validation rules (e.g., "if status==halted, blockers[] non-empty") — deferred
- Cross-skill convergence learning (orchestrator learns which convergence cycle limits work per project)

---

## Spec self-review checklist

- [x] No `TBD` / `TODO` / `fill in details` markers
- [x] 3-phase composition diagram (§1.1) matches phase ordering in §2/§3/§4
- [x] Iter 31 closure areas listed in §2.1-§2.3 + deferred in §1.4 — counts to 5 total (3 in scope + 2 deferred)
- [x] 4 Phase C features (§4.1-§4.4) each have: goal + mechanism + files + halt + backward-compat sections
- [x] 4 new halt types listed identically in §5.1 + §5.2 example + §5.4 trigger tests
- [x] Skill version bumps in §1.3 match §2 + §4 modified files (orchestrate-flow 3.0.0 + memory 1.3.0 + 11 patch bumps)
- [x] Acceptance criteria (13 items) traceable to spec sections
- [x] Audit-pattern prevention (§5.3) ties iter-31 + iter-32 lessons to iter-33 acceptance
- [x] Out-of-scope items explicitly listed
- [x] Standing user prefs (orchestrator pintar + handoff solid + flawless) used as guiding principles throughout
- [x] Phase A is the prerequisite for Phase C F3 enforceability (called out explicitly in §1.2 + §4.3 backward-compat + §5.5 risks)
