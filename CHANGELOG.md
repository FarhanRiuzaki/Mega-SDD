# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] — 2026-05-08

### Added
- **Project Shape Registry** in `SKILL.md`. 5 pre-templated shapes (`mobile-app`, `web-app`, `api-only`, `multi-platform`, `data-pipeline`) + `custom` fallback. Skill is now general-purpose, not biased toward mobile banking.
- **Step 2 — Project shape inference + confirmation**. Skill infers shape from PRD content using heuristics, presents reasoning to user, asks for confirm/override. Custom shape triggers user-described layers.
- **`PROJECT_SHAPE` flag** persisted alongside `IMPLEMENTATION_MODE`, drives sub-section structure in `02-architecture.md`, `04-flows.md`, and reading paths in `00-index.md`.
- **Project shape field** in `00-index.md > Vault Lock Status`.
- **Shape-aware Implementation Notes for AI Consumers** in `00-index.md` — instructs AI consumer to confirm both shape AND mode before code work, and to use the relevant layer section based on what's being implemented.

### Changed
- **`02-architecture.md` template** is now shape-agnostic. Layer sub-sections derived from `PROJECT_SHAPE`, not hardcoded "Mobile / Backend / Integrations".
- **`04-flows.md` template** is now shape-agnostic. Flow type sub-sections derived from `PROJECT_SHAPE`. Flow ID prefixes (`F-U-`, `F-S-`, `F-C-`, `F-P-`, `F-X-`) documented for use across shapes.
- **Reading paths in `00-index.md`** are now shape-conditional. Common patterns documented for each pre-templated shape.

### Fixed
- Removed mobile-banking bias. Skill no longer assumes UI exists, no longer hardcodes "Mobile" as a layer, no longer assumes user flows are mobile-facing.

## [0.2.0] — 2026-05-08

### Added
- **Step 0.5 — Implementation mode flag (simplified)**. Skill asks `new` vs `existing` — flag-only, no codebase reference. Mode is metadata that drives downstream AI consumer behavior.
- **`00-index.md > Vault Lock Status`**. Records vault version, lock timestamp, sign-off, status (DRAFT vs LOCKED), and PRD source. Vault locks against requirement, not codebase.
- **`00-index.md > Changelog`**. Tracks vault revisions per PRD update.
- **`00-index.md > Implementation Notes for AI Consumers`**. Explicit instructions for downstream AI dev tools (Claude Code, Cursor) on what to verify with user before writing/modifying code, especially in `existing` mode (cross-check entities/flows/decisions vs existing codebase).
- **Per-layer addressability in `02-architecture.md`**. Sub-sections `### Mobile / Frontend`, `### Backend`, `### Integrations` so each role can deep-link.
- **Per-type addressability in `04-flows.md`**. Sub-sections `### User flows (mobile-facing)`, `### Backend / system flows`, `### Cross-cutting flows`.
- **Deep-link reading paths in `00-index.md`**. Reading paths now use anchor links (e.g. `02-architecture.md#backend`).

### Changed
- Vault structure remains 7 files regardless of mode. Mode flag drives content of `00-index.md > Implementation Notes for AI Consumers`, not file count.
- Anti-halu rules clarified: vault locks **requirement**, not codebase. Codebase reconciliation is the AI consumer's job, instructed via Implementation Notes.

### Removed (vs 0.2.0-alpha conceptual draft, never released)
- `07-integration.md` was conceptually drafted in v0.2.0-alpha and dropped before stable release. Integration mapping to existing codebase belongs to AI consumer at consumption time, not to vault generator.
- Step 0.5 no longer asks for codebase reference (repo URL, local path).

## [0.1.0] — 2026-05-08

### Added
- Initial skill release.
- 7 file vault output: `00-index.md`, `01-overview.md`, `02-architecture.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md`, `06-constraints.md`.
- Anti-hallucination by construction: every claim must cite source, ambiguities flagged as Open Questions, Out of Scope explicit.
- Step 0 — Output path setup with cross-platform handling (sandbox detection, alien path warning, mkdir variants for Mac/Linux/WSL/Windows).
- Step 1 — Environment-aware input file detection (sandbox vs local Claude Code).
- Step 2 — Extract before writing with gap threshold (>10 → ask).
- Step 3 — Generate with template scaffolding from `references/templates/`.
- Step 4 — Self-check with grounding, readability, simplicity, output integrity verification.
- Step 5 — Present with top blocker surfacing.
- TL;DR header (3 lines: what / for whom / when to read) on every numbered doc.
- Open Question tagging: `OQ-{DOC_CODE}-{N}` with priority `[P1|P2|P3]`.
- 00-index sections: Executive Summary, Project Readiness Status, Reading paths by role, Glossary, OQ roll-up.
- Length & simplicity policy: simple by default; only `04-flows.md` may be complete-wajar.
- Readability standards: EN/ID convention (code EN, prose ID), anti-AI-tone read-aloud test, glossary mandate, cross-ref budget, date format convention.
- Push-back behavior: refuses "just guess the rest" requests, offers to mark as Open Questions instead.
- Templates for all 7 numbered docs.
- README.md with installation instructions for Claude Code (personal & project), Claude.ai/Desktop (zip upload), and Claude API.
- MIT License.
