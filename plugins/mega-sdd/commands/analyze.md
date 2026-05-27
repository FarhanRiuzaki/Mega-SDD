---
description: Run unified cross-artifact consistency analysis — orchestrates all validators + vault internal checks, produces CONSISTENCY-REPORT.md. [VERIFY-STEP] surface per R1 roadmap.
---

# /mega-sdd:analyze

Run the unified consistency analyzer across all mega-sdd artifacts in the current project. This is the [VERIFY-STEP] surface — user-invoked, deterministic, read-only (writes report only, never modifies source artifacts).

## What it does

1. Invokes 6 existing validator scripts against `<cwd>/.mega-sdd/`:
   - `validate-handoff-binding-units.sh` — binding→units OQ-ID propagation
   - `validate-unit-spec.sh` — unit frontmatter + Hard Rules grammar
   - `validate-bolt-artifacts.sh` — bolt report structure
   - `validate-vault-oqs.sh` — vault OQ structural integrity
   - `validate-fsd-slots.sh` — FSD template slot fill
   - `validate-vault-binding-coverage.sh` — vault→binding coverage

2. Runs vault internal consistency checks (NEW):
   - vault.json entities count ↔ 03-data-model.md entity blocks
   - vault.json OQ count ↔ 00-index.md OQ tags
   - vault.json flows count ↔ 04-flows.md flow IDs
   - 7+1 required vault files presence
   - source_documents paths exist on disk

3. Writes:
   - `<cwd>/.mega-sdd/.analyze-state.json` — machine-readable aggregate (PASS/FAIL/SKIP per boundary + vault consistency)
   - `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` — human-readable report

## Usage

```
/mega-sdd:analyze
```

No arguments. CWD auto-detected.

## When to use

- **Before proceeding from one phase to the next** — verify all boundaries are clean
- **After resolving CONFLICTs or OQs** — verify resolution propagated correctly
- **Periodic health check** — verify no silent drift accumulated
- **Before execute-bolts** — comprehensive pre-flight beyond just the binding→units gate

## What this is NOT

- NOT auto-triggered by hooks (manual [VERIFY-STEP] only — per R1 design discipline)
- NOT a replacement for per-boundary validators (those still fire on PostToolUse; this aggregates their results)
- NOT a fixer — reports only, never modifies artifacts

## Implementation

When user invokes `/mega-sdd:analyze`:

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-analyze.sh" --cwd="$(pwd)"`
2. Read the output JSON: `{"state_path": "...", "report_path": "...", "overall": "PASS|WARN|FAIL"}`
3. Read and display `CONSISTENCY-REPORT.md` in chat
4. If `overall == FAIL`: surface failing boundaries + vault consistency issues clearly, suggest resolution path per failing validator
5. If `overall == PASS`: confirm clean state, suggest next pipeline step based on CWD signals
