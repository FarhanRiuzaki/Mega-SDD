# Mega-SDD Optional Native Tooling — Install Guide

> **v1.0.0+ Iter 55 update (documented Iter 61 per B-P3-1):** for OS-aware auto-install with safety rails (detect OS + pkg mgr + propose plan + confirm + verify + memory-cache outcomes), use `/mega-sdd:install-deps` — it consumes the canonical YAML tool-matrix at `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`. This document remains useful as manual reference + fallback when auto-install isn't appropriate.

## Platform support matrix

How much of mega-sdd works per environment (verified 2026-06-11 against the shipped hooks/scripts — all 5 hooks are bash and spawn `python3`; no `.ps1` ports ship yet):

| Environment | Skills & commands | Hooks (gates, journal, staleness) | Scripts/validators | Moat enforcement | Verdict |
|---|---|---|---|---|---|
| **macOS / Linux** | ✅ | ✅ | ✅ | ✅ deterministic | Full support |
| **Windows + WSL** | ✅ | ✅ | ✅ | ✅ deterministic | **Full support — the recommended Windows path** |
| **Windows + Git Bash (MINGW)** | ✅ | ✅ *if `python3` on PATH* (Windows Python is usually `python`/`py` — add a `python3` alias/shim) | ✅ same condition | ✅ even WITHOUT python3 — the pre-tool-use fail-closed shell fallback still blocks execute-bolts when blockers ≠ PASS | Works; diagnostics degrade without python3 |
| **Windows native (cmd/PowerShell, no bash)** | ⚠️ prose only — the model can follow skills via PowerShell | ❌ hooks are bash (`run-hook.sh` routes to `hooks/<name>.ps1` when present, but no `.ps1` ports ship) | ❌ | ⚠️ **prose-enforced only — no deterministic gate** | Not recommended for real pipelines |

> **Windows hook dispatch requires `bash` resolvable on PATH.** `hooks.json` invokes the dispatcher as `bash run-hook.sh <name>`, so cmd.exe launches `bash.exe` with the script as an argument rather than trying to interpret the file (a `.cmd`-extension dispatcher made cmd parse the `#!` shebang and fail with `'#!' is not recognized as an internal or external command`). On the Git Bash / WSL rows above, "✅ Hooks" therefore assumes Git for Windows (or WSL) is installed and its `bash` wins on PATH.

`/mega-sdd:install-deps` detects winget/scoop/choco on Windows (best-effort) and apt inside WSL. PowerShell ports of the 5 hooks are a tracked roadmap item — tell us if your team needs native cmd.

Centralized install commands for all native binaries mega-sdd can leverage. **All are OPTIONAL** — mega-sdd has graceful fallbacks for every tool. Install for higher precision + better UX; skip for minimal-footprint setup.

Per Iter 14 audit (`docs/superpowers/audits/2026-05-21-command-sprawl-audit-v3.6.md` + research): bundling these binaries in the plugin is impractical (50MB+ multi-platform bloat, license redistribution, maintenance overhead). Install once via your package manager.

## Contents

- Tool matrix
- One-command install (recommended setup)
- Verify install
- Minimal-footprint setup (skip everything optional)
- License notes
- Troubleshooting
- References

## Tool matrix

| Tool | Used by | Fallback if absent | Install |
|---|---|---|---|
| `tree-sitter` (or `tree-sitter-cli`) | scan-codebase v2.0+ (AST extraction) | Regex engine (lower precision) | macOS: `brew install tree-sitter` · Linux/win: `cargo install tree-sitter-cli` · Node: `npm install -g tree-sitter-cli` |
| `ast-grep` (alias `sg`) | execute-bolts v2.0+ (Hard Rule v2 grammar) | v1 grammar (5 types only) | macOS: `brew install ast-grep` · Linux/win: `cargo install ast-grep` · Node: `npm install -g @ast-grep/cli` |
| `ripgrep` (`rg`) | scan-codebase + detect-drift + bind-codebase + lint-units (v14.0+) | GNU grep (slower; no structured JSON) | macOS: `brew install ripgrep` · Linux/win: `cargo install ripgrep` · apt: `apt install ripgrep` |
| `jd` | diff-vault v1.1+ (canonical JSON/YAML diff with patches) | Manual diff via Read+compare | macOS: `brew install jd` · Linux/win: `go install github.com/josephburnett/jd@latest` |
| `markdownlint-cli2` | lint-units (Iter 14+; vault prose quality) | Skill-internal heuristic checks | `npm install -g markdownlint-cli2` · macOS: `brew install markdownlint-cli2` |
| `gh` (GitHub CLI) | execute-bolts post-bolt PR pattern (optional) | Manual PR creation by user | macOS: `brew install gh` · Linux: package manager · win: `scoop install gh` |
| `semgrep` | execute-bolts L0 code gates (SAST on bolt diffs) | SAST gate SKIPs with a visible note | macOS: `brew install semgrep` · any: `pipx install semgrep` |
| `gitleaks` | execute-bolts L0 code gates (secret scan on bolt diffs) | Plugin regex fallback (reduced coverage; always scanned) | macOS: `brew install gitleaks` · win: `scoop install gitleaks` · any: `go install github.com/zricethezav/gitleaks/v8@latest` |
| `osv-scanner` | execute-bolts L0 code gates (known-CVE lockfile audit, advisory) | Ecosystem-native audit (npm/pip/cargo/composer audit) or skipped | macOS: `brew install osv-scanner` · any: `go install github.com/google/osv-scanner/cmd/osv-scanner@v1` |
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

If you are on **Windows** (git-bash / MSYS2):

`tree-sitter`, `ast-grep`, `tectonic`, and `jd` have **no winget package** — their native Windows source is **Scoop**. `ripgrep`, `pandoc`, and `gh` install via either winget or scoop.

```powershell
# Scoop (covers every tool natively — recommended on Windows):
scoop install tree-sitter ast-grep ripgrep jd pandoc tectonic gh
npm install -g markdownlint-cli2          # optional; vault prose lint

# winget (covers ripgrep / pandoc / gh only):
winget install BurntSushi.ripgrep.MSVC JohnMacFarlane.Pandoc GitHub.cli
# tree-sitter / ast-grep / tectonic / jd: use scoop above, or the cargo/npm/go fallback:
cargo install tree-sitter-cli ast-grep tectonic   # if Rust present
npm install -g tree-sitter-cli @ast-grep/cli      # if Node present
go install github.com/josephburnett/jd@latest     # if Go present
```

`/mega-sdd:install-deps` automates this: on a winget-primary box it also uses Scoop as a fallback when present, and for any tool it can't reach it prints the concrete remedy (install Scoop, or a runtime) instead of silently skipping.

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
