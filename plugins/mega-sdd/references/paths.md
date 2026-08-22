# Mega-SDD Canonical Path Convention

Centralized path definitions for ALL mega-sdd skill outputs: a unified `.mega-sdd/` container at project root, replacing the legacy scattered output locations (migration: `/mega-sdd:migrate-paths`).

Per user UX request — "by default semua file output md hasil skill itu masuk saja otomatis ke `.mega-sdd/*`".

## Contents

- Path resolution algorithm
- Canonical layout
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

1. **Check user override**: `~/.mega-sdd/memory/config.yaml` `default_output_root: <abs-or-rel-path>` (cross-project user preference)
2. **Check project override**: `<project-root>/.mega-sdd/config.yaml` `output_root: <abs-or-rel-path>` (per-repo override)
3. **Default**: `<project-root>/.mega-sdd/`
4. **Legacy detection**: if old-layout paths exist (e.g., `docs/mega-sdd/vaults/`, `.mega-sdd-memory/`, top-level `codebase-map.md`), skills WRITE to legacy paths for back-compat. User opts into new layout via `/mega-sdd:migrate-paths`.

## Canonical layout

```
<project-root>/
├── .mega-sdd/                                    # ALL mega-sdd outputs (default; configurable)
│   ├── config.yaml                                # Project-level config (output_root, opt-outs)
│   ├── slices/<slug>/slice-report.md              # /mega-sdd:slice reports (slice-design, 6.8.0 — new artifact, no legacy location)
│   ├── vaults/<slug>/                             # Vault content + per-vault state
│   │   ├── 00-index.md ... 06-constraints.md     # 7-file vault
│   │   ├── vault.json                             # Manifest
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
│   │   ├── .memory/                               # Vault-scope memory
│   │   │   ├── classifier-accuracy.json
│   │   │   ├── bind-history.md
│   │   │   ├── bolt-outcomes.json                 # + failure_reflection / concerns (learning loop)
│   │   │   ├── drift-history.md                   # drift direction calls (learning loop)
│   │   │   └── citation-failures.jsonl            # citation-failure audit log (emit-fsd)
│   │   └── .internal/                             # Vault-internal state
│   │       ├── checkpoints/<timestamp>-<skill>-<step>.jsonl   # resumable checkpoints
│   ├── knowledge-base/                            # Legacy KB extraction (extract-intelligence)
│   │   ├── README.md
│   │   ├── 00-overview/, 10-domains/, etc.
│   │   └── .scan-meta.json
│   ├── codebase/                                  # Codebase analysis outputs
│   │   ├── codebase-map.md                        # scan-codebase output
│   │   └── symbol-index.json                      # build-symbol-index.sh output (reuse substrate; recomputable, advisory)
│   ├── memory/                                    # PROJECT-scope memory
│   │   ├── decisions.md                           # OQ resolutions, CONFLICT actions
│   │   ├── conventions.md                         # Detected conventions
│   │   ├── outcomes.md                            # Pipeline run summaries
│   │   ├── routing-outcomes.md                    # Orchestrator chain learning
│   │   ├── install-outcomes.md                    # install-deps audit log
│   │   ├── _index.md                              # derived scope index (regenerated; learning loop)
│   │   └── archived-vaults/<slug>/                # Vault archive on delete (MEMORY-OQ-5)
│   └── exports/                                   # Tool-agnostic exports
│       └── (additional exports)
├── AGENTS.md                                       # Tool-agnostic interop at REPO ROOT (unchanged — must be discoverable by other tools)
├── CLAUDE.md                                       # Project AI context (unchanged)
└── (project source: app/, routes/, src/, etc.)
```

## User-scope

```
~/.mega-sdd/
├── memory/                                  # Cross-project user memory
│   ├── preferences.md
│   ├── patterns.md
│   ├── learning-log.md
│   └── config.yaml                          # User defaults (thresholds, opt-outs, default_output_root override)
└── migrations/<from>-to-<to>.sh              # Memory schema migrations
```

## Per-skill path mapping (canonical → legacy)

