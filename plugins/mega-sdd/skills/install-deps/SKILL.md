---
name: install-deps
version: 1.7.1
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

## Pre-flight checks

1. **pkg_mgr_detected**: at least one of (brew | apt | dnf | pacman | apk | winget | scoop | choco | cargo | npm | go | pipx) is on PATH
   - If none → halt `pkg_mgr_not_found`
2. **memory_writable**: `<project>/.mega-sdd/memory/` exists and writable (or can be created)

## Procedure

### Step 1: Detect environment

Run the canonical detection algorithm per `references/os-detection.md`. Emit chat output:

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
3. **Usability is the only thing that can mark a tool `present`** — but the probe MUST be bounded. **Resolve the bounding prefix; never type it literally at a probe site.** The resolver is the prelude of the *same* Bash invocation that runs the probe loop:

   ```bash
   # Prelude — same Bash invocation as the probes below. Shell state does NOT
   # survive between tool calls, so Step 6 re-runs this prelude instead of
   # referring back to this variable. Two builtins, zero forks.
   if   command -v timeout  >/dev/null 2>&1; then BOUND="timeout -k 2 10"
   elif command -v gtimeout >/dev/null 2>&1; then BOUND="gtimeout -k 2 10"
   else BOUND=""; fi

   $BOUND <verify_cmd>   # unquoted on purpose — an empty BOUND must vanish
   ```

   **A `verify_cmd` containing a shell operator MUST be wrapped, or the bound covers
   only its first word-group.** Seven matrix rows read
   `tree-sitter --version || tree-sitter-cli --version`. Substituted bare, the shell parses
   `||` at the TOP level: `timeout … tree-sitter --version` is bounded, then the fallback
   limb runs **completely unbounded** — and because `||` yields the LAST command's status,
   it also swallows the 124/137 the bound just produced, so the verdict table below reads
   the fallback's code instead. Both halves of the protection are lost silently.
   When the value contains `||`, `&&`, `|`, or `;`, wrap it in one bounded shell:

   ```bash
   $BOUND sh -c "<verify_cmd>"   # one bounded process; the operator is INSIDE the bound
   ```

   Every value in `tool-matrix.yaml` is plain words and flags — no quotes, `$`, or
   backticks — so double-quoting is safe today. If a future row needs any of those, give
   that tool a single-command `verify_cmd` rather than escaping around this rule.

   **`timeout` is not universal, and its absence is not a fact about the probed tool.** Git Bash ships MSYS2 coreutils `timeout` and Linux ships GNU coreutils, but **stock macOS ships neither `timeout` nor `gtimeout`** — `gtimeout` only appears after `brew install coreutils`. A literal prefix there makes every probe exit 127 and, under the verdict table below, reports every *installed* tool as `missing`. When `BOUND` resolves empty, state it once in the audit output and continue; probes run unbounded on that machine. **A missing bounding utility degrades the protection — it must NEVER be converted into a verdict about the probed tool.**

   **Write the flag BEFORE the duration** — the reverse order is a parse error that exits 127. GNU `timeout` sends SIGTERM at expiry and then *waits* for the child; `-k 2` escalates to SIGKILL 2 s later, so the ceiling is an explicit ~12 s. Under Git Bash (MSYS2) SIGTERM **does** reach a native `.exe`: the MSYS2 runtime injects a thread that calls `ExitProcess`, then escalates to `TerminateProcess` after ~10 s (cygwin `kill` docs; `git-for-windows/msys2-runtime` PR#15, PR#16, commit `c967bd8`). The unescalated form is therefore a **bounded ~10 s overshoot on top of the bound, not an unbounded hang**. `-k 2` is still worth keeping: it makes the ceiling a number this procedure owns and states, instead of one that depends on an MSYS2 runtime implementation detail.

   **Never run `verify_cmd` unbounded when a bound resolves.** `command -v` is a builtin and cannot hang; an execution probe can, and on a corporate network a tool that checks for updates on startup will block until the proxy gives up. Measured cost of the exec probes, macOS warm — Windows + EDR is roughly an order of magnitude worse: `semgrep --version` **3.9 s**, `mmdc --version` 384 ms, `markdownlint-cli2 --version` 366 ms, everything else under 150 ms.
   - Exit 0 → mark `present`; capture the version from stdout best-effort.
   - **Timeout — exit 124 (SIGTERM landed) OR exit 137 (the `-k` escalation had to SIGKILL) → mark `present` with a `slow-verify` note, NEVER `missing`.** `command -v` already proved the binary exists; a slow probe is not a missing tool, and treating it as one would propose a pointless reinstall of something already installed. **Both codes carry the same verdict** — a native `.exe` that ignores SIGTERM exits 137, and reading 137 as a failed probe reintroduces exactly the false-`missing` bug the bound exists to prevent.
   - **Exit 127 → mark `present` with a `probe-inconclusive` note, NEVER `missing`.** `command -v` already resolved this name in step 2, so 127 cannot mean the tool is absent from PATH — it means the probe layer itself could not run: no bounding utility on this machine, flags written in the wrong order, or a shim whose interpreter is gone. Say *inconclusive*, not *working*: we did not observe the tool execute. **The absence of the bounding utility must never itself produce a `missing` verdict** — that proposes reinstalling software that is already installed.
   - Exit non-zero with any OTHER code (not 124, 137, or 127) → mark `missing`.
   - A memory hit from step 1 **plus** exit 0 → additionally annotate `cached-installed` (we installed it before; don't re-propose it). A memory hit NEVER skips the probe.
   - **The exit code is the verdict — never gate on a stdout pattern.** `semgrep --version` prints an upgrade banner before the version, so a "does stdout look like a version" test false-fails a working tool.
4. **A `command -v` hit is never sufficient on its own.** Windows ships App Execution Alias stubs in `%LOCALAPPDATA%\Microsoft\WindowsApps` (on the default per-user PATH) that resolve, print "Python was not found…" to stderr, and exit 49. Presence ≠ usability — which is exactly why the pre-filter may only ever produce `missing`, never `present`.
5. **`python3` is the named exception** — the one entry in `defaults.required_tools`. Its verdict comes from the shared resolver, not a bare `verify_cmd`, because the working command name differs per install route:

   ```bash
   $BOUND bash -c '. "${CLAUDE_PLUGIN_ROOT}/scripts/_lib/resolve-python.sh" && mega_sdd_python && $MEGA_SDD_PY -V'
   ```

   This is an execution probe like any other, so it carries the **same resolved prefix and the same carve-out** — bounded, and exit 124 / 137 / 127 never mean `missing`. It rejects any candidate under `WindowsApps` and walks `python3` → `python` → `py -3`. Exit 0 → `present`; record WHICH name resolved (a winget/python.org install ships no `python3.exe`, so `python` is the working name there). Exit non-zero with any OTHER code → `missing`, and print `mega_sdd_python_remedy` verbatim from that same file rather than composing new remedy prose.

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

1. Run `verify_cmd` from matrix entry, **bounded exactly as in Step 2**. Shell state does not survive between tool calls, so **re-run the resolver prelude here** rather than reusing Step 2's variable — and never hard-code the prefix, for the same stock-macOS reason:

   ```bash
   if   command -v timeout  >/dev/null 2>&1; then BOUND="timeout -k 2 10"
   elif command -v gtimeout >/dev/null 2>&1; then BOUND="gtimeout -k 2 10"
   else BOUND=""; fi

   $BOUND <verify_cmd>
   # …but if <verify_cmd> contains `||`, `&&`, `|` or `;` (the seven tree-sitter rows do),
   # use `$BOUND sh -c "<verify_cmd>"` — see Step 2, or the operator escapes the bound.
   ```

   Report the resolved prefix here the same way Step 2 does — including `none — probes unbounded` when the ladder falls through to empty. Exit 124 OR exit 137 (timeout — SIGTERM landed, or the `-k` SIGKILL escalation fired) → `verified` with a `slow-verify` note: the install just exited 0, so a slow probe is not a failed install. **Exit 127 → `verified` with a `probe-inconclusive` note, never `unverified`** — the install exited 0 and `command -v` resolves the name, so a probe layer that could not run says nothing about the install.
2. Exit 0 + version capture → mark `verified`.
3. Exit non-zero with any code other than 124/137/127 → **on `OS = windows-bash`, do NOT mark `unverified` yet** — go to the Windows branch below. On every other OS, mark `unverified` and add to the halt list.

#### Windows branch (`OS = windows-bash`) — stale PATH is not a failed install

An installer writes `HKCU\Environment\Path`; a bash session that is already running never sees it (winget prints "restart your shell to use the new value"). So a `verify_cmd` failing here proves nothing about the install. Ask the question that does distinguish them — *will it resolve in a NEW shell?*:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/fix-windows-path.sh" --probe=<binary>
```

- rc 0 → mark `verified`, note "restart terminal". **Not** a halt.
- rc 3 → propose the gated PATH repair (`--ensure-dirs --dry-run` first, then `--backup-to=<project>/.mega-sdd/memory/path-backup-<ts>.txt`), re-probe, and only if it is still rc 3 mark `unverified`.
- rc 4 / rc 6 → mark `unverified` with "restart terminal and re-run".
- rc 7 → the interpreter is an MSYS2/Cygwin build with no `winreg`; nothing was read or written. Mark `unverified` and name the remedy (install Python via winget or scoop).

Full triage table, the per-installer binary locations, and the destructive methods that must never be used: `references/windows-path.md`. Manual per-tool install commands (the non-skill path, e.g. `markdownlint-cli2`): `plugins/mega-sdd/references/tooling-install.md`.

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
