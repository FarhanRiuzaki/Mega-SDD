---
name: install-deps
version: 1.10.0
description: Detect OS + package manager and install missing optional native deps (tree-sitter, ast-grep, ripgrep, jd, pandoc, markdownlint-cli2, mmdc, semgrep, gitleaks) with one batch confirmation; never auto-sudo, never curl-pipe-bash, post-install verify. Triggers — "install deps", "auto install", "install tools", "install pandoc", "pasang tools", "auto install deps", or paraphrases.
---

# Install-Deps — OS-Aware Dependency Installer

**Announce at start:** "I'm using the install-deps skill to audit + install missing native deps."

> **Instruction language:** this skill reasons in English. Narrate (the announce, the install-plan proposal, confirmation) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens — tool names, package-manager names, shell commands — stay English (→ `plugins/mega-sdd/references/output-language.md`). *(Greenfield-reachable: "pasang tools" runs with no `.mega-sdd/` signal, so it carries the policy itself.)*

## When to use

- "install deps" / "auto install" / "install tools" / "pasang tools"
- After fresh mega-sdd install — bootstrap optional native binaries
- After predictive-checks warn (e.g., `pandoc_installed: warn` from emit-fsd predictive checks)
- Before generating emit PDFs — pandoc + a detected Chrome (mmdc for mermaid) via md2pdf.sh
- Cross-machine re-sync (memory layer skips already-installed tools)

## Inputs

- `--dry-run` (show install plan; don't execute)
- `--tools=<csv>` (limit to subset, e.g., `--tools=pandoc,mmdc` for emit-PDF-only)
- `--force-recheck` (ignore memory; re-audit every tool from scratch)
- `--pkg-mgr=<name>` (override auto-detected manager; e.g., force `cargo` instead of `brew`)
- `--manual` (print install commands but skip Bash invocation — user runs commands themselves)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per orchestrate-flow handoff-contract)

## Outputs

```
<project>/.mega-sdd/memory/install-outcomes.md   # memory log of install runs
```

Plus chat-only output: detected OS, tool inventory, install plan, per-tool verify result.

## Playwright browser (detect-and-offer — deliberately NO tool-matrix row)

The plugin bundles the Playwright MCP server (one of the two pinned servers in `plugins/mega-sdd/.mcp.json` — the other is Context7, 6.9.0); the ~130MB Chromium binary is NOT bundled and is never auto-installed. This lane follows the Chrome detect-only precedent (a matrix row would need an exec `verify_cmd`, and `npx playwright --version` auto-fetches from the npm registry when absent — the unbounded-network-probe class; spec 2026-08-12):

1. **Detect** (filesystem-only, offline, bounded): the browser cache dir exists and is non-empty —
   - macOS: `~/Library/Caches/ms-playwright/`
   - Linux: `~/.cache/ms-playwright/`
   - Windows: `%USERPROFILE%\AppData\Local\ms-playwright\`
2. **Offer** (never auto-run): print `npx playwright install chromium` with the size estimate (~130MB) and let the human run it — on gov/office networks the download may be blocked; absence is ALWAYS graceful (every Playwright consumer SKIPs with a reason; nothing gates).
3. Record the outcome in the install memory like any other tool (detected / offered / declined) — never "installed" without the cache dir appearing.

The MCP server itself can also fail to start (npx cold-cache package fetch on a blocked registry) — that is a DISTINCT rung; the mitigation is the `/mcp` per-server disable, documented in the README.

## Pre-flight checks

1. **pkg_mgr_detected**: at least one of (brew | apt | dnf | pacman | apk | winget | scoop | choco | cargo | npm | go | pipx) is on PATH
   - If none → halt `pkg_mgr_not_found`
2. **memory_writable**: `<project>/.mega-sdd/memory/` exists and writable (or can be created)

## Procedure

### Step 1: Detect environment

**Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-os.sh"` — the canonical detection algorithm, script-owned (never transcribe it; outcome table + special cases live in `references/os-detection.md`, open on an odd result). Emit chat output:

```
Detecting environment...
  OS: <macos|linux|wsl|windows-bash> <version> [<distro>]
  Package manager: <brew|apt|dnf|...> [v<version>]
  Fallbacks available: <cargo|npm|go>
```

If detection yields `OS = unknown` OR `PKG_MGR = none` AND no fallbacks → emit halt `pkg_mgr_not_found` with details `{os, distro, attempted_pkg_mgrs}`; STOP.

### Step 2: Audit tool inventory

Read `references/tool-matrix.yaml`. For each tool:

1. Check memory file `<project>/.mega-sdd/memory/install-outcomes.md` (if exists) for prior install entry within last 30 days.
2. **Pre-filter with `command -v` FIRST — this ordering is mandatory, not an optimisation.**
   - Not on PATH → mark `missing` immediately. **Do not run the exec probe.** A name absent from PATH is conclusively missing, and `command -v` is a shell builtin: zero forks, ~5 ms for all tools combined.
   - On PATH → continue to the exec probe below. Only tools that are actually present pay its cost.
