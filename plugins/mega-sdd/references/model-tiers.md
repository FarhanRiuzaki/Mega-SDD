# Model Tiers Catalog

> Single source of truth for which model tier each named subagent role uses across the mega-sdd plugin.

**Version:** 1.0
**Introduced:** v3.25.0 (Iter 34)
**Consumed by:** all SKILL.md subagent dispatch sites (cite via `references/model-tiers.md §<role-name>`)
**Resolved by:** `mega-sdd:orchestrate-flow` v3.1.0+ Step 2.8 (override chain: CLI > project config > catalog default — non-panel roles only; `*-reviewer` lenses are frontmatter-pinned, see §Override syntax)

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

**Examples:** manifest-only lib detection; catalog lookup; `verify`-only bolt routing (the `haiku ← tier minimal AND task_type verify` rung in `resolve-review-tier.sh`).

### sonnet — pick when ANY of these hold (default)
- Pattern recognition across multiple documents
- Fuzzy classification (e.g., "is this Sanctum or Breeze?" — multiple signals to weigh)
- Structured synthesis with known output schema
- Bounded reasoning depth (≤5 reasoning steps)
- Mid-range cost/quality tradeoff

**Examples:** deep-scan extractors (auth/authz/ui-ux/libs/reuse); spec-reviewer; implementer for typical tasks.

### opus — pick when ANY of these hold
- Open-ended reasoning (no fixed output schema)
- Holistic synthesis across many sources (≥10 documents OR ≥5 categories)
- Architectural decisions (skill body design, schema design, halt taxonomy decisions)
- Deep code review (cross-cutting concerns, security, performance)
- Cross-cutting pattern detection across a codebase

**Examples:** code-quality-reviewer; security-reviewer (the review-panel opus criteria); implementer overridden up for a complex rebuild.

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

Row numbers are stable history, so gaps are deliberate: 7–10 retired with the wave
pipeline (v7.6.0), 11–14 + 18 removed 7.13.0 (zero dispatch sites anywhere in the
plugin — a `model_tiers:` override naming them now gets an honest `model_tier_unknown`
notice instead of validating silently and doing nothing).

| # | Role | Tier | Rationale |
|---|---|---|---|
| 1 | `auth-extractor` | sonnet | Fuzzy detection across 5 auth libs + version + features; multi-file evidence (scan-codebase Iter 32) |
| 2 | `authz-extractor` | sonnet | Same pattern; RBAC libs + middleware + policies (scan-codebase Iter 32) |
| 3 | `ui-ux-extractor` | sonnet | Multi-domain (JS+CSS+notification+icon+datatable+idioms); empirically-grounded idiom inference needs reasoning (scan-codebase Iter 32) |
| 4 | `libs-extractor` | sonnet | Manifest parsing + category mapping + usage-hint grep across many libs (scan-codebase Iter 32) |
| 5 | `reuse-extractor` | sonnet | First-party source trawl (helpers/model_api/services/commands); multi-file pattern recognition; outputs reuse-index.yaml (scan-codebase reuse-awareness) |
| 6 | `extract-intelligence-module` | sonnet | Per-module PRD-kontrak extraction; bounded file-set per agent, disciplines ride the agent body (extract-intelligence). Synthesis (README roll-up + data-mutation-policy) runs on the MAIN thread — no dispatched role |
| 23 | `extract-intelligence-verify` | sonnet | Claim-verify lane (7.25.0): adversarial per-module citation grading against explicit claims with a known output schema — the spec-reviewer/resolution-verifier class of bounded judgment; escalate via `model_tiers:` override for gnarly legacy dialects |
| 15 | `implementer` | sonnet | Typical implementation task (subagent-driven-development pattern); user can override to opus for complex tasks |
| 16 | `spec-reviewer` | sonnet | Compliance verification against spec (subagent-driven-development pattern) |
| 17 | `code-quality-reviewer` | **opus** | Deep code review; cross-cutting concerns; security/performance (subagent-driven-development pattern) |
| 19 | `security-reviewer` | **opus** | Semantic authz-vs-spec + architectural-drift reasoning; deep code review per the opus criteria (review-panel security lens) |
| 20 | `standards-reviewer` | sonnet | Pattern recognition vs pack rules + sibling files; bounded judgment with known output schema (review-panel standards lens) |
| 21 | `design-reviewer` | sonnet | Code-evidence checks against an explicit design contract (tokens/states/a11y rubric); pattern recognition, not open-ended taste (review-panel design lens) |
| 21b | `resolution-verifier` | sonnet | Fix-round verification: per-finding resolved/unresolved against new-head evidence + delta review of the fix range — bounded judgment against an explicit finding ledger, known output schema (review-panel §Attempt rounds) |
| 22 | `bolt-implementer` | **inherit → v7.1 per-unit routed** | AMENDED v7.1 (spec 2026-08-22-per-unit-model-routing-design.md): config `model_tiers.bolt_implementer:` default `inherit` keeps the operator-tier behavior below verbatim; `auto` routes per unit from the SAME deterministic risk signals as the review-panel tier (opus←full, haiku←verify-only, sonnet←else) + a one-step evidence-gated cascade — NOT the hard pin the old rationale rejected (the pin follows per-unit evidence, both directions of the old cost argument are answered). Ship default stays `inherit` until the clinic A/B passes (≥25% token saving, panel quality equal — user gate). ORIGINAL rationale (still governs `inherit`): Deliberately operator-tiered, not unpinned: the implementer writes the code the LOCKED "akurasi code WAJIB" mandate is about, so it tracks the tier the operator chose for the session — a session run on a stronger model gets a stronger implementer with no plugin edit. A hard pin would also cut the wrong way in both directions: pinning down risks paying more via panel rejections + re-dispatches than the per-token saving, pinning up taxes every routine bolt. `inherit` is an EXPLICIT frontmatter value (`agents/bolt-implementer.md`), and any catalog↔frontmatter parity check must accept it as such (spec `2026-07-30-token-and-latency-optimization.md` §Phase 1a, amended) |

