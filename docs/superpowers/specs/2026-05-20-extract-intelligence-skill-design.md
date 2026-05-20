# `mega-sdd:extract-intelligence` — Design Spec

**Status**: Proposed → Implemented (v1.4.0)
**Date**: 2026-05-20
**Author**: Farhan Riuzaki (via Claude collaboration)
**Validates against**: Bank Mega Trade Finance legacy PHP rebuild (~600 files → 35-MD knowledge base, 968 KB)

---

## 1. Motivation

Mega-SDD pipeline (intent → units → bolts) assumes either:

- a PRD/BRD exists and is the source of truth (greenfield), or
- a `codebase-map.md` exists that `bind-codebase` can validate vault claims against (brownfield migration).

A third realistic scenario is missing from the rails: **legacy codebase + intent to rebuild on a different stack**. In this case:

- The codebase IS the only "spec" — there is no PRD.
- `scan-codebase`'s heuristic map (entities, modules, routes) is too thin for rebuild planning — it doesn't capture business rules, hidden gotchas, regulatory context, or state machines.
- The codebase is not in the target tech stack, so a tech-agnostic intermediate is required.
- The legacy code itself contains bugs the rebuild MUST NOT replicate, dependencies invisible to the repo (UDFs, external systems), and compliance gaps to close.

`superpowers:reverse-engineering-legacy-codebase` already addresses parts of this — but its output contract is generic. Downstream `mega-sdd` skills cannot consume it as context without a defined output shape and frontmatter contract.

This spec defines `mega-sdd:extract-intelligence` — a mega-sdd-flavored counterpart that produces a structured, machine-consumable knowledge base. The output is then consumed by `generate-intent` (Mode B brief) and `bind-codebase` (secondary ground truth).

## 2. Goals

- Produce a **tech-agnostic** domain knowledge base from a legacy codebase, organized by **business domain** (not by code structure).
- Apply the same anti-hallucination discipline as the rest of the mega-sdd pipeline: every non-trivial claim carries a `[VERIFIED] / [INFERRED] / [OPEN]` marker + a `file:line` citation.
- **Wave-based parallel subagent execution** to manage token budget on 600+-file codebases.
- **Machine-consumable output**: YAML frontmatter on every domain file, so downstream mega-sdd skills can read counts/classifications without re-parsing prose.
- Plug into pipeline routing: `orchestrate-flow` detects KB presence and routes the next step; `generate-intent --kb=<path>` accepts the KB as a Mode B brief; `bind-codebase` consults KB markers as secondary ground truth when codebase-map is silent or ambiguous.

## 3. Non-goals

- Direct code port to a newer version of the same stack — that's a migration, use specialized tools.
- Greenfield design — use `generate-intent` directly.
- Replacing `scan-codebase` — that remains the right tool for lighter, code-organized brownfield mapping.
- Replacing `bind-codebase` — KB is a secondary input, not a replacement for the codebase-map.

## 4. Naming + positioning

| Skill | Output | Use |
|---|---|---|
| `mega-sdd:scan-codebase` | `codebase-map.md` | Light heuristic catalog by code structure; consumed by `bind-codebase` as primary ground truth |
| `mega-sdd:extract-intelligence` | `docs/knowledge-base/` (multi-file) | Tech-agnostic domain knowledge for rebuild; consumed by `generate-intent` (Mode B brief) + `bind-codebase` (secondary marker source) |
| `superpowers:reverse-engineering-legacy-codebase` | Generic reverse-engineering | Standalone — when next step is NOT mega-sdd unit/bolt generation |

Naming chosen to avoid collision with the superpowers skill of the same purpose. `extract-intelligence` matches the working terminology already used in the validated trade-finance project (`legacy-system-intelligence.md`).

## 5. Output contract

### 5.1 Directory layout

```
{out}/
├── _source/                       # forensic seed cross-reference (optional, read-only)
└── knowledge-base/                # default `--out` target
    ├── README.md                  # nav + critical findings + OQ roll-up + stats
    ├── 00-overview/
    │   ├── system-purpose.md
    │   ├── glossary.md
    │   ├── module-classification.md
    │   └── actors-and-roles.md
    ├── 10-domains/                # 1 file per business domain (11-section template)
    ├── 20-workflows/              # cross-cutting workflows
    ├── 30-data-model/             # conceptual ERD + entities
    ├── 40-business-rules/         # regulatory + operational + hidden gotchas
    ├── 50-integrations/           # external contracts (conceptual, not protocol)
    └── 99-rebuild-architecture/   # suggested-erd / system-flow / dependency-graph / phasing
```

