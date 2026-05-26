# Telemetry Schema — LOCKED Iter 64 ship (v3.44.0+, Iter 66a v3.47.0+ emission rewire)

> **DAY-1 CAPTURE REQUIRED — cannot be backfilled.** Whatever Iter 64 does not log, Iter 68 analysis cannot recover. Schema fields are FROZEN at Iter 64 ship; cannot evolve mid-soak.
>
> Source of truth for telemetry event format. Consumed by: skills that emit telemetry events (`memory` + indirectly all skills via convention), Iter 68 analysis (deferred), Iter 69 budget tuning (deferred), Iter 70 consolidation decisions (deferred).
>
> **Iter 66a correction (v3.47.0+):** Iter 64 schema-lock was correct, but emission was broken — skill bodies were INSTRUCTED to emit (markdown convention), zero skill bodies actually emitted (verified: `grep -rE "token_count|loaded_per_turn|>> .*telemetry" plugins/mega-sdd/skills/` returned 0 hits). Iter 66a fixes this by emitting via **Claude Code hooks** (PostToolUse + Stop), NOT markdown instructions. Hooks fire in harness with access to tool_input/tool_response — more accurate than model self-counting (model cannot precisely count its own context tokens; harness can). Schema unchanged; only emission mechanism replaced.

## Storage location

`<project>/.mega-sdd/memory/telemetry.jsonl` — append-only, line-delimited JSON, one event per line.

Opt-out: `--no-telemetry` flag on `/mega-sdd:auto` and `/mega-sdd:orchestrate-flow` suppresses all writes. Existing telemetry.jsonl preserved (not deleted). Persistent opt-out via `<project>/.mega-sdd/config.yaml`: `telemetry: false`.

## Emission mechanism (Iter 66a — v3.47.0+)

| Event type | Emitted by | When |
|---|---|---|
| `ref_loaded` | `plugins/mega-sdd/hooks/post-tool-use` (PostToolUse hook, matcher=`Read`) | Every Claude Code `Read` of a mega-sdd-relevant path (skills/, references/, CLAUDE.md, `.mega-sdd/vaults/`, `.mega-sdd/codebase/`, `.mega-sdd/knowledge-base/`) |
| `skill_invoked` | `plugins/mega-sdd/hooks/post-tool-use` (PostToolUse hook, matcher=`Skill`) | Every `Skill` invocation with name `mega-sdd:*` OR `using-mega-sdd` |
| `turn_end_marker` | `plugins/mega-sdd/hooks/stop` (Stop hook) | End of every agent turn (only if telemetry.jsonl already exists) |
| `iter_classifier_output` / `iter_classifier_drift` | `plugins/mega-sdd/scripts/classify-iter.sh` | EP1 + EP2 in orchestrate-flow chain |
| `replan_triggered` / `revalidate_triggered` / `*_budget_exceeded` | `plugins/mega-sdd/scripts/check-recursion-budget.sh` | Anti-recursive guard increments + cap hits |
| `halt_fired` / `activation_outcome` / `plan_mode_entered` / etc. | Skill body markdown convention (best-effort) | Per-skill emission points; less reliable than hook-emitted events |

**Why hooks over markdown:** the model cannot count its own context tokens precisely (schema even writes `estimated_tokens`). Hooks run in the Claude Code harness with deterministic access to `tool_input` + `tool_response` → exact byte/line counts. Markdown-instructed emission was Iter 64's design choice; Iter 66a (post-empirical-gap-discovery) replaced it.

**Hook registration:** see `plugins/mega-sdd/hooks/hooks.json` — registers PostToolUse (matcher `Read|Skill`) + Stop (matcher `""`) handlers. Both async (telemetry never blocks tool execution or turn completion).

## Event schema (LOCKED)

