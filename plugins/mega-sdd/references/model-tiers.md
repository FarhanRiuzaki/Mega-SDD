# Model Tiers Catalog

> Single source of truth for which model tier each named subagent role uses across the mega-sdd plugin.

**Version:** 1.0
**Introduced:** v3.25.0 (Iter 34)
**Consumed by:** all SKILL.md subagent dispatch sites (cite via `references/model-tiers.md §<role-name>`)
**Resolved by:** `mega-sdd:orchestrate-flow` v3.1.0+ Step 2.8 (override chain: CLI > project config > user preference > catalog default — non-panel roles only; `*-reviewer` lenses are frontmatter-pinned, see §Override syntax)

---

## Contents

- Tier selection rubric
- Catalog
- Override syntax
- Adding new roles
- See also

## Tier selection rubric

Pick the LEAST powerful model that can handle the task. Each tier has clear criteria:

### haiku — pick when ALL of these hold
- Task is bounded scope (≤2 files read, ≤1KB output)
- Decision space is narrow (enum-like classification; ≤5 distinct outputs possible)
- No multi-document synthesis required
- No architectural reasoning required
- Speed/cost dominates quality requirement

**Examples:** per-skill intelligence probe scoring (0-3 scale); manifest-only lib detection; catalog lookup.

### sonnet — pick when ANY of these hold (default)
- Pattern recognition across multiple documents
- Fuzzy classification (e.g., "is this Sanctum or Breeze?" — multiple signals to weigh)
- Structured synthesis with known output schema
- Bounded reasoning depth (≤5 reasoning steps)
- Mid-range cost/quality tradeoff

**Examples:** deep-scan extractors (auth/authz/ui-ux/libs/reuse); pipeline-audit per-skill; spec-reviewer; implementer for typical tasks.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

**Examples:** extract-intelligence wave-5 synthesis; intelligence-audit deep dimension analysis; code-quality-reviewer; pipeline-audit consolidator.

### inherit — the operator-tiered escape hatch (deliberate, not "unpinned")

A fourth legal `model:` value for a plugin agent: the subagent runs on whatever tier the operator chose for the session. Pick it when ALL of these hold:

- The role's right tier is genuinely a **per-project cost/quality call**, not a property of the task shape (so no fixed rubric row above is correct for every user).
- The operator's own session tier is a good proxy for that call — a session run on a stronger model *should* get a stronger agent.
- A wrong hard pin is expensive in BOTH directions (pinning down costs more downstream than it saves; pinning up taxes every routine run).

`inherit` is an **explicit** declaration and a catalog↔frontmatter parity check must accept it as one — it is not a missing pin. Do not reach for it to avoid making a decision; the rubric above is the default path. Exactly one role uses it today (`bolt-implementer`, row 22).

### Default when in doubt: sonnet

Sonnet is the safe middle ground. Escalate to opus only with concrete evidence the task needs broader reasoning. Drop to haiku only when scope is provably bounded.

---

## Catalog

