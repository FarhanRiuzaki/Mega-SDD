# Mega-SDD Optional Native Tooling — Install Guide

> **Auto-install:** for OS-aware auto-install with safety rails (detect OS + pkg mgr + propose plan + confirm + verify + memory-cache outcomes), use `/mega-sdd:install-deps` — it consumes the canonical YAML tool-matrix at `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`. This document remains useful as manual reference + fallback when auto-install isn't appropriate.

## Platform support matrix

How much of mega-sdd works per environment (verified 2026-06-11 against the shipped hooks/scripts — all 5 hooks are bash and spawn `python3`; no `.ps1` ports ship yet):

| Environment | Skills & commands | Hooks (gates, journal, staleness) | Scripts/validators | Moat enforcement | Verdict |
|---|---|---|---|---|---|
| **macOS / Linux** | ✅ | ✅ | ✅ | ✅ deterministic | Full support |
| **Windows + WSL** | ✅ | ✅ | ✅ | ✅ deterministic | **Full support — the recommended Windows path** |
| **Windows + Git Bash (MINGW)** | ✅ | ✅ *if a USABLE interpreter resolves* — `resolve-python.sh` walks `python3` → `python` → `py -3` and rejects the WindowsApps alias stub, so no manual shim is needed; do NOT add a `python3` alias by hand | ✅ same condition | ✅ even WITHOUT python3 — the pre-tool-use fail-closed shell fallback still blocks execute-bolts when blockers ≠ PASS | Works; diagnostics degrade without python3 |
| **Windows native (cmd/PowerShell, no bash)** | ⚠️ prose only — the model can follow skills via PowerShell | ❌ hooks are bash (`run-hook.sh` routes to `hooks/<name>.ps1` when present, but no `.ps1` ports ship) | ❌ | ⚠️ **prose-enforced only — no deterministic gate** | Not recommended for real pipelines |

> **Windows hook dispatch requires `bash` resolvable on PATH.** `hooks.json` invokes the dispatcher as `bash run-hook.sh <name>`, so cmd.exe launches `bash.exe` with the script as an argument rather than trying to interpret the file (a `.cmd`-extension dispatcher made cmd parse the `#!` shebang and fail with `'#!' is not recognized as an internal or external command`). On the Git Bash / WSL rows above, "✅ Hooks" therefore assumes Git for Windows (or WSL) is installed and its `bash` wins on PATH.
>
> **It also assumes Claude Code itself is running its Bash tool, not its PowerShell tool.** Claude Code enables the PowerShell tool automatically on Windows when it cannot find Git Bash, and falls back to `powershell.exe`. On a corporate image where PowerShell is blocked by policy, every hook command then dies before `bash` is ever reached — the symptom is `EUNKNOWN: unknown error, uv_spawn` naming `powershell.exe`, which looks like a mega-sdd failure but is not one. Fix it host-side in `~/.claude/settings.json`:
>
> ```jsonc
> { "env": {
>     "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe",
>     "CLAUDE_CODE_USE_POWERSHELL_TOOL": "0"
> } }
> ```
>
> This is a Claude Code setting, not a plugin setting — mega-sdd invokes `bash` explicitly in all 9 `hooks.json` entries and ships no `.ps1`.

`/mega-sdd:install-deps` detects winget/scoop/choco on Windows (best-effort) and apt inside WSL. PowerShell ports of the 5 hooks are a tracked roadmap item — tell us if your team needs native cmd.

Centralized install commands for all native binaries mega-sdd can leverage. **All are OPTIONAL** — mega-sdd has graceful fallbacks for every tool. Install for higher precision + better UX; skip for minimal-footprint setup.

Bundling these binaries in the plugin is impractical (50MB+ multi-platform bloat, license redistribution, maintenance overhead). Install once via your package manager.

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
| `tree-sitter` (or `tree-sitter-cli`) | scan-codebase (AST extraction) | Regex engine (lower precision) | macOS: `brew install tree-sitter-cli` · Linux/win: `cargo install tree-sitter-cli` · Node: `npm install -g tree-sitter-cli` |
| `ast-grep` (alias `sg`) | execute-bolts, generate-units, detect-drift (Hard Rule v2 grammar) | v1-authored rules run natively; units carrying v2 rules need it installed | macOS: `brew install ast-grep` · Linux/win: `cargo install ast-grep` · Node: `npm install -g @ast-grep/cli` |
| `ripgrep` (`rg`) | scan-codebase (structured JSON grep) | GNU grep (slower; no structured JSON) | macOS: `brew install ripgrep` · Linux/win: `cargo install ripgrep` · apt: `apt install ripgrep` |
| `jd` | diff-vault, replay (canonical JSON/YAML diff with patches) | Manual diff via Read+compare | macOS: `brew install jd` · Linux/win: `go install github.com/josephburnett/jd/v2/jd@latest` |
| `pandoc` | emit-fsd/prd/sit/uat (md2pdf HTML render for the PDF lanes) | Markdown-only output (no PDF) | macOS: `brew install pandoc` · apt: `apt install pandoc` · win: `winget install JohnMacFarlane.Pandoc` |
| `mmdc` (`@mermaid-js/mermaid-cli`) | emit-fsd/prd/sit/uat (pre-render mermaid to SVG for the PDF lane) | mermaid stays a code block (quality drop) | `npm install -g @mermaid-js/mermaid-cli` (all platforms) |
| `markdownlint-cli2` | lint-units (vault prose quality) | Skill-internal heuristic checks | `npm install -g markdownlint-cli2` · macOS: `brew install markdownlint-cli2` |
| `semgrep` | execute-bolts L0 code gates (SAST on bolt diffs) | SAST gate SKIPs with a visible note | macOS: `brew install semgrep` · any: `pipx install semgrep` |
| `gitleaks` | execute-bolts L0 code gates (secret scan on bolt diffs) | Plugin regex fallback (reduced coverage; always scanned) | macOS: `brew install gitleaks` · win: `scoop install gitleaks` · any: `go install github.com/zricethezav/gitleaks/v8@latest` |
| `superpowers` plugin | execute-bolts (TDD bridge) | Vendored fallback at `plugins/mega-sdd/skills/_vendored/` | `/plugin install superpowers` |

