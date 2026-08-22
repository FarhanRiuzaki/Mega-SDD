# Propose-and-Confirm Prompt Template

Canonical prompt for AI fix proposer subagent dispatched when bolt halts with eligible halt type. User reviews proposed fix + approves/rejects via AskUserQuestion.

**Eligible halt types** (per spec §6.3):
- `test_fail` (after default 3 retries)
- `hard_rule_violated` (with framework pack provenance evidence)
- `pbt_property_violated` (counterexample preserved)

**NOT eligible** (always pure pause; never propose fix):
- `oq_business_p1_unresolved` (needs human business decision)
- `dedup_ambiguous` (needs human judgment)
- `quality_gate_failed` (broader investigation needed)
- `constitution_drift_detected` (audit-significant)
- `bolt_repeated_partial_failure` (structural problem)
- `provenance_missing` (post-flight detected; user must add trailer)

## Contents

- Subagent dispatch contract
- Prompt template
- Main thread post-processing
- Confidence-driven defaults
- Halt cycle safety
- Anti-halu rails
- Performance
- Backward compatibility

## Subagent dispatch contract

execute-bolts post-flight detects halt → if halt type eligible → dispatch fix-proposer subagent with this template → render result via AskUserQuestion → on user-accept apply fix + re-execute bolt → on user-reject continue chain pause.

## Prompt template

```
ROLE: AI fix proposer for mega-sdd bolt halt.

CONTEXT:
- Bolt halt type: <halt_type>
- Unit: <unit_id> "<title>"
- Scope: <scope_id>
- Halt details (verbatim from halt YAML):
  <verbatim halt YAML block>

EVIDENCE FILES (read these via Read tool):
- Unit body: <vault>/units/U-XXX.md
- Bolt report: <vault>/bolts/U-XXX/bolt-report.md (includes bolt's self-assessment + retry history)
- Preflight snapshot: <vault>/bolts/U-XXX/preflight.json
- Postflight snapshot: <vault>/bolts/U-XXX/postflight.json (if any)
- Halt-type-specific evidence:
  - test_fail: failing test file from halt details
  - hard_rule_violated: violating file (from halt details) + framework pack rule definition
  - pbt_property_violated: counterexample input + failing property definition

TASK:

1. Read evidence files in order: bolt-report.md first (bolt's own assessment), then halt-type-specific evidence
2. Identify root cause:
   - For test_fail: parse failure output; cross-reference with bolt's uncertain_decisions to see if bolt flagged uncertainty in this area
   - For hard_rule_violated: locate violation file:line; understand rule intent from pack/constitution
   - For pbt_property_violated: analyze counterexample; identify code path that violates invariant
3. Propose SPECIFIC fix:
   - Identify minimal code change (single function, single validation rule, single config tweak — NOT broad refactor)
   - Cite exact file:line where fix should apply
   - Show diff-like before/after for the change
   - Cite EVIDENCE chain (e.g., "bolt's uncertain_decisions[0] already flagged validation area; test asserts 200 status (line 47); RefundRequest.php lacks rule for refund_amount cap")
4. Estimate confidence (0.0-1.0) that this fix will resolve the halt
5. Optionally propose 1-2 ALTERNATIVE fixes (if multiple valid approaches exist)

DISCIPLINE (non-negotiable):
- NEVER propose a fix without evidence chain (cite specific anchors in evidence files)
- NEVER propose changes outside the failing bolt's target_files (would be scope creep — surface as halt_escalation instead)
- NEVER propose changes to LOCKED files (per vault data-mutation-policy.md)
- If you cannot determine root cause from evidence → return overall_confidence: LOW + describe what additional context you'd need
- If halt type ineligible (somehow dispatched anyway) → return refusal with reason

OUTPUT FORMAT (exact YAML structure, no prose preamble):

```yaml
proposed_fix:
  unit_id: U-XXX
  halt_type: <halt_type>
  root_cause: "<1-2 sentence summary>"
  evidence_chain:
    - "<file:line> — <what it shows>"
    - "<file:line> — <what it shows>"
  fix:
    file: <relative path>
    location: "<line N OR after function X OR within Y block>"
    change_type: add | modify | remove
    diff:
      before: |
        <verbatim code before change OR null for additions>
      after: |
        <verbatim code after change>
    rationale: "<why this fix resolves the halt>"
  re_execution_plan:
    - "Apply fix to <file>"
    - "Run: <validation command from unit's acceptance_test>"
    - "Expect: <expected outcome>"
  confidence: <0.0-1.0>
  alternative_fixes:  # OPTIONAL, only if multiple valid approaches exist
    - file: <path>
      change: "<brief description>"
      tradeoff: "<why this is alternative, not primary>"
  refusal:  # ONLY if cannot propose fix (overrides above fields)
    reason: "<why fix cannot be proposed>"
    missing_context: ["<what would help>"]
