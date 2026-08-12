---
description: "Standalone UI slicing — implement components from a design reference (Figma export / reference URL / image file) and verify the render via the bundled Playwright MCP. Works with or without a vault; never writes vault or binding; never starts a dev server."
argument-hint: "[--figma=<url>] [--url=<web>] [--image=<path>] [--rounds=<n≤3>]"
---

Invoke the `mega-sdd:slice-design` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- `--figma=<url>`: design reference in Figma — used via the user's own Figma MCP when present; otherwise the skill asks for an exported image (never scrapes)
- `--url=<web>`: a reference site to slice from (captured via Playwright MCP)
- `--image=<path>`: an exported design image (PNG/JPG/WebP)
- `--rounds=<n>`: compare-round override; hard cap 3
- No reference argument at all → the skill asks for ONE (with keterangan), then proceeds

Hard rails:
- This verb NEVER writes the vault or binding — it is a code-emission surface only (adding it to a bound project never touches `.mega-sdd/` state beyond its own `slices/` report dir).
- The dev server is OPERATOR-owned — the skill never starts, installs, or backgrounds one; unreachable `preview_url` → code still generated, render honestly reported as NOT verified.
- A browser is never load-bearing: Playwright MCP absent/disabled → the compare loop SKIPs with a stated reason; nothing gates.
- Command-invocation only: free-text "slicing" phrases do NOT auto-route here (surface-cull containment, spec 2026-08-12).
