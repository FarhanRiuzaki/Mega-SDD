# resolve-oq — --auto, memory layer, auto-accept & handoff

## Contents
- --auto flag (logistical-only skip table)
- Memory layer (reads / writes / anti-halu rails)
- Non-interactive auto-accept mode (flags + logic + convergence-loop use)
- Scope context in OQ resolution
- Handoff emission (YAML)

Loaded when `resolve-oq` runs under `--auto`, as an `orchestrate-flow` chain phase, or in a convergence loop. The interactive walk, binding mode, and recommendation building each have their own reference, listed by the SKILL.md router; this file covers only the non-interactive machinery.

## --auto flag

The `--auto` flag is passed by upstream callers (typically `/mega-sdd:orchestrate-flow`) to skip **logistical** prompts only. **Substance prompts — per-OQ Resolve / Out-of-Scope / Defer / Skip choices — ALWAYS stay interactive.** That is the entire point of this skill: capturing stakeholder answers, not Claude's guesses.

| Step | Interactive behavior | `--auto` behavior |
|------|---------------------|-------------------|
| Step 0 (vault location) | Ask via `AskUserQuestion` | If exactly 1 vault detected in CWD, use it without prompting. If 0 or >1, ask (or fail loudly if called with `--auto` from a non-orchestrator context). |
| Step 0 (lock check, if `Status: 🔒 LOCKED`) | Ask user to confirm unlock | Default to "proceed if DRAFT" (no unlock implied). If LOCKED, **STILL ASK** — unlocking has audit consequences. |
| Step 0.5 (resume detection) | Ask continue / fresh / cancel | Default to "continue from current state". |
| Step 0.6 (resolution scope) | Ask scope | Default to `p1-only`. |
| Step 2 (per-OQ Resolve/OOS/Defer/Skip) | **Always ask** | **Always ask** (substance prompt — no override) |
| Step 2c (cross-cutting multi-doc landing) | Ask user to confirm primary doc | Always ask (substance prompt — landing affects content placement) |

What stays interactive even with `--auto`:

- **Per-OQ choice** (Resolve / OOS / Defer / Skip) — captures stakeholder answers; never auto-decides.
- **Resolution destination override** when auto-classification is wrong.
- **Cross-cutting OQ landing prompts** — affects which doc the answer lives in.
- **LOCKED vault unlock confirmation** — audit-significant.

When this skill is invoked without `--auto`, behavior is the standard interactive walk.

## Memory layer

When memory is enabled (default; opt-out via `--memory-off`), this skill participates in the mega-sdd memory layer per `memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After each OQ resolved (standard mode) | `<project>/.mega-sdd/memory/decisions.md` | Append row to `## OQ resolutions` table: date, oq-id, category, resolution-text, source-run |
| After each CONFLICT resolved (--binding mode) | `<project>/.mega-sdd/memory/decisions.md` | Append row to `## CONFLICT resolutions` table: date, conflict-id, claim, KEEP_CODE/KEEP_VAULT/DEFER/SPLIT, user-rationale, source-run |
| After each recommend-mode OQ ACCEPT/OVERRIDE/REJECT | `<project>/.mega-sdd/memory/decisions.md` | Append row to `## Recommendation outcomes` table |

The `## OQ resolutions` table gains an optional `scope` column when the vault has a `scope` field.

### Reads

| What | Source | How used |
|---|---|---|
| Past CONFLICT resolutions matching current conflict claim pattern | `<project>/.mega-sdd/memory/decisions.md` (passed via handoff `metadata.memory_context.project_decisions_relevant` when under --auto) | SUGGEST a pre-filled action in `AskUserQuestion` (e.g., "Past pattern: 8/10 KEEP_CODE on auth conflicts. Default to KEEP_CODE? Y/N/Other"). User still confirms each time. |
| Cross-project patterns (when project memory has no match) | `~/.mega-sdd/memory/patterns.md` | SUGGEST a per-pattern action with confidence + source observation count |

### Anti-halu rails

