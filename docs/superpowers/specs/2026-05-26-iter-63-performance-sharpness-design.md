# Iter 63 Performance + Sharpness Design — v4.0.0-Candidate Refactor (Sub-Project 1)

**Status:** Design approved 2026-05-26 (user-confirmed Section 1-6 + revised roadmap + 5 tunes)
**Iter target:** Plugin v3.41.0 → v3.42.0 (MINOR — auto-invoke behavior change with backward-compat)
**Driver:** user shift from feature work to performance/sharpness. "Senior engineer collaborator, not verbose assistant."
**Spec author:** brainstorming session (research-driven; superpowers:brainstorming flow)
**Audit source:** `docs/superpowers/audits/2026-05-26-iter-63-performance-audit.md`

---

## 0. Scope decomposition (3 sub-projects)

This spec covers **Sub-Project 1 (Quick Wins, Iter 63) in detail** + Sub-Project 2 + 3 at roadmap level. Each sub-project gets its own spec → plan → implementation cycle when ready.

| Sub-project | Iters | Plugin range | Status |
|---|---|---|---|
| **SP1 — Quick Wins (this spec)** | Iter 63 | v3.41.0 → v3.42.0 | DETAILED + approved; ship now |
| **SP2 — Architecture Refactor** | Iter 64-70 | v3.42.0 → v3.50.0 | ROADMAP only; each iter brainstormed separately when reached. **~1 week edit work; wall-clock several weeks due to telemetry soak gap (see §4.5).** |
| **SP3 — Foundation Replacement** | Multi-week R&D | v4.0.0 candidate | UNCOMMITTED; explicit fork decision required first |

---

## 1. Research backing (2026 context engineering)

Sources (loaded in brainstorming session, sourced from auto mode WebSearch):

- **LangChain Deep Agents** — 3-tier architecture: hot memory (always loaded) / domain specialists (per task) / cold memory (RAG on-demand)
- **Claude Code tool lazy loading** — 95% context reduction via on-demand tool discovery vs upfront loading
- **Morph / Augment Code 2026** — 40%+ of context budget burned BEFORE agent does real work; 39.9-59.7% of tool-result tokens removable with no perf loss
- **Cline Plan & Act** (v3.78+, April 2026) — Plan mode = cheap non-destructive reasoning; Act mode = expensive execution. **Plan/Act is COMPLEXITY-GATED in Cline, not universal**
- **Context rot research** (Morph, Atlan, Zylos 2026) — Lost-in-middle attention gaps + 30%+ accuracy drop in mid-window + attention dilution as token count grows
- **Token budget thresholds** (industry consensus 2026) — 20K tokens for tool outputs, 85% total context utilization

**Empirical takeaway:** large markdown skill bodies (mega-sdd has 8,174 lines across 15 skills) hit context rot before they hit window limit. Trim is more impactful than expansion.

---

## 2. Audit-measured current state

From [iter-63-performance-audit.md](../audits/2026-05-26-iter-63-performance-audit.md):

| Metric | Value |
|---|---|
| Skill bodies | **8,174 lines** across 15 skills |
| Reference files | **~10,132 lines** across ~50 files |
| Heaviest skills | generate-intent **1,267** / execute-bolts **1,012** / generate-units **826** / orchestrate-flow **764** |
| `generate-intent` reference files | **13** (unmanageable) |
| CHANGELOG | **5,663 lines / 82 versions** |
| Halt taxonomy | **60+ distinct types** |
| TOTAL plugin content | **~18,000 lines** + CHANGELOG |

Plus 7 actionable audit-flagged top wins (TRIM/CONSOLIDATE/DEFER/OVERLAP/HEAVY/AMBIGUOUS categorization).

---

## 3. Sub-Project 1 (Iter 63) — Quick Wins Design

### 3.1 Section 1 — FSD auto-invoke opt-out

**User explicit ask:** FSD generation expensive (pandoc/LaTeX) + low user feedback signal. Flip to opt-in.

**Change:**
- `orchestrate-flow/SKILL.md` Step 6 auto-integrated diagnostics table — `emit-fsd` row flips `default: on` → `default: off`
- `commands/auto.md` adds `--with-fsd` flag (opt-in). Existing `--no-fsd` continues to work as no-op (back-compat)
- `commands/orchestrate-flow.md` same flag pattern
- `commands/emit-fsd.md` standalone command unchanged (user invokes manually for FSD generation)

