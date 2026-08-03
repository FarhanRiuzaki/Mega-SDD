---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:analyze` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

# /mega-sdd:analyze

Unified consistency analyzer across all mega-sdd artifacts. Two modes:

## Auto mode (hook-driven — no user action needed)

Fires automatically via:
- **Stop hook** (end of every agent turn): aggregates existing `.*-state.json` files written by PostToolUse validators during the session → produces `CONSISTENCY-REPORT.md`. Cheap (no validator re-run — reads state files only).
- **PostToolUse Write** on phase-boundary artifacts (`binding.md`, `vault.json`, `_index.md`, `FSD.md`, `DRIFT-REPORT.md`): same aggregate-only mode, gives inter-phase visibility.

The report updates silently; user sees it in `.mega-sdd/CONSISTENCY-REPORT.md`.

## Manual mode (user-invoked — semantic-scoped re-run)

```
/mega-sdd:analyze [--fresh]
```

Re-runs the validator suite + vault internal consistency checks, and surfaces every code-delivery gate read-only from its state file. **Scoped by default** (spec 2026-08-03-semantic-scoped-validation.md): per-file validators re-run only for files changed since the last analyze (freshness ledger `.mega-sdd/.analyze-freshness.json`); unchanged files reuse their recorded verdict spawn-free, and the report's `Scope:` line discloses the split. `--fresh` forces a ground-up re-run. Report-layer only — no gate reads the ledger. Use when:
- Starting a new session (state files may be stale from prior session)
- After resolving CONFLICTs or OQs — verify resolution propagated correctly
- Before execute-bolts — comprehensive pre-flight
- Periodic health check

## Validators orchestrated (core set — scoped re-run; unchanged files reuse their ledgered verdict, `--fresh` re-runs all)

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

### Code-delivery gates (surfaced read-only)

Beyond the core set above, the report surfaces every code-delivery gate's last status read-only from its PostToolUse state file (`NOT_RUN` until a chain writes it), so `/mega-sdd:analyze` is a true pre-flight of what will block `execute-bolts`:

- **KEPT hard-blocks** — block `execute-bolts` at the PreToolUse gate; a FAIL here flips the report to FAIL: `flow-coverage`, `render-test` (via unit-spec), `sibling-consistency`, `ui-quality`, `cross-cutting-registration`. (Plus the core invariants enforced at the hook: binding→units handoff, preflight, scope-flag, anti-self-bypass.)
- **DEMOTED to advisory** (v4 Hybrid — surfaced but NEVER block; an advisory FAIL shows as overall WARN): `dispatch-prompt`, `operator-UX` (vault-oqs), `fanout-parity`, `ui-deferral`, `vault-flow-staging`.

## Outputs

- `<cwd>/.mega-sdd/.analyze-state.json` — machine-readable aggregate
- `<cwd>/.mega-sdd/CONSISTENCY-REPORT.md` — human-readable report

## Implementation

When user invokes `/mega-sdd:analyze`:

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-analyze.sh" --cwd="$(pwd)"`
2. Read and display `CONSISTENCY-REPORT.md` in chat
3. If `overall == FAIL`: surface failing boundaries, suggest resolution path
4. If `overall == PASS`: confirm clean state, suggest next pipeline step
