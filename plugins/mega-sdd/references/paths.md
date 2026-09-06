# Mega-SDD Canonical Path Convention

Centralized path definitions for ALL mega-sdd skill outputs: a unified `.mega-sdd/` container at project root, replacing the legacy scattered output locations (migration: `/mega-sdd:migrate-paths`).

Per user UX request — "by default semua file output md hasil skill itu masuk saja otomatis ke `.mega-sdd/*`".

## Contents

- Path resolution algorithm
- Canonical layout
- Root state surface (`.mega-sdd/` dot-files)
- User-scope
- Per-skill path mapping (canonical → legacy)
- Detection logic
- Read-side compatibility
- Config file format
- Why .mega-sdd at project root (not docs/)
- Migration
- Recommended `.gitignore` entries
- References

## Path resolution algorithm

Every writer skill resolves output paths via this protocol:

1. **Check user override**: `~/.mega-sdd/config.yaml` `default_output_root: <abs-or-rel-path>` (cross-project user preference) *(documented-only — no code reads `default_output_root` today)*
2. **Check project override**: `<project-root>/.mega-sdd/config.yaml` `output_root: <abs-or-rel-path>` (per-repo override)
3. **Default**: `<project-root>/.mega-sdd/`
4. **Legacy detection**: if old-layout paths exist (e.g., `docs/mega-sdd/vaults/`, `.mega-sdd-memory/`, top-level `codebase-map.md`), skills WRITE to legacy paths for back-compat. User opts into new layout via `/mega-sdd:migrate-paths`.

## Canonical layout

```
<project-root>/
├── .mega-sdd/                                    # ALL mega-sdd outputs (default; configurable)
│   ├── config.yaml                                # Project-level config (output_root, opt-outs)
│   ├── vaults/<slug>/                             # Vault content + per-vault state
│   │   ├── vault.md, model.md, flows.md,          # 4-file layout-2 vault (v7; legacy vaults:
│   │   │   constraints.md                         #   00-index.md ... 06-constraints.md — see §Vault layout)
│   │   ├── vault.json                             # Manifest (carries vault_layout: 2 on layout-2)
│   │   ├── claims-ledger.json                     # Derived claim index (derive-claims-ledger.sh — bind --express input)
│   │   ├── binding.md                             # Binding manifest (after bind-codebase)
│   │   ├── bound/                                 # Bound-vault (after binding clean)
│   │   ├── units/U-*.md, _index.md                # Atomic units
│   │   ├── bolts/U-*/bolt-report.md               # Bolt outcomes
│   │   ├── bolts/U-*/preflight.json, postflight.json  # Hard Rule snapshots
│   │   ├── bolts/U-*/acceptance.json              # B4 acceptance evidence (run-acceptance-tests.sh)
│   │   ├── bolts/U-*/dispatch-prompt.md           # Assembled bolt dispatch (build-dispatch-prompt.sh)
│   │   ├── bolts/U-*/findings.json                # Review-panel finding ledger (controller-written; review-panel.md §Attempt rounds)
│   │   ├── lens-inputs/U-*/design-slice.md        # Controller-written REVIEW-LENS inputs ONLY — never implementer/reviewer output (review-panel.md §Blind dispatch)
│   │   ├── lens-inputs/U-*/l0-results.json        # L0 code-gate results for the panel (controller-written, overwritten per round)
│   │   ├── interfaces/                            # Multi-squad interface notes
│   │   ├── fsd/                                   # Confluence FSD output (emit-fsd)
│   │   │   ├── FSD.md                             # Markdown source
│   │   │   ├── FSD.pdf                            # Rendered PDF (md2pdf.sh — GitHub-style, never LaTeX)
│   │   │   ├── FSD.styling.yaml                   # User-editable styling overrides
│   │   │   ├── .citation-map.json                 # Audit trace per section
│   │   │   └── .doc-history.json                  # Doc versioning sidecar (refresh-doc-stamps.sh --bump)
│   │   ├── prd/                                   # PRD output (emit-prd): PRD.md, PRD.pdf, .citation-map.json, .doc-history.json
│   │   ├── sit/                                   # SIT output (emit-sit): SIT.md, SIT.pdf, .sit-evidence.md, .citation-map.json, .doc-history.json
│   │   ├── uat/                                   # UAT output (emit-uat): UAT.md, UAT.pdf, UAT-v<version>.xlsx, .uat-scaffold.md, .citation-map.json, .doc-history.json
│   │   │   ├── e2e/                               # Playwright skeletons (build-uat-e2e.sh, 6.10.0): UAT-NNN.spec.ts + config + package.json + .gitignore
│   │   │   └── evidence/<UAT-id>/<run-ts>/        # auditor evidence packs (uat-run.sh, sole hook-guarded writer): result.json + screenshots/ + trace.zip
│   │   ├── _meta/squads.yaml                      # Multi-squad partition
│   │   ├── .memory/                               # Vault-scope PIPELINE state (name is historical)
│   │   │   └── bolt-outcomes.json                 # per-unit completion — read by query-graph --modules
│   │   └── .internal/                             # Vault-internal state
│   │       ├── checkpoints/<timestamp>-<skill>-<step>.jsonl   # resumable checkpoints
│   ├── knowledge-base/                            # Legacy extraction (extract-intelligence): census.json + modules/*.prd.md + README (PRD-kontrak; pre-v7.6 numbered tree still readable)
│   │   ├── README.md
│   │   ├── 00-overview/, 10-domains/, etc.
│   │   └── .scan-meta.json
│   ├── codebase/                                  # Codebase analysis outputs
│   │   ├── codebase-map.md                        # scan-codebase output
│   │   └── symbol-index.json                      # build-symbol-index.sh output (reuse substrate; recomputable, advisory)
│   └── exports/                                   # Tool-agnostic exports — reserved, no writer today
│       └── (additional exports)
├── AGENTS.md                                       # Tool-agnostic interop at REPO ROOT (unchanged — must be discoverable by other tools)
├── CLAUDE.md                                       # Project AI context (unchanged)
└── (project source: app/, routes/, src/, etc.)
```

