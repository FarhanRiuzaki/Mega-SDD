---
name: analyze
version: 2.4.0
description: Unified cross-artifact consistency analysis — semantic-scoped validator re-runs (unchanged files reuse their ledgered verdict) + vault checks; produces CONSISTENCY-REPORT.md. Triggers — "analyze", "consistency check", "check consistency", "consistency report", "run all validators", "cek konsistensi", or paraphrases.
---

# mega-sdd:analyze — Unified Consistency Analyzer

> **Output language (Tier-3 artifact):** the analysis / recommendation prose this skill authors into `CONSISTENCY-REPORT.md` (and its chat narration) → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). Tier-1 tokens stay English verbatim — boundary verdicts `PASS`/`FAIL`, validator IDs, field names, paths. Full rules → `plugins/mega-sdd/references/output-language.md`.

## When this skill activates

User mentions "analyze consistency", "run all validators", "cek konsistensi", "check all boundaries" — routed via the front door (`/mega-sdd`) or directly by phrase. (The typed alias form is retired; typed legacy text still routes here by phrase.)

## Two modes

**Auto mode (hook-driven — no user action needed).** Fires automatically via the **Stop hook** (end of agent turn, when the spine/profile opts in — `spine: classic` or `profile: full`): aggregates existing `.*-state.json` files written by PostToolUse validators during the session → produces `CONSISTENCY-REPORT.md`. Cheap (no validator re-run — reads state files only). Also on **PostToolUse Write** at phase-boundary artifacts (`binding.md`, `vault.json`, `_index.md`, `FSD.md`, `DRIFT-REPORT.md`) — same aggregate-only mode, inter-phase visibility. The report updates silently in `.mega-sdd/CONSISTENCY-REPORT.md`.

**Manual mode (user-invoked — semantic-scoped re-run).** The procedure below: re-runs the validator suite + vault internal consistency checks, and surfaces every code-delivery gate read-only from its state file. **Scoped by default** (spec 2026-08-03-semantic-scoped-validation.md); `--fresh` forces a ground-up re-run. Use when: starting a new session (stale state files) · after resolving CONFLICTs/OQs (verify propagation) · before execute-bolts (comprehensive pre-flight) · periodic health check.

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

**Semantic-scoped by default:** per-file validators re-run only for files changed since the last analyze (freshness ledger `.mega-sdd/.analyze-freshness.json`); unchanged files fold their recorded verdict without a spawn, and the report's `Scope:` line says exactly how many were re-run vs reused. Pass `--fresh` (user asks for a forced/ground-up re-check, or after a suspected ledger problem) to re-run everything. Scoping is report-layer only — the execute-bolts gate re-derives its states from ground truth regardless, so a stale ledger can never open a gate.

### Step 3: Read and present the report

Read `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` and present it in chat. (Token/cost reporting was REMOVED in v7.3.0 — mega-sdd is pipeline-only; usage accounting is the gateway/harness's concern. If the user asks about token cost, say the plugin no longer measures it.)

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
- binding_units_handoff FAIL → re-run generate-units with binding OQ-IDs
- unit_spec FAIL → fix unit frontmatter per validate-unit-spec.sh findings
- vault_binding_coverage FAIL → re-run bind-codebase
- vault_oqs FAIL → fix OQ structure in vault docs
- FAIL traceable to a low-precision (regex-tier) scan or another missing optional native dep upstream → run `/mega-sdd:install-deps` then re-run the upstream skill (scan-codebase / generate-units / etc.)
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

## Validators orchestrated (core set — scoped re-run; unchanged files reuse their ledgered verdict, `--fresh` re-runs all)

| # | Validator | Boundary |
|---|---|---|
| 1 | `validate-handoff-binding-units.sh` | binding→units OQ-ID propagation |
| 2 | `validate-unit-spec.sh` | unit frontmatter + Hard Rules grammar |
| 3 | `validate-bolt-artifacts.sh` | bolt report structure |
| 4 | `validate-vault-oqs.sh` | vault OQ structural integrity |
| 5 | `validate-fsd-slots.sh` | FSD template slot fill |
| 6 | `validate-kb.sh --surface=output` | KB output completeness + frontmatter |
| 7 | `validate-kb.sh --surface=markers` | KB [VERIFIED] citation evidence |
| 8 | `validate-kb.sh --surface=citations` | KB §11 source file resolution |
| 9 | `validate-constitution.sh` | constitution clause coverage |
| 10 | `validate-constitution-propagation.sh` | constitution clause carry-over |
| 11 | `validate-codebase-map.sh` | codebase-map schema |

Plus: vault internal consistency checks (entities/OQs/flows count sync, file completeness, source doc paths).

**Domain-rule gap check (Mode B — LLM, v7):** when a KB exists, READ `knowledge-base/40-business-rules/*.md` against the vault's rules/flows and report any domain rule with no vault counterpart (and vice versa) as an advisory finding in the report. This is semantic-gap detection — judgment work; the old keyword-overlap script (`audit-domain-rules.sh`) was demoted and removed in v7 Fase 2.

### Code-delivery gates (surfaced read-only)

Beyond the core set, the report surfaces every code-delivery gate's last status read-only from its PostToolUse state file (`NOT_RUN` until a chain writes it), so analyze is a true pre-flight of what will block `execute-bolts`:

- **KEPT hard-blocks** — block `execute-bolts` at the PreToolUse gate; a FAIL here flips the report to FAIL: `flow-coverage`, `render-test` (via unit-spec), `sibling-consistency`, `ui-quality`, `cross-cutting-registration`. (Plus the core invariants enforced at the hook: binding→units handoff, preflight, scope-flag, anti-self-bypass.)
- **DEMOTED to advisory** (v4 Hybrid — surfaced but NEVER block; an advisory FAIL shows as overall WARN): `dispatch-prompt`, `operator-UX` (vault-oqs), `fanout-parity`, `ui-deferral`, `vault-flow-staging`.

## Scope constraints

- **Report-only**: NEVER modifies source artifacts. Only writes `.analyze-state.json` and `CONSISTENCY-REPORT.md`.
- **Manual [VERIFY-STEP]**: NOT auto-triggered by hooks. User or orchestrator invokes explicitly.
- **Additive**: Reuses all existing validator scripts unchanged. New vault consistency checks are additive.
- **Idempotent**: Safe to run repeatedly. State files are overwrite-not-append.
