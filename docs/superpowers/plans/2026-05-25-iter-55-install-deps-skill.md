# Iter 55 Install-Deps Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `mega-sdd:install-deps` skill that detects OS + package manager, audits which native deps are missing, proposes batch-install with single explicit confirmation, executes via detected package manager, verifies success, and persists outcomes to memory.

**Architecture:** New markdown-driven skill following `emit-fsd` anatomy (SKILL.md + 2 reference files + slash command); OS detection via canonical Bash patterns; tool-matrix.yaml encodes (tool × OS × pkg_mgr) → install/verify commands for 8 tools; 6-step procedure (detect → audit → propose → confirm → install → verify); safety rails (no auto-sudo, no curl|bash, mandatory verify, memory write only after pass).

**Tech Stack:** Markdown (skill body + references), YAML (tool matrix), Bash (OS detection + install execution), JSON (memory outcomes).

**Spec source:** `docs/superpowers/specs/2026-05-25-iter-55-install-deps-skill-design.md`

**Versions:** Plugin `3.37.0 → 3.38.0` (MINOR — new skill); new skill `install-deps 1.0.0`.

---

## File Structure (responsibility map)

**Create (4 files):**

| File | Responsibility |
|---|---|
| `plugins/mega-sdd/skills/install-deps/SKILL.md` | Main 6-step procedure: OS detect, tool audit, install plan, confirm, execute, verify, memory write |
| `plugins/mega-sdd/skills/install-deps/references/os-detection.md` | Canonical Bash detection algorithm (mac/linux/wsl/windows-bash + pkg manager + fallbacks) |
| `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml` | 8-tool matrix: (tool × OS × pkg_mgr) → install_cmd + verify_cmd + size_mb + requires_sudo |
| `plugins/mega-sdd/commands/install-deps.md` | Slash command wrapper (~30 lines, follows emit-fsd.md pattern) |

**Modify (5 files):**

| File | Change |
|---|---|
| `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md` | Append hint suffix to 3 existing `on_fail:` messages (tree_sitter_present, pandoc_installed, pandoc_latex_engine_present) |
| `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md` | + 2 new halt types in §halt-protocol type enum (`install_failed`, `pkg_mgr_not_found`) |
| `plugins/mega-sdd/.claude-plugin/plugin.json` | version 3.37.0 → 3.38.0 |
| `CHANGELOG.md` | + [3.38.0] Iter 55 entry |
| `plugins/mega-sdd/README.md` | + v3.38.0 What's new entry; folder layout +1 line for install-deps skill; skill count 14 → 15; command count 21 → 22 |
| `README.md` | + 2 occurrences "14 skills + 21 slash commands" → "15 skills + 22 slash commands"; + install-deps in skill listing + cheat-sheet + commands table |

---

## Task 1: Scaffold install-deps skill skeleton

**Files:**
- Create: `plugins/mega-sdd/skills/install-deps/SKILL.md`
- Create: `plugins/mega-sdd/skills/install-deps/references/` (directory)

- [ ] **Step 1.1: Create skill scaffold with frontmatter + section anchors**

Create `plugins/mega-sdd/skills/install-deps/SKILL.md`:

```markdown
---
name: install-deps
version: 1.0.0
description: Auto-detect OS + package manager (brew/apt/dnf/pacman/apk/winget/scoop/cargo/npm/go) and install missing native deps mega-sdd can leverage (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh). Single explicit batch confirmation; never auto-sudo; never curl|bash; mandatory post-install verify; memory-cached outcomes. Triggers — "install deps", "auto install", "install tools", "install pandoc", "pasang tools", "auto install deps", or paraphrases.
---

# Install-Deps — OS-Aware Dependency Installer

**Announce at start:** "I'm using the install-deps skill to audit + install missing native deps."

## When to use

- "install deps" / "auto install" / "install tools" / "pasang tools"
- After fresh mega-sdd install — bootstrap optional native binaries
- After predictive-checks warn (e.g., `pandoc_installed: warn` from emit-fsd predictive checks)
- After Iter 54 emit-fsd ship — pandoc + tectonic needed for FSD PDF
- Cross-machine re-sync (memory layer skips already-installed tools)

## Inputs

- `--dry-run` (show install plan; don't execute)
- `--tools=<csv>` (limit to subset, e.g., `--tools=pandoc,tectonic` for FSD-only)
- `--force-recheck` (ignore memory; re-audit every tool from scratch)
- `--pkg-mgr=<name>` (override auto-detected manager; e.g., force `cargo` instead of `brew`)
- `--manual` (print install commands but skip Bash invocation — user runs commands themselves)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per orchestrate-flow handoff-contract)

## Outputs

```
<project>/.mega-sdd/memory/install-outcomes.md   # memory log of install runs
```

Plus chat-only output: detected OS, tool inventory, install plan, per-tool verify result.

## Pre-flight checks

1. **pkg_mgr_detected**: at least one of (brew | apt | dnf | pacman | apk | winget | scoop | cargo | npm | go) is on PATH
   - If none → halt `pkg_mgr_not_found`
2. **memory_writable**: `<project>/.mega-sdd/memory/` exists and writable (or can be created)

## Procedure

(filled in Task 4 — see plan)

## Halt protocol

(filled in Task 4)

## Handoff emission (v1.0.0+, Iter 55)

(filled in Task 4)
```

- [ ] **Step 1.2: Create references directory**

Run: `mkdir -p plugins/mega-sdd/skills/install-deps/references`
Expected: no output (idempotent)

- [ ] **Step 1.3: Verify scaffold**

