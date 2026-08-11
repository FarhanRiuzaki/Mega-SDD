# Telemetry Schema — Fork A scope lock (v3.48.0+, Iter 67.5)

> **Honest reset.** Iter 64 locked an aspirational 16-event schema; only 1 of those events ever emitted in real runs (per audit `docs/superpowers/audits/2026-05-27-iter-67-integrity-audit.md`). Iter 67.5 shrinks the schema to what is *actually* emitted via Claude Code hooks (Fork A). The 11 control-layer events (classifier, guard, Plan/Act) are PARKED as Fork-B-future and are NOT emitted in Fork A.

## Contents

- Fork A scope (this doc) vs Fork B (future)
- Storage location
- Emission mechanism (Fork A — only the hook layer is reliable)
- Event schema (live events only)
- Fork-B-future (PARKED — NOT emitted in Fork A)
- Iter 68 analysis prerequisites (REVISED for Fork A)
- Schema evolution policy (revised)

## Fork A scope (this doc) vs Fork B (future)

**Fork A — Telemetry-only, model-can't-no-op layer:**
- Emit via Claude Code hooks (`PostToolUse`, `Stop`). The hook layer is the only model-proof surface in Claude Code; the model cannot skip a hook.
- Scope: what files were loaded, what skills were invoked via the Skill tool, when turns ended (with real harness-reported usage).
- Cannot enforce control flow (classifier-gating, recursion-budget, Plan/Act mode). Those need a runtime control plane the model can't bypass — that's Fork B (Agent SDK / custom runtime).

**Fork B — Deterministic control plane (FUTURE; explicitly parked at Iter 67.5):**
- Classifier output → ceremony gating
- Anti-recursive guard → re-plan / re-validate caps
- Plan/Act mode gating per complexity
- All "Runtime SHIPPED" claims from Iter 65 + 67 are RETRACTED (audit §C, §D, §E). The scripts (`classify-iter.sh`, `check-recursion-budget.sh`) exist as advisory tools; no skill body actually Bash-invokes them. Retracting the claims is the honest move.

## Storage location

`<project>/.mega-sdd/memory/telemetry.jsonl` — append-only, line-delimited JSON, one event per line.

