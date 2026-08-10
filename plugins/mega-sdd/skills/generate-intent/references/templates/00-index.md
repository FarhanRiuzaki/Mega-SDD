---
type: prose
doc_id: 00-index
vault_version: "{{VAULT_VERSION}}"
aliases: [Index, Vault Index, Grand Design Index]
tags: ["vault/{{PROJECT_SLUG}}", "doc/index"]
---

# <Project Name> — Grand Design

> 1-line product description (mirrors [[01-overview]]).

## Vault Lock Status

- **Vault version**: v1.0
- **History**: full version log in "## Changelog" at the end of this doc (newest entry first).
- **Project shape**: `mobile-app` | `web-app` | `api-only` | `multi-platform` | `data-pipeline` | `custom: <description>`
- **Implementation mode**: `new` | `existing`
- **Mode migration trigger**: `<event>` (e.g., "first commit on main" / "first prod deploy" / "sprint-1 demo") — applies to `mode=new` only; set to `null` for `mode=existing`. After trigger fires, flip mode to `existing` (manual edit + Changelog entry, or run `diff-vault`).
- **PRD status**: `final` (signed-off by stakeholder) | `draft` (still in flux)
- **Output mode**: `compact` (default — table-first, prose-cut) | `full` (verbose — prose-rich for cross-functional review)
- **Locked at**: YYYY-MM-DD HH:MM (TZ)
- **Locked by**: <PM name>, <Architect name>, <Tech Lead name>
- **PRD source**: <filename, version, date> — <FINAL | DRAFT>
- **Status**: 🔒 LOCKED for <scope, e.g. "sprint 1 implementation"> | ⚠️ DRAFT (not locked yet)

> **PRD status semantics**:
> - `final` → vault was generated under the assumption PRD is locked. All gaps captured as Open Questions; user triages OQ list with stakeholder offline.
> - `draft` → vault may have been paused mid-generation for clarification; some gaps may have been resolved inline before generation completed.

> The vault is a **lock against requirements** (PRD/BRD), not against the codebase. Any change to the vault after lock = bump version + append Changelog + re-sign-off by relevant stakeholders. Dev and AI consumers MUST verify which vault version they're working from.

## Executive Summary

<3–4 sentences: what the product is, why it's being built, and the current state of the project. Written assuming a first-time reader with no context. Natural language, no jargon.>

## Project Readiness Status

| Item | Status |
|------|--------|
| PRD | ✅ Complete / 🟡 Draft / 🔴 Pending |
| Figma | ✅ Complete / 🟡 Pending review / ⚪ Not consumed |
| Tech stack | ✅ Defined / 🔴 TBD |
| Sign-off | X / Y stakeholders |
| Open Questions | P1: {n} · P2: {n} · P3: {n} |

> Snapshot at doc-generation time. Update on each review iteration.

## Reading paths by role

> Roles and paths are derived from `Project shape` (see Vault Lock Status above).
> Replace the examples below with roles and anchors that fit this project's shape.
>
> Common patterns:
> - **mobile-app**: Architect / Mobile Dev / BE Dev / QA / PM / UI/UX
> - **web-app**: Architect / FE Dev / BE Dev / QA / PM / UI/UX
> - **api-only**: Architect / BE Dev / QA / PM / External integrator
> - **multi-platform**: Architect / FE Dev / Mobile Dev / BE Dev / QA / PM / UI/UX
> - **data-pipeline**: Architect / Data Engineer / QA / PM / Data analyst
> - **custom**: roles per user description
>
> Anchor links let readers jump directly to a relevant section without reading the full doc.

Examples (adjust to `PROJECT_SHAPE`):