| Skill | Artifact | Default canonical path | Legacy path |
|---|---|---|---|
| `extract-intelligence` | knowledge-base/ | `.mega-sdd/knowledge-base/` | `docs/knowledge-base/` or `<out>/knowledge-base/` |
| `slice-design` | slice-report.md | `.mega-sdd/slices/<slug>/slice-report.md` | — (new artifact 6.8.0, no legacy location) |
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
| memory (project) | decisions.md, etc. | `.mega-sdd/memory/` | `.mega-sdd-memory/` |
| `orchestrate-flow` | routing-outcomes | `.mega-sdd/memory/routing-outcomes.md` | (no legacy back-compat) |
| `orchestrate-flow` | model-tiers config | `.mega-sdd/config.yaml` (per-project `model_tiers:` section) | (no legacy back-compat) |
| memory (user) | patterns.md, etc. | `~/.mega-sdd/memory/` (UNCHANGED) | same |
| memory (vault) | classifier-accuracy.json | `<vault>/.memory/` (UNCHANGED) | same |
| `emit-agents-md` | AGENTS.md | `<repo-root>/AGENTS.md` (UNCHANGED — interop file) | same |

## Detection logic

Each writer skill resolves `OUTPUT_ROOT`:

```bash
# Pseudo-code for OUTPUT_ROOT resolution
OUTPUT_ROOT=""

# 1. User override (cross-project)
if [ -f ~/.mega-sdd/memory/config.yaml ] && grep -q "default_output_root:" ~/.mega-sdd/memory/config.yaml; then
  OUTPUT_ROOT=$(yaml_get ~/.mega-sdd/memory/config.yaml default_output_root)
fi

# 2. Project override
if [ -f "<project>/.mega-sdd/config.yaml" ] && grep -q "output_root:" "<project>/.mega-sdd/config.yaml"; then
  OUTPUT_ROOT=$(yaml_get "<project>/.mega-sdd/config.yaml" output_root)
fi

# 3. Default (canonical)
if [ -z "$OUTPUT_ROOT" ]; then
  OUTPUT_ROOT="<project>/.mega-sdd"
fi

# 4. Back-compat detection: if legacy paths exist AND new paths don't, WRITE to legacy
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

Same protocol for codebase-map (`<project>/.mega-sdd/codebase/codebase-map.md` → `<project>/codebase-map.md`), KB (`<project>/.mega-sdd/knowledge-base/` → `docs/knowledge-base/` → `docs/mega-sdd/knowledge-base/` → `old-reference/knowledge-base/`), and project memory (`<project>/.mega-sdd/memory/` → `<project>/.mega-sdd-memory/`).

## Config file format

`<project-root>/.mega-sdd/config.yaml` (full key reference: `plugins/mega-sdd/references/project-config.md`):

```yaml
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

**Multi-dev note:** `vault.json`, `binding.md`, and `claims-ledger.json` are whole-file regenerated state — git line-merge of any of them after two devs ran the pipeline concurrently produces a corrupt file (the GROUND-time guard in `scripts/ground.sh` detects unparseable vault.json but does not merge it). Team options: (a) one-writer-at-a-time discipline (feature branch per vault), or (b) gitignore `vault.json` + regenerate from markdown on checkout (`vault.json` is derived; the markdown is the truth). Per-dev noise files (`outcomes.md`, `routing-outcomes.md`, `telemetry.jsonl`, `.dirty-paths.jsonl`) should always be gitignored.

## References

- `commands/migrate-paths.md` — migration helper
- `plugins/mega-sdd/references/upgrade-from-old-version.md` — legacy-layout upgrade guide

## Derived caches (never state)

- `<root>/.mega-sdd/.cache/pack-resolver/` — the framework-pack resolver's derived stdout cache (one file per section/chain request). Discardable at any time; deleting it costs one cold resolve. Never committed (gitignored), never read as project state.
- `<root>/.mega-sdd/.stop-scan-stamp` — the Stop hook's turn-gate stamp (HEAD sha at the last artifact scan). Absence simply means the next Stop scans; never committed.
- `<root>/.mega-sdd/.ptu-scan-stamp` — the PostToolUse debounce stamp for the 4 unconditional project-wide scanners (HEAD sha at their last run). Absence simply means the next Write|Edit scans; never committed.
