---
name: extract-intelligence
version: 1.4.0
description: Tech-agnostic domain extractor for legacy codebases targeted for rebuild. Wave-based parallel-subagent extraction produces `.mega-sdd/knowledge-base/` with `[VERIFIED]/[INFERRED]/[OPEN]` confidence markers + (v1.4+ Iter 22) `[LOCKED]/[INTENT]/[ARTIFACT]` mutability tiers — KB is an analysis input that drives REENGINEERING recommendations, not a 1:1 mirror of legacy. Output consumable by `mega-sdd:generate-intent` (Mode B via `--kb`) and `mega-sdd:bind-codebase` as secondary ground truth. Triggers — "extract domain knowledge", "reverse engineer this legacy", "pecah legacy code jadi knowledge base", "rebuild di stack baru", "legacy intelligence", or paraphrases.
---

# Extract-Intelligence — Legacy Domain Knowledge Extractor

Tech-agnostic domain extractor for legacy codebases. Produces a multi-file knowledge base organized by **business domain**, not by code structure. Output describes WHAT the system does in tech-agnostic terms, not HOW the legacy stack implements it. Source-of-truth for rebuild planning on a different stack.

**Announce at start:** "I'm using the extract-intelligence skill to extract domain knowledge from the legacy codebase."

**Core principle:** Domain-first, not code-first. Tech-agnostic vocabulary. Citation-disciplined extraction. Wave-based parallel agents to manage token budget. Ambiguous → `[OPEN]`, never silent default.

## When to use

- Legacy codebase needs full rebuild on a different stack (not in-place migration).
- High-stakes domain (financial, regulatory, healthcare) — missing edges cost money.
- Architect needs "what does this system actually do" without reading 600+ source files.
- After `mega-sdd:scan-codebase` when rebuild is in scope — KB is richer than codebase-map for rebuild planning.
- User says variations of: "extract domain knowledge", "reverse engineer this", "pecah legacy code", "source of truth dari legacy code", "rebuild di stack baru".

**When NOT to use:**
- Direct code port to a newer version of the same stack → use migration tooling.
- Small codebases (<50 files) → just read them.
- Greenfield projects (no legacy).
- "What files are in this repo" → use `mega-sdd:scan-codebase` (lighter, faster, code-organized).

## Relationship to other mega-sdd skills

| Need | Skill | Why |
|---|---|---|
| Map files/modules in a brownfield repo | `mega-sdd:scan-codebase` | Heuristic catalog organized by code structure |
| Validate an SDD vault claim against existing code | `mega-sdd:bind-codebase` | Primary ground truth = codebase-map; KB consulted as secondary |
| Extract domain knowledge to rebuild elsewhere | **this skill** | Tech-agnostic, domain-organized, marker-disciplined |
| Convert brief/KB → intent vault | `mega-sdd:generate-intent` | Consumes this skill's KB via `--kb=<path>` |

**Typical chain:**
`extract-intelligence` → `generate-intent --kb=<kb>` → `generate-units` → `execute-bolts`

Naming: this is the mega-sdd-flavored counterpart to `superpowers:reverse-engineering-legacy-codebase`. The mega-sdd version produces a structured `.mega-sdd/knowledge-base/` that downstream mega-sdd skills explicitly consume. Use this version when the next step is mega-sdd unit/bolt generation.

## Inputs

- Legacy codebase path (positional, required)
- `--out=<path>` (output directory; default `.mega-sdd/knowledge-base/` per `plugins/mega-sdd/references/paths.md`)
- `--seed=<path>` (optional pre-existing forensic dump; moved to `_source/`)
- `--max-parallel=N` (subagent cap per wave; default 5, hard cap 8)
- `--auto` (skip per-wave confirmation prompts; quality-gate failures still halt)

## Output

Per `references/knowledge-base-schema.md` (read this file before generating any wave output):

