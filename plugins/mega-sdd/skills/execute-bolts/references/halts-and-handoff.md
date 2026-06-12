# execute-bolts — Halts, propose-and-confirm, PBT, streaming, handoff + memory

Everything downstream of the per-unit gates: the halt protocol + YAMLs, propose-and-confirm UX, Property-Based Testing validation, compact streaming + the aggregate `_summary.md`, outputs detail, the handoff YAML + end-of-chain phasing, and the memory layer.

## Contents
- Halt protocol + `test_fail` YAML
- Propose-and-confirm halt UX
- New halt types table
- Property-Based Testing validation
- Self-assessment requirement
- Post-flight acceptance-test concern harvest
- Provenance trailer enforcement
- Compact streaming progress
- Aggregate `_summary.md`
- Outputs detail
- Hand-off + end-of-chain phasing
- Handoff emission (`--auto`)
- Memory layer

## Halt protocol + `test_fail` YAML

Per the bolt-contract failure modes (the bolt-contract ref listed in SKILL.md). Always emit a blocker YAML on halt:

```yaml
blocker:
  unit: U-XXX
  cause: <category>
  details: <verbatim error / test output>
  next_action: <retry | edit unit | manual fix>
```

When retries exhaust for a unit's acceptance test, emit the structured halt (per `vault-contract.md §halt-protocol`):

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
- `dep_missing` — environment setup needed.
- `hard_rule_unparseable` — config issue.
- `hard_rule_unanchored` — config issue.
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
| `bolt_introduces_locked_drift` | The per-bolt drift check detects drift on a LOCKED entity | YES (propose-and-confirm OR override) |
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

## Self-assessment requirement

Every `bolt-report.md` MUST include a `bolt_self_report` YAML block at the end:

```yaml
bolt_self_report:
  confidence: <0.0-1.0>   # bolt subagent's own confidence in this bolt's correctness
  certain_decisions:
    - "<decision with HIGH confidence + evidence>"
  uncertain_decisions:
    - decision: "<what bolt did>"
      rationale: "<why this path was taken>"
      fallback_if_wrong: "<safer alternative if this turns out wrong>"
  retry_history:
    - attempt: 1
      failure: "<verbatim failure if any>"
      fix: "<what was changed>"
```

If `bolt-report.md` lacks this block → halt `self_assessment_missing` (post-flight verification fails). The aggregate `_summary.md` rolls up `uncertain_decisions` across the batch for post-execution human review.

## Post-flight acceptance-test concern harvest

After `bolt-report.md` is written, scan the `bolt_self_report` block (and adjacent self-assessment text) for an `acceptance_test_concern: <non-empty string>` field (written by the bolt subagent per the dispatch-prompt template, listed in SKILL.md, when the implementation passes the acceptance test but feels under-validated):

1. Parse the bottom-of-file YAML blocks.
2. IF `acceptance_test_concern:` is present AND non-empty:
   - Append to the in-memory aggregate: `{unit_id, concern, source: <bolt-report.md path>}`.
   - Log a one-line chat warning: `"⚠ U-XXX flagged acceptance_test_concern: <truncated 100 chars>"`.
3. After all bolts complete (`--all`), assemble the aggregate into handoff `metrics.acceptance_test_concerns: [{unit, concern}]`.
4. Also surfaced via `_summary.md` (a new "## Acceptance-test concerns" sub-section).

No new halt type — concerns are warnings, not blockers. The re-validation path is `/mega-sdd:generate-units --regenerate --adversarial-subagent --units=<list>` to author stronger acceptance tests, then re-run the affected bolts. orchestrate-flow Step 7's final summary surfaces the count + unit list when non-empty.

## Provenance trailer enforcement

The post-flight scan also verifies every modified file has a provenance trailer comment:

```
Generated by mega-sdd execute-bolts <version>
Unit: U-XXX (vault sha256: <hash>)
Implements claim: C-NNN "<claim text>"
Anchors consulted: <list>
Hard Rules active: <list of rule IDs>
```