**Opt-out:** `--no-telemetry` flag on `/mega-sdd` and `/mega-sdd` (per-invocation, advisory only — hooks don't read this flag) OR `telemetry: false` in `<project>/.mega-sdd/config.yaml` (persistent — hooks DO honor this).

**Diagnostic log (Iter 67.5):** Stop hook also writes to `<project>/.mega-sdd/memory/hook-debug.log` on every Stop invocation (one JSON line per fire). Purpose: prove the Claude Code harness is actually invoking the hook for the project CWD. If `hook-debug.log` doesn't grow during a real turn, the hook is not being called and no amount of script-side debugging will fix it.

## Emission mechanism (Fork A — only the hook layer is reliable)

| Event type | Emitted by | Reliability |
|---|---|---|
| `ref_loaded` | `plugins/mega-sdd/hooks/post-tool-use` (PostToolUse, matcher `Read\|Skill\|Bash`) | HIGH — fires for Read AND Bash `cat\|head\|tail\|grep\|less\|more\|rg` of mega-sdd paths, **including inside dispatched subagents** (PostToolUse fires on subagent fg+bg tool calls — settled by a 3-sentinel telemetry probe; see the archived audit record `docs/superpowers/audits/2026-06-05-audit-md-rounds-1-3-ARCHIVED.md` Round-2 L1). **HONEST UNDER-COUNT (cause = lossy emission, NOT subagent invisibility):** the hook is async + every append is best-effort (`>> … 2>/dev/null \|\| true`, exit-0-always) so events can drop under load; and complex Bash (shell redirection `< file`, awk/sed-via-stdin, find-exec, xargs) is unparseable by the verb-regex. `ref_loaded` therefore UNDER-COUNTS true loads. |
| `skill_invoked` | `plugins/mega-sdd/hooks/post-tool-use` (PostToolUse, matcher `Skill`) | LOW — captures explicit `/mega-sdd:*` user invocations only. Most mega-sdd skill activation bypasses the Skill tool (anchor injection, in-thread CLAUDE.md context, internal orchestrate-flow chains). Audit-confirmed effective dead surface; kept in schema for completeness. |
| `turn_end_marker` | `plugins/mega-sdd/hooks/stop` (Stop) | HIGH (if harness invokes Stop for project CWD — verified via `hook-debug.log`). Payload includes real harness-reported `usage: {input_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens}` extracted from the last `assistant` message in `transcript_path`. |
| `halt_fired` | Skill body (markdown convention) | **BEST-EFFORT, UNRELIABLE.** Audit-confirmed: 0 emissions in real runs pre-67.5. Skill bodies may include emit-step instructions; model may or may not execute them. Treat as supplementary, not ground truth. |
| `activation_outcome` | Skill body (markdown convention) | Same as `halt_fired`. |
| `halt_self_resolved` (v3.50.0+, Iter 67.7 Phase A) | Skill body (markdown convention — same caveat as halt_fired) | Emitted when a C1-classified halt auto-resolves per `plugins/mega-sdd/references/halt-protocol.md §halt-escalation-discipline §C1 self-resolve protocol`. Anti-erosion mechanism: every self-resolve is logged to enable Iter 68 audit of C1 frequency + class distribution. If a C1 class fires too often → indicates skill emission bug worth root-cause review. |

Aggregation (`turn_loaded_summary`-style metrics): derived offline by Iter 68 by rolling up `ref_loaded` events bracketed by adjacent `turn_end_marker` events. Per-turn token totals use the `usage.input_tokens` field on the trailing `turn_end_marker` (real number from harness), NOT the sum of `ref_loaded.estimated_tokens` (which under-counts due to the blind spots above).

## Event schema (live events only)

Top-level shape per JSONL line:

```json
{
  "ts": "<ISO8601 UTC>",
  "skill": "<emitter skill name; defaults to 'orchestrate-flow' for hook-emitted events>",
  "event_type": "ref_loaded | skill_invoked | turn_end_marker | halt_fired | activation_outcome | halt_self_resolved",
  "session_id": "<Claude Code session UUID from hook stdin>",
  "hook_source": "PostToolUse | Stop | null",
  "payload": { /* event-specific; see below */ }
}
```

### `ref_loaded`

Emitted by PostToolUse hook for every Read OR Bash-driven read of a mega-sdd-relevant path.

```json
{
  "event_type": "ref_loaded",
  "hook_source": "PostToolUse",
  "payload": {
    "file_path": "/abs/path/to/file.md",
    "lines": 327,
    "bytes": 18353,
    "estimated_tokens": 4588,
    "source_tool": "Read | Bash"
  }
}
```

`estimated_tokens` = `bytes / 4` (industry approximation for English text). For exact per-turn token cost, prefer `turn_end_marker.payload.usage.input_tokens` (harness-reported).

`source_tool` distinguishes direct Read events from Bash-derived events. Useful for Iter 68 to estimate the size of the Bash-coverage gap (e.g., if Bash events dominate, the Read-only matcher would have lost most data).

### `skill_invoked`

Emitted when user invokes a `mega-sdd:*` or `using-mega-sdd` skill explicitly via the Skill tool. Rare in practice.

```json
{
  "event_type": "skill_invoked",
  "hook_source": "PostToolUse",
  "payload": {
    "skill_full_name": "mega-sdd:orchestrate-flow"
  }
}
```

### `turn_end_marker`

Emitted by Stop hook at the end of every agent turn (subject to opt-out + `.mega-sdd/` existence).

```json
{
  "event_type": "turn_end_marker",
  "hook_source": "Stop",
  "payload": {
    "usage": {
      "input_tokens": 12345,
      "cache_creation_input_tokens": 6789,
      "cache_read_input_tokens": 98765,
      "output_tokens": 432
    },
    "stop_hook_active": false
  }
}
```

`usage` is extracted from the last `assistant` message in `transcript_path` (stdin from Claude Code). When `transcript_path` is missing or the file is unreadable, `usage: {}` — the turn boundary is still recorded, just without token data.

`stop_hook_active: true` indicates the agent is currently in a Stop-hook continuation (the harness can re-invoke the agent after a hook). Useful to filter out non-user-turn boundaries during Iter 68 analysis.

### `halt_fired` (best-effort, unreliable)

Emitted by skill bodies when they hit a structured halt per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. Pre-67.5: zero such events in real runs. Skill bodies MAY include emit-step instructions; model compliance is unverified.

```json
{
  "event_type": "halt_fired",
  "hook_source": null,
  "payload": {
    "halt_type": "unit_oq_trace_missing",
    "halt_details": { /* per-halt-type */ }
  }
}
```

### `activation_outcome` (best-effort, unreliable)

End-of-skill outcome marker. Same reliability caveat as `halt_fired`.

```json
{
  "event_type": "activation_outcome",
  "hook_source": null,
  "payload": {
    "skill": "<skill name>",
    "outcome": "success | halted | user_aborted | downstream_failure",
    "false_positive_signal": "user_explicit_skip | wrong_skill_invoked | overlap_with_other_skill | null"
  }
}
```

## Fork-B-future (PARKED — NOT emitted in Fork A)

These event types were declared in Iter 64's locked schema but never had working emitters. They are parked here, NOT removed entirely, so future Fork B work can pick up the design without rediscovering.

| Parked event_type | Original intent | Why parked |
|---|---|---|
| `tier_classification_decision` | Log declared_tier from manifest + loaded_this_session per ref | No skill body emits; tier enforcement is Fork-B |
| `turn_loaded_summary` | Per-turn aggregate of ref_loaded events | Derived offline from `ref_loaded` + `turn_end_marker` in Fork A; no live emit needed |
| `iter_classifier_output` | EP1/EP2 classifier output | `classify-iter.sh` exists but no skill body Bash-invokes it (audit §C). Wiring needs a non-prose control plane = Fork B |
| `iter_classifier_drift` | EP1 != EP2 drift detection | Cascades from classifier — Fork B |
| `replan_triggered` | Re-plan counter increment | `check-recursion-budget.sh` not referenced by any skill body (audit §D). Fork B |
| `revalidate_triggered` | Re-validate counter increment | Same as above |
| `replan_budget_exceeded` | max_replan_count cap hit | Same |
| `revalidate_budget_exceeded` | max_revalidate_count cap hit | Same |
| `plan_mode_entered` | Plan-mode entry per Iter 67 gating | Depends on broken classifier (audit §E). Fork B |
| `act_mode_entered` | Act-mode entry | Same |
| `plan_act_transition` | Plan→Act handoff | Same |

**Status of advisory scripts:** `plugins/mega-sdd/scripts/classify-iter.sh` and `plugins/mega-sdd/scripts/check-recursion-budget.sh` remain in the repo as advisory tools (a developer can run them by hand, e.g., `bash classify-iter.sh --ep=EP1` to check what an iter would classify as). They are NOT wired into any chain. CLAUDE.md retracts the "Runtime SHIPPED" claim.

## Iter 68 analysis prerequisites (REVISED for Fork A)

Soak gates per `plugins/mega-sdd/CLAUDE.md` §Telemetry Collection — REVISED Iter 67.5:

- ≥ 14 calendar days elapsed since **Iter 67.5 verified-write date** (clock starts on first real run that produces ≥1 `ref_loaded` + ≥1 `turn_end_marker` event in the same session)
- ≥ 10 real chain runs with non-empty `turn_end_marker` events (one per session = the most reliable run-count proxy)
- `hook-debug.log` confirms Stop hook fires for the project CWD (one debug line per turn)

If soak passes with all 3 gates → Iter 68 may proceed with the analysis it CAN do: ref-load distribution per skill, per-turn token cost from harness numbers, Bash-vs-Read coverage estimate. Iter 68 cannot analyze classifier accuracy, recursion-budget distribution, or Plan/Act behavior — those are Fork-B-future.

## Schema evolution policy (revised)

Iter 64's "frozen mid-soak" policy was based on the assumption that 16 event types were being emitted. Since only 5 actually emit (and 11 are parked), the freeze policy is RELAXED to:

- Additive changes to live events (new payload subfields under `payload.*`) are allowed mid-soak — they don't invalidate prior data.
- Adding new event_types is allowed but rare — every addition needs an audit-verified emitter before declaring it shipped.
- Removing or renaming live-event fields requires a schema migration plan (rare; not anticipated in Fork A).
- Parked events listed above can be UN-parked (moved to live section) only when both a working emitter AND artifact-verified telemetry from a real run exist.

The previous Iter 64 schema lock document (in git history at v3.44.0 — v3.47.0) is preserved for reference but superseded by this doc.