**Distribution:** 3 opus + 14 sonnet + 2 haiku + 1 inherit (20 rows). Sonnet-dominant by design; the sole `inherit` is the bolt implementer, whose tier is an operator choice.

---

## Override syntax

> **Scope (S7-PANEL-3):** the `model_tiers:` override chain applies to SKILL-LEVEL
> model picks (module extraction, audit probes, consolidators). It does NOT apply to
> the execute-bolts review-panel lenses (`*-reviewer`) — those are pinned in each
> plugin agent's frontmatter, which the runtime reads directly; a
> `model_tiers: {security-reviewer: …}` entry is silently ignored at panel dispatch
> (see `execute-bolts/references/review-panel.md`). Do not configure panel lenses here.

### CLI flag (per-run override)

```bash
# Primary (shipped) grammar — bare tier, forwarded to execute-bolts:
/mega-sdd --model-tier=sonnet ./prd.md     # inherit | auto | haiku | sonnet | opus

# orchestrate-flow-scoped grammar — <role>:<tier> per catalog role:
/mega-sdd --model-tier=implementer:opus ./prd.md
# multiple overrides allowed:
/mega-sdd --model-tier=implementer:opus --model-tier=libs-extractor:haiku
```

### Per-project config

`<project>/.mega-sdd/config.yaml`:
```yaml
model_tiers:
  extract-intelligence-module: sonnet  # cost-sensitive extraction on this project
  implementer: opus  # complex rebuild — the row-15 rationale names this exact override
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

- `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` §Step 2.8 (override resolution)
- `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md` §`model_tiers:` (handoff metadata schema)
- `plugins/mega-sdd/references/halt-protocol.md` §halt-protocol (`model_tier_unknown` halt definition)

## v7.1 office rollout runbook (per-unit routing)

1. **Probe the build first (1 line, never assume):** dispatch `Agent(subagent_type: general-purpose, model: "haiku")` asking the agent to quote its own system-prompt model line. Reply names Haiku → the `model` param works on that build; reply names the session model → STOP, report (frontmatter wins there — the file-variant fallback is a separate decision, do not build it ad hoc).
2. **Gateway sessions (mega-code):** the model aliases must resolve at the office gateway; if they do not, set `model_tiers.bolt_implementer: inherit` (or a hard value the gateway serves) per project — the config neutralizes routing without a plugin change.
3. Ship default is `inherit` everywhere until the A/B gate passes; flipping to `auto` is a config-line change, not a plugin release.
4. **Field-pilot measurement:** after ≥10 bolts on a pilot project, read `model_used` / `escalated_from` / `signals_fired` from each unit's `bolts/U-*/bolt-report.md` (the per-unit audit trail — part of the bolt artifact set) and price the run **gateway-side** (the gateway logs usage per request; billing is a gateway concern, not this plugin's — v7.3.0 removed all in-plugin cost reporting). The 2026-08-22 pilot showed raw tokens are the WRONG flip metric (cheaper model ≠ fewer tokens) — decide on the gateway-billed number.