Run: `ls plugins/mega-sdd/skills/install-deps/`
Expected: `SKILL.md  references/`

Run: `grep -c "filled in" plugins/mega-sdd/skills/install-deps/SKILL.md`
Expected: 3 (Procedure, Halt protocol, Handoff emission)

- [ ] **Step 1.4: Commit scaffold**

```bash
git add plugins/mega-sdd/skills/install-deps/SKILL.md
git commit -m "scaffold(iter-55): install-deps skill skeleton

Frontmatter + section anchors per emit-fsd anatomy. Procedure body filled
in Task 4 per docs/superpowers/plans/2026-05-25-iter-55-install-deps-skill.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Write tool-matrix.yaml (8 tools × OS × pkg_mgr)

**Files:**
- Create: `plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`

- [ ] **Step 2.1: Create tool-matrix.yaml**

Create file with the full 8-tool matrix from spec §6 verbatim. The file content is exactly the YAML block in `docs/superpowers/specs/2026-05-25-iter-55-install-deps-skill-design.md §6 Tool matrix schema` (the entire YAML starting with `schema_version: "1.0"` through the `defaults:` block at end).

The matrix covers 8 tools (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh) across pkg managers (brew, apt, dnf, winget, scoop, cargo, npm, go) with `install_cmd`, `verify_cmd`, `size_mb`, `requires_sudo`, and per-os `notes`.

- [ ] **Step 2.2: Validate YAML structure**

Run: `python3 -c "
content = open('plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml').read()
assert '\t' not in content, 'tabs in YAML'
assert content.count('id: ') == 8, f'expected 8 tools, got {content.count(\"id: \")}'
assert 'schema_version' in content
print('✓ tool-matrix.yaml: 8 tools, no tabs, schema_version present')
"`
Expected: `✓ tool-matrix.yaml: 8 tools, no tabs, schema_version present`

- [ ] **Step 2.3: Commit tool matrix**

```bash
git add plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml
git commit -m "feat(iter-55): install-deps tool-matrix.yaml — 8 tools × OS × pkg_mgr

Tools: tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh.
Pkg managers: brew (mac), apt (debian/ubuntu), dnf (fedora/rhel), winget/scoop
(windows), cargo/npm/go (cross-platform fallbacks).

Schema v1.0: per (tool, os, pkg_mgr) tuple, captures install_cmd + verify_cmd +
size_mb + requires_sudo + notes. Defaults block: required_tools (none),
recommended_minimum (tree-sitter/ast-grep/ripgrep), fsd_extension (pandoc/tectonic).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Write os-detection.md (canonical Bash detection algorithm)

**Files:**
- Create: `plugins/mega-sdd/skills/install-deps/references/os-detection.md`

- [ ] **Step 3.1: Create os-detection.md**

Create `plugins/mega-sdd/skills/install-deps/references/os-detection.md`:

````markdown
# OS Detection — Canonical Bash Algorithm

> Consumed by `install-deps/SKILL.md` Step 1 (Detect environment).
> Cross-platform Bash patterns: macOS / Linux (Ubuntu/Debian/Fedora/Arch/Alpine) / WSL / Windows-bash (git-bash / MSYS2).

## Detection algorithm (canonical)

```bash
# === Step 1: Detect OS family ===
OS=""
OS_VERSION=""
DISTRO=""

case "$OSTYPE" in
  darwin*)
    OS="macos"
    OS_VERSION=$(sw_vers -productVersion 2>/dev/null)
    ;;
  linux-gnu*|linux*)
    if uname -a 2>/dev/null | grep -qi microsoft; then
      OS="wsl"
    else
      OS="linux"
    fi
    if [ -f /etc/os-release ]; then
      DISTRO=$(awk -F= '/^ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"')
      OS_VERSION=$(awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"')
    fi
    ;;
  msys*|cygwin*)
    OS="windows-bash"
    OS_VERSION=$(uname -r 2>/dev/null)
    ;;
  *)
    OS="unknown"
    ;;
esac

# === Step 2: Detect primary package manager ===
PKG_MGR="none"
PKG_MGR_VERSION=""

case "$OS" in
  macos)
    if command -v brew >/dev/null 2>&1; then
      PKG_MGR="brew"
      PKG_MGR_VERSION=$(brew --version 2>/dev/null | head -1 | awk '{print $2}')
    fi
    ;;
  linux|wsl)
    case "$DISTRO" in
      ubuntu|debian|linuxmint|pop|elementary)
        if command -v apt >/dev/null 2>&1; then
          PKG_MGR="apt"
          PKG_MGR_VERSION=$(apt --version 2>/dev/null | awk '{print $2}')
        fi
        ;;
      fedora|rhel|centos|rocky|alma|amzn)
        if command -v dnf >/dev/null 2>&1; then
          PKG_MGR="dnf"
        elif command -v yum >/dev/null 2>&1; then
          PKG_MGR="yum"   # legacy fallback
        fi
        ;;
      arch|manjaro|endeavouros|garuda)
        command -v pacman >/dev/null 2>&1 && PKG_MGR="pacman"
        ;;
      alpine)
        command -v apk >/dev/null 2>&1 && PKG_MGR="apk"
        ;;
      *)
        PKG_MGR="cargo-fallback"   # unknown distro; try cargo if available
        ;;
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

# === Step 3: Detect cross-platform fallback managers ===
FALLBACKS=""
command -v cargo >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}cargo "
command -v npm >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}npm "
command -v go >/dev/null 2>&1 && FALLBACKS="${FALLBACKS}go "
FALLBACKS=$(echo "$FALLBACKS" | sed 's/ $//')   # trim trailing space

