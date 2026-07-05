# Handoff Consumption — Orchestrator-Side Validation Gate

`orchestrate-flow` is the **consumer** of the handoff YAML protocol. Sub-skills (producers) emit a `handoff:` block as the last assistant message before exiting; the orchestrator parses it to decide auto-continue / pause / stop. The producer schema, field TYPE annotations, and per-skill expected emissions live in the handoff-contract reference (indexed in SKILL.md §Specialist references) — this file specifies how the orchestrator **validates** what it receives.

This gate runs per sub-skill in the chain loop, between dispatch and propagation. All checks below assume `--auto` is in effect (standalone invocations emit the YAML but no orchestrator consumes it).

## Contents

- [Validation gate ordering](#validation-gate-ordering)
- [b.0 — Handoff presence check](#b0--handoff-presence-check)
- [b.i — Type-check fields](#bi--type-check-fields)
- [b.ii to b.vi — Schema validation](#bii-to-bvi--schema-validation)
- [b.vii — Artifact existence check](#bvii--artifact-existence-check)
- [b.ix — Cross-metric consistency check](#bix--cross-metric-consistency-check)
- [Propagation](#propagation)
- [Orchestrator consumption loop](#orchestrator-consumption-loop)

## Validation gate ordering

Per sub-skill, after it exits, run in this order. Any failure emits the named halt and STOPS the chain.

1. **b.0** Handoff presence → `handoff_missing`
2. **b.i** Field type-check → `handoff_type_mismatch`
3. **b.ii** YAML parse → `invalid_handoff`
4. **b.iii** REQUIRED fields present → `invalid_handoff`
5. **b.iv** CONDITIONAL fields present when condition met → `invalid_handoff`
6. **b.v** OPTIONAL fields → log only
7. **b.vii** Artifact existence → `artifact_missing`
8. **b.ix** Cross-metric consistency → `quality_gate_failed`
9. Pass → propagate (step c)

## b.0 — Handoff presence check

After the sub-skill exits, scan the **sub-skill's chat output** (the last assistant message) for a YAML code fence containing a top-level `handoff:` key per the handoff-contract reference `§Handoff YAML schema`. Skills emit the handoff inline in chat (NOT to a file on disk).

- If no `handoff:` block can be located, OR multiple `handoff:` blocks exist with conflicting `emitted_by:` values → emit halt `handoff_missing` with details `{failing_skill, last_known_step: <best-effort from any checkpoint trail or "unknown">, chat_tail_excerpt: <last 500 chars of sub-skill chat for diagnostics>}`; STOP chain. Halts at the failing boundary with chat-tail excerpt for diagnosis.

```yaml
# Example handoff_missing envelope:
type: handoff_missing
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  last_known_step: "Step 7 (binding entries written)"
  chat_tail_excerpt: "...write to file failed: ENOSPC: no space left on device\nProcess exited with code 1"
next_action: "Sub-skill `bind-codebase` exited without emitting handoff YAML in its chat output. chat_tail_excerpt above shows the last 500 chars of the sub-skill's output — look for crash logs / parse errors / OS-level failures (disk full, permissions, OOM). Re-run `/mega-sdd:bind-codebase` standalone to reproduce."
```

## b.i — Type-check fields

Type-check fields against handoff-contract.md TYPE annotations. For each field present in handoff YAML:

- Lookup TYPE annotation in handoff-contract.md §<field-name> section.
- **TYPE annotation absent behavior (strict default):**
  - **Default (strict):** emit halt `handoff_type_mismatch` with details `{failing_skill, field_name, missing_annotation: true, recommended_fix: "Add TYPE annotation to handoff-contract.md §<skill> §<field> per existing peer fields"}`; STOP chain. Halt-against-author forces skill authors to declare TYPE before the field can be emitted in production handoff.
  - **Legacy bypass:** `--legacy-type-bypass` flag logs warn-only ("field <name> has no TYPE in schema; skipping type check") + continues. Available for migration scenarios only: users with older plugins set the flag for one chain run, fix author-side TYPE annotations, then remove the flag.
- If TYPE annotation present → validate value matches TYPE:
  - `string` → value is string (not int/array/object)
  - `int` → value is integer; respect `(≥N)` constraint if present
  - `enum (a | b | c)` → value is in allowed list
  - `array<T>` → value is array AND each element matches T
  - `object {...}` → value is object AND each declared sub-field matches its TYPE
  - `string (sha256 hex)` → value is 64-char hex string
  - `string (ISO8601)` → value matches ISO8601 pattern
  - `bool` → value is true | false
  - `<T> | null` → value is T OR null (nullable variant)
- On type mismatch → emit halt `handoff_type_mismatch` with details `{failing_skill, field_name, expected_type, actual_type, actual_value (truncated to 100 chars)}`; STOP chain.

```yaml
# Example handoff_type_mismatch envelope:
type: handoff_type_mismatch
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  field_name: "scope.id"
  expected_type: "string (enum from vault.json scope_metadata.allowed_scopes)"
  actual_type: "object"
  actual_value: "{ id: 'BE', name: 'Backend' }"
next_action: "Field scope.id should be a string (enum value), not an object. Edit bind-codebase handoff template to emit scope.id as 'BE' string directly. Likely cause: handoff template emitted the entire scope object as scope.id by mistake. (Possible upstream: vault.json shape changed; verify scope_metadata schema.)"
```

## b.ii to b.vi — Schema validation

ii. Parse handoff YAML; if YAML parse fails → emit halt `invalid_handoff` with details `{failing_skill, parse_error}`; STOP chain.

iii. For each field declared `(REQUIRED)` in handoff-contract.md schema:
   - If field absent in handoff YAML → emit halt `invalid_handoff` with details `{failing_skill, missing_field, severity: REQUIRED}`; STOP chain.

iv. For each field declared `(CONDITIONAL — <condition>)`:
   - Evaluate condition against orchestrator's known runtime state at chain-start (e.g., "if vault has scope_metadata" → check vault.json `scope_metadata` key read during chain-start CWD inspection).
   - If condition met AND field absent → emit halt `invalid_handoff` with details `{failing_skill, missing_field, severity: CONDITIONAL, condition_evaluated: <result>}`; STOP chain.
   - If condition NOT met → field absence OK; continue.

v. For each field declared `(OPTIONAL)`:
   - Field absence OK; log presence/absence for telemetry only.

vi. If all schema validation passes → proceed to artifact existence check.

```yaml
# Example invalid_handoff envelope (REQUIRED field missing):
type: invalid_handoff
source_skill: orchestrate-flow
details:
  failing_skill: bind-codebase
  missing_field: "scope.id"
  field_severity: CONDITIONAL
  condition_evaluated: "vault has scope_metadata = TRUE"
  handoff_file: "<vault>/.internal/checkpoints/2026-05-24-bind-codebase.handoff.yaml"
next_action: "Edit plugins/mega-sdd/skills/bind-codebase/SKILL.md §Handoff emission YAML template to include scope: block per handoff-contract.md schema. After fix, re-run chain. (Phase A1 audit closure should have prevented this — verify your skill body is up to date.)"
```

## b.vii — Artifact existence check

Iterate the `artifacts: [paths]` array from the validated handoff. For each path:
- If absolute file path: verify `test -f <path>` returns 0.
- If absolute directory path: verify `test -d <path>` returns 0.
- If relative path: log warn-only ("artifact path is relative; cannot existence-check") + continue.

If ANY listed artifact fails the existence check → emit halt `artifact_missing` with details `{failing_skill, missing_paths: array, present_paths: array, handoff_file: <path>}`; STOP chain. Halts at the producer boundary with explicit list of missing paths.

```yaml
# Example artifact_missing envelope:
type: artifact_missing
source_skill: orchestrate-flow
details:
  failing_skill: generate-units
  missing_paths: ["<vault>/units/U-007.md", "<vault>/units/U-008.md"]
  present_paths: ["<vault>/units/U-001.md", "<vault>/units/U-002.md", "<vault>/units/U-006.md"]
  handoff_file: "<vault>/.internal/checkpoints/2026-05-25-generate-units.handoff.yaml"
next_action: "Producer skill `generate-units` declared 8 unit files in handoff but only wrote 6. Re-run `/mega-sdd:generate-units` standalone to reproduce. Likely cause: skill crashed mid-loop after emitting handoff metadata for all units but only writing some. Inspect chat output."
```

## b.ix — Cross-metric consistency check

For specific producers, validate that their emitted metrics are consistent with upstream cached state:

- **IF sub-skill == `generate-units`** AND handoff `metrics.units_with_starterkit_rules > 0`:
  - Read `<project>/.mega-sdd/codebase/starterkit-context.yaml` → `starterkit_context.partial` flag (written by scan-codebase per `plugins/mega-sdd/references/starterkit-context-schema.md`).
  - IF `starterkit_context.partial == true` AND `units_with_starterkit_rules > 0` → emit halt `quality_gate_failed` with details `{subtype: starterkit_metrics_inconsistent, failing_skill: generate-units, units_with_starterkit_rules: <N>, starterkit_partial: true, evidence: "generate-units pulled Hard Rules from a partial starterkit slice — rules may reference incomplete framework conventions"}`; STOP chain.
  - IF consistent (partial=false OR rules=0) → log telemetry line `"✓ starterkit metrics consistent: rules=<N>, partial=false"` + continue.
- Extensible: future producers MAY add their own consistency rules here following the same `IF sub-skill == <name>` gating pattern.

## Propagation

After all checks pass, propagate handoff metadata to the next skill in the chain: pass canonical top-level fields (scope, constitution, mutability, pbt, cycles, replay, starterkit_context) without modification. The memory slice for the next skill is built from the updated state.

## Orchestrator consumption loop

```
loop:
  invoke current skill with --auto
  parse handoff YAML from skill output
  if handoff.status == completed:
    log: "✓ Phase {N} of {M} completed: {skill}"
    if --deep AND no --stop-after match:
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
