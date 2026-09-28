# Convergence Loops — Auto-Recovery Cycling

Formalizes iteration cycles between skills — the "cycling agent" pattern. In `--deep` mode, eligible halts auto-resolve via grounded (KB/vault/codebase) recommendations and re-run, up to `--max-cycles`. Every other halt follows its taxonomy class (`halt-taxonomy.md`: always-stop = human required; self-resolve C1 = handled without stopping; soft = warn-only).

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
| `binding_conflict` — `--agents` (execute-bolts 3.9, per unit) | Auto-invoke `resolve-oq --binding <vault>` with grounded recommendations; it writes each choice via `write-unit-binding.sh --resolve`. Next step is ACTION-MIX dependent: KEEP_CODE/SPLIT edits the unit's `## Claims` → `rebind-units.sh --units=U-XXX` (3.9b) → re-dispatch; KEEP_VAULT/DEFER-only → the resolution in `binding.json` already opens the gate (open = CONFLICT without resolution), so continue that unit's dispatch with no re-bind (a re-bind would only spend the unit's one 3.9b at this HEAD — `rebind_exhausted`; per `execute-bolts/references/jit-bind-and-quarantine.md` §3.9/§3.9b) | Recommendation confidence ≥ 0.80; else stop |
| `binding_conflict` — default inline run, `scope: all_units` / `run` (every unit blocked at run start) | Auto-invoke `resolve-oq --binding <vault>` as above → re-invoke `execute-bolts`, which re-plans (`inline-run.md` (b)). A partial CONFLICT is NOT a halt there: the unit is quarantined and reported in the Karantina table, never auto-resolved | Same |
| `binding_conflict` — default inline run, `scope: close` (a CONFLICT the close's re-bind left; `derive-exec-plan.sh --rebind-wip` / `--retire` exit 1) | Auto-invoke `resolve-oq --binding <vault>` as above → re-invoke `execute-bolts`: the open plan resumes at (d)4 (the ledger's `Close: reviewed` line), so the suite and the blind review never run twice; the close re-runs `--rebind-wip`, commits, gates, retires | Same |
| `module_blocked_by` | Auto-run prerequisite module first → resume requested module | All prerequisites identifiable + non-circular |
| `cross_squad_interface_draft` | Wait (with backoff: 30s, 60s, 120s) for producer to lock interface; retry up to 3 times | Producer squad interface still `draft` after retries → stop |
| `oq_recommend_underspecified` | Auto-regenerate the missing recommendation fields from GROUND evidence (symbol index) + KB → re-run `plan` (the OQ lives in context.md) | Memory has fallback rationale template |

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
      - resolver writes resolution to vault.json
      - resolver returns success or "needs manual"

    if resolver success:
      # The resolver's emitted next_action decides the next hop — a
      # resolver may route BACK to the halted skill (retry model) or FORWARD past it:
      if resolver's next_action routes BACK to the halted skill
         (e.g. binding_conflict resolved via KEEP_CODE/SPLIT → re-bind that unit:
          `rebind-units.sh --units=U-XXX`, execute-bolts 3.9b):
        re-bind + re-dispatch that unit
        check if halt clears → loop continues
        if halt persists → escalate (treat as manual)
      else (resolver returns status:completed with a FORWARD next_action —
            e.g. binding_conflict resolved KEEP_VAULT/DEFER-only → the unit's gate is
            open; continue its execute-bolts dispatch):
        EXIT the convergence loop for this halt; rejoin the normal --deep chain at
        next_action.suggested_skill. There is NO "halt to clear" — do NOT re-bind: the
        gate is already open, and a re-bind would only spend the unit's one 3.9b
        re-bind at this HEAD.

    if resolver needs-manual:
      escalate: stop chain, surface blocker, user resolves

  if status == halted AND blocker.type NOT in CYCLE_ELIGIBLE:
    STOP — surface blocker; user-required halt

  if cycle count >= max:
    STOP — emit "convergence_max_reached" with cycle history; user reviews
```

## Per-cycle chat output

```
▶ Phase 2 of 2: execute-bolts --agents, U-008 pre-flight 3.9 (JIT bind)
⛔ Halt: binding_conflict (U-008: 3 conflicts)
🔁 Cycle 1/3: auto-resolving via resolve-oq...
   ↳ C-U008-01 (auth conflict) → recommendation: KEEP_CODE (vault D-004 + code anchor; conf: 0.95) → ACCEPTED
   ↳ C-U008-02 (sanctum vs passport) → recommendation: KEEP_VAULT (per constitution §B-001) → ACCEPTED
   ↳ C-U008-03 (audit table schema) → recommendation: SPLIT (per past pattern) → ACCEPTED
✓ Cycle 1 complete: 3 conflicts resolved (write-unit-binding.sh --resolve). Mixed actions → re-binding U-008 (rebind-units.sh --units=U-008)...

▶ U-008 re-bind (execute-bolts 3.9b)
✓ U-008 binding.json → gate open, 24 claims, 0 unresolved CONFLICT → dispatching bolt-implementer
   Convergence: 1 cycle (3 conflicts auto-resolved from grounded evidence; 0 manual)
```

## convergence_max_reached halt YAML

When chain force-stops at max-cycles:

```yaml
blocker:
  type: convergence_max_reached
  emitted_at: <ISO8601>
  emitted_by: orchestrate-flow
  details:
    cycles_attempted: 3
    halt_history:
      - cycle: 1, halt: binding_conflict, auto-resolved: yes
      - cycle: 2, halt: binding_conflict (different conflicts), auto-resolved: yes
      - cycle: 3, halt: binding_conflict (recurring), auto-resolved: no — recommendation confidence dropped to 0.65
    last_halt: binding_conflict (U-008 C-U008-03, auth-related; sources disagree)
  next_action: "Recurring conflict detected after 3 cycles. Run resolve-oq --binding manually OR edit the unit's ## Claims and re-bind it (rebind-units.sh --units=U-008)."
```

## Anti-halu rails

- Auto-loop ONLY for eligible halt types listed above (closed set; never expanded silently)
- Resolver MUST have HIGH-confidence recovery path (≥0.80); else escalate
- `--max-cycles` hard limit prevents runaway
- Every cycle logged in the chain summary (audit trail)
- If same halt recurs after auto-resolution → escalate (don't loop on identical recurring failure)
- `--no-converge` flag preserves legacy behavior (stop on any halt)

## Backward compatibility

- Legacy pipelines invoked WITHOUT `--converge` → unchanged behavior (stop on any halt)
- `--auto` chain mode → `--converge` defaults ON (autonomous behavior)
- Manual `orchestrate-flow` mode → `--converge` defaults OFF (per-phase control)
- `--max-cycles` flag override available always

## Bolt halt convergence bridge

Convergence loops handle: `binding_conflict`, `module_blocked_by`, `cross_squad_interface_draft`, `oq_recommend_underspecified`.

The **propose-and-confirm bridge** extends convergence to bolt halts:

| Bolt halt type | Convergence behavior |
|---|---|
| `test_fail` (after retries) | Propose-and-confirm fix → user approve → re-execute single bolt → continue batch |
| `hard_rule_violated` | Propose-and-confirm fix → user approve → re-execute → continue |
| `pbt_property_violated` | Propose-and-confirm fix → user approve → re-execute → continue |

Cycle counter respects `--max-cycles` (default 3). One cycle = 1 propose + 1 user decision + 1 re-execute attempt.

**Cycle escalation**: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Prevents propose-and-confirm from looping on a structurally-broken unit.

**Configuration** (`~/.mega-sdd/config.yaml` — user-scope):
```yaml
halt_auto_propose:
  test_fail: propose
  hard_rule_violated: propose
  pbt_property_violated: propose
```

Per-halt-type override allowed (set to `pause` to disable propose for that type).

## See also

SKILL.md §Specialist references indexes the related orchestrate-flow references: halt-taxonomy (full halt classification — cycle-eligible / always-stop / self-resolve C1 / soft) and handoff-consumption (how the orchestrator parses handoff status to drive the loop).