# === Output (consumed by install-deps SKILL.md Step 1) ===
echo "OS: $OS $OS_VERSION ($DISTRO)"
echo "PKG_MGR: $PKG_MGR $PKG_MGR_VERSION"
echo "FALLBACKS: $FALLBACKS"
```

## Detection outcome table

| OSTYPE pattern | OS | Distro examples | Primary PKG_MGR |
|---|---|---|---|
| `darwin*` | `macos` | n/a | `brew` (or `none` if absent) |
| `linux-gnu*` (no microsoft) | `linux` | ubuntu, debian, fedora, arch, alpine | `apt` / `dnf` / `pacman` / `apk` / `cargo-fallback` |
| `linux-gnu*` (microsoft) | `wsl` | usually ubuntu | `apt` (most common in WSL) |
| `msys*` / `cygwin*` | `windows-bash` | git-bash / MSYS2 | `winget` / `scoop` / `choco` / `none` |
| unknown | `unknown` | — | `none` (halt `pkg_mgr_not_found`) |

## Special-case notes

- **macOS without brew**: PKG_MGR = `none` initially; install-deps proposes installing brew first via official Apple-pkg-manager-friendly method (Homebrew's own `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` is FORBIDDEN per safety rails — instead, point user to https://brew.sh and instruct manual install)
- **WSL Ubuntu without `apt`**: extremely rare; happens in chroot/container envs. Halt `pkg_mgr_not_found` with hint to install apt.
- **Windows native (no WSL, no git-bash)**: out of scope for Iter 55 — user instructed to install WSL Ubuntu and re-run.
- **Alpine `apk`**: most mega-sdd deps (pandoc, tree-sitter) NOT available in default `apk` repos. Cross-platform cargo fallback used heavily on Alpine.

## Fallback chain

When primary PKG_MGR lacks a tool (per `tool-matrix.yaml`), install-deps Step 3 tries fallback managers in this order:

1. `cargo` (Rust-based: tree-sitter-cli, ast-grep, ripgrep, tectonic)
2. `npm` (Node-based: markdownlint-cli2, tree-sitter-cli, @ast-grep/cli)
3. `go install` (Go-based: jd)

If a tool has no matching `(tool, os, pkg_mgr)` entry AND no fallback works, mark tool as `unsupported` in install plan + skip with warning (don't halt — graceful degradation).

## Cross-reference

- `tool-matrix.yaml` — encodes which install_cmd to use per detected (OS, PKG_MGR) tuple
- `SKILL.md` §Procedure Step 1 — invokes this algorithm
- `SKILL.md` §Halt protocol — `pkg_mgr_not_found` halt fires when PKG_MGR = `none` AND no fallbacks
````

- [ ] **Step 3.2: Verify file structure**

Run: `wc -l plugins/mega-sdd/skills/install-deps/references/os-detection.md`
Expected: 110-130 lines

Run: `grep -c "^## \|^### " plugins/mega-sdd/skills/install-deps/references/os-detection.md`
Expected: ≥ 5 (sections present)

- [ ] **Step 3.3: Commit os-detection**

```bash
git add plugins/mega-sdd/skills/install-deps/references/os-detection.md
git commit -m "feat(iter-55): install-deps os-detection.md canonical Bash algorithm

3-step detection: OS family (mac/linux/wsl/windows-bash via OSTYPE +
/etc/os-release for linux distro) → primary pkg manager (brew/apt/dnf/pacman/
apk/winget/scoop) → cross-platform fallbacks (cargo/npm/go).

Outcome table + special-case notes (macOS without brew, WSL edge cases, Alpine
apk gaps, Windows native out-of-scope).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Fill SKILL.md main procedure body

**Files:**
- Modify: `plugins/mega-sdd/skills/install-deps/SKILL.md` (replace 3 placeholder sections)

- [ ] **Step 4.1: Read SKILL.md to find placeholders**

Run: `grep -n "filled in Task" plugins/mega-sdd/skills/install-deps/SKILL.md`
Expected: 3 matches (Procedure, Halt protocol, Handoff emission)

- [ ] **Step 4.2: Replace placeholder sections with full procedure**

Replace the placeholder block:

```markdown
## Procedure

(filled in Task 4 — see plan)

## Halt protocol

(filled in Task 4)

## Handoff emission (v1.0.0+, Iter 55)

(filled in Task 4)
```

With:

````markdown
## Procedure

### Step 1: Detect environment

Run the canonical detection algorithm per `references/os-detection.md`. Emit chat output:

```
Step 1: Detecting environment...
  OS: <macos|linux|wsl|windows-bash> <version> [<distro>]
  Package manager: <brew|apt|dnf|...> [v<version>]
  Fallbacks available: <cargo|npm|go>
```

If detection yields `OS = unknown` OR `PKG_MGR = none` AND no fallbacks → emit halt `pkg_mgr_not_found` with details `{os, distro, attempted_pkg_mgrs}`; STOP.

### Step 2: Audit tool inventory

Read `references/tool-matrix.yaml`. For each tool:

1. Check memory file `<project>/.mega-sdd/memory/install-outcomes.md` (if exists) for prior install entry within last 30 days.
2. If memory says "installed" AND `command -v <tool>` (or alternate per matrix `verify_cmd`) passes → mark `cached-installed`; skip audit.
3. Otherwise, run `verify_cmd` from matrix entry matching detected (OS, PKG_MGR):
   - Exit 0 → mark `present` (already installed); capture version via tool's `--version` if available
   - Exit non-zero → mark `missing`

