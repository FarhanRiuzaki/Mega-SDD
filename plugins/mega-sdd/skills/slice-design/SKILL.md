---
name: slice-design
version: 1.0.0
description: Standalone UI slicing — implement components from a design reference (Figma export, reference URL, or image file) and verify the render via the bundled Playwright MCP; works with or without a vault. Command-invocation only (/mega-sdd:slice) — this skill never auto-triggers off free text.
---

# Slice-Design — reference → UI code → verified render

**Announce at start:** "I'm using the slice-design skill to slice this reference into UI code. `mega-sdd-trace:slice-design`"

> **Instruction language:** this skill reasons in English. Narrate (announce, clarifying questions, the report summary) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). *(Greenfield-reachable: /mega-sdd:slice runs with no `.mega-sdd/` signal, so it carries the policy itself.)*

## When to use

ONLY via `/mega-sdd:slice` (or an explicit user request naming this skill). This skill is deliberately OUTSIDE the free-text census: a bare "slicing" sentence routes nowhere — the surface-cull containment decision (spec `docs/superpowers/specs/2026-08-12-playwright-embed-design.md`, on record).

## Inputs (at least one reference required)

- `--figma=<url>` — consumed via the user's own Figma MCP when its tools are present; when absent, ASK for an exported image instead (never scrape the URL).
- `--url=<web>` — reference site, captured via the bundled Playwright MCP.
- `--image=<path>` — exported design file (PNG/JPG/WebP).
- `--rounds=<n>` — compare-round override, hard cap 3.

## Procedure (full loop → `references/slice-procedure.md`)

1. **Reference intake** → component inventory. At most 3 clarifying questions (where in the repo, which route, which framework), each with keterangan per the OQ interaction rule.
2. **Implement** following the ACTIVE framework pack + the design-intelligence corpus (`plugins/mega-sdd/references/ui-design-heuristics.md`, `references/design-intelligence/{style-principles,ux-rules}.md`) — REUSE, never author new design knowledge. If a vault exists, its `design_system` tokens are optional enrichment; this skill **NEVER writes the vault or binding** — it is a code-emission verb only.
3. **Render-compare** (cap: 3 compare rounds): open the dev-server URL (`.mega-sdd/config.yaml` `preview_url:` or operator-supplied) via Playwright MCP → screenshot → model-judged compare vs the reference → iterate. NO pixel-diff tooling.
4. **Report** → `.mega-sdd/slices/<slug>/slice-report.md` (slug = kebab-case of the primary component/route): files created, reference mapping, remaining deltas (honest). When MCP/browser/server was absent, the report states literally that the render was NOT verified.

## Dev-server ownership (binding)

The dev server is OPERATOR-owned. This skill **NEVER starts, installs, or backgrounds a dev server** (unbounded-spawn + zombie class under Git Bash/EDR). Unreachable `preview_url` → compare rounds = 0 + the honest-skip statement — mirror of `capture-views.sh`'s "start it, then re-run" contract.

## Degradation

Playwright MCP absent/disabled/failed → code generation still happens from the reference; only the compare loop degrades (SKIP with the stated reason). A browser is NEVER load-bearing; nothing here gates.

## Outputs

```
<repo>/<framework-conventional component paths>   # the sliced UI code
<project>/.mega-sdd/slices/<slug>/slice-report.md # the honest report
```
