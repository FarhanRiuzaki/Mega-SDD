# Handoff Consumption — Orchestrator-Side Validation Gate

`orchestrate-flow` is the **consumer** of the handoff YAML protocol. Sub-skills (producers) emit a `handoff:` block as the last assistant message before exiting; the orchestrator parses it to decide auto-continue / pause / stop. The producer schema, field TYPE annotations, and per-skill expected emissions live in the handoff-contract reference (indexed in SKILL.md §Specialist references) — this file specifies how the orchestrator **validates** what it receives.

This gate runs per sub-skill in the chain loop, between dispatch and propagation. All checks below assume `--auto` is in effect (standalone invocations emit the YAML but no orchestrator consumes it).

## Contents

- [Validation gate ordering](#validation-gate-ordering)
- [b.script — Deterministic per-hop gate (one call)](#bscript--deterministic-per-hop-gate-one-call)
- [b.iv — Conditional fields (prose)](#biv--conditional-fields-prose)
- [b.ix — Cross-metric consistency check](#bix--cross-metric-consistency-check)
- [Propagation](#propagation)
- [Orchestrator consumption loop](#orchestrator-consumption-loop)

## Validation gate ordering

Per sub-skill, after it exits. Any failure emits the named halt and STOPS the chain.

1. **b.script** — ONE deterministic validator call (replaces the prose-executed b.0 presence / b.i type-check / b.ii–b.iii parse+required / b.vii artifact checks — M-04)
2. **b.iv** CONDITIONAL fields present when condition met → `invalid_handoff` (prose — needs chain-start runtime state the script does not have)
3. **b.ix** Cross-metric consistency → `quality_gate_failed` (prose — needs upstream cached state)
4. Pass → propagate (step c); the confidence floor stays in the consumption loop below

## b.script — Deterministic per-hop gate (one call)

Save the sub-skill's chat output (the last assistant message) to a temp file, then run:

```bash
# Resolve $PLUGIN_ROOT to the LATEST cached version (defeats stale-version anchoring;
# see plugins/mega-sdd/references/plugin-root-resolution.md). DERIVED = this reference
# file's own absolute path truncated before /skills/.
DERIVED="<this reference file's absolute path, truncated before /skills/>"
RESOLVER="$(ls -1 ~/.claude/plugins/cache/mega-sdd/mega-sdd/*/scripts/resolve-plugin-root.sh 2>/dev/null | tail -1)"
PLUGIN_ROOT="$([ -n "$RESOLVER" ] && bash "$RESOLVER" "$DERIVED" || echo "$DERIVED")"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$DERIVED"
bash "$PLUGIN_ROOT/scripts/validate-handoff-yaml.sh" \
  --cwd="$PROJECT_ROOT" --response-file="$TMP" --skill-name="<sub-skill>" --quiet
```

- **exit 0** → all deterministic checks pass; proceed to b.iv. Print nothing.
- **exit non-zero** → read `.mega-sdd/.handoff-validation-state.json` (ONLY on failure) and surface its halt envelope **verbatim**; STOP chain. The state file carries `halt_type` ∈ `handoff_missing` (no `handoff:` block, OR multiple blocks with CONFLICTING `emitted_by` — same-emitter duplicates validate the producer's LAST block; includes a 300-char response tail) / `invalid_handoff` (YAML parse failure, REQUIRED field missing, or `status: halted` with an empty/absent blockers envelope) / `handoff_type_mismatch` (a present field fails its TYPE annotation, incl. the conditional-object shapes and the `next_action.confidence` `[0,1]` range) / `artifact_missing` (a listed `artifacts:` path does not exist) / `bolt_artifacts_missing` / `scope_args_missing` (the L9 seam), plus `retry_count` + the C1→C2 escalation fields.

**The orchestrator does NOT load the handoff-contract reference to validate** (M-04 — the per-field "lookup TYPE annotation in handoff-contract §<field>" prose forced a full contract load on every hop). The TYPE annotations there are the AUTHORING source the script encodes; the script is the runtime check. Producer self-fix stays as before: the PreToolUse handoff gate auto-allows re-invoking the producer named in the FAIL state.

> Retired with the prose type-check: the `--legacy-type-bypass` migration flag (its home was the prose loop). The script's annotation-absent behavior is warn-only for unknown fields — a present field with a KNOWN annotation is still hard-checked; unknown extra fields never fail the handoff.

## b.iv — Conditional fields (prose)

For each field declared `(CONDITIONAL — <condition>)` in the handoff-contract schema:
- Evaluate the condition against the orchestrator's known runtime state at chain-start (e.g., "if vault has scope_metadata" → check vault.json `scope_metadata` key read during chain-start CWD inspection).
- Condition met AND field absent → emit halt `invalid_handoff` with details `{failing_skill, missing_field, severity: CONDITIONAL, condition_evaluated: <result>}`; STOP chain.
- Condition not met → absence OK. (Type-of-present-conditional-fields is already covered by b.script.)

## b.ix — Cross-metric consistency check

For specific producers, validate that their emitted metrics are consistent with upstream cached state:

- **IF sub-skill == `generate-units`** AND handoff `metrics.units_with_starterkit_rules > 0`:
  - Read `<project>/.mega-sdd/codebase/starterkit-context.yaml` → `starterkit_context.partial` flag (written by scan-codebase per `plugins/mega-sdd/references/starterkit-context-schema.md`).
  - IF `starterkit_context.partial == true` AND `units_with_starterkit_rules > 0` → emit halt `quality_gate_failed` with details `{subtype: starterkit_metrics_inconsistent, failing_skill: generate-units, units_with_starterkit_rules: <N>, starterkit_partial: true, evidence: "generate-units pulled Hard Rules from a partial starterkit slice — rules may reference incomplete framework conventions"}`; STOP chain.
  - IF consistent (partial=false OR rules=0) → log telemetry line `"✓ starterkit metrics consistent: rules=<N>, partial=false"` + continue.
- Extensible: future producers MAY add their own consistency rules here following the same `IF sub-skill == <name>` gating pattern.

## Propagation

After all checks pass, propagate handoff metadata to the next skill in the chain: pass canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) without modification. The memory POINTER slice for the next skill is built from the updated state (pointers only — row text never re-transits; see `memory-layer.md §Per-phase invocation`).

## Orchestrator consumption loop

```
loop:
  invoke current skill with --auto
  parse handoff YAML from skill output
  if handoff.status == completed:
    log: "✓ Phase {N} of {M} completed: {skill}"
    if --deep AND current phase != the `--to=` bound (the front door renders --step-after/--stop-after INTO --to before dispatch — this loop never sees those names):
      # Confidence-aware auto-continue: next_action.confidence is a TYPED field
      # (handoff-contract §next_action.confidence) — consume it, don't just type-check it.
      if handoff.next_action.confidence is present AND < confidence_minimum (config, default 0.80):
        log: "⏸ {skill} recommends {next} with confidence {c} (< {floor}) — confirm before continuing"
        ask user (continue / reroute / stop)   # demote auto-continue to user review; absent confidence → auto-continue unchanged
      current = handoff.next_action.suggested_skill
      args = handoff.next_action.suggested_args
      continue loop
    else:
      exit loop with summary
  if handoff.status == paused:
    log: "⏸ Phase {N} paused: {skill}. Items needing review: {items_blocked}"
    surface paused-item summary in chat
    exit loop awaiting user review
  if handoff.status == halted:
    log: "⛔ Phase {N} halted: {skill}. Blockers: {blockers list}"
    surface verbatim blocker YAMLs in chat
    exit loop awaiting user resolution

emit final summary:
  - Phases completed / paused / halted (lists)
  - Artifacts produced: {flat list of all artifact paths}
```

Anti-halu invariants (consumer side):
- Orchestrator MUST surface blocker YAMLs verbatim. No paraphrasing.
- Orchestrator MUST NOT invoke `next_action.suggested_skill` if status is `paused` or `halted`. Chain pauses; user resumes manually.
- Skills WITHOUT handoff emission (pre-v2.0) → treat completion as `status: completed` with `next_action: null`; chain stops after that skill (acceptable degraded behavior).

## See also

- The handoff-contract reference (indexed in SKILL.md §Specialist references) — producer schema, field TYPE annotations, per-skill expected emissions, memory layer integration.
- `plugins/mega-sdd/references/halt-protocol.md §halt-protocol` — canonical blocker envelope.
