# Iter 55 — Auto-Install Deps Skill Design

**Status:** Design approved 2026-05-25
**Iter target:** v3.37.0 → v3.38.0 (MINOR — new skill)
**Driver:** user need — manual install of optional native deps (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic) is friction; want plugin to detect OS + auto-install with safety rails
**Spec author:** research → recommendation → user-approved 2026-05-25 (auto mode)

---

## 1. Goal

One sentence: **Add `mega-sdd:install-deps` skill that detects OS + package manager, audits which native deps are missing, proposes batch-install with single explicit confirmation, executes via detected package manager, verifies success, and persists outcomes to memory.**

## 2. Non-Goals

- Windows native PowerShell support without WSL (defer to Iter 56+; Windows users get "open WSL Ubuntu" hint for now)
- Auto-update detection (`brew outdated`) — separate concern, Iter 57+
- Signed-repo bootstrap (Anthropic apt/dnf repos for Claude Code itself) — out of scope; this skill installs OPTIONAL deps mega-sdd uses, not Claude Code itself
- Auto-invocation from orchestrate-flow pipeline — install is user-explicit per safety consensus (predictive-checks just HINT to run the command, don't run it themselves)
- Curl|bash patterns or `sudo` auto-execution — explicitly forbidden by safety rails

## 3. User-facing surfaces

### 3.1 New skill: `mega-sdd:install-deps`

Standalone skill invokable via `/mega-sdd:install-deps [flags]`. Flags:
- `--dry-run` (show commands + sizes; don't execute)
- `--tools=<csv>` (limit to subset, e.g., `--tools=pandoc,tectonic` for FSD-only)
- `--force-recheck` (ignore memory; re-audit every tool from scratch)
- `--pkg-mgr=<name>` (override auto-detected manager; e.g., force `cargo` instead of `brew`)
- `--manual` (print install commands but skip Bash invocation — for users who want to run commands themselves)

### 3.2 New command: `/mega-sdd:install-deps`

Slash command wrapper at `plugins/mega-sdd/commands/install-deps.md` (~30 lines, follows emit-fsd.md pattern).

### 3.3 Predictive-checks hint update

In `orchestrate-flow/references/predictive-checks.md`, existing `on_fail:` messages for tool-presence checks (`tree_sitter_present`, `pandoc_installed`, `pandoc_latex_engine_present`, etc.) get a uniform suffix: `"...OR run /mega-sdd:install-deps for auto-install."` No behavior change — just better discoverability.

## 4. Skill anatomy

```
plugins/mega-sdd/skills/install-deps/
├── SKILL.md                     # main procedure (~200 lines)
└── references/
    ├── os-detection.md          # canonical detection algorithm (Bash one-liners)
    └── tool-matrix.yaml         # (tool, os, pkg_mgr) → install_cmd + verify_cmd + size_estimate
```

Plus:
- `plugins/mega-sdd/commands/install-deps.md` — slash command wrapper

No `_vendored/`, no runtime code — markdown-driven per plugin design principle.

## 5. OS detection algorithm

Canonical Bash detection (stored in `references/os-detection.md`):

```bash
# Step 1: detect OS family
OS=""
OS_VERSION=""
DISTRO=""
case "$OSTYPE" in
  darwin*)
    OS="macos"
    OS_VERSION=$(sw_vers -productVersion)
    ;;
  linux-gnu*|linux*)
    if uname -a 2>/dev/null | grep -qi microsoft; then
      OS="wsl"
    else
      OS="linux"
    fi
    if [ -f /etc/os-release ]; then
      DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
      OS_VERSION=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | tr -d '"')
    fi
    ;;
  msys*|cygwin*)
    OS="windows-bash"
    # native Windows in git-bash / MSYS2 — limited support, Iter 55 best-effort
    ;;
  *)
    OS="unknown"
    ;;
esac

# Step 2: detect package manager (prefer dev-focused)
PKG_MGR="none"
PKG_MGR_VERSION=""
case "$OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      PKG_MGR="brew"
      PKG_MGR_VERSION=$(brew --version | head -1 | awk '{print $2}')
    fi
    ;;
  linux|wsl)
    case "$DISTRO" in
      ubuntu|debian|linuxmint|pop) PKG_MGR="apt" ;;
      fedora|rhel|centos|rocky|alma) PKG_MGR="dnf" ;;
      arch|manjaro|endeavouros) PKG_MGR="pacman" ;;
      alpine) PKG_MGR="apk" ;;
      *) PKG_MGR="cargo-fallback" ;;  # try cargo if available
    esac
    ;;
  windows-bash)
    if command -v winget >/dev/null 2>&1; then
      PKG_MGR="winget"
    elif command -v scoop >/dev/null 2>&1; then
      PKG_MGR="scoop"
    elif command -v choco >/dev/null 2>&1; then
      PKG_MGR="choco"
    fi
    ;;
esac

# Step 3: detect cross-platform fallbacks
FALLBACKS=()
command -v cargo >/dev/null 2>&1 && FALLBACKS+=("cargo")
command -v npm >/dev/null 2>&1 && FALLBACKS+=("npm")
command -v go >/dev/null 2>&1 && FALLBACKS+=("go")
```

## 6. Tool matrix schema

`plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`:

```yaml
# Per-tool: install command + verify command per (os, pkg_mgr) combo.
# Used by emit-deps Step 3 (build install plan) + Step 5 (execute) + Step 6 (verify).

schema_version: "1.0"

tools:
  - id: tree-sitter
    used_by: [scan-codebase]
    purpose: "AST-precise symbol extraction (v2.0+ scan-codebase)"
    fallback_behavior: "Regex engine (lower precision)"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install tree-sitter"
        verify_cmd: "command -v tree-sitter || command -v tree-sitter-cli"
        size_mb: 5
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "sudo apt install -y tree-sitter-cli"
        requires_sudo: true
        verify_cmd: "command -v tree-sitter-cli"
        size_mb: 5
      - os: [linux, wsl]
        pkg_mgr: dnf
        install_cmd: "sudo dnf install -y tree-sitter-cli"
        requires_sudo: true
        verify_cmd: "command -v tree-sitter-cli"
        size_mb: 5
      - os: any
        pkg_mgr: cargo
        install_cmd: "cargo install tree-sitter-cli"
        verify_cmd: "command -v tree-sitter-cli"
        size_mb: 8
        notes: "Cross-platform fallback when no native pkg available"
      - os: any
        pkg_mgr: npm
        install_cmd: "npm install -g tree-sitter-cli"
        verify_cmd: "command -v tree-sitter-cli"
        size_mb: 6

  - id: ast-grep
    used_by: [execute-bolts, generate-units]
    purpose: "Hard Rule v2 grammar (5-10x expressivity vs v1)"
    fallback_behavior: "v1 grammar (5 closed types)"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install ast-grep"
        verify_cmd: "command -v ast-grep"
        size_mb: 8
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "cargo install ast-grep"  # no native apt pkg
        requires_sudo: false
        verify_cmd: "command -v ast-grep"
        size_mb: 12
      - os: any
        pkg_mgr: cargo
        install_cmd: "cargo install ast-grep"
        verify_cmd: "command -v ast-grep"
        size_mb: 12
      - os: any
        pkg_mgr: npm
        install_cmd: "npm install -g @ast-grep/cli"
        verify_cmd: "command -v ast-grep"
        size_mb: 10

  - id: ripgrep
    used_by: [scan-codebase, bind-codebase, detect-drift, lint-units]
    purpose: "Fast structured grep (JSON output)"
    fallback_behavior: "GNU grep (slower; no JSON)"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install ripgrep"
        verify_cmd: "command -v rg"
        size_mb: 3
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "sudo apt install -y ripgrep"
        requires_sudo: true
        verify_cmd: "command -v rg"
        size_mb: 3
      - os: [linux, wsl]
        pkg_mgr: dnf
        install_cmd: "sudo dnf install -y ripgrep"
        requires_sudo: true
        verify_cmd: "command -v rg"
        size_mb: 3
      - os: windows-bash
        pkg_mgr: winget
        install_cmd: "winget install BurntSushi.ripgrep.MSVC"
        verify_cmd: "command -v rg"
        size_mb: 4
      - os: windows-bash
        pkg_mgr: scoop
        install_cmd: "scoop install ripgrep"
        verify_cmd: "command -v rg"
        size_mb: 4
      - os: any
        pkg_mgr: cargo
        install_cmd: "cargo install ripgrep"
        verify_cmd: "command -v rg"
        size_mb: 5

  - id: jd
    used_by: [diff-vault]
    purpose: "Canonical JSON/YAML diff with RFC-6902 patches"
    fallback_behavior: "Manual Read+compare via skill body"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install jd"
        verify_cmd: "command -v jd"
        size_mb: 4
      - os: any
        pkg_mgr: go
        install_cmd: "go install github.com/josephburnett/jd@latest"
        verify_cmd: "command -v jd"
        size_mb: 8

  - id: pandoc
    used_by: [emit-fsd]
    purpose: "FSD PDF rendering (Iter 54)"
    fallback_behavior: "Markdown-only output (no PDF)"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install pandoc"
        verify_cmd: "command -v pandoc"
        size_mb: 20
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "sudo apt install -y pandoc"
        requires_sudo: true
        verify_cmd: "command -v pandoc"
        size_mb: 25
      - os: [linux, wsl]
        pkg_mgr: dnf
        install_cmd: "sudo dnf install -y pandoc"
        requires_sudo: true
        verify_cmd: "command -v pandoc"
        size_mb: 25
      - os: windows-bash
        pkg_mgr: winget
        install_cmd: "winget install JohnMacFarlane.Pandoc"
        verify_cmd: "command -v pandoc"
        size_mb: 30
      - os: windows-bash
        pkg_mgr: scoop
        install_cmd: "scoop install pandoc"
        verify_cmd: "command -v pandoc"
        size_mb: 30

  - id: tectonic
    used_by: [emit-fsd]
    purpose: "LaTeX engine for FSD PDF (lighter alternative to BasicTeX, Iter 54)"
    fallback_behavior: "HTML output (browser print-to-PDF) when neither tectonic nor xelatex available"
    notes: "Recommended over BasicTeX (~2GB) — tectonic is ~50MB self-contained"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install tectonic"
        verify_cmd: "command -v tectonic"
        size_mb: 50
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "cargo install tectonic"  # no native apt pkg in older Ubuntu
        verify_cmd: "command -v tectonic"
        size_mb: 60
      - os: any
        pkg_mgr: cargo
        install_cmd: "cargo install tectonic"
        verify_cmd: "command -v tectonic"
        size_mb: 60

  - id: markdownlint-cli2
    used_by: [lint-units]
    purpose: "Vault prose lint (optional, Iter 14)"
    fallback_behavior: "Skill-internal heuristic checks"
    matrix:
      - os: any
        pkg_mgr: npm
        install_cmd: "npm install -g markdownlint-cli2"
        verify_cmd: "command -v markdownlint-cli2"
        size_mb: 2
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install markdownlint-cli2"
        verify_cmd: "command -v markdownlint-cli2"
        size_mb: 2

  - id: gh
    used_by: [execute-bolts]
    purpose: "GitHub CLI for PR automation (optional)"
    fallback_behavior: "Manual PR creation"
    matrix:
      - os: macos
        pkg_mgr: brew
        install_cmd: "brew install gh"
        verify_cmd: "command -v gh"
        size_mb: 30
      - os: [linux, wsl]
        pkg_mgr: apt
        install_cmd: "sudo apt install -y gh"
        requires_sudo: true
        verify_cmd: "command -v gh"
        size_mb: 30
      - os: windows-bash
        pkg_mgr: winget
        install_cmd: "winget install GitHub.cli"
        verify_cmd: "command -v gh"
        size_mb: 35

# Defaults
defaults:
  required_tools: []                                          # ALL tools optional; mega-sdd has graceful fallback for each
  recommended_minimum: [tree-sitter, ast-grep, ripgrep]        # baseline for brownfield projects
  fsd_extension: [pandoc, tectonic]                            # Iter 54 FSD generation
  full_stack: [tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh]
```

## 7. UX flow

```
/mega-sdd:install-deps

I'm using the install-deps skill to audit + install missing native deps.

Step 1: Detecting environment...
  OS: macOS 14.5 (darwin)
  Package manager: brew v4.5.0
  Fallbacks available: cargo, npm

Step 2: Auditing tool inventory...
  ✓ tree-sitter v0.22.6
  ✗ ast-grep (missing — execute-bolts will fall back to v1 grammar, lower expressivity)
  ✗ ripgrep (missing — scan-codebase falls back to GNU grep, slower)
  ✓ jd v1.8.0
  ✗ pandoc (missing — emit-fsd will emit Markdown only, no PDF)
  ✗ tectonic (missing — emit-fsd will fallback to HTML when LaTeX absent)
  ✓ gh v2.45.0 (optional; PR automation)

Memory check: 0 prior install records for this project (first run).

Step 3: Building install plan...

4 tools to install via brew (total ~78MB download):
  1. ast-grep      8MB    brew install ast-grep
  2. ripgrep       3MB    brew install ripgrep
  3. pandoc        20MB   brew install pandoc
  4. tectonic      50MB   brew install tectonic

Optional add-ons (skipped by default — pick if needed):
  - markdownlint-cli2  2MB   npm install -g markdownlint-cli2

[Install all (4 tools)] [Pick subset] [Cancel]
```

On `[Install all]`:
```
Step 4: Installing (estimated 2-3 min)...
  [1/4] brew install ast-grep        ... ✓ (0:35)
  [2/4] brew install ripgrep         ... ✓ (0:12)
  [3/4] brew install pandoc          ... ✓ (1:05)
  [4/4] brew install tectonic        ... ✓ (1:42)

Step 5: Verifying...
  ✓ ast-grep v0.31.0
  ✓ ripgrep v14.1.0
  ✓ pandoc v3.1.13
  ✓ tectonic v0.15.0

Step 6: Memory write...
  Wrote outcome to <project>/.mega-sdd/memory/install-outcomes.md

✅ All 4 tools installed successfully. mega-sdd full-precision mode enabled.

Re-run check anytime via: /mega-sdd:install-deps --force-recheck
```

On `[Pick subset]`: secondary AskUserQuestion with checkboxes (multiSelect) for which tools to install.

On `[Cancel]`: skill exits with summary of what would have been installed.

## 8. Safety rails (non-negotiable)

1. **NEVER auto-`sudo`** — for tools requiring elevation (apt/dnf), skill PRINTS the command + instructs user to run manually: `"⚠ This package requires root. Run manually: sudo apt install -y ripgrep. Re-run /mega-sdd:install-deps after to verify."` Memory records "sudo-pending" status.
2. **NEVER use curl|bash patterns** — only signed package manager commands per tool-matrix.yaml.
3. **ALWAYS show exact command + source + size BEFORE running** — single batch confirmation (AskUserQuestion).
4. **ALWAYS verify post-install** — `command -v <tool>` after each. On verify fail: halt `install_failed` with `{tool, install_cmd, verify_cmd, exit_code, stderr_tail}`.
5. **Verify pkg manager exists before proposing** — if user has `apt` distro but no `brew`/`cargo` for cargo-fallback tools, gracefully skip + warn.
6. **NEVER install Claude Code itself** — out of scope; this skill only installs OPTIONAL mega-sdd deps.
7. **Memory write happens AFTER verify** — never claim "installed" without verify pass.

## 9. Memory layer integration (Iter 5 pattern)

Writes to `<project>/.mega-sdd/memory/install-outcomes.md` (new memory file):

```markdown
# Install Outcomes — mega-sdd

> Audit log of /mega-sdd:install-deps runs. Schema v1.0. Skip re-audit of installed tools on next run unless --force-recheck.

## Run 2026-05-25T14:32:00Z (OS: macos darwin 14.5, pkg_mgr: brew 4.5.0)

| Tool | Status | Install Command | Verify Result |
|---|---|---|---|
| ast-grep | ✓ installed | brew install ast-grep | v0.31.0 |
| ripgrep | ✓ installed | brew install ripgrep | v14.1.0 |
| pandoc | ✓ installed | brew install pandoc | v3.1.13 |
| tectonic | ✓ installed | brew install tectonic | v0.15.0 |
| markdownlint-cli2 | ⊘ skipped | (user declined) | n/a |
| gh | already-present | (skipped) | v2.45.0 |
```

Skill reads memory on entry — if tool already in "✓ installed" within last 30 days AND `command -v <tool>` still passes, skip re-audit. `--force-recheck` ignores memory entirely.

Memory write happens through standard memory layer (`mega-sdd:memory` skill writes — reuses existing memory file-lock pattern per Iter 49 `memory_in_use` halt).

## 10. Predictive-checks hint update

Existing predictive checks (Iter 33 catalog) get hint suffix appended to `on_fail:` messages where applicable:

| check_id | current on_fail | new on_fail |
|---|---|---|
| `tree_sitter_present` | "tree-sitter not installed; ... Install: brew install ..." | "...OR run `/mega-sdd:install-deps` for auto-install." |
| `pandoc_installed` | "pandoc not installed; ... Install: brew install pandoc ..." | "...OR run `/mega-sdd:install-deps` for auto-install." |
| `pandoc_latex_engine_present` | "no LaTeX engine ... brew install tectonic ..." | "...OR run `/mega-sdd:install-deps` for auto-install." |

No behavior change in predictive-checks logic — just better discoverability. Affects 3 existing checks; future predictive-checks for tools listed in `tool-matrix.yaml` should append the same hint.

## 11. Implementation scope (atomic Iter 55)

**Deliverables (6 files):**

1. **New skill** `plugins/mega-sdd/skills/install-deps/SKILL.md` (~200 lines) — main 6-step procedure
2. **Reference files (2)**:
   - `references/os-detection.md` (Bash detection algorithm)
   - `references/tool-matrix.yaml` (tool × os × pkg_mgr matrix)
3. **New command** `plugins/mega-sdd/commands/install-deps.md` (~30 lines)
4. **Modify predictive-checks.md** — append hint suffix to 3 existing `on_fail:` messages
5. **Plugin version bump** `3.37.0 → 3.38.0` (MINOR — new skill)
6. **CHANGELOG.md** + plugin README + root README — Iter 55 entry + version refs + skill listing

**Total files touched:** 9 (4 new + 5 modified: predictive-checks.md, vault-contract.md halt enum, plugin.json, CHANGELOG, plugin README, root README — root + plugin README both touch version refs so counted once each = 5 modified).

**Reuse-first principle applied:**
- emit-fsd / emit-agents-md skill anatomy (template for new skill)
- Iter 33 predictive-checks pattern (hint extension, no behavior change)
- Iter 5 memory layer pattern (install-outcomes.md memory file)
- Existing `tooling-install.md` matrix (promoted to YAML + extended with pandoc/tectonic)
- AskUserQuestion for batch confirmation (standard Claude Code pattern)
- 2 new halt types added (`install_failed` + `pkg_mgr_not_found`) — both follow existing halt envelope schema; new halts give clearer error path than overloading `quality_gate_failed`. Added to vault-contract.md halt enum (§12 details).

## 12. Halt protocol

emit-fsd-style halts:

- **`install_failed`** (NEW halt type, Iter 55): verify-cmd returned non-zero after install ran. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars)}`. Resolution: user manually runs install, retries.
- **`pkg_mgr_not_found`** (NEW halt type, Iter 55): no compatible package manager detected for OS. Details `{os, distro, attempted_pkg_mgrs}`. Resolution: install brew/cargo/etc first, then retry.
- **`memory_in_use`** (EXISTING from Iter 5/49): install-outcomes.md write conflicts with concurrent memory write. Resolution: retry after backoff.

Add to vault-contract.md `§halt-protocol type enum` (2 new halt types).

## 13. Success criteria

- [ ] `/mega-sdd:install-deps` audits all 8 tools per `tool-matrix.yaml` and identifies missing ones
- [ ] OS detection correctly identifies macOS / Ubuntu / Fedora / Arch / Alpine / WSL / Windows-bash
- [ ] Package manager auto-detect picks brew (mac) / apt (ubuntu) / dnf (fedora) / etc correctly
- [ ] Cross-platform fallbacks (cargo / npm / go) detected and proposed when native pkg mgr lacks tool
- [ ] AskUserQuestion shows tool list + sizes + install commands BEFORE execution
- [ ] `--dry-run` shows plan without executing
- [ ] `--manual` prints commands but skips Bash invocation
- [ ] `--tools=pandoc,tectonic` filters to subset
- [ ] sudo-required tools print command but DON'T auto-execute (user runs manually)
- [ ] Post-install verify catches failures; halts `install_failed` with clear next-step
- [ ] Memory write `install-outcomes.md` records outcomes per tool
- [ ] Re-running skill skips already-installed tools (reads memory + `command -v`)
- [ ] `--force-recheck` ignores memory + re-audits
- [ ] Predictive-checks hint update points users to skill
- [ ] No `sudo` ever auto-executed
- [ ] No curl|bash patterns anywhere

## 14. Out of scope (deferred to future iters)

- **Iter 56+**: Windows native PowerShell variant (winget/scoop without WSL)
- **Iter 57+**: Auto-update detection (`brew outdated` / `apt list --upgradable` → suggest updates)
- **Iter 58+**: Signed Anthropic apt/dnf repo bootstrap for Claude Code itself
- **Iter 59+**: Air-gapped install mode (bundle binaries offline)
- **Iter 60+**: Integration with project lockfile (e.g., `mega-sdd.deps.lock` for reproducible env)

---

**Approval:** user approved 2026-05-25 ("ok approved" after research-driven recommendation).
**Next:** writing-plans skill to produce atomic implementation plan.
