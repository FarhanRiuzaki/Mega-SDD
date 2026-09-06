# Slice procedure — the per-page loop (mega-sdd-extras)

## Contents

- [0. Resolve the core plugin (optional, degrade-never-halt)](#0-resolve-the-core-plugin-optional-degrade-never-halt)
- [1. Reference intake — one page](#1-reference-intake--one-page)
- [2. The Figma ladder: page → section → component](#2-the-figma-ladder-page--section--component)
- [3. Implementation rules](#3-implementation-rules)
- [4. Render-compare rounds (≤3)](#4-render-compare-rounds-3)
- [5. The report (always emitted)](#5-the-report-always-emitted)

## 0. Resolve the core plugin (optional, degrade-never-halt)

Installed plugins live at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — a relative `../mega-sdd/` from this plugin's root does NOT reach the core. Resolve it the way the core front-door wrapper does (`install-front-door.sh`, wrapper v2): **Run**

```bash
python3 - <<'EOF' 2>/dev/null || python - <<'EOF' 2>/dev/null || true
import json, os
p = os.path.expanduser("~/.claude/plugins/installed_plugins.json")
try:
    rows = json.load(open(p)).get("plugins", {}).get("mega-sdd@mega-sdd", [])
except Exception:
    rows = []
def key(r):
    v = [int(x) if x.isdigit() else 0 for x in str(r.get("version", "0")).split(".")]
    return (r.get("scope") == "user", v, r.get("lastUpdated", ""))
rows = sorted((r for r in rows if r.get("installPath")), key=key, reverse=True)
print(rows[0]["installPath"] if rows else "")
EOF
```

Non-empty → `CORE=<installPath>`; then Read on demand: `$CORE/references/ui-design-heuristics.md`, `$CORE/references/design-intelligence/style-principles.md`, `$CORE/references/design-intelligence/ux-rules.md`, the ACTIVE pack under `$CORE/references/framework-conventions/` (a project pack `<root>/.mega-sdd/packs/<framework>.md` wins over a same-named plugin pack), `$CORE/references/output-language.md`. Empty / unreadable → continue without them and write `core corpus: NOT READ (<reason>)` in the report. Never halt on this.

## 1. Reference intake — one page

- `--figma=<url>`: extract `fileKey` + `nodeId` from the URL (`…/design/<fileKey>/<name>?node-id=<a>-<b>` → nodeId `a:b`; a `/branch/<branchKey>/` URL uses the branchKey as fileKey). **No `node-id`** → `get_metadata(fileKey)` with no nodeId lists the top-level pages → ONE `AskUserQuestion` (keterangan per option: page name + what it seems to contain) → continue with that single node. Several nodes or "semua page" → refuse: *"satu page per jalan — jalankan lagi untuk page berikutnya."*
- Figma MCP absent (`ToolSearch query:"figma"` finds no `mcp__figma__get_design_context`) → ask for an exported image (never scrape figma.com) and continue on the image lane.
- `--image`: Read the image directly (multimodal) — layout regions, component types, typography scale, spacing rhythm, color roles. Tokens are NOT recoverable from pixels: the report carries `tokens: NOT AVAILABLE (image fallback) — values inferred`.
- `--url`: navigate via the core-bundled Playwright MCP (tools via ToolSearch), capture at 1280 and 390, treat the captures as the reference images (same token caveat).

## 2. The Figma ladder: page → section → component

1. **`get_metadata(fileKey, nodeId)`** — structure only (ids, layer types, names, positions, sizes). Cheap. Derive the section/component inventory of THIS page (navbar, hero, card grid, form, footer …). Use it to orient, never as a substitute for design context.
2. **Per section/component, top to bottom: `get_design_context(fileKey, nodeId, clientFrameworks=<detected>, clientLanguages=<detected>, skillNames="figma-design-to-code")`** — returns reference code (React + Tailwind flavored), asset download URLs, a screenshot, and hints. **Load the `figma-design-to-code` guidance BEFORE the first call** (Skill `figma:figma-design-to-code` when present; else the `skill://figma/figma-design-to-code/SKILL.md` MCP resource — then prefix `resource:` in `skillNames`). Honor its hint priority: Code Connect snippet > component docs > designer annotations > design tokens (CSS vars) > raw hex / absolute positioning. A response that is metadata-only because the node is too large → **descend to that node's children** (the ladder) — **never set `forceCode`**; on a timeout retry a smaller node; on an error STOP and read the message.
3. **`get_variable_defs(fileKey, <page nodeId>)`** — the page's variables (colors, type, spacing). Map them to the project's token system (CSS vars / theme file of the active stack; a vault's `design_system` block when one exists — enrichment only). Hardcode a raw value ONLY when the project has no token home, and record it under `tokens:`.
4. **`get_screenshot(fileKey, nodeId)`** — ONLY for the compare reference of §4 (URL + curl form, default `maxDimension` 1024; base64 only when no shell can fetch). Never the substitute for design context.

Assets: icons and images come back as exported asset URLs that expire in ~7 days — download and commit the exact bytes into the project's asset convention (or wire a dynamic image), size containers explicitly, and reuse a project icon component only when the glyph clearly matches. Never hand-write an `<svg>`.

## 3. Implementation rules

- Follow the ACTIVE framework pack conventions (file locations, naming, idioms) exactly as a bolt would; with no pack readable, mirror the surrounding code of the repo.
- Design floor from the core corpus (§0): tokens/spacing/typography per `ui-design-heuristics.md`; interaction + a11y floor per `design-intelligence/ux-rules.md`; composition per `style-principles.md`. REUSE the corpus — never author new design knowledge here.
- **Reuse-first**: before writing a component, check the project's existing components and, when present, `<root>/.mega-sdd/codebase/symbol-index.json` (core's reuse index). Never rebuild an existing button.
- The Figma reference code is a REFERENCE: adapt it to the project's language, framework, component library, and styling system; never paste React+Tailwind into a Blade/Vue/Razor project.
- Current docs beat trained recall: when Context7 MCP tools are available (core-bundled, via ToolSearch), consult current framework docs before writing against fast-moving/unfamiliar APIs; absent → proceed normally (never load-bearing).
- Never write anything under `.mega-sdd/` except `slices/<slug>/` — no vault, binding, units, bolts, or gate-state file.

## 4. Render-compare rounds (≤3)

Dev server = OPERATOR-owned: read `<root>/.mega-sdd/config.yaml` `preview_url:` (or the operator's URL). Unreachable / unset → rounds = 0, report `compare rounds: 0 — preview_url unreachable — render NOT verified`; **never start, install, or background a server** ("start it, then re-run" is the whole remedy). Per round: screenshot the implemented route at 1280 + 390 via the core Playwright MCP → compare against the Figma node screenshot (§2.4) or the reference image: layout fidelity, spacing, typography, color roles, interactive states → apply the deltas. Stop early on a match; after round 3 STOP and report the remaining deltas honestly. Playwright MCP absent → SKIP with the stated reason. Never claim a match that was not rendered.

## 5. The report (always emitted)

`.mega-sdd/slices/<slug>/slice-report.md` (slug = kebab-case of the Figma page/frame name, or of the primary component/route on the image/URL lanes):

```markdown
# Slice report — <slug> (<date>)

**Reference:** <figma url (fileKey / nodeId) | web url | image path>
**Lane:** figma-mcp | image-fallback | url
**core corpus:** READ (<installPath>) | NOT READ (<reason>)
**tokens:** figma variables (<n> mapped → <token home>) | vault design_system | NOT AVAILABLE (image fallback) — values inferred
**Compare rounds run:** <0-3> (<why 0 if 0 — e.g. "preview_url unreachable — render NOT verified">)

| Component | File(s) | Figma nodeId | Notes |
|---|---|---|---|
| <name> | <path> | <a:b> | <adapted from reference / reused project component X> |

**Remaining deltas:** <honest list, or "none observed at 1280/390">
```

A component with no Figma nodeId is never presented as "from the design". The report is a plugin artifact — it never lands in the user's source tree.
