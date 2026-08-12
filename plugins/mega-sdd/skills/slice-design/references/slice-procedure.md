# Slice procedure — the detailed loop

## 1. Reference intake

- `--image` / Figma-export image: Read the image directly (multimodal) — extract layout regions, component types, typography scale, spacing rhythm, color roles.
- `--url`: navigate via Playwright MCP (tools loaded on demand through ToolSearch), capture at 1280 and 390 widths, then treat the captures as the reference images.
- `--figma=<url>`: if the user's session has Figma MCP tools (`mcp__figma__get_design_context` / `get_screenshot`), use them for the design context; otherwise ASK for an exported image (never scrape figma.com).

## 2. Component inventory + clarifying questions

Derive the component list (e.g. navbar, hero, card grid, form). Ask AT MOST 3 questions via AskUserQuestion, each with keterangan (Indonesian, per the OQ rule): target location in the repo, target route/page, framework confirmation when detection is ambiguous. Sensible defaults over questions — an existing framework pack + obvious component dir needs zero questions.

## 3. Implementation rules

- Follow the ACTIVE framework pack conventions (file locations, naming, idioms) exactly as a bolt would.
- Design floor comes from the corpus: tokens/spacing/typography per `ui-design-heuristics.md`; interaction + a11y floor per `design-intelligence/ux-rules.md`; composition per `style-principles.md`.
- Vault `design_system` tokens (when a vault exists): prefer them over invented values — enrichment only, no vault read is required to proceed.
- Reuse-first: check the symbol index / existing components before authoring a new one (never rebuild an existing button).
- Current docs beat trained recall: when Context7 MCP tools are available (ToolSearch), consult the current framework docs before writing against fast-moving/unfamiliar APIs; absent → proceed normally (never load-bearing).

## 4. Render-compare rounds (≤3)

Per round: screenshot the implemented route at 1280 + 390 via Playwright MCP → compare against the reference (layout fidelity, spacing, typography, color roles, states) → apply the deltas. Stop early when the render matches; after round 3, STOP and report the remaining deltas honestly. Never claim a match that was not rendered.

## 5. The report (always emitted)

`.mega-sdd/slices/<slug>/slice-report.md`:

```markdown
# Slice report — <slug> (<date>)

**Reference:** <figma url | web url | image path>
**Files created/modified:** <list>
**Compare rounds run:** <0-3> (<why 0 if 0 — e.g. "preview_url unreachable — render NOT verified">)
**Reference mapping:** <component → file table>
**Remaining deltas:** <honest list, or "none observed at 1280/390">
```

The report is a plugin artifact — it never lands in the user's source tree.