Default `--out`: `docs/knowledge-base/`. Configurable. Pipeline-consumers (`orchestrate-flow`, `generate-intent`, `bind-codebase`) probe `docs/knowledge-base/`, `docs/mega-sdd/knowledge-base/`, and `old-reference/knowledge-base/` in that order.

### 5.2 Per-domain file frontmatter (mandatory)

```yaml
---
generated_by: mega-sdd:extract-intelligence
generated_at: <ISO8601>
domain: <kebab-case-id>
classification: master | workflow | reporting | integration | reference
criticality: high | medium | low
rebuild_phase: 1 | 2 | 3
verified_count: <int>
inferred_count: <int>
open_count: <int>
source_files_cited: <int>
---
```

This frontmatter is what `bind-codebase` reads. The format mirrors `codebase-map.md` frontmatter so the binding consultation logic is symmetric.

### 5.3 Per-domain 11-section template

Defined in `references/knowledge-base-schema.md`. Every domain file MUST have all 11 sections:

1. Purpose
2. Actors (link to `00-overview/actors-and-roles.md`)
3. Flow (Input → Process → Output) — Mermaid flowchart
4. Inputs
5. Process — step-by-step business logic
6. Outputs
7. Business Rules — Rule / Why / Source
8. State Machine (only if classification = workflow)
9. Edge Cases & Gotchas
10. Open Questions
11. Source References — `file:line` citations

### 5.4 Marker discipline

- `[VERIFIED]` — confirmed by multiple code paths OR explicit doc
- `[INFERRED]` — single code path, needs confirmation
- `[OPEN]` — unknown from code, requires domain expert input → propagates to `bind-codebase` as OQ candidate

## 6. Execution model — 5 waves

```
Wave 0 (main thread)  : Prep — skeleton dirs, move seed to _source/
Wave 1 (3 subagents)  : Foundation — overview, glossary, classification, data-model, workflows
                        Gate check before Wave 2
Wave 2 (4 subagents)  : Masters — master entities, reference data, regulatory rules
                        Gate check before Wave 3
Wave 3 (5 subagents)  : Workflows — transactional flows, ops rules, hidden gotchas
                        Gate check before Wave 4
Wave 4 (3 subagents)  : Integrations & reporting
                        Gate check before Wave 5
Wave 5 (main thread)  : Synthesis — ERD, system-flow, dependency-graph, phasing, README
```

**Why wave-based**: token budget control (≤5 parallel subagents), later waves cross-reference earlier outputs (e.g., glossary anchors every domain file), quality gates catch template drift before it propagates downstream, main-thread synthesis avoids subagent context loss.

**Per-wave dispatch templates** + **gate grep commands** live in `references/wave-dispatch-templates.md`.

## 7. Integration with pipeline

### 7.1 `using-mega-sdd` anchor

Add CWD signals:
- `docs/knowledge-base/`, `old-reference/knowledge-base/`, `docs/mega-sdd/knowledge-base/`

Add trigger keywords:
- `reverse engineer`, `pecah legacy`, `legacy intelligence`, `rebuild di stack baru`, `extract domain`, `extract intelligence`

### 7.2 `orchestrate-flow` routing rules

Add to CWD inspection:
```
knowledge_base: present | absent (path: <detected-path>)
```

Add decision rows:

| State | Proposed chain |
|---|---|
| Legacy codebase + no PRD + no vault + rebuild intent | `extract-intelligence` → `generate-intent --kb=<kb>` |
| `knowledge-base/` exists + no vault | `generate-intent --kb=<kb>` |
| `knowledge-base/` exists + vault exists + bind-codebase conflicts | KB consultation runs inside `bind-codebase` automatically |

### 7.3 `generate-intent` consumes KB as Mode B brief

Add `--kb=<path>` flag. When set OR when CWD has `docs/knowledge-base/README.md`:
- Read `<kb>/README.md` as primary brief input.
- For each domain file under `<kb>/10-domains/`, treat `## 1. Purpose` + `## 7. Business Rules` as PRD-equivalent source quotes.
- Detection rule precedence: `--kb` explicit > `--from-prompt` brief > positional PRD file > CWD scan.
- Items marked `[VERIFIED]` in KB → eligible for vault body without re-asking the user during Mode B Q&A. Items marked `[INFERRED]` → surface as confirmation. Items marked `[OPEN]` → carry over to vault as OQs.

### 7.4 `bind-codebase` consults KB as secondary ground truth

