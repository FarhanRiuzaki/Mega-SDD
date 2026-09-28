# Scenario 11 — Model Tier Override

**Time:** ~5 minutes
**When to use:** override the default model tier of an extract-intelligence role (cost control OR quality boost)
**Prerequisites:** plugin v9 with P3 (spec v9 §8.6 — the per-unit implementer and the review-panel roles are gone)

## What you'll learn

- mega-sdd uses a curated catalog (role × tier) for its subagent dispatches: the two extract-intelligence roles
- 2 ways to override: project config, CLI flag
- When to escalate (opus) vs. when to drop (haiku)

## The catalog

By default mega-sdd picks tier per role per `plugins/mega-sdd/references/model-tiers.md`:

- `extract-intelligence-module` — **sonnet** (per-module PRD-kontrak extraction; synthesis runs on the MAIN thread — no dispatched role)
- `extract-intelligence-verify` — **sonnet** (claim-verify lane: adversarial per-module citation grading)

`execute-bolts` dispatches no plugin agent (one blind `general-purpose` reviewer at the close), so it has no catalog row.

## Override mechanism — 3 levels (highest precedence first)

1. **CLI flag** (per-run): `--model-tier=<role>:<tier>`
2. **Per-project config**: `<project>/.mega-sdd/config.yaml` `model_tiers:` section (the single persistent override surface)
3. **Catalog default**: `references/model-tiers.md §Catalog`

## Example 1 — Project config (persistent)

A gnarly legacy dialect needs a stronger claim verifier; extraction stays on the default:

```yaml
# <project>/.mega-sdd/config.yaml
model_tiers:
  extract-intelligence-module: sonnet   # pin extraction to sonnet on this project
  extract-intelligence-verify: opus     # the row-23 rationale names this override
```

Applies to every mega-sdd run in this project. Doesn't affect other projects. An underscored key (`extract_intelligence_module`) is read the same way.

## Example 2 — CLI flag (one-off)

```bash
/mega-sdd --model-tier=extract-intelligence-module:opus --model-tier=extract-intelligence-verify:opus ./legacy/
```

The bare `--model-tier=<tier>` form and `--no-escalate` are retired (no implementer is dispatched); the front door says so in one line and carries on.

## Example 3 — Unknown or retired role

What if you reference a role not in the catalog — a future role, or a key from before P3 (`bolt_implementer`, a `*-reviewer` lens)?

```yaml
# .mega-sdd/config.yaml
model_tiers:
  bolt_implementer: auto
```

GROUND emits the `[self-resolved] model_tier_unknown` notice on every run: `role 'bolt_implementer' unknown; chain uses catalog default`. It never halts; delete the key to silence it.

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

## Verify override applied

After running with overrides, check chain output. orchestrate-flow logs final tier resolution:

```
Model tier overrides applied: extract-intelligence-verify=opus (project); extract-intelligence-module=opus (cli-flag)
```

handoff metadata.model_tiers + model_tier_sources blocks have the provenance trail (source: catalog | project | cli per role).

## See also

- `plugins/mega-sdd/references/model-tiers.md` — full catalog (role × tier + rationale; numbering gaps are retired rows)
- `docs/mega-sdd/reading-map.md` — Stage 7 cross-cutting (where overrides live)
