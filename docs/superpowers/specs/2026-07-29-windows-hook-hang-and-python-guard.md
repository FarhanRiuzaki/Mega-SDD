# Spec — Windows hook hang + silent moat bypass

**Date:** 2026-07-29
**Status:** implemented (v5.4.0)
**Class:** two independent P0 defects, both Windows-only in effect, both latent on POSIX

---

## 1. Report

A team running mega-sdd on Windows 11 corporate laptops reported Claude Code sitting
"red" for tens of minutes with CPU pinned at 100%. Task Manager showed
`CSFalconService` (CrowdStrike Falcon EDR) high, **system/kernel CPU ~70%**, 148
background processes, and dozens of `bash` processes at **0% CPU**, several
`Suspended`.

Kernel-dominated CPU next to an EDR is the signature of a **process-spawn storm**,
not a compute loop. That framing drove the whole investigation.

## 2. Evidence (measured, not inferred)

Measured on the reporting machine — Windows 11 26200, MSYS2 runtime `3.6.9`,
Git for Windows `2.55.0.windows.3`, bash `5.3.15`:

```
$ time (i=0; d='C:\Users\x\proj'; while [ $i -lt 50 ]; do i=$((i+1)); d=$(dirname "$d"); done)
real 0m11.004s    user 0m2.083s    sys 0m4.637s
```

- **220 ms per iteration** (one `bash.exe` subshell fork + one `dirname.exe` exec).
- `sys` > 2× `user` — 69% of CPU time in the kernel. The EDR, not the script.
- Same loop on macOS: 18 ms/iteration. Windows is **~12× more expensive per spawn**.

```
$ dirname 'C:\Users\x' ; dirname 'C:\Users' ; dirname 'C:' ; dirname '.'
C:\Users
C:
C:          <-- FIXED POINT
.
```

```
$ command -v python3
/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/python3    -> alias stub, NOT Python
$ python3 -c 'print(1)' 2>/dev/null ; echo "=== batas ==="
=== batas ===                                                   -> stdout EMPTY (message is on stderr)
$ python3 -c 'print(1)' ; echo $?
Python was not found; run without arguments to install from the Microsoft Store...
49
```

`python3`, `python` → both alias stubs. `py` → absent. **Zero usable interpreters.**

Fork-count baseline, measured by PATH-shim tally (counts are platform-invariant;
only the per-spawn cost differs):

| Hook / trigger | external process spawns |
|---|---|
| PostToolUse / Read | 10 |
| PostToolUse / Read, non-mega-sdd project | 15 |
| PostToolUse / Write of a unit file | 134 |
| PreToolUse / Bash | 15 |
| PreToolUse / Skill `execute-bolts` | 153 |
| Stop (every turn end) | 98 |
| SessionStart | 16 |

## 3. Root cause A — unbounded walk-up loop (the hang)

`scripts/_lib/resolve-project-root.sh` — sourced by **9 hooks and 43 scripts**.

```bash
while [ "$d" != "/" ] && [ -n "$d" ]; do
  ...
  d=$(dirname "$d")        # one subshell fork + one exec, PER LEVEL
done
```

On Git Bash `dirname C:` returns `C:`. The walk from any Windows path converges to
`C:` and stops changing, while the loop condition only ever tests for `/`. The loop
**never terminates**.

It is reached from `hooks/pre-tool-use:44-53` — the "fast negative short-circuit",
which runs *before* the python3 parse specifically to make the hook cheap. That
optimization is what enters the trap, on **every** `Bash`/`Edit`/`Write`/`Skill`
tool call, inside a hook declared `async: false` — so Claude Code blocks on it.

Cost: at 220 ms/iteration against the 600 s default hook timeout, one stuck hook
spawns **~5,400 processes**, each scanned by the EDR. Per tool call.

The same defect exists on POSIX for relative inputs (`dirname a` → `.`,
`dirname .` → `.`), and is reproducible on macOS. It was never hit there because
Claude Code hands POSIX hosts absolute paths.

