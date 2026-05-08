# <Project Name> — Grand Design

> 1-line product description (mirrors `01-overview.md`).

## Vault Lock Status

- **Vault version**: v1.0
- **Project shape**: `mobile-app` | `web-app` | `api-only` | `multi-platform` | `data-pipeline` | `custom: <description>`
- **Implementation mode**: `new` | `existing`
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

## Changelog

### v1.0 (YYYY-MM-DD)
- Initial vault generated from PRD <version> <date>.
- Mode: <new | existing>.

<!-- Add a new entry above when revising the vault:
### v1.1 (YYYY-MM-DD)
- <changes>
-->

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

- **IT Architect / Tech Lead**: `02-architecture.md` (full) → `03-data-model.md` → `05-decisions.md` → `06-constraints.md`
- **<Layer-specific Dev, e.g. "Backend Developer">**: `02-architecture.md#<layer-anchor>` → `03-data-model.md` → `04-flows.md#<flow-type-anchor>`
- **QA**: `04-flows.md` (all sections, focusing on Definition of Done per flow)
- **PM / Business Owner**: `00-index.md` → `01-overview.md` → `05-decisions.md`
- **<UI/UX or other UI-relevant role, if the project has UI>**: `01-overview.md` → `04-flows.md#<user-flow-anchor>`

- **UI/UX or FE Dev** (v0.6, conditional): `01-overview.md` → `02-architecture.md#ui-components-patterns` → `06-constraints.md#design-system` → `04-flows.md`

  > **Conditional**: appears only if the vault has at least one of `02-architecture.md#ui-components-patterns` or `06-constraints.md#design-system` (i.e., Step 2 detection found explicit source). If both are absent, remove this reading path.

## Reading order (full)

1. `01-overview.md` — what, who, why, success metrics
2. `02-architecture.md` — system components (per layer), API contracts
3. `03-data-model.md` — entities, relations, constraints
4. `04-flows.md` — user flows, backend flows, cross-cutting flows + Definition of Done
5. `05-decisions.md` — technical decisions and their rationale (ADR-lite)
6. `06-constraints.md` — technical, business, NFR constraints

## Anti-hallucination rules for dev / dev AI

This document is the **single source of truth for requirements**. When working from it:

1. **If a requirement is NOT written here → STOP, ask a human / PM. Do not infer, do not use "best-practice defaults".**
2. **If two docs appear to conflict → STOP, surface the conflict.**
3. **If a flow has no Definition of Done → STOP, do not mark it complete.**
4. **The Open Questions below are blockers.** They must be answered by the relevant stakeholder before the related work begins.

## Implementation Notes for AI Consumers (Claude Code, Cursor, etc.)

> This section is specifically for AI dev tools that read the vault as source of truth when writing/modifying code.

**Vault metadata**:
- Project shape: <set per Vault Lock Status above — drives which layers/flows exist>
- Implementation mode: <set per Vault Lock Status above>
- PRD status: <set per Vault Lock Status above — `final` means the OQ list is the authoritative gap list, no synchronous stakeholder clarification expected>
- Vault version: <set per Vault Lock Status above>

### MANDATORY before writing/modifying any code

1. **Confirm project shape & mode with the user**:
   - Ask: *"This vault states shape `<shape>` and mode `<mode>`. Are you working in a project that matches?"*
   - On mismatch → STOP, escalate.

2. **For mode `existing`** — additional MANDATORY steps:
   - Ask the user: *"Share a short description of the existing codebase (project root, framework, key tables that are relevant), or confirm I should scan first before continuing."*
   - **Cross-check entities** (`03-data-model.md`) against the existing schema:
     - New entity in vault, name doesn't collide with existing → safe to create.
     - Vault entity that shares a name with an existing one → STOP, clarify extend vs replace.
   - **Cross-check flows** (`04-flows.md`) against existing routes/handlers/cron jobs:
     - New flow, no collision → safe to add.
     - Flow that touches an existing endpoint/job → STOP, clarify extend vs replace.
   - **Cross-check decisions** (`05-decisions.md`) against existing patterns:
     - Decision that **conflicts** with an existing pattern → STOP, escalate to architect for a transition plan.

3. **For mode `new`** — checks still apply:
   - Confirm tech stack from the vault with the user (`02-architecture.md` may still have Open Questions on stack).
   - If P1 Open Questions are unresolved → STOP, do not auto-pick a stack default.