```
{out}/
├── _source/                       # forensic seed cross-reference (optional)
└── knowledge-base/                # default; --out can override the parent path
    ├── README.md                  # nav + critical findings + OQ roll-up + stats
    ├── 00-overview/               # system-purpose, glossary, classification, actors-and-roles
    ├── 10-domains/                # 1 file per business domain (11-section template)
    ├── 20-workflows/              # cross-cutting workflows (state machines)
    ├── 30-data-model/             # conceptual ERD + entities
    ├── 40-business-rules/         # regulatory + operational + hidden gotchas
    ├── 50-integrations/           # external contracts (conceptual, not protocol)
    └── 99-rebuild-architecture/   # suggested-erd / system-flow / dependency-graph / phasing
```

Every domain file has YAML frontmatter (`generated_by: mega-sdd:extract-intelligence`, classification, criticality, verified/inferred/open counts, citation count). Consumed by `bind-codebase` as secondary ground truth.

## Wave-based execution

5 sequential waves with parallel subagents inside each wave. Read `references/wave-dispatch-templates.md` for the per-wave dispatch prompts and quality-gate grep commands.

| Wave | Output | Subagents | Why |
|---|---|---|---|
| **0 — Prep** | Skeleton dirs; move existing forensic dump to `_source/` | Main thread | Foundation |
| **1 — Foundation** | overview, glossary, classification, data-model, workflows | 3 parallel | Anchors for waves 2-4 |
| **2 — Masters** | Master entities, reference data, regulatory rules | 4 parallel | Low write volume; anchors workflows |
| **3 — Workflows** | Transactional workflows, ops rules, hidden gotchas | 5 parallel | Heaviest extraction wave |
| **4 — Integrations** | External system contracts, reporting/monitoring | 3 parallel | Wraps domain coverage |
| **5 — Synthesis** | ERD, system-flow, dependency-graph, phasing, README | Main thread | Needs holistic view across all wave outputs |

**Why wave-based:**
- Token budget control — never more than `--max-parallel` subagents in flight.
- Later waves cross-reference earlier outputs (glossary anchors every domain file).
- Quality gate between waves catches template / citation drift early.
- Wave 5 on main thread avoids subagent context loss — synthesis needs the whole map.

**Common timeout pitfall:** subagents reading >40 KB single files hit stream timeout. Mitigation: tighten Read scope with line ranges, prefer `Grep` for targeted patterns, fall back to synthesis-from-siblings (read other KB files instead of legacy source) for late waves.

## Extraction discipline (non-negotiable)

Every non-trivial claim carries TWO orthogonal axes — **confidence** (epistemic: how sure are we?) + **mutability** (decisional: how much freedom does rebuild have?). Both axes are mandatory.

### Axis 1 — Confidence markers (existing convention, also used by `bind-codebase`)

- `[VERIFIED]` — confirmed by multiple code paths OR an explicit doc.
- `[INFERRED]` — single source code path; needs confirmation.
- `[OPEN]` — unknown from code; needs domain expert. Propagates to vault as OQ when KB is consumed by `generate-intent`.

### Axis 2 — Mutability tiers (v1.4+, Iter 22)

Per user directive "code dan ERD bisa berubah, tapi goals reengineering nya terpenuhi, jika tidak ada ketentuan erd harus 1:1" — every claim is tagged with the freedom rebuild has to change it:

- `[LOCKED]` — **MUST be preserved 1:1 in rebuild**. Triggered by:
  - Regulatory citation (BI/OJK/SOX/HIPAA/PCI/GDPR specific field, calculation, retention rule)
  - Contractual integration spec (SWIFT MT format, partner API contract, audit-trail compliance)
  - Migration cost prohibitive (live production data with sensitive constraints — column rename breaks downstream)
  - Hard external dependency (FK referenced by external system out of scope)
