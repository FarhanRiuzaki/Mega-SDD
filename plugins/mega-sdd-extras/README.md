# mega-sdd-extras

Optional companion plugin to [`mega-sdd`](../mega-sdd/README.md), same marketplace, separate install. One verb:

```
/mega-sdd-extras:slice --figma=<url-with-node-id>
/mega-sdd-extras:slice --image=./design/dashboard.png     # fallback lane (no design tokens)
/mega-sdd-extras:slice --url=https://example.com/pricing  # reference-site lane
```

**What it does:** slices **one Figma page or frame per run** into framework-conventional UI code through your own Figma MCP (`get_metadata` → `get_design_context` per section → `get_variable_defs`), reuses the project's components and tokens, optionally render-checks the result through the mega-sdd Playwright MCP against the Figma screenshot (≤ 3 compare rounds), and writes an honest report at `.mega-sdd/slices/<slug>/slice-report.md` with a component → file → Figma nodeId table.

**Why per-page and why Figma MCP:** the team's field attempt batched four pages from PNG exports — the batch was the source of weight and latency, and the rasterized PNG lost the design tokens, which is why details drifted (triage 2026-08-23 §Item 2). Images stay available as the fallback lane; their report says `tokens: NOT AVAILABLE`.

## Install

```
/plugin marketplace add https://scm.bankmegadev.com/ai-rnd/mega-sdd.git   # once, if not already
/plugin install mega-sdd-extras
```

Requires the core `mega-sdd` plugin to be installed from the same marketplace for the design corpus, framework packs, and the bundled Playwright/Context7 MCPs (it is located through `~/.claude/plugins/installed_plugins.json`; when it cannot be found the skill still runs and the report says `core corpus: NOT READ`). Figma access is **your own** Figma MCP (this plugin bundles none).

## What it never does

- never auto-triggers off free text — `/mega-sdd-extras:slice` only;
- never writes mega-sdd pipeline state (vault, binding, units, bolts, gate states);
- never starts, installs, or backgrounds a dev server (`preview_url` is operator-owned);
- never batches pages; never sets `forceCode`; never hand-draws icons;
- ships zero hooks, zero scripts, zero MCP servers — nothing runs unless you invoke the verb.

## Gateway

The announce line ends with `` `mega-sdd-trace:slice-design` `` per the core gateway contract (`docs/gateway-contract.md`).

Spec: `docs/superpowers/specs/2026-09-06-mega-sdd-extras-slice-design.md`. Changes: [`CHANGELOG.md`](CHANGELOG.md).