`--force-recheck` flag skips memory cache; re-audits every tool.

Emit chat output:

```
Step 2: Auditing tool inventory...
  ✓ <tool> <version>             # present
  ⊘ <tool>                       # cached-installed (skipped audit)
  ✗ <tool> (missing — <fallback_behavior>)
```

### Step 3: Build install plan

For each `missing` tool:

1. Look up matrix entry matching detected (OS, PKG_MGR).
2. If entry exists with `install_cmd` → add to install plan.
3. If no matching entry → try fallback managers (cargo / npm / go) per `os-detection.md §Fallback chain`.
4. If `--pkg-mgr=<name>` flag passed → force that manager for ALL tools (override matrix lookup).
5. If `--tools=<csv>` flag passed → filter plan to listed tools only.

If a tool has `requires_sudo: true`:
- DO NOT add to auto-execute plan.
- Add to "manual install" list shown separately with explicit instruction.

Compute total download size + per-tool details.

### Step 4: Propose + confirm (AskUserQuestion)

If `--dry-run` flag passed → emit plan + exit (don't execute).

If `--manual` flag passed → print all install commands as instructions + exit (don't execute via Bash tool).

Otherwise emit chat plan:

```
Step 3: Building install plan...

<N> tools to install via <pkg_mgr> (total ~<size>MB download):
  1. <tool_1>      <size>MB    <install_cmd>
  2. <tool_2>      <size>MB    <install_cmd>
  ...

Manual install required (sudo / no auto):
  - <tool_X>       <size>MB    <install_cmd>   (run manually after this skill)

[Install all (<N> tools)] [Pick subset] [Cancel]
```

Use AskUserQuestion with 3 options. On `Pick subset` → secondary AskUserQuestion with multiSelect=true listing each tool with size + cmd.

### Step 5: Execute install (only for auto-executable tools — never sudo-required)

For each tool in approved plan:

```
Step 4: Installing (estimated <minutes> min)...
  [<i>/<N>] <install_cmd> ...
```

Invoke Bash tool with the `install_cmd` from matrix. Capture stdout/stderr/exit_code per tool. Emit per-tool progress line on completion: `✓ (Xs)` on success OR `✗ (exit <code>)` on failure.

If ANY install fails:
- Continue with remaining tools (don't abort entire batch).
- Collect failures into `install_failures[]` list.
- After loop, emit halt `install_failed` per failed tool with details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars)}`.

### Step 6: Verify (post-install)

For each successfully-installed tool:

1. Run `verify_cmd` from matrix entry.
2. Exit 0 + version capture → mark `verified`.
3. Exit non-zero → mark `unverified`; add to halt list (install ran but tool not on PATH — PATH refresh needed OR install bug).

Emit chat output:

```
Step 5: Verifying...
  ✓ <tool> v<version>
  ✗ <tool> (install ran but verify failed — try `hash -r` and re-run; OR check PATH)
```

If ANY unverified → halt `install_failed` with subtype `verify_after_install_failed`.

### Step 7: Memory write

After all installs + verifies complete:

1. Acquire memory file lock per Iter 5 pattern (`<project>/.mega-sdd/memory/install-outcomes.md.lock` — backoff + retry 3x; fail with `memory_in_use` if all retries fail).
2. Append run record to `<project>/.mega-sdd/memory/install-outcomes.md` per schema in spec §9.
3. Release lock.

If memory write fails (disk full / permissions) → log warning to chat; don't halt (memory is convenience, not correctness).

### Step 8: Summary + handoff

Emit chat summary:

```
✅ Install complete: <N> verified, <M> failed, <K> skipped
  Verified: <tool list>
  Failed: <tool list with one-line reason>
  Skipped: <sudo-required tool list — instructed user to run manually>

Memory: outcomes written to <path>
Re-run check anytime: /mega-sdd:install-deps --force-recheck
```

If `--auto` flag → emit handoff YAML per §Handoff emission.

## Halt protocol

Per `mega-sdd:generate-intent/references/vault-contract.md §halt-protocol`. install-deps emits these halts:

- **`pkg_mgr_not_found`** (NEW v1.0.0+, Iter 55): no compatible package manager detected for OS. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Resolution: install brew (macOS) / verify apt-on-PATH (Linux) / install WSL Ubuntu (Windows native) → re-run.
- **`install_failed`** (NEW v1.0.0+, Iter 55): install command exited non-zero OR verify_cmd failed post-install. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail, subtype: <install_command_failed | verify_after_install_failed>}`. Resolution: inspect stderr_tail, fix root cause (PATH / repo signing / network), re-run `/mega-sdd:install-deps --tools=<failed-tool>` to retry single tool.
- **`memory_in_use`** (EXISTING from Iter 5/49): install-outcomes.md write lock collision. Resolution: retry after backoff; if persistent, manually remove stale `.lock` file.

## Handoff emission (v1.0.0+, Iter 55)

When invoked with `--auto` flag, emit handoff YAML at end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: install-deps
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to <project>/.mega-sdd/memory/install-outcomes.md>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "Deps installed; mega-sdd full-precision mode enabled. Re-run /mega-sdd:install-deps --force-recheck if needed."
  blockers: []   # populated on install_failed / pkg_mgr_not_found
  metrics:
    tools_audited: <int>             # NEW v1.0.0+, Iter 55
    tools_already_present: <int>     # NEW v1.0.0+, Iter 55 (already installed pre-skill)
    tools_installed: <int>           # NEW v1.0.0+, Iter 55 (successfully installed this run)
    tools_failed: <int>              # NEW v1.0.0+, Iter 55 (install or verify failed)
    tools_sudo_pending: <int>        # NEW v1.0.0+, Iter 55 (requires_sudo — printed but not auto-run)
    detected_os: <"macos" | "linux" | "wsl" | "windows-bash" | "unknown">
    detected_pkg_mgr: <"brew" | "apt" | "dnf" | "pacman" | "apk" | "winget" | "scoop" | "cargo-fallback" | "none">
```

Status `halted` on `install_failed` OR `pkg_mgr_not_found`. Required ONLY under `--auto`.

## Memory layer (v1.0.0+, Iter 55)

Participates in mega-sdd memory layer per `mega-sdd:memory/references/memory-schema.md`.

### Writes

| When | File | Content |
|---|---|---|
| After successful install + verify | `<project>/.mega-sdd/memory/install-outcomes.md` | Append run record with timestamp, OS detection, per-tool status (✓ installed / ⊘ skipped / ✗ failed / ⊕ sudo-pending) |

### Reads

| What | Source | How used |
|---|---|---|
| Prior install outcomes | `install-outcomes.md` | Step 2 audit skips re-verify of tools marked "installed" within last 30 days AND still present on PATH |

`--force-recheck` flag disables memory reads; always re-audit from scratch.

## Anti-hallucination rails

1. NEVER auto-`sudo` — for tools requiring elevation, PRINT command + instruct user to run manually. Memory records as "sudo-pending" status.
2. NEVER use curl|bash patterns — only signed package manager commands from `tool-matrix.yaml`.
3. ALWAYS show exact `install_cmd` + source pkg manager + size estimate BEFORE running (AskUserQuestion gate).
4. ALWAYS verify post-install with `verify_cmd` from matrix — claim "installed" only after verify passes.
5. NEVER install Claude Code itself — out of scope; this skill installs OPTIONAL mega-sdd deps only.
6. Memory write happens AFTER verify pass — never record "installed" on partial state.
7. Skip tools with no matching matrix entry AND no working fallback — emit warning, don't halt entire batch.
````

- [ ] **Step 4.3: Verify procedure body**

Run: `wc -l plugins/mega-sdd/skills/install-deps/SKILL.md`
Expected: 200-250 lines (full skill body)

Run: `grep -c "^### Step\|^## " plugins/mega-sdd/skills/install-deps/SKILL.md`
Expected: ≥ 12 (8 procedure steps + 6 section headers)

- [ ] **Step 4.4: Commit SKILL.md procedure**

```bash
git add plugins/mega-sdd/skills/install-deps/SKILL.md
git commit -m "feat(iter-55): install-deps SKILL.md main procedure (8 steps)

Step 1 detect env -> Step 2 audit inventory (memory cache + verify_cmd) ->
Step 3 build plan (matrix lookup + fallback chain + sudo separation) ->
Step 4 propose+confirm (AskUserQuestion + --dry-run / --manual paths) ->
Step 5 execute (Bash invocation, per-tool progress) -> Step 6 verify ->
Step 7 memory write (Iter 5 lock pattern) -> Step 8 summary + handoff.

Halt protocol: 2 new halts (install_failed, pkg_mgr_not_found) + memory_in_use
(reused). Handoff emission with 7 metrics (tools_audited / _present / _installed /
_failed / _sudo_pending / detected_os / detected_pkg_mgr). Anti-halu rails:
no auto-sudo, no curl|bash, mandatory verify, memory write only after verify pass.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Create install-deps.md slash command

**Files:**
- Create: `plugins/mega-sdd/commands/install-deps.md`

- [ ] **Step 5.1: Create slash command wrapper**

Create `plugins/mega-sdd/commands/install-deps.md`:

```markdown
---
description: [USER-INVOKED] Auto-detect OS + pkg manager + install missing native deps (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh) with single batch confirmation. NEVER auto-sudo; NEVER curl|bash; mandatory post-install verify; memory-cached outcomes prevent re-asking next session. Supports macOS (brew), Ubuntu/Debian (apt), Fedora/RHEL (dnf), Arch (pacman), Alpine (apk), WSL, Windows-bash (winget/scoop/choco best-effort), cross-platform fallbacks (cargo/npm/go).
argument-hint: "[--dry-run] [--tools=<csv>] [--force-recheck] [--pkg-mgr=<name>] [--manual] [--auto]"
---

Invoke the `mega-sdd:install-deps` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- `--dry-run`: show install plan + estimated sizes; don't execute (useful to preview)
- `--tools=<csv>`: limit to subset (e.g., `--tools=pandoc,tectonic` for FSD deps only)
- `--force-recheck`: ignore memory cache; re-audit every tool from scratch
- `--pkg-mgr=<name>`: override auto-detected manager (e.g., `--pkg-mgr=cargo` to use Rust toolchain instead of brew/apt)
- `--manual`: print install commands as instructions but skip Bash invocation (user runs manually)
- `--auto`: skip confirmation prompts + emit handoff YAML (orchestrator-invoked)

Follow `skills/install-deps/SKILL.md` Procedure exactly.

Hard rails (anti-halu + safety):
- NEVER auto-`sudo` — for tools requiring elevation (most apt/dnf installs), the skill PRINTS the command + instructs user to run manually. Memory records as "sudo-pending".
- NEVER use curl|bash patterns — only signed package manager commands per `tool-matrix.yaml`.
- ALWAYS show exact `install_cmd` + source pkg manager + size estimate BEFORE running.
- Single batch confirmation via AskUserQuestion — user sees full plan before any install runs.
- ALWAYS verify post-install with `verify_cmd` from matrix — claim "installed" only after verify passes.
- Memory write happens AFTER verify pass — never record "installed" on partial state.
- This skill installs OPTIONAL mega-sdd deps only — never installs Claude Code itself.

On completion, announce summary: "✅ Install complete: N verified, M failed, K skipped. Memory: outcomes written to <path>."
```

- [ ] **Step 5.2: Verify command structure**

Run: `head -5 plugins/mega-sdd/commands/install-deps.md`
Expected: starts with `---` frontmatter block

Run: `grep -c "no-sudo\|NEVER.*sudo\|sudo" plugins/mega-sdd/commands/install-deps.md`
Expected: ≥ 2 (safety rails about sudo present)

- [ ] **Step 5.3: Commit slash command**

```bash
git add plugins/mega-sdd/commands/install-deps.md
git commit -m "feat(iter-55): /mega-sdd:install-deps slash command wrapper

Matches emit-fsd.md anatomy. Documents 6 flags (--dry-run, --tools, --force-
recheck, --pkg-mgr, --manual, --auto). Hard rails: NEVER auto-sudo, NEVER
curl|bash, single batch confirmation, mandatory verify.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: Wire predictive-checks.md hint suffix

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`

- [ ] **Step 6.1: Find existing tool-presence checks**

Run: `grep -n "tree_sitter_present\|pandoc_installed\|pandoc_latex_engine_present" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: 3+ matches (1 per check_id + on_fail line)

- [ ] **Step 6.2: Append hint suffix to tree_sitter_present on_fail**

Find:
```markdown
  on_fail: "tree-sitter not installed; scan-codebase will fall back to regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli"
```

Replace with:
```markdown
  on_fail: "tree-sitter not installed; scan-codebase will fall back to regex engine (lower precision). Install: brew install tree-sitter / cargo install tree-sitter-cli / npm install -g tree-sitter-cli — OR run `/mega-sdd:install-deps` for auto-install (Iter 55+)."
```

- [ ] **Step 6.3: Append hint suffix to pandoc_installed on_fail**

Find:
```markdown
  on_fail: "pandoc not installed; emit-fsd will produce FSD.md only (no PDF render). Install: brew install pandoc (macOS) / apt install pandoc (Debian/Ubuntu) / dnf install pandoc (Fedora)"
```

Replace with:
```markdown
  on_fail: "pandoc not installed; emit-fsd will produce FSD.md only (no PDF render). Install: brew install pandoc (macOS) / apt install pandoc (Debian/Ubuntu) / dnf install pandoc (Fedora) — OR run `/mega-sdd:install-deps` for auto-install (Iter 55+)."
```

- [ ] **Step 6.4: Append hint suffix to pandoc_latex_engine_present on_fail**

Find:
```markdown
  on_fail: "no LaTeX engine found; pandoc PDF render needs xelatex (brew install --cask basictex / apt install texlive-xetex) OR tectonic (brew install tectonic — recommended, lighter, ~50MB vs ~2GB BasicTeX). Falls back to FSD.html for browser print-to-PDF."
```

Replace with:
```markdown
  on_fail: "no LaTeX engine found; pandoc PDF render needs xelatex (brew install --cask basictex / apt install texlive-xetex) OR tectonic (brew install tectonic — recommended, lighter, ~50MB vs ~2GB BasicTeX). Falls back to FSD.html for browser print-to-PDF — OR run `/mega-sdd:install-deps` for auto-install (Iter 55+)."
```

- [ ] **Step 6.5: Verify hint suffix added to all 3**

Run: `grep -c "/mega-sdd:install-deps" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: 3

- [ ] **Step 6.6: Commit predictive-checks hint update**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md
git commit -m "feat(iter-55): + /mega-sdd:install-deps hint in 3 predictive checks

Appends 'OR run /mega-sdd:install-deps for auto-install (Iter 55+)' suffix to
on_fail messages for tree_sitter_present, pandoc_installed, and
pandoc_latex_engine_present. No behavior change — just better discoverability
of the new install-deps skill.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Wire vault-contract.md halt enum (2 new halts)

**Files:**
- Modify: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`

- [ ] **Step 7.1: Find halt enum**

Run: `grep -n "^## §halt-protocol\|halt-protocol type enum\|## halt-protocol" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md | head -3`
Expected: at least 1 match (anchor for §halt-protocol section)

- [ ] **Step 7.2: Read context around halt enum**

Read 40 lines starting at the §halt-protocol section to understand the existing enum format.

- [ ] **Step 7.3: Add 2 new halt types to enum**

Find the enum list (typically a YAML or bullet list with halt type names). Add `install_failed` and `pkg_mgr_not_found` to the enum, alphabetically ordered or appended at end (match existing convention).

If enum is a YAML enum like:
```yaml
type:
  enum:
    - bind_conflict
    - dep_missing
    - ...
```

Add:
```yaml
    - install_failed       # NEW v3.38.0+, Iter 55 (install-deps post-install verify failed)
    - pkg_mgr_not_found    # NEW v3.38.0+, Iter 55 (install-deps detected no compatible package manager)
```

Also add descriptions to the enum description block if present (match existing format per other halt types). Example:

```markdown
- `install_failed`: install-deps skill ran an install command but post-install `verify_cmd` failed. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail, subtype}`. Source skill: `install-deps`.
- `pkg_mgr_not_found`: install-deps detected no compatible package manager for the OS. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Source skill: `install-deps`.
```