3. **Usability is the only thing that can mark a tool `present`** — and the probe is SCRIPT-OWNED: **Run** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/probe-tool.sh" --verify-cmd='<verify_cmd>' --tool=<id>` per tool. Its ONE output line (`<verdict> bound=<N>s rc=<rc>`) IS the verdict — NEVER hand-run a bounded probe. The full contract it implements — bound resolution, operator wrapping, the timeout/127 carve-outs, and the **verdict map** (124/137/127 are NEVER `missing`; the exit code is the verdict, never a stdout pattern) — lives in `references/audit-and-verify.md §Probe contract` + `§Verdict map`; open it before interpreting ANY non-zero rc.
4. **A `command -v` hit is never sufficient on its own** (WindowsApps alias stubs resolve yet exit 49 — `references/audit-and-verify.md §command -v is never sufficient`). Presence ≠ usability; the pre-filter may only ever produce `missing`, never `present`.
5. **`python3` is the named exception** — verdict via the shared resolver (`scripts/_lib/resolve-python.sh`), not a bare `verify_cmd`; same bound, same carve-outs. Exact invocation + remedy rule: `references/audit-and-verify.md §python3 — the named exception`.

`--force-recheck` flag skips memory cache; re-audits every tool.

Emit chat output:

```
Auditing tool inventory...
  bound: <timeout -k 2 10 | gtimeout -k 2 10 | none — probes unbounded, `brew install coreutils` to bound them>
  ✓ <tool> <version>             # present
  ⊘ <tool>                       # cached-installed (skipped audit)
  ✗ <tool> (missing — <fallback_behavior>)
```

### Step 3: Build install plan

For each `missing` tool:

1. Look up matrix entry matching detected (OS, PKG_MGR).
2. If entry exists with `install_cmd` → add to install plan.
3. If no matching entry → try fallback managers per `os-detection.md §Fallback chain` (the Windows secondary-native order + cargo / npm / go runtimes live there). On a tool skipped purely for lack of a manager, surface the concrete remedy (install a manager or runtime), never a bare skip.
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
Proposing install plan...

<N> tools to install via <pkg_mgr> (total ~<size>MB download):
  1. <tool_1>      <size>MB    <install_cmd>
  2. <tool_2>      <size>MB    <install_cmd>
  ...

Manual install required (sudo / no auto):
  - <tool_X>       <size>MB    <install_cmd>   (run manually after this skill)

[Install all (<N> tools)] [Pick subset] [Cancel]
```

`AskUserQuestion` — question text restates what's at stake (the `<N>`-tool list, total `~<size>MB`, `<pkg_mgr>`, and the exact `install_cmd`s already shown in the plan above). Every option carries its keterangan per `plugins/mega-sdd/references/output-language.md §Prompt surfaces` — what choosing it does + the consequence, Indonesian-mix by default:

- **`Install all (<N> tools)`** **(recommended — jalankan semua `install_cmd` di plan ini sekarang lewat `<pkg_mgr>`; semua dep opsional terpasang, mega-sdd jalan full-precision)**
- `Pick subset` — secondary `AskUserQuestion` (`multiSelect=true`) listing each tool with size + cmd; tool yang TIDAK dipilih tetap `missing` dan jalan di `fallback_behavior`-nya masing-masing (lihat baris audit Step 2) sampai diinstall lain kali.
- `Cancel` — batal total, tidak ada yang diinstall; setiap tool `missing` tetap pada `fallback_behavior`-nya (mis. regex engine bukan tree-sitter AST, output PDF turun ke markdown-only); jalankan lagi `/mega-sdd:install-deps` kapan saja untuk retry.

### Step 5: Execute install (only for auto-executable tools — never sudo-required)

For each tool in approved plan:

```
Installing (estimated <minutes> min)...
  [<i>/<N>] <install_cmd> ...
```

Invoke Bash tool with the `install_cmd` from matrix. Capture stdout/stderr/exit_code per tool. Emit per-tool progress line on completion: `✓ (Xs)` on success OR `✗ (exit <code>)` on failure.

If ANY install fails:
- Continue with remaining tools (don't abort entire batch).
- Collect failures into `install_failures[]` list.
- After loop, emit halt `install_failed` per failed tool with details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars)}`.

### Step 6: Verify (post-install)

For each successfully-installed tool:

1. Run `verify_cmd` from the matrix entry via the SAME script as Step 2 — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/probe-tool.sh" --verify-cmd='<verify_cmd>' --tool=<id>` — its verdict line is final; NEVER hand-run the prelude. Verdict rules mirror Step 2 with `verified` in place of `present` (124/137 → `verified` + `slow-verify`; **127 → `verified` + `probe-inconclusive`, never `unverified`**): `references/audit-and-verify.md §Verify after install`.
2. Exit 0 + version capture → mark `verified`.
3. Exit non-zero with any code other than 124/137/127 → **on `OS = windows-bash`, do NOT mark `unverified` yet** — a stale PATH is not a failed install; run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/fix-windows-path.sh" --probe=<binary>` and follow the rc ladder in `references/audit-and-verify.md §Windows branch` (rc 0 = `verified` + "restart terminal", NOT a halt). Full PATH triage table + the destructive methods that must never be used: `references/windows-path.md`. Manual per-tool install commands (the non-skill path): `plugins/mega-sdd/references/tooling-install.md`. On every other OS, mark `unverified` and add to the halt list.

