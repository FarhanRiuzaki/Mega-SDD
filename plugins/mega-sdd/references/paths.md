# Mega-SDD Canonical Path Convention (v3.4+, Iter 10)

Centralized path definitions for ALL mega-sdd skill outputs. Replaces scattered output locations across iterations with a unified `.mega-sdd/` container at project root.

Per user UX request — "by default semua file output md hasil skill itu masuk saja otomatis ke `.mega-sdd/*`".

## Path resolution algorithm

Every writer skill resolves output paths via this protocol:

1. **Check user override**: `~/.mega-sdd/memory/config.yaml` `default_output_root: <abs-or-rel-path>` (cross-project user preference)
2. **Check project override**: `<project-root>/.mega-sdd/config.yaml` `output_root: <abs-or-rel-path>` (per-repo override)
3. **Default**: `<project-root>/.mega-sdd/` (new in v3.4+)
4. **Legacy detection**: if old-layout paths exist (e.g., `docs/mega-sdd/vaults/`, `.mega-sdd-memory/`, top-level `codebase-map.md`), skills WRITE to legacy paths for back-compat. User opts into new layout via `/mega-sdd:migrate-paths`.

## Canonical layout (v3.4+)

```
<project-root>/
├── .mega-sdd/                                    # ALL mega-sdd outputs (default; configurable)
│   ├── config.yaml                                # Project-level config (output_root, opt-outs)
│   ├── vaults/<slug>/                             # Vault content + per-vault state
│   │   ├── 00-index.md ... 06-constraints.md     # 7-file vault
│   │   ├── vault.json                             # Manifest
│   │   ├── binding.md                             # Binding manifest (after bind-codebase)
│   │   ├── bound/                                 # Bound-vault (after binding clean)
│   │   ├── units/U-*.md, _index.md                # Atomic units
│   │   ├── bolts/U-*/bolt-report.md               # Bolt outcomes
│   │   ├── bolts/U-*/preflight.json, postflight.json  # Hard Rule snapshots
│   │   ├── interfaces/                            # Multi-squad interface notes
│   │   ├── _meta/squads.yaml                      # Multi-squad partition
│   │   ├── .memory/                               # Vault-scope memory (Iter 5)
│   │   │   ├── classifier-accuracy.json
│   │   │   ├── bind-history.md
│   │   │   ├── bolt-outcomes.json
│   │   │   └── citation-failures.jsonl            # Iter 9 audit fix
│   │   └── .internal/                             # Vault-internal state (NEW v3.4+)
│   │       ├── checkpoints/<timestamp>-<skill>-<step>.jsonl   # Iter 6
│   │       └── symbol-graph.json                  # PageRank cache (Iter 6)
│   ├── knowledge-base/                            # Legacy KB extraction (extract-intelligence)
│   │   ├── README.md
│   │   ├── 00-overview/, 10-domains/, etc.
│   │   └── .scan-meta.json
│   ├── codebase/                                  # Codebase analysis outputs
│   │   └── codebase-map.md                        # scan-codebase output
│   ├── memory/                                    # PROJECT-scope memory (Iter 5)
│   │   ├── decisions.md                           # OQ resolutions, CONFLICT actions
│   │   ├── conventions.md                         # Detected conventions
│   │   ├── outcomes.md                            # Pipeline run summaries
│   │   └── archived-vaults/<slug>/                # Vault archive on delete (MEMORY-OQ-5)
│   └── exports/                                   # Tool-agnostic exports
│       └── (additional exports as iters add them)
├── AGENTS.md                                       # Tool-agnostic interop at REPO ROOT (unchanged — must be discoverable by other tools)
├── CLAUDE.md                                       # Project AI context (unchanged)
└── (project source: app/, routes/, src/, etc.)
```

## User-scope (unchanged across iters)