```json
{
  "ts": "<ISO8601 timestamp>",
  "skill": "<skill name, e.g., generate-intent>",
  "event_type": "skill_invoked | ref_loaded | halt_fired | tier_classification_decision | iter_classifier_output | iter_classifier_drift | activation_outcome | turn_loaded_summary | turn_end_marker | replan_triggered | revalidate_triggered | replan_budget_exceeded | revalidate_budget_exceeded | plan_mode_entered | act_mode_entered | plan_act_transition",
  "turn_id": "<UUID per agent turn — same across events in same turn>",
  "session_id": "<UUID per Claude Code session — same across turns in same session>",

  "iter_classifier": {
    "ep": "EP1 | EP2",
    "output": "PATCH | MINOR | MAJOR",
    "criteria_matched": ["files_changed_5_15", "existing_skill_modified", "..."],
    "explicit_flag": null
  },

  "token_count": {
    "estimated_input": 0,
    "estimated_output": 0,
    "reference_loads": [
      {"path": "references/vault-contract.md", "estimated_tokens": 1200}
    ]
  },

  "loaded_per_turn": {
    "turn_id": "<UUID — duplicated here for query convenience>",
    "skill": "<skill that loaded this content>",
    "lines_loaded": 0,
    "tokens_loaded": 0,
    "breakdown_by_tier": {
      "hot": {"lines": 0, "tokens": 0},
      "specialist": {"lines": 0, "tokens": 0, "refs_loaded": []},
      "cold": {"lines": 0, "tokens": 0, "refs_loaded": []}
    }
  },

  "activation_outcome": {
    "skill": "<which skill was invoked>",
    "outcome": "success | halted | user_aborted | downstream_failure",
    "false_positive_signal": "user_explicit_skip | wrong_skill_invoked | overlap_with_other_skill | null",
    "downstream_skill_invoked_within_chain": null
  },

  "tier_classification_decision": {
    "ref_path": "references/saga-rollback.md",
    "declared_tier": "HOT | SPECIALIST | COLD",
    "loaded_this_session": false,
    "load_step": "Step 4.5.a.5"
  },

  "payload": {}
}
```

## Field rationale (each traces to a downstream consumer)

| Field | Consumed by | Why needed |
|---|---|---|
| `ts` | Iter 68 time-series analysis | Trend over soak window |
| `skill` + `event_type` | Iter 68 skill hit frequency | Which skills invoked most |
| `turn_id` + `session_id` | All Iter 68/69/70 aggregations | Group events by turn / session for per-turn metric (the metric per §9.4) |
| `iter_classifier.output` | Iter 68 classifier accuracy + Iter 69 budget tuning | Distribution of iter types over time |
| `iter_classifier.criteria_matched` | Iter 68 classifier audit | Are inputs catching the right cases? |
| `iter_classifier.explicit_flag` | Iter 68 override frequency | Do users override classifier often? Signal of misclassification |
| `token_count.estimated_input` | Iter 68 token-per-skill aggregate | Which skills heaviest in practice |
| `token_count.reference_loads` | Iter 68 hot/cold reality check | Per-ref token cost |
| **`loaded_per_turn.lines_loaded` + `tokens_loaded`** | **§9.4 NEW METRIC (the actual one)** | The metric that matters — turn-level context window cost. Replaces dead "skill body line count" metric. Iter 68 produces baseline; Iter 66 target = ≥30% reduction in median. |
| **`loaded_per_turn.breakdown_by_tier`** | Iter 66 lazy-loading manifest tuning | Empirical evidence of which refs load WHEN. SPECIALIST/COLD refs that never load → confirm tier; SPECIALIST refs that load every turn → reclassify HOT; HOT refs that rarely load → reclassify SPECIALIST. |
| `activation_outcome.outcome` | Iter 68 activation accuracy | Did invoked skill achieve its goal? |
| `activation_outcome.false_positive_signal` | Iter 68 false-positive rate | Hardest metric to capture — see Activation Outcome Labeling below |
| `tier_classification_decision.loaded_this_session` | Iter 68 tier discipline audit | Was HOT actually loaded? Was COLD never loaded? Validates Iter 66 lazy loading payoff |

## Event types

### `skill_invoked`
Emitted at start of skill body execution. Required fields: `ts`, `skill`, `event_type`, `turn_id`, `session_id`. Optional: `iter_classifier` (if EP1 ran at this point).

### `ref_loaded`
Emitted when skill body loads a reference file. Required: `ts`, `skill`, `event_type`, `turn_id`, `session_id`, `tier_classification_decision` (which ref, what tier, load_step).

### `halt_fired`
Emitted when skill emits a halt. Required: all base + `payload.halt_type` + `payload.halt_details`.

