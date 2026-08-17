# A7 userConfig + A8 FileChanged verdict (v6.18.0)

**Status:** SHIPPED v6.18.0 (2026-08-17, 223f393, CI green, both-tree suite 278/278). Closes the adoption roadmap.
**Source:** adoption scan A7+A8, USER-GREENLIT 2026-08-17. Release 3 of the batches (final).

## A7 — SHIPPED (minimal, mechanism-verified)
Docs verified (plugins-reference): userConfig values reach hooks as `CLAUDE_PLUGIN_OPTION_<KEY>` env vars; `displayName` valid ≥2.1.143.
- `plugin.json`: `displayName: "Mega-SDD"` + `userConfig.telemetry` (boolean, default true, title required — the validator caught the missing title live, proving the A1 CI step).
- **Precedence (the contract):** project `.mega-sdd/config.yaml` `telemetry:` line ALWAYS wins; `CLAUDE_PLUGIN_OPTION_TELEMETRY=false` applies ONLY when the project file has no telemetry line; default on. Wired at all three telemetry guard sites (post-tool-use emitter, session-start guard block, session-start diagnostic layer).
- Deferred honestly: spine/profile knobs — engine reads config.yaml in skill prose; an env second-source there needs its own design + demand. Not shipped.

## A8 — FileChanged: EVALUATED, REJECTED on doc evidence
hooks doc: FileChanged fires on WATCHED-file on-disk changes, matcher = **literal filenames** (`.envrc|.env` style) — not globs. The imagined third sync channel (watching source files) is unsupported; watching vault artifacts duplicates the gate's re-derivation. Reject; revisit only if matchers grow glob support.

## Tests
`tests/delta-hygiene/test-a7-userconfig.sh`: plugin.json displayName + userConfig shape (title present); precedence at all three sites (project-line-wins + env-only-when-absent greps); validator passes.
