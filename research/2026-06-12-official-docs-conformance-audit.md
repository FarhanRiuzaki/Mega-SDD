# Audit — hook/agent surfaces vs official Claude Code docs (2026-06-12)

Deep audit of every hook/agent/manifest surface against code.claude.com/docs after the 4.20→4.27 sprint. Two parallel agents (inventory + official-docs research), then direct WebFetch verification of the contested claims.

## Verified CONFORM (no change)

- **SessionStart raw stdout → context.** Docs: *"Any text your hook script prints to stdout is added as context for Claude"* — SessionStart/UserPromptSubmit/UserPromptExpansion are the three exceptions where stdout reaches context. The anchor + instinct + compaction-resume heredoc is correct. (A sub-agent claimed only JSON works; direct fetch disproved it — and the anchor injected via stdout in the live session.)
- **UserPromptExpansion** is a real documented event (fires on command expansion, can block). Not a no-op.
- **PreToolUse deny** uses `hookSpecificOutput.permissionDecision: "deny"` (current). The legacy `decision: "block"` riding along is ignored extra-keys (deliberate back-compat, harmless).
- **PreCompact** is side-effect-only (exit 2 blocks). The snapshot hook writes a file + exit 0 — correct.
- **Plugin agent frontmatter**: only `hooks`/`mcpServers`/`permissionMode` are banned for plugin agents; none of the 8 use them. `color` is undocumented-but-tolerated (pre-existing on all agents; no evidence of harm) — left as-is.
- **No stdout/JSON mixing**: each hook emits EITHER one JSON object OR plain text OR nothing — never both on one stream.

## Fixed (2 real gaps)

1. **Compaction advisor was invisible (introduced 4.27.0).** It printed to the **Stop** hook's stdout, but docs: Stop stdout is debug-log-only (Stop is NOT a stdout→context event), and the hook is `async` — so the line reached no one. **Relocated to a new `UserPromptSubmit` hook**, where stdout *is* added to context per docs. Same threshold/opt-out; fires per turn while a chain is in flight.
2. **`MultiEdit` matcher (introduced 4.25.0).** Not a current Claude Code tool name. Dropped from the PreToolUse matcher, the case label, and the parse tuple — GateGuard now matches `Edit|Write` only (the documented file-mutating tools; `file_path` lives in `tool_input` for both).

## Net

The moat surfaces (binding gate, GateGuard, code-delivery gates) were already doc-correct. The two fixes are a relocation and a no-op-cleanup — no behavior regression, and the compaction advisory now actually surfaces. plugin → 4.27.1.