When `bind-codebase` runs:
- Detect `knowledge-base/` presence in CWD or alongside the vault.
- If a vault claim cannot be matched in `codebase-map.md`:
  - Search KB domain files for the claim.
  - KB `[VERIFIED]` match → CONFIRMED.
  - KB `[INFERRED]` match → CONFIRMED with note "verified via KB inference".
  - KB `[OPEN]` match → escalate as OQ.
- Never override a `codebase-map.md` CONFLICT verdict; KB is only consulted for unmatched/ambiguous cases.

## 8. Anti-hallucination invariants

These do NOT change; they extend to the new skill:

- No invented entities, fields, flows, decisions, regulations, or business rules.
- Every non-trivial claim cites `file:line`.
- Ambiguous → `[OPEN]`, never silent default.
- Tech-agnostic vocabulary outside `## 11. Source References` and `50-integrations/`.
- Synthesis wave (5) is main-thread only — subagents lack the holistic view.

## 9. CLI surface

```bash
/mega-sdd:extract-intelligence <legacy-codebase-path> [--out=<path>] [--seed=<path>] [--max-parallel=N] [--auto]
```

- Positional: legacy codebase path (required)
- `--out=<path>`: knowledge-base output dir (default `docs/knowledge-base/`)
- `--seed=<path>`: optional pre-existing forensic dump moved to `_source/`
- `--max-parallel=N`: subagent cap per wave (default 5, hard cap 8)
- `--auto`: skip per-wave confirmation prompts; still halts on quality-gate failures

## 10. Halt conditions

- Legacy path missing or empty → halt, ask user
- `--max-parallel` > 8 → halt, warn token budget collapse
- Quality gate fails twice on the same wave for the same agent → halt with gate output
- Wave 5 synthesis dispatched as a subagent → halt (config error; must be main thread)

## 11. Versioning + rollout

- Plugin: `1.3.0` → `1.4.0` (minor — additive)
- New skill: `extract-intelligence` v1.0.0
- Touched skills:
  - `using-mega-sdd`: 1.0.0 → 1.1.0 (trigger + signal extension)
  - `orchestrate-flow`: 1.1.0 → 1.2.0 (routing-rules extension)
  - `generate-intent`: 1.1.0 → 1.2.0 (`--kb` flag + KB consumption)
  - `bind-codebase`: 1.0.0 → 1.1.0 (KB consultation logic)

Backward compatibility: every change is additive. Pipelines that don't produce a KB behave unchanged. The KB consultation in `bind-codebase` is gated on KB presence — projects without a KB get identical behavior to v1.3.

## 12. Test coverage

New: `tests/skill-triggering/extract-intelligence.test.md`

Trigger cases:
- E1: explicit `/mega-sdd:extract-intelligence ./legacy-php/`
- E2: natural — "reverse engineer this legacy code"
- E3: Indonesian — "pecah legacy code jadi knowledge base"
- E4: `orchestrate-flow` auto-route — legacy codebase + no PRD + no vault

Behavior checks:
- B1: `docs/knowledge-base/` exists with all 7 top-level dirs
- B2: every domain file has YAML frontmatter with counts
- B3: every domain file has all 11 sections
- B4: anti-hallucination — when a regulation is unknown, OQ is emitted, not invented
- B5: wave 5 ran on main thread (synthesis section present in README)

## 13. Real-world validation

Bank Mega Trade Finance legacy:
- ~600 PHP files (MySQL + MSSQL + LDAP + SWIFT FTP)
- Input: 63.9 KB forensic seed doc
- Output: 35 MD files, ~968 KB, 13 business domains
- Findings beyond seed doc:
  - Actor-order error in seed (corrected by code reading)
  - 41 hidden gotchas (silent bugs, race conditions)
  - 430 open questions catalogued for domain expert
  - 4 critical legacy bugs documented (do-not-replicate list)
  - Hidden MySQL UDF dependency (`BizDaysInclusive`)
  - Compliance gap: no OFAC sanctions screening (must add)
- Time: ~3 hours wall-clock for 15 agent dispatches across 5 waves
- Output usable immediately as Phase 1 acceptance criteria

This validates the wave-based parallel-subagent approach + the marker discipline as the right cost/quality trade-off for legacy-rebuild planning.

## 14. References

- `plugins/mega-sdd/skills/extract-intelligence/SKILL.md` — skill content
- `plugins/mega-sdd/skills/extract-intelligence/references/knowledge-base-schema.md` — output shape
- `plugins/mega-sdd/skills/extract-intelligence/references/wave-dispatch-templates.md` — per-wave agent prompts + gate checks
- `docs/superpowers/specs/2026-05-13-mega-sdd-revamp-design.md` — pipeline overview this skill extends