```

## Main thread post-processing

After subagent returns:

1. Parse output YAML
2. Render to user via AskUserQuestion (per execute-bolts SKILL.md propose-and-confirm halt UX):

```
⛔ <Unit-ID> halted: <halt_type> (<retries> retries)
   <halt summary, e.g., test name + failure>
   Bolt confidence: <from bolt-report self-assessment>
   
   AI proposed fix (review evidence below):
   ┌─────────────────────────────────────────────────────────────
   │ Root cause: <proposed_fix.root_cause>
   │ 
   │ Fix: <file> @ <location>
   │   <diff.before> → <diff.after>
   │ 
   │ Re-run: <re_execution_plan command>
   │ 
   │ Evidence trace:
   │ - <evidence_chain[0]>
   │ - <evidence_chain[1]>
   │ - ...
   │ Confidence: <confidence>
   └─────────────────────────────────────────────────────────────
   
❓ How to proceed?
   [1] Apply proposed fix + re-execute (recommended if confidence ≥0.75)
   [2] Show alternative fix options (if alternative_fixes present)
   [3] Reject — I'll fix manually then /mega-sdd --resume
   [4] Override halt — accept current state as "good enough" (logs to memory)
   (Cancel chain — pause everything for review — rides the built-in "Other"/Esc escape; the platform caps AskUserQuestion at 4 options, per halt-recovery.md §Propose-and-confirm)
```

3. On user accept (option 1): apply diff to file → re-execute single bolt → continue batch
4. On user reject (option 3): write proposed_fix to `<vault>/bolts/U-XXX/proposed-fix.md` (preserved for next session) → continue chain pause
5. On user override (option 4): record decision to `<project>/.mega-sdd/memory/decisions.md` "Override accepted halt <halt_type> on <unit_id>" → mark unit as `status: forced_pass` → continue batch (high-risk; audit log mandatory)

## Confidence-driven defaults

- `confidence ≥0.85` → recommend option 1 (Apply + re-execute) as default
- `0.60 ≤ confidence < 0.85` → no default recommendation; user picks
- `confidence < 0.60` → default option 3 (Reject; manual fix) — fix-proposer flagging uncertainty
- Always show confidence prominently in UI

## Halt cycle safety

Per spec §6.7: if same halt fires twice on same bolt with different proposed fixes → escalate to `bolt_repeated_partial_failure` (always-stop). Logic:

```
if bolt.halt_history[-2:].halt_type == halt_type AND
   bolt.halt_history[-2:].proposed_fix_ids are different:
  halt("bolt_repeated_partial_failure", {...})
```

This prevents propose-and-confirm from looping on a structurally-broken unit.

## Anti-halu rails

- Subagent MUST cite line numbers for every evidence claim
- Subagent MUST NOT modify any files (read-only analyzer; main thread applies)
- Subagent MUST refuse if halt type is ineligible (defensive check even if main thread already filtered)
- Subagent confidence MUST be 0.0-1.0 (not "high" / "medium" / "low" strings — numeric for default-recommendation logic)
- alternative_fixes capped at 2 (avoid analysis paralysis)
- Refusal path takes precedence over fix path if both populated

## Performance

Subagent dispatch overhead: ~5-10s per halt. Acceptable because halts are rare in clean runs + user is already paused awaiting decision.

Average bolt run with 1 halt + propose-and-confirm: ~30s additional vs pure pause (~5s dispatch + ~20s user review + ~5s apply). vs current `--resume` flow (~minutes for user to fix manually).

## Backward compatibility

Without propose-and-confirm, halts always pause for manual `--resume`. Propose-and-confirm is opt-IN via halt type eligibility + user config (`~/.mega-sdd/config.yaml` `halt_auto_propose` block). Disable per-type via config:

```yaml
halt_auto_propose:
  test_fail: pause             # disable propose-and-confirm for test_fail
```

Default: all eligible types propose. User-explicit `pause` override always honored.