- `[INTENT]` — **Business OUTCOME matters, implementation is FREE**. Default tier for most domain rules. Rebuild may redesign schema, refactor flow, swap algorithms — as long as the outcome (state transition, calculated value, business rule effect) is preserved.
- `[ARTIFACT]` — **Coincidental legacy implementation detail — free to DISCARD**. Triggered by:
  - Implementation accidents (e.g., field exists because legacy framework required it; not used by any business rule)
  - Workarounds for legacy stack limitations (denormalization for performance; flag columns for missing JOIN support; column-based polymorphism)
  - Dead code paths (referenced by zero callers; defunct workflow branches)

### Combined notation

Markers stack: `[VERIFIED][LOCKED]`, `[VERIFIED][INTENT]`, `[INFERRED][LOCKED]`, etc. Confidence comes first (epistemic) then mutability (decisional). When `[OPEN]`, mutability is `[?]` until the question is answered: `[OPEN][?]`.

Example claims:

> Customer NIP field is 8 numeric digits, validated by checksum algorithm `<spec link>`. `[VERIFIED][LOCKED]` — `(see §11.3)` — required by BI Regulation 23/2/2021 §4.

> Loan amount is denormalized into `application` and `disbursement` tables for read-performance. `[VERIFIED][ARTIFACT]` — `(see §11.7)` — rebuild may normalize via JOIN or projection.

> Approver matrix uses 7 hierarchy levels keyed by `approval_code`. `[VERIFIED][INTENT]` — `(see §11.4)` — outcome (correct authority routing) matters; representation (matrix vs role-based) is rebuild's choice.

### Default tier when uncertain

If a wave-2/3/4 agent can't classify with high confidence, default to `[INTENT]` (middle-ground, safest). Wave 5 synthesis re-reviews tier distribution and surfaces likely mis-classifications. Never default to `[LOCKED]` (would over-constrain rebuild) or `[ARTIFACT]` (would risk discarding business rule).

### Why this matters — KB role re-positioned

KB is no longer a "preserve-legacy spec". KB is an **analysis input** that produces a vault containing:
1. Business goals (immutable across rebuild)
2. Hard constraints (`[LOCKED]` rules from KB)
3. Recommended new shape (`99-rebuild-architecture/*` proposals — schema, flows, modules)
4. Discarded legacy detail (`[ARTIFACT]` items — listed but flagged as discardable)

The rebuild's job is to satisfy goals + locked constraints, not to mirror legacy verbatim.

**Citation required:** every non-trivial claim has a `file:line` reference in the file's `## 11. Source References` section. Inline claims may use a short `(see §11)` pointer if the citation is shared.

**Tech-agnostic vocabulary:** no language / framework / DB names in domain files except `## 11. Source References` and `50-integrations/`.
- ✓ "Customer entity (persisted in legacy as table `cifmast`)"
- ✗ "MySQL `cifmast` table"

**`.bak` / dated-file handling:** compare with live version, document discrepancies in `## 9. Edge Cases & Gotchas`. Don't assume `.bak` is older — sometimes it contains logic removed due to a regression.

**No fabrication:** ambiguous → `[OPEN]`. Never guess regulatory citations, never invent business rules from a single source.

**Citation required:** every non-trivial claim has a `file:line` reference in the file's `## 11. Source References` section. Inline claims may use a short `(see §11)` pointer if the citation is shared.

**Tech-agnostic vocabulary:** no language / framework / DB names in domain files except `## 11. Source References` and `50-integrations/`.
- ✓ "Customer entity (persisted in legacy as table `cifmast`)"
- ✗ "MySQL `cifmast` table"

**`.bak` / dated-file handling:** compare with live version, document discrepancies in `## 9. Edge Cases & Gotchas`. Don't assume `.bak` is older — sometimes it contains logic removed due to a regression.

**No fabrication:** ambiguous → `[OPEN]`. Never guess regulatory citations, never invent business rules from a single source.

## Quality gates between waves

After each wave, run the grep checks from `references/wave-dispatch-templates.md` §gate-checks:

- `^## 3\. Flow` exists in every new domain file
- `^## 10\. Open Questions` exists in every new domain file
- `^## 11\. Source References` exists in every new domain file
- Forbidden patterns (language/DB names, SQL strings) absent outside allowed sections
- Frontmatter present with required keys

If failures → re-dispatch the failing agent with specific feedback. Don't proceed to the next wave with broken outputs — they're inputs to the next wave's cross-references.

If the same gate fails twice for the same agent → halt with the gate output. User decides whether to re-scope, re-prompt, or abort.

## Synthesis wave (main thread only)

Wave 5 MUST be main thread, not a subagent — it needs holistic context across every wave's output:

1. **`suggested-erd.md`** — clean ERD (Mermaid). Document DEPARTURES from legacy (normalize denormalized tables, event-source mutable counters, fix typo bugs structurally). Apply Normalization Checklist (see `references/knowledge-base-schema.md` §ERD Quality Rails).
2. **`suggested-system-flow.md`** — service boundaries (logical, not framework-mandate). Anti-corruption layer pattern for integrations. Idempotency requirements. No framework prescription.
3. **`module-dependency-graph.md`** — DAG (Mermaid). Leaf-vs-trunk analysis. Critical-path estimate.
4. **`suggested-phasing.md`** — Phase 1/2/3 sprint plan with acceptance criteria per phase. Pre-milestone blocker list. Per-module acceptance template.
5. **`data-mutation-policy.md`** (v1.4+, Iter 22) — entity-by-entity table listing which tables/fields are `[LOCKED]` vs `[INTENT]` vs `[ARTIFACT]`. Drives ERD freedom in `generate-intent --kb` — without this file the consumer doesn't know what it's allowed to redesign.
6. **`README.md`** roll-up — navigation, **reengineering opportunities + critical findings surfaced first**, mutability tier distribution table, OQ roll-up grouped by phase blocker, stats, next steps.

## Bridge to rebuild + mega-sdd pipeline

After extraction, suggest one of:

1. **Manual rebuild planning** — use `99-rebuild-architecture/suggested-phasing.md` as the phase plan.
2. **Continue in mega-sdd pipeline** — run `/mega-sdd:generate-intent --kb=<knowledge-base-path>` to bootstrap a per-phase vault from the KB README + relevant domain files. From there: `generate-units` → `execute-bolts`.

If the rebuild lives in a different directory: copy `knowledge-base/` to the new project under `old-reference/`. Mark the distinction in the new project's CLAUDE.md:
- `old-reference/knowledge-base/` → REFERENCE liberally
- `old-reference/_source/` → legacy code dump, DON'T pattern-match

## Halt conditions

- Legacy codebase path missing or empty → halt; ask user for correct path.
- `--max-parallel` > 8 → halt; warn token budget collapse risk.
- Same wave's quality gate fails twice for the same agent → halt; surface the gate output verbatim.
- Wave 5 dispatched as a subagent → halt; config error, must be main thread.

## Path resolution (v1.3+, Iter 21 hotfix)

Per `plugins/mega-sdd/references/paths.md`. **No-excuse rule: ALL output defaults to `.mega-sdd/`** — back-compat to legacy `docs/knowledge-base/` triggers ONLY when legacy paths already exist on disk.

Resolution algorithm:

1. **User explicit `--out=<path>`** → always respected, overrides everything.
2. **Project config**: `<project-root>/.mega-sdd/config.yaml` → if `output_root: <path>` set, resolve `<out>` = `<output_root>/knowledge-base/`.
3. **Legacy back-compat detection**: ONLY if `<project-root>/docs/knowledge-base/` already exists with prior extraction (has `README.md` or any `00-overview/` content) → continue writing there to avoid split-brain.
4. **Default (new + fresh projects)**: `<project-root>/.mega-sdd/knowledge-base/`. Create the parent `.mega-sdd/` directory if absent. This is the path for ALL fresh extractions — chicken-and-egg detection from v1.2 is REMOVED.