## Root state surface (`.mega-sdd/` dot-files)

Live state files at the `.mega-sdd/` root (writers in parentheses):

- `.validation-blockers.json` — gate aggregator (PreToolUse gate)
- `.locked-files-index.json` — `build-locked-index.sh`; read by GateGuard + the v7.5.0 LOCKED-edit notice
- `codebase/.dirty-paths.jsonl` — PostToolUse journal; read by the session-start notice + the completion census
- `state.json` — routing digest (`derive-state.sh` / `ground.sh`)
- `graph.json` — `build-graph.sh`; gates the Stop-hook publisher leg
- `factory-ledger.json` — Factory Line ledger
- `CONSISTENCY-REPORT.md` — analyze output
- `codebase/reuse-index.yaml` + `codebase/symbol-index.json` — reuse substrate
- `codebase/starterkit-context.yaml` — deep-scan cache
- `codebase/framework-conventions/` — resolved framework packs
- `.cache/pack-resolver/` — derived cache (see §Derived caches)
- `.stop-scan-stamp` — Stop-hook turn-gate stamp (see §Derived caches)

Plus ~35 `.*-state.json` validator/gate state files (one per validator; written by their deterministic writers, re-derived at gates).

## Vault layout (v7 layout-2 ↔ legacy 7-file)

Layout-2 (v7 default; marker `vault_layout: 2` in the vault.md frontmatter + vault.json) is the 4-file vault. Every reader is DUAL-LAYOUT for one minor cycle (probe the layout-2 file first, fall back to the legacy name — floor v5.9.0 kantor). Migration: `migrate-paths.sh --vault-layout` (dry-run default; `--apply` executes) → then a FULL re-bind is MANDATORY (line anchors invalidated; binding.json/.citation-map.json are regenerated, never patched).

| Layout-2 | Legacy (7-file) | Content |
|---|---|---|
| `vault.md` frontmatter | `00-index.md` §Vault Lock Status | the six lock values (+ `project_scale` since 7.29.0, + `kb_module_graph`) |
| `vault.md ## Overview` | `01-overview.md` | product, personas, problem, success criteria |
| `vault.md ## Architecture` | `02-architecture.md` | layers, components, API contracts |
| `vault.md ## Decisions` | `05-decisions.md` | `### D-NNN` ADRs |
| `vault.md` Glossary/Auto-Classification/Source documents/Changelog | `00-index.md` sections | moved verbatim (roll-up + reading ceremony retired) |
| `model.md` | `03-data-model.md` | DBML entities |
| `flows.md` | `04-flows.md` | Mermaid flows + DoD (the hot surface — hook + locators dual-probe) |
| `constraints.md` (+ `## Open Questions`, `[origin:]` tokens) | `06-constraints.md` + per-doc OQ sections + the roll-up | constraints + THE one authored OQ home |

The `## Overview` / `## Architecture` / `## Decisions` anchors are a HARD-HEADER CONTRACT — derive-vault-json + derive-claims-ledger exit 2 naming the missing header (DOC_CODE re-keys filename→section on layout-2).

## User-scope

```
~/.mega-sdd/
└── config.yaml                              # User defaults (halt_auto_propose, default_output_root override)
                                             # (v7.3.0: relocated from ~/.mega-sdd/memory/config.yaml; the memory dir is removed)
```

