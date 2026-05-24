# Model Tiers Catalog

> Single source of truth for which model tier each named subagent role uses across the mega-sdd plugin.

**Version:** 1.0
**Introduced:** v3.25.0 (Iter 34)
**Consumed by:** all SKILL.md subagent dispatch sites (cite via `references/model-tiers.md §<role-name>`)
**Resolved by:** `mega-sdd:orchestrate-flow` v3.1.0+ Step 2.8 (override chain: CLI > project config > user preference > catalog default)

---

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

**Examples:** deep-scan extractors (auth/rbac/ui-ux/libs); pipeline-audit per-skill; spec-reviewer; implementer for typical tasks.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

**Examples:** extract-intelligence wave-5 synthesis; intelligence-audit deep dimension analysis; code-quality-reviewer; pipeline-audit consolidator.

### Default when in doubt: sonnet

Sonnet is the safe middle ground. Escalate to opus only with concrete evidence the task needs broader reasoning. Drop to haiku only when scope is provably bounded.

---

## Catalog

| # | Role | Tier | Rationale |
|---|---|---|---|
| 1 | `auth-extractor` | sonnet | Fuzzy detection across 5 auth libs + version + features; multi-file evidence (scan-codebase Iter 32) |
| 2 | `rbac-extractor` | sonnet | Same pattern; 3 RBAC libs + middleware + policies (scan-codebase Iter 32) |
| 3 | `ui-ux-extractor` | sonnet | Multi-domain (JS+CSS+notification+icon+datatable+idioms); empirically-grounded idiom inference needs reasoning (scan-codebase Iter 32) |
| 4 | `libs-extractor` | sonnet | Manifest parsing + category mapping + usage-hint grep across many libs (scan-codebase Iter 32) |
| 5 | `extract-intelligence-wave-1` | sonnet | Artifact extraction; bounded artifact-set per agent (extract-intelligence) |
| 6 | `extract-intelligence-wave-2` | sonnet | Domain extraction; pattern recognition + multi-source synthesis |
| 7 | `extract-intelligence-wave-3` | sonnet | Cross-reference resolution across domain docs |
| 8 | `extract-intelligence-wave-4` | sonnet | Mutability tier classification (LOCKED/INTENT/ARTIFACT) with criteria |
| 9 | `extract-intelligence-wave-5` | **opus** | Holistic synthesis across all prior waves; main-thread; needs broadest context |
| 10 | `pipeline-audit-per-skill` | sonnet | Forensic audit across 10 dimensions per skill; bounded scope per skill (Iter 31 style) |
| 11 | `pipeline-audit-consolidator` | **opus** | Cross-skill pattern detection; consolidates 13 YAML inputs; broad reasoning (Iter 31 style) |
| 12 | `intelligence-audit-deep` | sonnet | 6-dimension audit on orchestrate-flow + handoff-contract; bounded (Iter 33 Phase B) |
| 13 | `intelligence-audit-probe` | **haiku** | Per-skill 0-3 scoring + 1-sentence justification; narrow decision space (Iter 33 Phase B) |
| 14 | `implementer` | sonnet | Typical implementation task (subagent-driven-development pattern); user can override to opus for complex tasks |
| 15 | `spec-reviewer` | sonnet | Compliance verification against spec (subagent-driven-development pattern) |
| 16 | `code-quality-reviewer` | **opus** | Deep code review; cross-cutting concerns; security/performance (subagent-driven-development pattern) |
| 17 | `domain-research` | **haiku** | Web fetches + structured extraction; low reasoning depth |

**Distribution:** 3 opus + 11 sonnet + 3 haiku. Sonnet-dominant by design.

---

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
- `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` §halt-protocol (`model_tier_unknown` halt definition)
