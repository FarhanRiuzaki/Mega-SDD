---
name: orchestrate-flow
version: 2.4.1
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
   knowledge_base: present | absent (path: ...)  # (v2.3.1+ Iter 21) priority order: .mega-sdd/knowledge-base → docs/knowledge-base → docs/mega-sdd/knowledge-base → old-reference/knowledge-base
   git_repo: yes | no
   oq_p0_p1_count: N
   mode_inferred: greenfield | brownfield | legacy-rebuild
   squad_count: N  # (v1.1+) from <vault>/_meta/squads.yaml; 0 if file absent or single squad
   interfaces_count: N  # (v1.1+) count of files in <vault>/interfaces/ (excluding _index.md); 0 if folder absent
   starterkit: detected | absent  # (v2.4+ Iter 27) framework manifest probe
     framework: <name|null>       # e.g., laravel-base-26 (pack match), laravel (universal), null (no manifest)
     pack_match: yes | no         # yes if framework-conventions/<framework>.md exists; no if universal fallback
     manifest_path: <path|null>   # e.g., composer.json, package.json, Gemfile, pyproject.toml, go.mod, Cargo.toml
   ```

2.5. **Starterkit detection + mode classification (v2.4+, Iter 27).**

   Per user directive "starterkit itu wajib ada. jika tidak ada baru greenfield": starterkit is REQUIRED by default; greenfield only when user opts in explicitly.

   Three modes determined by inspection:

   | Mode | Trigger | Pipeline ordering |
   |---|---|---|
   | **A — Starterkit-first** (DEFAULT) | `starterkit: detected` + `pack_match: yes` | scan-codebase FIRST (loads pack into context) → generate-intent (pack-aware vault) → bind → units → bolts |
   | **B — Framework-detected** (universal fallback) | `starterkit: detected` + `pack_match: no` | scan-codebase FIRST (universal conventions from `_universal.md`) → generate-intent → bind → units → bolts |
   | **C — Greenfield (EXPLICIT)** | `--greenfield` flag OR (cwd empty/.git-only AND user confirms via halt) | generate-intent (stack-agnostic) → user scaffolds later → re-run with scan to bind |

   **Default behavior** when starterkit absent AND `--greenfield` NOT set → halt with `no_starterkit_detected`:

   ```yaml
   halt:
     type: no_starterkit_detected
     reason: "Mega-sdd default workflow requires a framework starterkit (composer.json / package.json / Gemfile / etc.) for delivery-grade output. Vault generation produces stack-agnostic designs without it."
     options:
       a: "Scaffold a starterkit first (recommended). For Laravel: clone base-laravel-26. For Django: django-admin startproject. For Rails: rails new. Then re-run."
       b: "Proceed as greenfield with --greenfield flag (vault stays stack-agnostic; you scaffold + re-run scan/bind later)"
       c: "Cancel"
   ```

   **Legacy rebuild scenario** (extract-intelligence + scan-on-target):
   ```
   extract-intelligence <legacy> → KB
     ↓
   scan-codebase (TARGET — new framework scaffold) → codebase-map.md
     ↓
   generate-intent --kb=<kb> --scan=<codebase-map> → vault aware of BOTH legacy domain AND target scaffold conventions
     ↓ bind → units → bolts
   ```

   **Memory hint**: user's last starterkit preference saved to `~/.mega-sdd/memory/preferences.md` `last_used_starterkit:` — next legacy-rebuild prompts "Last 3 projects used `laravel-base-26`. Use same starterkit?" Y/N/other.

3. **Build proposed chain** per `references/routing-rules.md` §Decision matrix.
   - Default mode (no `--deep`): hard cap 3 sub-skills (legacy behavior, backward-compatible).
   - **`--deep` mode (v1.3+)**: cap LIFTED — chain extends to pipeline-end per `references/routing-rules.md` §Deep-chain decision matrix. Auto-continue between phases via handoff YAML protocol (see `references/handoff-contract.md`).

4. **First-run pre-flight (only if chain includes execute-bolts):**
   - Check superpowers OR `_vendored/` availability
   - If neither → propose install command, halt chain proposal

5. **Present plan + single `AskUserQuestion`** (Run / Edit / Cancel). Edit supports `skip step N` and `stop after step N` only.

6. **Execute chain.** Dispatch sub-skills with `--auto` flag. Pause on blocker artifacts (any type) per `vault-contract.md` §halt-protocol. `resolve-oq` step is always interactive on per-OQ choices.

   **Chain proposal UX clarity (v1.4+, Iter 9 Bug 4 fix)**: when surfacing the upfront confirmation, include a "Halts may re-engage you" line so users have accurate expectations:

   ```
   Proposed pipeline (--deep):
     1. generate-intent ./prd.md  → vault
     2. scan-codebase             → codebase-map.md
     3. bind-codebase             → binding.md + bound-vault/
     4. generate-units            → units/
     5. execute-bolts --all       → bolts/

   Halts may re-engage you mid-chain (test failures, business OQ
   resolutions, hard-rule violations, dedup ambiguity, recommendation
   reviews). Otherwise runs end-to-end silently with progress indicators.

   [Run] [Edit] [Cancel]
   ```

   User confirmation is ONE-TIME for chain proposal; halts are NOT additional confirmations — they're interventions on real issues.

   **Progress indication (v1.3+, per AUTONOMY-OQ-4)**: before each skill invocation, emit one chat line:
   ```
   ▶ Phase {current} of {total}: invoking {skill} ({args})
   ```
   After each skill completes, emit one summary line:
   ```
   {✓|⏸|⛔} Phase {current} of {total}: {skill} → status: {status}, items: {items_processed}, blocked: {items_blocked}
   ```

   **`--deep` mode auto-continue (v1.3+)**: after each skill completes with `status: completed`, parse the skill's handoff YAML (per `references/handoff-contract.md`) and auto-invoke `next_action.suggested_skill` with `next_action.suggested_args`. Continue until pipeline-end OR `status: paused`/`halted` halts the loop. If skill emits `status: paused` (e.g., business OQs need triage) → log paused items and STOP chain awaiting user. If `status: halted` → surface blocker YAML verbatim and STOP.

   **Auto-integrated diagnostics (v2.2+, Iter 13)**: per audit `docs/superpowers/audits/2026-05-21-command-sprawl-audit-v3.6.md` consolidation restoring "single command" philosophy. Inside `--deep` chain (OR `--auto` mode), the orchestrator AUTOMATICALLY invokes diagnostic commands at appropriate phases — user does NOT run these separately:

   | Phase | Auto-runs | Output integration |
   |---|---|---|
   | After `generate-units` completes | `lint-units` (per `commands/lint-units.md` Procedure) | One-line chat summary: "lint: N HIGH / M MEDIUM / K LOW grounding; X/Y anchors verified" + halt-on-LOW-strict if `--strict-quality` flag set |
   | Before `execute-bolts` invocation | `analyze-parallelism` (per `commands/analyze-parallelism.md`) | Wave plan computed; passed to execute-bolts to drive `--parallel` batch dispatch |
   | After `execute-bolts` completes | `list-modules` (per `commands/list-modules.md` table format) | Per-module status table in chain end summary |
   | After all phases complete | `emit-agents-md` (per `commands/emit-agents-md.md`, respecting `config.yaml defaults.emit_agents_md: true|false`) | `AGENTS.md` (or `.mega-sdd.md` sibling) written at repo root |
   | After all phases complete | Memory review check (per `commands/memory.md review` if `~/.mega-sdd/memory/patterns.md` has ≥1 pending suggestion) | Surface in chain summary: "N pending learning suggestions → review via `/mega-sdd:memory review`" |

   These diagnostics run TRANSPARENTLY — chat output includes their summaries inline with phase progress lines. User does NOT need to know they exist as separate commands.

   **Manual override**: users invoking individual commands directly (`/mega-sdd:lint-units` etc.) still works for debugging/one-off use. Auto-invocations skip when user explicitly disables via `--no-lint`, `--no-analyze`, `--no-modules-summary`, `--no-agents-md` flags on `auto`/`orchestrate-flow`.

7. **Emit final summary** with completed/paused/skipped per step + verbatim blocker YAMLs if any. In `--deep` mode, append:
   - Total phases proposed, total phases completed, total artifacts produced (flat path list)
   - **(v2.2+, Iter 13) Auto-integrated diagnostics summary**:
     - Quality metrics from auto lint-units (units HIGH/MEDIUM/LOW counts)
     - Parallelism speedup from auto analyze-parallelism (X.Yx vs sequential)
     - Per-module status from auto list-modules (X/Y modules completed)
     - AGENTS.md emission confirmation (file path + section count)
     - Memory review prompt if pending suggestions exist

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
- (v2.0+) Checkpoint protocol auto-emits per-step JSONL files at `<vault>/.internal/checkpoints/` (per `references/checkpoint-protocol.md`); enables mid-skill resume

## Convergence loops (v2.3+, Iter 19)

Per user request — formalize iteration cycles antara skills yang sebelumnya manual (`--resume` driven). "Cycling agent" pattern.

### Cycle-eligible halt types

ONLY these halts trigger auto-loop. Other halts ALWAYS stop chain (human-required):

| Halt type | Auto-loop action | Safety condition |
|---|---|---|
| `bind_conflict` | Auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → re-run `bind-codebase` | Recommendation confidence ≥ 0.80 (per Iter 7); else stop |
| `module_blocked_by` | Auto-run prerequisite module first → resume requested module | All prerequisites identifiable + non-circular |
| `cross_squad_interface_draft` | Wait (with backoff: 30s, 60s, 120s) for producer to lock interface; retry up to 3 times | Producer squad has lock-in-progress signal in memory |
| `oq_recommend_underspecified` | Auto-regenerate recommendation fields from binding context → re-run generate-intent | Memory has fallback rationale template |

### Halt types that ALWAYS STOP chain (no auto-loop; human required)

- `hard_rule_violated` — code in working tree; user reviews + decides revert vs edit
- `dedup_ambiguous` — multi-path resolution; user picks intent
- `quality_gate_failed` — extract-intelligence; user reviews wave output
- `oq_business_p1_unresolved` — stakeholder decision required
- `test_fail` after 3 retries — manual investigation needed
- `hard_rule_unparseable` / `hard_rule_unanchored` — config error; user fixes
- `cross_squad_dep_invalid` — explicit blocked_by needed; user configures (canonical name per `handoff-contract.md`; was `cross_module_dep_invalid` pre-v2.3.2 Iter 25)
- `memory_schema_mismatch` — migration prompt; user opts in
- `mode_migrate` — vault/code mode contradiction; user decides
- `scope_not_declared_in_prd` — generate-intent: `--scope=<id>` flag mismatches PRD scopes block. ALWAYS STOP (user must pick valid scope from PRD declared list or cancel). v3.20+ Iter 28.
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP (user manually retrofits PRD or chooses single-scope fallback). v3.20+ Iter 28.
- `prd_retrofit_low_confidence` — generate-intent: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP (user reviews/accepts anyway / single-scope fallback / cancel). v3.20+ Iter 28.
- `prd_path_missing` — diff-vault (v1.3.0+ Iter 29): vault.json.prd_path_at_generation points to non-existent file. ALWAYS STOP (user must restore PRD or regenerate vault).

### `--converge` flag (v2.3+)

Default behavior in `--deep` mode:

- `--converge` (default ON in `--deep`) — auto-loop eligible halts up to `--max-cycles`
- `--no-converge` — STOP on any halt (pre-v2.3 behavior; explicit user resume needed)
- `--max-cycles=N` — max convergence iterations before forcing human review (default 5)

### Convergence loop algorithm

```
loop until clean OR max-cycles reached:
  execute current skill
  parse handoff YAML

  if status == completed AND blockers empty:
    proceed to next_action.suggested_skill (Iter 4 behavior)

  if status == halted AND blocker.type in CYCLE_ELIGIBLE:
    log: "🔁 Cycle {N}/{max}: halt={type}; auto-resolving..."

    invoke resolver skill (resolve-oq / module-runner / interface-wait / regen):
      - resolver MUST have HIGH confidence recovery path
      - resolver writes resolution to vault.json + memory
      - resolver returns success or "needs manual"

    if resolver success:
      re-run halted skill from checkpoint
      check if halt clears → loop continues
      if halt persists → escalate (treat as manual)

    if resolver needs-manual:
      escalate: stop chain, surface blocker, user resolves

  if status == halted AND blocker.type NOT in CYCLE_ELIGIBLE:
    STOP — surface blocker; user-required halt

  if cycle count >= max:
    STOP — emit "convergence_max_reached" with cycle history; user reviews