- [ ] **Step 7.4: Verify halt enum additions**

Run: `grep -c "install_failed\|pkg_mgr_not_found" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`
Expected: ≥ 2 (one per halt — may be more if both enum + description block updated)

- [ ] **Step 7.5: Commit halt enum update**

```bash
git add plugins/mega-sdd/skills/generate-intent/references/vault-contract.md
git commit -m "feat(iter-55): + install_failed + pkg_mgr_not_found halt types

2 new halts from install-deps skill (Iter 55). Both follow existing halt
envelope schema (source_skill, details, next_action). No existing halt was
overloaded — new types give clearer error path than e.g. reusing
quality_gate_failed.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Smoke test (structural verification)

**Files:** No modifications; verification only.

- [ ] **Step 8.1: Verify all 4 new files exist**

Run: `ls plugins/mega-sdd/skills/install-deps/ plugins/mega-sdd/skills/install-deps/references/ plugins/mega-sdd/commands/install-deps.md`
Expected:
```
plugins/mega-sdd/skills/install-deps/:
SKILL.md   references/

plugins/mega-sdd/skills/install-deps/references/:
os-detection.md   tool-matrix.yaml

plugins/mega-sdd/commands/install-deps.md
```

- [ ] **Step 8.2: Verify SKILL.md references all 2 reference files**

Run: `grep -c "references/os-detection.md\|references/tool-matrix.yaml" plugins/mega-sdd/skills/install-deps/SKILL.md`
Expected: ≥ 4 (each ref cited at least twice — section + procedure step)

- [ ] **Step 8.3: Verify tool-matrix.yaml has 8 tools**

Run: `grep -c "^  - id: " plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml`
Expected: 8

- [ ] **Step 8.4: Verify os-detection algorithm structure**

Run: `grep -c "OS=\"macos\"\|OS=\"linux\"\|OS=\"wsl\"\|OS=\"windows-bash\"" plugins/mega-sdd/skills/install-deps/references/os-detection.md`
Expected: ≥ 4 (all 4 OS family branches)

Run: `grep -c "PKG_MGR=\"brew\"\|PKG_MGR=\"apt\"\|PKG_MGR=\"dnf\"\|PKG_MGR=\"pacman\"\|PKG_MGR=\"apk\"\|PKG_MGR=\"winget\"\|PKG_MGR=\"scoop\"" plugins/mega-sdd/skills/install-deps/references/os-detection.md`
Expected: ≥ 7 (all 7 pkg managers covered)

- [ ] **Step 8.5: Verify predictive-checks hints added**

Run: `grep -c "/mega-sdd:install-deps" plugins/mega-sdd/skills/orchestrate-flow/references/predictive-checks.md`
Expected: 3

- [ ] **Step 8.6: Verify halt types in vault-contract**

Run: `grep -c "install_failed\|pkg_mgr_not_found" plugins/mega-sdd/skills/generate-intent/references/vault-contract.md`
Expected: ≥ 2

- [ ] **Step 8.7: Record smoke test result**

NO commit at this task — verification only. If any step fails, fix in appropriate prior task + re-verify.

Document any deviations in chat output for user awareness.

---

## Task 9: Atomic release commit + push

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `plugins/mega-sdd/README.md`
- Modify: `README.md`

- [ ] **Step 9.1: Bump plugin.json**

Find:
```json
  "version": "3.37.0",
