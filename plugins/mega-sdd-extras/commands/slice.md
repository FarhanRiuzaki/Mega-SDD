---
description: "Standalone UI slicing — ONE Figma page/frame per invocation (via your own Figma MCP; image or reference URL as the honest fallback) into framework-conventional UI code, render-checked through the mega-sdd Playwright MCP. Never writes mega-sdd pipeline state; never starts a dev server; one page per run."
argument-hint: "--figma=<url-with-node-id> | --image=<path> | --url=<web>  [--rounds=<n≤3>]"
---

Invoke the `mega-sdd-extras:slice-design` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- `--figma=<url>`: the Figma page or frame to slice — the URL MUST carry a `node-id`; without one the skill lists the file's pages (`get_metadata`) and asks which ONE to slice. Used through the user's own Figma MCP; when that MCP is absent in this session the skill asks for an exported image instead (never scrapes figma.com).
- `--image=<path>`: an exported design image (PNG/JPG/WebP) — the FALLBACK lane; design tokens are not available on it and the report says so.
- `--url=<web>`: a reference site to slice from (captured via the mega-sdd Playwright MCP).
- `--rounds=<n>`: compare-round override; hard cap 3.
- No reference argument at all → the skill asks for ONE (with keterangan), then proceeds.

Hard rails:
- **One page per invocation.** A URL naming several nodes, or a request to batch pages, is refused with "satu page per jalan — jalankan lagi untuk page berikutnya" (the batch was the measured source of weight and latency).
- This verb NEVER writes mega-sdd pipeline state (no vault, binding, units, bolts) — it is a code-emission surface only; its sole artifact is `.mega-sdd/slices/<slug>/slice-report.md`.
- The dev server is OPERATOR-owned — the skill never starts, installs, or backgrounds one; unreachable `preview_url` → code still generated, render honestly reported as NOT verified.
- A browser is never load-bearing: Playwright MCP absent/disabled → the compare loop SKIPs with a stated reason; nothing gates.
- Command-invocation only: free-text "slicing" phrases do NOT auto-route here (surface-cull containment, spec 2026-08-12 D1 + spec 2026-09-06 §3.6).
