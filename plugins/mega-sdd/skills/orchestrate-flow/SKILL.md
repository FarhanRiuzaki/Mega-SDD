---
name: orchestrate-flow
version: 2.0.0
description: Multi-skill lifecycle orchestrator for mega-sdd. Inspects CWD, proposes a chain of sub-skills (extract-intelligence / generate-intent / scan-codebase / bind-codebase / generate-units / execute-bolts / resolve-oq / detect-drift / diff-vault), confirms once, then executes the chain in --auto mode. (v1.3+, Iter 4) `--deep` flag lifts 3-skill cap and chains to pipeline-end with auto-continue via handoff YAML protocol; `--resume` resumes a paused chain from CWD state (no persisted state file). Triggers — "orchestrate", "run flow", "auto mega-sdd", "do the next thing", "what's next", or paraphrases.
---

# Orchestrate-Flow — Lifecycle Orchestrator

**Announce at start:** "I'm using the orchestrate-flow skill to inspect CWD and propose the next phases."

## When to use

- "run the flow" / "auto mega-sdd" / "do the next thing"
- "what's next" / "orchestrate"
- After completing one phase, user wants automatic transition

## Procedure

1. **Parse args.** Persist `WORK_DIR`, optional `--from=<phase>`, `--to=<phase>`, optional `--deep` (v1.3+), optional `--resume` (v1.3+).

2. **Deterministic CWD inspection** per `references/routing-rules.md` §CWD inspection. Output a state snapshot:
   ```
   prd: present | absent
   vault: present | absent (path: ...)
   bound_vault: present | absent
   units: N
   bolts: N
   codebase_map: present | absent
   knowledge_base: present | absent (path: ...)  # (v1.2+) probe docs/knowledge-base, docs/mega-sdd/knowledge-base, old-reference/knowledge-base
   git_repo: yes | no
   oq_p0_p1_count: N
   mode_inferred: greenfield | brownfield | legacy-rebuild
   squad_count: N  # (v1.1+) from <vault>/_meta/squads.yaml; 0 if file absent or single squad
   interfaces_count: N  # (v1.1+) count of files in <vault>/interfaces/ (excluding _index.md); 0 if folder absent
   ```

3. **Build proposed chain** per `references/routing-rules.md` §Decision matrix.
   - Default mode (no `--deep`): hard cap 3 sub-skills (legacy behavior, backward-compatible).
   - **`--deep` mode (v1.3+)**: cap LIFTED — chain extends to pipeline-end per `references/routing-rules.md` §Deep-chain decision matrix. Auto-continue between phases via handoff YAML protocol (see `references/handoff-contract.md`).

4. **First-run pre-flight (only if chain includes execute-bolts):**
   - Check superpowers OR `_vendored/` availability
   - If neither → propose install command, halt chain proposal

5. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.

6. **Execute chain.** Dispatch sub-skills with `--auto` flag. Pause on blocker artifacts (any type) per `vault-contract.md` §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.

   **Progress indication (v1.3+, per AUTONOMY-OQ-4)**: before each skill invocation, emit one chat line:
   ```
   ▶ Phase {current} of {total}: invoking {skill} ({args})
   ```
   After each skill completes, emit one summary line:
   ```
   {✓|⏸|⛔} Phase {current} of {total}: {skill} → status: {status}, items: {items_processed}, blocked: {items_blocked}
   ```

   **`--deep` mode auto-continue (v1.3+)**: after each skill completes with `status: completed`, parse the skill's handoff YAML (per `references/handoff-contract.md`) and auto-invoke `next_action.suggested_skill` with `next_action.suggested_args`. Continue until pipeline-end OR `status: paused`/`halted` halts the loop. If skill emits `status: paused` (e.g., business OQs need triage) → log paused items and STOP chain awaiting user. If `status: halted` → surface blocker YAML verbatim and STOP.

7. **Emit final summary** with completed/paused/skipped per step + verbatim blocker YAMLs if any. In `--deep` mode, append: total phases proposed, total phases completed, total artifacts produced (flat path list).

8. **Resume support (v1.3+, per AUTONOMY-OQ-2 — CWD-driven, no state file).**

   When invoked with `--resume`:
   - Skip the upfront confirmation (chain was already approved last run)
   - Re-run CWD inspection (Step 2) — produces fresh state snapshot
   - Build chain per routing-rules; if state shows certain artifacts already exist (e.g., vault.json present) → skip those phases automatically; cursor lands on the next un-done phase
   - Execute from cursor onward
   - If a previously-halted phase still has its blocker unresolved → halt fires again identically. User MUST resolve blocker BEFORE re-running `--resume`.

## Hard rails

- No content generation by the orchestrator itself.
- No state file (resumption = re-invoke `orchestrate-flow --resume`; CWD inspection rebuilds state).
- No skill runs in parallel.
- Sub-skill substance prompts ALWAYS surface to human.
- Chain depth ≤ 3 by default; `--deep` flag (v1.3+) lifts the cap with auto-continue via handoff YAML.
- (v1.3+) `--deep` mode does NOT relax any halt-condition. Every blocker still fires identically. Auto-continue happens ONLY when skill reports `status: completed` with empty `blockers: []`.

