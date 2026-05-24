# Iter 34 — Dynamic Model Selection per Subagent Dispatch

**Status:** Design approved 2026-05-24 (autonomous-execute mode)
**Plugin target:** v3.24.0 → v3.25.0 (orchestrate-flow 3.0.0 → 3.1.0)
**Iter type:** Feature iter (~8hr)
**Predecessor context:**
- Iter 33 v3.24.0 flawless seamless intelligence (orchestrator + handoffs)
- User directive: "model pilihan dynamik. misal perlu yg complpex pake opus, klo yg ringaan web and research.. and find the best"

---

## Background and motivation

Across the mega-sdd plugin, ~15-18 named subagent roles dispatch via the Agent tool. Currently:
- Only `scan-codebase` deep-scan subagents specify model explicitly (4 hardcoded `sonnet`)
- All other dispatches inherit the caller's model (effectively always Opus when invoked from main Claude Code thread)
- No central catalog; no override mechanism; no rationale documented

User's goal: pick the BEST model per task. Heavy reasoning (synthesis, deep code review, architectural decisions) → opus. Lightweight (web fetch, bounded research, catalog lookup, single-document scoring) → cheaper models. Catalog + override + rubric.

This iter introduces a curated **model-tiers catalog** that maps every named subagent role to a recommended tier (haiku/sonnet/opus) with explicit rationale. Skills cite the catalog instead of hardcoding. Users override via CLI flag, per-project config, or user-scope preferences. The orchestrator propagates the resolved tier through handoff metadata.

Not a learning system — purely static + curated + user-overridable. Future iter (35+) can add adaptive learning on top.

---

## §1 Architecture overview

### 1.1 Three-tier model taxonomy

mega-sdd standardizes on three Anthropic model tiers:

| Tier | Model family | When to use |
|---|---|---|
| **haiku** | claude-haiku-4-5 (or current) | Bounded scope; single-document analysis; mechanical scoring; light web/research; pattern matching against known catalog; tasks where speed + cost dominate quality |
| **sonnet** | claude-sonnet-4-6 (or current) | Pattern recognition + reasoning across multiple inputs; fuzzy classification (e.g., "is this Sanctum or Breeze?"); structured synthesis with clear schema; most balanced choice |
| **opus** | claude-opus-4-7 (or current) | Open-ended reasoning; holistic synthesis across many sources; architectural decisions; deep code review; cross-cutting pattern detection; cases where quality dominates cost |

### 1.2 Override chain (highest precedence first)

1. **CLI flag** (per-run, rare): `--model-tier=<role>:<tier>` (multiple allowed)
2. **Per-project config**: `<project>/.mega-sdd/config.yaml` `model_tiers: {<role>: <tier>}`
3. **User-scope preference**: `~/.mega-sdd/memory/preferences.md` `## Model tiers` section
4. **Catalog default**: `plugins/mega-sdd/references/model-tiers.md` §<role>

The chain resolves at orchestrate-flow Step 2.8 (NEW). Resolved tiers propagate to all sub-skills via handoff metadata `model_tiers:` block. Each sub-skill consults this block before dispatching its own subagents.

### 1.3 Catalog structure

`plugins/mega-sdd/references/model-tiers.md` includes:
- **§Tier selection rubric** — criteria for picking haiku/sonnet/opus (user-facing decision guide)
- **§Catalog (15-18 entries)** — table mapping role → tier + rationale
- **§Override syntax** — examples of CLI flag, config.yaml, preferences.md
- **§Adding new roles** — protocol for future iters that introduce new subagent roles

### 1.4 Files

**New (1):**
- `plugins/mega-sdd/references/model-tiers.md` (~200 LOC catalog + rubric + override syntax)

**Modified:**
- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` — add Step 2.8 override-chain resolution; bump 3.0.0 → 3.1.0
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` — add `model_tiers:` top-level block schema (REQUIRED/CONDITIONAL/OPTIONAL + TYPE annotations from Iter 33)
- `plugins/mega-sdd/skills/scan-codebase/SKILL.md` — replace hardcoded `model: sonnet` with catalog citation; bump 2.6.0 → 2.6.1
- `plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md` — same replacement
- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — wave dispatch citations; bump 1.4.1 → 1.5.0
- `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` — same citations
- `plugins/mega-sdd/skills/memory/SKILL.md` — preferences.md model_tiers entry doc; bump 1.3.0 → 1.3.1
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` — user-scope preferences.md schema extension
- `plugins/mega-sdd/references/paths.md` — note config.yaml model_tiers location

**Plugin:** v3.24.0 → v3.25.0

---

## §2 The catalog (model-tiers.md content)

### 2.1 Tier selection rubric (top of catalog)

```markdown
## Tier selection rubric

