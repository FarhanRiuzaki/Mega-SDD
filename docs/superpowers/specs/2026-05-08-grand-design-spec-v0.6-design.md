# grand-design-spec v0.6 — Design System Coverage

**Date**: 2026-05-08
**Status**: Spec — awaiting plan
**Author**: Farhan Riuzaki + Claude (Opus 4.7) via brainstorming session
**Target version**: 0.6.0

---

## Background

Current vault (v0.5.0) outputs 7 markdown files optimized for AI dev consumers (Cursor, Claude Code) — table-driven, fact-only, anti-hallucination by construction. It serves backend / system architecture well. It does **not** serve FE devs or UI/UX reviewers — there is no place in the vault for design tokens, UI components, interaction patterns, or accessibility rules.

Trigger: project use cases increasingly include UI-heavy products (mobile-app, web-app, multi-platform). When the next FE dev joins mid-project or at kickoff, the vault is silent on the design system. They re-derive it from Figma + ad-hoc Slack threads.

## Goals

1. Extend vault to cover design system content (tokens, components, patterns, a11y) **when the project has UI**.
2. Keep the human-primary, AI-secondary stance (decided in brainstorm). Spec voice for tech sections; guide voice for design-system sections only.
3. Stay within the 7-file cap. No new files.
4. Stay backward compatible. Existing v0.5 vaults remain valid; non-UI shapes get identical output to v0.5.
5. Preserve anti-hallucination guarantees. Design tokens / components / patterns must cite source (Figma / tokens file / PRD) — never invent.

## Non-goals

- No tone rewrite of existing tech sections. Spec voice stays for 02-architecture (non-UI parts), 03-data-model, 04-flows, 05-decisions, 06-constraints (non-design parts).
- No new mandatory step in the workflow. Reuse `PROJECT_SHAPE`.
- No expansion to >7 files. Concentrate within existing structure.
- No support for design system as a standalone shape (e.g., "design-system-only" shape). Out of scope.
- No interaction with 04-flows.md beyond cross-ref. Flow steps may reference UI components via anchor link, no new flow content.
- No motion / animation specs as first-class content. If PRD specifies, captured under "Patterns" prose.

## Audience

Primary: human FE dev / UI-UX reviewer joining at kickoff or mid-project.
Secondary: AI dev consumer (Cursor / Claude Code) using vault to implement UI.
Tertiary: PM, architect, QA reviewing the design layer.

## Design

### A. Workflow & extraction (skill-side)

#### A.1 No new mandatory step

Reuse `PROJECT_SHAPE` (Step 2 confirmation). Branch on whether shape has UI:

- **UI shapes** (`mobile-app`, `web-app`, `multi-platform`) → design system sections appear in templates.
- **Non-UI shapes** (`api-only`, `data-pipeline`) → design system sections absent.
- **`custom`** → skill asks user during shape elaboration whether the custom project has UI; if yes, treat as UI-shape branch.

#### A.2 New optional input (Step 1 — Inventory and read)

When shape has UI, skill asks once during inventory:

> "Project punya UI. Lo punya design system source? (a) Figma URL with variables, (b) tokens file path (tokens.json / tailwind.config.js / Storybook export), (c) PRD spells out tokens, (d) none — semua jadi Open Questions."

Multiple sources allowed (e.g. Figma + tokens.json). When sources conflict, follow merge rules in A.3.

#### A.3 Source extraction priority

When multiple sources are available, **higher priority wins for the same token/component**. When a higher-priority source is silent on a value but a lower-priority source has it, use the lower one. **When two sources of equal precedence disagree (e.g., two Figma URLs, or Figma + tokens.json with different hex for `color.primary`), do NOT silently pick — emit an OQ with both quoted values side-by-side.**

1. **Figma MCP** (highest priority) — call `mcp__claude_ai_Figma__get_variable_defs` on the Figma URL/node-id to extract color/typography/spacing tokens. Call `get_design_context` to extract component definitions and frame inventory. Already wired via existing Figma MCP integration in v0.5.0.
2. **User-provided tokens file** — read directly via `Read` tool. Common formats: `tokens.json` (W3C design tokens), `tailwind.config.js`, Storybook export, design-system repo path.
3. **PRD-stated** — extract verbatim if PRD explicitly states ("use brand color #1A73E8 for CTAs"). Rare but supported.
4. **None** (lowest) → all design-system content for that token/component becomes Open Questions tagged `OQ-AR-{N}` (components) and `OQ-CN-{N}` (tokens / a11y / brand).

**Multi-platform note**: for `multi-platform` shape, Web and Mobile may have separate Figma projects / token files. Skill asks for sources per platform, treats them independently per layer (Web layer reads Web sources; Mobile layer reads Mobile sources). Cross-platform shared tokens (e.g., brand color used in both) are surfaced under the parent `06-constraints#design-system` section once; per-platform divergences (e.g., spacing scale differences) are flagged as `OQ-CN-{N} [P2]`.

