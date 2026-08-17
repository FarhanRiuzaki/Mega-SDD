# Audit & verify — the probe contract (Step 2 + Step 6 detail)

Operative detail routed from `SKILL.md` §Step 2 / §Step 6 (relocated 6.13.0, spec
2026-08-17-token-lard-cuts-p1 D3 — content moved verbatim, not rewritten).

## Contents
- [Probe contract (Step 2 item 3)](#probe-contract-step-2-item-3)
- [Verdict map](#verdict-map)
- [`command -v` is never sufficient (item 4)](#command--v-is-never-sufficient-item-4)
- [python3 — the named exception (item 5)](#python3--the-named-exception-item-5)
- [Verify after install (Step 6)](#verify-after-install-step-6)
- [Windows branch — stale PATH is not a failed install](#windows-branch--stale-path-is-not-a-failed-install)

## Probe contract (Step 2 item 3)

The probe is SCRIPT-OWNED: `bash "<plugin-root>/scripts/probe-tool.sh" --verify-cmd='<verify_cmd>' --tool=<id>` per tool. It owns the bound resolution, the `sh -c` wrapping, and the verdict map; its ONE output line (`<verdict> bound=<N>s rc=<rc>`) IS the verdict — NEVER hand-run a bounded probe. The contract it implements (reference — do not execute by hand): the probe MUST be bounded; resolve the bounding prefix, never type it literally at a probe site. The resolver is the prelude of the *same* Bash invocation that runs the probe loop:

```bash
# Prelude — same Bash invocation as the probes below. Shell state does NOT
# survive between tool calls, so Step 6 re-runs this prelude instead of
# referring back to this variable. Two builtins, zero forks.
if   command -v timeout  >/dev/null 2>&1; then BOUND="timeout -k 2 10"
elif command -v gtimeout >/dev/null 2>&1; then BOUND="gtimeout -k 2 10"
else BOUND=""; fi

$BOUND <verify_cmd>   # unquoted on purpose — an empty BOUND must vanish
```

**A `verify_cmd` containing a shell operator MUST be wrapped, or the bound covers only its first word-group.** Seven matrix rows read `tree-sitter --version || tree-sitter-cli --version`. Substituted bare, the shell parses `||` at the TOP level: `timeout … tree-sitter --version` is bounded, then the fallback limb runs **completely unbounded** — and because `||` yields the LAST command's status, it also swallows the 124/137 the bound just produced, so the verdict table below reads the fallback's code instead. Both halves of the protection are lost silently. When the value contains `||`, `&&`, `|`, or `;`, wrap it in one bounded shell:

```bash
$BOUND sh -c "<verify_cmd>"   # one bounded process; the operator is INSIDE the bound
```

Every value in `tool-matrix.yaml` is plain words and flags — no quotes, `$`, or backticks — so double-quoting is safe today. If a future row needs any of those, give that tool a single-command `verify_cmd` rather than escaping around this rule.

**`timeout` is not universal, and its absence is not a fact about the probed tool.** Git Bash ships MSYS2 coreutils `timeout` and Linux ships GNU coreutils, but **stock macOS ships neither `timeout` nor `gtimeout`** — `gtimeout` only appears after `brew install coreutils`. A literal prefix there makes every probe exit 127 and, under the verdict table below, reports every *installed* tool as `missing`. When `BOUND` resolves empty, state it once in the audit output and continue; probes run unbounded on that machine. **A missing bounding utility degrades the protection — it must NEVER be converted into a verdict about the probed tool.**

**Write the flag BEFORE the duration** — the reverse order is a parse error that exits 127. GNU `timeout` sends SIGTERM at expiry and then *waits* for the child; `-k 2` escalates to SIGKILL 2 s later, so the ceiling is an explicit ~12 s. Under Git Bash (MSYS2) SIGTERM **does** reach a native `.exe`: the MSYS2 runtime injects a thread that calls `ExitProcess`, then escalates to `TerminateProcess` after ~10 s. The unescalated form is therefore a **bounded ~10 s overshoot on top of the bound, not an unbounded hang**. `-k 2` is still worth keeping: it makes the ceiling a number this procedure owns and states, instead of one that depends on an MSYS2 runtime implementation detail.

**Never run `verify_cmd` unbounded when a bound resolves.** `command -v` is a builtin and cannot hang; an execution probe can, and on a corporate network a tool that checks for updates on startup will block until the proxy gives up. Measured cost of the exec probes, macOS warm — Windows + EDR is roughly an order of magnitude worse: `semgrep --version` **3.9 s**, `mmdc --version` 384 ms, `markdownlint-cli2 --version` 366 ms, everything else under 150 ms.

## Verdict map

- Exit 0 → mark `present`; capture the version from stdout best-effort.
- **Timeout — exit 124 (SIGTERM landed) OR exit 137 (the `-k` escalation had to SIGKILL) → mark `present` with a `slow-verify` note, NEVER `missing`.** `command -v` already proved the binary exists; a slow probe is not a missing tool, and treating it as one would propose a pointless reinstall of something already installed. **Both codes carry the same verdict** — a native `.exe` that ignores SIGTERM exits 137, and reading 137 as a failed probe reintroduces exactly the false-`missing` bug the bound exists to prevent.
- **Exit 127 → mark `present` with a `probe-inconclusive` note, NEVER `missing`.** `command -v` already resolved this name in step 2, so 127 cannot mean the tool is absent from PATH — it means the probe layer itself could not run: no bounding utility on this machine, flags written in the wrong order, or a shim whose interpreter is gone. Say *inconclusive*, not *working*: we did not observe the tool execute. **The absence of the bounding utility must never itself produce a `missing` verdict** — that proposes reinstalling software that is already installed.
- Exit non-zero with any OTHER code (not 124, 137, or 127) → mark `missing`.
- A memory hit from step 1 **plus** exit 0 → additionally annotate `cached-installed` (we installed it before; don't re-propose it). A memory hit NEVER skips the probe.
- **The exit code is the verdict — never gate on a stdout pattern.** `semgrep --version` prints an upgrade banner before the version, so a "does stdout look like a version" test false-fails a working tool.

## `command -v` is never sufficient (item 4)

Windows ships App Execution Alias stubs in `%LOCALAPPDATA%\Microsoft\WindowsApps` (on the default per-user PATH) that resolve, print "Python was not found…" to stderr, and exit 49. Presence ≠ usability — which is exactly why the pre-filter may only ever produce `missing`, never `present`.

## python3 — the named exception (item 5)

`python3` is the one entry in `defaults.required_tools`. Its verdict comes from the shared resolver, not a bare `verify_cmd`, because the working command name differs per install route:

```bash
$BOUND bash -c '. "<plugin-root>/scripts/_lib/resolve-python.sh" && mega_sdd_python && $MEGA_SDD_PY -V'
```

This is an execution probe like any other, so it carries the **same resolved prefix and the same carve-out** — bounded, and exit 124 / 137 / 127 never mean `missing`. It rejects any candidate under `WindowsApps` and walks `python3` → `python` → `py -3`. Exit 0 → `present`; record WHICH name resolved (a winget/python.org install ships no `python3.exe`, so `python` is the working name there). Exit non-zero with any OTHER code → `missing`, and print `mega_sdd_python_remedy` verbatim from that same file rather than composing new remedy prose.

## Verify after install (Step 6)

For each successfully-installed tool: run `verify_cmd` from the matrix entry via the SAME script as Step 2 — `bash "<plugin-root>/scripts/probe-tool.sh" --verify-cmd='<verify_cmd>' --tool=<id>` — its verdict line is final; NEVER hand-run the prelude (the §Probe contract block above is the script's contract, kept for reference — shell state does not survive between tool calls and the prefix is never hard-coded, for the same stock-macOS reason).

Report the resolved prefix the same way Step 2 does — including `none — probes unbounded` when the ladder falls through to empty. Exit 124 OR exit 137 (timeout — SIGTERM landed, or the `-k` SIGKILL escalation fired) → `verified` with a `slow-verify` note: the install just exited 0, so a slow probe is not a failed install. **Exit 127 → `verified` with a `probe-inconclusive` note, never `unverified`** — the install exited 0 and `command -v` resolves the name, so a probe layer that could not run says nothing about the install.

- Exit 0 + version capture → mark `verified`.
- Exit non-zero with any code other than 124/137/127 → **on `OS = windows-bash`, do NOT mark `unverified` yet** — go to the Windows branch below. On every other OS, mark `unverified` and add to the halt list.

## Windows branch — stale PATH is not a failed install

An installer writes `HKCU\Environment\Path`; a bash session that is already running never sees it (winget prints "restart your shell to use the new value"). So a `verify_cmd` failing here proves nothing about the install. Ask the question that does distinguish them — *will it resolve in a NEW shell?*:

```bash
bash "<plugin-root>/scripts/fix-windows-path.sh" --probe=<binary>
```

- rc 0 → mark `verified`, note "restart terminal". **Not** a halt.
- rc 3 → propose the gated PATH repair (`--ensure-dirs --dry-run` first, then `--backup-to=<project>/.mega-sdd/memory/path-backup-<ts>.txt`), re-probe, and only if it is still rc 3 mark `unverified`.
- rc 4 / rc 6 → mark `unverified` with "restart terminal and re-run".
- rc 7 → the interpreter is an MSYS2/Cygwin build with no `winreg`; nothing was read or written. Mark `unverified` and name the remedy (install Python via winget or scoop).

Full triage table, the per-installer binary locations, and the destructive methods that must never be used: `references/windows-path.md`. Manual per-tool install commands (the non-skill path, e.g. `markdownlint-cli2`): `plugins/mega-sdd/references/tooling-install.md`.
