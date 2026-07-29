# Spec — install-deps on Windows: PATH staleness, presence-vs-usability, winget source

**Date:** 2026-07-30
**Status:** implemented (v5.8.0)
**Class:** four independent defects on one platform. Three make install-deps report the wrong answer; one makes it unable to install at all.

---

## 1. Report

A team laptop — Windows 11, Git Bash, winget, PowerShell blocked by Group Policy,
CrowdStrike EDR — ran `/mega-sdd:install-deps`. Two distinct failures, one after the
other:

1. The first install attempt failed outright with exit 248 and 94.
2. After a retry succeeded, **every install exited 0 and every `verify_cmd` still
   failed.** The audit had also reported `python3` as *present* when there was no
   Python on the machine at all.

## 2. Defect A — a stale PATH is not a failed install

An installer writes `HKCU\Environment\Path`. A bash session that is **already
running** never sees it; its environment block was copied at process creation.
winget says so itself: *"Path environment variable modified; restart your shell to
use the new value."*

So on Windows a `verify_cmd` failing immediately after an install carries **no
information** about whether the install worked. install-deps nonetheless marked
those tools `unverified` and raised `install_failed`.

Compounding it, three installer families use directories that are never added to
PATH at all:

| installer | binary lands in | on PATH? |
|---|---|---|
| `winget install <pkg>` | `%LOCALAPPDATA%\Microsoft\WinGet\Packages\<PkgId>_<src>\` | new shells only |
| `winget install Python.Python.3.x` | `%LOCALAPPDATA%\Programs\Python\Python3<XY>\` | new shells only; ships `python.exe`, never `python3.exe` |
| `pip install --user <pkg>` | `%APPDATA%\Roaming\Python\Python<XY>\Scripts\` | **no** — a different dir from the main install's `Scripts` |
| `pipx install <pkg>` | `%USERPROFILE%\.local\bin\` | **no** |
| `npm install -g <pkg>` | `%APPDATA%\Roaming\npm\` | usually yes |

## 3. Defect B — `verify_cmd` tested presence, not usability

**39 of the 46 `verify_cmd` values in `tool-matrix.yaml` were literally
`command -v <tool>`.** "Run verify_cmd" and "test presence" were therefore the same
operation for every tool except `python3`. That is why the field output read
`✓ jd (command -v jd — RC=0)`.

It is also the mechanism behind the `python3` false positive: Windows ships App
Execution Alias stubs in `%LOCALAPPDATA%\Microsoft\WindowsApps` which sit on the
default per-user PATH, resolve to `command -v`, print *"Python was not found…"* to
stderr and exit 49. v5.4.0 fixed this for the **hooks** (`resolve-python.sh`); the
**audit** was never updated.

`SKILL.md:64` compounded it by offering `command -v <tool>` as the memory fast-path
check with `verify_cmd` only as a parenthetical "alternate".

## 4. Defect C — winget's msstore source kills the whole command

Verified against the winget-cli source, not inferred from the error text:
`winget install` is the one search command that does **not** set
`ContextFlag::TreatSourceFailuresAsWarning`, so `HandleSearchResultFailures` takes
the error branch and calls `SetTerminationHR` with the first failing source's
HRESULT — even though it also sets `ShowSearchResultsOnPartialFailure` and prints
the matches it *did* find in the `winget` source.

- `0x8A15005E` = `APPINSTALLER_CLI_ERROR_PINNED_CERTIFICATE_MISMATCH`. winget pins
  the msstore REST endpoint's certificate; a TLS-inspecting corporate middlebox
  breaks that pin **permanently**, so msstore will keep failing on this network.
- `0x801901F8` = the `FACILITY_HTTP` encoding of HTTP 504.
- Exit 248 and 94 are **not** winget codes: they are POSIX `WEXITSTATUS` low-byte
  truncations of those two HRESULTs. Two failures, not four.

The operator's `--source winget` workaround is correct and officially documented —
but their stated reason ("source ambiguity") is wrong. Genuine ambiguity has its own
code (`0x8A150016`), which never appeared. The real reason makes the fix stronger:
pinning the source also skips the msstore metadata refresh entirely, because a
source is only update-checked when it is used.

## 5. Defect D — the scoop remedy is unreachable where it is most needed

`tool-matrix.yaml` calls `scoop install python` "the ONLY package-manager route that
yields a working `python3`", and every fail-closed message (`session-start:197`,
`pre-tool-use:130`, `resolve-python.sh:116`) steers there. But scoop's official
bootstrap is **PowerShell-only** (`irm get.scoop.sh | iex`). On the reporting
laptop PowerShell is blocked by policy, so the sole documented remedy could not be
followed — and nothing said so.

## 6. Fixes

### A. `scripts/_lib/windows_path.py` + `scripts/fix-windows-path.sh` (new)

`--probe=<binary>` answers *"will this resolve in a NEW shell?"* by composing the
persisted system + user PATH from the registry. rc 0 → the install worked and the
shell is merely stale (report `verified`, say "restart the terminal"); rc 3 → a real
gap. `--ensure-dirs` prepends the never-on-PATH directories, idempotently.

Registry access uses `winreg.QueryValueEx`/`SetValueEx` — never `reg query`
parsing, never `reg add`, never `.reg` import, never `setx` (§7).

Two deliberate design points:

- **Path STRINGS are normalised with `ntpath`, not `os.path`.** These values always
  come from the Windows registry, but `os.path` is whatever the *running*
  interpreter uses; under a Cygwin/MSYS Python that is `posixpath`, where a
  backslash is an ordinary character. There `normpath(r"C:\x\bin\")` is a no-op and
  the dedupe fails silently, appending the same directory on every run. Filesystem
  *access* still uses `os.path`, which is what the interpreter can actually open.
- **A bash bootstrap for the chicken-and-egg case.** The tool most likely missing
  from PATH is `python3` itself, and the module needs a Python to read the registry.
  When `resolve-python.sh` finds nothing on PATH, the script probes the known
  absolute install roots directly and re-execs. Without this the feature is
  unavailable in exactly the scenario that motivated it.

### B. `SKILL.md` Step 2 — usability is the only route to `present`

`command -v` may now only ever produce `missing`, never `present`. It is retained as
a cheap fork-free **pre-filter** — a name absent from PATH is conclusively missing,
and skipping the exec probe there matters on an EDR box at ~220 ms/spawn. All 39
`verify_cmd` values become execution probes; `--version` was measured rc 0 on all
nine tools. **The exit code is the verdict, never a stdout pattern** — `semgrep
--version` prints an upgrade banner ahead of the version. `python3`'s verdict comes
from `mega_sdd_python`, reusing `mega_sdd_python_remedy` verbatim.

### C. `SKILL.md` Step 6 — the Windows branch

On `os = windows-bash`, a failing `verify_cmd` routes through the probe before any
verdict. New halt **subtype** `path_stale_pending_restart`; no new halt id.

### D. `tool-matrix.yaml` — `--source winget` on all 7 winget routes

Inserted immediately after the `install` verb, every existing flag preserved.

### E. The scoop precondition, stated

Recorded in `tool-matrix.yaml`'s python3 scoop note and in
`os-detection.md`'s remedy: where PowerShell is blocked, scoop cannot be
bootstrapped and winget is the only route — verifying `python`, not `python3`.

`plugins/mega-sdd/references/tooling-install.md` also carried a stale claim ("add a
`python3` alias/shim"), contradicted by the shipped resolver; corrected, and given
the host-side `CLAUDE_CODE_GIT_BASH_PATH` note (§8).

## 7. Methods banned outright

Each was observed to fail **destructively** on the reporting machine, and each
looks like it worked:

- `reg add "HKCU\Environment" /v Path …` from Git Bash — the `reg` parser mangles
  backslashes and semicolons; prints `ERROR: Invalid syntax` **while returning
  RC=0**. Writes nothing, or partially.
- A hand-written `.reg` + `reg import` — a wrong `hex(2)` UTF-16LE encoding imports
  "successfully" while storing a corrupt value. **Observed: a 798-character USER
  PATH truncated to 92 characters.**
- `setx PATH` — truncates at 1024 characters and expands `%VAR%`, destroying
  `REG_EXPAND_SZ`.

These are encoded as anti-hallucination rails 8-11, not merely documented, because
prose that says "don't" enforces nothing.

## 8. Explicitly NOT a plugin concern

The operator also hit `EUNKNOWN: unknown error, uv_spawn` on `powershell.exe`.
mega-sdd is not the cause: all 9 `hooks.json` entries invoke `bash` explicitly, the
one `powershell` line in `run-hook.sh` is guarded by `[ -f "${HOOK_PATH}.ps1" ]` and
no `.ps1` ships. Claude Code enables its PowerShell tool automatically on Windows
when it cannot find Git Bash. Host-side fix, recorded in `tooling-install.md`:
`CLAUDE_CODE_GIT_BASH_PATH` + `CLAUDE_CODE_USE_POWERSHELL_TOOL: "0"`.

Generic `OTEL_*` settings **cannot** cause this — they are HTTP export config. (One
OTel-adjacent key, `otelHeadersHelper`, *is* documented to spawn a shell on Windows,
but it does not match the reported error.)

## 9. Tests

- `tests/derived-artifacts/test-verify-cmd-usability.sh` — no `verify_cmd` may be a
  bare PATH lookup; all 46 carry an execution probe; a `python -V` route exists; and
  a control replays the historical `command -v jd` shape and requires a catch.
  `test-tool-matrix.sh` is structural and never inspected `verify_cmd` *values*,
  which is why this defect could persist unseen.
- `tests/windows/test-windows-path.sh` — `winreg` is Windows-only, so the test
  injects a fake that **records** reads and writes: idempotence, no-write-on-no-op,
  `REG_EXPAND_SZ` preserved, `%USERPROFILE%` left unexpanded, trailing-separator
  dedupe, system-then-user ordering, and a simulated truncating write that must
  RAISE. Plus a control proving the fake registers writes at all, so the
  "no write happened" assertions cannot pass vacuously.

## 10. Not verified here

No Windows machine was available. The `winreg` write path, `py -3`, the scoop
`python3` shim, and `tree-sitter-cli --version` are exercised against fakes, upstream
documentation and source — not against the real platform. The nine `--version` exit
codes WERE measured locally. This is stated plainly rather than implied.