Emit chat output:

```
Verifying...
  ✓ <tool> v<version>
  ↻ <tool> (installed — resolves in a new shell; restart the terminal)
  ✗ <tool> (install ran but verify failed — try `hash -r` and re-run; OR check PATH)
```

If ANY unverified → halt `install_failed` with subtype `verify_after_install_failed`, or subtype `path_stale_pending_restart` when the probe succeeded but this shell cannot see it.

### Step 7: Memory write

After all installs + verifies complete:

1. Append the run record to `<project>/.mega-sdd/memory/install-outcomes.md` (schema in spec §9) via `bash "${CLAUDE_PLUGIN_ROOT}/scripts/memory-write.sh" --file=<resolved-path> --scope=project --cwd=<project-root>` — the script owns the secret scan, the file lock (backoff + retry 3x; exhaustion → `memory_in_use` telemetry), and the atomic append.

If the write fails (exit ≠ 0 — lock contention, disk full, permissions) → log warning to chat; don't halt (memory is convenience, not correctness).

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

Per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. install-deps emits these halts:

- **`pkg_mgr_not_found`**: no compatible package manager detected for OS. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Resolution: install brew (macOS) / verify apt-on-PATH (Linux) / install WSL Ubuntu (Windows native) → re-run.
- **`install_failed`**: install command exited non-zero OR verify_cmd failed post-install. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail, subtype: <install_command_failed | verify_after_install_failed>}`. Resolution: inspect stderr_tail, fix root cause (PATH / repo signing / network), re-run `/mega-sdd:install-deps --tools=<failed-tool>` to retry single tool.
- **`memory_in_use`**: install-outcomes.md write lock collision. Resolution: retry after backoff; if persistent, manually remove stale `.lock` file.

## Handoff emission

When invoked with `--auto` flag, emit handoff YAML at end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

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
    tools_audited: <int>             #
    tools_already_present: <int>     # already installed pre-skill
    tools_installed: <int>           # successfully installed this run
    tools_failed: <int>              # install or verify failed
    tools_sudo_pending: <int>        # requires_sudo — printed but not auto-run
    detected_os: <"macos" | "linux" | "wsl" | "windows-bash" | "unknown">
    detected_pkg_mgr: <"brew" | "apt" | "dnf" | "pacman" | "apk" | "winget" | "scoop" | "choco" | "pipx" | "cargo-fallback" | "none">
```

Status `halted` on `install_failed` OR `pkg_mgr_not_found`. Required ONLY under `--auto`.

## Memory layer

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
8. NEVER treat `command -v <tool>` as proof a tool works — it may only ever yield `missing`. A Windows App Execution Alias stub resolves on PATH and exits 49. Promotion to `present` requires an execution probe.
9. NEVER write PATH with `reg add` from Git Bash — the `reg` parser mangles backslashes and semicolons, prints `ERROR: Invalid syntax` **while returning RC=0**, and writes nothing or writes partially.
10. NEVER hand-write a `.reg` file for `reg import` — a wrong `hex(2)` UTF-16LE encoding imports "successfully" while storing a corrupt value (observed: a 798-char USER PATH truncated to 92). NEVER use `setx PATH` either — it truncates at 1024 chars and expands `%VAR%`, destroying `REG_EXPAND_SZ`. The only sanctioned path writer is `scripts/fix-windows-path.sh`.
11. ALWAYS back up the current PATH before modifying it — `fix-windows-path.sh` refuses `--ensure-dirs` without `--backup-to`, and that refusal must not be worked around.
12. NEVER run a `verify_cmd` unbounded where a bound resolves, and NEVER run one for a tool `command -v` already reported absent. An execution probe can block where a builtin cannot; `semgrep --version` alone measures 3.9 s warm on macOS, and v5.8.0 shipped these probes with no timeout and no pre-filter, which stalled an audit on a corporate Windows machine. Resolve the prefix per Bash invocation — `timeout -k 2 10`, else `gtimeout -k 2 10`, else empty — and treat exit 124, 137 AND 127 as `present`/`verified`, never `missing`/`unverified`.
13. NEVER hard-code that bound as a literal at a probe site, and NEVER let its absence become a verdict about a tool. Stock macOS ships neither `timeout` nor `gtimeout`, so a literal prefix exits 127 on every probe there and would report every installed tool `missing` — the exact false-`missing` class rule 12 exists to prevent. Keep `-k 2` whenever a bound *does* resolve: GNU `timeout` alone sends SIGTERM and then WAITS for the child. Under Git Bash (MSYS2) that SIGTERM still lands — the runtime injects an `ExitProcess` thread and escalates to `TerminateProcess` after ~10 s, so the unescalated worst case is a bounded overshoot, not a hang — but `-k 2` is what makes the ceiling a number this procedure owns rather than an MSYS2 runtime implementation detail.