## 4. Root cause B — `command -v python3` is a false positive (silent moat bypass)

Windows ships App Execution Alias stubs at
`%LOCALAPPDATA%\Microsoft\WindowsApps\{python,python3}.exe`, installed by the App
Installer package (**not** by Python), in a directory on the default per-user PATH.
With no real interpreter they print to **stderr** and exit 49.

Inside every hook:

```bash
PARSE_OUTPUT=$(printf '%s' "$STDIN_JSON" | python3 -c '...' 2>/dev/null)   # EMPTY
if [ -z "$PARSE_OUTPUT" ]; then
  if ! command -v python3 >/dev/null 2>&1; then    # SUCCEEDS — the stub IS on PATH
    ... fail-closed ...                            # never reached
  fi
  exit 0                                           # every gate skipped, silently
fi
```

Net effect on the reporting machine: the binding→units gate, the CONFLICT gate,
every quality gate and anti-self-bypass **all passed without being evaluated**, with
no diagnostic anywhere. This breaks invariant #2 (`plugins/mega-sdd/CLAUDE.md`).

**Compounding:** `hooks/session-start` runs under `set -euo pipefail`. A python3
command substitution exiting 49 aborts the hook mid-way, so it emitted **0 bytes** —
the routing anchor itself never reached the model. mega-sdd was entirely inert and
said nothing about it.

Also confirmed: the stub's message goes to **stderr**, so `PARSE_OUTPUT` is empty
rather than garbage. The `eval "$PARSE_OUTPUT"` line is therefore NOT an injection
hazard on this class of machine. Recorded because it was considered and ruled out.

## 5. Fixes

### A. `scripts/_lib/resolve-project-root.sh`

