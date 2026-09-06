---
name: slice-design
version: 0.1.0
description: "Standalone UI slicing — ONE Figma page or frame per invocation via the user's own Figma MCP (an exported image or a reference URL is the honest fallback) into framework-conventional UI code, render-checked through the mega-sdd Playwright MCP. Command-invocation only (/mega-sdd-extras:slice) — never auto-triggers off free text, never writes mega-sdd pipeline state, never starts a dev server."
---

# Slice-Design (extras) — one Figma page → UI code → verified render

**Announce at start:** "I'm using the slice-design skill (mega-sdd-extras) to slice this page into UI code. `mega-sdd-trace:slice-design`"

> **Instruction language:** this skill reasons in English. Narrate (announce, clarifying questions, the report summary) in **natural Indonesian + English technical terms by default** — light, not stiff; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English. *(Greenfield-reachable: `/mega-sdd-extras:slice` runs with no `.mega-sdd/` signal, so it carries the policy itself; the full census lives in the core plugin's `references/output-language.md`, read when core resolves — §Core resolution.)*

## When to use

ONLY via `/mega-sdd-extras:slice` (or an explicit user request naming this skill). This skill is deliberately OUTSIDE any free-text census: a bare "slicing" sentence routes nowhere — the containment decision from the core surface cull (spec `docs/superpowers/specs/2026-08-12-playwright-embed-design.md` D1, re-affirmed for extras in `docs/superpowers/specs/2026-09-06-mega-sdd-extras-slice-design.md` §3.6).

## Why per-page, why Figma MCP (the two changes vs the 6.8.0 skill)

The team's field attempt (triage 2026-08-23 §Item 2) sliced **4 pages in one batch from PNG exports**: the batch was the source of weight and latency, and the PNG rasterization lost the design tokens (spacing / color roles / typography / component identity) — which is why details drifted. So:

1. **One page per invocation** (§Inputs). Page → section → component is a LADDER inside that page, never a multi-page swallow.
2. **Figma MCP direct is the primary lane** (`references/slice-procedure.md §2`): `get_metadata` → `get_design_context` per section/component → `get_variable_defs`. An image is only the fallback, and its report must say `tokens: NOT AVAILABLE (image fallback) — values inferred`.

## Inputs (exactly ONE reference per run)

- `--figma=<url>` — MUST carry a `node-id` (page or frame). Without one: `get_metadata(fileKey)` lists the top-level pages → ONE `AskUserQuestion` "page/frame yang mana?" with keterangan per option → proceed on that one node. Several nodes / "do all pages" → REFUSE: *"satu page per jalan — jalankan lagi untuk page berikutnya."* Figma MCP absent in the session (probe: `ToolSearch query:"figma"` finds no `mcp__figma__get_design_context`) → ask for an exported image instead (never scrape figma.com).
- `--image=<path>` — exported design file (PNG/JPG/WebP). Fallback lane.
- `--url=<web>` — reference site, captured via the mega-sdd Playwright MCP at 1280 + 390.
- `--rounds=<n>` — compare-round override, hard cap 3.
- No reference at all → ask for ONE (with keterangan), then proceed.

## Core resolution (read-only, degrade-never-halt)

This plugin ships **no** hooks, scripts, or MCP servers. It REUSES the core `mega-sdd` plugin's design corpus, framework packs, and bundled Playwright/Context7 MCPs. Installed plugins live in per-plugin cache dirs, so the core is located by the same rule the front-door wrapper uses (`references/slice-procedure.md §0`): read `~/.claude/plugins/installed_plugins.json` → `plugins["mega-sdd@mega-sdd"]` → the `scope: "user"` entry with the HIGHEST version → its `installPath`. Core unresolved/unreadable → keep going without the corpus and say so in the report (`core corpus: NOT READ (<reason>)`). Nothing here gates.

## Procedure (full loop → `references/slice-procedure.md`)

0. **Resolve core** (§0) — path to `references/ui-design-heuristics.md`, `references/design-intelligence/{style-principles,ux-rules}.md`, `references/framework-conventions/`, `references/output-language.md`. Optional; recorded either way.
1. **Intake — the per-page ladder** (§1–§2): Figma → `get_metadata` (structure) → component inventory → per section/component `get_design_context` (reference code + assets + screenshot; **load the `figma-design-to-code` guidance first** — Skill `figma:figma-design-to-code` when present, else the `skill://figma/figma-design-to-code/SKILL.md` MCP resource — and pass it in `skillNames`) → `get_variable_defs` on the page node (tokens). A node that comes back metadata-only (too large) → descend to its children; **never set `forceCode`**. Image/URL → multimodal read of the image / Playwright captures.
2. **Clarify (≤ 3 questions, each with keterangan):** target location in the repo, target route/page, framework confirmation only when detection is ambiguous. Sensible defaults over questions.
3. **Implement** (§3): follow the ACTIVE framework pack exactly as a bolt would (project pack `.mega-sdd/packs/*.md` beats the plugin pack); design floor from the core corpus; project tokens beat raw values (Figma variables → the project's token system → vault `design_system` when a vault exists — enrichment only); **reuse-first** (existing components + `.mega-sdd/codebase/symbol-index.json` when present); the Figma reference code is ADAPTED, never pasted; icons/images from the exported assets, never hand-drawn SVG. Context7 (core-bundled) for fast-moving framework APIs — never load-bearing.
4. **Render-compare** (§4, ≤ 3 rounds): the OPERATOR-owned dev server (`.mega-sdd/config.yaml` `preview_url:` or operator-supplied) → Playwright MCP screenshot at 1280 + 390 → model-judged compare vs the Figma node screenshot (`get_screenshot`, URL+curl form) or the reference image → apply deltas → stop early on match; after round 3 STOP and report. No pixel-diff tooling.
5. **Report** (§5) → `.mega-sdd/slices/<slug>/slice-report.md` with the **component → file → Figma nodeId** table (every UI piece traces to its node; no node = not claimed as designed), the `tokens:` line, compare rounds run, remaining deltas — honest. When MCP/browser/server was absent, the report states literally that the render was NOT verified.

## Hard rails

- **One page per invocation** — refuse batches (the measured root of the team's pain).
- **Never writes mega-sdd pipeline state**: no vault, binding, units, bolts, or gate-state file is touched; the ONLY artifact is the slice report under `.mega-sdd/slices/`. Reads of a vault's `design_system` are enrichment only.
- **The dev server is OPERATOR-owned** — this skill **never starts, installs, or backgrounds a dev server** (unbounded-spawn + zombie class under Git Bash/EDR). Unreachable `preview_url` → compare rounds = 0 + the honest-skip statement.
- **A browser is never load-bearing** — Playwright MCP absent/disabled/failed → code generation still happens; only the compare loop degrades (SKIP with the stated reason). Nothing gates.
- **No fabrication from a screenshot when context exists** — when `get_design_context` can still answer, never fall back to hand-writing the screen from the image alone; on a tool error STOP and read the message; on a timeout retry a smaller node.
- **Honesty lines are mandatory in the report**: `tokens:` source, `core corpus:` read or not, `compare rounds:` count with reason when 0.

## Outputs

```
<repo>/<framework-conventional component paths>   # the sliced UI code
<project>/.mega-sdd/slices/<slug>/slice-report.md # the honest report (slug = kebab-case page/frame name)
```

## Related

- Core plugin `mega-sdd` (same marketplace) — the corpus, packs, and MCPs this skill reuses; `references/paths.md` lists the `slices/` artifact home.
- Spec: `docs/superpowers/specs/2026-09-06-mega-sdd-extras-slice-design.md`.