Language-appropriate comment style (e.g. `//` for JS/PHP/Java, `#` for Python/Ruby, `--` for SQL). Missing trailer → halt `provenance_missing`.

## Compact streaming progress

Per-bolt status emitted as a compact streaming format (chat-friendly, updated in place):

```
▶ Bolt 7/20: U-007 "Create User model" (scope: BE)
  └─ Context: 6 upstream loaded, 3 anti-patterns flagged, confidence HIGH
  └─ Pre-flight: Hard Rules ✓ | PBT ready ✓ | Anchors verified 3/3 ✓
  └─ Execution: TDD red ✓ → green ✓ (45s)
  └─ Post-flight: Hard Rules ✓ | PBT ✓ | Drift check: clean ✓
  └─ Commit: 8a3f2e1 "feat(U-007): create User model"
✓ Bolt 7/20: U-007 → done in 1m23s, 0 retries, confidence 0.92
```

After the batch (printed at the end of an `--all` run):

```
══════════════════════════════════════════════════════════
✓ execute-bolts batch complete: 18/20 done, 2 halted, 1 auto-resolved
══════════════════════════════════════════════════════════
  Scope: BE | Duration: 24m11s | Retries: 3 total | Avg confidence: 0.87
  Halts open: U-012 (test_fail awaiting user), U-015 (hard_rule_violated)
  See <vault>/bolts/_summary.md for the full table
  Next: detect-drift (auto-gate, hybrid mode — DEFAULT-ON)
```

## Aggregate `_summary.md`

Auto-generated AFTER every batch (overwrite-safe; idempotent regen) at `<vault>/bolts/_summary.md`:

```markdown
# Bolts Summary — <Project Name>
**Generated**: <ISO8601> (mega-sdd execute-bolts)
**Scope**: <scope_id> (<scope_name>)
**Batch**: <--all | --squad=X | --module=Y>
**Duration**: <duration>
**Avg AI confidence**: <0.0-1.0>

## Status table
| Unit | Title | Status | Duration | Retries | Confidence | Halt type | Commit |
|---|---|---|---|---|---|---|---|
| U-001 | <title> | ✓ done | 45s | 0 | 0.95 | — | <sha> |
| ... | ... | ... | ... | ... | ... | ... | ... |

## Halts open (N)
- U-XXX: <halt_type> after <retries> retries. <fix proposal status>. Resume: `/mega-sdd:auto --resume`.

## Hard rule violations across batch (by rule)
| Rule | Source | Violations | Resolution |
|---|---|---|---|

## Mutability tier coverage (when scope-tagged vault)
| Tier | Units touched | Status |
|---|---|---|

## Self-assessment summary (uncertain decisions across batch)
- U-XXX: "<decision>" — fallback: <safer alternative>

## Next steps
- Resolve <N> halts: `/mega-sdd:auto --resume`
- After all green: detect-drift will auto-run (hybrid gate; --no-drift-check opt-out)
```

Written immediately after the batch loop completes (whether all bolts succeeded, some halted, or the chain was cancelled). Overwrites any prior `_summary.md` (full regen each batch). The `--force-skip-postflight` anti-bypass policy surfaces here when used.

## Outputs detail

Per unit:
- Code commits (1+) on the current branch (skipped for `task_type: verify` if no changes).
- `<vault>/bolts/U-XXX/bolt-report.md` — frontmatter MUST include `target_hashes:` (living-vault staleness anchor; spec `2026-06-10-living-vault-continuous-sync-design.md` S6):
  ```yaml
  target_hashes:                       # sha256 of each target_files entry AT COMMIT TIME
    <repo-relative-path>: <sha256-hex> # computed by the controller AFTER the commit, from the committed content
  ```
  `scripts/compute-unit-staleness.sh` later compares these to the working tree — a mismatch marks the unit `stale` for the sync lane. Older bolt-reports without the field → staleness is `unknown` (treated as not-stale; never guessed).