4. **Use the relevant layer section based on what you're implementing**:
   - Working on backend → focus on `02-architecture.md#backend` + the backend section of `04-flows.md`.
   - Working on UI (mobile/web) → focus on the relevant UI layer in `02-architecture.md` + user flows in `04-flows.md`.
   - Cross-cutting feature → check the cross-cutting flows section + multiple layer sections.

### During implementation

- **Do not inject requirements** that aren't in the vault. If a new requirement is needed → STOP, append it to `## Open Questions` in the relevant doc and ask the user.
- **Do not skip Definition of Done**. For each flow you implement, validate DoD before marking it complete.
- **Cite the vault** in commit messages or code comments when touching business logic — e.g., `// Per vault 04-flows.md F-U-001 step 5`.

### When you encounter an inconsistency

- Vault internal conflict (e.g., doc 03 vs doc 04) → STOP, surface to the user with quotes from both sides.
- Vault vs existing code conflict → STOP, escalate to user. Show the vault quote + the existing-code reference.
- Vault vs original PRD (if user grants PRD access) → STOP, escalate to user. The vault should reflect the PRD; if not, the vault is stale.

## Glossary

Cross-doc terms and acronyms:

| Term | Definition |
|------|----------|
| ADR | Architecture Decision Record — record of a technical decision with context, decision, consequences |
| DBML | Database Markup Language — text format for defining database schema |
| DoD | Definition of Done — observable criteria that mark a flow/task complete |
| FK | Foreign Key |
| NFR | Non-Functional Requirement — performance, availability, security, etc. |
| OQ | Open Question — ambiguity that needs a stakeholder answer |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| SLO | Service Level Objective |
| design tokens (v0.6, cond.) | Named design values (color, typography, spacing) shared across components. Source-mirrored from Figma variables / tokens.json / PRD. |
| design system (v0.6, cond.) | Set of components + tokens + a11y + voice rules that constrain UI implementation. |
| WCAG (v0.6, cond.) | Web Content Accessibility Guidelines — international standard for a11y. Vault uses a level only if source explicitly states it. |
| a11y (v0.6, cond.) | Numeronym for "accessibility" (a + 11 letters + y). |
| semantic HTML (v0.6, cond.) | Use of meaningful HTML elements (`<button>`, `<nav>`, `<main>`, etc.) for accessibility and structure. |

> Add product-specific terms from the PRD here (e.g., MPIN, CIF, OTP, parameterized, etc.).

> **v0.6 conditional entries**: `design tokens`, `design system`, `WCAG`, `a11y`, `semantic HTML` appear only if the term is used elsewhere in the vault (i.e., `02-architecture#ui-components-patterns` or `06-constraints#design-system` is present). If unused, remove the rows marked `(v0.6, cond.)`.

## Open Questions (roll-up)

> Total: **{N} Open Questions** across 6 docs. Sorted by category (by topic, not by doc), then P1 → P2 → P3 within each.

### {Category 1 — e.g. "PRD inconsistencies"} (PRIORITY-1)

- [ ] **OQ-DM-1** [P1]: <text> `[03-data-model.md]`
- [ ] **OQ-FL-1** [P1]: <text> `[04-flows.md]`

### {Category 2 — e.g. "Tech stack & architecture"} (PRIORITY-1)

- [ ] **OQ-AR-1** [P1]: <text> `[02-architecture.md]`
- [ ] **OQ-AR-2** [P1]: <text> `[02-architecture.md]`

### {Category 3 — e.g. "Data model details"} (PRIORITY-2)

- [ ] **OQ-DM-2** [P2]: <text> `[03-data-model.md]`

> Add categories as needed. Suggested: PRD inconsistencies, Tech stack & architecture, Data model, Flow & timing, Decisions, Constraints / sign-off / NFR / compliance, Overview & metrics.

## Source documents

- **PRD**: <filename / version / date YYYY-MM>
- **BRD**: <filename / version / date YYYY-MM>
- **Figma**: <URL or frame set name>
- **Other**: <existing system docs, etc.>

## Last updated

YYYY-MM-DD

> **Date format convention**: `Last updated` uses `YYYY-MM-DD` (precision). Decision dates / PRD version refs in other docs use `YYYY-MM` (sprint/version granularity).
