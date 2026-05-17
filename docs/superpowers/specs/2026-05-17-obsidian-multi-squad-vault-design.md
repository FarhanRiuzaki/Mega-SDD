# Obsidian-Friendly Vault + Multi-Squad Delivery — Design

> **Status**: Draft — brainstorming approved 2026-05-17
> **Author**: Farhan ITEC (riuzakif@gmail.com)
> **Plugin**: mega-sdd (plugins/mega-sdd)
> **Target version**: v1.3 (incremental, not overhaul)
> **Scope**: Minimal Obsidian compatibility + multi-squad partition

## TL;DR

Add lightweight Obsidian compatibility (wikilinks, frontmatter, tags) to the existing 7-file vault format, and introduce a multi-squad partition model so one PRD can ship as N per-squad delivery bundles. Keep the plugin simple — no atomic-note explosion, no new derivation pipeline, no hash-based linting. The 7 prose docs stay authoritative and structurally unchanged; AI consumer skills behave identically. New value: clickable cross-refs in Obsidian, basic graph visibility, and per-squad handoff bundles for dev teams.

## Design principles (from steering)

1. **Tidak overhaul** — additive changes only, existing pipeline rhythm preserved
2. **Simple** — minimum new skills (one), minimum new file types
3. **Flawless** — no dual source of truth, no hallucination vector
4. **Ritme terjaga** — `generate-intent → bind → units → bolts` flow unchanged
5. **Easier for IT architects + dev teams** — that's the user outcome that matters

## Motivation

- IT architects want to navigate the vault in Obsidian and see relationships
- Dev teams (squads) want a self-contained package, not a shared monolithic spec they have to mentally slice
- One PRD typically spans multiple squads; the current plugin treats units as a single pool

## Non-goals

- Atomic-note decomposition (one note per entity/flow/ADR/OQ) — too heavy for the value gained
- Auto-regeneration pipeline or staleness linting — no derived files = no staleness problem
- Obsidian-specific features (Dataview blocks, Canvas) — lock-in risk
- Backward-incompatible breaking changes to existing v1.x vaults
- Renaming or restructuring the 7 prose docs

---

## Section 1 — File layout

**Existing 7 prose docs** (unchanged structure, additive enhancements):

```
vault/
├── 00-index.md
├── 01-overview.md
├── 02-architecture.md
├── 03-data-model.md
├── 04-flows.md
├── 05-decisions.md
└── 06-constraints.md
```

**New additions (multi-squad mode only):**

```
vault/
├── _meta/
│   └── squads.yaml                # squad declarations + ownership rules
├── interfaces/                    # cross-squad contracts (only when N ≥ 2)
│   ├── api-leave-request-submit.md
│   ├── event-leave-approved.md
│   └── webhook-stripe-payment.md
├── _squads/                       # one MOC per squad (Obsidian nav aid)
│   ├── squad-be.md
│   ├── squad-fe-web.md
│   └── squad-integrations.md
└── .obsidian/
    └── graph.json                 # graph view template (committed)
```

**Generated separately (outside `vault/`):**

```
units/                             # existing — now with squad field in frontmatter
delivery/                          # NEW — per-squad bundles
├── squad-be/
├── squad-fe-web/
└── squad-integrations/
```

### Single-squad / no-squad mode

If `_meta/squads.yaml` is absent OR declares exactly 1 squad:
- `interfaces/`, `_squads/`, `delivery/` are NOT generated
- Units omit `squad:` field or use `squad: default`
- Plugin behavior identical to current v1.x

---

## Section 2 — Frontmatter additions (7 prose docs)

Minimal frontmatter added to each prose doc. Currently the prose docs have no frontmatter at all.

```yaml
---
type: prose
doc_id: 02-architecture            # matches filename without extension
vault_version: v1.3
aliases: [Architecture, Arch]      # optional Obsidian aliases for quick search
tags: [vault/<project-slug>, doc/architecture]
---
```

`tags` enables Obsidian tag panel. `aliases` enables type-anything-find-it search.

**No `sha256`, no `derived`, no `authoritative`** — single source, no derivation, nothing to lint.

---

## Section 3 — Wikilinks in prose docs

Convert existing standard markdown cross-refs to Obsidian wikilinks.

