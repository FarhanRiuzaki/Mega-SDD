---
description: One-shot autonomous pipeline — THE primary mega-sdd command. Detects input shape (PRD file / legacy codebase / existing vault / free-text brief), runs the full chain end-to-end with single upfront confirmation. Auto-integrates diagnostics (lint-units, analyze-parallelism, list-modules, emit-agents-md, memory review) — no separate command invocations needed. Halts on blockers; resume via --resume. Per AUTONOMY-OQ-1 resolved: single upfront confirmation covers ALL phases including execute-bolts. Per Iter 13 audit: this is the ONE command users need; advanced/diagnostic commands available but auto-invoked transparently.
argument-hint: [input] [--deep|--shallow] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md]
---

Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` flags + the detected starting phase based on input shape.

User arguments: $ARGUMENTS

Argument parsing (input detection rules, per spec `2026-05-20-autonomy-layer-design.md` §4 Pillar 4):

1. **Is `<input>` a path to a directory?**
   - Does it contain code files (`.{js,ts,php,py,rs,go,java,…}`) but NO `vault.json` / `vaults/` / `docs/mega-sdd/vaults/`?
     - YES → legacy codebase. Propose chain starting with `extract-intelligence <input>` (REQUIRES `--out=<path>` per AUTONOMY-OQ-7 — conflating extract output with rebuild project dir is dangerous).
   - Does it contain `vault.json` OR `docs/mega-sdd/vaults/*/vault.json`?
     - YES → existing vault. Propose chain starting with `scan-codebase` (if no codebase-map) or `bind-codebase` (if codebase-map exists) or `generate-units` (if bound-vault exists).
   - Otherwise → halt; ask user to clarify directory purpose.

2. **Is `<input>` a path to a file?**
   - Extension `.{md,pdf,docx,txt}` → likely PRD. Propose chain starting with `generate-intent <input>` (Mode A).
   - Extension `.json` with vault schema → vault file directly. Propose chain starting with `bind-codebase`.
   - Other → halt; ask user to clarify file type.

3. **Is `<input>` quoted free-text** (e.g., `"build a clinic appointment system"`)?
   - YES → Mode B brief. Propose chain starting with `generate-intent --from-prompt <input>`.

4. **Is `<input>` empty**?
   - YES → CWD inspection via `orchestrate-flow`'s routing-rules drives the chain. No fixed starting phase; CWD decides.

5. **Flag handling**:
   - `--deep` (default true for `auto`; opt-out via `--shallow` to revert to 3-skill cap).
   - `--step-after=<phase>` — switch to manual handoffs after this phase (e.g., `--step-after=bind-codebase` to review binding before continuing).
   - `--stop-after=<phase>` — halt after this phase even if no blocker.
   - `--resume` — re-enter a paused/halted chain; CWD inspection rebuilds cursor; halts re-fire if blockers unresolved.
   - `--manual` — disable autonomy entirely; reverts to per-skill explicit-command behavior (each skill's chat hint replaces auto-continue).
   - `--out=<path>` — REQUIRED when starting phase is `extract-intelligence` (legacy rebuild scenario). Specifies output dir for knowledge-base.

After detection + flag parse, invoke `orchestrate-flow --deep --auto [--from=<detected-start>] [other-flags]`.

## Auto-integrated diagnostics (v3.7+, Iter 13)

This command transparently invokes diagnostic skills at appropriate phases — user does NOT need to run them separately:

| Phase | Auto-invokes | Why |
|---|---|---|
| After `generate-units` | `lint-units` | Quality gate before bolt execution |
| Before `execute-bolts` | `analyze-parallelism` | Compute optimal wave plan for `--parallel` |
| After `execute-bolts` | `list-modules` | Per-module status in chain summary |
| At chain end | `emit-agents-md` | Tool-agnostic interop file refreshed |
| At chain end | Memory review prompt | Surface pending learning suggestions |

**Opt-out per diagnostic**: `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags available for debugging or non-standard workflows.

## Hard rails:
- **ONE upfront confirmation** showing the full proposed chain (per skill, per arguments). User picks Run / Edit / Cancel.
- **All existing halt-protocol blockers fire identically** — CONFLICT, business OQ P1, dedup_ambiguous, hard_rule_violated, cross_squad_*, quality_gate_failed. Chain pauses; user resolves; runs `/mega-sdd:auto --resume`.
- **Anti-halu invariants preserved**: binding gate non-negotiable, OQ-business stays human-decided, dedup_ambiguous halts on conflict, Hard rules pre/post-flight runs unchanged.
- **`--manual` flag disables autonomy entirely**; reverts to current per-skill explicit invocation behavior.
- **Legacy rebuild scenarios** REQUIRE `--out=<path>` per AUTONOMY-OQ-7. If invoking on a legacy codebase without `--out`, halt with message asking for explicit destination dir.
- **No persisted state file** per AUTONOMY-OQ-2. `--resume` re-runs CWD inspection; cursor position derives from artifact presence.
- **No `--skip-preflight`** for Hard rules (Iter 3 contract preserved per DESIGN-OQ-5).

On halt OR pause: chain stops; surface verbatim blocker YAMLs in chat (per `references/handoff-contract.md`). User resolves and re-runs `--resume`.

On chain completion: emit final summary per `orchestrate-flow/SKILL.md` Step 7 — total phases completed/paused/halted, flat list of all artifacts produced.