## Per-skill path mapping (canonical → legacy)

| Skill | Artifact | Default canonical path | Legacy path |
|---|---|---|---|
| `extract-intelligence` | knowledge-base/ (census.json + modules/*.prd.md + README.md) | `.mega-sdd/knowledge-base/` | `docs/knowledge-base/` or `<out>/knowledge-base/` |
| `scan-codebase` | codebase-map.md | `.mega-sdd/codebase/codebase-map.md` | `<repo-root>/codebase-map.md` |
| `scan-codebase` | starterkit-context | `.mega-sdd/codebase/starterkit-context.yaml` | `docs/codebase/starterkit-context.yaml` (legacy back-compat probe only) |
| `build-symbol-index.sh` (script) | symbol-index | `.mega-sdd/codebase/symbol-index.json` | — (new artifact, no legacy location) |
| `generate-intent` | vault/ | `.mega-sdd/vaults/<slug>/` | `docs/mega-sdd/vaults/<slug>/` |
| `bind-codebase` | binding.md + bound/ | `<vault>/binding.md` + `<vault>/bound/` | `<vault>/binding.md` + `<vault>-bound/` |
| `derive-claims-ledger.sh` (script) | claims-ledger | `<vault>/claims-ledger.json` | — (new artifact, no legacy location) |
| `generate-units` | units/ | `<vault>/units/` | `<vault>-bound/units/` (or `<vault>/units/`) |
| `execute-bolts` | bolts/ | `<vault>/bolts/U-*/` | `<vault>/bolts/U-*/` |
| `execute-bolts` | lens-inputs/ | `<vault>/lens-inputs/U-*/` | n/a (new 2026-07-31) |
| `execute-bolts` | checkpoints | `<vault>/.internal/checkpoints/` | `<vault>/.mega-sdd/checkpoints/` |
| `orchestrate-flow` | model-tiers config | `.mega-sdd/config.yaml` (per-project `model_tiers:` section) | (no legacy back-compat) |
| `emit-agents-md` | AGENTS.md | `<repo-root>/AGENTS.md` (UNCHANGED — interop file) | same |
| `slice-design` (plugin `mega-sdd-extras`, separate install — writes NOTHING else under `.mega-sdd/`) | slice-report.md | `.mega-sdd/slices/<slug>/slice-report.md` | same path the 6.8.0–7.4.0 core skill used |

The project `.mega-sdd/memory/` dir is still honored as a project-root MARKER by `scripts/_lib/resolve-project-root.sh` and rewritten by migrate-paths, but nothing writes it since v7.3.0. The only live vault-memory artifact is `<vault>/.memory/bolt-outcomes.json` (documented in the canonical-layout tree above).

## Detection logic

Each writer skill resolves `OUTPUT_ROOT`:

```bash
# Pseudo-code for OUTPUT_ROOT resolution
OUTPUT_ROOT=""

# 1. Project override
if [ -f "<project>/.mega-sdd/config.yaml" ] && grep -q "output_root:" "<project>/.mega-sdd/config.yaml"; then
  OUTPUT_ROOT=$(yaml_get "<project>/.mega-sdd/config.yaml" output_root)
fi

# 2. Default (canonical)
if [ -z "$OUTPUT_ROOT" ]; then
  OUTPUT_ROOT="<project>/.mega-sdd"
fi

# 3. Back-compat detection: if legacy paths exist AND new paths don't, WRITE to legacy
# (Skills that detect old layout continue using it; user explicitly migrates via /mega-sdd:migrate-paths)
if [ -d "<project>/docs/mega-sdd/vaults" ] && [ ! -d "$OUTPUT_ROOT/vaults" ]; then
  LEGACY_LAYOUT=true
  echo "ℹ️ Legacy layout detected. Outputs go to docs/mega-sdd/vaults/. Migrate via /mega-sdd:migrate-paths."
fi
```

## Read-side compatibility

Skills that READ existing artifacts probe MULTIPLE paths in priority order:

```bash
# Probe new layout first, fall back to legacy
for candidate in \
  "<project>/.mega-sdd/vaults/<slug>" \
  "<project>/docs/mega-sdd/vaults/<slug>"; do
  if [ -d "$candidate" ]; then
    VAULT_PATH="$candidate"
    break
  fi
done
```

Same protocol for codebase-map (`<project>/.mega-sdd/codebase/codebase-map.md` → `<project>/codebase-map.md`) and KB (`<project>/.mega-sdd/knowledge-base/` → `docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` → `old-reference/knowledge-base/`).

## Config file format

`<project-root>/.mega-sdd/config.yaml` (full key reference: `plugins/mega-sdd/references/project-config.md`):

```yaml
# scaffold defaults written by migrate-paths.sh; `layout:`, `defaults:`, `probe_paths:`, `mega_sdd_schema:` have NO reader today — live keys are documented in references/project-config.md
# Project-level mega-sdd config
mega_sdd_schema: 1

# Output root override (default: .mega-sdd/ — i.e., this file's parent dir)
output_root: .mega-sdd/    # relative to project root; or absolute

# Layout mode
layout: new                 # new (canonical default) | legacy (preserves pre-migration paths)

# Per-skill memory opt-outs
defaults:
  memory_enabled: true
  emit_agents_md: true
  defensive_generation: true

# Detection paths (skills probe these in addition to default; useful for non-standard layouts)
probe_paths:
  vault_candidates:
    - .mega-sdd/vaults/
    - docs/mega-sdd/vaults/
  knowledge_base_candidates:
    - .mega-sdd/knowledge-base/
    - docs/knowledge-base/
    - old-reference/knowledge-base/
```

## Why .mega-sdd at project root (not docs/)

| Aspect | Old (`docs/mega-sdd/`) | New (`.mega-sdd/`) |
|---|---|---|
| Visibility | Visible in file tree | Hidden by default (most tools/IDEs hide dotfiles) |
| Discoverability for AI tools | Mixed with project docs | Clearly separated as mega-sdd state |
| Git tracking | Often tracked (developer-facing) | Per-project decision (recommend track `vaults/`, `decisions.md`, `conventions.md`; gitignore `outcomes.md`, `.internal/`, `.memory/`) |
| Convention parity | Mixed with markdown docs | Matches `.git/`, `.vscode/`, `.idea/` patterns (tool state) |
| Migration cost | n/a | One-time `/mega-sdd:migrate-paths` |

User explicitly requested consolidation under `.mega-sdd/`. Trade-off: lose some default visibility for vault content. Mitigation: tools that need to read vault content (Continue.dev, Cursor) consume `AGENTS.md` at root (which mega-sdd auto-emits via `emit-agents-md`).

## Migration

`/mega-sdd:migrate-paths` walks old layout, moves to new with `git mv` where safe, updates internal references in vault.json, binding.md, and per-file frontmatter. See `commands/migrate-paths.md`.

Migration is opt-in. Existing projects continue to work with legacy paths via back-compat detection.

## Recommended `.gitignore` entries

For project repo `.gitignore`:

```
# Mega-SDD ephemeral state (per-project decision; uncomment what you want untracked)
# .mega-sdd/memory/outcomes.md          # noisy per-dev run logs
# .mega-sdd/vaults/*/.internal/          # checkpoints (stale symbol-graph.json caches from <5.29.0 are inert — safe to delete)
# .mega-sdd/vaults/*/.memory/            # per-vault ephemeral memory
# .mega-sdd/vaults/*/bolts/              # bolt reports (regenerable)
# .mega-sdd/vaults/*/lens-inputs/        # review-lens inputs (derived per bolt; regenerable)
# .mega-sdd/vaults/*/claims-ledger.json  # derived claim index (regenerable; re-derived on every express bind)
```

Mega-sdd does NOT modify your `.gitignore` automatically. User decides what to track per team norms.

**Multi-dev note:** `vault.json`, `binding.md`, and `claims-ledger.json` are whole-file regenerated state — git line-merge of any of them after two devs ran the pipeline concurrently produces a corrupt file (the GROUND-time guard in `scripts/ground.sh` detects unparseable vault.json but does not merge it). Team options: (a) one-writer-at-a-time discipline (feature branch per vault), or (b) gitignore `vault.json` + regenerate from markdown on checkout (`vault.json` is derived; the markdown is the truth). The per-dev noise file (`.dirty-paths.jsonl`) should always be gitignored.

## References

- `commands/migrate-paths.md` — migration helper
- `docs/mega-sdd/upgrade-from-old-version.md` (repo docs, maintainer-facing since v7.4.0) — legacy-layout upgrade guide

## Derived caches (never state)

- `<root>/.mega-sdd/.cache/pack-resolver/` — the framework-pack resolver's derived stdout cache (one file per section/chain request). Discardable at any time; deleting it costs one cold resolve. Never committed (gitignored), never read as project state.
- `<root>/.mega-sdd/.stop-scan-stamp` — the Stop hook's turn-gate stamp (HEAD sha at the last artifact scan). Absence simply means the next Stop scans; never committed.
- `<root>/.mega-sdd/.ptu-scan-stamp` — legacy name — the PostToolUse debounce and its 4 scanners were removed in v7; retained only in the anti-forge guard + probe-prune lists, never written.
