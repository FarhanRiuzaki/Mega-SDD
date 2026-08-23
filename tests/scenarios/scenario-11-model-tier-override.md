# Scenario 11 — Model Tier Override

**Time:** ~5 minutes
**When to use:** override default model tiers per subagent role (cost control OR quality boost)
**Prerequisites:** plugin v7.1+

## What you'll learn

- mega-sdd uses a curated catalog (23 named roles × tier) for subagent dispatches
- 2 ways to override: CLI flag, project config
- When to escalate (opus) vs. when to drop (haiku)

## The catalog

By default mega-sdd picks tier per role per `plugins/mega-sdd/references/model-tiers.md`:

- 4 roles default **opus**: `extract-intelligence-wave-5` (synthesis), `pipeline-audit-consolidator`, `code-quality-reviewer`, `security-reviewer` (reviewer lenses stay frontmatter-pinned — see the Scope note under Example 1)
- 16 roles default **sonnet**: deep-scan extractors, early waves, audit-per-skill, implementers, etc.
- 2 roles default **haiku**: `intelligence-audit-probe`, `domain-research`

Distribution is sonnet-dominant by design (rubric in catalog file).

## Override mechanism — 3 levels (highest precedence first)

1. **CLI flag** (per-run): `--model-tier=<role>:<tier>`
2. **Per-project config**: `<project>/.mega-sdd/config.yaml` `model_tiers:` section (the single persistent override surface — the user-scope rung was removed in v7.3.0)
3. **Catalog default**: `references/model-tiers.md §Catalog`

## Example 1 — Cost-sensitive run (one-off)

You're testing a feature; don't need opus reviews. Override code-quality-reviewer to sonnet for THIS run:

```bash
/mega-sdd --model-tier=code-quality-reviewer:sonnet ./prd.md
```

Multiple overrides allowed:

```bash
/mega-sdd \
  --model-tier=intelligence-audit-probe:sonnet \
  --model-tier=extract-intelligence-wave-5:sonnet \
  ./prd.md
```

> **Scope:** `model_tiers:` covers SKILL-LEVEL roles only. The execute-bolts review-panel
> lenses (`*-reviewer`) are pinned in each agent's frontmatter and silently ignore this
> config — see `review-panel.md` / `model-tiers.md §Override syntax`.

## Example 2 — Project always wants cheaper extraction

You manage a project where the team standardizes on cheaper extraction/audit passes:

```yaml
# <project>/.mega-sdd/config.yaml
model_tiers:
  intelligence-audit-probe: sonnet
  extract-intelligence-wave-5: sonnet
```

Applies to every mega-sdd run in this project. Doesn't affect other projects.

## Example 3 — Persistent quality boost

The user-scope model-tier rung was removed in v7.3.0 — the override surface is the per-project `.mega-sdd/config.yaml` (single source) + the CLI flag. A persistent boost therefore lives in the project config.

The real use case: bumping intelligence-audit-probe from haiku to sonnet because you want more thorough scoring:

```yaml
# <project>/.mega-sdd/config.yaml
model_tiers:
  intelligence-audit-probe: sonnet  # default haiku is fine, but I prefer higher signal
```

## Example 4 — Unknown role tolerance

What if you reference a role not in catalog?

```yaml
# .mega-sdd/config.yaml
model_tiers:
  future-unreleased-role: opus
```

The chain emits SOFT halt `model_tier_unknown` + log: "Role 'future-unreleased-role' not in catalog; override ignored. Chain proceeds." 

Forward-compat: when a future iter adds `future-unreleased-role` to catalog, this override auto-applies on next run.

## Example 5 — per-unit implementer routing (v7.1)

The bolt implementer gets its own routing knob:

```yaml
# <project>/.mega-sdd/config.yaml
model_tiers:
  bolt_implementer: inherit   # or: auto
```

- `inherit` (default): the implementer tracks the operator's session tier.
- `auto`: the router picks the `implementer_model` per unit from resolve-review-tier's six risk signals; haiku is verify-only.

Front-door flags: `--model-tier=inherit|auto|haiku|sonnet|opus` + `--no-escalate`.

Cascade: 2 consecutive failed attempts → the next attempt runs ONE tier higher, at most once per unit; never auto-de-escalate.

Audit fields in `bolt-report.md`: `model_used`, `escalated_from`, `signals_fired`.

## When to escalate to opus

Per the catalog rubric (top of `model-tiers.md`):

- **Open-ended reasoning** (no fixed output schema)
- **Holistic synthesis** across many sources (≥10 documents or ≥5 categories)
- **Architectural decisions** (skill body design, schema design)
- **Deep code review** (cross-cutting concerns, security, performance)

If your override is for one of these → opus is correct.

## When to drop to haiku

Per the catalog rubric:

- Task is bounded scope (≤2 files read, ≤1KB output)
- Decision space is narrow (enum-like, ≤5 distinct outputs)
- No multi-document synthesis
- No architectural reasoning
- Speed/cost dominates quality

If your override is for a probe-style scoring or web fetch → haiku is correct.

## Verify override applied

After running with overrides, check chain output. orchestrate-flow logs final tier resolution:

```
Model tier overrides applied: code-quality-reviewer=sonnet (cli-flag); extract-intelligence-wave-5=sonnet (cli-flag)
```

handoff metadata.model_tiers + model_tier_sources blocks have the provenance trail (source: catalog | user | project | cli per role).

## See also

- `plugins/mega-sdd/references/model-tiers.md` — full catalog (23 roles × tier + rationale)
- `docs/mega-sdd/reading-map.md` — Stage 7 cross-cutting (where overrides live)