```

Replace with:
```json
  "version": "3.38.0",
```

- [ ] **Step 9.2: Add CHANGELOG entry**

Find existing `## [3.37.0] - 2026-05-25` entry. Insert BEFORE it the v3.38.0 entry with full Iter 55 release notes per spec §11 + standing directives section + skill bumps. Use the same structure as Iter 53/54 CHANGELOG entries (Pipeline addition / New skill / Supported OSes / Tool matrix / Safety rails / Files created / Files modified / Out of scope / Standing directives / Plugin version).

- [ ] **Step 9.3: Update plugin README — folder layout + What's new + counts**

Find skill listing block in `plugins/mega-sdd/README.md`. Update:
- Skill count: `# 14 skills + _vendored/` → `# 15 skills + _vendored/`
- Add `│   ├── install-deps/              # OS-aware dep installer (v1.0.0) — NEW Iter 55` after `emit-fsd/` line
- Command count: `# 21 slash commands (1 primary + 20 advanced)` → `# 22 slash commands (1 primary + 21 advanced)`
- Add `install-deps.md` to commands listing

In What's new block, insert BEFORE `### v3.37.0 (Iter 54, minor)` a new `### v3.38.0 (Iter 55, minor) — OS-Aware Auto-Install Deps (new skill `install-deps`)` entry summarizing the iter (research-driven, supported OSes, tool matrix, safety rails, reuse-first).