```

### Per-cycle chat output

```
▶ Phase 3 of 5: bind-codebase
⛔ Halt: bind_conflict (3 conflicts detected)
🔁 Cycle 1/5: auto-resolving via resolve-oq...
   ↳ C-007 (auth conflict) → recommendation: KEEP_CODE (memory pattern 8/10; conf: 0.95) → ACCEPTED
   ↳ C-009 (sanctum vs passport) → recommendation: KEEP_VAULT (per constitution §B-001) → ACCEPTED
   ↳ C-011 (audit table schema) → recommendation: SPLIT (per past pattern) → ACCEPTED
✓ Cycle 1 complete: 3 conflicts resolved. Re-running bind-codebase...

▶ Phase 3 of 5: bind-codebase (re-run)
✓ Phase 3 of 5: bind-codebase → status: completed, items: 24 claims, blocked: 0
   Convergence: 1 cycle (3 conflicts auto-resolved via memory; 0 manual)
```

### Halt YAML extension for convergence

When chain force-stops at max-cycles:

```yaml
blocker:
  type: convergence_max_reached
  emitted_at: <ISO8601>
  emitted_by: orchestrate-flow
  details:
    cycles_attempted: 5
    halt_history:
      - cycle: 1, halt: bind_conflict, auto-resolved: yes
      - cycle: 2, halt: bind_conflict (different conflicts), auto-resolved: yes
      - cycle: 3, halt: bind_conflict (recurring), auto-resolved: no — recommendation confidence dropped to 0.65
    last_halt: bind_conflict (C-019, auth-related; memory has 2 conflicting patterns)
  next_action: "Recurring conflict detected after 5 cycles. Run /mega-sdd:resolve-oq --binding manually OR re-configure vault claim. Memory has 2 conflicting patterns for this conflict type — review via /mega-sdd:memory show patterns"
