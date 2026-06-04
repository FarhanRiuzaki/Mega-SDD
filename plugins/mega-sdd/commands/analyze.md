---
description: Unified cross-artifact consistency analysis — runs in two modes. AUTO (hook-driven, aggregate-only, fires at chain-end + phase boundary) and MANUAL (user-invoked, re-runs all validators). Produces CONSISTENCY-REPORT.md.
---

# /mega-sdd:analyze

Unified consistency analyzer across all mega-sdd artifacts. Two modes:

## Auto mode (hook-driven — no user action needed)

Fires automatically via:
- **Stop hook** (end of every agent turn): aggregates existing `.*-state.json` files written by PostToolUse validators during the session → produces `CONSISTENCY-REPORT.md`. Cheap (no validator re-run — reads state files only).
- **PostToolUse Write** on phase-boundary artifacts (`binding.md`, `vault.json`, `_index.md`, `FSD.md`, `DRIFT-REPORT.md`): same aggregate-only mode, gives inter-phase visibility.

The report updates silently; user sees it in `.mega-sdd/CONSISTENCY-REPORT.md`.

## Manual mode (user-invoked — full re-run)

```
/mega-sdd:analyze
```

Re-runs ALL 14 validators fresh + vault internal consistency checks. Use when:
- Starting a new session (state files may be stale from prior session)
- After resolving CONFLICTs or OQs — verify resolution propagated correctly
- Before execute-bolts — comprehensive pre-flight
- Periodic health check

## Validators orchestrated (14)

| # | Validator | Boundary |
|---|---|---|
| 1 | `validate-handoff-binding-units.sh` | binding→units OQ-ID propagation |
| 2 | `validate-unit-spec.sh` | unit frontmatter + Hard Rules grammar |
| 3 | `validate-bolt-artifacts.sh` | bolt report structure |
| 4 | `validate-vault-oqs.sh` | vault OQ structural integrity |
| 5 | `validate-fsd-slots.sh` | FSD template slot fill |
| 6 | `validate-vault-binding-coverage.sh` | vault→binding coverage |
| 7 | `validate-kb-output.sh` | KB output completeness + frontmatter |
| 8 | `validate-kb-markers.sh` | KB [VERIFIED] citation evidence |
| 9 | `validate-kb-citations.sh` | KB §11 source file resolution |
| 10 | `validate-conflict-classification.sh` | CONFLICT classification enrichment |
| 11 | `audit-domain-rules.sh` | domain-rule gap detection (Mode B) |
| 12 | `validate-constitution.sh` | constitution clause coverage |
| 13 | `validate-constitution-propagation.sh` | constitution clause carry-over |
| 14 | `validate-codebase-map.sh` | codebase-map schema |

Plus: vault internal consistency checks (entities/OQs/flows count sync, file completeness, source doc paths).

### Advisory (non-blocking) code-delivery checks

Surfaced read-only from their PostToolUse state files. These were demoted from PreToolUse hard-blocks to advisory — they appear in the report (an advisory FAIL shows as overall WARN, never FAIL) but never block `execute-bolts`:

- `dispatch-prompt` — the ui_ux bolt dispatch prompt carries design tokens + a view exemplar
- `fanout-parity` — view-bearing siblings declare the same kind of obligation
- `ui-deferral` — a bolt-report doesn't defer a `## UI contract` to a later unit
- `vault-flow-staging` — a flow preserves the `stages:` block its KB workflow carried

The code-delivery gates that **remain HARD-BLOCKS** at PreToolUse (not advisory): flow-coverage, render-test, sibling-consistency, ui-quality, cross-cutting-registration — plus the core invariants (binding→units handoff, preflight, scope-flag, anti-self-bypass).

## Outputs

- `<cwd>/.mega-sdd/.analyze-state.json` — machine-readable aggregate
- `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` — human-readable report

## Implementation

When user invokes `/mega-sdd:analyze`:

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-analyze.sh" --cwd="$(pwd)"`
2. Read and display `CONSISTENCY-REPORT.md` in chat
3. If `overall == FAIL`: surface failing boundaries, suggest resolution path
4. If `overall == PASS`: confirm clean state, suggest next pipeline step
