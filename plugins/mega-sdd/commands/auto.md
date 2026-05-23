---
description: One-shot autonomous pipeline — THE primary mega-sdd command. Detects input shape (PRD file / legacy codebase / existing vault / free-text brief), runs the full chain end-to-end with single upfront confirmation. Auto-integrates diagnostics (lint-units, analyze-parallelism, list-modules, emit-agents-md, memory review) — no separate command invocations needed. Halts on blockers; resume via --resume. Per AUTONOMY-OQ-1 resolved: single upfront confirmation covers ALL phases including execute-bolts. Per Iter 13 audit: this is the ONE command users need; advanced/diagnostic commands available but auto-invoked transparently.
argument-hint: [input] [--deep|--shallow] [--greenfield] [--step-after=<phase>] [--stop-after=<phase>] [--resume] [--manual] [--out=<path>] [--no-lint] [--no-analyze] [--no-modules-summary] [--no-agents-md] [--converge|--no-converge] [--max-cycles=N]
---

Invoke the `mega-sdd:orchestrate-flow` skill via the Skill tool with `--deep --auto` flags + the detected starting phase based on input shape.

User arguments: $ARGUMENTS

Argument parsing (input detection rules, per spec `2026-05-20-autonomy-layer-design.md` §4 Pillar 4):

1. **Is `<input>` a path to a directory?**
   - Does it contain code files (`.{js,ts,php,py,rs,go,java,…}`) but NO vault at any of these paths: `.mega-sdd/vaults/*/vault.json` (v3.4+ canonical), `docs/mega-sdd/vaults/*/vault.json` (legacy), `vaults/*/vault.json` (pre-Iter-10)?
     - YES → legacy codebase. Propose chain starting with `extract-intelligence <input>` (REQUIRES `--out=<path>` per AUTONOMY-OQ-7 — conflating extract output with rebuild project dir is dangerous; default `--out=.mega-sdd/knowledge-base/`).
   - Does it contain a vault at any of these paths (priority order): `.mega-sdd/vaults/*/vault.json` (v3.4+ canonical) → `docs/mega-sdd/vaults/*/vault.json` (legacy)?
     - YES → existing vault. Propose chain starting with `scan-codebase` (if no codebase-map at `.mega-sdd/codebase/codebase-map.md` or legacy `codebase-map.md`) or `bind-codebase` (if codebase-map exists) or `generate-units` (if bound-vault exists).
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
   - `--greenfield` (v3.19+ Iter 27) — EXPLICIT opt-in for stack-agnostic vault generation. REQUIRED when CWD has no framework manifest (package.json / composer.json / Gemfile / pyproject.toml / go.mod / Cargo.toml). Without this flag AND no manifest detected → halt `no_starterkit_detected`.
   - `--step-after=<phase>` — switch to manual handoffs after this phase (e.g., `--step-after=bind-codebase` to review binding before continuing).
   - `--stop-after=<phase>` — halt after this phase even if no blocker.
   - `--resume` — re-enter a paused/halted chain; CWD inspection rebuilds cursor; halts re-fire if blockers unresolved.
   - `--manual` — disable autonomy entirely; reverts to per-skill explicit-command behavior (each skill's chat hint replaces auto-continue).
   - `--out=<path>` — REQUIRED when starting phase is `extract-intelligence` (legacy rebuild scenario). Specifies output dir for knowledge-base.

## Starterkit detection (v3.19+, Iter 27)

Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield" — starterkit is REQUIRED by default. Three modes per `orchestrate-flow/references/routing-rules.md` §Decision matrix:

| Mode | Trigger | Pipeline ordering |
|---|---|---|
| **A — Starterkit-first** (DEFAULT) | Framework manifest detected + pack match found in `references/framework-conventions/` | scan-codebase FIRST → generate-intent --scan=<map> (pack-aware vault, dual-citation format) → bind → units → bolts |
| **B — Framework-detected** (universal fallback) | Manifest detected but no pack match | scan-codebase FIRST → generate-intent --scan=<map> (universal conventions from `_universal.md`) → bind → units → bolts |
| **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | generate-intent --greenfield (stack-agnostic vault) → user scaffolds later → re-run scan to bind |

When neither manifest nor `--greenfield` set → halt `no_starterkit_detected` with options (scaffold first / opt in greenfield / cancel).

After detection + flag parse, invoke `orchestrate-flow --deep --auto [--from=<detected-start>] [--greenfield] [other-flags]`.

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

## Convergence loops (v3.12+, Iter 19)

In `--deep` mode, `auto` auto-loops eligible halts up to `--max-cycles` (default 5) instead of stopping on first halt. Cycle-eligible halts:

- `bind_conflict` → auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → re-run binding
- `module_blocked_by` → auto-run prerequisite module first
- `cross_squad_interface_draft` → wait+retry for producer to lock interface
- `oq_recommend_underspecified` → auto-regenerate recommendation fields

Halts that ALWAYS STOP (no auto-loop; require human review): `hard_rule_violated`, `dedup_ambiguous`, `quality_gate_failed`, `oq_business_p1_unresolved`, `test_fail` (post-retries), `hard_rule_unparseable`, `cross_module_dep_invalid`, `memory_schema_mismatch`, `mode_migrate`.

Per-cycle chat output:

```
⛔ Halt: bind_conflict (3 conflicts)
🔁 Cycle 1/5: auto-resolving via resolve-oq...
   ↳ C-007 → KEEP_CODE (memory 8/10; conf: 0.95) → ACCEPTED
✓ Cycle 1 complete. Re-running bind-codebase...
```

Opt-out: `--no-converge` reverts to pre-v3.12 (stop on any halt). Adjust limit: `--max-cycles=10`.

See `orchestrate-flow/SKILL.md` §Convergence loops for full algorithm + safety rails.

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
