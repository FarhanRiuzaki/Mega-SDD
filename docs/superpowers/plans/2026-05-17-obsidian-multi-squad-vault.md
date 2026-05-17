# Obsidian-Friendly Vault + Multi-Squad Subagent Execution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lightweight Obsidian compatibility (wikilinks + frontmatter + tags) to the existing 7-file vault format and introduce a multi-squad dimension that threads through the existing 5-phase pipeline. Multi-squad coupling is forced through explicit interface notes, and `execute-bolts` gains `--per-squad` and `--squad=<id>` flags that leverage the already-vendored `subagent-driven-development` skill to spawn one Claude subagent per squad.

**Architecture:** Pure additive. README flowchart unchanged. Zero new skills — multi-squad is a `--flag`, not a `:command`. Single source of truth (the vault) shared across all squad subagents (anti-hallucination invariant preserved). Squad assignment is a routing concern declared in `_meta/squads.yaml`, NOT a content concern (prose docs stay squad-agnostic).

**Tech Stack:** Markdown templates with YAML frontmatter, Obsidian wikilink syntax, YAML config (`_meta/squads.yaml`), existing skill-instruction format (SKILL.md + references/*.md). No new dependencies, no new tooling.

**Spec reference:** `docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md`

---

## File Structure

### Files to MODIFY

```
plugins/mega-sdd/skills/generate-intent/
├── SKILL.md                                              # Task 2, 3
└── references/
    └── templates/
        ├── 00-index.md                                   # Task 1 (frontmatter + wikilinks)
        ├── 01-overview.md                                # Task 1
        ├── 02-architecture.md                            # Task 1
        ├── 03-data-model.md                              # Task 1
        ├── 04-flows.md                                   # Task 1
        ├── 05-decisions.md                               # Task 1
        └── 06-constraints.md                             # Task 1

plugins/mega-sdd/skills/generate-units/
├── SKILL.md                                              # Task 5
└── references/
    └── unit-schema.md                                    # Task 4

plugins/mega-sdd/skills/execute-bolts/
├── SKILL.md                                              # Task 6
└── references/
    └── superpowers-bridge.md                             # Task 6

plugins/mega-sdd/skills/orchestrate-flow/
├── SKILL.md                                              # Task 7
└── references/
    └── routing-rules.md                                  # Task 7

plugins/mega-sdd/skills/generate-intent/references/
└── vault-contract.md                                     # Task 8 (add 2 halt types)
```

### Files to CREATE

```
plugins/mega-sdd/skills/generate-intent/references/templates/
├── squads.yaml.template                                  # Task 2
├── interface-note.template.md                            # Task 3
├── interfaces-index.template.md                          # Task 3
└── obsidian-graph.json.template                          # Task 3

plugins/mega-sdd/skills/generate-intent/references/
└── squad-partition.md                                    # Task 2 (partition routing rules)

plugins/mega-sdd/skills/execute-bolts/references/
└── squad-subagent.md                                     # Task 6 (subagent fan-out spec)

tests/skill-triggering/
├── (modify) generate-units.test.md                       # Task 9
├── (modify) execute-bolts.test.md                        # Task 9
└── (modify) orchestrate-flow.test.md                     # Task 9

tests/integration/
└── e2e-multi-squad.test.md                               # Task 10
```

### Files to BUMP (version)

```
plugins/mega-sdd/skills/generate-intent/SKILL.md          # 1.0.0 → 1.1.0
plugins/mega-sdd/skills/generate-units/SKILL.md           # 1.0.0 → 1.1.0
plugins/mega-sdd/skills/execute-bolts/SKILL.md            # 1.0.0 → 1.1.0
plugins/mega-sdd/skills/orchestrate-flow/SKILL.md         # 1.0.0 → 1.1.0
plugins/mega-sdd/.claude-plugin/plugin.json               # 1.2.0 → 1.3.0
.claude-plugin/marketplace.json                            # 1.2.0 → 1.3.0
CHANGELOG.md                                               # Task 11 (release notes)
```

---

## Task 1: Add Obsidian frontmatter + wikilinks to 7 prose templates

**Goal:** Make the existing 7 prose templates Obsidian-friendly without changing their structural content. Architects opening the vault in Obsidian see clickable cross-refs and a meaningful tag panel.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/00-index.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/01-overview.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/02-architecture.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/03-data-model.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/04-flows.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/05-decisions.md`
- Modify: `plugins/mega-sdd/skills/generate-intent/references/templates/06-constraints.md`

- [ ] **Step 1.1: Add frontmatter block to `00-index.md`**

Open `plugins/mega-sdd/skills/generate-intent/references/templates/00-index.md`. Insert this frontmatter as the very first content (before line 1 `# <Project Name> — Grand Design`):

```yaml
---
type: prose
doc_id: 00-index
vault_version: "{{VAULT_VERSION}}"
aliases: [Index, Vault Index, Grand Design Index]
tags: ["vault/{{PROJECT_SLUG}}", "doc/index"]
---

```

Note: `{{VAULT_VERSION}}` and `{{PROJECT_SLUG}}` are template placeholders that `generate-intent` fills at vault generation time. They stay as literal placeholders in the template file.

- [ ] **Step 1.2: Add frontmatter to `01-overview.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 01-overview
vault_version: "{{VAULT_VERSION}}"
aliases: [Overview, Product Overview]
tags: ["vault/{{PROJECT_SLUG}}", "doc/overview"]
---

```

- [ ] **Step 1.3: Add frontmatter to `02-architecture.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 02-architecture
vault_version: "{{VAULT_VERSION}}"
aliases: [Architecture, Arch, System Architecture]
tags: ["vault/{{PROJECT_SLUG}}", "doc/architecture"]
---

```

- [ ] **Step 1.4: Add frontmatter to `03-data-model.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 03-data-model
vault_version: "{{VAULT_VERSION}}"
aliases: [Data Model, DBML, Schema]
tags: ["vault/{{PROJECT_SLUG}}", "doc/data-model"]
---

```

- [ ] **Step 1.5: Add frontmatter to `04-flows.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 04-flows
vault_version: "{{VAULT_VERSION}}"
aliases: [Flows, User Flows, System Flows]
tags: ["vault/{{PROJECT_SLUG}}", "doc/flows"]
---

```

- [ ] **Step 1.6: Add frontmatter to `05-decisions.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 05-decisions
vault_version: "{{VAULT_VERSION}}"
aliases: [Decisions, ADRs, ADR Log]
tags: ["vault/{{PROJECT_SLUG}}", "doc/decisions"]
---

```

- [ ] **Step 1.7: Add frontmatter to `06-constraints.md`**

Insert at top:

```yaml
---
type: prose
doc_id: 06-constraints
vault_version: "{{VAULT_VERSION}}"
aliases: [Constraints, NFR, Non-Functional Requirements]
tags: ["vault/{{PROJECT_SLUG}}", "doc/constraints"]
---

```

- [ ] **Step 1.8: Convert internal cross-refs to wikilinks in `00-index.md`**

In `00-index.md`, find every cross-ref of the form `01-overview.md`, `02-architecture.md`, ... (with optional `#anchor`) and replace as follows:

| Find | Replace with |
|---|---|
| `` `01-overview.md` `` | `[[01-overview]]` |
| `` `02-architecture.md` `` | `[[02-architecture]]` |
| `` `02-architecture.md#web-frontend` `` | `[[02-architecture#Web Frontend]]` |
| `` `02-architecture.md#backend` `` | `[[02-architecture#Backend]]` |
| `` `02-architecture.md#integrations` `` | `[[02-architecture#Integrations]]` |
| `` `02-architecture.md#api-contracts` `` | `[[02-architecture#API Contracts]]` |
| `` `02-architecture.md#ui-components-patterns` `` | `[[02-architecture#UI Components Patterns]]` |
| `` `03-data-model.md` `` | `[[03-data-model]]` |
| `` `04-flows.md` `` | `[[04-flows]]` |
| `` `04-flows.md#user-flows-web` `` | `[[04-flows#User Flows (Web)]]` |
| `` `04-flows.md#backend--system-flows` `` | `[[04-flows#Backend & System Flows]]` |
| `` `04-flows.md#cross-cutting-flows` `` | `[[04-flows#Cross-Cutting Flows]]` |
| `` `05-decisions.md` `` | `[[05-decisions]]` |
| `` `06-constraints.md` `` | `[[06-constraints]]` |
| `` `06-constraints.md#design-system` `` | `[[06-constraints#Design System]]` |

Rule: only convert refs to the **7 prose docs in this same vault**. External file refs (PRD PDFs, customer-research files like `customer-research-2026-Q1.md`) keep their markdown form because they live outside the vault.

Also convert OQ doc citations of the form `` `[06-constraints.md]` `` (appearing at end of each OQ entry in the roll-up) to `[[06-constraints]]`. Same pattern for `[02-architecture.md]`, `[03-data-model.md]`, `[04-flows.md]`, `[05-decisions.md]`.

- [ ] **Step 1.9: Convert internal cross-refs to wikilinks in `01-overview.md` through `06-constraints.md`**

Apply the same find/replace table from Step 1.8 to each of the remaining 6 prose template files. Be careful to:
- NOT touch external file references (PRDs, attached PDFs)
- NOT touch code fences or inline code that happens to contain `.md`
- Preserve heading capitalization in the wikilink anchor (Obsidian is case-sensitive for headings)

- [ ] **Step 1.10: Manual smoke test — render in Obsidian (or visually inspect)**

If Obsidian is available locally: open `plugins/mega-sdd/skills/generate-intent/references/templates/` as a vault and verify:
- 7 prose docs appear with their `aliases` showing in the quick-switcher
- Wikilinks render as blue clickable text (not broken-link red)
- Graph view shows 7 nodes connected by their cross-refs

If Obsidian isn't available: grep-check that the templates parse:

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -l "^---$" plugins/mega-sdd/skills/generate-intent/references/templates/0*.md
```

Expected: all 7 files listed (frontmatter delimiters present).

```bash
grep -c "\[\[" plugins/mega-sdd/skills/generate-intent/references/templates/00-index.md
```

Expected: count > 10 (many wikilinks now in the index).

- [ ] **Step 1.11: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/templates/
git commit -m "$(cat <<'EOF'
feat(generate-intent): add Obsidian frontmatter + wikilinks to prose templates

Per spec §2 (Obsidian frontmatter + wikilinks). Existing 7 prose templates
gain minimal YAML frontmatter (type, doc_id, aliases, tags) and internal
cross-refs are converted to Obsidian wikilink syntax [[file#heading]].
External file refs and code blocks untouched.

Non-Obsidian readers see plain text; AI consumers use text search either way.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Squad declaration scaffolding — `squads.yaml.template` + partition rules ref

**Goal:** Provide the new `_meta/squads.yaml` template that `generate-intent` will emit (in multi-squad mode), and the routing-rules document that `generate-units` will consult.

**Files:**
- Create: `plugins/mega-sdd/skills/generate-intent/references/templates/squads.yaml.template`
- Create: `plugins/mega-sdd/skills/generate-intent/references/squad-partition.md`

- [ ] **Step 2.1: Create `squads.yaml.template`**

Write the file at `plugins/mega-sdd/skills/generate-intent/references/templates/squads.yaml.template`:

```yaml
# Squad partition declaration
# Generated by /mega-sdd:generate-intent. Hand-edit to refine.
# Single-squad project: keep only one entry under `squads:`.
#
# partition_model:
#   layer    — squads own architectural layers from 02-architecture.md
#   feature  — squads own feature tags (vault must tag flows/entities)
#   hybrid   — feature wins over layer when both match

project_shape: "{{PROJECT_SHAPE}}"        # web-app | mobile-app | api-only | multi-platform | data-pipeline | custom
partition_model: "{{PARTITION_MODEL}}"    # layer | feature | hybrid
squads:
  - id: "{{SQUAD_ID_1}}"                  # e.g., squad-be (lowercase kebab-case, prefix `squad-`)
    label: "{{SQUAD_LABEL_1}}"            # e.g., Backend Squad
    owns_layers: []                       # e.g., [backend, data-model]
    owns_flow_prefixes: []                # e.g., [F-B-, F-C-] — flows with these prefixes belong here
    owns_components: []                   # explicit named components from 02-architecture.md
    owns_feature_tags: []                 # feature tags (only used in partition_model: feature or hybrid)

# Add additional squads by repeating the block above.
# Validation rules:
#   - At least one squad must exist
#   - Squad IDs must be unique and match pattern: ^squad-[a-z0-9-]+$
#   - Two squads must NOT claim the same layer/component/feature_tag
#   - If partition_model: feature, every squad must declare owns_feature_tags
```

- [ ] **Step 2.2: Create `squad-partition.md` routing rules reference**

Write the file at `plugins/mega-sdd/skills/generate-intent/references/squad-partition.md`:

```markdown
# Squad Partition Rules

Defines how `_meta/squads.yaml` ownership rules route vault artifacts (entities, flows, ADRs, OQs, integrations) to squads. Consumed by `generate-units` when assigning the `squad:` field on each unit.

## Partition models

### Layer-based (`partition_model: layer`)

Default for `web-app` and most multi-component shapes.

Routing: a vault artifact's primary layer (from `02-architecture.md`) matches a squad's `owns_layers` list.

| Vault layer hint | Routes to squad with `owns_layers` containing |
|---|---|
| `backend`, `api`, `service` | `backend` |
| `web-frontend`, `web-client`, `ui` | `web-frontend` |
| `mobile`, `ios`, `android` | `mobile` |
| `data-model`, `database`, `schema` | `data-model` (often paired with backend) |
| `integrations`, `external`, `webhook` | `integrations` |
| `infra`, `devops`, `platform` | `infra` |

### Feature-based (`partition_model: feature`)

Each squad owns one or more feature tags. Vault MUST tag flows/entities with feature names during `generate-intent` (use `tags: [feature/auth, feature/billing]` in flow descriptions or entity headers).

Routing: artifact's feature tag matches a squad's `owns_feature_tags` list.

If an artifact has multiple feature tags, the first match in declaration order wins.

### Hybrid (`partition_model: hybrid`)

Priority: feature > layer.

Routing rule:
1. If artifact has a feature tag matching some squad's `owns_feature_tags` → route to that squad.
2. Else if artifact has a layer matching some squad's `owns_layers` → route to that squad.
3. Else: unrouted — emit warning at `generate-units` time.

## Routing precedence (within a partition model)

When multiple rules in the same squad match, precedence is:

1. `owns_components` (explicit named match) — highest precedence
2. `owns_flow_prefixes` (flow ID prefix match, e.g., `F-B-` for backend flows)
3. `owns_layers` (architectural layer match)
4. `owns_feature_tags` (feature tag match)

If two squads claim the same artifact via the same precedence level → halt at `generate-units` time with `cross_squad_ambiguous` (NOT silently pick one).

## Single-squad mode

If `squads.yaml` declares exactly one squad, or the file is absent:
- All units get `squad: default` (or omit the field)
- No interface notes required
- `generate-units` skips all cross-squad validations
- Plugin behavior matches v1.2

## Validation (performed by generate-units)

- Each squad ID matches `^squad-[a-z0-9-]+$`
- No two squads claim same `owns_layers` entry
- No two squads claim same `owns_components` entry
- No two squads claim same `owns_feature_tags` entry
- If `partition_model: feature`, every squad has non-empty `owns_feature_tags`
- All artifacts route to exactly one squad (warn on unrouted)
```

- [ ] **Step 2.3: Verify file syntax**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
cat plugins/mega-sdd/skills/generate-intent/references/templates/squads.yaml.template | head -5
cat plugins/mega-sdd/skills/generate-intent/references/squad-partition.md | head -10
```

Expected: clean output, no errors.

- [ ] **Step 2.4: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/templates/squads.yaml.template \
        plugins/mega-sdd/skills/generate-intent/references/squad-partition.md
git commit -m "$(cat <<'EOF'
feat(generate-intent): add squads.yaml template + partition routing rules

Per spec §3 (squad declaration). Provides the squads.yaml schema with
documentation of the three partition models (layer / feature / hybrid)
and a routing-rules reference (squad-partition.md) that generate-units
will consult when assigning squad: field to units.

Single-squad mode = absence of squads.yaml or single entry; preserves
v1.2 behavior identically.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §3

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Interface note + Obsidian graph templates

**Goal:** Provide template files for the new `interfaces/` folder content (cross-squad contracts) and the optional `.obsidian/graph.json` polish.

**Files:**
- Create: `plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md`
- Create: `plugins/mega-sdd/skills/generate-intent/references/templates/interfaces-index.template.md`
- Create: `plugins/mega-sdd/skills/generate-intent/references/templates/obsidian-graph.json.template`

- [ ] **Step 3.1: Create `interface-note.template.md`**

Write `plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md`:

```markdown
---
id: "{{INTERFACE_ID}}"                    # e.g., api-leave-request-submit (kebab-case)
type: interface
interface_id: "{{INTERFACE_NUMERIC_ID}}"  # e.g., I-API-001 (zero-padded, monotonic per kind)
contract_kind: "{{CONTRACT_KIND}}"        # rest | graphql | rpc | event | webhook | schema
producer: "{{PRODUCER_SQUAD_ID}}"         # one squad ID from squads.yaml
consumers: ["{{CONSUMER_SQUAD_ID_1}}"]    # list of squad IDs (one or more)
status: draft                              # draft | locked  — start as draft; lock after stakeholder review
version: "1.0"
locked_at: null                            # ISO8601 date when first locked; preserved across edits
related_flows: []                          # e.g., [[04-flows#F-U-001]]
related_entities: []                       # e.g., [[03-data-model#leave_request]]
tags: [interface, "squad/{{PRODUCER_SQUAD_SLUG}}"]
---

# {{INTERFACE_NUMERIC_ID}} — {{INTERFACE_TITLE}}

> **Producer:** {{PRODUCER_SQUAD_LABEL}}
> **Consumers:** {{CONSUMER_LIST}}
> **Status:** draft
> **Related:** {{RELATED_FLOWS_AND_ENTITIES}}

## Contract

<!-- Concrete schema below. Choose the right format for contract_kind:
     - rest      → YAML with HTTP method, path, request/response body
     - graphql   → GraphQL SDL fragment
     - rpc       → method signature + payload
     - event     → event name + payload JSON schema
     - webhook   → endpoint + headers + body schema
     - schema    → DBML excerpt or JSON Schema for shared data shape
-->

```yaml
# Example — REST endpoint contract:
POST /api/v1/<resource>
auth: bearer-token
request:
  body:
    field_1: <type>
    field_2: <type>
response:
  200: { ... }
  400: validation errors
  409: business-rule conflict
```

## Definition of Done — producer ({{PRODUCER_SQUAD_LABEL}})

- [ ] <verifiable criterion 1, references vault section>
- [ ] <criterion 2>

## Definition of Done — consumer (each consumer squad)

- [ ] <verifiable criterion 1 — how consumer detects "interface honored">
- [ ] <criterion 2>

## Blocked by

<list of [[06-constraints#OQ-XX-N]] references for OQs that must resolve
before this interface can move from draft → locked. Empty list = ready
to lock pending review.>

## Changelog

- v1.0 (YYYY-MM-DD): initial draft
```

- [ ] **Step 3.2: Create `interfaces-index.template.md`**

Write `plugins/mega-sdd/skills/generate-intent/references/templates/interfaces-index.template.md`:

```markdown
---
type: index
doc_id: interfaces-index
vault_version: "{{VAULT_VERSION}}"
aliases: [Interfaces Index, Cross-Squad Contracts]
tags: ["vault/{{PROJECT_SLUG}}", "doc/interfaces-index"]
---

# Cross-Squad Interfaces — Index

> Every cross-squad coupling MUST be represented by an interface note in this folder.
> Status `locked` is required before consumer-squad units can execute via
> `/mega-sdd:execute-bolts --squad=<consumer>`.

## Rules

1. One producer squad per interface; one or more consumer squads.
2. Schema is concrete (OpenAPI / GraphQL / DBML / event payload), not prose.
3. Status transitions: `draft` → `locked` (one-way; bump version to revise).
4. Each interface cites the vault flow + entities it implements.

## Interfaces in this vault

<!-- This list is hand-maintained or refreshed by an Obsidian Dataview / manual
     edit. Plugin does not auto-regenerate. -->

| ID | Title | Kind | Producer | Consumers | Status |
|----|-------|------|----------|-----------|--------|
| _none yet_ | — | — | — | — | — |

## How to author a new interface

1. Copy `interface-note.template.md` to this folder, renamed to `<kebab-id>.md`
2. Fill frontmatter (producer, consumers, kind, related_flows, related_entities)
3. Write the concrete schema in the `## Contract` section
4. Define DoD per side (producer + each consumer)
5. List blocking OQs (if any)
6. Append row to the table above

## Lock procedure

When stakeholders approve a draft interface:
1. Set `status: locked` in frontmatter
2. Set `locked_at: YYYY-MM-DD` (today)
3. Update this index table's Status column to `locked`
4. Re-run `/mega-sdd:execute-bolts --per-squad` to unblock consumer squads

## Anti-hallucination

- `execute-bolts` halts (`cross_squad_interface_draft`) if a unit `consumes_interfaces` something with `status: draft`
- `generate-units` halts (`cross_squad_dep_invalid`) if a unit's `depends_on` references a unit in a different squad (must route via interface instead)
```

- [ ] **Step 3.3: Create `obsidian-graph.json.template`**

Write `plugins/mega-sdd/skills/generate-intent/references/templates/obsidian-graph.json.template`:

```json
{
  "collapse-filter": true,
  "search": "",
  "showTags": true,
  "showAttachments": false,
  "hideUnresolved": false,
  "showOrphans": false,
  "collapse-color-groups": false,
  "colorGroups": [
    {
      "query": "tag:#type/interface",
      "color": { "a": 1, "rgb": 2280724 }
    },
    {
      "query": "tag:#doc/index",
      "color": { "a": 1, "rgb": 5651507 }
    },
    {
      "query": "path:units/",
      "color": { "a": 1, "rgb": 16441125 }
    }
  ],
  "collapse-display": true,
  "showArrow": true,
  "textFadeMultiplier": 0,
  "nodeSizeMultiplier": 1,
  "lineSizeMultiplier": 1,
  "collapse-forces": false,
  "centerStrength": 0.5,
  "repelStrength": 10,
  "linkStrength": 1,
  "linkDistance": 250,
  "scale": 0.5,
  "close": true
}
```

Note: this is a sensible default. Users can edit in Obsidian's Graph View settings; the file just provides a starting point. `generate-intent` will add additional `colorGroups` entries per declared squad at generation time (handled in Task 5).

- [ ] **Step 3.4: Verify all three template files exist**

```bash
ls plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md \
   plugins/mega-sdd/skills/generate-intent/references/templates/interfaces-index.template.md \
   plugins/mega-sdd/skills/generate-intent/references/templates/obsidian-graph.json.template
```

Expected: all three files listed.

- [ ] **Step 3.5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md \
        plugins/mega-sdd/skills/generate-intent/references/templates/interfaces-index.template.md \
        plugins/mega-sdd/skills/generate-intent/references/templates/obsidian-graph.json.template
git commit -m "$(cat <<'EOF'
feat(generate-intent): add interface note + obsidian graph templates

Per spec §4 (interface notes — cross-squad contracts) and §2 (Obsidian
polish). Three new templates:

- interface-note.template.md — schema for one cross-squad contract
- interfaces-index.template.md — _index.md emitted in interfaces/ folder
- obsidian-graph.json.template — color groups for graph view

Templates are placeholders consumed by generate-intent only when squads
yaml declares ≥2 squads.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §3 §4

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extend unit schema with squad + interfaces fields

**Goal:** Update `unit-schema.md` so `generate-units` knows about the new `squad:`, `produces_interfaces:`, and `consumes_interfaces:` frontmatter fields.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/references/unit-schema.md`

- [ ] **Step 4.1: Add new optional frontmatter fields to the schema block**

In `plugins/mega-sdd/skills/generate-units/references/unit-schema.md`, find the existing frontmatter block (lines 7-36, starts with `---` and ends with `---`):

Replace the block from `id: U-001` through `estimated_complexity: small` with:

```yaml
---
id: U-001                         # zero-padded, monotonic
title: <short imperative phrase>
vault_source: <vault-file:section>  # which vault section this unit derives from
squad: <squad-id>                  # OPTIONAL — required when ≥2 squads declared in _meta/squads.yaml
                                   # Format: squad-<kebab-case>. Omit or set to `default` for single-squad projects.
depends_on: []                     # list of unit IDs that must complete first
                                   # MUST be same-squad units only when multi-squad mode active.
                                   # Cross-squad coupling MUST route through `consumes_interfaces` (see below).
target_files:                      # exact files this unit MAY touch (whitelist)
  - path: src/api/auth.ts
    operation: modify              # create | modify | delete
  - path: tests/auth.test.ts
    operation: create
existing_interfaces:               # contracts that MUST be preserved (in-codebase interfaces)
  - file: src/types/user.ts
    symbol: User
    note: "do not change shape; add optional field if needed"
produces_interfaces: []            # OPTIONAL — list of vault interface IDs this unit produces
                                   # Refs the kebab-id from interfaces/<id>.md frontmatter.
                                   # Only meaningful in multi-squad mode.
consumes_interfaces: []            # OPTIONAL — list of vault interface IDs this unit depends on
                                   # `execute-bolts` halts (cross_squad_interface_draft) if any referenced
                                   # interface has status: draft.
acceptance_test:                   # how to verify the bolt succeeded
  - type: test                     # test | manual | lint | typecheck
    command: "npm test -- auth"
    expects: "passes"
  - type: manual
    desc: "Hit /login with valid creds, expect 200 + token"
superpowers_skills:                # which superpowers skills execute-bolts invokes
  - test-driven-development
  - subagent-driven-development
binding_refs:                      # binding manifest IDs this unit honors
  - C-001
  - OQ-012
estimated_complexity: small        # small | medium | large
---
```

- [ ] **Step 4.2: Add a new section "Multi-squad rules" after `## Atomicity rules`**

In `unit-schema.md`, find the line `## Atomicity rules` (around line 60). After the entire `## Atomicity rules` section ends (just before `## Dependency graph`), insert this new section:

```markdown
## Multi-squad rules (v1.1+)

Applies only when `_meta/squads.yaml` exists with ≥2 squads. Single-squad / no-squad-config vaults skip these rules.

- `squad:` field is REQUIRED on every unit. `generate-units` assigns based on `squad-partition.md` routing rules.
- `depends_on` MUST reference units with the SAME `squad:`. Cross-squad direct deps are rejected with `cross_squad_dep_invalid` halt.
- Cross-squad coupling MUST go through interface notes:
  - Producer side: declare `produces_interfaces: [<id>, ...]` listing every interface this unit creates/implements.
  - Consumer side: declare `consumes_interfaces: [<id>, ...]` listing every interface this unit reads/calls.
- Every entry in `produces_interfaces` and `consumes_interfaces` MUST exist as an `interfaces/<id>.md` file in the vault. Dangling references fail validation.
- A unit that `consumes_interfaces` a `status: draft` interface CAN be generated but CANNOT be executed: `execute-bolts` halts with `cross_squad_interface_draft` until the producer squad locks the interface.

## Interface reference resolution

When `generate-units` emits a unit with `consumes_interfaces: [api-leave-request-submit]`:
1. Verify `<vault>/interfaces/api-leave-request-submit.md` exists.
2. Read its frontmatter: `producer`, `status`.
3. Confirm `producer` squad ≠ the unit's `squad` (it's a CROSS-squad interface, not intra-squad).
4. Record the interface's status — `execute-bolts` reads this at execution time to decide halt vs run.
```

- [ ] **Step 4.3: Update the existing "Anti-hallucination rails" section**

Find the section `## Anti-hallucination rails` (near the bottom of the file). Append two new bullets at the end of the existing list:

```markdown
- (v1.1+) In multi-squad mode, `depends_on` MUST be intra-squad only. Cross-squad direct deps halt with `cross_squad_dep_invalid`.
- (v1.1+) `consumes_interfaces` entries MUST resolve to existing interface files; status field is read at bolt time to gate execution.
```

- [ ] **Step 4.4: Verify the file**

```bash
cd /Users/farhanriuzaki/Downloads/grand-design-spec
grep -c "^## " plugins/mega-sdd/skills/generate-units/references/unit-schema.md
```

Expected: count includes the new `## Multi-squad rules (v1.1+)` and `## Interface reference resolution` sections (was 7 headings, now 9).

```bash
grep -n "squad:" plugins/mega-sdd/skills/generate-units/references/unit-schema.md
```

Expected: appears in the frontmatter block and in the new multi-squad section.

- [ ] **Step 4.5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/references/unit-schema.md
git commit -m "$(cat <<'EOF'
feat(generate-units): extend unit schema with squad + interfaces fields

Per spec §5 (unit frontmatter). Adds optional fields:
- squad: <id>              required in multi-squad mode
- produces_interfaces: []  cross-squad outputs
- consumes_interfaces: []  cross-squad inputs

Adds two new sections to unit-schema.md:
- ## Multi-squad rules (v1.1+) — same-squad depends_on, interface-routed coupling
- ## Interface reference resolution — producer/status validation

Single-squad vaults ignore these fields entirely.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §5

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Update `generate-intent` SKILL.md — squad Q&A + emit new artifacts

**Goal:** Make `generate-intent` ask squad questions during Q&A, emit `_meta/squads.yaml` when ≥2 squads, and emit `interfaces/_index.md` + `.obsidian/graph.json` from templates.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/SKILL.md`

- [ ] **Step 5.1: Read the existing SKILL.md to understand its structure**

```bash
wc -l plugins/mega-sdd/skills/generate-intent/SKILL.md
grep -n "^## " plugins/mega-sdd/skills/generate-intent/SKILL.md | head -20
```

Expected: large file (54K), many sections. Identify where the Q&A flow is described (likely under "Procedure" or "Q&A" section).

- [ ] **Step 5.2: Bump version in frontmatter**

In the YAML frontmatter at the top of `plugins/mega-sdd/skills/generate-intent/SKILL.md`, change:

```yaml
version: 1.0.0
```

to:

```yaml
version: 1.1.0
```

(If the current version is different — check the file — bump the minor version by 1.)

- [ ] **Step 5.3: Add squad Q&A section to the skill instructions**

Locate the section in `generate-intent/SKILL.md` that describes the question flow (search for "Project shape" or "implementation mode" — those are the existing Q&A items the new ones go alongside).

After the existing question about project shape / implementation mode, insert this new sub-section. The exact location: search for a heading like `## Q&A flow`, `### Required questions`, or similar — append AFTER the existing "implementation mode" Q. If no such structured Q&A section exists, add a new section titled `## Squad partition Q&A (v1.1+)` after the existing project-shape Q.

```markdown
### Squad partition (v1.1+)

After project shape and implementation mode are decided, ask:

> **Q (squad count):** "How many development squads will work on this project?
> Single-squad (1) = current default; multi-squad (≥2) enables per-squad
> execution via `/mega-sdd:execute-bolts --per-squad` with one Claude
> subagent per squad."

If answer is `1`:
- Skip remaining squad questions
- Do NOT emit `_meta/squads.yaml`
- Do NOT emit `interfaces/` folder
- Set `multi_squad_mode: false` in `vault.json`

If answer is `≥2`:

> **Q (partition model):** "How should squads be partitioned?
>   1. layer-based  — each squad owns architectural layers from `02-architecture.md`
>      (e.g., Backend Squad, Frontend Squad, Integrations Squad)
>   2. feature-based — each squad owns one or more feature tags
>      (e.g., Auth Squad, Billing Squad, Leave-Mgmt Squad)
>   3. hybrid       — feature wins over layer when both match"

Then per squad (loop until user signals "done"):

> **Q (squad declaration):** "Declare a squad. Provide:
>   - id (format: squad-<kebab-case>, e.g., squad-be)
>   - label (display name, e.g., Backend Squad)
>   - ownership rules per the chosen partition model:
>     - layer: list of layer names from architecture (e.g., backend, data-model)
>     - feature: list of feature tags (e.g., auth, billing)
>     - hybrid: both"

Validate per `references/squad-partition.md`. If validation fails (duplicate
ownership, malformed id), re-ask the failed field only.

After all squads declared, emit `_meta/squads.yaml` from `references/templates/squads.yaml.template`, replacing `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and `{{SQUAD_*}}` placeholders with collected answers. Set `multi_squad_mode: true` in `vault.json`.
```

- [ ] **Step 5.4: Add multi-squad artifact emission to the procedure**

Find the section in `generate-intent/SKILL.md` that describes file emission (search for "Write the 7", "Emit vault", or the procedure step that lists what files get created). Add the following after the existing 7-file emission step:

```markdown
### Multi-squad artifact emission (v1.1+)

After emitting the 7 prose docs + `vault.json`, if `multi_squad_mode: true`:

1. **Emit `_meta/squads.yaml`** from `references/templates/squads.yaml.template`,
   substituting `{{PROJECT_SHAPE}}`, `{{PARTITION_MODEL}}`, and per-squad
   `{{SQUAD_ID_N}}`, `{{SQUAD_LABEL_N}}`, ownership lists.

2. **Emit `interfaces/_index.md`** from `references/templates/interfaces-index.template.md`,
   substituting `{{VAULT_VERSION}}` and `{{PROJECT_SLUG}}`. Do NOT emit any
   `interfaces/<id>.md` files — those are authored manually by the architect
   when cross-squad contracts emerge during design.

3. **Emit `.obsidian/graph.json`** from `references/templates/obsidian-graph.json.template`,
   then ADD per-squad `colorGroups` entries — one for each declared squad with
   a distinct color from this palette in order:
   - `squad-be` → `{ "a": 1, "rgb": 3911867 }`     (blue: #3b82f6)
   - `squad-fe-web` → `{ "a": 1, "rgb": 11048700 }` (purple: #a855f7)
   - `squad-integrations` → `{ "a": 1, "rgb": 16330027 }` (orange: #f97316)
   - additional squads → cycle through standard Obsidian palette

4. **Single-squad mode**: skip steps 1-3 above. Plugin behaves as v1.0.

After emission, suggest next step per the existing hand-off message but
include squad count: "Generated vault for N squads. Next: …".
```

- [ ] **Step 5.5: Update the "Outputs" section to list new files**

Find the section in `generate-intent/SKILL.md` that lists outputs (search for "Outputs" or "Produces"). Append:

```markdown
**Additional outputs in multi-squad mode (≥2 squads):**
- `_meta/squads.yaml` — squad partition declaration
- `interfaces/_index.md` — cross-squad contract index (stub; architect authors actual contracts)
- `.obsidian/graph.json` — Obsidian graph view defaults with squad color groups
```

- [ ] **Step 5.6: Run skill triggering test manually**

Walk through `tests/skill-triggering/generate-intent.test.md` mentally with the new Q&A:
- Existing triggers should still fire (no change to description field)
- New behavior: when user answers `≥2` to squad count, the squad Q&A loop kicks in

```bash
cat tests/skill-triggering/generate-intent.test.md | head -30
```

Expected: trigger fixtures focus on "Trigger cases" + "Behavior" — none should break since they don't exercise squad Q&A. Adjustments come in Task 9.

- [ ] **Step 5.7: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/SKILL.md
git commit -m "$(cat <<'EOF'
feat(generate-intent): v1.1 squad Q&A + multi-squad artifact emission

Per spec §3 §4. After project shape + implementation mode Q&A, asks:
1. How many squads? (1 = single-squad mode, ≥2 enables multi-squad)
2. If ≥2: partition model (layer / feature / hybrid)
3. Per squad: id, label, ownership rules

When ≥2 squads, emits:
- _meta/squads.yaml (from template)
- interfaces/_index.md (architect authors actual contracts manually)
- .obsidian/graph.json (with per-squad color groups)

Single-squad mode = current v1.0 behavior, zero regression.

Skill version bumped 1.0.0 → 1.1.0.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §3 §4

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update `generate-units` SKILL.md — read squads.yaml + validate

**Goal:** Make `generate-units` read `_meta/squads.yaml`, assign `squad:` field per partition rules, validate intra-squad-only `depends_on`, validate `consumes_interfaces` / `produces_interfaces` references resolve, and emit `cross_squad_dep_invalid` halt artifact on violations.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-units/SKILL.md`

- [ ] **Step 6.1: Bump version in frontmatter**

In `plugins/mega-sdd/skills/generate-units/SKILL.md`, change `version: 1.0.0` to `version: 1.1.0`.

- [ ] **Step 6.2: Add a new step to the Procedure section**

Find the `## Procedure` section (lines 28-83 in the existing file). Insert this new step BEFORE the existing "5. Allocate IDs" step (so it becomes step 5; existing 5-11 shift to 6-12):

```markdown
5. **Squad assignment (v1.1+).** Load `_meta/squads.yaml` if present.

   **If file absent OR single squad declared:**
   - Single-squad / no-squad mode active
   - All units get `squad: default` (or field omitted)
   - Skip all multi-squad validations below

   **If ≥2 squads declared:**
   - Per `references/squad-partition.md` routing rules, assign `squad:` to each
     unit based on its `vault_source` and the relevant layer/feature tags.
   - For each candidate unit:
     - Determine primary layer from its `vault_source` (e.g., a unit derived
       from `02-architecture.md#backend` → layer `backend`)
     - Match against squad ownership rules with precedence:
       `owns_components` > `owns_flow_prefixes` > `owns_layers` > `owns_feature_tags`
     - Set `squad: <matched-id>`
   - **Unrouted units**: emit warning (not halt) and assign `squad: default` so
     execution can proceed. User should refine `squads.yaml` and re-run.
   - **Ambiguous routing** (two squads claim same artifact at same precedence
     level): halt with `cross_squad_ambiguous` (see §halt-protocol additions).
```

- [ ] **Step 6.3: Add cross-squad dependency validation to the procedure**

In the same `## Procedure` section, find the existing step "4. Resolve dependency graph" (which now becomes step 4 still, just before the new squad-assignment step we added). After its existing "Reject cycles" sub-bullet, add a new sub-bullet:

Original text:
```markdown
4. **Resolve dependency graph.**
   - Build DAG from semantic deps (entity before flow that uses it, schema migration before code that depends on column)
   - **Reject cycles.** If detected, halt and instruct user to restructure vault sections.
```

Replace with:

```markdown
4. **Resolve dependency graph.**
   - Build DAG from semantic deps (entity before flow that uses it, schema migration before code that depends on column)
   - **Reject cycles.** If detected, halt and instruct user to restructure vault sections.
   - **(v1.1+) Reject cross-squad direct deps in multi-squad mode.** After Step 5
     (squad assignment) completes, walk every `depends_on` edge and verify both
     endpoints have the same `squad:`. If a `depends_on` edge crosses squads,
     halt with `cross_squad_dep_invalid` (see §halt-protocol).
   - **(v1.1+) Validate interface references.** For each unit with
     `consumes_interfaces` or `produces_interfaces`, verify each listed
     interface ID resolves to an existing `<vault>/interfaces/<id>.md` file.
     Dangling references halt with `interface_ref_missing`.
```

- [ ] **Step 6.4: Add the new halt protocol YAML blocks**

Find the existing "Structured halt per `vault-contract.md §halt-protocol`" block (lines 43-53 of the original file, the `cycle_detected` example). After that block, add three new halt blocks:

```markdown
**Structured halt per `vault-contract.md §halt-protocol` (v1.1+):**

```yaml
blocker:
  type: cross_squad_dep_invalid
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    dependency_id: U-YYY
    dependency_squad: squad-be
  next_action: "Cross-squad direct depends_on is not allowed. Route the coupling through an interface note: producer squad declares produces_interfaces, consumer squad declares consumes_interfaces. See interfaces/_index.md."
```

```yaml
blocker:
  type: interface_ref_missing
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    unit_id: U-XXX
    missing_interface_id: api-leave-request-submit
    referenced_in: consumes_interfaces
  next_action: "Create interfaces/api-leave-request-submit.md from interface-note.template.md, fill the contract, and re-run generate-units."
```

```yaml
blocker:
  type: cross_squad_ambiguous
  emitted_at: <ISO8601 timestamp>
  emitted_by: generate-units
  details:
    artifact: F-U-007
    artifact_kind: flow
    claimed_by_squads: [squad-fe-web, squad-mobile]
    matched_via: owns_layers
  next_action: "Two squads claim ownership at the same precedence level. Refine _meta/squads.yaml so exactly one squad matches this artifact, then re-run generate-units."
```

- [ ] **Step 6.5: Update the "Halt conditions" list**

Find the section `## Halt conditions` (around line 92). Append three new bullets:

```markdown
- (v1.1+) Cross-squad direct dependency in `depends_on` → halt, route via interface
- (v1.1+) `consumes_interfaces` or `produces_interfaces` references missing file → halt, author interface first
- (v1.1+) Two squads claim same artifact at same precedence level → halt, refine squads.yaml
```

- [ ] **Step 6.6: Update the "Anti-hallucination rails" list**

Find the section `## Anti-hallucination rails` (around line 84). Append:

```markdown
- (v1.1+) `depends_on` is intra-squad only; cross-squad coupling MUST route through interface notes.
- (v1.1+) Interface references resolve to existing files; no fabricated interface IDs.
```

- [ ] **Step 6.7: Verify SKILL.md updated correctly**

```bash
grep -c "v1.1" plugins/mega-sdd/skills/generate-units/SKILL.md
```

Expected: count ≥ 5 (version field + procedure additions + halt types + anti-hallucination rails).

```bash
grep -n "cross_squad_dep_invalid\|interface_ref_missing\|cross_squad_ambiguous" plugins/mega-sdd/skills/generate-units/SKILL.md
```

Expected: each halt type appears at least once.

- [ ] **Step 6.8: Commit**

```bash
git add plugins/mega-sdd/skills/generate-units/SKILL.md
git commit -m "$(cat <<'EOF'
feat(generate-units): v1.1 squad assignment + cross-squad validation

Per spec §5 §7. New behavior in multi-squad mode (≥2 squads in squads.yaml):

- Step 5 (NEW): assign squad: to each unit per squad-partition.md routing
- Step 4 (extended): reject cross-squad depends_on edges
- Step 4 (extended): validate consumes_interfaces / produces_interfaces references resolve

Three new halt types emit structured blocker YAML:
- cross_squad_dep_invalid    direct cross-squad depends_on rejected
- interface_ref_missing      dangling interface ID reference
- cross_squad_ambiguous      two squads claim same artifact

Single-squad / no-squad mode unchanged (all validations skipped).

Skill version bumped 1.0.0 → 1.1.0.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §5 §7

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add `--per-squad` and `--squad=<id>` to `execute-bolts`

**Goal:** Add the two new flags to `execute-bolts` that leverage `subagent-driven-development` to spawn one Claude subagent per squad, or filter units to one squad for human-team handoff.

**Files:**
- Modify: `plugins/mega-sdd/skills/execute-bolts/SKILL.md`
- Modify: `plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md`
- Create: `plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md`

- [ ] **Step 7.1: Bump version in frontmatter**

In `plugins/mega-sdd/skills/execute-bolts/SKILL.md`, change `version: 1.0.0` to `version: 1.1.0`.

- [ ] **Step 7.2: Add new flags to the Inputs section**

Find the `## Inputs` section in `execute-bolts/SKILL.md`. Locate the bullet list under "Flags". Append two new flag entries:

```markdown
  - `--per-squad` — (v1.1+) fan out across all squads declared in `_meta/squads.yaml`. Spawns one Claude subagent per squad via `subagent-driven-development`; each subagent filters units by their `squad:` field and runs in parallel.
  - `--squad=<id>` — (v1.1+) filter units to a single squad. For human-team handoff: a dev team runs this on their own laptop to process only their squad's units. Halts on `cross_squad_interface_draft` if any consumed interface is still draft.
```

- [ ] **Step 7.3: Add a new Procedure variant for `--per-squad`**

Find the `## Procedure (per unit)` and `For --all:` sections. After the `For --all:` block, append:

```markdown
For `--per-squad` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent or single-squad → halt with informative message: "`--per-squad` requires ≥2 squads declared in `_meta/squads.yaml`. Run `/mega-sdd:generate-intent` to add squad config, or use plain `/mega-sdd:execute-bolts --all` for single-squad."
2. **Read squad list.** Build a list of squad IDs declared.
3. **For each squad, dispatch a Claude subagent** per `references/squad-subagent.md`. Subagents run in parallel via `Agent(run_in_background: true)`.
4. **Wait for all subagents** to complete or halt. Each subagent reports back its bolt-report list + halt status.
5. **Consolidate report.** Aggregate per-squad summaries into a single chat message: N squads, M units total, K commits, list of halts (with squad attribution).

For `--squad=<id>` (v1.1+):

1. **Load `_meta/squads.yaml`.** If absent → halt: "`--squad=` requires `_meta/squads.yaml`. This flag is only valid in multi-squad mode."
2. **Validate `<id>` exists** in declared squads. If not → halt with list of valid IDs.
3. **Filter units.** Build the working set = units where `squad: <id>` matches.
4. **Verify consumed interfaces lockable.** For each unit in the working set, read `consumes_interfaces`. For each listed interface, read its frontmatter `status`. If ANY status is `draft` → halt with `cross_squad_interface_draft`.
5. **Proceed with normal sequential or `--parallel` execution** on the filtered working set.
```

- [ ] **Step 7.4: Add the new halt type to the halt protocol section**

Find the existing halt-protocol YAML blocks in `execute-bolts/SKILL.md` (around line 75-104). After the `test_fail` block, add:

```markdown
**Structured halt per `vault-contract.md §halt-protocol` (v1.1+):**

```yaml
blocker:
  type: cross_squad_interface_draft
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    unit_squad: squad-fe-web
    consumed_interface_id: api-leave-request-submit
    producer_squad: squad-be
    interface_status: draft
  next_action: "Producer squad must lock the interface before consumer bolts can execute. Edit interfaces/<id>.md frontmatter: status: locked, locked_at: YYYY-MM-DD. Re-run execute-bolts."
```

- [ ] **Step 7.5: Add subagent fan-out reference**

Create `plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md`:

```markdown
# Squad Subagent Fan-Out

Specifies how `execute-bolts --per-squad` spawns one Claude subagent per declared squad and consolidates their results.

## When this applies

- Flag `--per-squad` is set on `execute-bolts`
- `_meta/squads.yaml` exists with ≥2 squads

## Subagent dispatch

For each squad declared in `_meta/squads.yaml`, dispatch ONE subagent via the
Agent tool. Subagents run in parallel via `run_in_background: true` so all
squads work concurrently.

### Per-subagent invocation

```
Agent(
  subagent_type: "general-purpose",
  description: "Execute <squad-label> bolts",
  run_in_background: true,
  prompt: """
    You are executing mega-sdd bolts for ONE squad: <SQUAD_ID> (<SQUAD_LABEL>).

    Context:
    - Vault path: <ABSOLUTE_VAULT_PATH>
    - Squad config: <ABSOLUTE_VAULT_PATH>/_meta/squads.yaml
    - Your squad's units: filter <ABSOLUTE_VAULT_PATH>/units/U-*.md where
      `squad: <SQUAD_ID>` in the frontmatter.
    - Interfaces you produce: filter <ABSOLUTE_VAULT_PATH>/interfaces/*.md
      where `producer: <SQUAD_ID>`.
    - Interfaces you consume: filter where `consumers:` array contains `<SQUAD_ID>`.

    Your job:
    1. Load all units assigned to your squad.
    2. For each unit with `consumes_interfaces`, verify each interface has
       `status: locked`. If any are `draft`, HALT with cross_squad_interface_draft
       blocker and stop — do not proceed.
    3. Execute units sequentially in topological order of their `depends_on`
       (all deps are intra-squad by validation).
    4. Use the mega-sdd:execute-bolts skill (this same skill) recursively for
       each unit, but with a single unit ID argument (NOT --per-squad), and
       follow the existing TDD-first procedure with superpowers integration.
    5. Commit each bolt atomically per the existing protocol.
    6. Write bolt-report.md per unit.
    7. Report back when done: { squad: <id>, units_run: N, commits: M, halts: [...] }

    Anti-hallucination rules from the existing execute-bolts SKILL.md still
    apply verbatim (target_files whitelist, no --no-verify, etc.). The vault
    is shared single source of truth — do NOT modify any vault file (only
    units/<your-squad>/U-*.md frontmatter status fields are touchable by you).

    Halt protocol: emit standard blocker YAML if you must stop. Parent will
    consolidate halts from all squads.
  """
)
```

### Parent consolidation

After all subagents complete (or halt), the parent process:

1. Collects per-squad results
2. Builds a single summary table:

   ```
   Squad             Units run   Commits   Status
   ─────────────────────────────────────────────
   squad-be            12          12      OK
   squad-fe-web         8           7      HALT (test_fail on U-FE-005)
   squad-integrations   4           4      OK
   ─────────────────────────────────────────────
   Total:              24          23      1 halt
   ```

3. Lists each blocker verbatim
4. Surfaces to user for resolution

## Why fan out at squad level (not unit level)

The existing `--parallel` flag already fans out independent units within
a single execution stream via `subagent-driven-development`. `--per-squad`
adds a second layer: each squad runs its own parallel-units stream
inside its own subagent.

Combined: `--per-squad --parallel` → N squad subagents, each running
multiple unit subagents internally. Resource usage scales accordingly;
suitable for moderate-size projects (3-5 squads × 10-20 units each).

## Failure isolation

If one squad's subagent halts, others continue (run_in_background means
they don't share execution state). Each writes its own bolt-reports and
halt artifacts. Parent aggregates after all complete.

## Single-squad fallback

If user passes `--per-squad` but only one squad is declared: halt early
(per Procedure step 1 in SKILL.md). Don't spawn a single subagent for
no benefit — defer to plain `--all` or `--parallel`.
```

- [ ] **Step 7.6: Reference the new file from `superpowers-bridge.md`**

In `plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md`, find the section that maps unit → superpowers skills (around line 23-33). After the existing table, add:

```markdown
## Squad-level fan-out (v1.1+)

When `execute-bolts --per-squad` is invoked, fan-out happens at the squad
level BEFORE the per-unit skill mapping above. See
`references/squad-subagent.md` for the dispatch protocol. Each squad's
subagent then independently follows the per-unit flow described in this
document.
```

- [ ] **Step 7.7: Verify the changes**

```bash
grep -c "per-squad\|cross_squad_interface_draft\|squad-subagent" plugins/mega-sdd/skills/execute-bolts/SKILL.md
```

Expected: count ≥ 5.

```bash
ls plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md
```

Expected: file exists.

- [ ] **Step 7.8: Commit**

```bash
git add plugins/mega-sdd/skills/execute-bolts/SKILL.md \
        plugins/mega-sdd/skills/execute-bolts/references/superpowers-bridge.md \
        plugins/mega-sdd/skills/execute-bolts/references/squad-subagent.md
git commit -m "$(cat <<'EOF'
feat(execute-bolts): v1.1 --per-squad and --squad=<id> flags

Per spec §6. Two new flags:

--per-squad   spawn one Claude subagent per declared squad (via Agent tool +
              run_in_background); each filters units by squad: field and
              runs in parallel. Parent consolidates results.

--squad=<id>  filter units to a single squad. For human-team handoff:
              dev team runs on their own laptop. Halts if any consumed
              interface is still status: draft.

New halt type: cross_squad_interface_draft (consumer must wait for
producer squad to lock the interface).

New reference doc: references/squad-subagent.md specifies subagent
dispatch prompt template + parent consolidation logic.

Single-squad / no-squad: --per-squad halts early with informative message.

Skill version bumped 1.0.0 → 1.1.0.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §6

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Update `vault-contract.md` halt-protocol with new types

**Goal:** Document the 4 new halt types (`cross_squad_dep_invalid`, `interface_ref_missing`, `cross_squad_ambiguous`, `cross_squad_interface_draft`) in the shared halt-protocol contract so all skills consume them consistently.

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`

- [ ] **Step 8.1: Add the four new halt types to the type list**

In `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`, find the `## §halt-protocol — Unified blocker envelope` section (around line 137). Locate the `type:` line in the schema:

```yaml
type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate
```

Replace with:

```yaml
type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft
```

- [ ] **Step 8.2: Add the four new type-specific schemas**

In the same file, find the `### Type-specific schemas (v1.1 additions)` section (around line 228). At the end of that section (after the existing `mode_migrate` block), append:

```yaml
# cross_squad_dep_invalid — emitted by generate-units in multi-squad mode
# when a unit's depends_on references a unit in a different squad
details:
  unit_id: U-XXX
  unit_squad: <squad-id>
  dependency_id: U-YYY
  dependency_squad: <squad-id-different>

# interface_ref_missing — emitted by generate-units when a unit's
# produces_interfaces or consumes_interfaces references an interface ID
# that has no corresponding file in <vault>/interfaces/
details:
  unit_id: U-XXX
  missing_interface_id: <kebab-id>
  referenced_in: consumes_interfaces | produces_interfaces

# cross_squad_ambiguous — emitted by generate-units when two or more
# squads in _meta/squads.yaml claim ownership of the same artifact at
# the same precedence level
details:
  artifact: <flow-id or entity-name or component-name>
  artifact_kind: flow | entity | component | adr | oq
  claimed_by_squads: [<id-1>, <id-2>, ...]
  matched_via: owns_layers | owns_components | owns_flow_prefixes | owns_feature_tags

# cross_squad_interface_draft — emitted by execute-bolts (specifically
# --per-squad or --squad=<id> modes) when a unit consumes an interface
# whose status is draft, blocking consumer execution until producer locks
details:
  unit_id: U-XXX
  unit_squad: <consumer-squad-id>
  consumed_interface_id: <kebab-id>
  producer_squad: <producer-squad-id>
  interface_status: draft
```

- [ ] **Step 8.3: Bump the §halt-protocol version comment**

Find the line `## §halt-protocol — Unified blocker envelope (v0.14)` (or similar). Update the version annotation:

Before:
```markdown
## §halt-protocol — Unified `blocker` envelope (v0.14)
```

After:
```markdown
## §halt-protocol — Unified `blocker` envelope (v0.14, extended v1.1)
```

- [ ] **Step 8.4: Verify**

```bash
grep -c "cross_squad\|interface_ref_missing" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
```

Expected: count ≥ 8 (4 types × 2 occurrences each in type union + type-specific block).

- [ ] **Step 8.5: Commit**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "$(cat <<'EOF'
feat(vault-contract): v1.1 add 4 new halt types for multi-squad mode

Per spec §6 §7. Halt-protocol type union extended with:
- cross_squad_dep_invalid     (generate-units rejects cross-squad depends_on)
- interface_ref_missing       (generate-units dangling interface reference)
- cross_squad_ambiguous       (generate-units two squads claim same artifact)
- cross_squad_interface_draft (execute-bolts consumer waits for producer lock)

Each gets its type-specific details schema in §Type-specific schemas (v1.1
additions). Existing 8 halt types unchanged.

vault-contract.md is the single source of truth for all skills — they
already reference these schemas, no code changes needed in consumer skills.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §6 §7

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update `orchestrate-flow` — detect multi-squad mode

**Goal:** Make `orchestrate-flow` aware of multi-squad mode so its CWD inspection reports squad count and its proposed chain suggests `execute-bolts --per-squad` when appropriate.

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md`

- [ ] **Step 9.1: Bump version in frontmatter**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`, change `version: 1.0.0` to `version: 1.1.0`.

- [ ] **Step 9.2: Add squad detection to the CWD inspection state**

Find the procedure step about CWD inspection (Step 2 in the existing file, around lines 20-32). Find the state snapshot block:

```
prd: present | absent
vault: present | absent (path: ...)
bound_vault: present | absent
units: N
bolts: N
codebase_map: present | absent
git_repo: yes | no
oq_p0_p1_count: N
mode_inferred: greenfield | brownfield
```

Replace with:

```
prd: present | absent
vault: present | absent (path: ...)
bound_vault: present | absent
units: N
bolts: N
codebase_map: present | absent
git_repo: yes | no
oq_p0_p1_count: N
mode_inferred: greenfield | brownfield
squad_count: N  # (v1.1+) from <vault>/_meta/squads.yaml; 0 if file absent or single squad
interfaces_count: N  # (v1.1+) count of files in <vault>/interfaces/ (excluding _index.md); 0 if folder absent
```

- [ ] **Step 9.3: Add squad-aware execute-bolts suggestion to the decision matrix**

In `plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md`, find the `## Decision matrix` section (around line 17-31). Add these new rows to the table:

| State (from inspection) | Proposed chain |
|---|---|
| (v1.1+) Vault has `squad_count: ≥2`, units exist, some not in bolts | `execute-bolts --per-squad` |
| (v1.1+) Vault has `squad_count: ≥2`, units exist, user invokes from a single-squad context (e.g., on a dev's laptop with a specific role) | Ask: "Run for which squad?" then propose `execute-bolts --squad=<answer>` |
| (v1.1+) Vault has `squad_count: ≥2` but `interfaces_count: 0` and ≥1 unit has cross-squad coupling hint in vault_source | `generate-units` (re-run, will surface `interface_ref_missing` halts as needed) |

Insert the new rows after the existing "Units exist, some not in bolts" row.

- [ ] **Step 9.4: Add a note about multi-squad detection**

After the `## Decision matrix` section in `routing-rules.md`, before the `## Chain depth limit` section, insert:

```markdown
## Multi-squad detection (v1.1+)

When CWD inspection finds `<vault>/_meta/squads.yaml` with ≥2 squads:

- Set `squad_count` in state snapshot to the count
- Read declared squad IDs to validate any `--squad=<id>` user input
- Adjust execute-bolts proposal:
  - Default to `--per-squad` (parallel subagent fan-out)
  - If user is running in a context that suggests single-squad focus
    (e.g., explicit `--squad=<id>` arg passed to orchestrate-flow, or
    a hint like "I'm on the FE team"), use `--squad=<id>` instead

If the count is exactly 1 (or file absent): treat as single-squad mode,
do NOT propose `--per-squad` (it would halt). Use `--all` or unit-by-unit.

If interface files exist (`<vault>/interfaces/*.md`):
- Report `interfaces_count` in state snapshot
- Don't read content (cheap inspection); just count files
- Trust execute-bolts pre-flight to validate interface lock states at run time
```

- [ ] **Step 9.5: Verify the changes**

```bash
grep -c "squad_count\|--per-squad\|--squad=" plugins/mega-sdd/skills/orchestrate-flow/SKILL.md plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md
```

Expected: count ≥ 5 across both files.

- [ ] **Step 9.6: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/SKILL.md \
        plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md
git commit -m "$(cat <<'EOF'
feat(orchestrate-flow): v1.1 detect multi-squad mode + suggest --per-squad

Per spec §8. CWD inspection state snapshot now includes:
- squad_count (from _meta/squads.yaml)
- interfaces_count (from interfaces/ folder)

Decision matrix gains 3 new rules:
- multi-squad + units pending → execute-bolts --per-squad
- multi-squad + user single-squad context → ask, then --squad=<id>
- multi-squad + zero interfaces but cross-squad hints → generate-units re-run

No new procedure steps; existing chain proposal logic extended.

Skill version bumped 1.0.0 → 1.1.0.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §8

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Update skill-triggering tests

**Goal:** Add test fixtures for the new flags and behaviors so the existing test harness covers v1.1 changes.

**Files:**
- Modify: `tests/skill-triggering/generate-units.test.md`
- Modify: `tests/skill-triggering/execute-bolts.test.md`
- Modify: `tests/skill-triggering/orchestrate-flow.test.md`

- [ ] **Step 10.1: Extend `generate-units.test.md` with multi-squad behaviors**

In `tests/skill-triggering/generate-units.test.md`, find the `## Behavior` section. After the existing B5 case, append:

```markdown
### B6 (v1.1+): Single-squad / no-squad mode = current behavior
- **Setup:** vault has no `_meta/squads.yaml` file
- **Expect:** units generated without `squad:` field (or with `squad: default`); no cross-squad validations run; behavior identical to v1.0

### B7 (v1.1+): Multi-squad assignment per partition rules
- **Setup:** vault has `_meta/squads.yaml` declaring 3 squads (squad-be, squad-fe-web, squad-integrations) with layer-based partition; vault flows include F-U-001 (user/web), F-B-003 (backend), and a flow touching Stripe (component owned by integrations)
- **Expect:** F-U-001 unit gets `squad: squad-fe-web`; F-B-003 unit gets `squad: squad-be`; Stripe-touching unit gets `squad: squad-integrations`

### B8 (v1.1+): Cross-squad depends_on rejected
- **Setup:** generate-units would produce a unit U-FE-007 that depends_on U-BE-012 (different squad)
- **Expect:** halt with `cross_squad_dep_invalid` blocker YAML; next_action mentions routing via interface

### B9 (v1.1+): Dangling interface reference rejected
- **Setup:** a unit declares `consumes_interfaces: [does-not-exist]` (no `<vault>/interfaces/does-not-exist.md`)
- **Expect:** halt with `interface_ref_missing` blocker YAML

### B10 (v1.1+): Ambiguous routing detected
- **Setup:** two squads both declare `owns_layers: [backend]` in squads.yaml; vault has backend flow F-B-001
- **Expect:** halt with `cross_squad_ambiguous` blocker YAML listing both claiming squads
```

- [ ] **Step 10.2: Extend `execute-bolts.test.md` with subagent + per-squad behaviors**

In `tests/skill-triggering/execute-bolts.test.md`, after the existing BH3 case (`--dry-run`), append:

```markdown
### BH4 (v1.1+): --per-squad requires multi-squad config
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:** halt with informative message; suggest `--all` or `generate-intent` to add squad config

### BH5 (v1.1+): --per-squad fans out subagents
- **Setup:** vault with 3 declared squads, units assigned across squads (e.g., 4 BE + 3 FE + 2 integrations)
- **Prompt:** `/mega-sdd:execute-bolts --per-squad`
- **Expect:**
  - 3 Agent() dispatches with run_in_background: true
  - Each subagent prompted with its squad ID and filter instructions per references/squad-subagent.md
  - Parent consolidates results into per-squad table after all complete

### BH6 (v1.1+): --squad=<id> filters and runs single squad
- **Setup:** vault with 3 squads; user runs on their FE laptop
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** only units where `squad: squad-fe-web` execute; BE and integrations units skipped; bolts written only for FE units

### BH7 (v1.1+): --squad=<id> halts on draft consumed interface
- **Setup:** FE unit U-FE-002 declares `consumes_interfaces: [api-x]`; `interfaces/api-x.md` has `status: draft`
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** halt with `cross_squad_interface_draft` blocker; next_action names producer squad

### BH8 (v1.1+): --per-squad combined with --parallel
- **Setup:** vault with 2 squads; each has internally independent units
- **Prompt:** `/mega-sdd:execute-bolts --per-squad --parallel`
- **Expect:** 2 squad-level subagents, each internally using subagent-driven-development for parallel unit dispatch; no resource collision (different working sets)
```

- [ ] **Step 10.3: Extend `orchestrate-flow.test.md` with multi-squad routing**

In `tests/skill-triggering/orchestrate-flow.test.md`, append a new `## Multi-squad routing (v1.1+)` section:

```markdown
## Multi-squad routing (v1.1+)

### MS1: CWD inspection reports squad count
- **Setup:** vault has `_meta/squads.yaml` with 3 squads
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot includes `squad_count: 3`

### MS2: Multi-squad + pending units → suggest --per-squad
- **Setup:** vault with 3 squads, units exist, no bolts yet
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposed chain contains `execute-bolts --per-squad`

### MS3: Single-squad (squad_count=1) → existing behavior
- **Setup:** vault has `_meta/squads.yaml` with exactly 1 squad declared
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** proposes `execute-bolts --all` (NOT `--per-squad`)

### MS4: No squads.yaml → existing behavior
- **Setup:** vault has no `_meta/squads.yaml`
- **Prompt:** `/mega-sdd:orchestrate-flow`
- **Expect:** state snapshot `squad_count: 0`; proposes `execute-bolts --all`
```

- [ ] **Step 10.4: Verify all test fixtures updated**

```bash
grep -c "v1.1" tests/skill-triggering/generate-units.test.md \
                tests/skill-triggering/execute-bolts.test.md \
                tests/skill-triggering/orchestrate-flow.test.md
```

Expected: each file has count ≥ 3.

- [ ] **Step 10.5: Commit**

```bash
git add tests/skill-triggering/generate-units.test.md \
        tests/skill-triggering/execute-bolts.test.md \
        tests/skill-triggering/orchestrate-flow.test.md
git commit -m "$(cat <<'EOF'
test(skill-triggering): cover v1.1 multi-squad behaviors

generate-units: 5 new cases (B6-B10) — single-squad fallback, multi-squad
assignment, cross-squad depends_on rejection, dangling interface, ambiguous
routing.

execute-bolts: 5 new cases (BH4-BH8) — --per-squad guard, subagent fan-out,
--squad filter, draft-interface halt, combined --per-squad --parallel.

orchestrate-flow: new section "Multi-squad routing" with 4 cases (MS1-MS4)
covering state-snapshot fields and decision-matrix routing.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §11

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Add multi-squad E2E integration test

**Goal:** Create a full end-to-end manual fixture exercising the v1.1 multi-squad flow on a small synthetic project.

**Files:**
- Create: `tests/integration/e2e-multi-squad.test.md`

- [ ] **Step 11.1: Write the integration test fixture**

Create `tests/integration/e2e-multi-squad.test.md`:

```markdown
# E2E Multi-Squad Pipeline Test

Walks the full pipeline on a synthetic multi-squad project. Manual run; exercises every v1.1+ behavior end-to-end.

## Setup

```bash
mkdir -p /tmp/megasdd-e2e-multi && cd /tmp/megasdd-e2e-multi
git init
echo "# Multi-Squad Test Project" > README.md
git add . && git commit -m "init"
```

## Walk

### Step 1: generate-intent with multi-squad Q&A

```
/mega-sdd:generate-intent --from-prompt "build a tenant-billing web app with backend API (Node), web frontend (React), and Stripe billing integration"
```

**Expect during Q&A:**
- Standard project shape Q → answer: `web-app`
- Standard mode Q → answer: `new` (greenfield)
- NEW squad-count Q → answer: `3`
- NEW partition-model Q → answer: `1` (layer-based)
- NEW squad-declaration loop (3 iterations):
  1. id=squad-be, label="Backend Squad", owns_layers=[backend, data-model]
  2. id=squad-fe-web, label="Frontend Web Squad", owns_layers=[web-frontend]
  3. id=squad-integrations, label="Integrations Squad", owns_layers=[integrations], owns_components=[stripe]

**Expect output:**
- `docs/mega-sdd/vaults/<name>/` with the 7 prose docs
- Each prose doc has YAML frontmatter (type, doc_id, aliases, tags)
- Cross-refs are wikilinks (e.g., `[[02-architecture#Backend]]`)
- `_meta/squads.yaml` with 3 squads declared
- `interfaces/_index.md` (empty stub, no `<id>.md` files yet)
- `.obsidian/graph.json` with color groups for 3 squads
- `vault.json` has `multi_squad_mode: true`

### Step 2: Author one interface manually (architect step)

Create `docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md` from the template:

```bash
cp plugins/mega-sdd/skills/generate-intent/references/templates/interface-note.template.md \
   docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md
```

Then edit it (substitute placeholders):
- id: api-billing-checkout
- type: interface
- producer: squad-integrations
- consumers: [squad-fe-web, squad-be]
- contract_kind: rest
- status: draft  (will lock later)

### Step 3: generate-units in multi-squad mode

```
/mega-sdd:generate-units docs/mega-sdd/vaults/<name>
```

**Expect:**
- Units generated with `squad:` field assigned per layer rules
- BE flows → `squad: squad-be`; FE flows → `squad: squad-fe-web`; Stripe-touching → `squad: squad-integrations`
- A FE unit that bills through Stripe has `consumes_interfaces: [api-billing-checkout]` in frontmatter
- An integrations unit that produces the billing endpoint has `produces_interfaces: [api-billing-checkout]`
- No `depends_on` edge crosses squads

### Step 4: Try execute-bolts --per-squad with draft interface

```
/mega-sdd:execute-bolts --per-squad
```

**Expect:**
- Halts: the FE squad subagent emits `cross_squad_interface_draft` because `api-billing-checkout` is `status: draft`
- BE squad subagent may still complete (no draft-interface dependencies)
- Integrations squad subagent works on producing the locked side

### Step 5: Lock the interface and retry

Edit `docs/mega-sdd/vaults/<name>/interfaces/api-billing-checkout.md`:
- frontmatter: `status: locked`, `locked_at: <today>`

```
/mega-sdd:execute-bolts --per-squad
```

**Expect:**
- All 3 squad subagents now complete
- Each writes bolt-reports to their squad's units
- Final consolidated report shows 3 squads, M total units, K commits, 0 halts

### Step 6: Verify per-squad handoff

Simulate a dev team member running only the FE squad on their laptop:

```
/mega-sdd:execute-bolts --squad=squad-fe-web
```

**Expect:**
- Only FE units execute
- No BE/integrations work touched (already done in step 5, but the filter would skip them anyway)
- Confirms the human-handoff use case

### Step 7: orchestrate-flow shows v1.1 awareness

```
/mega-sdd:orchestrate-flow
```

**Expect:**
- State snapshot includes `squad_count: 3`, `interfaces_count: 1`
- If any units pending: suggests `execute-bolts --per-squad`
- If all units done: suggests `detect-drift`

## Pass criteria

End-to-end pipeline produces working multi-squad project:
- 3 squad subagents executed in parallel
- Cross-squad coupling went through 1 locked interface
- Draft-interface halt fired correctly on the first --per-squad attempt
- Single-squad re-run via `--squad=squad-fe-web` worked as filtered execution
- No cross-squad direct depends_on edges existed in unit DAG
- Vault structure: 7 prose docs (with frontmatter + wikilinks) + _meta/squads.yaml + interfaces/api-billing-checkout.md + .obsidian/graph.json + units/ + bolts/
```

- [ ] **Step 11.2: Verify the file**

```bash
ls tests/integration/e2e-multi-squad.test.md
wc -l tests/integration/e2e-multi-squad.test.md
```

Expected: file exists, ~100 lines.

- [ ] **Step 11.3: Commit**

```bash
git add tests/integration/e2e-multi-squad.test.md
git commit -m "$(cat <<'EOF'
test(integration): add e2e-multi-squad pipeline test

Walks all v1.1 behaviors end-to-end on a synthetic 3-squad project:
1. generate-intent multi-squad Q&A → vault + squads.yaml + interfaces/_index
2. Manual interface authoring (draft state)
3. generate-units assigns squad: field + interface refs
4. execute-bolts --per-squad halts on draft interface (BH7 behavior)
5. Lock interface, retry, 3 subagents complete in parallel
6. Per-squad filter via --squad=<id> for human handoff
7. orchestrate-flow reports squad_count + interfaces_count

Manual fixture (no CI runner) — follow tests/integration/ pattern.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md §12

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Version bump + CHANGELOG entry

**Goal:** Bump plugin version to 1.3.0 and document the v1.1 skill-level changes + new features in CHANGELOG.

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 12.1: Bump plugin.json**

Read the current version in `plugins/mega-sdd/.claude-plugin/plugin.json`:

```bash
cat plugins/mega-sdd/.claude-plugin/plugin.json | grep version
```

Update the version field from `1.2.0` to `1.3.0`. Use Edit to change exactly:

```
  "version": "1.2.0",
```

to:

```
  "version": "1.3.0",
```

- [ ] **Step 12.2: Bump marketplace.json**

Read the current version:

```bash
cat .claude-plugin/marketplace.json | grep -i version | head -5
```

Find the mega-sdd plugin's version entry and bump from `1.2.0` to `1.3.0`. Use Edit on the specific line.

- [ ] **Step 12.3: Add CHANGELOG entry**

Open `CHANGELOG.md`. Find the existing top-most entry (likely `## v1.2.0`). Insert a new entry above it:

```markdown
## v1.3.0 — 2026-05-17

### Added — Obsidian-friendly vault + multi-squad subagent execution

Per spec `docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md`.

Lightweight Obsidian compatibility:
- 7 prose templates gain minimal YAML frontmatter (`type`, `doc_id`, `aliases`, `tags`)
- Internal cross-refs converted to Obsidian wikilink syntax `[[file#heading]]`
- Optional `.obsidian/graph.json` template with squad color groups

Multi-squad partition as a dimension threaded through the existing 5-phase pipeline (zero pipeline change, README flowchart intact):
- New `_meta/squads.yaml` declaring squad partition (layer / feature / hybrid models)
- New `interfaces/` folder for cross-squad contracts (architect-authored, status: draft → locked)
- Units gain optional `squad:`, `produces_interfaces:`, `consumes_interfaces:` frontmatter fields
- `execute-bolts --per-squad` spawns one Claude subagent per declared squad via existing `subagent-driven-development`
- `execute-bolts --squad=<id>` filters to one squad for dev-team handoff
- `generate-units` validates intra-squad-only `depends_on` and interface reference resolution
- `orchestrate-flow` detects multi-squad mode and suggests appropriate flags

### Halt protocol extensions (vault-contract.md §halt-protocol)

Four new blocker types:
- `cross_squad_dep_invalid` (generate-units rejects cross-squad direct depends_on)
- `interface_ref_missing` (generate-units dangling interface reference)
- `cross_squad_ambiguous` (generate-units two squads claim same artifact)
- `cross_squad_interface_draft` (execute-bolts consumer waits for producer to lock interface)

### Skill versions

- `generate-intent`: 1.0.0 → 1.1.0
- `generate-units`: 1.0.0 → 1.1.0
- `execute-bolts`: 1.0.0 → 1.1.0
- `orchestrate-flow`: 1.0.0 → 1.1.0

### Backward compatibility

- Existing v1.0–v1.2 vaults work unchanged (single-squad / no-squad-config mode active)
- Multi-squad is OPT-IN via the new Q&A in `generate-intent`
- No new skills; plugin skill count unchanged
- AI consumer skills (`bind-codebase`, `resolve-oq`, `detect-drift`, `diff-vault`) behave identically across v1.2 and v1.3 single-squad vaults

### New tests

- `tests/skill-triggering/`: 14 new cases across `generate-units`, `execute-bolts`, `orchestrate-flow`
- `tests/integration/e2e-multi-squad.test.md`: full multi-squad pipeline walkthrough
```

- [ ] **Step 12.4: Verify all version bumps**

```bash
grep version plugins/mega-sdd/.claude-plugin/plugin.json
grep version .claude-plugin/marketplace.json | head -3
head -3 CHANGELOG.md
```

Expected: plugin.json `1.3.0`, marketplace.json contains `1.3.0` entry, CHANGELOG starts with v1.3.0 entry.

- [ ] **Step 12.5: Commit**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json \
        .claude-plugin/marketplace.json \
        CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(v1.3): bump plugin + marketplace to 1.3.0 + CHANGELOG entry

Plugin: 1.2.0 → 1.3.0
Marketplace: 1.2.0 → 1.3.0

CHANGELOG entry documents v1.3.0 — Obsidian-friendly vault + multi-squad
subagent execution. Per-skill version bumps (4 skills 1.0.0 → 1.1.0) and
4 new halt types in vault-contract.md.

Spec: docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md
Plan: docs/superpowers/plans/2026-05-17-obsidian-multi-squad-vault.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (after all tasks complete)

This is the final verification step before declaring the plan implemented.

- [ ] **R1: All 12 tasks committed individually.** Run `git log --oneline | head -15` and verify 12 atomic commits exist, one per task.

- [ ] **R2: Spec coverage check.** Walk through each section of `docs/superpowers/specs/2026-05-17-obsidian-multi-squad-vault-design.md`:
  - §1 (file layout) → Task 1, 2, 3 (templates), Task 5 (emission)
  - §2 (Obsidian frontmatter + wikilinks) → Task 1
  - §3 (squad declaration) → Task 2, Task 5
  - §4 (interface notes) → Task 3, Task 5
  - §5 (unit schema) → Task 4
  - §6 (execute-bolts flags) → Task 7
  - §7 (niche protection) → Task 4 + Task 6 (validations)
  - §8 (skill changes) → Tasks 5, 6, 7, 9
  - §9 (backward compat) → all tasks preserve single-squad path
  - §10 (implementation plan) → this plan itself
  - §11 (risk register) → tests in Tasks 10, 11
  - §12 (success criteria) → e2e test in Task 11

  Every spec section has a corresponding task. ✓

- [ ] **R3: Trigger phrase test pass.** Manually run through each `tests/skill-triggering/*.test.md` file's new cases and verify behavior matches expectations.

- [ ] **R4: E2E test walkthrough.** Run `tests/integration/e2e-multi-squad.test.md` end-to-end on a clean `/tmp/megasdd-e2e-multi/` directory.

- [ ] **R5: Single-squad regression check.** Re-run `tests/integration/e2e-greenfield.test.md` (existing single-squad test) on a v1.3 plugin and verify zero behavioral difference from v1.2.

- [ ] **R6: README verification.** Per `plugins/mega-sdd/CLAUDE.md`, every behavior change should trace back to the spec. Verify no out-of-spec edits leaked in.

- [ ] **R7: README flowchart unchanged.** `git diff main -- README.md plugins/mega-sdd/README.md` should show ZERO flowchart changes (and possibly only minor additions like Migrating section updates if needed).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-17-obsidian-multi-squad-vault.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