Pick the LEAST powerful model that can handle the task. Each tier has clear criteria:

### haiku — pick when ALL of these hold
- Task is bounded scope (≤2 files read, ≤1KB output)
- Decision space is narrow (enum-like classification; ≤5 distinct outputs possible)
- No multi-document synthesis required
- No architectural reasoning required
- Speed/cost dominates quality requirement

Examples: per-skill intelligence probe scoring (0-3 scale); manifest-only lib detection; catalog lookup.

### sonnet — pick when ANY of these hold (default)
- Pattern recognition across multiple documents
- Fuzzy classification (e.g., "is this Sanctum or Breeze?" — multiple signals to weigh)
- Structured synthesis with known output schema
- Bounded reasoning depth (≤5 reasoning steps)
- Mid-range cost/quality tradeoff

Examples: deep-scan extractors (auth/rbac/ui-ux/libs); pipeline-audit per-skill; spec-reviewer; implementer for typical tasks.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

Examples: extract-intelligence wave-5 synthesis; intelligence-audit deep dimension analysis; code-quality-reviewer; pipeline-audit consolidator.

### Default when in doubt: sonnet

Sonnet is the safe middle ground. Escalate to opus only with concrete evidence the task needs broader reasoning. Drop to haiku only when scope is provably bounded.
```

### 2.2 Catalog entries (~17 roles)

```markdown
## Catalog

| # | Role | Tier | Rationale |
|---|---|---|---|
| 1 | `auth-extractor` (scan-codebase Iter 32) | sonnet | Fuzzy detection across 5 auth libs + version + features; multi-file evidence |
| 2 | `rbac-extractor` (scan-codebase Iter 32) | sonnet | Same pattern; 3 RBAC libs + middleware + policies |
| 3 | `ui-ux-extractor` (scan-codebase Iter 32) | sonnet | Multi-domain (JS+CSS+notification+icon+datatable+idioms); empirically-grounded idiom inference needs reasoning |
| 4 | `libs-extractor` (scan-codebase Iter 32) | sonnet | Manifest parsing + category mapping + usage-hint grep across many libs |
| 5 | `extract-intelligence wave-1` (artifact extraction) | sonnet | Wave parallelism; bounded artifact-set per agent |
| 6 | `extract-intelligence wave-2` (domain extraction) | sonnet | Domain pattern recognition; multi-source synthesis |
| 7 | `extract-intelligence wave-3` (cross-reference) | sonnet | XRef resolution across domain docs |
| 8 | `extract-intelligence wave-4` (mutability classification) | sonnet | LOCKED/INTENT/ARTIFACT tier scoring with criteria |
| 9 | `extract-intelligence wave-5` (synthesis) | **opus** | Holistic synthesis across all prior waves; main-thread; needs broadest context |
| 10 | `pipeline-audit-per-skill` (Iter 31 style) | sonnet | Forensic audit across 10 dimensions per skill; bounded scope per skill |
| 11 | `pipeline-audit-consolidator` (Iter 31 style) | **opus** | Cross-skill pattern detection; consolidates 13 YAML inputs; needs broad reasoning |
| 12 | `intelligence-audit-deep` (Iter 33 Phase B) | sonnet | 6-dimension audit on orchestrate-flow + handoff-contract; bounded |
| 13 | `intelligence-audit-probe` (Iter 33 Phase B) | **haiku** | Per-skill 0-3 scoring + 1-sentence justification; narrow decision space |
| 14 | `implementer` (subagent-driven-development) | sonnet | Typical implementation task; if task complexity escalates → user can override to opus |
| 15 | `spec-reviewer` (subagent-driven-development) | sonnet | Compliance verification against spec |
| 16 | `code-quality-reviewer` (subagent-driven-development) | **opus** | Deep code review; cross-cutting concerns; security/performance |
| 17 | `domain-research` (web fetch / external research) | **haiku** | Web fetches + structured extraction; low reasoning depth |

Total: 17 roles. 3 opus + 11 sonnet + 3 haiku.
```

### 2.3 Override syntax section

```markdown
## Override syntax

### CLI flag (per-run override)

```bash
/mega-sdd:auto --model-tier=code-quality-reviewer:sonnet ./prd.md
# multiple overrides allowed:
/mega-sdd:auto --model-tier=audit-consolidator:opus --model-tier=audit-probe:sonnet
```

### Per-project config

