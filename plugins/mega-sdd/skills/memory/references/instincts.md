# Instincts — confidence-scored atomic learnings with bounded re-injection

The closing half of the learning loop (spec `docs/superpowers/specs/2026-06-12-instincts-and-gateguard-design.md` §A). `patterns.md ## Pending suggestions` accumulates candidates; instincts are the GRADUATED form — atomic, confidence-weighted, and re-injected into context automatically so a learning actually changes future behavior.

## Contents

- Schema
- Lifecycle (confidence rules)
- Promotion (project → global)
- Re-injection contract
- Relationship to patterns.md

## Schema

One YAML file per instinct. Project scope: `<project>/.mega-sdd/memory/instincts/<slug>.yaml`. Global scope: `~/.mega-sdd/memory/instincts/<slug>.yaml`.

```yaml
id: money-fields-use-helper          # kebab-case slug = filename
trigger: "rendering a money/amount field in a view"     # ONE situation
action: "format via the project money helper, never raw {{ $x->amount }}"  # ONE behavior
confidence: 0.7                      # 0.3–0.9; see lifecycle
domain: ui                           # ui | security | testing | conventions | workflow | general
scope: project                       # project | global (set by promotion, never by hand-edit alone)
status: active                       # active | retired
evidence:
  - { ts: 2026-06-12, source: panel-finding, ref: "bolts/U-011/bolt-report.md" }
  - { ts: 2026-06-12, source: drift, ref: "DRIFT-REPORT.md DR-002" }
created: 2026-06-12
last_confirmed: 2026-06-12
```

Atomicity is the rule: one trigger, one action. A "pattern" needing three sentences is a `patterns.md` entry or a skill change, not an instinct.

## Lifecycle (confidence rules)

Owned by the SAME chain-end pass that runs the learning-rules §1 thresholds (orchestrate-flow Step 7.6) — no skill evaluates instincts mid-chain:

| Event | Effect |
|---|---|
| Birth | a threshold-crossing observation class (same panel-finding class ≥2, same drift class ≥2, or 1 explicit user correction) → new instinct at **0.5** (user-correction births at **0.6** — corrections are high-signal) |
| Reconfirmation (same class observed again, no correction) | **+0.1**, cap **0.9**; update `last_confirmed` + append evidence |
| Explicit user correction against the instinct | **−0.2** |
| Staleness (`last_confirmed` > 30 days at a chain-end pass) | **−0.1** |
| confidence < **0.3** | `status: retired` (file kept — evidence trail, never silently deleted) |

Evidence is mandatory: an instinct with an empty `evidence` list is invalid (no fabricated learnings — the memory-layer analog of citation discipline).

## Promotion (project → global)

At chain end, the pass appends one line per active instinct to `~/.mega-sdd/memory/instincts/_seen.jsonl`:

```json
{"project": "<12-char hash of git remote origin (or project path)>", "key": "<id>", "confidence": 0.8, "ts": "..."}
```

When the same `key` appears from **≥2 distinct projects** with **avg confidence ≥0.8**, copy the instinct to `~/.mega-sdd/memory/instincts/` with `scope: global`. Demotion is manual (`/mega-sdd:memory review`) — global instincts are a curated set, not an auto-churning one.

## Re-injection contract

- **SessionStart hook** (the point of the whole system): top **6** active instincts with confidence **≥0.7** — project scope first, then global, sorted by confidence — appended as a `<learned-instincts>` block, hard budget **1200 chars**. Opt-out: `instincts: false` in `.mega-sdd/config.yaml`. Parse failures are silent (injection is advisory context, never a gate).
- **Bolt T2**: instincts whose `domain` matches the unit (ui → UI-bearing units, security → risk-signal units, etc.) ride the existing `Historical memory` slice in `bolt-dispatch-prompt.md` — same budget, same truncation tier; no new section.
- Injected instincts are ADVISORY: a Hard rule, the spec, or the user always wins. The injection text says so explicitly.

## Relationship to patterns.md

`patterns.md ## Pending suggestions` remains the staging area (human-reviewable, status: pending). An accepted suggestion that is atomic (one trigger → one action) graduates to an instinct file; broader accepted patterns stay in `patterns.md` as before. `/mega-sdd:memory review` walks both.
