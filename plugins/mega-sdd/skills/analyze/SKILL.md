---
name: analyze
description: Unified cross-artifact consistency analysis. Orchestrates all validators + vault internal checks. Produces CONSISTENCY-REPORT.md with PASS/FAIL per boundary. [VERIFY-STEP] surface — user-invoked, deterministic, report-only. Triggers — "analyze", "consistency check", "run all validators", "cek konsistensi", or paraphrases.
---

# mega-sdd:analyze — Unified Consistency Analyzer

## When this skill activates

User explicitly invokes `/mega-sdd:analyze` OR mentions "analyze consistency", "run all validators", "cek konsistensi", "check all boundaries".

## Procedure

### Step 1: Verify CWD has `.mega-sdd/` directory

If absent → inform user this is not a mega-sdd project. Stop.

### Step 2: Run the orchestrator script

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-analyze.sh" --cwd="$(pwd)"
```

Parse the JSON output:
```json
{"state_path": "<path>", "report_path": "<path>", "overall": "PASS|WARN|FAIL"}
```

### Step 3: Read and present the report

Read `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` and present it in chat.

### Step 4: Interpret results

**If `overall == PASS`:**
```
All boundaries clean. Vault internal consistency verified.
Next: <suggest based on CWD state — e.g., "generate-units" if bound-vault exists but no units>
```

**If `overall == WARN`:**
```
Boundaries clean but vault internal consistency has warnings:
<list WARN items>
These are advisory — pipeline can proceed. Review if any seem incorrect.
```

**If `overall == FAIL`:**
```
Consistency check FAILED:
<list FAIL boundaries with detail>

Resolution:
- binding_units_handoff FAIL → re-run /mega-sdd:generate-units with binding OQ-IDs
- unit_spec FAIL → fix unit frontmatter per validate-unit-spec.sh findings
- vault_binding_coverage FAIL → re-run /mega-sdd:bind-codebase
- vault_oqs FAIL → fix OQ structure in vault docs
<etc.>
```

### Step 5: Handoff emission

```yaml
handoff:
  emitted_by: analyze
  emitted_at: <ISO8601>
  status: completed
  artifacts:
    - <cwd>/.mega-sdd/CONSISTENCY-REPORT.md
    - <cwd>/.mega-sdd/.analyze-state.json
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "Consistency analysis complete. Review report and resolve any FAILs before proceeding."
  blockers: []
  metrics:
    validators_run: <N>
    validators_pass: <N>
    validators_fail: <N>
    validators_skip: <N>
    vaults_analyzed: <N>
    overall: <PASS|WARN|FAIL>
```

## Scope constraints

- **Report-only**: NEVER modifies source artifacts. Only writes `.analyze-state.json` and `CONSISTENCY-REPORT.md`.
- **Manual [VERIFY-STEP]**: NOT auto-triggered by hooks. User or orchestrator invokes explicitly.
- **Additive**: Reuses all existing validator scripts unchanged. New vault consistency checks are additive.
- **Idempotent**: Safe to run repeatedly. State files are overwrite-not-append.
