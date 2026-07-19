# execute-bolts — Halt recovery: full halt YAMLs, propose-and-confirm, PBT violation flow

Cold companion to `halts-and-handoff.md` (which keeps the always-hot halt protocol, the canonical bolt-halt enum, streaming/summary formats, the handoff schema, and the memory layer). Load this file ONLY when a halt actually fires (or is about to be emitted) or when a batched unit carries a non-empty `properties:` field (Property-Based Testing) — per the SKILL.md routing.

## Contents
- `test_fail` halt YAML
- `review_critical_unresolved` halt YAML
- Propose-and-confirm halt UX
- New halt types table
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
  next_action: "Review bolt-report.md; edit unit acceptance criteria, fix code manually, or skip via --force"
```

## `review_critical_unresolved` halt YAML

When the review panel's retry budget exhausts with a **Critical** finding still open OR the spec lens still ❌ (per `review-panel.md §Merge + severity gate` — a missing/misread requirement carries no severity grade, so spec ❌ is its own terminal condition), emit the terminal halt — the run STOPS; never proceed to the next bolt over an open Critical or an unmet requirement:

```yaml
blocker:
  type: review_critical_unresolved
  emitted_at: <ISO8601 timestamp>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    retries_attempted: <N>
    tier: <minimal|standard|full>
    open_criticals:
      - lens: <spec|quality|security|standards|design>
        finding: <one-line>   # a still-❌ spec lens rides this list as lens: spec —
        anchor: <file:line>   # the unmet requirement IS the open finding
  next_action: "Review the open finding(s) in bolt-report.md ## Review panel — open Critical(s) and/or the spec lens's unmet requirement; fix the committed code (or revert the bolt commit) and re-run the unit. The finding survived the shared --max-retries budget — do not raise the cap to outlast it."
```

## Propose-and-confirm halt UX

Per the propose-and-confirm-prompt template (listed in SKILL.md). When a bolt halts with an eligible halt type, dispatch an AI fix-proposer subagent → render the proposal via `AskUserQuestion` → on accept, apply the fix + re-execute → on reject, the chain pauses.

**Eligible halt types** (default propose-and-confirm; configurable per `~/.mega-sdd/memory/config.yaml` `halt_auto_propose`):
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
- `dispatch_prompt_too_large` — config issue, not bolt-fixable.
- `dep_missing` — environment setup needed. (The agent-carried halt vocabulary — `agents/bolt-implementer.md` §Halt vocabulary — emits this same type; the legacy alias `missing_dependency` is retired.)
- `hard_rule_unparseable` — config issue.
- `hard_rule_unanchored` — config issue.
- `ambiguous_spec` — human interpretation call (subagent-emitted; pure-pause).
- `scope_creep_detected` — the unit's scope is wrong or the plan drifted; human restructures.
- `review_critical_unresolved` — a Critical (or a still-❌ spec lens) survived the retry budget; human reviews the code.
- `bolt_introduces_locked_drift` — LOCKED behavior is a human decision by definition; override-only (the fix-proposer template refuses LOCKED files).
- `verify_unit_writable` — config issue.

**Dispatch contract:**
1. Bolt halt → check halt-type eligibility + user config override.
2. If eligible: dispatch the fix-proposer subagent with the propose-and-confirm-prompt template (listed in SKILL.md).
3. The subagent returns a `proposed_fix` YAML (root_cause + evidence_chain + fix diff + confidence + optional alternatives).
4. Render to the user via `AskUserQuestion` (4 options — the platform caps options at 4: Apply / Alt / Reject / Override; Cancel rides the built-in "Other"/Esc escape).
5. On Apply: write `proposed_fix` to `<vault>/bolts/U-XXX/proposed-fix.md` → apply diff → re-execute the single bolt → continue the batch.
6. On Reject: write `proposed_fix` to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for the next session) → the chain pauses.
7. On Override: record to memory `decisions.md` as `forced_pass` → continue the batch (audit-significant).

**Halt-cycle safety:** if the same halt fires twice on the same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop).

**Configuration override** (`~/.mega-sdd/memory/config.yaml`):

```yaml
halt_auto_propose:
  test_fail: propose          # default
  hard_rule_violated: propose
  pbt_property_violated: propose
  oq_business_p1_unresolved: pause   # always
  dedup_ambiguous: pause             # always
  # ... rest pause by default
```

## New halt types table

Beyond the existing halts, this skill adds:

| Halt type | Fires when | Eligible for propose? |
|---|---|---|
| `dispatch_prompt_too_large` | Step 4.5 tiered prompt exceeds the hard cap | NO (config/spec issue) |
| `bolt_repeated_partial_failure` | 3+ partial-state attempts on the same bolt OR propose-and-confirm cycled with different fixes | NO (structural) |
| `provenance_missing` | Post-flight detects a missing provenance trailer in a modified file | NO (user adds the trailer) |
| `bolt_introduces_locked_drift` | The per-bolt drift check detects drift on a LOCKED entity | NO (override-only — LOCKED behavior is a human decision; the fix-proposer template refuses LOCKED files) |
| `self_assessment_missing` | `bolt-report.md` lacks the `bolt_self_report` YAML block | NO (bolt must self-report) |
| `commit_rejected_by_hook` | The repo's own commit hook (pre-commit/husky/lefthook) or required GPG signing rejected the bolt's commit. Hook output verbatim in details. NEVER retried with `--no-verify` (forbidden plugin-wide). | NO (user fixes the hook finding or environment) |
| `bolt_artifacts_missing` | An `emitted_by: execute-bolts` `status: completed` handoff that executed units (`metrics.items_processed > 0`) lists no `<vault>/bolts/U-XXX/` artifact — the bolt folder was never generated. Detected by the Stop-hook handoff validator (`validate-handoff-yaml.sh`); exempts dry-run/no-op (`items_processed == 0`). | NO (controller must create the dir at Procedure Step 0 + write `bolt-report.md`, then re-emit) |

Halt YAML envelopes for each are documented in the propose-and-confirm-prompt template (listed in SKILL.md).

## Property-Based Testing validation

Per `generate-units/references/pbt-integration.md`. When a unit has a non-empty `properties:` field:

**Pre-flight (during the Hard Rule snapshot step):** for each `properties[].cites` reference, validate the citation resolves — probe that the vault section / entity / constitution clause exists. Unresolved → halt `pbt_citation_invalid` (mirrors the `oq_recommend_citation_invalid` rail).

**Acceptance phase (within superpowers TDD):** if a PBT framework is detected (per `pbt-integration.md` §Framework detection):
1. Generate-units has already emitted PBT test stubs in the unit's `target_files` (e.g. `tests/Property/<Name>Test.<ext>`).
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
    cites: 04-flows.md#F-U-001-login
  next_action: "Property violated. Either fix code to satisfy the property OR adjust the property statement OR add explicit edge-case handling. See <vault>/bolts/<unit>/bolt-report.md PBT section for the full counterexample."
```

**Framework absent fallback:** if `properties:` is non-empty but no PBT framework is detected (e.g. a bare PHP project without Eris) → skip test emission + validation; log an advisory note in bolt-report.md ("PBT framework not detected; properties documented as advisory only"); the bolt proceeds per `acceptance_test`.

**`--no-pbt` opt-out:** skips PBT validation entirely (preserves pre-v2.4 behaviour). Useful when CI lacks a PBT framework, for a one-off bolt run, or when the user explicitly wants example-test-only validation.