- Memory consultation surfaces as a SUGGESTION, never enforcement.
- Every suggestion cites its source memory entry.
- Current evidence (the current conflict's full context) always wins over memory.
- `--memory-off` disables both reads and writes.

## Non-interactive auto-accept mode

Enables `resolve-oq` to be invoked automatically by `orchestrate-flow --converge` without prompting the user, using memory-pre-filled recommendations.

### Flags

- `--auto-accept-from-memory` — skip `AskUserQuestion`; auto-pick the recommendation when available
- `--confidence-min=N` (default 0.80) — minimum recommendation confidence to auto-accept (≥0.80 standard)
- `--non-interactive` — combined alias for `--auto-accept-from-memory --confidence-min=0.80` + suppresses any informational prompts

### Logic when `--auto-accept-from-memory` set

For each OQ/CONFLICT during the walk:

1. Build the recommendation via the context-aware recommendation flow (KB / memory / vault / codebase / silent fallback) — per the recommendation reference the SKILL.md router lists.
2. Check recommendation confidence:
   - `confidence >= confidence-min` → auto-apply the recommendation; log to memory `decisions.md` with `source: ai_auto_accepted`; skip `AskUserQuestion`.
   - `confidence < confidence-min` → escalate: surface the OQ as still-pending; emit log "recommendation low-conf; deferred for manual resolve-oq".
3. After the walk: emit a summary with auto-accepted count + deferred count.
4. Status `paused` (not `completed`) if any OQs were deferred for manual resolution; the chain resumes after the user's manual walk.

### Use case — convergence loops

When `orchestrate-flow --converge` hits `bind_conflict`:

```
🔁 Cycle 1/5: invoking resolve-oq --binding --auto-accept-from-memory --confidence-min=0.80

resolve-oq walking 3 conflicts:
  ✓ C-007 (auth) → KEEP_CODE (memory 8/10; conf 0.95) → AUTO-ACCEPTED
  ✓ C-009 (Sanctum) → KEEP_VAULT (constitution §B-001; conf 1.00) → AUTO-ACCEPTED
  ⏸ C-011 (audit schema) → recommendation conf 0.65 < 0.80 → DEFERRED for manual

2 conflicts resolved auto; 1 deferred. Convergence loop continues to re-bind.
```

### Anti-halu rails

- `--auto-accept-from-memory` requires `confidence-min` (default 0.80; no silent low-conf acceptance).
- Audit trail: every auto-accepted decision logged to memory with the `source: ai_auto_accepted` marker.
- Recurring same-pattern auto-accepts captured in pattern memory for review via `/mega-sdd:memory review`.
- The user CAN override auto-accepted decisions later via a standard interactive `resolve-oq` walk.
- High-stakes business OQs (P1 + category: business) NEVER auto-accept; always require interactive review even with `--auto-accept-from-memory`.

### Backward compat

- Invocations of `resolve-oq` without the new flags → unchanged interactive behavior.
- `--auto-accept-from-memory` is opt-in; no default behavior change.
- Memory consultation already exists in the base skill; the new flag just changes when to AUTO-APPLY recommendations.

## Scope context in OQ resolution

When `vault.json` has a `scope` field, the OQ resolution panel surfaces scope context for the user (read `vault.json` scope at skill start; prepend to each `AskUserQuestion`):

```
OQ-AR-7 [P1] [tech] (scope: BE — Backend API):
  Question: Use RFC 7807 problem+json envelope?
  ...
```

This helps multi-architect scenarios where one OQ might involve cross-scope dependencies — the user knows which scope they are answering for. Decisions written to memory `<project>/.mega-sdd/memory/decisions.md` `## OQ resolutions` table get the optional `scope` column when applicable. The handoff YAML includes the `scope:` block (below) per `orchestrate-flow/references/handoff-contract.md` when the vault has scope.

## Handoff emission

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd:auto --resume` after a halt), emit a handoff YAML record at the end of skill output per `orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: resolve-oq
  emitted_at: <ISO8601 timestamp>
  status: completed | paused
  artifacts:
    - <absolute path to vault.json (updated)>
    - <absolute path to binding.md (when --binding mode)>
  next_action:
    # --binding mode — the next hop is ACTION-MIX dependent (binding-mode.md Step 5). A
    # blanket re-bind LOOPS on KEEP_VAULT/DEFER: bind re-derives the SAME CONFLICT from the
    # unchanged vault-vs-code contradiction (it never consumes a prior resolution as evidence).
    #   • any KEEP_CODE or SPLIT chosen (vault was edited)  → mega-sdd:bind-codebase   (re-bind is clean)
    #   • ONLY KEEP_VAULT / DEFER (vault + code unchanged)  → mega-sdd:generate-units  (the resolution-marked binding.md already passes validate-handoff-binding-units.sh; proceed)
    # intent mode (non-binding OQ walk) → mega-sdd:orchestrate-flow (resume chain)
    suggested_skill: mega-sdd:bind-codebase    # OR mega-sdd:generate-units (KEEP_VAULT/DEFER-only) OR mega-sdd:orchestrate-flow (intent mode)
    suggested_args: ["--auto"]
    rationale: "<1-sentence — e.g., 'KEEP_CODE/SPLIT resolutions; re-run binding gate' / 'KEEP_VAULT/DEFER only; binding resolved, proceed to units' / 'P1 OQs answered; chain resumable'>"
  blockers: []
  metrics:
    items_processed: <N OQs/CONFLICTs walked>
    items_resolved: <N actions taken>
    items_deferred: <N kept as deferred>
    items_blocked: <N>                    # canonical handoff metric per handoff-contract.md
  scope:                                  # when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

Status `paused` if the user opted to walk away mid-resolution (some OQs unresolved). Standalone invocation (without `--auto`) emits an informational chat hint only.
