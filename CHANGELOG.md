# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] — 2026-05-08

### Added
- **Optional design-system coverage for UI projects.** When source documents (PRD / Figma via MCP / uploaded tokens files) explicitly contain design-system content, the vault now emits two new sections:
  - **`02-architecture.md > UI components & patterns`** sub-section under each UI layer. Components table (spec voice) + Patterns prose (guide voice — when-to-use rules). Triggered by `HAS_UI_COMPONENTS=true` flag from Step 2 detection.
  - **`06-constraints.md > Design system`** top-level section alongside Technical / Business / NFR. Three sub-blocks (Tokens / Accessibility / Voice & brand), each independently conditional on its specific flag.
- **Step 2 design-system content detection.** Skill scans all sources for explicit mentions of UI components, design tokens, a11y standards, and voice/brand rules. Persists four flags: `HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`. Flags drive Step 3 conditional generation.
- **Source merge rules** when multiple design-system sources are provided (Figma + tokens.json, multiple Figma URLs, etc.). Higher priority wins for the same value (Figma > tokens file > PRD-stated). Equal-precedence disagreement → emit `OQ-CN-{N} [P1]` with both quoted values; never silent pick.
- **Conditional UI/UX or FE Dev reading path** in `00-index.md`. Appears only when at least one of the new design-system sections is present.
- **Conditional design-system glossary entries** in `00-index.md` (design tokens, design system, WCAG, a11y, semantic HTML). Appear only when terms are used elsewhere in the vault.
- **Six new Step 4 self-check items** for design-system grounding. Apply only when at least one design-system section is present in the vault.

### Changed
- **Anti-hallucination rule extended** from v0.5's "no invented content within sections" to v0.6's "no invented sections." Section presence is determined by source coverage alone — `PROJECT_SHAPE` is NOT a trigger. Vault never auto-creates design-system sections because shape inference suggests UI. Vault never defaults to industry standards (WCAG 2.1 AA, Material Design, iOS HIG, Tailwind defaults) when sources are silent.
- **Push-back rules** gain explicit "design-system absence is acceptable" sub-section. Skill MUST NOT prompt the user for missing design-system sources. PRD silent on FE → vault silent on FE. No exception, no questioning.
- **`SKILL.md` frontmatter** version bumped 0.5.0 → 0.6.0.
- **`plugin.json`** and **`marketplace.json` plugins[0].version** bumped 0.5.0 → 0.6.0.

### Backward compatibility
- v0.5 vaults remain valid. No migration step.
- v0.6 for projects without design-system source coverage produces output **identical to v0.5**. The four detection flags simply stay `false` and no sections are added.
- v0.6 with full design-system coverage adds two sub-sections, one top-level section, one reading path, and up to five glossary entries — all conditional, all source-cited.

### Notes
- The four detection flags (`HAS_UI_COMPONENTS`, `HAS_TOKENS`, `HAS_A11Y`, `HAS_VOICE_BRAND`) are independent. A project might surface tokens but not components (e.g., PRD spells out brand colors but Figma is unavailable), and vice versa. Each flag is independently evaluated.
- Existing-codebase reconciliation for design system remains the downstream AI consumer's job. Vault generator never reads codebase, even when `IMPLEMENTATION_MODE=existing` and a design-system package exists in the repo.

## [0.5.0] — 2026-05-08

### Added
- **`PRD_STATUS=final|draft` flag (Step 0.6).** New mandatory step after implementation mode flag. Captures whether the source PRD/BRD is signed-off (`final`) or still in flux (`draft`). Drives gap-handling and push-back behavior throughout the workflow.
  - `final` → skill never pauses for clarification, even when gap count is large or PRD is contradictory. All ambiguities funnel into Open Questions roll-up. User triages OQ list with stakeholder offline, post-vault.
  - `draft` → existing behavior preserved. Skill pauses when gap count > 10, surfaces contradictions inline, asks for resolution before generating.
- **`PRD status` field in `00-index.md > Vault Lock Status`.** Surfaced to downstream AI consumers (Claude Code, Cursor) so they know the OQ list is the authoritative gap inventory under `final` mode.
- **PRD source file annotation.** `<filename> — FINAL | DRAFT` marker in Vault Lock Status PRD source line.

### Fixed
- **Tool name references for Claude Code distribution.** SKILL.md previously used Claude.ai sandbox API names that don't resolve under `/plugin install`:
  - `tool_search(query="figma")` → `ToolSearch` with `query: "figma"` or `query: "select:..."` syntax.
  - `ask_user_input_v0` → `AskUserQuestion`.
  - `present_files` → no tool needed in Claude Code (files already on disk after Step 3); fall back kept for Claude.ai sandbox.
  - `view` (template read) → `Read`.
- **Step 3 template path stale post-v0.4.0 restructure.** Plugin-installed skills no longer land at `~/.claude/skills/`. Updated to use `${CLAUDE_PLUGIN_ROOT}/skills/grand-design-spec/references/templates/` as the primary path. Manual-install and Claude.ai sandbox paths kept as fallbacks.
- **Push-back rules** restructured to clearly distinguish always-push-back cases (Figma missing, "just guess the rest", path mismatch) from `draft`-only cases (missing sections, contradictions, large gap count).
- **`03-data-model.md` template typo**: "follow project conventions Han already confirmed" → "follow project conventions you've already confirmed with the team".
- **`.gitignore`**: removed project-specific `mega-rencana-spec/` entry (test fixture leak).

### Changed
- **`marketplace.json`**: dropped redundant top-level `version` field. Marketplace itself isn't versioned; each plugin entry now owns its version (`plugins[].version: "0.5.0"`).
- **`plugin.json`** version bumped 0.4.0 → 0.5.0.
- **`SKILL.md` frontmatter** version bumped 0.4.0 → 0.5.0.
- **README "What happens next"** updated with the new PRD-status question.

### Notes
- `final` mode does NOT relax anti-hallucination guarantees. Skill still refuses "just guess the rest" — `final` only changes whether the skill pauses to ask stakeholder synchronously, not whether Claude can fill in blanks. Gaps remain Open Questions, never silently filled.
- For `final` mode contradictions, the skill writes OQ entries with both PRD quotes side-by-side so stakeholder can rule which is canonical without re-reading the original doc.

## [0.4.0] — 2026-05-08

### Changed
- **Repository restructured to Claude Code Plugin Marketplace format.** Added `.claude-plugin/marketplace.json` at repo root and `plugins/grand-design-spec/.claude-plugin/plugin.json` at plugin root. Skill files (`SKILL.md`, `references/templates/*.md`) moved to `plugins/grand-design-spec/skills/grand-design-spec/`. Marketplace catalog points to the plugin via relative path source `./plugins/grand-design-spec`.
- **Install flow.** Now installable via `/plugin marketplace add <gitlab-url>` + `/plugin install grand-design-spec@grand-design-spec` instead of manual `git clone` to `~/.claude/skills/`. Version pinning via `#v0.4.0` ref appended to the GitLab URL.
- **Plugin-level README** added at `plugins/grand-design-spec/README.md` (focused on what the plugin does + trigger phrases). Root `README.md` now describes the marketplace itself and installation across Claude Code, Claude.ai, and Claude API.
- **`SKILL.md` frontmatter** version bumped 0.3.0 → 0.4.0. No skill content changes — behavior identical to v0.3.0.

### Notes
- Existing users who installed via `git clone` to `~/.claude/skills/` should remove the old clone (`rm -rf ~/.claude/skills/grand-design-spec`) before installing via `/plugin install` to avoid duplicate skill registration.

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
