---
type: vault
doc_id: vault
vault_layout: 2
vault_version: "{{VAULT_VERSION}}"
project_shape: <mobile-app | web-app | api-only | multi-platform | data-pipeline | custom>
implementation_mode: <new | existing>
mode_migration_trigger: <event, e.g. "first prod deploy" — null for mode=existing>
prd_status: <final | draft>
output_mode: <compact | full>
prd_source: "<filename, version, date — FINAL | DRAFT>"
locked_at: "<YYYY-MM-DD HH:MM (TZ)>"
locked_by: ["<PM name>", "<Tech Lead name>"]
aliases: [Vault, Grand Design]
tags: ["vault/{{PROJECT_SLUG}}", "doc/vault"]
# KB sub-mode only — read by generate-units decomposition (kb-submode.md):
# kb_module_graph: <path>
---

# <Project Name> — Grand Design

> 1-line product description.

## Phase context

**Phase:** <N> of <M>

**This vault covers:** <1-line summary from suggested-phasing.md §Phase N — first sentence wins. Single-phase: "Single-phase project".>

<!-- HARD-HEADER CONTRACT (v7 layout-2): the three H2 anchors below —
     `## Overview`, `## Architecture`, `## Decisions` — are EXACT strings.
     derive-vault-json.sh and derive-claims-ledger.sh exit 2 naming the missing
     header when one is absent (DOC_CODE re-keys from filename to section).
     Never rename, translate, or demote them. Sub-headings INSIDE a section
     are free (unknown H2s do not end a section; only the anchor set does). -->

## Overview

> **TL;DR**: <what the product is · primary audience · when to read>.

### Product

<2–3 sentences. What the product is.>

### Target users / personas

- **<Persona 1>**: <1-line description, role, primary need>

> Only list personas explicitly named or described in the PRD.

### Problem

<Business problem this product solves, from the user's pain perspective.>

### Success criteria

- <KPI / metric with target if given — PRD-sourced only; unknown → an Open Question in constraints.md>

### Sources

- PRD §<X.Y>

### Out of Scope

- <explicit non-goals; if unknown: "TBD - confirm with PO">

## Architecture

> **TL;DR**: system components + API surface, organized per layer per PROJECT_SHAPE.

### System overview

<1-paragraph high-level + text diagram, all layers in one view.>

### {Layer 1, e.g. "Backend"}

| Component | Purpose | Source |
|-----------|---------|--------|
| <component name> | <1-line> | <PRD §X> |

**Tech stack ({this layer})**: <only if stated>

#### UI components & patterns

> **Conditional**: only if `HAS_UI_COMPONENTS=true` from Step 2 (explicit source named the components — never shape inference or prior knowledge).

| Component | Purpose | Variants | Source |
|-----------|---------|----------|--------|
| `<ComponentName>` | <1-line purpose> | `<variant1 | variant2>` | Figma `<frame>` / tokens.json `<key>` / PRD §<X.Y> |

### API contracts

> Group endpoints under their consuming layer. Only contracts explicitly stated or directly derivable from AC — anything else is an Open Question.
> `compact`: table per group (endpoint · method · purpose · auth · errors · source); `full`: request/response JSON per endpoint.

### Sources

- PRD §<X.Y> · Figma: <frame-name>

### Out of Scope

- <e.g. "Real-time sync via WebSocket — not in v1">

## Decisions

> ADR-lite. One entry per decision WITH an explicit source; PRD silent → an Open Question in constraints.md, never an ADR.

### D-001: <short decision title>

<Context in one sentence>. **Decision**: <what was decided, 1–2 sentences>. **Consequences**: <pros + trade-offs, max 2 lines>. **Source**: <PRD §X>.

<!-- OUTPUT_MODE=full — multi-section per ADR:
### D-001: <short decision title>
**Status**: Proposed | Accepted | Superseded by D-XXX
**Date**: YYYY-MM
**Context**: <2–3 sentences>
**Decision**: <1–3 sentences>
**Consequences**:
- ✅ <positive>
- ⚠️ <trade-off>
**Source**: <PRD §X / explicit user instruction / meeting note>
-->

## Glossary

Product-specific PRD terms only (standard terms — ADR, DBML, DoD, FK, NFR, OQ, … — live in `_meta/ai-consumer-guide.md` §Standard terms; never re-emit them here):

| Term | Definition |
|------|----------|
| <PRD term> | <definition, cited to the PRD section that defines it> |

## Auto-Classification Review

> Written by Step 3.5. Every tech-tagged OQ + every flipped/overridden OQ; only `high`-confidence tech OQs auto-resolve in bind-codebase.

- <OQ tag> → <tech|business> / <confidence> (<1-line note>)

## Source documents

- **PRD**: <filename / version / date YYYY-MM>
- **Figma**: <URL or frame set name>

## Changelog

### v1.0 (YYYY-MM-DD)
- Initial vault generated from PRD <version> <date>.
- Mode: <new | existing>.

## Last updated

YYYY-MM-DD