- `<vault>/bolts/U-XXX/preflight.json` — Hard rule pre-flight snapshot for audit + diff.
- `<vault>/bolts/U-XXX/postflight.json` — Hard rule post-flight check results (per-rule pass/fail + evidence).

Global:
- Update `<vault>/vault.json` changelog: `{ "event": "bolt_completed", "unit": "U-XXX", "commits": [...] }`.

**Scope traceability:** when `vault.json` has a `scope` field, `bolt-report.md` MUST include scope in its header for multi-squad traceability (read vault.json once at skill start; propagate into the header — NO behavior change to bolt execution):

```yaml
---
unit: U-001
scope: <vault.scope_metadata.id>           # omit when the vault has no scope
scope_name: <vault.scope_metadata.name>
# ... existing fields
---
```

The handoff YAML may include a `scope:` block per `orchestrate-flow/references/handoff-contract.md` when the vault has scope.

## Hand-off + end-of-chain phasing

After the last unit: suggest `/mega-sdd:detect-drift` to verify all bolts honored the vault; show a summary (N units done, M failed, P skipped).

**End-of-chain phase context.** After the final bolt completes successfully (status==completed AND blockers==[]), inspect `vault.json` for `phase` + `phase_total`:

IF `vault.phase < vault.phase_total`:
```yaml
next_action:
  suggested_skill: mega-sdd:generate-intent
  suggested_args: ["--kb=<KB-path-from-vault.json.kb_source>", "--phase=<phase+1>"]
  rationale: "Phase <N> complete; continue to Phase <N+1>. Plan: .mega-sdd/knowledge-base/99-rebuild-architecture/suggested-phasing.md §Phase <N+1>."
```

IF `vault.phase == vault.phase_total` (final phase) OR `phase_total == 1`:
```yaml
next_action: "All phases complete (Phase <N> of <M>). Pipeline finished — no further skill to invoke."
```

IF `phase` is absent (older vault): default to `phase: 1, phase_total: 1` → chain-complete hint.

## Handoff emission (`--auto`)

