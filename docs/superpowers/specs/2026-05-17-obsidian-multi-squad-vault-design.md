# Obsidian-Friendly Vault + Multi-Squad Subagent Execution — Design

> **Status**: Draft — brainstorming approved 2026-05-17
> **Author**: Farhan ITEC (riuzakif@gmail.com)
> **Plugin**: mega-sdd (plugins/mega-sdd)
> **Target version**: v1.3 (additive, zero pipeline change)
> **Scope**: Obsidian polish + multi-squad dimension via Claude subagents

## TL;DR

Add multi-squad capability as a **dimension threaded through the existing 5-phase pipeline**, not as a parallel pipeline. The README flowchart stays intact. New behavior is concentrated in `execute-bolts` via a `--per-squad` flag that leverages the already-vendored `subagent-driven-development` skill — one Claude subagent per squad, each filtering units by their assigned squad while reading the same shared vault (anti-hallucination preserved). Plus lightweight Obsidian compatibility (wikilinks + frontmatter + tags) so architects can navigate the vault graphically. Zero new skills. One new flag, one new config file (`_meta/squads.yaml`), one new optional artifact type (interface notes), and frontmatter additions to existing prose templates.

## Design principles (from steering)

1. **Konsep terjaga** — README flowchart unchanged; 5-phase pipeline intact; anti-hallucination niche preserved
2. **Tidak overhaul** — additive only, no new pipeline phases, no new skills
3. **Simple namun powerful** — squad partition adds parallel-execution power for N teams without restructuring the plugin
4. **Subagent Claude support** — leverages existing `subagent-driven-development` (already vendored via `_vendored/`); `execute-bolts --per-squad` is the integration point
5. **Easier for IT architects + dev teams** — architect gets graph navigation in Obsidian; squads get clean filtered execution

## Existing pipeline (unchanged — for reference)

Per `README.md`:

```
PRD → generate-intent → vault → [OQ gate → resolve-oq] → [scan + bind-codebase if brownfield] → generate-units → execute-bolts → code
```

Side lifecycles: `diff-vault` (on PRD revision), `detect-drift` (code vs vault), `orchestrate-flow` (auto-router).

**Architect/Dev separation** (README): architect produces vault without repo; dev/AI runs scan/bind/units with read-only; AI agent ships bolts with write.

This spec **does not change any of the above**. It threads a `squad` dimension through the existing artifacts and adds one optional flag to `execute-bolts`.

## Motivation

- One PRD typically spans multiple dev squads (BE, FE, integrations — or feature-based squads). The current plugin treats units as a single pool and one execution stream.
- Claude's `subagent-driven-development` already enables parallel unit execution. By partitioning units by squad and letting `execute-bolts` spawn one subagent per squad, we gain a clean handoff model for both AI-parallel runs (one architect, Claude spawns N subagents) and human-parallel runs (dev team members each run `execute-bolts --squad=<their-squad>` on their own machine).
- IT architects want to navigate the vault in Obsidian and see relationships — current `.md` cross-refs do not render as clickable links and produce a near-empty graph.

## Non-goals

- New skill creation — keep total skill count flat; multi-squad is a `--flag` not a `:command`
- Splitting the vault into per-squad copies — single source of truth required for anti-hallucination
- Atomic-note decomposition (one note per entity/flow/ADR/OQ) — too heavy; not worth it for graph
- Hash-based staleness linting or auto-regeneration pipelines — no derived files = no problem to solve
- Renaming or restructuring the 7 prose docs — they stay exactly as they are today
- Generating a `delivery/squad-*/` folder structure — subagent context IS the delivery; on-disk filter happens at execute-time via `--squad` flag
- Auto-generating `_squads/*.md` MOC pages — defer to user; not required for pipeline

---

## Section 1 — File layout (additive only)

**Existing vault files (unchanged):**

```
docs/mega-sdd/vaults/<name>/
├── 00-index.md
├── 01-overview.md
├── 02-architecture.md
├── 03-data-model.md
├── 04-flows.md
├── 05-decisions.md
├── 06-constraints.md
├── vault.json
├── units/                          # existing
├── bolts/                          # existing
└── codebase-map.md                 # existing (brownfield only)
```

**New additions (opt-in via squad Q&A in `generate-intent`):**

```
docs/mega-sdd/vaults/<name>/
├── _meta/
│   └── squads.yaml                 # squad declarations + ownership rules
├── interfaces/                     # cross-squad contracts (only when ≥2 squads)
│   ├── api-leave-request-submit.md
│   ├── event-leave-approved.md
│   └── webhook-stripe-payment.md
└── .obsidian/
    └── graph.json                  # graph view template (optional polish)
```

