# Changelog — mega-sdd-extras

Separate from the core `mega-sdd` changelog (the repo-root `CHANGELOG.md` tracks the core plugin; its CI parity check anchors the core manifests to that file's newest tag).

## [0.1.0] - 2026-09-06 — slice-design revived as a separate plugin (per-page, Figma MCP direct)

Spec `docs/superpowers/specs/2026-09-06-mega-sdd-extras-slice-design.md` P0 (owner APPROVE 2026-09-06). Evidence: team-feedback triage 2026-08-23 §Item 2 — a real design→code user; the 4-page batch was the latency source; PNG exports lost the design tokens.

### Added
- `/mega-sdd-extras:slice` → skill `slice-design` (revived from core `d4f82c7^`, removed there in v7.4.0) with two changes: **one page/frame per invocation** (batches refused; page → section → component ladder inside the page) and **Figma MCP direct as the primary lane** (`get_metadata` → `get_design_context` per section with the `figma-design-to-code` guidance loaded first → `get_variable_defs`; `get_screenshot` only as the compare reference; never `forceCode`). Image / reference-URL lanes stay as the honest fallback (`tokens: NOT AVAILABLE`).
- Core located through `~/.claude/plugins/installed_plugins.json` (the front-door wrapper-v2 rule) — installed plugins live in per-plugin cache dirs, so no relative path can reach the core; unresolved → degrade, never halt.
- Report gains the component → file → Figma nodeId table (every UI piece traces to its node) and three mandatory honesty lines (`tokens:`, `core corpus:`, `compare rounds:`).
- Zero hooks, zero scripts, zero `.mcp.json`: reuses the core-bundled Playwright + Context7; nothing runs unless the verb is invoked.

### Kept from the 6.8.0 skill
- Command-invocation only (no free-text census); never writes vault/binding; dev server operator-owned; browser never load-bearing; ≤ 3 clarifying questions with keterangan; ≤ 3 compare rounds; no pixel-diff.

### Tests
- `tests/extras/test-extras-plugin-contracts.sh` (repo-root tree, CI-discovered): manifests + marketplace parity for EVERY plugin entry, zero-cost pins, containment pins, wording pins, core-unchanged pins (no core slice skill/command, 6 core commands, anchor core 3844 B). CI runs `claude plugin validate plugins/mega-sdd-extras`.