```
~/.mega-sdd/
├── memory/                                  # Cross-project user memory (Iter 5; unchanged)
│   ├── preferences.md
│   ├── patterns.md
│   ├── learning-log.md
│   └── config.yaml                          # User defaults (thresholds, opt-outs, default_output_root override)
└── migrations/<from>-to-<to>.sh              # Memory schema migrations (Iter 9)
```

## Per-skill path mapping (v3.4 default → legacy)

| Skill | Artifact | Default path (v3.4+) | Legacy path (≤v3.3) |
|---|---|---|---|
| `extract-intelligence` | knowledge-base/ | `.mega-sdd/knowledge-base/` | `docs/knowledge-base/` or `<out>/knowledge-base/` |
| `scan-codebase` | codebase-map.md | `.mega-sdd/codebase/codebase-map.md` | `<repo-root>/codebase-map.md` |
| `scan-codebase` | starterkit-context | `.mega-sdd/codebase/starterkit-context.yaml` | `docs/codebase/starterkit-context.yaml` (legacy back-compat probe only) |
| `generate-intent` | vault/ | `.mega-sdd/vaults/<slug>/` | `docs/mega-sdd/vaults/<slug>/` |
| `bind-codebase` | binding.md + bound/ | `<vault>/binding.md` + `<vault>/bound/` | `<vault>/binding.md` + `<vault>-bound/` |
| `generate-units` | units/ | `<vault>/units/` | `<vault>-bound/units/` (or `<vault>/units/`) |
| `execute-bolts` | bolts/ | `<vault>/bolts/U-*/` | `<vault>/bolts/U-*/` |
| `execute-bolts` | checkpoints | `<vault>/.internal/checkpoints/` | `<vault>/.mega-sdd/checkpoints/` |
| `execute-bolts` | symbol-graph | `<vault>/.internal/symbol-graph.json` | `<vault>/.mega-sdd/symbol-graph.json` |
| memory (project) | decisions.md, etc. | `.mega-sdd/memory/` | `.mega-sdd-memory/` |
| `orchestrate-flow` | routing-outcomes | `.mega-sdd/memory/routing-outcomes.md` | (no legacy back-compat — introduced v3.24.0+) |
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

# 3. Default (v3.4+)
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

Same protocol for codebase-map (`<project>/.mega-sdd/codebase/codebase-map.md` → `<project>/codebase-map.md`), KB (`<project>/.mega-sdd/knowledge-base/` → `docs/knowledge-base/` → `old-reference/knowledge-base/`), and project memory (`<project>/.mega-sdd/memory/` → `<project>/.mega-sdd-memory/`).

## Config file format

`<project-root>/.mega-sdd/config.yaml` (NEW in v3.4):

```yaml
# Project-level mega-sdd config
mega_sdd_schema: 1

# Output root override (default: .mega-sdd/ — i.e., this file's parent dir)
output_root: .mega-sdd/    # relative to project root; or absolute

# Layout mode
layout: new                 # new (v3.4+ default) | legacy (preserves pre-v3.4 paths)

# Per-skill opt-outs (per Iter 5+ skill memory opt-out)
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

## Recommended `.gitignore` entries (v3.4+)

For project repo `.gitignore`:

```
# Mega-SDD ephemeral state (per-project decision; uncomment what you want untracked)
# .mega-sdd/memory/outcomes.md          # noisy per-dev run logs
# .mega-sdd/vaults/*/.internal/          # checkpoints + symbol-graph cache
# .mega-sdd/vaults/*/.memory/            # per-vault ephemeral memory
# .mega-sdd/vaults/*/bolts/              # bolt reports (regenerable)
```

Mega-sdd does NOT modify your `.gitignore` automatically. User decides what to track per team norms.

## References

- Iter 5 spec — original memory layer paths (now consolidated)
- Iter 9 audit — Gap E2E-6 (archive scope on vault delete) — fixed in this iter via `.mega-sdd/memory/archived-vaults/`
- `commands/migrate-paths.md` — migration helper