**Single-squad or no-squad mode:**
- `_meta/squads.yaml` absent OR declares exactly 1 squad
- `interfaces/` not created (no cross-squad coupling possible)
- Units omit `squad:` field
- Plugin behavior 100% identical to current v1.2

---

## Section 2 — Obsidian frontmatter + wikilinks (cosmetic polish)

### Frontmatter on the 7 prose docs

Add minimal frontmatter to each existing prose template in `plugins/mega-sdd/skills/generate-intent/references/templates/`:

```yaml
---
type: prose
doc_id: 02-architecture
vault_version: v1.3
aliases: [Architecture, Arch]
tags: [vault/<project-slug>, doc/architecture]
---
```

- `aliases` powers Obsidian quick-find
- `tags` powers Obsidian tag panel and graph color groups
- No `sha256`, no `derived`, no `authoritative` — single source, nothing to lint

### Wikilinks for cross-refs

Convert existing markdown cross-refs in prose templates to Obsidian wikilink form:

**Before:**
```markdown
Working on web client → `02-architecture.md#web-frontend` + `04-flows.md#user-flows-web`.
```

**After:**
```markdown
Working on web client → [[02-architecture#Web Frontend]] + [[04-flows#User Flows (Web)]].
```

- Obsidian renders these as clickable links AND draws graph edges
- Non-Obsidian viewers see plain text — readable, links not broken
- AI consumers (`bind-codebase`, etc.) already use text search; either form is findable

Rule for template authors: internal vault cross-refs use wikilink form; external file refs (PRDs, customer-research PDFs) stay markdown form.

### `.obsidian/graph.json` (optional polish)

Shipped as part of `generate-intent` output. Static JSON with sensible defaults for color groups by tag (squad, type, status). User can edit or delete; nothing depends on it.

```json
{
  "colorGroups": [
    { "query": "tag:#squad/be", "color": "#3b82f6" },
    { "query": "tag:#squad/fe-web", "color": "#a855f7" },
    { "query": "tag:#type/interface", "color": "#22c55e" }
  ],
  "showOrphans": false
}
```

---

## Section 3 — Squad declaration (`_meta/squads.yaml`)

Single config file declaring squad partition. Authored interactively via `generate-intent` Q&A, or hand-edited later.

```yaml
project_shape: web-app             # web-app | mobile | backend-only | cli | library
partition_model: layer             # layer | feature | hybrid
squads:
  - id: squad-be
    label: "Backend Squad"
    owns_layers: [backend, data-model]
    owns_flow_prefixes: [F-B-, F-C-]
  - id: squad-fe-web
    label: "Frontend Web Squad"
    owns_layers: [web-frontend]
    owns_flow_prefixes: [F-U-]
  - id: squad-integrations
    label: "Integrations Squad"
    owns_layers: [integrations]
    owns_components: [stripe, slack, google-oauth]
```

### Partition models

- **layer-based** (default for `web-app`) — squad owns one or more layers from `02-architecture.md`
- **feature-based** — squad owns one or more feature tags (vault must tag flows/entities with feature names during intent)
- **hybrid** — feature wins over layer when both match a note

### `generate-intent` Q&A additions (after existing shape + mode questions)

1. "Berapa squad akan kerjakan project ini? (1 = single-squad mode, skip squad config)"
2. If ≥ 2: "Partition model — layer / feature / hybrid?"
3. Per squad: ask `id`, `label`, ownership rules
4. Write `_meta/squads.yaml`

Single-squad answer → skip all squad emission entirely. Plugin behaves identically to v1.2.

---

## Section 4 — Interface notes (cross-squad contracts)

Only relevant when `_meta/squads.yaml` has ≥ 2 squads.

### Rules

1. Every cross-squad coupling MUST go through an interface note
2. Schema is concrete (OpenAPI / JSON schema / DBML / event payload), not prose
3. One producer squad, N consumer squads
4. `status: locked` required before consumer-squad units can execute via `execute-bolts`

### Anatomy

```markdown
---
id: api-leave-request-submit
type: interface
interface_id: I-API-001
contract_kind: rest                # rest | graphql | rpc | event | webhook | schema
producer: squad-be
consumers: [squad-fe-web]
status: locked
version: v1.0
tags: [interface, "squad/be", "squad/fe-web"]
---

# I-API-001 — Submit Leave Request (REST)

> Producer: Backend Squad · Consumers: Frontend Web Squad
> Related flow: [[04-flows#F-U-001]]

## Contract

\`\`\`yaml
POST /api/v1/leave-requests
auth: bearer-token
request:
  body:
    leave_type_id: uuid
    start_date: date
    end_date: date
    note: string | null
response:
  201: { id: uuid, status: "pending" }
  400: validation errors
  409: balance insufficient
\`\`\`

## Definition of Done — producer (squad-be)

- [ ] Endpoint deployed, returns 201 with leave_request id
- [ ] Validation per AC-2 to AC-5 in [[04-flows#F-U-001]] step 3

## Definition of Done — consumer (squad-fe-web)

- [ ] Form submit calls endpoint with correct shape
- [ ] Handles 201/400/409 with appropriate UX

## Blocked by

- [[06-constraints#OQ-AR-4]] (wire protocol — REST assumed)
```

### Authoring

Interface notes are written **manually by the architect** (with optional AI assistance). `generate-units` does NOT auto-create them — it READS them and validates that every cross-squad unit dependency points to a `status: locked` interface.

---

## Section 5 — Unit frontmatter (squad field)

Existing unit schema in `plugins/mega-sdd/skills/generate-units/references/unit-schema.md` gains one optional field:

```yaml
---
unit_id: U-BE-014
squad: squad-be                                  # NEW — required when ≥2 squads
title: "Implement POST /api/v1/leave-requests endpoint"
target_files: [...]                              # existing
acceptance_test: "..."                           # existing
produces_interfaces: [api-leave-request-submit]  # NEW — only when multi-squad
consumes_interfaces: [event-user-authenticated]  # NEW — only when multi-squad
depends_on: [U-BE-001, U-BE-003]                 # SAME-SQUAD ONLY
priority: P1
---
```

### Validation added to `generate-units`

- ❌ Reject: `depends_on` references a unit with different `squad:` (force interface routing)
- ❌ Reject: `consumes_interfaces` references an interface with `status: draft`
- ❌ Reject: `produces_interfaces` references an interface absent from `interfaces/`
- ⚠️ Warn: flow without squad assignment (gap in `squads.yaml` ownership rules)

Single-squad mode: `squad:` is absent or `default`; cross-squad validations skipped.

---

## Section 6 — `execute-bolts --per-squad` (the subagent integration)

This is the **only behavior change to an existing skill** that touches runtime execution. Everything else is additive to artifacts.

### Existing capability (per README line 97)

> `execute-bolts` — Executes units via superpowers integration. TDD-first ... Optional `--parallel` via `subagent-driven-development`.

So `execute-bolts` already knows how to spawn subagents in parallel — that mechanism is reused.

### New flags

```bash
# spawn one subagent per declared squad, each filtering units by their squad
/mega-sdd:execute-bolts --per-squad

# run a single squad's units only (for human dev team handoff to local laptop)
/mega-sdd:execute-bolts --squad=squad-be

# existing flags unchanged
/mega-sdd:execute-bolts                     # single agent, all units
/mega-sdd:execute-bolts --parallel          # subagents per independent unit (existing)
/mega-sdd:execute-bolts U-BE-001            # specific unit (existing)
```

### Execution model: `--per-squad`

```
execute-bolts --per-squad
    │
    ├─ read _meta/squads.yaml → list squads
    ├─ for each squad in squads:
    │     │
    │     └─ Agent(
    │            subagent_type: "general-purpose",
    │            description: "Execute squad-be bolts",
    │            prompt: """
    │                You are executing bolts for squad-be.
    │                Read full vault at <path>.
    │                Filter units/ where squad == squad-be.
    │                For each unit, use mega-sdd:execute-bolts in TDD-first mode
    │                with superpowers:subagent-driven-development if --parallel.
    │                Honor interfaces/ contracts: only consume interfaces with
    │                status: locked. Halt if blocked by draft interface.
    │                Commit one bolt per unit. Report when done.
    │            """,
    │            run_in_background: true  # parallel across squads
    │        )
    │
    └─ wait for all subagents to report → consolidate bolt-report.md per squad
```

### Execution model: `--squad=<id>` (human handoff)

```
execute-bolts --squad=squad-fe-web
    │
    ├─ read _meta/squads.yaml → validate squad ID exists
    ├─ filter units/ where squad == squad-fe-web
    ├─ verify all consumes_interfaces are status: locked
    │     │ if any draft → halt with informative message naming the producer squad
    │     │
    └─ proceed with normal execute-bolts loop (TDD, subagent if --parallel, atomic commits)
```

### Halt protocol additions

Per README halt-protocol §8 list, add:
- `cross_squad_interface_draft` — `execute-bolts --squad=X` halts when a consumed interface is `status: draft`. Block until producer squad locks it.
- `cross_squad_dep_invalid` — `generate-units` halts when a unit's `depends_on` crosses squads (must route via interface).

---

## Section 7 — Niche protection (anti-hallucination guarantees)

The plugin's defining value is preserved by these invariants:

### N1 — Single vault, shared across all squads

Each squad subagent reads the **same vault**. There is no per-squad vault slice, no per-squad copy. This guarantees no two squads ever see contradictory specs.

### N2 — Cross-squad coupling forced through interface notes

Unit `depends_on` is intra-squad only. All cross-squad data flow goes through `interfaces/`. This makes coupling EXPLICIT and reviewable.

### N3 — Interface lock gate

Consumer-squad bolts cannot execute until producer-squad has locked the interface. Prevents AI dev tools on the consumer side from inventing missing contract details.

### N4 — Vault prose stays squad-agnostic

The 7 prose docs do not mention squad assignments. Squad ownership lives only in `_meta/squads.yaml` (a routing config, not a spec). Consequence: changing squad partition doesn't require rewriting prose — re-run `generate-units` and it re-assigns.

### N5 — Single-squad mode = current behavior

If no `squads.yaml` or one-squad squads.yaml: `generate-units` skips squad field; `execute-bolts` behaves as v1.2. Zero regression for existing projects.

---

## Section 8 — Skill changes (additive, minimal)

| Skill | Change | Risk |
|---|---|---|
| `generate-intent` | (1) Frontmatter + wikilinks in prose templates. (2) Squad Q&A → emit `_meta/squads.yaml`. (3) Emit `interfaces/_index.md` stub when ≥ 2 squads. (4) Emit `.obsidian/graph.json` template. | Low — additive only |
| `scan-codebase` | None | None |
| `bind-codebase` | None — prose unchanged structurally; wikilinks parse fine | None |
| `generate-units` | (1) Read `_meta/squads.yaml` if present. (2) Assign `squad:` to each unit per partition rules. (3) Validate intra-squad deps + interface-routed cross-squad. (4) Emit new halt artifact `cross_squad_dep_invalid`. | Medium — new validations |
| `execute-bolts` | (1) New flag `--per-squad` (spawn one subagent per squad via `subagent-driven-development`). (2) New flag `--squad=<id>` (filter units by squad). (3) New halt artifact `cross_squad_interface_draft`. | Medium — subagent fan-out logic; reuses existing parallel infra |
| `resolve-oq` | None | None |
| `detect-drift` | None | None |
| `diff-vault` | None for prose. When interfaces change in new PRD: secondary diff section listing affected consumer squads. | Low |
| `orchestrate-flow` | Detect multi-squad mode; suggest `execute-bolts --per-squad` (or single `--squad`) as next step | Low |

**No new skills.** Plugin's `skills/` directory count stays the same. README's "5-phase + 4 lifecycle" framing stays the same.

---

## Section 9 — Backward compatibility

### Existing v1.0–v1.2 vaults

- Work unchanged. Plugin reads them in single-squad mode (no `squads.yaml` = single squad).
- Upgrading is opt-in: re-run `generate-intent` on the PRD with new squad Q&A.
- No `upgrade-vault` skill, no forced migration.

### AI consumer skills

- `bind-codebase`, `resolve-oq`, `detect-drift`, `diff-vault`: zero behavior change for content reading. They never touch `squads.yaml` or `interfaces/`.
- `generate-units` + `execute-bolts`: read `squads.yaml` if present; default to single-squad otherwise.

### Existing units (from v1.x)

- Lack `squad:` field → treated as `squad: default` (single-squad mode)
- `execute-bolts` without `--per-squad` flag: behavior identical to v1.2

---

## Section 10 — Implementation plan (single phase)

1. **Update prose templates** in `plugins/mega-sdd/skills/generate-intent/references/templates/`:
   - Add frontmatter (`type`, `doc_id`, `vault_version`, `aliases`, `tags`)
   - Convert internal cross-refs to wikilinks
2. **Add squad Q&A** in `generate-intent` SKILL.md flow → emit `_meta/squads.yaml`
3. **Emit `interfaces/_index.md` stub + `.obsidian/graph.json`** in `generate-intent` when squads ≥ 2 (architect authors interface notes manually as needed)
4. **Update `generate-units`** SKILL.md + `references/unit-schema.md`:
   - Read `_meta/squads.yaml` if present
   - Assign `squad:` per partition rules
   - Validate intra-squad deps + interface refs
   - Emit `cross_squad_dep_invalid` halt artifact on violation
5. **Update `execute-bolts`** SKILL.md:
   - Add `--per-squad` flag (spawn one subagent per squad via existing `subagent-driven-development`)
   - Add `--squad=<id>` flag (filter units by squad)
   - Emit `cross_squad_interface_draft` halt artifact when consumed interface is draft
6. **Update `orchestrate-flow`**: detect multi-squad mode and suggest the right execute-bolts variant
7. **Tests** in `tests/`:
   - `tests/skill-triggering/`: add trigger fixtures for `--per-squad` and `--squad=` flags
   - `tests/integration/`: add multi-squad smoke fixture (TimeOff with 3 squads, 2 interfaces, 1 cross-squad dep enforced through interface)

---

## Section 11 — Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wikilinks confuse non-Obsidian readers | Low | Low | Plain text fallback; AI consumers use text search |
| Squad mis-routing (entity assigned wrong squad) | Medium | Medium | Deterministic routing rules in squads.yaml; `generate-units` warns on unrouted notes |
| Interface contract drift | Medium | High | Status field (locked/draft) + lock requirement before consumer bolts |
| Subagent context size (each subagent loads full vault) | Medium | Low | Vault is small (7 docs, ~50KB total typical); within context budget |
| Cross-squad halt creates deadlock (A waits B, B waits A) | Low | High | Architect explicitly designs interface graph during intent; circular interface deps should be rare and surfaceable via static check |
| Existing v1.x users surprised by Obsidian wikilinks | Low | Low | Documented in CHANGELOG + plugin README |

---

## Section 12 — Success criteria

- Existing v1.2 vaults work unchanged with v1.3 plugin (no regression)
- New v1.3 single-squad vault opens cleanly in Obsidian with clickable cross-refs and visible graph
- TimeOff multi-squad fixture (BE + FE + Integrations) executes via `/mega-sdd:execute-bolts --per-squad`, spawning 3 subagents in parallel, each committing only their squad's bolts
- Same TimeOff fixture supports `--squad=fe-web` from a different laptop, executing only FE units with no access to other squads' work-in-progress
- Cross-squad direct dependency in unit graph is rejected with `cross_squad_dep_invalid` halt artifact and clear remediation message
- Consuming a draft interface halts with `cross_squad_interface_draft`, naming the producer squad responsible
- README flowchart unchanged
- Plugin skill count unchanged (no new skills)
- AI consumer skills (`bind-codebase`, `resolve-oq`, `detect-drift`, `diff-vault`) behave identically across v1.2 and v1.3 single-squad vaults

---

## Open questions

> Captured for resolution before implementation. Not blocking spec sign-off.

- [ ] **OQ-DESIGN-1** [P2]: Should `_meta/squads.yaml` live inside `vault/<name>/` or at project root? (Lean: inside `vault/` for portability and one-vault-one-config invariant.)
- [ ] **OQ-DESIGN-2** [P2]: When a unit consumes an interface with `status: draft`, should `execute-bolts --squad=X` halt (block) or warn-and-continue? (Lean: halt by default; flag `--allow-draft-interfaces` to opt into warn mode for sketching.)
- [ ] **OQ-DESIGN-3** [P3]: How does `--per-squad` interact with `--parallel` (subagent per unit within squad)? Can both be combined? (Lean: yes — `--per-squad` is squad-level fan-out; each squad subagent then internally uses `--parallel` for its own units. Document the combined form.)
- [ ] **OQ-DESIGN-4** [P3]: Should `orchestrate-flow` auto-detect ≥ 2 squads and default to `--per-squad`, or always ask? (Lean: ask once with a default suggestion based on declared squad count.)

---

## Decision

**Approved direction (2026-05-17):**

- Multi-squad as a dimension threaded through the existing 5-phase pipeline — flowchart unchanged
- Squad partition declared in `_meta/squads.yaml`; units gain optional `squad:` field; cross-squad coupling forced through `interfaces/` notes
- Subagent integration via new `--per-squad` and `--squad=<id>` flags on `execute-bolts`, reusing the existing `subagent-driven-development` mechanism
- Obsidian polish: frontmatter + wikilinks in prose templates + `.obsidian/graph.json`
- Zero new skills, single-phase implementation, ~7 discrete tasks

Next step: invoke `superpowers:writing-plans` to produce a detailed implementation plan.
