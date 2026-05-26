# Mega-SDD Optional Native Tooling — Install Guide

> **v1.0.0+ Iter 55 update (documented Iter 61 per B-P3-1):** for OS-aware auto-install with safety rails (detect OS + pkg mgr + propose plan + confirm + verify + memory-cache outcomes), use `/mega-sdd:install-deps` — it consumes the canonical YAML tool-matrix at `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`. This document remains useful as manual reference + fallback when auto-install isn't appropriate.

Centralized install commands for all native binaries mega-sdd can leverage. **All are OPTIONAL** — mega-sdd has graceful fallbacks for every tool. Install for higher precision + better UX; skip for minimal-footprint setup.

Per Iter 14 audit (`docs/superpowers/audits/2026-05-21-command-sprawl-audit-v3.6.md` + research): bundling these binaries in the plugin is impractical (50MB+ multi-platform bloat, license redistribution, maintenance overhead). Install once via your package manager.

## Tool matrix

| Tool | Used by | Fallback if absent | Install |
|---|---|---|---|
| `tree-sitter` (or `tree-sitter-cli`) | scan-codebase v2.0+ (AST extraction) | Regex engine (lower precision) | macOS: `brew install tree-sitter` · Linux/win: `cargo install tree-sitter-cli` · Node: `npm install -g tree-sitter-cli` |
| `ast-grep` (alias `sg`) | execute-bolts v2.0+ (Hard Rule v2 grammar) | v1 grammar (5 types only) | macOS: `brew install ast-grep` · Linux/win: `cargo install ast-grep` · Node: `npm install -g @ast-grep/cli` |
| `ripgrep` (`rg`) | scan-codebase + detect-drift + bind-codebase + lint-units (v14.0+) | GNU grep (slower; no structured JSON) | macOS: `brew install ripgrep` · Linux/win: `cargo install ripgrep` · apt: `apt install ripgrep` |
| `jd` | diff-vault v1.1+ (canonical JSON/YAML diff with patches) | Manual diff via Read+compare | macOS: `brew install jd` · Linux/win: `go install github.com/josephburnett/jd@latest` |
| `markdownlint-cli2` | lint-units (Iter 14+; vault prose quality) | Skill-internal heuristic checks | `npm install -g markdownlint-cli2` · macOS: `brew install markdownlint-cli2` |
| `gh` (GitHub CLI) | execute-bolts post-bolt PR pattern (optional) | Manual PR creation by user | macOS: `brew install gh` · Linux: package manager · win: `scoop install gh` |
| `superpowers` plugin | execute-bolts (TDD bridge) | Vendored fallback at `plugins/mega-sdd/skills/_vendored/` | `/plugin install superpowers` |

## One-command install (recommended setup)

If you have **Homebrew** (macOS / Linux):

```bash
brew install tree-sitter ast-grep ripgrep jd
npm install -g markdownlint-cli2     # optional; vault prose lint
brew install gh                       # optional; PR automation
```

If you have **cargo** (cross-platform Rust):

```bash
cargo install tree-sitter-cli ast-grep ripgrep
go install github.com/josephburnett/jd@latest
npm install -g markdownlint-cli2
```

If you have **npm** only:

```bash
npm install -g tree-sitter-cli @ast-grep/cli markdownlint-cli2
# ripgrep + jd + gh: install via system package manager (apt/brew/scoop/etc)
```

If you have **Scoop** (Windows):

```powershell
scoop install tree-sitter ast-grep ripgrep gh
# jd: go install
# markdownlint-cli2: npm install
```

## Verify install

```bash
command -v tree-sitter || command -v tree-sitter-cli && echo "✓ tree-sitter ready"
command -v ast-grep && echo "✓ ast-grep ready"
command -v rg && echo "✓ ripgrep ready"
command -v jd && echo "✓ jd ready"
command -v markdownlint-cli2 && echo "✓ markdownlint-cli2 ready"
command -v gh && echo "✓ gh ready"
```

## Minimal-footprint setup (skip everything optional)

Mega-sdd works WITHOUT any of these. You get:
- scan-codebase: regex engine (precision_tier: regex; documented in codebase-map.md frontmatter)
- execute-bolts: Hard Rule v1 grammar (5 closed types)
- diff-vault: skill-internal compare
- lint-units: internal heuristic checks
- No PR automation

For first-time exploration or one-off projects, minimal setup is fine. For sustained brownfield work or multi-project use, recommend installing at least `tree-sitter` + `ast-grep` + `ripgrep`.

## License notes

All recommended tools are MIT or Apache-2.0 licensed. Mega-sdd does NOT redistribute them; users install via their preferred package manager. Tool authors retain copyright; see each tool's repo for license details.

## Troubleshooting

### "tree-sitter command not found" after brew install

macOS may have stale shell PATH. Try:

```bash
hash -r          # clear shell command cache
which tree-sitter   # verify path
# Or restart shell session
```

### `npm install -g` permission denied on Linux

Either fix npm prefix (`npm config set prefix ~/.npm-global`) or use `sudo`. Better: use Volta or nvm for managed Node.

### ast-grep binary name conflict

If you have `ast-grep` AND `sg` aliases conflicting (sg is the short form), mega-sdd uses full name `ast-grep` exclusively. Set `alias sg=ast-grep` if you want both.

### Updating tools

```bash
brew upgrade tree-sitter ast-grep ripgrep jd
npm update -g markdownlint-cli2
```

Mega-sdd is tested against versions pinned in `plugins/mega-sdd/skills/scan-codebase/queries/VERSIONS.md` (tree-sitter grammars). Major version drift may produce warnings; minor versions typically compatible.

## References

- Iter 6 spec — tree-sitter + ast-grep adoption
- Iter 14 audit (research-driven adoptions: ripgrep + jd + markdownlint-cli2)
- `plugins/mega-sdd/skills/scan-codebase/queries/VERSIONS.md` — tree-sitter grammar version matrix