### `tier_classification_decision`
Emitted when skill manifest declares ref tier (Iter 66 manifest evaluation; Iter 64 = baseline classification declared in `skill-tier-manifest.yaml`).

### `iter_classifier_output`
Emitted by orchestrate-flow (Iter 65 runtime) when classify-iter.sh runs at EP1 or EP2. Required: `iter_classifier` populated.

### `iter_classifier_drift`
Emitted when EP1 output != EP2 output (scope grew during work). Required: `iter_classifier` + `payload.ep1_output` + `payload.ep2_output` + `payload.drift_reason`.

### `activation_outcome`
Emitted at end of skill body execution. Required: `ts`, `skill`, `turn_id`, `session_id`, `activation_outcome` block populated.

### `turn_loaded_summary` (THE metric event)
Emitted once per agent turn — aggregate of all `ref_loaded` events in the turn. Required: `ts`, `turn_id`, `loaded_per_turn` block fully populated. **Iter 66a:** populated by Iter 68 aggregation pass (rolls up `ref_loaded` events between two adjacent `turn_end_marker` events). Hooks emit `ref_loaded` per-event + `turn_end_marker` per-turn; the aggregate `turn_loaded_summary` is derived offline, not emitted live (model cannot count its own context tokens accurately enough mid-turn).

### `turn_end_marker` (Iter 66a — v3.47.0+)
Emitted by the Stop hook (`plugins/mega-sdd/hooks/stop`) when an agent turn completes. Enables Iter 68 to delimit per-turn `ref_loaded` windows. Required: `ts`, `session_id`, `hook_source: "Stop"`, `payload: {}`. Only fires if `<cwd>/.mega-sdd/memory/telemetry.jsonl` already exists (avoids polluting non-mega-sdd projects with empty `.mega-sdd/` directories on every Stop event).

### `replan_triggered` (Iter 65 — anti-recursive guard instrumentation)
Emitted by `check-recursion-budget.sh --action=increment-replan` when a re-plan starts. Required: `ts`, `turn_id`, `session_id`, `payload`:
```json
{
  "task_id": "<UUID per task>",
  "trigger": "execution_failed | ambiguity_increased | contract_mismatch",
  "replan_count_before": 0,
  "replan_count_after": 1,
  "details": {"<trigger-specific>": "..."}
}
```
**Why instrumented day-0:** without this event, tune #2 (revisit max_replan_count default of 2 post-Iter-68) is impossible — Iter 68 cannot analyze distribution of re-plans without per-trigger logs.

### `revalidate_triggered` (Iter 65)
Emitted by `check-recursion-budget.sh --action=increment-revalidate` when a re-validate starts. Required: same as `replan_triggered` but `revalidate_count_before`/`after` instead of `replan_count_*`.

### `replan_budget_exceeded` (Iter 65)
Emitted when `max_replan_count` exceeded → halt `quality_gate_failed:replan_budget_exceeded` fires. Required: `ts`, `turn_id`, `session_id`, `payload`:
```json
{
  "task_id": "<UUID>",
  "max_replan_count": 2,
  "actual_replan_count": 3,
  "trigger_history": ["execution_failed", "execution_failed", "contract_mismatch"],
  "halt_emitted": "quality_gate_failed:replan_budget_exceeded"
}
```
**Why instrumented:** captures every cap-exceeded event for tune #2 analysis (was default 2 the right cap? Tune to telemetry-validated value post-Iter-68).

### `revalidate_budget_exceeded` (Iter 65)
Emitted when `max_revalidate_count` exceeded → halt `quality_gate_failed:revalidate_budget_exceeded` fires. Required: same structure as `replan_budget_exceeded`.

### `plan_mode_entered` (Iter 67)
Emitted when orchestrate-flow Step 2.95 branches to Plan mode (MAJOR iter or `--plan` flag). Required: `ts`, `turn_id`, `session_id`, `payload`:
```json
{
  "iter_type": "PATCH | MINOR | MAJOR",
  "trigger": "classifier_major | explicit_plan_flag | plan_then_act_flag",
  "task_id": "<UUID>"
}
```

### `act_mode_entered` (Iter 67)
Emitted when orchestrate-flow Step 2.95 enters Act mode (any path). Required: `ts`, `turn_id`, `session_id`, `payload`:
```json
{
  "iter_type": "PATCH | MINOR | MAJOR",
  "trigger": "classifier_patch_direct | classifier_minor_direct | classifier_minor_act | plan_complete_transition | explicit_act_flag",
  "task_id": "<UUID>",
  "plan_consumed": false
}
```

