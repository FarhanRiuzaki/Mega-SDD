# Convergence Loops — Auto-Recovery Cycling

Formalizes iteration cycles between skills that were previously manual (`--resume` driven) — the "cycling agent" pattern. In `--deep` mode, eligible halts auto-resolve via memory-pre-filled recommendations and re-run, up to `--max-cycles`. Every other halt always stops the chain (human required).

## Contents

- [Cycle-eligible halt types](#cycle-eligible-halt-types)
- [--converge flag](#--converge-flag)
- [Convergence loop algorithm](#convergence-loop-algorithm)
- [Per-cycle chat output](#per-cycle-chat-output)
- [convergence_max_reached halt YAML](#convergence_max_reached-halt-yaml)
- [Anti-halu rails](#anti-halu-rails)
- [Backward compatibility](#backward-compatibility)
- [Bolt halt convergence bridge](#bolt-halt-convergence-bridge)

## Cycle-eligible halt types

ONLY these halts trigger auto-loop. Other halts ALWAYS stop chain (human-required; the full halt-taxonomy reference is indexed in SKILL.md §Specialist references):

| Halt type | Auto-loop action | Safety condition |
|---|---|---|
| `bind_conflict` | Auto-invoke `resolve-oq --binding` with memory-pre-filled recommendations → next step is ACTION-MIX dependent (S4): KEEP_CODE/SPLIT resolutions → re-run `bind-codebase`; KEEP_VAULT/DEFER-only → proceed to `generate-units` (a re-bind re-raises the same CONFLICT from the unchanged vault-vs-code contradiction — looping it burns every cycle; per `resolve-oq/references/binding-mode.md` Step 5) | Recommendation confidence ≥ 0.80; else stop |
| `module_blocked_by` | Auto-run prerequisite module first → resume requested module | All prerequisites identifiable + non-circular |
| `cross_squad_interface_draft` | Wait (with backoff: 30s, 60s, 120s) for producer to lock interface; retry up to 3 times | Producer squad has lock-in-progress signal in memory |
| `oq_recommend_underspecified` | Auto-regenerate recommendation fields from binding context → re-run generate-intent | Memory has fallback rationale template |

## `--converge` flag

Default behavior in `--deep` mode:

- `--converge` (default ON in `--deep`) — auto-loop eligible halts up to `--max-cycles`
- `--no-converge` — STOP on any halt (legacy behavior; explicit user resume needed)
- `--max-cycles=N` — max convergence iterations before forcing human review (default 3; canonical with `/mega-sdd` command)

## Convergence loop algorithm

```
loop until clean OR max-cycles reached:
  execute current skill
  parse handoff YAML

  if status == completed AND blockers empty:
    proceed to next_action.suggested_skill

  if status == halted AND blocker.type in CYCLE_ELIGIBLE:
    log: "🔁 Cycle {N}/{max}: halt={type}; auto-resolving..."

    invoke resolver skill (resolve-oq / module-runner / interface-wait / regen):
      - resolver MUST have HIGH confidence recovery path
      - resolver writes resolution to vault.json + memory
      - resolver returns success or "needs manual"

    if resolver success:
      # The resolver's emitted next_action decides the next hop (round-2 Batch A2) — a
      # resolver may route BACK to the halted skill (retry model) or FORWARD past it:
      if resolver's next_action routes BACK to the halted skill
         (e.g. bind_conflict resolved via KEEP_CODE/SPLIT → re-run bind-codebase):
        re-run halted skill from checkpoint
        check if halt clears → loop continues
        if halt persists → escalate (treat as manual)
      else (resolver returns status:completed with a FORWARD next_action —
            e.g. bind_conflict resolved KEEP_VAULT/DEFER-only → generate-units, per the
            Cycle-eligible table above + binding-mode.md Step 5):
        EXIT the convergence loop for this halt; rejoin the normal --deep chain at
        next_action.suggested_skill. There is NO "halt to clear" — do NOT re-run the
        halted skill (a re-bind would re-raise the same CONFLICT and burn every cycle).

    if resolver needs-manual:
      escalate: stop chain, surface blocker, user resolves

  if status == halted AND blocker.type NOT in CYCLE_ELIGIBLE:
    STOP — surface blocker; user-required halt

  if cycle count >= max:
    STOP — emit "convergence_max_reached" with cycle history; user reviews
```

## Per-cycle chat output

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

## convergence_max_reached halt YAML

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
  next_action: "Recurring conflict detected after 5 cycles. Run resolve-oq --binding manually OR re-configure vault claim. Memory has 2 conflicting patterns for this conflict type — review via /mega-sdd:memory show patterns"
```

## Anti-halu rails

- Auto-loop ONLY for eligible halt types listed above (closed set; never expanded silently)
- Resolver MUST have HIGH-confidence recovery path (≥0.80); else escalate
- `--max-cycles` hard limit prevents runaway
- Every cycle logged in chain summary + memory `outcomes.md` (audit trail)
- If same halt recurs after auto-resolution → escalate (don't loop on identical recurring failure)
- `--no-converge` flag preserves legacy behavior (stop on any halt)

## Backward compatibility

- Legacy pipelines invoked WITHOUT `--converge` → unchanged behavior (stop on any halt)
- `--auto` chain mode → `--converge` defaults ON (autonomous behavior)
- Manual `orchestrate-flow` mode → `--converge` defaults OFF (per-phase control)
- `--max-cycles` flag override available always

## Bolt halt convergence bridge

Convergence loops handle: `bind_conflict`, `module_blocked_by`, `cross_squad_interface_draft`, `oq_recommend_underspecified`.

The **propose-and-confirm bridge** extends convergence to bolt halts:

| Bolt halt type | Convergence behavior |
|---|---|
| `test_fail` (after retries) | Propose-and-confirm fix → user approve → re-execute single bolt → continue batch |
| `hard_rule_violated` | Propose-and-confirm fix → user approve → re-execute → continue |
| `pbt_property_violated` | Propose-and-confirm fix → user approve → re-execute → continue |

Cycle counter respects `--max-cycles` (default 3). One cycle = 1 propose + 1 user decision + 1 re-execute attempt.

**Cycle escalation**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Prevents propose-and-confirm from looping on a structurally-broken unit.

**Configuration** (`~/.mega-sdd/memory/config.yaml`):
```yaml
halt_auto_propose:
  test_fail: propose
  hard_rule_violated: propose
  pbt_property_violated: propose
```

Per-halt-type override allowed (set to `pause` to disable propose for that type).

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: halt-taxonomy (full halt classification — cycle-eligible / always-stop / soft) and handoff-consumption (how the orchestrator parses handoff status to drive the loop).