## Greenfield vs Brownfield routing

Per `references/routing-rules.md` §Greenfield vs brownfield detection.

## Mode-migration

If CWD signals say "brownfield" but vault says `mode: greenfield` (or vice versa):
- Halt
- Emit mode-migration prompt — user chooses to update vault or re-detect

**Structured halt per `vault-contract.md §halt-protocol`:**

```yaml
blocker:
  type: mode_migrate
  emitted_at: <ISO8601 timestamp>
  emitted_by: orchestrate-flow
  details:
    vault_mode: greenfield | existing  # what vault.json says
    cwd_signals: [.git, package.json, ...]  # what was detected
    resolution: "update vault.mode to match CWD" | "re-detect by moving to clean dir"
  next_action: "Confirm correct mode then re-run /mega-sdd:orchestrate-flow"
```

## Flags

- `--from=<phase>`: resume from a specific phase (skip earlier phases even if state says they're needed)
- `--to=<phase>`: stop at a specific phase (do not chain beyond it)
- `--dry-run`: show proposed chain without executing
- (v1.3+) `--deep`: lift 3-skill cap; chain to pipeline-end via handoff-YAML auto-continue
- (v1.3+) `--resume`: re-enter a paused/halted chain; skip upfront confirmation; CWD inspection rebuilds cursor position; halts re-fire if blockers unresolved
- (v1.4+) `--memory-off`: disable memory layer (no reads, no writes) for this chain
- (v2.0+) Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.mega-sdd/checkpoints/` (per `references/checkpoint-protocol.md`); enables mid-skill resume

## Checkpoint protocol (v2.0+, Iter 6)

Per `references/checkpoint-protocol.md`:

- Each long-running skill emits per-step checkpoints (JSONL) at `<vault>/.mega-sdd/checkpoints/`
- Resume via `--resume-from=<step-id>` (per-skill) OR `/mega-sdd:auto --resume` (chain-wide; orchestrator finds latest checkpoint automatically)
- Granularity per skill — extract-intelligence per wave, bind-codebase per claim, etc.
- Rotation: last 3 runs kept; older archived; prune >180d via `mega-sdd:memory prune`
- Checkpoint emission integrates with handoff YAML via new `checkpoints` field

### Resume logic in orchestrator (v2.0+)

When `/mega-sdd:auto --resume` invoked:

1. Scan `<vault>/.mega-sdd/checkpoints/*.jsonl` for current vault context
2. Identify last incomplete skill invocation (most recent checkpoint without "completed" marker)
3. Build chain starting from that skill with `--resume-from=<latest-step-id>` flag
4. Skill resumes mid-execution
5. After skill completes, chain auto-continues per Iter 4 handoff YAML protocol

If NO checkpoints found → fall back to Iter 4 CWD-driven resume (artifact presence).

## Memory layer (v1.4+, Iter 5)

When memory enabled (default; opt-out via `--memory-off`), the orchestrator is the SINGLE memory I/O point for the chain per MEMORY-OQ-7. Skills do not re-read disk; they receive slices via handoff YAML.

### Chain start (single memory read)

Before invoking first skill in `--deep` mode:

1. Read user-scope: `~/.mega-sdd/memory/preferences.md` + `~/.mega-sdd/memory/patterns.md`
2. Read project-scope: `<cwd-project>/.mega-sdd-memory/decisions.md` + `conventions.md` + `outcomes.md`
3. Read vault-scope (if vault detected): `<vault>/.memory/classifier-accuracy.json` + `bind-history.md` + `bolt-outcomes.json`
4. Verify all `memory_schema` versions match expected; halt with `memory_schema_mismatch` blocker if any differ (per MEMORY-OQ-1)
5. Build per-skill memory slices (filter to only what each skill needs)
6. Surface chain history in confirmation: "Past 3 runs: 2 completed, 1 halted on bind_conflict. Continue?"

### Per-phase invocation

When invoking each skill via Skill tool:

1. Pass that skill's memory slice via handoff YAML `metadata.memory_context` field (per `references/handoff-contract.md` §Memory layer integration)
2. Skill reads from in-memory slice — no disk re-read

### Per-phase write batching

When skill emits handoff with `metadata.memory_writes`:

1. Validate each write entry (file, scope, action, content)
2. Append to target file per scope rules (resolve absolute path from CWD + vault)
3. Atomic per-file append (per MEMORY-OQ-6 race-tolerant)
4. Log writes to chain progress chat (one line per write)
5. Failed writes logged but do NOT halt chain (memory is optional)

### Chain end

After last skill completes:

1. Final memory summary in chat: "Chain wrote N memory entries across scopes: user (X), project (Y), vault (Z)"
2. If pending suggestions accumulated (≥1 threshold crossed): announce "Mega-SDD has N pending learning suggestions. Review via `/mega-sdd:memory review`"

### Anti-halu rails

- Memory schema mismatch HALTS the chain (cannot continue with mixed schemas)
- Memory I/O failures (disk, perm) logged but do NOT halt (graceful degradation)
- Suggestions surfaced at chain end; NEVER auto-applied
- `--memory-off` propagates to all sub-skills automatically (passed as flag in handoff invocation args)