### `plan_act_transition` (Iter 67)
Emitted when Act mode reads + consumes `.plan-pending` (transitions from Plan to Act). Required: `ts`, `turn_id`, `session_id`, `payload`:
```json
{
  "task_id": "<UUID>",
  "plan_emitted_at": "<ISO8601>",
  "transition_at": "<ISO8601>",
  "transition_via": "act_flag | mega_sdd_act_command | text_acknowledgment",
  "elapsed_seconds": 0,
  "plan_actions_count": 0,
  "stale_plan_warning_fired": false
}
```

## Shakedown protocol (Iter 67 — soak governance)

Per CLAUDE.md §Soak Shakedown Protocol: first 1-2 real chain runs after Iter 67 ship MARKED `payload.shakedown: true` to exclude from soak ≥10 threshold until interaction verified. Marker is `payload.*` field — does not violate schema lock policy.

Telemetry events from shakedown runs include `payload.shakedown: true`. Iter 68 analysis filters these out of soak count.

```json
{
  "ts": "...",
  "event_type": "skill_invoked",
  "payload": {
    "shakedown": true
  }
}
```

After 2 shakedown runs complete cleanly: skills stop emitting the marker (manual flip via `<project>/.mega-sdd/config.yaml` `defaults.shakedown_complete: true` OR `2 runs since Iter 67 ship date` automatic). Future runs count toward soak.

## Activation outcome labeling (the hard metric)

**Auto signals (no user effort):**
- `outcome: user_aborted` when AskUserQuestion Cancel hit
- `outcome: halted` when halt fires
- `outcome: downstream_failure` when next-step skill in chain fails AND failure trace points back to current skill's handoff
- `outcome: success` when handoff status = completed AND chain proceeds

**Semi-auto signal:**
- `false_positive_signal: overlap_with_other_skill` when 2+ skills invoked within 60s AND latter's input was previous's output (overlap heuristic)

**Manual signal (user opt-in):**
- `/mega-sdd:telemetry label <event-id> false-positive` retroactively marks wrong-skill invocation. Stored as separate label event with reference to original.

If activation accuracy cannot be captured reliably for some cases: Iter 68 documents as known limitation. Other metrics (skill hit freq, tokens-per-skill, tier discipline, `loaded_per_turn`) remain actionable.

## Soak gates (Iter 68 prerequisite)

Iter 68 analysis fires ONLY if BOTH:
- ≥ 14 calendar days elapsed since Iter 64 ship
- ≥ 10 real chain runs logged (NOT test runs — distinguished by `payload.is_test_run: true` marker on synthetic events)

**Real pipeline usage during soak is REQUIRED.** If soak window passes with <10 runs OR <14 days: Iter 68 emits "DATA INSUFFICIENT" report instead of conclusions; SP3 gate stays closed; Iter 66 manifest tuning cannot proceed.

User-side discipline: run mega-sdd on at least one real project during soak (e.g., TF Import Phase 2 if scheduled).

## Frozen-schema policy

This schema is LOCKED at Iter 64 v3.44.0 ship. Field additions during soak window are FORBIDDEN — they would create non-uniform data across the soak window. Field semantics changes are FORBIDDEN.

Allowed mid-soak operations:
- Add NEW event_type values (existing fields unchanged)
- Add OPTIONAL payload-level fields under `payload.*` (does not affect base schema)

Forbidden mid-soak:
- Remove or rename existing top-level fields
- Change field types
- Change required-vs-optional status of existing fields

Schema unfreeze after Iter 68 analysis: Iter 68 may recommend schema v2 for future iters. v1 (this doc) preserved as canonical for the soak window's data.

## Opt-out semantics

`--no-telemetry` flag suppresses ALL writes to telemetry.jsonl. Existing file preserved (read-side unaffected). Memory skill SHOULD honor this flag; skills MUST check before appending.

Opt-out is per-chain (the flag travels with the user's command invocation; not persistent). For persistent opt-out: user adds `defaults.telemetry: false` to `<project>/.mega-sdd/config.yaml` (Iter 64 adds this config key).