```

### Anti-halu rails (mandatory)

- Auto-loop ONLY for eligible halt types listed above (closed set; never expanded silently)
- Resolver MUST have HIGH-confidence recovery path (≥0.80 per Iter 7); else escalate
- `--max-cycles` hard limit prevents runaway
- Every cycle logged in chain summary + memory `outcomes.md` (audit trail)
- If same halt recurs after auto-resolution → escalate (don't loop on identical recurring failure)
- `--no-converge` flag preserves pre-v2.3 behavior (stop on any halt)

### Backward compatibility

- v3.11 pipelines invoked WITHOUT `--converge` → unchanged behavior (stop on any halt)
- `--auto` chain mode → `--converge` defaults ON (autonomous behavior)
- Manual `orchestrate-flow` mode → `--converge` defaults OFF (per-phase control)
- `--max-cycles` flag override available always

## Checkpoint protocol (v2.0+, Iter 6)

Per `references/checkpoint-protocol.md`:

- Each long-running skill emits per-step checkpoints (JSONL) at `<vault>/.internal/checkpoints/`
- Resume via `--resume-from=<step-id>` (per-skill) OR `/mega-sdd:auto --resume` (chain-wide; orchestrator finds latest checkpoint automatically)
- Granularity per skill — extract-intelligence per wave, bind-codebase per claim, etc.
- Rotation: last 3 runs kept; older archived; prune >180d via `mega-sdd:memory prune`
- Checkpoint emission integrates with handoff YAML via new `checkpoints` field

### Resume logic in orchestrator (v2.0+)

When `/mega-sdd:auto --resume` invoked:

1. Scan `<vault>/.internal/checkpoints/*.jsonl` for current vault context
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
2. Read project-scope: `<cwd-project>/.mega-sdd/memory/decisions.md` + `conventions.md` + `outcomes.md`
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