- **IT Architect / Tech Lead**: [[02-architecture]] (full) → [[03-data-model]] → [[05-decisions]] → [[06-constraints]]
- **<Layer-specific Dev, e.g. "Backend Developer">**: [[02-architecture#<layer-anchor>]] → [[03-data-model]] → [[04-flows#<flow-type-anchor>]]
- **QA**: [[04-flows]] (all sections, focusing on Definition of Done per flow)
- **PM / Business Owner**: [[00-index]] → [[01-overview]] → [[05-decisions]]
- **<UI/UX or other UI-relevant role, if the project has UI>**: [[01-overview]] → [[04-flows#<user-flow-anchor>]]

- **UI/UX or FE Dev** (conditional): [[01-overview]] → [[02-architecture#UI components & patterns]] → [[06-constraints#Design System]] → [[04-flows]]

  > **Conditional**: appears only if the vault has at least one of [[02-architecture#UI components & patterns]] or [[06-constraints#Design System]] (i.e., Step 2 detection found explicit source). If both are absent, remove this reading path.

## Reading order (full)

1. [[01-overview]] — what, who, why, success metrics
2. [[02-architecture]] — system components (per layer), API contracts
3. [[03-data-model]] — entities, relations, constraints
4. [[04-flows]] — user flows, backend flows, cross-cutting flows + Definition of Done
5. [[05-decisions]] — technical decisions and their rationale (ADR-lite)
6. [[06-constraints]] — technical, business, NFR constraints

## Anti-hallucination rules for dev / dev AI

This document is the **single source of truth for requirements**. When working from it:

1. **If a requirement is NOT written here → STOP, ask a human / PM. Do not infer, do not use "best-practice defaults".**
2. **If two docs appear to conflict → STOP, surface the conflict.**
3. **If a flow has no Definition of Done → STOP, do not mark it complete.**
4. **The Open Questions below are blockers.** They must be answered by the relevant stakeholder before the related work begins.

## Implementation Notes for AI Consumers (Claude Code, Cursor, etc.)

> This section is specifically for AI dev tools that read the vault as source of truth when writing/modifying code.
> **MANDATORY: before writing code, read `_meta/ai-consumer-guide.md`.** Full consumer protocol (halt YAML envelopes, mode cross-check checklists, parallel-work under unresolved P1s, companion skills): `_meta/ai-consumer-guide.md` (travels with this vault — installed at generation time, identical across vaults).

**Vault metadata**:
- Project shape: <set per Vault Lock Status above — drives which layers/flows exist>
- Implementation mode: <set per Vault Lock Status above>
- PRD status: <set per Vault Lock Status above — `final` means the OQ list is the authoritative gap list, no synchronous stakeholder clarification expected>
- Vault version: <set per Vault Lock Status above>

### Per-vault notes (THIS vault only)

<Write the PER-VAULT specialization only: list which unresolved P1 OQ clusters block which work areas, and the layer-routing anchors for THIS vault (e.g. backend work → [[02-architecture#Backend]] + the backend flows in [[04-flows]]) — never restate the generic protocol (halt YAML shapes, mode checklists, parallel-work guidance, companion-skills routing live in `_meta/ai-consumer-guide.md`).>

<KB sub-mode only: the `kb_module_graph: <path>` pointer line lives here (written per `kb-submode.md`; read by generate-units decomposition).>

## Glossary

Product-specific PRD terms only (e.g., MPIN, CIF, OTP, parameterized, …):

| Term | Definition |
|------|----------|
| <PRD term> | <definition, cited to the PRD section that defines it> |

> Standard terms (ADR, DBML, DoD, FK, NFR, OQ, RTO, RPO, SLO + the design-system terms): see the **Standard terms** table in `_meta/ai-consumer-guide.md` — never re-emit those rows here.

## Open Questions (roll-up)

> Total: **{N} Open Questions** across 6 docs. Sorted by category (by topic, not by doc), then P1 → P2 → P3 within each.

### {Category 1 — e.g. "PRD inconsistencies"} (PRIORITY-1)

- [ ] **OQ-DM-1** [P1]: <text> [[03-data-model]]
- [ ] **OQ-FL-1** [P1]: <text> [[04-flows]]

### {Category 2 — e.g. "Tech stack & architecture"} (PRIORITY-1)

- [ ] **OQ-AR-1** [P1]: <text> [[02-architecture]]
- [ ] **OQ-AR-2** [P1]: <text> [[02-architecture]]

### {Category 3 — e.g. "Data model details"} (PRIORITY-2)

- [ ] **OQ-DM-2** [P2]: <text> [[03-data-model]]

> Add categories as needed. Suggested: PRD inconsistencies, Tech stack & architecture, Data model, Flow & timing, Decisions, Constraints / sign-off / NFR / compliance, Overview & metrics.

## Source documents

- **PRD**: <filename / version / date YYYY-MM>
- **BRD**: <filename / version / date YYYY-MM>
- **Figma**: <URL or frame set name>
- **Other**: <existing system docs, etc.>

## Changelog

### v1.0 (YYYY-MM-DD)
- Initial vault generated from PRD <version> <date>.
- Mode: <new | existing>.

<!-- Add a new entry above when revising the vault:
### v1.1 (YYYY-MM-DD)
- <changes>
-->

## Last updated

YYYY-MM-DD

> **Date format convention**: `Last updated` uses `YYYY-MM-DD` (precision). Decision dates / PRD version refs in other docs use `YYYY-MM` (sprint/version granularity).
