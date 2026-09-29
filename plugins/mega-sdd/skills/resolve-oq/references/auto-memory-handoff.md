# resolve-oq — --auto, auto-accept & handoff

## Contents
- --auto flag (logistical-only skip table)
- Non-interactive auto-accept mode (flags + logic + convergence-loop use)
- Scope context in OQ resolution
- Handoff emission (YAML)

Loaded when `resolve-oq` runs under `--auto`, as an `orchestrate-flow` chain phase, or in a convergence loop. The interactive walk, binding mode, and recommendation building each have their own reference, listed by the SKILL.md router; this file covers only the non-interactive machinery.

## --auto flag

The `--auto` flag is passed by upstream callers (typically `/mega-sdd`) to skip **logistical** prompts only. **Substance prompts — per-OQ Resolve / Out-of-Scope / Defer / Skip choices — ALWAYS stay interactive on the BLOCKING tier (P1), and on EVERY tier in a standalone invocation.** That is the entire point of this skill: capturing stakeholder answers, not Claude's guesses. **P3 express-chain carve-out:** P2/P3 OQs on the chain-routed express path auto-defer WITHOUT a prompt — no answer is invented (invariant #5 governs answer CONTENT; the defer fact, reason string, and re-surface obligations are all recorded mechanically), and `metrics.items_deferred` carries the full id list so the chain summary re-surfaces them.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault location) | Ask via `AskUserQuestion` | If exactly 1 vault detected in CWD, use it without prompting. If 0 or >1, ask (or fail loudly if called with `--auto` from a non-orchestrator context). |
| Step 0 (lock check, if `Status: 🔒 LOCKED`) | Ask user to confirm unlock | Default to "proceed if DRAFT" (no unlock implied). If LOCKED, **STILL ASK** — unlocking has audit consequences. |
| Step 0.5 (resume detection) | Ask continue / fresh / cancel | Default to "continue from current state". |
| Step 0.6 (resolution scope) | Ask scope | Chain-routed via the `oq_gate` (express spine): `express-batched` (SKILL Step 0.6 — P1 batched ≤4 per call, P2/P3 auto-deferred on the record). Any other `--auto` caller: `p1-only` — DELIBERATE chain-context divergence from the interactive default (`all-priorities`): a chain only needs the P1 blocking tier resolved to resume. |
| Step 2b (the ONE per-OQ prompt: Resolve/Defer/OOS/Skip + the answer + the landing) | **Always ask** | **Always ask** (substance prompt — no override) |
| Step 2c (cross-cutting multi-doc landing) | Chosen on the Step 2b prompt — the primary doc + cross-refs are DISCLOSED in the answer option's description, so picking the option is the human's confirmation | Identical — always the human's call, never auto-decided |
| Step 2c (Defer follow-up: `defer_to` + reason; OOS follow-up: rationale) | **Always ask** — ONE call, and for Defer that call carries BOTH questions | **Always ask** — recorded state may never be defaulted or derived (invariant #5) |

What stays interactive even with `--auto`:

- **Per-OQ choice** (Resolve / OOS / Defer / Skip) — captures stakeholder answers; never auto-decides.
- **Resolution destination** — still a human decision, now made ON the single prompt: the auto-classified target rides the answer option's description, and the override channel is "Other" (a bare `→ <file>.md` accepts the recommendation and re-lands it) plus the Step 2c diff summary. The override target is VALIDATED before any write against the vault's own document filenames for its layout (`interactive-walk.md` §"Reading the Other free text" step 1) — a miss is not an override, is narrated, and never re-prompts.
- **Cross-cutting OQ landing** — same mechanism: the primary doc + cross-ref plan are disclosed in the option the human picks.
- **LOCKED vault unlock confirmation** — audit-significant.

The `--auto` skips remain **logistical only**. Nothing in the collapse converts a substance prompt into a default: the count of human decisions per OQ is unchanged, only the number of round trips they cost.

When this skill is invoked without `--auto`, behavior is the standard interactive walk.

## Non-interactive auto-accept mode

Enables `resolve-oq` to be invoked automatically by `orchestrate-flow --converge` without prompting the user, using recommendations grounded in KB / vault / codebase evidence (grounded sources only).

### Flags

- `--auto-accept` — skip `AskUserQuestion`; auto-pick the recommendation when available
- `--confidence-min=N` (default 0.80) — minimum recommendation confidence to auto-accept (≥0.80 standard)
- `--non-interactive` — combined alias for `--auto-accept --confidence-min=0.80` + suppresses any informational prompts

### Logic when `--auto-accept` set

For each OQ/CONFLICT during the walk:

1. Build the recommendation via the context-aware recommendation flow (KB / vault / codebase / silent fallback) — per the recommendation reference the SKILL.md router lists.
2. Check recommendation confidence:
   - `confidence >= confidence-min` → auto-apply the recommendation; skip `AskUserQuestion`. The audit trail is the PIPELINE record: the vault resolve markers + the `derive-vault-json.sh --event` changelog entry each outcome already writes.
   - `confidence < confidence-min` → escalate: surface the OQ as still-open; emit log "recommendation low-conf; deferred for manual resolve-oq".
3. After the walk: emit a summary with auto-accepted count + deferred count.
4. Status `paused` (not `completed`) if any OQs were deferred for manual resolution; the chain resumes after the user's manual walk.

### Use case — convergence loops

When `orchestrate-flow --converge` halts on `binding_conflict` (execute-bolts run start, `derive-exec-plan.sh`):

```
🔁 Cycle 1/3: invoking resolve-oq --binding <vault> --auto-accept --confidence-min=0.80

resolve-oq walking 3 conflicts:
  ✓ U-007 · C-U007-01 (auth) → KEEP_CODE (codebase anchor evidence; conf 0.95) → AUTO-ACCEPTED
  ✓ U-009 · C-U009-02 (Sanctum) → KEEP_VAULT (constitution §B-001; conf 1.00) → AUTO-ACCEPTED
  ⏸ U-011 · C-U011-01 (audit schema) → recommendation conf 0.65 < 0.80 → DEFERRED for manual

2 conflicts resolved auto; 1 deferred. Convergence loop re-invokes execute-bolts: its run start re-binds and re-plans.
```

### Anti-halu rails

- `--auto-accept` requires `confidence-min` (default 0.80; no silent low-conf acceptance).
- Audit trail: every auto-accepted outcome lands in the vault markdown + the vault.json changelog event — the same record a manual walk writes.
- The user CAN override auto-accepted decisions later via a standard interactive `resolve-oq` walk.
- High-stakes business OQs (P1 + category: business) NEVER auto-accept; always require interactive review even with `--auto-accept`.

### Backward compat

- Invocations of `resolve-oq` without the new flags → unchanged interactive behavior.
- `--auto-accept` is opt-in; no default behavior change.

## Scope context in OQ resolution

When `vault.json` has a `scope` field, the OQ resolution panel surfaces scope context for the user (read `vault.json` scope at skill start; prepend to each `AskUserQuestion`):

```
OQ-AR-7 [P1] [tech] (scope: BE — Backend API):
  Question: Use RFC 7807 problem+json envelope?
  ...
```

This helps multi-architect scenarios where one OQ might involve cross-scope dependencies — the user knows which scope they are answering for. The handoff YAML includes the `scope:` block (below) per `orchestrate-flow/references/handoff-contract.md` when the vault has scope.

## Handoff emission

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd --resume` after a halt), emit a handoff YAML record at the end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: resolve-oq
  emitted_at: <ISO8601 timestamp>
  status: completed | paused
  artifacts:
    - <absolute path to vault.json (updated)>
    - <absolute path to the touched bolts/U-*/binding.json when --binding mode (layout-2 leg: binding.md)>
  next_action:
    # --binding mode — the next hop is ACTION-MIX dependent (binding-mode.md Step 5):
    #   • any KEEP_CODE or SPLIT (a unit was edited) → the engine runs scripts/rebind-units.sh
    #     --units=<edited U-ids>, then mega-sdd:plan ["--reconcile", "--auto"] (task_type flips) → execute-bolts
    #   • ONLY KEEP_VAULT / DEFER → mega-sdd:execute-bolts ["--all", "--lite", "--auto"] (no re-bind;
    #     a later re-bind carries the resolutions forward — _lib/unit_binding.py)
    #   • layout-2 leg (binding.md) → propose /mega-sdd:migrate-paths --vault-layout=3, never run silently
    # standard OQ walk → mega-sdd:orchestrate-flow (resume chain)
    suggested_skill: mega-sdd:plan    # KEEP_CODE/SPLIT; OR mega-sdd:execute-bolts (KEEP_VAULT/DEFER only) OR mega-sdd:orchestrate-flow (standard walk)
    suggested_args: ["--reconcile", "--auto"]
    rationale: "<1-sentence — e.g., 'KEEP_CODE/SPLIT; edited units re-bound, reconcile task_type' / 'KEEP_VAULT/DEFER only; gate open, resume bolts' / 'P1 OQs answered; chain resumable'>"
  blockers: [] # on halt: a LIST of envelope bodies `[ { type, emitted_by, details } ]` — never a mapping (handoff-contract.md §blockers)
  metrics:
    items_processed: <N OQs/CONFLICTs walked>
    items_resolved: <N actions taken>
    # STATUS RULE (P3 pin): express auto-defers ALONE never flip status to
    # `paused` — a fully-executed express-batched walk (every P1 answered or
    # explicitly skipped, P2/P3 auto-deferred on the record) ends
    # `completed`; `paused` remains for mid-walk abandonment and low-conf
    # auto-accept deferrals awaiting manual resolution. Without this pin the
    # chain would stop after resolve-oq on EVERY express run.
    items_deferred:              # P3: an ID LIST, never a bare count — a count cannot re-surface
      - {tag: OQ-AR-7, priority: P2, reason: "auto-deferred (P2, express) — bukan blocker delivery pertama; muncul lagi di delivery report"}
    items_blocked: <N>                    # canonical handoff metric per handoff-contract.md
  scope:                                  # when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

Status `paused` if the user opted to walk away mid-resolution (some OQs unresolved). Standalone invocation (without `--auto`) emits an informational chat hint only.