`<project>/.mega-sdd/config.yaml`:
```yaml
model_tiers:
  code-quality-reviewer: sonnet  # team prefers cheaper reviews on this project
  intelligence-audit-probe: sonnet  # bump from haiku to sonnet for higher signal
```

### User-scope preference

`~/.mega-sdd/memory/preferences.md`:
```markdown
## Model tiers

- `code-quality-reviewer`: sonnet  # personal preference (overrides catalog default opus)
- `extract-intelligence wave-5`: sonnet  # cost-sensitive default
```

### Override chain precedence

CLI flag > per-project config > user-scope preference > catalog default.

Highest applicable override wins. If no override applies, catalog default is used.
```

### 2.4 Adding new roles section

```markdown
## Adding new roles

When a future iter introduces a new subagent dispatch:

1. Pick a tier using §Tier selection rubric
2. Add a catalog entry to §Catalog with:
   - Role name (unique kebab-case)
   - Tier (haiku|sonnet|opus)
   - Rationale (1-sentence why this tier, not the others)
3. Update the skill's SKILL.md subagent dispatch instruction to cite the catalog:
   "Model: per `references/model-tiers.md §<role-name>`"
4. If the role is a candidate for user override, document the override path in the role rationale.

DO NOT hardcode model: tier in SKILL.md; always cite the catalog. This keeps tier choices auditable + centrally tunable.
```

---

## §3 orchestrate-flow Step 2.8 override-chain resolution

### 3.1 Step 2.8 procedure

```markdown
## Step 2.8 — Resolve model-tier override chain (v3.1.0+, Iter 34)

Per `references/model-tiers.md` override syntax.

a. Read CLI flags from invocation: collect all `--model-tier=<role>:<tier>` flags into a dict `cli_overrides`.

b. Read `<project>/.mega-sdd/config.yaml`: parse `model_tiers:` section if present; build `project_overrides` dict.

c. Read `~/.mega-sdd/memory/preferences.md` `## Model tiers` section: build `user_overrides` dict.

d. Compute final resolved tier per role (override chain precedence):
   - For each role mentioned in any override source:
     - If in cli_overrides → use cli value
     - Else if in project_overrides → use project value
     - Else if in user_overrides → use user value
     - Else → use catalog default (read from references/model-tiers.md §<role>)

e. Emit final `model_tiers:` dict in handoff metadata for all downstream skills:
```yaml
metadata:
  model_tiers:
    auth-extractor: sonnet
    rbac-extractor: sonnet
    code-quality-reviewer: sonnet  # override applied — was opus in catalog
    # ... (all 17 roles)
  model_tier_sources:  # provenance trail for debugging
    auth-extractor: catalog
    code-quality-reviewer: project-config
```

f. If any role mentioned in override sources doesn't exist in catalog → log warning ("unknown model tier role: <name>; ignored") but don't halt. (Forward-compat: future iters may add roles user is preparing for.)
```

### 3.2 Handoff schema extension

In `handoff-contract.md`, add new top-level field:

```markdown
### `model_tiers:` (CONDITIONAL — if v3.1.0+ orchestrate-flow resolved overrides)

TYPE: object {
  <role-name>: enum (haiku | sonnet | opus)
}

Resolved model tier per named subagent role. Sub-skills consult this block before each subagent dispatch; absent role-name → use catalog default per references/model-tiers.md.

Companion field: `model_tier_sources:` (OPTIONAL) — same keys; values are the override source for each tier (catalog | user | project | cli) for debugging.
```

### 3.3 Sub-skill consumption pattern

Each subagent dispatch in a SKILL.md now reads like:

```markdown
Dispatch <role-name> subagent.
Model: per references/model-tiers.md §<role-name> default (or handoff metadata.model_tiers.<role-name> if override applied).
```

The dispatching LLM (Claude) reads the catalog + override + uses the resolved tier in its Agent tool call.

---

## §4 Halt protocol + testing

### 4.1 New halts (1)

| Halt type | Severity | Emitted by | Recovery |
|---|---|---|---|
| `model_tier_unknown` | SOFT | orchestrate-flow Step 2.8 | Log warning; ignore override; use catalog default. Chain proceeds. |

Registered across 4 surfaces (vault-contract type enum + orchestrate-flow SOFT halts subsection) per audit-pattern-prevention checklist.

### 4.2 Trigger tests (3 new cases)

**`tests/skill-triggering/orchestrate-flow.test.md`** — add 3 cases under `## Iter 34 — Model tier resolution (v3.1.0+)`:

- **OF-MT1**: catalog defaults applied when no overrides exist. Verify handoff metadata.model_tiers populated from catalog.
- **OF-MT2**: CLI flag override takes precedence over project + user. Verify metadata.model_tier_sources marks "cli" for overridden role.
- **OF-MT3**: Unknown role in override → soft halt `model_tier_unknown` + log + chain continues.

### 4.3 Anti-halu rails

1. **Catalog discipline**: every subagent dispatch in SKILL.md MUST cite the catalog. No hardcoded `model: <tier>` in skill bodies (except in catalog example YAML blocks).
2. **Unknown role tolerance**: orchestrator MUST log + ignore unknown-role overrides; never halt chain. Forward-compat.
3. **Rationale required**: every catalog entry MUST include a 1-sentence rationale. Future iters that add roles without rationale fail catalog review.

### 4.4 Audit-pattern prevention

| Pattern | Iter 34 prevention |
|---|---|
| Halt in skill but absent from taxonomy | `model_tier_unknown` registered across 4 surfaces |
| Producer-only ship | catalog produced + orchestrate-flow consumes + all 4 dispatch categories cite — ships together |
| Hardcoded values in skill bodies | catalog is the single source of truth; no hardcoded tiers |

---

## §5 Risks + mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Catalog goes stale as new roles added in future iters | High over time | Catalog `## Adding new roles` protocol; plan acceptance criterion for future iters requires catalog update |
| User overrides break a workflow (e.g., haiku for synthesis) | Medium | Rubric guides user toward sensible choices; orchestrator logs final tier choice so user can audit "why did it use haiku for X" |
| LLM dispatching subagents misreads catalog (uses wrong tier) | Low | Catalog format is explicit table; each SKILL.md dispatch cites specific section; rubric clarifies criteria |
| Cost goes UP (catalog defaults to opus too often) | Low | Catalog has 3 opus / 11 sonnet / 3 haiku — sonnet-dominant by design |
| Cost goes DOWN but quality suffers | Medium | Override mechanism + user-scope memory preference lets cost-sensitive users dial down; quality-sensitive can dial up |

---

## Acceptance criteria

1. Plugin v3.24.0 → v3.25.0
2. orchestrate-flow v3.0.0 → v3.1.0 (Step 2.8 added)
3. `references/model-tiers.md` created with rubric + 17 catalog entries + override syntax + adding-new-roles protocol
4. Override chain (CLI > project > user > catalog) resolved at Step 2.8
5. handoff-contract.md extended with `model_tiers:` block (REQUIRED/CONDITIONAL/OPTIONAL + TYPE per Iter 33)
6. 4 dispatch categories cite catalog (scan-codebase deep-scan; extract-intelligence waves; audit dispatches in references; SDD pattern documented)
7. `model_tier_unknown` SOFT halt registered across 4 surfaces
8. 3 new trigger tests (OF-MT1/2/3) shipped
9. Zero hardcoded `model: <tier>` outside catalog example YAML
10. Standing user prefs: catalog rationale explicit (each entry); rubric criteria provide "find the best" guidance

---

## Out of scope (Iter 35+)

- Adaptive learning (memory tracks subagent outcomes per tier; auto-escalate on failures) — Iter 35 candidate
- Cost-aware pre-flight estimates ("this chain will use ~X tokens") — Iter 35+ candidate
- Cost tracking in routing-outcomes.md — Iter 35+ candidate
- Per-task-context tier resolution (e.g., simple feature vs complex refactor warrants different reviewer tier) — Iter 36+ candidate
- Model availability fallback (if opus unavailable → fallback chain) — assumed handled by Claude Code platform; not plugin scope

---

## Spec self-review checklist

- [x] No TBD/TODO/vague markers
- [x] Catalog has 17 entries (consistent across §1.4 + §2.2 + acceptance #6)
- [x] Override chain order consistent across §1.2 + §3.1 + §2.3
- [x] 1 new halt (model_tier_unknown) consistent across §4.1 + §4.2 + acceptance #7
- [x] Skill version bumps consistent: orchestrate-flow 3.1.0 + scan-codebase 2.6.1 + extract-intelligence 1.5.0 + memory 1.3.1
- [x] Tier rubric (haiku/sonnet/opus criteria) provides actionable "find the best" guidance per user directive
- [x] Standing directives applied: reuse-first (no new lock/cache mechanism; reuses Iter 33 handoff metadata pattern); propagation-within-iter (catalog + override + all 4 dispatch sites ship together); audit-pattern-prevention (new halt across 4 surfaces)
- [x] Backward-compat: absent overrides → catalog default; absent catalog citation → inherit caller (current behavior). Existing pipelines unaffected.