**Not changed:** emit-fsd skill itself unchanged; can be invoked manually anytime via `/mega-sdd:emit-fsd <vault>`.

**Lines impact:** ~10 edits, 0 new lines. Skill versions: `orchestrate-flow` 3.7.0 → 3.8.0 (MINOR — auto-invoke default change).

### 3.2 Section 2 — Skill body trim (~1,500 line target)

**Strategy:** move-to-references + structural cleanup. NO rewrite (preserves correctness; minimal drift risk).

**Per-skill trim plan:**

| Skill | Current | Target | Strategy |
|---|---|---|---|
| `generate-intent` | 1,267 | ~700 | Move halt-protocol descriptions (already mirrored in `vault-contract.md`); move Iter 35 phase context detail to new `references/phase-context.md`; consolidate 13 reference files where possible |
| `execute-bolts` | 1,012 | ~600 | Move T2 budget tracker procedural detail to `references/t2-budget-tracker.md` (Iter 44 spec content); move saga compensating actions detail to `references/saga-rollback.md` (Iter 45 spec content) |
| `generate-units` | 826 | ~500 | Move adversarial review wiring detail to existing `references/adversarial-test-prompt.md` (consolidate redundant content) |
| `orchestrate-flow` | 764 | ~500 | Move predictive-checks consumer detail to refs (already partial); move handoff validation gate detail to new `references/validation-gate.md` |
| Other heavy skills (>300 lines) | varies | shave 20-30% each | Strip version-stamp prose ("v1.10+, Iter 46:" etc. — git log has this); move worked examples to refs |