> `pandoc` + `mmdc` power the emit PDF lanes; the PDF printer is a detected Chrome/Chromium (GUI app, detect-only — never installed by mega-sdd). Absent Chrome → GitHub-styled HTML fallback.

## One-command install (recommended setup)

If you have **Homebrew** (macOS / Linux):

```bash
brew install tree-sitter-cli ast-grep ripgrep jd
npm install -g markdownlint-cli2     # optional; vault prose lint
```

If you have **cargo** (cross-platform Rust):

```bash
cargo install tree-sitter-cli ast-grep ripgrep
go install github.com/josephburnett/jd/v2/jd@latest
npm install -g markdownlint-cli2
```

If you have **npm** only:

```bash
npm install -g tree-sitter-cli @ast-grep/cli markdownlint-cli2
# ripgrep + jd: install via system package manager (apt/brew/scoop/etc)
```

If you are on **Windows** (git-bash / MSYS2):

`tree-sitter`, `ast-grep`, `jd`, `ripgrep`, and `pandoc` all have both winget and Scoop packages. Note `jd` lives in the Scoop **`extras`** bucket (not Main), so add that bucket first.

```powershell
# Scoop (jd is in the 'extras' bucket, not Main):
scoop install tree-sitter ast-grep ripgrep pandoc
scoop bucket add extras && scoop install jd
npm install -g @mermaid-js/mermaid-cli    # mermaid render for the PDF lane
npm install -g markdownlint-cli2          # optional; vault prose lint

# winget (covers all five native tools):
winget install BurntSushi.ripgrep.MSVC JohnMacFarlane.Pandoc
winget install tree-sitter.tree-sitter-cli ast-grep.ast-grep josephburnett.jd

# or the cross-platform runtime fallbacks:
cargo install tree-sitter-cli ast-grep   # if Rust present
npm install -g tree-sitter-cli @ast-grep/cli      # if Node present
go install github.com/josephburnett/jd/v2/jd@latest   # if Go present
```

`/mega-sdd:install-deps` automates this: on a winget-primary box it also uses Scoop as a fallback when present, and for any tool it can't reach it prints the concrete remedy (install Scoop, or a runtime) instead of silently skipping.

## Verify install

```bash
command -v tree-sitter || command -v tree-sitter-cli && echo "✓ tree-sitter ready"
command -v ast-grep && echo "✓ ast-grep ready"
command -v rg && echo "✓ ripgrep ready"
command -v jd && echo "✓ jd ready"
command -v pandoc && echo "✓ pandoc ready"
command -v mmdc && echo "✓ mmdc ready"
command -v markdownlint-cli2 && echo "✓ markdownlint-cli2 ready"
command -v semgrep && echo "✓ semgrep ready"
command -v gitleaks && echo "✓ gitleaks ready"
```

## Minimal-footprint setup (skip everything optional)

Mega-sdd works WITHOUT any of these. You get:
- scan-codebase: regex engine (precision_tier: regex; documented in codebase-map.md frontmatter)
- execute-bolts: Hard Rule v1 grammar (5 closed types)
- diff-vault: skill-internal compare
- lint-units: internal heuristic checks

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
brew upgrade tree-sitter-cli ast-grep ripgrep jd pandoc semgrep gitleaks
npm update -g @mermaid-js/mermaid-cli markdownlint-cli2
```

Mega-sdd is tested against versions pinned in `plugins/mega-sdd/skills/scan-codebase/queries/VERSIONS.md` (tree-sitter grammars). Major version drift may produce warnings; minor versions typically compatible.

## References

- `plugins/mega-sdd/skills/scan-codebase/queries/VERSIONS.md` — tree-sitter grammar version matrix
- Tool-adoption history and rationale: `CHANGELOG.md` + git log