**Before:**
```markdown
Working on web client → `02-architecture.md#web-frontend` + `04-flows.md#user-flows-web`.
```

**After:**
```markdown
Working on web client → [[02-architecture#Web Frontend]] + [[04-flows#User Flows (Web)]].
```

Notes:
- Obsidian renders `[[doc#heading]]` as a clickable link AND draws a graph edge between the two files
- Non-Obsidian readers see `[[02-architecture#Web Frontend]]` as plain text — readable, links not broken (no path resolution needed)
- AI consumers (`bind-codebase`, `generate-units`, etc.) already do text search; they find content equally well in either form
- Existing references like `` `[06-constraints.md]` `` in Open Questions become `[[06-constraints]]`

**Rule for `generate-intent` template update:** all internal cross-refs use wikilink form. External docs (PDFs, customer-research files) keep standard markdown form.

---

## Section 4 — `_meta/squads.yaml`

Single config file declaring squad partition. Hand-edited or generated via `generate-intent` Q&A.

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

- **layer-based** (default for `web-app`) — squad owns one or more architectural layers from `02-architecture.md`
- **feature-based** — squad owns one or more feature tags; vault must tag flows/entities with feature names
- **hybrid** — feature ownership takes precedence over layer ownership

### `generate-intent` Q&A additions

After existing project-shape + mode questions:

1. "Berapa squad akan kerjakan project ini? (1 = single-squad mode)"
2. If ≥ 2: "Partition model — layer / feature / hybrid?"
3. Per squad: ask `id`, `label`, ownership rules
4. Write `_meta/squads.yaml`

If user answers 1 → skip multi-squad emission entirely.

---

## Section 5 — Interface notes (cross-squad contracts)

Only emitted when `_meta/squads.yaml` declares ≥ 2 squads.

### Rules

1. Every cross-squad coupling MUST go through an interface note
2. Interface schema is concrete (OpenAPI / JSON schema / DBML / event payload), not prose
3. One producer squad, N consumer squads
4. Status `locked` is required before consumer bolts can execute

### Anatomy

```markdown
---
id: api-leave-request-submit
type: interface
interface_id: I-API-001
contract_kind: rest                # rest | graphql | rpc | event | webhook | schema
producer: squad-be
consumers: [squad-fe-web]
status: locked                     # locked | draft
version: v1.0
tags: [interface, "squad/be", "squad/fe-web"]
---

# I-API-001 — Submit Leave Request (REST)

> Producer: [[_squads/squad-be|Backend Squad]]
> Consumers: [[_squads/squad-fe-web|Frontend Web Squad]]
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

## Changelog

- v1.0 (2026-05-15): initial contract drafted
```

### Origin

Interface notes are authored by the architect (manual or with AI assistance). `generate-units` does NOT auto-generate them — it READS them and validates that every cross-squad unit dependency points to a locked interface.

---

## Section 6 — Unit schema (squad field)

Existing unit schema (`generate-units/references/unit-schema.md`) gains one field:

```yaml
---
unit_id: U-BE-014
squad: squad-be                          # NEW — required in multi-squad mode
title: "Implement POST /api/v1/leave-requests endpoint"
produces_interfaces: [api-leave-request-submit]    # NEW — interface refs
consumes_interfaces: [event-user-authenticated]    # NEW
depends_on: [U-BE-001, U-BE-003]         # SAME-SQUAD ONLY
priority: P1
---
```

### Validation in `generate-units`

- ❌ Reject: `depends_on` contains a unit with a different `squad:` (force interface routing)
- ❌ Reject: `consumes_interfaces` references an interface with `status: draft` or `status: open`
- ❌ Reject: `produces_interfaces` references an interface not present in `interfaces/`
- ⚠️ Warning: flow without squad assignment (gap in squads.yaml ownership rules)
- ✅ Allow: cross-squad coupling expressed via `consumes_interfaces` + `produces_interfaces` only

Single-squad mode: skip all squad validations (field optional or `squad: default`).

---

## Section 7 — Per-squad delivery bundle

New skill: `mega-sdd:export-squad-bundle`.

### Inputs

- 7 prose docs (committed)
- `_meta/squads.yaml`
- `interfaces/` (when multi-squad)
- `units/` (with `squad:` populated)

### Output (per declared squad)

```
delivery/squad-be/
├── README.md                            # squad scope + blocking OQs + cross-squad deps
├── vault/                               # COPY of vault/ (full 7 prose docs — small files)
│   ├── 00-index.md
│   ├── 01-overview.md
│   ├── ...
│   └── interfaces/                      # only interfaces where this squad is producer or consumer
├── units/                               # only units where squad = this squad
│   ├── U-BE-001-...md
│   └── ...
└── handoff-context.md                   # cheat sheet: cross-squad interface deps + status
```

**Note:** vault is COPIED in full (it's small — 7 markdown files), not sliced. Slicing prose docs would introduce content drift risk. Filtering happens at units + interfaces level only. Squad dev still gets the complete architectural picture.

### Routing logic (deterministic)

```python
for squad in squads.yaml:
    copy vault/ → delivery/{squad.id}/vault/
    filter interfaces:
        keep if producer == squad.id OR squad.id in consumers
    filter units:
        keep if unit.squad == squad.id
    write README.md (squad metadata + blocking OQs from vault prose)
    write handoff-context.md (cross-squad interface table with status)
```

No LLM in routing — pure filter + copy. Idempotent.

### `README.md` template

```markdown
# Squad BE — Delivery Bundle

> Generated 2026-05-17 from vault v1.3
> PRD source: PRD-Examples.pdf v1.0

## Scope

Squad BE owns the backend layer + data model. Accountable for:
- 12 units (see `units/`)
- 4 interfaces produced
- 2 interfaces consumed

## Cross-squad interface dependencies

| Interface | Producer | Status | Blocks your units |
|---|---|---|---|
| event-user-authenticated | squad-integrations | draft | YES — blocks U-BE-007 |

## Open Questions blocking you

Filtered from [[06-constraints]] where layer = backend OR data-model:
- [ ] OQ-AR-2 (P1) — backend tech stack TBD
- [ ] OQ-DM-1 (P1) — password specifics

⚠️ Cannot start U-BE-001 until OQ-AR-2 resolved.

## How to execute

\`\`\`
cd delivery/squad-be/
/mega-sdd:execute-bolts units/U-BE-001
\`\`\`
```

---

## Section 8 — Obsidian graph view

Ship `.obsidian/graph.json` template inside `vault/` (committed).

```json
{
  "colorGroups": [
    { "query": "tag:#squad/be", "color": "#3b82f6" },
    { "query": "tag:#squad/fe-web", "color": "#a855f7" },
    { "query": "tag:#squad/integrations", "color": "#f97316" },
    { "query": "tag:#type/interface", "color": "#22c55e" },
    { "query": "path:units/", "color": "#facc15" }
  ],
  "showOrphans": false,
  "showAttachments": false
}
```

### Expected graph node count (TimeOff example)

7 prose docs + ~6 interface notes + 3 squad MOC pages + ~30 units = **~46 nodes** with clear squad-colored clusters and green interface bridges. Useful for navigation, not overwhelming.

### `_squads/squad-be.md` MOC (plain markdown, no Dataview)

```markdown
---
type: index
squad: squad-be
tags: [squad/be]
---

# Squad BE — Map of Content

## Units assigned
- [[U-BE-001-tenant-bootstrap]]
- [[U-BE-002-user-model]]
- ...

## Interfaces produced
- [[api-leave-request-submit]] (locked)
- [[event-leave-approved]] (draft)

## Interfaces consumed
- [[event-user-authenticated]] (draft — BLOCKING)

## OQs blocking
- [[06-constraints#OQ-AR-2]] (P1)
- [[06-constraints#OQ-DM-1]] (P1)
```

Plain wikilinks. `_squads/*.md` are generated by `export-squad-bundle` alongside delivery bundles.

---

## Section 9 — Skill changes (incremental, additive)

| Skill | Change | Risk |
|---|---|---|
| `generate-intent` | (1) Add `tags`/`aliases` frontmatter to prose templates. (2) Convert cross-refs in templates to wikilinks. (3) Add squad Q&A → emit `_meta/squads.yaml`. (4) When ≥ 2 squads: emit `interfaces/` placeholder + `_squads/*.md` MOC stubs. | Low — additive |
| `scan-codebase` | None | None |
| `bind-codebase` | None — prose docs unchanged structurally; wikilinks parse same as standard refs | None |
| `generate-units` | Read `_meta/squads.yaml`; assign `squad:` to units; validate cross-squad deps go via interfaces; reject violations | Medium — new validation logic |
| `execute-bolts` | Optional `--squad <id>` filter flag; otherwise unchanged | Low — additive |
| `resolve-oq` | None — writes to prose docs as before | None |
| `detect-drift` | None | None |
| `diff-vault` | None for prose; if interfaces change, secondary diff section | Low |
| `orchestrate-flow` | Detect multi-squad mode; suggest `export-squad-bundle` after `generate-units` | Low |
| `export-squad-bundle` | **NEW skill** — deterministic copy + filter | New code, low complexity |

**One new skill only.** Everything else is additive edits to existing skills.

---

## Section 10 — Backward compatibility

### Existing v1.x vaults

- Work unchanged. Plugin reads them in single-squad mode (no `squads.yaml` = single squad).
- Users who want Obsidian graph + multi-squad: regenerate via `generate-intent` (new vault) OR manually add frontmatter + wikilinks (incremental).
- No forced migration path. No `upgrade-vault` skill needed.

### AI consumer skills

Zero behavioral change for content reading. The only new behavior is:
- `generate-units` reads new `_meta/squads.yaml` (if present)
- `generate-units` enforces new cross-squad-via-interface rule (if multi-squad)
- `export-squad-bundle` is new and opt-in

If `_meta/squads.yaml` absent → existing single-pool unit generation behavior.

---

## Section 11 — Implementation plan (single phase)

1. **Update prose templates** in `plugins/mega-sdd/skills/generate-intent/references/templates/`:
   - Add minimal frontmatter (`type`, `doc_id`, `vault_version`, `tags`, `aliases`)
   - Convert internal cross-refs to wikilinks
2. **Add squad Q&A** in `generate-intent` SKILL.md flow → emit `_meta/squads.yaml`
3. **Emit `interfaces/_index.md` stub** in `generate-intent` when squads ≥ 2 (architect authors interface notes manually; `_squads/*.md` MOCs are produced later by `export-squad-bundle` since they depend on unit assignments)
4. **Update `generate-units`**:
   - Read `_meta/squads.yaml` (if present)
   - Assign `squad:` to units per partition rules
   - Validate cross-squad-via-interface rule
5. **Add `export-squad-bundle` skill** in `plugins/mega-sdd/skills/export-squad-bundle/`:
   - SKILL.md + references/templates/ (README.md template, handoff-context.md template)
6. **Ship `.obsidian/graph.json`** as part of `generate-intent` output (committed to vault)
7. **Tests** (`tests/skill-triggering/`, `tests/integration/`): add multi-squad smoke fixture

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Wikilinks confuse non-Obsidian readers | Low | Low | Wikilinks remain human-readable; AI consumers find content via text search either way |
| Squad mis-routing (entity assigned wrong squad) | Medium | Medium | Deterministic routing rules in squads.yaml; validation pass surfaces unrouted notes as warnings |
| Interface contract drift | Medium | High | Status field (locked/draft) + lock requirement before consumer bolts execute |
| `_meta/squads.yaml` schema evolution | Low | Low | Versioned via `vault_version` field; future versions add fields, don't break |
| Existing v1.x users surprised by Obsidian wikilinks in new vaults | Low | Low | Documented in CHANGELOG + plugin README |

---

## Success criteria

- Existing v1.x vaults work unchanged with v1.3 plugin (no regression)
- New v1.3 single-squad vault opens cleanly in Obsidian with clickable cross-refs and visible graph
- TimeOff multi-squad fixture (BE + FE + Integrations) generates 3 `delivery/squad-*/` bundles, each containing only that squad's units + relevant interfaces, with handoff-context.md listing blocking cross-squad deps
- Cross-squad direct dependency in unit graph rejected with clear error message
- AI consumer skills (`bind-codebase`, `generate-units`, `resolve-oq`, `detect-drift`, `diff-vault`) behave identically across v1.x and v1.3 single-squad vaults
- Total new files in plugin: one new skill directory + template additions to existing skills

---

## Open Questions

> Captured for resolution before implementation. Not blocking for spec sign-off.

- [ ] **OQ-DESIGN-1** [P2]: Should `_meta/squads.yaml` live inside `vault/` or at project root? (Lean: inside `vault/` for portability with delivery bundles.)
- [ ] **OQ-DESIGN-2** [P2]: When a squad consumes an interface with `status: draft`, should `export-squad-bundle` warn or block? (Lean: warn — let architect decide.)
- [ ] **OQ-DESIGN-3** [P3]: Should `export-squad-bundle` copy or symlink `vault/` files? (Lean: copy for cross-platform safety incl. Windows.)
- [ ] **OQ-DESIGN-4** [P3]: How does this interact with `gsd-workstreams` (if user runs parallel workstreams + multi-squad simultaneously)? (Lean: out of scope; document interaction in later PR.)

---

## Decision

**Approved direction (2026-05-17):**

- Lightweight Obsidian compatibility: frontmatter + wikilinks + tags on existing 7 prose docs (no atomic decomposition)
- Multi-squad model as opt-in via `_meta/squads.yaml` (single-squad default = current behavior)
- One new skill (`export-squad-bundle`); other skills get minor additive edits
- Single-phase implementation, ~7 discrete tasks
- Zero new derivation pipelines, zero new linters, zero forced migration

Next step: invoke `superpowers:writing-plans` to produce a detailed implementation plan.
