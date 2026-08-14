# Scenario 11 — Model Tier Override

**Time:** ~5 minutes
**When to use:** override default model tiers per subagent role (cost control OR quality boost)
**Prerequisites:** plugin v6+

## What you'll learn

- mega-sdd uses a curated catalog (17 named roles × tier) for subagent dispatches
- 3 ways to override: CLI flag, project config, user preference
- When to escalate (opus) vs. when to drop (haiku)

## The catalog

By default mega-sdd picks tier per role per `plugins/mega-sdd/references/model-tiers.md`:

- 3 roles default **opus**: `extract-intelligence-wave-5` (synthesis), `pipeline-audit-consolidator`, `code-quality-reviewer`
- 12 roles default **sonnet**: deep-scan extractors, early waves, audit-per-skill, implementers, etc.
- 2 roles default **haiku**: `intelligence-audit-probe`, `domain-research`

Distribution is sonnet-dominant by design (rubric in catalog file).

## Override mechanism — 4 levels (highest precedence first)

1. **CLI flag** (per-run): `--model-tier=<role>:<tier>`
2. **Per-project config**: `<project>/.mega-sdd/config.yaml` `model_tiers:` section
3. **User-scope preference**: `~/.mega-sdd/memory/preferences.md` `## Model tiers` section
4. **Catalog default**: `references/model-tiers.md §Catalog`

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

## Example 3 — User-scope quality boost

You always want deep audit consolidator on opus (the catalog default; you want to ensure it stays opus even if a project config tries to drop it):

```markdown
# ~/.mega-sdd/memory/preferences.md

## Model tiers

- `pipeline-audit-consolidator`: opus  # personal default — keep even if project overrides
```

Wait — but project config wins over user preference per precedence chain. So this preference only applies when project doesn't override.

The real use case: bumping intelligence-audit-probe from haiku to sonnet because you want more thorough scoring:

```markdown
# ~/.mega-sdd/memory/preferences.md

## Model tiers

- `intelligence-audit-probe`: sonnet  # default haiku is fine, but I prefer higher signal
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

- `plugins/mega-sdd/references/model-tiers.md` — full catalog (17 roles × tier + rationale)
- `plugins/mega-sdd/references/reading-map.md` — Stage 7 cross-cutting (where overrides live)
