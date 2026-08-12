# Context7 embed — second bundled MCP server + implementer consult wiring

**Date:** 2026-08-12
**Status:** DESIGN — user "gas" on the presented design (post-6.8.0 dialog)
**Source:** USER — "btw bisa pasang embed di mega-sdd?" after the Context7 explainer; rides the D0 packaging lane the Playwright embed opened (`2026-08-12-playwright-embed-design.md`).
**Version:** 6.9.0 (minor). **Renumbering side-effect:** Playwright P2/P3 are renumbered OFF their drafted 6.9.0/6.10.0 slots — each takes the next free minor at its own ship time (no pinned future numbers here either; the playwright spec's version-plan line was amended to the same floating form in this ship).

## Why (no-gimmick)

Context7 injects CURRENT version-specific library docs into context — the direct antidote to the hallucinated-API / deprecated-syntax class, which is an anti-fabrication concern (v6 goal 4). Bundling alone would be a gimmick (nothing consumes it); this ship therefore ALSO wires the two code-emitting surfaces (`bolt-implementer`, `slice-design`) with optional, non-gating consult guidance. Registry facts verified 2026-08-12: `@upstash/context7-mcp` latest **4.0.2**, Node **>=20.18.1**, keyless free tier (rate-limited), `--api-key` optional.

## D0 — the second server in `plugins/mega-sdd/.mcp.json`

```json
"context7": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@4.0.2"]
}
```

- **Pin exact 4.0.2**, never floating — the pin joins the SAME CLAUDE.md §Versioning MCP-pin checklist line (reworded to cover "every server in `.mcp.json`", not just Playwright).
- **Keyless deliberately**: `--api-key ${CONTEXT7_API_KEY:-}` was considered and REJECTED — an empty `--api-key` flag's fallback behavior is not contractually documented; keyless is the unambiguous free-tier form. A user with an API key registers their own user-level server (or keeps the standalone context7 plugin).
- **Duplicate-plugin safety, CONFIRMED from docs**: plugin MCP servers are namespaced per-plugin (`plugin:mega-sdd:context7` vs `plugin:context7:context7`; tools `mcp__plugin_<plugin>_<server>__*`) — no collision with a user's standalone context7 plugin; two active copies just means two npx processes, and `/mcp` per-server disable is the mitigation (README notes it).
- **Node floor note**: context7 needs Node >=20.18.1 (Playwright's server only >=18). Same degradation rung 2 as the playwright spec: server fails to start → consumers proceed without it; never load-bearing, nothing gates.

## D1 — consult wiring (optional, non-gating, in the AGENT/skill bodies — NOT the dispatch builder)

- `agents/bolt-implementer.md` gains one paragraph: when Context7 MCP tools are available (load via ToolSearch), consult current library docs BEFORE writing code against fast-moving or unfamiliar framework APIs, and prefer what the current docs say over trained recall; when absent, proceed normally — availability is never load-bearing and never blocks a bolt.
- `skills/slice-design/references/slice-procedure.md` §3 gains the mirror line.
- **Deliberately NOT in `build-dispatch-prompt.sh`**: the dispatch-parity golden corpus stays byte-identical — zero builder edits, zero regen (the 6.7.1 doctrine: regen accompanying a feature = red flag).

## Pins (amended same-commit as the `.mcp.json` edit — attack-own-assertions)

- Arm A2 re-pins the server set to EXACTLY `["context7", "playwright"]` (sorted), both stdio via npx, no `env`/`alwaysLoad` on either.
- NEW arm A5: context7 pinned to an exact version (regex mirror of A3; the existing floating-tag grep covers the whole file).
- NEW section E: consult-guidance pins on both wired surfaces (presence + "never load-bearing"/non-gating wording) + a pin that `build-dispatch-prompt.sh` contains NO context7 reference (the golden-corpus firewall).
- README bundled-MCP notes (both files) updated to name the two servers + the Node floors.

## Non-goals

- No API-key plumbing, no config surface, no new skill/command/verb.
- No dispatch-builder edit; no golden regen.
- No census/anchor-core change (nothing routes on "context7" free text).
- Consult guidance is advice to the implementer, never a gate, never a halt.