When invoked with `--auto` (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit a handoff YAML at the end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: execute-bolts
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  notes:
    postflight_skipped: <true|false>     # true ONLY when --force-skip-postflight was used this run (anti-bypass audit trail)
  artifacts:                             # ONE LINE per bolt dir actually written; NO range shorthand of ANY kind; NO "(N units)" annotations
    - <absolute path to vault/bolts/U-001/>
    - <absolute path to vault/bolts/U-002/>
    # WRONG (range shorthand — DON'T): ellipsis "...", "through", "to", "thru", Unicode "…", or "(16 units)".
    # CORRECT: list EACH executed unit on its own line with an absolute path.
    # validate-handoff-yaml.sh os.path.exists() each entry.
  starterkit_context:                    # passthrough + metrics
    reused: false
    framework: laravel
    auth_lib: sanctum
    authz_lib: spatie/permission
    ui_stack: "alpine + tailwind + sweetalert2"
    libs_count: 47
    bolts_used_starterkit_slice: 11
    slice_avg_size_kb: 1.6
  next_action:
    suggested_skill: mega-sdd:detect-drift
    suggested_args: []                     # → ["--scope=<id>"] when the `scope:` block below is present (AUDIT L9): propagate THIS batch's scope so the chained detect-drift inherits it instead of full-scanning. Stays [] for a single-scope vault.
    rationale: "All bolts executed; recommend a periodic drift check."
  blockers: []   # populated on test_fail / hard_rule_violated / hard_rule_unparseable / hard_rule_unanchored / cross_squad_interface_draft / verify_unit_writable
  metrics:
    items_processed: <N units ACTUALLY executed/committed — MUST be 0 for a --dry-run/preview or an "all units already done" no-op re-run; never the would-process count. The bolt_artifacts_missing gate keys off this field.>
    items_blocked: <N halts encountered>
    bolts_used_starterkit_slice: <int>
    slice_avg_size_kb: <float>
    acceptance_test_concerns:            # harvested from bolt-report.md self-assessment per §Post-flight acceptance-test concern harvest
      - unit: U-007
        concern: "Test asserts user.id present but doesn't validate id is unique across concurrent requests; implementation may regress under load."
      # ... one entry per bolt that flagged a concern; empty array if none
  scope:                                 # when the vault has scope_metadata
    id: <scope id, e.g., "BE">
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256 from vault.json>
```

> **Scope propagation to detect-drift (AUDIT L9).** When this handoff carries a `scope:` block, `next_action.suggested_args` MUST include `--scope=<scope.id>` — `detect-drift` accepts `--scope`, and the orchestrator's consumption loop passes `suggested_args` straight through. Deterministically enforced: the Stop-hook handoff validator FAILs `scope_args_missing` when a scoped execute-bolts handoff routes to detect-drift without `--scope=` in `suggested_args`. Without it, a scope-filtered bolt batch hands off to a **full-scan** drift check (the seam asymmetry: detect-drift propagates scope to ITS downstream, but nothing seeded scope into detect-drift). For a single-scope vault there is no `scope:` block and `suggested_args` stays `[]`.

Status `halted` on `test_fail` / `hard_rule_violated` / `hard_rule_unparseable` / `hard_rule_unanchored` / `cross_squad_interface_draft` / `verify_unit_writable`. Required ONLY under `--auto`.

## Memory layer

When memory is enabled (default; opt-out via `--memory-off`), this skill participates in the mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

**Writes:**

| When | File | Content |
|---|---|---|
| After each bolt commits (success) | `<vault>/.memory/bolt-outcomes.json` | Append: unit_id, run_at, task_type, status=completed, duration_ms, tests_passed=true, hard_rules_validated=[rule strings that passed], concerns=[the bolt's `acceptance_test_concern` strings, if any — persisted here so cross-vault recurrence can reach a learning threshold instead of dying with the handoff] |
| After each bolt halts (failure) OR retries | `<vault>/.memory/bolt-outcomes.json` | Append: unit_id, status=halted_*, halt_reason, violated_rules=[with evidence], resolution=pending, **failure_reflection** — ONE line of root-cause from the fix-proposer (the *why*, e.g. "Hard Rule predates the binding's extend verdict — unit was mis-typed create"), not just the resolution enum |
| After a user resolves a halt (next session) | `<vault>/.memory/bolt-outcomes.json` | Update the prior entry: resolution=(user_reverted_code \| user_edited_unit \| user_force_committed \| user_skipped), resolution_at, resolution_note |
| After a chain run completes | `<project>/.mega-sdd/memory/outcomes.md` | Append a run summary: phases run, halts encountered, total duration, hard rule violation count |

**Reads:**

| What | Source | How used |
|---|---|---|
| Past bolt outcomes for the same unit | `<vault>/.memory/bolt-outcomes.json` | Before executing U-X: if a past run halted with violation Y → surface to the user pre-execution: "U-X previously halted on rule Y. Same risk now. Continue?" (informational; not blocking) |
| Past failure reflections (Reflexion) | `<vault>/.memory/bolt-outcomes.json` `bolts[].failure_reflection` | Before executing U-X: surface the reflections of (a) U-X's own past attempts and (b) sibling units in the same module, as a `## Prior failure context` block in the bolt dispatch prompt — retry N+1 and neighboring bolts start with the *why*, not just the *what* |
| Past Hard Rule violation+revert patterns | `<vault>/.memory/bolt-outcomes.json` | Pre-flight: if rule R has been violated AND reverted ≥3 times → emit a one-line chat warning before scanning: "Rule R has been overridden 3+ times. Validation will still fire; consider removing the rule from the unit" |

**Anti-halu rails:**
- Memory consultation NEVER bypasses pre/post-flight Hard Rule validation.
- Past-halt warnings are INFORMATIONAL only; the user decides to proceed.
- The `bolt_outcomes.json` write happens AFTER commit (or after halt) — memory is derivative of `bolt-report.md` (the source-of-truth artifact).
- `--memory-off` disables both reads and writes.
