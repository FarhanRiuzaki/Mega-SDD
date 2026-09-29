# Model Tiers Catalog

> Single source of truth for which model tier each named subagent role uses across the mega-sdd plugin.

**Version:** 1.0
**Consumed by:** the extract-intelligence module / claim-verify dispatch (rows 6, 23) + `scripts/ground.sh` Guard 8 (validates `model_tiers:` override role names against the Role column); agent-backed roles are pinned in `agents/*.md` frontmatter (parity with rows 6, 23)
**Resolved by:** `mega-sdd:orchestrate-flow` (SKILL.md "Model-tier override resolution" bullet; procedure in `references/chain-execution.md`) (override chain: CLI > project config > catalog default)

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

**Examples:** manifest-only lib detection; catalog lookup.

### sonnet — pick when ANY of these hold (default)
- Pattern recognition across multiple documents
- Fuzzy classification (e.g., "is this Sanctum or Breeze?" — multiple signals to weigh)
- Structured synthesis with known output schema
- Bounded reasoning depth (≤5 reasoning steps)
- Mid-range cost/quality tradeoff

**Examples:** extract-intelligence module + claim-verify agents.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

**Examples:** claim-verify overridden up for a gnarly legacy dialect (row 23).

### Default when in doubt: sonnet

Sonnet is the safe middle ground. Escalate to opus only with concrete evidence the task needs broader reasoning. Drop to haiku only when scope is provably bounded.

---

## Catalog

Row numbers are stable, so gaps are deliberate: 1–5 retired with the
scan-codebase deep-scan (9.0), 7–10 retired with the wave pipeline, 16–21b with
the review panel (P3), 15 + 22 with the per-unit implementer (P3), 11–14 + 18 removed (zero dispatch sites anywhere in the plugin — a `model_tiers:` override
naming them now gets an honest `model_tier_unknown` notice instead of validating
silently and doing nothing).

| # | Role | Tier | Rationale |
|---|---|---|---|
| 6 | `extract-intelligence-module` | sonnet | Per-module PRD-kontrak extraction; bounded file-set per agent, disciplines ride the agent body (extract-intelligence). Synthesis (README roll-up + data-mutation-policy) runs on the MAIN thread — no dispatched role |
| 23 | `extract-intelligence-verify` | sonnet | Claim-verify lane: adversarial per-module citation grading against explicit claims with a known output schema — bounded judgment; escalate via `model_tiers:` override for gnarly legacy dialects |

**Distribution:** 2 sonnet (2 rows). Sonnet by design: both roles are bounded extraction/grading work.

---

## Override syntax

> **Scope:** the `model_tiers:` override chain applies to the extract-intelligence
> roles (module extraction, claim-verify). A role with no catalog row (e.g. a
> retired `bolt_implementer` or `*-reviewer` key) gets GROUND's
> `model_tier_unknown` notice and is otherwise ignored.

### CLI flag (per-run override)

```bash
# <role>:<tier> per catalog role (the bare --model-tier=<tier> form is retired):
/mega-sdd --model-tier=extract-intelligence-module:opus ./legacy/
# multiple overrides allowed:
/mega-sdd --model-tier=extract-intelligence-module:opus --model-tier=extract-intelligence-verify:opus
```

### Per-project config

`<project>/.mega-sdd/config.yaml`:
```yaml
model_tiers:
  extract-intelligence-module: sonnet  # cost-sensitive extraction on this project
  extract-intelligence-verify: opus  # gnarly legacy dialect — the row-23 rationale names this override
```

### Override chain precedence

CLI flag > per-project config > catalog default.

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

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` "Model-tier override resolution" bullet + `references/chain-execution.md` (override resolution)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` §`model_tiers:` (handoff metadata schema)
- `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol (`model_tier_unknown` halt definition)