**Existing-mode note**: skill does NOT read the codebase. Even if `IMPLEMENTATION_MODE=existing` and the codebase already has a design system implemented (e.g., a `design-system/` package), the vault reflects only PRD/Figma/tokens file sources. Reconciling vault with existing-codebase design system is the downstream AI consumer's job (instructed via `00-index.md > Implementation Notes for AI Consumers`, no change needed in v0.6).

#### A.4 Push-back rule (new in v0.6)

If shape has UI but no Figma + no tokens file + no PRD design specs → skill MUST ask user before generating:

> "Project punya UI tapi gue gak punya akses ke design system source apapun. Lo kasih reference (Figma URL / tokens.json / Storybook), atau gue dump semuanya ke Open Questions?"

Never invent tokens, components, or patterns. Existing anti-halu rule preserved.

### B. Template structure

Three template files change. One file reachable via cross-ref but unchanged. Three files unchanged.

| File | Change |
|------|--------|
| `00-index.md` | Add UI/UX or FE Dev reading path; glossary entries for design tokens, design system, WCAG, a11y |
| `01-overview.md` | Unchanged |
| `02-architecture.md` | Add "UI components & patterns" sub-section under existing UI layer (conditional on shape) |
| `03-data-model.md` | Unchanged |
| `04-flows.md` | Unchanged. Flow steps may cross-ref `02-architecture#ui-components` — uses existing cross-ref budget |
| `05-decisions.md` | Unchanged |
| `06-constraints.md` | Add "Design system" category alongside Technical / Business / NFR (conditional on shape) |

#### B.1 `02-architecture.md` — new sub-section

Appears under existing UI layer (`### Mobile / Frontend` or `### Web Frontend`). For `multi-platform`, appears under both Mobile and Web layers (each may have shape-specific patterns).

```markdown
#### UI components & patterns

> Muncul kalau PROJECT_SHAPE punya UI + design system source tersedia.
> Source: Figma frame inventory, Storybook export, PRD-stated.

| Component | Purpose                | Variants                       | Source        |
|-----------|------------------------|--------------------------------|---------------|
| Button    | Primary action         | primary / secondary / ghost    | Figma "Btn/*" |
| Modal     | Blocking confirmation  | confirm / form / fullscreen    | Figma "Modal" |

**Patterns** (when-to-use rules — guide voice):

- **Primary CTA**: max 1 per screen, use `primary` variant.
- **Destructive actions**: always `destructive` variant + confirmation modal (cross-ref F-U-005).
- **Mobile forms > 3 fields**: bottom sheet, not modal.

**Tokens used**: lihat `06-constraints.md#design-system`.
```

**Voice mix**: Components table = spec voice (data is data). **Patterns** block = guide voice (when-to-use prose). This is the only place guide voice appears in 02-architecture.

#### B.2 `06-constraints.md` — new category

Appears as a new top-level section alongside "Technical constraints", "Business constraints", "Non-functional requirements".

```markdown
## Design system

> Muncul kalau PROJECT_SHAPE punya UI. Source: Figma variables, tokens file, atau PRD.

### Tokens

**Color**:
| Token         | Value    | Use case                              |
|---------------|----------|---------------------------------------|
| color.primary | #1A73E8  | CTA, active states, brand accents     |
| color.danger  | #E53935  | Destructive actions, errors           |

**Typography**: `font.display` 'Inter Bold 32/40' · `font.body` 'Inter Regular 16/24'
**Spacing scale**: 4 / 8 / 16 / 24 / 32 / 48 / 64 (px). Increments of 8 only.
**Radius**: 4 / 8 / 16 (px).

### Accessibility

- WCAG 2.1 AA minimum (or PRD-stated level).
- Color contrast: text ≥ 4.5:1, large text ≥ 3:1.
- All interactive elements keyboard-reachable. Screen reader: semantic HTML required.

### Voice & brand (light)

- Tone: <from PRD or "TBD with PO">
- User-facing locale: <from PRD>
```

**Voice mix**: Tokens table = spec voice. Headers/intro/Patterns = guide voice. Voice & brand block = guide voice (it's editorial guidance).

#### B.3 `00-index.md` — small additions

- **Reading paths** gain new role (only when shape has UI):
  - `**UI/UX or FE Dev**: 01-overview → 02-architecture#ui-components → 06-constraints#design-system → 04-flows`
- **Glossary** entries (only when shape has UI): design tokens, design system, WCAG, a11y, semantic HTML.
- No new top-level section in 00-index.

### C. Quality gates, OQ tagging, version

#### C.1 Step 4 self-check additions (UI shapes only)