1. Normalize `\` → `/` **before** any suffix arithmetic, gated on `$OSTYPE`
   (`msys*|cygwin*|win32*`) so a POSIX filename legitimately containing a backslash
   is never rewritten.
2. Terminate on a Windows drive root (`C:` / `C:/`).
3. Replace `d=$(dirname "$d")` with `d="${d%/*}"` and `$(basename "$d")` with
   `${d##*/}` — **zero forks**, where the old code cost two process operations per
   level.
4. No-progress guard (`[ "$d" = "$prev" ] && break`) — catches every fixed point,
   including ones not enumerated.
5. Iteration cap of 64 as a backstop.

Resolution semantics (substantive root, litter shadowing, greenfield fallback,
legacy layouts, nested-`.mega-sdd` guard) are **unchanged**.

### B. `scripts/_lib/resolve-python.sh` (new)

`mega_sdd_python` sets `MEGA_SDD_PY` to a usable interpreter or returns 1.
Rejects any candidate resolving under `WindowsApps` (case-insensitive), tries
`python3` → `python` → `py -3`, memoizes, and spawns **zero processes** — a command
substitution would itself be a `bash.exe` fork under Git Bash.

"First PATH hit wins" deliberately mirrors what the shell would execute: if the
alias directory precedes a real interpreter, that *name* is unusable and returning
it would hand the caller the stub.

### C. `hooks/pre-tool-use`

Fail-closed guard now asks "is there a **usable** interpreter", not "is the name on
PATH". Windows `cwd` is backslash-normalized before the `.mega-sdd` test. The deny
reason carries a keterangan + the `/mega-sdd:install-deps` remedy.

### D. `hooks/session-start`

Emits a missing-interpreter notice, then **exits cleanly** rather than letting
`set -e` abort it silently — so the anchor still reaches the model and the
degradation is stated out loud.

### E. `install-deps`

`python3` declared in `tool-matrix.yaml` as the first genuinely **required** tool,
routes web-verified against each live registry per the v5.3.1 audit lesson (that
audit found 6 already-dead routes). `defaults.required_tools: []` and its comment
"ALL tools optional; mega-sdd has graceful fallback for each" are amended — false
for the one hard dependency in the system.

The two Windows questions that gated this are now answered, and the answers changed
the remedy:

1. **Does a winget/python.org install put a `python3` command on PATH? NO.** The
   installer ships `python.exe`, `pythonw.exe`, `py.exe` only — CPython's
   `PC/layout` `alias3` option (which would emit `python3.exe`) is in **no preset**,
   and the winget manifest declares `Commands: [py, python, pythonw, pyw]`. Only the
   *Microsoft Store* package registers `python3` as an alias.
2. **Does it beat the WindowsApps alias? The question is malformed.** The installer
   does prepend its dir to PATH, but there is no `python3.exe` to override the stub
   *with*, so the lookup for `python3` walks past the real install and lands on the
   0-byte stub. **A user can `winget install` Python successfully and still be
   broken.**

Consequence: **scoop is the preferred Windows route.** Its manifest declares a real
`python3` shim (`bin: [["python.exe","python3"], …]`) and its installer *prepends*
the shims directory to PATH, so it beats the alias. Per-user, no admin, and no
Group Policy surface — unlike winget, which Policy CSP `DesktopAppInstaller` can
disable outright on a managed image. All three remedy strings name scoop explicitly.

Note the winget row still earns its place: `resolve-python.sh`'s ladder falls
through to `python`, which *is* real after a winget install — so the fail-closed
gate lifts even though the bare `python3` name stays broken. Its `verify_cmd` is
`python -V`, not `python3 -V`, for exactly that reason.

Residual gap: the ~56 hook call sites still invoke bare `python3` rather than the
resolved `$MEGA_SDD_PY`, so on a winget-only machine the hooks themselves remain
broken even though the guard now reports correctly. Tracked in §8 — until that
lands, scoop is not merely preferred on Windows, it is the only route that fully
works.

## 6. Invariant impact

| Invariant | Before | After |
|---|---|---|
| #2 CONFLICT gate blocks | silently open on any machine without a usable interpreter | fails closed, with a stated reason |
| #1/#3/#4/#5 | unchanged | unchanged |

**Behavior change worth calling out:** machines that were silently passing every
gate will now be *blocked* at `execute-bolts` until they have a working interpreter
or their blockers attest PASS. That is the correct behavior and the reason this is a
MINOR bump, not a patch.

## 7. Tests

- `tests/hooks/resolve-project-root.test.sh` — equivalence against a verbatim
  pre-fix reference implementation across 18 POSIX cases (byte-identical output);
  seven termination cases under hard timeouts (a regression **hangs**); zero-fork
  assertion with a live sentinel so a `0` cannot be vacuous.
- `tests/hooks/resolve-python.test.sh` — 10 cases including a control that proves
  `command -v python3` *is* fooled by the fixture, so the passes are meaningful.
- `tests/hooks/python-guard.test.sh` — end-to-end: PreToolUse denies `execute-bolts`
  with no usable interpreter and non-PASS blockers; does not over-block on PASS;
  SessionStart surfaces the notice with a remedy; no false alarm with a real python3.

## 8. Not in this change

Spawn-count reduction (root cause A removed the unbounded case; the 10–153
spawns/tool-call baseline remains). Tracked separately:

- `post-tool-use` pipes to `python3` at line 36 before any `.mega-sdd` check, so
  every tool call in **every** project pays an interpreter cold start.
- The Write/Edit branch fans out 6 background validators then `wait`s, on an
  `async: true` hook nobody waits for — no debounce, no concurrency cap, so trees
  pile up across consecutive tool calls.
- `validate-bolt-artifacts.sh` (51 KB) is invoked 5× in the Stop hook and 5× again
  in the PreToolUse gate, each with a different `--flag`.
- `$(cd "$(dirname "$0")" && pwd)` costs a fork in every hook; `${0%/*}` does not.
- Swapping all ~56 `python3` call sites to `$MEGA_SDD_PY` so `py -3` is actually
  *used* rather than only detected.
- No hook sets an explicit `timeout` in `hooks.json`; the default is 600 s.
