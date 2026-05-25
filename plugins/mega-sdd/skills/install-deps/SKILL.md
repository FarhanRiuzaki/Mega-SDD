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