- [ ] Components table in `02-architecture#ui-components` cites source (Figma frame name / tokens file path / PRD §). No invented components.
- [ ] Tokens table in `06-constraints#design-system` cites source. No invented hex values, type scales, or spacing values.
- [ ] Patterns prose grounded in PRD note / Figma annotation / explicit user instruction. No "best practice" insertions.
- [ ] If design system source unavailable for any sub-section → that sub-section's content is OQ, not body.

#### C.2 OQ tagging — no new doc codes

- Component gaps → `OQ-AR-{N}` (existing 02-architecture doc code).
- Token / a11y / brand gaps → `OQ-CN-{N}` (existing 06-constraints doc code).
- 00-index OQ roll-up gains a likely category: "Design system". Default priority P1 if blocking FE dev, else P2.

#### C.3 Version & release notes

- Bump to `0.6.0` (minor — additive, backward compatible).
- CHANGELOG headline: "Adds optional design-system coverage for UI shapes. New 'UI components & patterns' sub-section in 02-architecture and 'Design system' category in 06-constraints. Conditional on PROJECT_SHAPE having UI. Source priority: Figma MCP → user tokens file → PRD → Open Questions."

#### C.4 Backward compatibility

- v0.5 vaults remain valid. No migration step.
- v0.6 for non-UI shapes → output identical to v0.5. No design-system content appears.
- v0.6 for UI shapes without design source → design-system sections present, body is OQ-driven. Anti-halu preserved.
- Frontmatter version bump: `0.5.0` → `0.6.0` in SKILL.md, plugin.json, marketplace.json (per-plugin).

## Affected files (scope)

| File | Type of change |
|------|----------------|
| `plugins/grand-design-spec/skills/grand-design-spec/SKILL.md` | Edit — Step 1 input prompt, Step 2 shape-branching, Step 4 self-check, push-back rules, version bump |
| `plugins/grand-design-spec/skills/grand-design-spec/references/templates/00-index.md` | Edit — reading paths, glossary |
| `plugins/grand-design-spec/skills/grand-design-spec/references/templates/02-architecture.md` | Edit — new "UI components & patterns" sub-section markup with conditional comment |
| `plugins/grand-design-spec/skills/grand-design-spec/references/templates/06-constraints.md` | Edit — new "Design system" category with conditional comment |
| `plugins/grand-design-spec/.claude-plugin/plugin.json` | Edit — version 0.5.0 → 0.6.0 |
| `.claude-plugin/marketplace.json` | Edit — `plugins[0].version` 0.5.0 → 0.6.0 |
| `CHANGELOG.md` | Edit — add 0.6.0 entry |
| `README.md` | Edit — version pin example, "What you get" section to mention design system for UI shapes |

Files unchanged: `01-overview.md`, `03-data-model.md`, `04-flows.md`, `05-decisions.md` templates.

## Open questions for the spec

- **OQ-SPEC-1** [P2]: For `multi-platform` shape, should "UI components & patterns" sub-section appear once (consolidated) or twice (under each of Web Frontend and Mobile layers)? **Working assumption**: twice — patterns may differ between web and mobile (e.g., bottom sheet vs modal). User can override at generation time if both share components.
- **OQ-SPEC-2** [P3]: Should `tokens.json` parsing handle W3C draft Design Tokens spec specifically, or accept any flat key-value JSON? **Working assumption**: accept any reasonable JSON shape, document key extraction heuristics in SKILL.md (look for `color.*`, `font.*`, `spacing.*`, `radius.*` patterns; flag unknown keys as OQ).
- **OQ-SPEC-3** [P3]: Motion / animation specs — out of scope per non-goals, but if PRD spells out specific animations (e.g., "modal slide-up 200ms ease-out"), where do they go? **Working assumption**: under "Patterns" block in 02-architecture#ui-components, prose-form. Don't promote motion to first-class section.

## Out of scope (for v0.6)

- Tone rewrite of existing tech sections.
- New project shape for "design-system-only" projects.
- Motion / animation as first-class section.
- Auto-detection of design system source (skill always asks user).
- Token diff between Figma and tokens file when both provided (skill picks Figma if both, notes the conflict as OQ).
- Component implementation snippets (React / Vue / Flutter code). Vault still describes contracts, not code.
- Generation of Storybook stories or component scaffolds. Those belong to downstream AI dev consumer.

## Source for this spec

This spec was produced via `superpowers:brainstorming` skill on 2026-05-08. Decisions traced to user answers:

- Direction: **Hybrid — dev guide + light UI patterns** (max 7 files locked).
- Primary reader: **Both, with human as primary**.
- Scenario: **Both kickoff and existing-codebase enhancement**.
- Tone: **Spec voice for tech sections, guide voice for design-system sections only**.
- Distribution approach: **A — Split: components in 02, tokens/rules in 06**.

---

## Next step

Invoke `superpowers:writing-plans` skill to break this spec into an executable implementation plan. Implementation will be a single focused PR producing v0.6.0 with the file changes listed above.
