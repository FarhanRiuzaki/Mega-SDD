# execute-bolts — Halt recovery: full halt YAMLs, propose-and-confirm, PBT violation flow

Cold companion to `halts-and-handoff.md` (which keeps the always-hot halt protocol, the canonical bolt-halt enum, streaming/summary formats, and the handoff schema). Load this file ONLY when a halt actually fires (or is about to be emitted) or when a batched unit carries a non-empty `properties:` field (Property-Based Testing) — per the SKILL.md routing.

## Contents
- `test_fail` halt YAML
- Propose-and-confirm halt UX
- Property-Based Testing validation

## `test_fail` halt YAML

When retries exhaust for a unit's acceptance test, emit the structured halt (per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`):

```yaml
blocker:
  type: test_fail
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    retries_attempted: <N, default 3>
    test_command: <exact command run>
    last_failure_output: |
      <verbatim output of last failing test invocation>
    files_touched:
      - <list of files touched during the attempts>
  next_action: "Review bolt-report.md; edit the unit acceptance criteria or fix the code, then re-run"
```

## Propose-and-confirm halt UX

Per the propose-and-confirm-prompt template (listed in SKILL.md). When a bolt halts with an eligible halt type, dispatch an AI fix-proposer subagent → render the proposal via `AskUserQuestion` → on accept, apply the fix + re-execute → on reject, the chain pauses.

**Eligible halt types** (default propose-and-confirm; configurable per `~/.mega-sdd/config.yaml` `halt_auto_propose` (user-scope)):
- `test_fail` (after the default 3 retries via `--max-retries`).
- `hard_rule_violated` (with framework-pack provenance evidence).
- `pbt_property_violated` (counterexample preserved in postflight).

**NOT eligible** (always pure pause):
- `oq_business_p1_unresolved` — human business decision required.
- `dedup_ambiguous` — human judgment required.
- `quality_gate_failed` — broader investigation needed.
- `constitution_drift_detected` — audit-significant.
- `bolt_repeated_partial_failure` — structural problem; a fix won't help.
- `provenance_missing` — user must add the trailer.
- `dep_missing` — environment setup needed (the legacy alias `missing_dependency` is retired).
- `hard_rule_unparseable` — config issue.
- `hard_rule_unanchored` — config issue.
- `ambiguous_spec` — human interpretation call (the implementing session will not guess; pure-pause).
- `verify_unit_writable` — config issue.

**Dispatch contract:**
1. Bolt halt → check halt-type eligibility + user config override.
2. If eligible: dispatch the fix-proposer subagent with the propose-and-confirm-prompt template (listed in SKILL.md).
3. The subagent returns a `proposed_fix` YAML (root_cause + evidence_chain + fix diff + confidence + optional alternatives).
4. Render to the user via `AskUserQuestion` (4 options — the platform caps options at 4: Apply / Alt / Reject / Override; Cancel rides the built-in "Other"/Esc escape).
5. On Apply: write `proposed_fix` to `<vault>/bolts/U-XXX/proposed-fix.md` → apply diff → re-execute the single bolt → continue the batch.
6. On Reject: write `proposed_fix` to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for the next session) → the chain pauses.
7. On Override: the `forced_pass` status lands in the bolt-report (the audit record) → continue the batch.

**Halt-cycle safety:** if the same halt fires twice on the same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop).

**Configuration override** (`~/.mega-sdd/config.yaml`):

```yaml
halt_auto_propose:
  test_fail: propose          # default
  hard_rule_violated: propose
  pbt_property_violated: propose
  oq_business_p1_unresolved: pause   # always
  dedup_ambiguous: pause             # always
  # ... rest pause by default
```

## Property-Based Testing validation

Per `plan/references/pbt-integration.md`. When a unit has a non-empty `properties:` field:

**Pre-flight (during the Hard Rule snapshot step):** for each `properties[].cites` reference, validate the citation resolves — probe that the vault section / entity / constitution clause exists. Unresolved → halt `pbt_citation_invalid` (mirrors the `oq_recommend_citation_invalid` rail).

**Acceptance phase (within superpowers TDD):** if a PBT framework is detected (per `pbt-integration.md` §Framework detection):
1. `plan` (step 4) has already emitted PBT test stubs in the unit's `target_files` (e.g. `tests/Property/<Name>Test.<ext>`).
2. Run PBT tests as part of the acceptance phase via the detected framework:
   ```bash
   ./vendor/bin/phpunit --group=property      # PHP/Eris
   npm run test -- --testPathPattern=Property # TS/JS/fast-check
   pytest tests/property/ -p hypothesis        # Python/Hypothesis
   go test ./... -run TestProperty              # Go/gopter
   cargo test property -- --include-ignored    # Rust/proptest
   ```
3. Parse the exit code + counterexample output.

**Post-flight halt logic** — per property tested:

| Outcome | severity=error | severity=warning |
|---|---|---|
| Property holds | ✓ PASS | ✓ PASS |
| Property violated (counterexample found) | HALT `pbt_property_violated` | Log to bolt-report.md as a warning; the bolt proceeds to commit |

```yaml
blocker:
  type: pbt_property_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    violated_property: PROP-002
    property_description: "nama is case-insensitive"
    counterexample:
      nip: 12345
      nama: "Müller"
      password: "secret"
    expected: case-insensitive match
    actual: response codes differ for 'müller' vs 'Müller'
    cites: flows.md#F-U-001-login
  next_action: "Property violated. Either fix code to satisfy the property OR adjust the property statement OR add explicit edge-case handling. See <vault>/bolts/<unit>/bolt-report.md PBT section for the full counterexample."
```

**Framework absent fallback:** if `properties:` is non-empty but no PBT framework is detected (e.g. a bare PHP project without Eris) → skip test emission + validation; log an advisory note in bolt-report.md ("PBT framework not detected; properties documented as advisory only"); the bolt proceeds per `acceptance_test`.

**`--no-pbt` opt-out:** skips PBT validation entirely (example-test-only behaviour). Useful when CI lacks a PBT framework, for a one-off bolt run, or when the user explicitly wants example-test-only validation.