**Net effect (tune meta-#3 — math reconciled):**
- Skill bodies (HOT tier, loads every session): 8,174 → ~6,500 lines (**-1,674 line / -20% hot-tier reduction**)
- References (SPECIALIST/COLD tier, loads on-demand): ~10,132 → ~11,132 lines (**+1,000 due to relocation** of content from bodies)
- Pure deletion (version-stamp prose, redundant historical context, mirrored halt descriptions): **~-674 lines net deletion** (small)
- **Plugin total content: ~18,306 → ~17,632 lines (~-3.7% — nearly flat)**

**The win is hot→cold tier RELOCATION, not deletion.** Skill bodies that load every session via anchor drop -20%. Refs grow but load on-demand. Plugin total content nearly flat — claim is NOT line-deletion, it's CONTEXT-WINDOW IMPACT at session start.

**Backward compat:** all existing skills work; refs are loaded by skill body when referenced. Trim is documentation-style; no behavioral change. Iter 66 (SP2) lazy-loading completes the win by making specialist refs truly on-demand.

### 3.3 Section 3 — Command differentiation (keep both, explicit)

**Resolve `/mega-sdd:auto` ↔ `/mega-sdd:orchestrate-flow` ambiguity** without deprecation.

**`/mega-sdd:auto`** — user-facing entry-point. Detects input shape (PRD file / legacy code / brief / vault state) + proposes chain + single confirm. THIS is the marketed "ONE command users need."

**`/mega-sdd:orchestrate-flow`** — power-user lower-level chain executor. Skips input-shape detection (assumes user already knows what to chain). For advanced use (e.g., custom chain composition).

**Doc updates:**
- Both `commands/auto.md` + `commands/orchestrate-flow.md` get cross-reference block at top
- Both clarify scope explicitly in description line
- README documents `/mega-sdd:auto` as primary; `/mega-sdd:orchestrate-flow` as power-user

**No deprecation; no breaking changes; no merge.**

### 3.4 Section 4 — Per-iter ceremony aggressive opt-in (DETERMINISTIC classifier — DUAL EVALUATION POINT)

**User concern (tune meta-#1):** Classifier temporal kebalik in original spec. Ceremony decision is PRE-work (before commit exists); version-bump labeling is POST-work. Same enum, two evaluation points — state explicitly.

**Two evaluation points, same enum output (PATCH | MINOR | MAJOR):**

| Evaluation point | When | Inputs | Use-case |
|---|---|---|---|
| **EP1: Ceremony gating** | BEFORE work starts (pre-commit) | working-tree state + upfront scope estimate | Decides whether to emit spec/plan/audit docs |
| **EP2: Version-bump labeling** | AFTER work done (post-commit) | `git diff HEAD~1 HEAD` of completed commits | Decides PATCH/MINOR/MAJOR version bump in plugin.json + CHANGELOG label |

**EP1 (pre-work) inputs — deterministic estimates:**
- `est_files_changed` = `git diff --stat HEAD | wc -l` (working tree vs HEAD) + plan-doc-declared targets if exists
- `est_halt_enum_diff` = scan in-flight changes to vault-contract.md halt enum (grep working tree diff)
- `est_new_skill_dir` = check working tree for new `plugins/mega-sdd/skills/<new>/` directories
- `breaking_marker` = user's explicit flag `--iter-type=<>` OR scope-statement in brainstorming session
- Fallback when no working-tree changes yet (start-of-work): use user's stated iter-type from brainstorming session intent → default PATCH if absent

**EP2 (post-work) inputs — deterministic completed-diff:**
- `files_changed` = `git diff --name-only HEAD~1 HEAD | wc -l`
- halt-enum diff = `git diff HEAD~1 HEAD -- plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | grep -c "^[+-].*type:.*|"`
- new skill dir = `git diff HEAD~1 HEAD --name-status | grep "^A.*plugins/mega-sdd/skills/.*/SKILL.md"`
- handoff-contract field diff = same pattern on handoff-contract.md
- breaking change marker = `git log -1 --pretty=%B | grep -c "BREAKING CHANGE:"`

**Classifier criteria (same enum, applied at both EPs):**

| Iter type | Criteria (machine-checkable at both EPs) | Required artifacts | Optional |
|---|---|---|---|
| **PATCH** | `files_changed ≤ 5` AND no halt-enum diff AND no new skill dir AND no `BREAKING CHANGE:` marker | CHANGELOG entry only | (nothing) |
| **MINOR** | `files_changed 5-15` OR new halt-enum entry OR new field in handoff-contract OR existing skill body modified | CHANGELOG entry | Spec (only if brainstorming skill invoked) |
| **MAJOR** | new skill dir OR `BREAKING CHANGE:` commit marker OR `files_changed > 15` | CHANGELOG + spec + plan | Audit (only if explicitly requested) |

**Drift handling (EP1 vs EP2 mismatch):**
If EP1 classified PATCH but EP2 reveals MAJOR criteria met (e.g., scope grew during work): emit drift warning + retroactively generate missing artifacts (spec/plan) under accelerated rules (compressed prose; not full ceremony). Log to telemetry as `ceremony_classifier_drift` event for Iter 68 analysis.

**Precedence rule (uniform across plugin, both EPs):**
```
explicit user flag (--iter-type=major) > classifier output > default (PATCH)
```

**No LLM judgment in any path. Output is enum: PATCH | MINOR | MAJOR.**

**Estimated effect:** ~70% of future iters skip spec+plan ceremony (most iters are PATCH-classified per audit's recent-iter analysis).

### 3.5 Section 5 — CHANGELOG archive rotation

**Cutoff:** v3.27.0+ stays in main `CHANGELOG.md` (~28 recent versions). v3.0.0-v3.26.x rotates to `CHANGELOG-ARCHIVE.md` at repo root.

**Main `CHANGELOG.md` header** adds: `For pre-v3.27.0 history, see [CHANGELOG-ARCHIVE.md](CHANGELOG-ARCHIVE.md).`

**Net effect:** main CHANGELOG drops 5,663 → ~1,500 lines (73% reduction). Archive readable but not loaded into context unless user explicitly opens it.

**Future rotation rule (added to plugin CLAUDE.md):** when main CHANGELOG exceeds 2,000 lines OR 30 versions, oldest 50% rotate to archive.

### 3.6 Section 6 — Version + release

- Plugin **v3.41.0 → v3.42.0** MINOR (auto-invoke FSD default change is behavior change; backward-compat preserved via `--with-fsd` flag)
- `orchestrate-flow` **3.7.0 → 3.8.0** MINOR (Step 6 default change)
- Heavy-trim skills get PATCH bumps per change (generate-intent, execute-bolts, generate-units): all retain frontmatter `version: <current+0.0.1>`

---

## 4. Sub-Project 2 Roadmap (Iter 64-70, ~1 week EDIT WORK + soak gap)

**Timeline clarification (tune meta-#2):** ~1 week refers to ACTIVE edit work across Iter 64-70. BUT Iter 68 (telemetry analyze) requires accumulated real-usage data from Iter 64+ — soak gap = wall-clock several weeks of real-world usage between Iter 64 ship and Iter 68 analysis. Iter 64-67 + 69-70 can ship at edit-pace; Iter 68 PAUSES the sequence until soak window completes.

**Realistic wall-clock:** ~1 week edit work + 3-4 weeks soak gap = ~4-5 weeks total elapsed for SP2 completion. SP3 gate at Iter 68 cannot fire faster than soak window allows. If telemetry analysis runs with insufficient data (< 14 days OR < 10 chain runs), it produces "data insufficient" report instead of conclusions — SP3 gate stays closed until enough data accumulated.

Each iter brainstormed separately when reached. This is the COMMITTED sequencing — not detailed design.

### 4.1 Iter 64 — 3-tier context architecture + START telemetry collection

**Tune #1 applied:** telemetry SPLIT into collect-vs-analyze. **Collection starts Iter 64** (cheap append-only `<project>/.mega-sdd/memory/telemetry.jsonl`). Iter 68 = analyze/enforce phase. Rationale: tier assignment (Iter 64), Plan/Act (Iter 67), budget (Iter 69) all need historical data; if instrumentation starts at Iter 68, downstream iters have only days of history. Decouple instrument from analyze.

**Scope:**
- Codify 3-tier model per skill in plugin docs (hot/specialist/cold)
- Mark which references are HOT (always-loaded) vs SPECIALIST (per-task) vs COLD (RAG-on-demand)
- **Start telemetry.jsonl append** with line schema: `{ts, skill, event_type, payload}` — events include: skill_invoked, ref_loaded, halt_fired, tier_classification_decision
- Telemetry opt-out via `--no-telemetry` flag (privacy)
- No analysis logic yet — just collection

### 4.2 Iter 65 — Complexity classifier + anti-recursive guard (2 separate modules, same iter)

**Tune #5 applied:** classifier + guard = different concerns, separate modules, can ship same iter for sequencing convenience.

**Iter 65 CONCRETE DELIVERABLES (tune meta-#4 — what Iter 65 actually builds):**

Iter 63 only documents the classifier criteria + guard rules as CONVENTION in CLAUDE.md (no runtime artifact). Iter 65 builds the executable mechanism:

1. **`plugins/mega-sdd/scripts/classify-iter.sh`** — executable bash script wrapping the git/grep commands; output is JSON `{iter_type: "PATCH|MINOR|MAJOR", criteria_matched: [...], evaluation_point: "EP1|EP2"}` for both pre-work and post-work invocation
2. **`plugins/mega-sdd/scripts/check-recursion-budget.sh`** — bash script that reads `<project>/.mega-sdd/.replan-budget` ephemeral state file; tracks active task's re-plan count + re-validate count; exits non-zero if cap exceeded (orchestrator translates to halt)
3. **Orchestrate-flow integration** — orchestrate-flow Step 3 invokes `classify-iter.sh` at chain start (EP1); Step 7 (final summary) invokes again at chain end (EP2); telemetry event logged on drift
4. **Skill body invocation pattern** — skills that gate behavior on complexity (Iter 67 Plan/Act gating, Iter 69 budget enforcement) invoke `classify-iter.sh` at procedure start (caching result in handoff metadata for single-classifier-per-chain discipline)

**Without these concrete artifacts, Iter 65 would be a no-op** (the convention from Iter 63 would just sit in CLAUDE.md without runtime enforcement). Iter 65 ships the enforcement layer.

**Module A: Deterministic complexity classifier**

Specified in Section 4 above. Single source of truth for PATCH/MINOR/MAJOR enum. Used by:
- Iter 63 Section 4 iter-ceremony rule (which artifacts to emit)
- Iter 67 Plan/Act gating (when to plan vs direct act)
- Iter 69 budget enforcement (per-tier context thresholds)

**Module B: Anti-recursive guard (formal spec)**

Codified as plugin-wide rule (added to `plugins/mega-sdd/CLAUDE.md`):

```
RULE 1 — Re-plan triggers (CLOSED ENUM, no judgment):
  - execution_failed (commit failed / test failed / halt fired)
  - ambiguity_increased (new contract mismatch detected POST-plan)
  - contract_mismatch (handoff field TYPE drift caught at validation gate — STRICTLY this only)

RULE 1.5 — Tune #4 explicit exclusion (per user clarification):
  - bind-codebase CONFLICT is NOT a re-plan trigger. CONFLICT hard-gate is human-halt
    (user resolves via resolve-oq OR vault edit). Guard MUST NOT loop binding gate
    into re-plan cycles. Scope of contract_mismatch is HANDOFF FIELD TYPE DRIFT ONLY.

RULE 2 — Hard caps per task (CONFIGURABLE DEFAULTS, tune post-Iter 68):
  - max_replan_count: 2 (DEFAULT — only magic number without empirical evidence;
    Tune #2 explicitly flagged for revisit post-Iter 68 telemetry analysis)
  - max_revalidate_count: 3 (DEFAULT — same caveat)
  - Exceeded → halt (NAMING DEFERRED to Iter 65 implementation, per tune meta-#5):
    Iter 65 evaluates reuse-first options BEFORE creating new halt enum entry:
    (a) Reuse `bolt_repeated_partial_failure` semantic (existing N-retry-exhausted halt;
        generalize from execute-bolts-only to "any task hitting hard retry cap")
    (b) Add subtype to `quality_gate_failed` (subtype: `replan_budget_exceeded` |
        `revalidate_budget_exceeded` — pattern from Iter 53/54 subtype discriminator)
    (c) LAST RESORT only: new halt enum entry `replan_budget_exceeded`
    Iter 65 ships the decision + impl. Iter 63 spec defers naming to avoid
    pre-committing to halt enum growth (Fork-A debt concern §5.2).

RULE 3 — No validating-the-validation:
  - If validation step itself fails, halt directly — DO NOT spawn meta-validation
  - Validators are LEAF NODES in execution graph, not internal nodes
  - "Plan to validate the validation plan" is recursion → prohibited
```

### 4.3 Iter 66 — Lazy reference loading (Claude Code 95% pattern)

Skills declare per-reference loading discipline:
- `HOT` — always loaded when skill body loads (e.g., `vault-contract.md` halt enum is always needed)
- `SPECIALIST` — loaded only when specific procedure step requires it (e.g., `t2-budget-tracker.md` loaded only when execute-bolts hits Step 4.5.a.5)
- `COLD` — loaded only via explicit grep/RAG when user request matches (e.g., individual scenario walkthroughs)

Telemetry from Iter 64 used to validate which refs are actually hot vs cold (post-Iter 68 analysis tunes the discipline).

### 4.4 Iter 67 — Plan/Act mode per skill — COMPLEXITY-GATED via Iter 65 classifier

**Tune #3 applied: Plan/Act is NOT universal default.**

Plan-mode is cheap reasoning (Cline pattern); Act-mode is expensive execution. Gating per Iter 65 classifier:

| Iter complexity | Plan/Act behavior |
|---|---|
| PATCH | Direct act (no plan phase) — economics dictate |
| MINOR | Optional plan (user opt-in via `--plan` flag) |
| MAJOR | Plan → Act mandatory; explicit transition required |

Universal-plan rejected — violates economics goal (cheap → cheap; expensive → planned).

### 4.5 Iter 68 — Telemetry ANALYZE phase + SP3 gate

**Tune #1 applied:** Iter 64 = collect; Iter 68 = analyze. Iter 68 reads accumulated telemetry.jsonl (likely 30-60 days of data by this point) and produces:

- Skill hit frequency report (which skills invoked most/least)
- Token-per-skill aggregate (which skills heaviest in practice)
- Activation accuracy (false-positive skill invocations)
- Tier-classification decision log analysis (validate hot/specialist/cold predictions vs actual loads)

**Output:** `docs/superpowers/telemetry/iter-68-analysis.md` — data-driven baseline for tuning Iter 69/70 + gate decision for SP3.

**"Prove gains" gate for SP3:** must point to specific metrics from this analysis. No SP3 work without empirical evidence.

### 4.6 Iter 69 — Token budget enforcement (data-driven thresholds)

Uses Iter 68 telemetry to tune per-tier context thresholds:
- Hot tier budget (default 20K tokens per research industry consensus)
- Specialist tier per-skill budget (data-driven from token-per-skill report)
- Cold tier on-demand (no upfront budget)

Extend `execute-bolts` T2 budget tracker pattern to ALL skills. Total context budget enforced at 85% of model window (industry standard).

### 4.7 Iter 70 — Skill consolidation evaluation (data-driven)

Read telemetry from Iter 68. Consolidate only skills with empirically low hit-frequency or high overlap. Candidates flagged by audit (NOT acted on without data):
- `diff-vault` + `detect-drift` + `resolve-oq --binding` (same "compare 2 ground truths" algorithm)
- `extract-intelligence` + `scan-codebase` (both wave-dispatched walkers)

**Tune #2 applied:** also revisit Iter 65 magic numbers (max_replan=2, max_revalidate=3) using re-plan distribution data.

---

## 5. Sub-Project 3 R&D — UNCOMMITTED + Explicit Fork Decision Required

**Tune #3 applied:** Plan/Act-as-universal-default REJECTED. Deepen complexity-gated pattern instead.

### 5.1 Strategic fork (MUST be resolved before SP3 work starts)

**Tune #5 applied with #3:** explicit decision inputs + acknowledgment of Fork A debt.

| Fork | Identity | Implication |
|---|---|---|
| **A. Correctness layer** | Mega-SDD sits ON TOP OF Claude Code / VSCode / Cline / other runtimes. Provides anti-halu rails + memory + handoff contracts. Runtime is someone else's problem. | Lighter touch. SP1 + SP2 sharpening makes this fork strong. v4.0.0 = VSCode extension that LAYERS over Copilot/Cline. |
| **B. Runtime itself** | Mega-SDD replaces the agent runtime. Owns LLM dispatch loop + tool execution + permission model + UI. | Heavier. Cline-pattern. v4.0.0 = standalone extension that ships its own runtime (Anthropic SDK / multi-provider). Much larger scope. |

**Decision inputs (machine-evaluable when SP3 reached):**

1. **SP2 telemetry results** (Iter 68 analysis): does mega-sdd's anti-halu value-add justify lighter-touch layer, or do runtime concerns dominate?
2. **User base composition**: do users primarily use Claude Code (Fork A natural fit) or are they multi-IDE / runtime-agnostic (Fork B better)?
3. **Host runtime availability**: do Claude Code + Cline + Cursor + VSCode Agent plugins cover enough use-cases that Fork A scales? If host runtimes have gaps in skill execution / memory / anti-halu, Fork B becomes necessary.

**Decision rule:** Fork chosen when SP3 starts, based on input data above. NOT chosen by drift.

### 5.2 Fork A debt acknowledgment (per tune #3)

**"SP2 keeps us in Fork A" applies to NEW WORK ONLY — not existing B-ward debt.**

Mega-SDD has been drifting toward Fork B since v2.0:
- Own halt taxonomy (60+ types) — Fork A may not need full taxonomy if host runtime provides error semantics
- Own execution model (skill bodies as agent instructions) — Fork A may simplify to typed manifests
- Own memory layer (3 scopes × 4-7 files) — Fork A may delegate to host runtime memory

**If Fork A chosen at SP3:** acknowledge existing B-ward artifacts may need unwind/deprecate work. SP3 spec MUST include explicit debt list + migration path.

**If Fork B chosen at SP3:** existing artifacts amortize over MAJOR breaking version. SP3 = own runtime build-out.

### 5.3 SP3 candidate scope items (revisited at SP3 brainstorm time)

Not committed; for reference:

- Semantic skill graph (activation-rule-driven loading)
- Structured context (typed manifest) vs markdown prose for hot tier
- Deepen complexity-gated Plan/Act (NOT universal — per tune #3)
- Always-on context budget enforcement at 85% with auto-compression
- IF Fork B: own runtime (Cline pattern)
- IF Fork A: deeper integration with host runtimes (Claude Code plugin API + VSCode Agent plugin API)

---

## 6. Unified complexity axis (single source of truth)

Iter 65 deterministic classifier drives THREE downstream consumers — NO parallel config surfaces:

```
                       ┌─────────────────────────────────────┐
                       │  Iter 65 deterministic classifier   │
                       │  (input: git/fs counts;             │
                       │   output: PATCH | MINOR | MAJOR)    │
                       └────┬────────────┬───────────────┬───┘
                            │            │               │
                ┌───────────▼───┐  ┌─────▼──────┐  ┌─────▼─────────┐
                │ Section 4     │  │ Iter 67    │  │ Iter 69       │
                │ iter-ceremony │  │ Plan/Act   │  │ budget        │
                │ rule (this    │  │ gating     │  │ enforcement   │
                │ iter)         │  │            │  │               │
                └───────────────┘  └────────────┘  └───────────────┘

Precedence (uniform across plugin):
  explicit user flag > classifier output > default (PATCH)
```

---

## 7. Anti-recursive guard formal spec (folded with binding CONFLICT exclusion per tune #4)

Codified Iter 65 in plugin CLAUDE.md (preview here for spec completeness):

```
RULE 1 — Re-plan triggers (closed enum, no LLM judgment):
  execution_failed | ambiguity_increased | contract_mismatch

RULE 1.5 — Explicit exclusion (tune #4):
  bind-codebase CONFLICT is NOT a re-plan trigger.
  CONFLICT hard-gate stays human-halt (user resolves via resolve-oq OR vault edit).
  Guard MUST NOT loop binding gate into re-plan cycles.
  contract_mismatch is SCOPED STRICTLY to handoff field TYPE drift caught at Iter 33 F4
  validation gate — NOT broader semantic disagreement.

RULE 2 — Hard caps per task (configurable defaults — tune #2):
  max_replan_count: 2 (DEFAULT — revisit post-Iter 68 telemetry analysis)
  max_revalidate_count: 3 (DEFAULT — same caveat)
  Exceeded → halt (NAMING DEFERRED to Iter 65 — reuse-first evaluation:
    bolt_repeated_partial_failure generalization OR quality_gate_failed
    subtype OR new enum entry as LAST RESORT. Per tune meta-#5.)

RULE 3 — No validating-the-validation:
  Validators are LEAF NODES; do not spawn meta-validators.
  Validation failure → halt directly. Never "validate the validation."
```

---

## 8. Iter 63 (SP1) Implementation scope

**Atomic deliverables:**

1. **Section 1 (FSD opt-out):** edit `orchestrate-flow/SKILL.md` Step 6 + `commands/auto.md` + `commands/orchestrate-flow.md`
2. **Section 2 (skill trim):** move-to-references + structural cleanup for generate-intent, execute-bolts, generate-units, orchestrate-flow, + 5 medium-trim skills
3. **Section 3 (command differentiation):** edit `commands/auto.md` + `commands/orchestrate-flow.md` cross-links
4. **Section 4 (ceremony classifier):** add classifier criteria + precedence rule to `plugins/mega-sdd/CLAUDE.md`
5. **Section 5 (CHANGELOG rotation):** create `CHANGELOG-ARCHIVE.md` at repo root with v3.0-v3.26.x entries; trim main `CHANGELOG.md` to v3.27.0+; add archive cross-ref in main header; document future rotation rule in `plugins/mega-sdd/CLAUDE.md`
6. **Section 6 (release):** plugin.json v3.41.0 → v3.42.0; orchestrate-flow 3.7.0 → 3.8.0; heavy-trim skills PATCH bumps; READMEs version refs; CHANGELOG entry

**Plus:**

7. Update `plugins/mega-sdd/README.md` + root `README.md` audit table (Iter 63 + roadmap reference)
8. Spec doc itself (this file) committed
9. Plan doc generated by writing-plans (per current process — last iter under OLD ceremony rules; PATCH iters under new rules skip plan doc)

**Total files touched:** ~25 (5 modifications per heavy skill trim + 7 surface touches + version refs + READMEs).

**No new skills. No new halt types. No new schemas. Backward-compatible behavior change (FSD flag).**

---

## 9. Success criteria

- [ ] `/mega-sdd:auto` runs WITHOUT FSD emission by default; `--with-fsd` opts in
- [ ] Skill body line count: 8,174 → ~6,500 (-20% hot context)
- [ ] CHANGELOG.md line count: 5,663 → ~1,500 (73% reduction; archive readable)
- [ ] `plugins/mega-sdd/CLAUDE.md` has deterministic classifier criteria + precedence rule + anti-recursive guard preview (Iter 65 full impl)
- [ ] `/mega-sdd:auto` + `/mega-sdd:orchestrate-flow` docs both have cross-reference blocks + scope clarification
- [ ] No new halts; no new skills; no new schemas
- [ ] Plugin v3.41.0 → v3.42.0 ships clean

---

## 10. Out of scope (explicit deferrals for SP1)

- 3-tier context architecture (SP2 Iter 64)
- Telemetry collection start (SP2 Iter 64)
- Complexity classifier impl (SP2 Iter 65 — Section 4 here is RULE doc only)
- Anti-recursive guard runtime enforcement (SP2 Iter 65 — Section 7 here is RULE doc only)
- Lazy reference loading (SP2 Iter 66)
- Plan/Act mode per skill (SP2 Iter 67)
- Token budget enforcement (SP2 Iter 69)
- Skill consolidation (SP2 Iter 70)
- Fork A vs Fork B decision (SP3 prerequisite)
- v4.0.0 work (SP3)

---

## 11. Risks + mitigations

| Risk | Mitigation |
|---|---|
| Skill body trim introduces drift between body and references | Move-to-references preserves content (cut-paste, not rewrite); refs are loaded by body so no semantic gap |
| CHANGELOG archive rotation breaks user bookmarks/links | Main CHANGELOG.md header has prominent cross-ref to archive; archive at repo root (discoverable) |
| Classifier deterministic criteria too rigid (misclassifies real-world iters) | Precedence rule allows explicit `--iter-type=major` override; defaults are conservative (PATCH default for ambiguous case) |
| FSD opt-out surprises users who relied on auto-emit | `--no-fsd` still works as no-op (back-compat); CHANGELOG entry highlights new default; existing users see one extra opt-in step |
| Anti-recursive guard cap values (2 re-plan / 3 re-validate) too tight or too loose | Tune #2 explicitly: defaults are placeholders; Iter 68 telemetry analysis informs revision |

---

## 12. Process notes (this spec under new ceremony rules)

Iter 63 itself = MINOR (classifier: existing skill body modified + new content in CLAUDE.md). Under NEW ceremony rules: CHANGELOG entry + spec (this doc, since brainstorming invoked) but optionally plan doc.

**Decision:** writing-plans skill invoked (current process applies; new rules ship WITH this iter). Future iters under MINOR with NO brainstorm skip both spec + plan.

**Last iter to follow old ceremony fully.** Iter 64+ subject to new classifier.

---

**Approval:** user approved Section 1-6 unchanged + revised roadmap + 5 tunes (telemetry split, configurable defaults, fork inputs explicit + Fork A debt, binding CONFLICT exclusion, classifier/guard separation) on 2026-05-26.

**Post-spec meta-tunes (applied in 2nd-pass user review of written spec):**
- meta-#1: Classifier temporal split (EP1 pre-work vs EP2 post-work) — §3.4
- meta-#2: SP2 timeline clarified (edit work + soak gap = ~4-5 weeks wall-clock) — §0 + §4
- meta-#3: Trim math reconciled (hot-tier relocation -1,674 lines vs net deletion only ~-674 small) — §3.2
- meta-#4: Iter 65 concrete deliverables specified (4 artifacts: classify-iter.sh, check-recursion-budget.sh, orchestrate-flow integration, skill invocation pattern) — §4.2
- meta-#5: `replan_budget_exceeded` halt naming deferred — Iter 65 reuse-first evaluation (bolt_repeated_partial_failure generalize / quality_gate_failed subtype / new enum LAST RESORT) — §4.2 + §7
- cosmetic: "4 tunes" → "5 tunes" consistent throughout

**Next:** writing-plans skill to produce atomic implementation plan for Iter 63 (SP1) scope.