Update plugin manifest version reference: `plugin manifest (v3.37.0)` → `plugin manifest (v3.38.0)`.

- [ ] **Step 9.4: Update root README — version refs + counts + listings**

Find and update:
- `**Plugin:** \`mega-sdd\` · **Version:** 3.37.0` → `3.38.0`
- `├── plugins/mega-sdd/                       # the plugin itself (v3.37.0)` → `(v3.38.0)`
- `14 skills (incl. 1 anchor) + 21 slash commands` → `15 skills (incl. 1 anchor) + 22 slash commands` (line 296)
- `14 skills + _vendored/` → `15 skills + _vendored/` (line 421)
- Add `│   │   ├── install-deps/                   # OS-aware dep installer (Iter 55)` after `emit-fsd/` line
- `21 slash commands` → `22 slash commands` (line 437)
- `Currently 3.37.0.` → `Currently 3.38.0.` (line 347)

Add to cheat-sheet:
```markdown
| Install missing native deps (pandoc, tectonic, etc.) | `/mega-sdd:install-deps` (Iter 55 — auto-detect OS + pkg mgr) |
```

Add row to "Audit-driven evolution" table at bottom of Audits section (already updated in Iter 54 audit). No update needed there — install-deps is feature work, not audit closure.

- [ ] **Step 9.5: Verify all version refs aligned**

