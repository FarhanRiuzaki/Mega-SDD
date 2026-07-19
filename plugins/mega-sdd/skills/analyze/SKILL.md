---
name: analyze
version: 2.2.2
description: Unified cross-artifact consistency analysis — runs all validators + vault checks; produces CONSISTENCY-REPORT.md + cost-weighted TOKEN-COST-REPORT.md. Triggers — "analyze", "consistency check", "check consistency", "consistency report", "run all validators", "token cost", "token usage", "how much did this cost", "cek konsistensi", "berapa cost token", or paraphrases.
---

# mega-sdd:analyze — Unified Consistency Analyzer

> **Output language (Tier-3 artifact):** the analysis / recommendation prose this skill authors into `CONSISTENCY-REPORT.md` (and its chat narration) → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). Tier-1 tokens stay English verbatim — boundary verdicts `PASS`/`FAIL`, validator IDs, field names, paths. Full rules → `plugins/mega-sdd/references/output-language.md`.

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

Read `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` and present it in chat. It ends with a **Token Cost (cost-weighted)** section; the full per-skill breakdown is in `<cwd>/.mega-sdd/TOKEN-COST-REPORT.md`. When the user asks about token usage / cost, present the **cost-weighted** number, not the raw count — raw overstates real cost ~5–8x because cache_read bills ~0.1x (input ×1, cache_creation ×1.25, cache_read ×0.1, output ×5). If `turns == 0`, telemetry captured no usage-bearing turns (the subagent blind-spot) — say so rather than implying zero cost.

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
    - <cwd>/.mega-sdd/TOKEN-COST-REPORT.md
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