| # | Role | Tier | Rationale |
|---|---|---|---|
| 1 | `auth-extractor` | sonnet | Fuzzy detection across 5 auth libs + version + features; multi-file evidence (scan-codebase Iter 32) |
| 2 | `authz-extractor` | sonnet | Same pattern; RBAC libs + middleware + policies (scan-codebase Iter 32) |
| 3 | `ui-ux-extractor` | sonnet | Multi-domain (JS+CSS+notification+icon+datatable+idioms); empirically-grounded idiom inference needs reasoning (scan-codebase Iter 32) |
| 4 | `libs-extractor` | sonnet | Manifest parsing + category mapping + usage-hint grep across many libs (scan-codebase Iter 32) |
| 5 | `reuse-extractor` | sonnet | First-party source trawl (helpers/model_api/services/commands); multi-file pattern recognition; outputs reuse-index.yaml (scan-codebase reuse-awareness) |
| 6 | `extract-intelligence-wave-1` | sonnet | Artifact extraction; bounded artifact-set per agent (extract-intelligence) |
| 7 | `extract-intelligence-wave-2` | sonnet | Domain extraction; pattern recognition + multi-source synthesis |
| 8 | `extract-intelligence-wave-3` | sonnet | Cross-reference resolution across domain docs |
| 9 | `extract-intelligence-wave-4` | sonnet | Mutability tier classification (LOCKED/INTENT/ARTIFACT) with criteria |
| 10 | `extract-intelligence-wave-5` | **opus** | Holistic synthesis across all prior waves; main-thread; needs broadest context |
| 11 | `pipeline-audit-per-skill` | sonnet | Forensic audit across 10 dimensions per skill; bounded scope per skill (Iter 31 style) |
| 12 | `pipeline-audit-consolidator` | **opus** | Cross-skill pattern detection; consolidates 13 YAML inputs; broad reasoning (Iter 31 style) |
| 13 | `intelligence-audit-deep` | sonnet | 6-dimension audit on orchestrate-flow + handoff-contract; bounded (Iter 33 Phase B) |
| 14 | `intelligence-audit-probe` | **haiku** | Per-skill 0-3 scoring + 1-sentence justification; narrow decision space (Iter 33 Phase B) |
| 15 | `implementer` | sonnet | Typical implementation task (subagent-driven-development pattern); user can override to opus for complex tasks |
| 16 | `spec-reviewer` | sonnet | Compliance verification against spec (subagent-driven-development pattern) |
| 17 | `code-quality-reviewer` | **opus** | Deep code review; cross-cutting concerns; security/performance (subagent-driven-development pattern) |
| 18 | `domain-research` | **haiku** | Web fetches + structured extraction; low reasoning depth |
| 19 | `security-reviewer` | **opus** | Semantic authz-vs-spec + architectural-drift reasoning; deep code review per the opus criteria (review-panel security lens) |
| 20 | `standards-reviewer` | sonnet | Pattern recognition vs pack rules + sibling files; bounded judgment with known output schema (review-panel standards lens) |
| 21 | `design-reviewer` | sonnet | Code-evidence checks against an explicit design contract (tokens/states/a11y rubric); pattern recognition, not open-ended taste (review-panel design lens) |
| 22 | `bolt-implementer` | **inherit** | Deliberately operator-tiered, not unpinned: the implementer writes the code the LOCKED "akurasi code WAJIB" mandate is about, so it tracks the tier the operator chose for the session — a session run on a stronger model gets a stronger implementer with no plugin edit. A hard pin would also cut the wrong way in both directions: pinning down risks paying more via panel rejections + re-dispatches than the per-token saving, pinning up taxes every routine bolt. `inherit` is an EXPLICIT frontmatter value (`agents/bolt-implementer.md`), and any catalog↔frontmatter parity check must accept it as such (spec `2026-07-30-token-and-latency-optimization.md` §Phase 1a, amended) |

**Distribution:** 4 opus + 14 sonnet + 3 haiku + 1 inherit (22 rows). Sonnet-dominant by design; the sole `inherit` is the bolt implementer, whose tier is an operator choice.

---

## Override syntax

> **Scope (S7-PANEL-3):** the `model_tiers:` override chain applies to SKILL-LEVEL
> model picks (extraction waves, audit probes, consolidators). It does NOT apply to
> the execute-bolts review-panel lenses (`*-reviewer`) — those are pinned in each
> plugin agent's frontmatter, which the runtime reads directly; a
> `model_tiers: {security-reviewer: …}` entry is silently ignored at panel dispatch
> (see `execute-bolts/references/review-panel.md`). Do not configure panel lenses here.

### CLI flag (per-run override)

```bash
/mega-sdd --model-tier=intelligence-audit-probe:sonnet ./prd.md
# multiple overrides allowed:
/mega-sdd --model-tier=audit-consolidator:opus --model-tier=audit-probe:sonnet
```

### Per-project config

`<project>/.mega-sdd/config.yaml`:
```yaml
model_tiers:
  extract-intelligence-wave-5: sonnet  # cost-sensitive extraction on this project
  intelligence-audit-probe: sonnet  # bump from haiku to sonnet for higher signal
```

### User-scope preference

`~/.mega-sdd/memory/preferences.md`:
```markdown
## Model tiers

- `audit-consolidator`: opus  # personal preference (overrides catalog default)
- `extract-intelligence-wave-5`: sonnet  # cost-sensitive default
```

### Override chain precedence

CLI flag > per-project config > user-scope preference > catalog default.

Highest applicable override wins. If no override applies, catalog default is used.

---

## Adding new roles

When a future iter introduces a new subagent dispatch:

1. Pick a tier using **Tier selection rubric** above
2. Add a catalog entry to **Catalog** with:
   - Role name (unique kebab-case)
   - Tier (haiku|sonnet|opus)
   - Rationale (1-sentence why this tier, not the others)
3. Update the skill's SKILL.md subagent dispatch instruction to cite the catalog:
   `Model: per references/model-tiers.md §<role-name>`
4. If the role is a candidate for user override, document the override path in the role rationale.

**DO NOT hardcode `model: <tier>` in SKILL.md procedures**; always cite the catalog. This keeps tier choices auditable + centrally tunable.

---

## See also

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 2.8 (override resolution)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` §`model_tiers:` (handoff metadata schema)
- `plugins/mega-sdd/skills/memory/references/memory-schema.md` §preferences.md (user-scope override location)
- `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol (`model_tier_unknown` halt definition)