Run: `grep -rn "3\.37\.0" plugins/mega-sdd/README.md README.md plugins/mega-sdd/.claude-plugin/plugin.json 2>/dev/null | grep -v "→ 3\.38\.0\|3\.37\.0 →\|## \[3.37.0\]\|v3\.37\.0 (Iter 54" | head -5`
Expected: empty (no remaining stale refs outside historical entries)

- [ ] **Step 9.6: Atomic release commit + push**

```bash
git add CHANGELOG.md README.md plugins/mega-sdd/.claude-plugin/plugin.json plugins/mega-sdd/README.md
git commit -m "$(cat <<'EOF'
release(iter-55): mega-sdd v3.38.0 — OS-Aware Auto-Install Deps (new skill install-deps)

User-driven feature after Iter 54: dependency install friction (pandoc, tectonic,
tree-sitter, ast-grep, ripgrep, jd, markdownlint-cli2, gh). Research-driven:
cross-platform shell OS detection canonical patterns + auto-install security
consensus (npm/Snyk best practices) + Claude Code Bash-via-skill model.

New skill: mega-sdd:install-deps v1.0.0
  Trigger: standalone /mega-sdd:install-deps (no auto-invocation per safety consensus)
  Detects OS: macOS / Ubuntu / Fedora / Arch / Alpine / WSL / Windows-bash
  Detects pkg mgr: brew / apt / dnf / pacman / apk / winget / scoop + cargo/npm/go fallbacks
  Tool matrix: 8 tools (tree-sitter, ast-grep, ripgrep, jd, pandoc, tectonic, markdownlint-cli2, gh)
  6-step procedure: detect -> audit -> propose -> confirm -> install -> verify -> memory write
  Safety rails: NEVER auto-sudo, NEVER curl|bash, mandatory verify, memory-cached outcomes

2 new halt types: install_failed (verify fail), pkg_mgr_not_found (no compatible pkg mgr).
Predictive-checks hint update: 3 existing tool-presence checks (tree_sitter_present,
pandoc_installed, pandoc_latex_engine_present) get '...OR run /mega-sdd:install-deps
for auto-install' suffix.

Files: 4 new + 5 modified
Plugin v3.37.0 -> v3.38.0 (MINOR -- new skill, backward-compatible)

Reuse-first: emit-fsd skill anatomy template, Iter 33 predictive-checks hint
pattern, Iter 5 memory layer (install-outcomes.md), existing tooling-install.md
matrix promoted to YAML + extended with pandoc/tectonic.

Spec: docs/superpowers/specs/2026-05-25-iter-55-install-deps-skill-design.md
Plan: docs/superpowers/plans/2026-05-25-iter-55-install-deps-skill.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin main
```

Expected: push succeeds.

---

## Self-Review (writing-plans skill checklist)

**1. Spec coverage:**
- §1 Goal → Task 4 (skill ships full procedure) + Task 9 (release)
- §2 Non-Goals → not implemented (intentional deferral)
- §3 User-facing surfaces → Tasks 1, 4 (skill), 5 (command), 6 (predictive-checks hint)
- §4 Skill anatomy → Tasks 1-5 (all 4 files created)
- §5 OS detection algorithm → Task 3 (os-detection.md)
- §6 Tool matrix schema → Task 2 (tool-matrix.yaml)
- §7 UX flow → Task 4 (SKILL.md procedure §Steps 1-8)
- §8 Safety rails → Task 4 (Anti-hallucination rails section) + Task 5 (command hard rails)
- §9 Memory layer integration → Task 4 (Memory layer section in SKILL.md)
- §10 Predictive-checks hint update → Task 6 (3 hints added)
- §11 Implementation scope → all 9 tasks
- §12 Halt protocol → Task 7 (vault-contract halt enum) + Task 4 (SKILL.md halt protocol section)
- §13 Success criteria → Task 8 (smoke test) + manual verification post-release
- §14 Out of scope → intentional deferral

**Spec coverage: 100% — every requirement has a task.**

**2. Placeholder scan:**
- "(filled in Task 4 — see plan)" in scaffold SKILL.md from Task 1 → replaced in Task 4 (intentional)
- No "TBD" / "TODO" / "implement later" / "add appropriate handling" patterns
- All code blocks complete

**Placeholder scan: clean.**

**3. Type consistency:**
- `<vault-path>` / `<project>` placeholders used consistently
- OS enum (`macos | linux | wsl | windows-bash | unknown`) consistent across spec + plan + SKILL.md procedure + handoff metrics
- PKG_MGR enum (`brew | apt | dnf | pacman | apk | winget | scoop | choco | cargo-fallback | none`) consistent
- Halt types (`install_failed`, `pkg_mgr_not_found`) consistent across SKILL.md + vault-contract.md + handoff status
- File paths (`<project>/.mega-sdd/memory/install-outcomes.md`) consistent

**Type consistency: clean.**

**Plan ready for execution.**

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-iter-55-install-deps-skill.md`. Per Iter 54 precedent (literal-paste markdown content) — inline execution per simplifikasi standing directive. Auto mode active; proceeding with inline execution.

9 tasks, atomic commits per task, final release commit + push in T9.