**Read-side back-compat**: downstream `generate-intent --kb`, `bind-codebase --kb`, `orchestrate-flow` all probe in priority order — `.mega-sdd/knowledge-base/` first, then `docs/knowledge-base/`, then `docs/mega-sdd/knowledge-base/`, then `old-reference/knowledge-base/`. First hit wins.

## Hand-off

On completion, announce:

> "Knowledge base written to `<out>/knowledge-base/`. Critical findings: N. Open questions: N total (P1: …, P2: …, P3: …). Source citations: N. Next: review `<out>/knowledge-base/README.md`, then `/mega-sdd:generate-intent --kb=<out>/knowledge-base/` to bootstrap a vault."

## Handoff emission (v1.1+, Iter 4)

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML record at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`. The orchestrator parses this to decide auto-continue.

```yaml
handoff:
  emitted_by: extract-intelligence
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to .mega-sdd/knowledge-base/>
    - <absolute path to .mega-sdd/knowledge-base/README.md>
  next_action:
    suggested_skill: mega-sdd:generate-intent
    suggested_args: ["--kb=<absolute path to knowledge-base>", "--auto"]
    rationale: "Knowledge base extracted; generate vault using KB as Mode B brief."
  blockers: []
  metrics:
    items_processed: <N MD files written>
    items_blocked: 0
  scope:                                  # v3.20+ (Iter 28) — when target vault will have scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from PRD if available>
  mutability:                             # v3.17+ (Iter 25) — extract-intelligence is PRIMARY tier producer
    tier_distribution: { LOCKED: <N>, INTENT: <N>, ARTIFACT: <N> }
    locked_claims_touched: []
    artifact_discards_proposed: <N>
```

Status `halted` when quality gate fails twice (per `references/wave-dispatch-templates.md` §gate-checks). Required ONLY under `--auto`; standalone invocations may emit informationally.

## Real-world validation

Bank Mega Trade Finance legacy (~600 PHP files; MySQL + MSSQL + LDAP + SWIFT FTP):
- Input: 63.9 KB forensic seed doc
- Output: 35 MD files, ~968 KB, 13 business domains
- Findings beyond seed: actor-order error corrected, 41 hidden gotchas catalogued, 430 OQs surfaced, 4 critical do-not-replicate bugs, hidden MySQL UDF dependency, OFAC compliance gap
- Time: ~3 hours wall-clock for 15 agent dispatches across 5 waves
- Output usable immediately as Phase 1 acceptance criteria + per-module reference

## Common mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Single mega-doc dump | 1000+ line monolith, unsearchable | Multi-file by domain — this skill's output shape |
| Code-organized output | Files named after legacy folders | Reorganize by business domain |
| Tech-leaking | "Customer is a `cifmast` row" in a domain file | Use conceptual types; relegate physical to `## 11. Source References` |
| No citations | Claims with no `file:line` | Re-dispatch with discipline |
| Fabricated regulations | Invented POJK/PBI numbers | Mark `[INFERRED]` or `[OPEN]` |
| Skip `.bak` compare | Miss removed-then-needed logic | Diff against `.bak`/dated copies, document in Edge Cases |
| Wave 5 as subagent | Synthesis lacks holistic view | Always main-thread synthesis |
| No quality gate | Template drift propagates downstream | Grep gates after every wave |

## Cross-references

- `references/knowledge-base-schema.md` — output directory structure + per-domain 11-section template + frontmatter contract
- `references/wave-dispatch-templates.md` — per-wave subagent prompts + quality-gate grep commands
- `mega-sdd:generate-intent` — consumes KB via `--kb=<path>` as Mode B brief
- `mega-sdd:bind-codebase` — consults KB as secondary ground truth when codebase-map is silent
- `superpowers:subagent-driven-development` — pattern for the parallel agent dispatch this skill uses
- `superpowers:verification-before-completion` — pattern for the quality-gate grep checks
- `docs/superpowers/specs/2026-05-20-extract-intelligence-skill-design.md` — design spec this skill implements
