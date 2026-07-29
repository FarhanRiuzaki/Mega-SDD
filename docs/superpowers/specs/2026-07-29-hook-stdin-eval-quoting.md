# Spec — hook stdin values are re-parsed by `eval`

**Date:** 2026-07-29
**Status:** implemented (v5.5.0)
**Class:** P0. Silent data corruption at the hook input boundary. Windows-fatal, POSIX-partial, plus a command-execution surface.

---

## 1. How it was found

While scoping the spawn-reduction backlog item `write-fanout-no-megasdd-precondition`
(spec `2026-07-29-windows-hook-hang-and-python-guard.md` §8), the precondition under
consideration was a glob on `$FILE_PATH`. Checking whether that glob could work on
Windows exposed the layer beneath it: `$FILE_PATH` does not hold what the JSON said.

## 2. The defect

Four hooks parse their stdin JSON in python and print `KEY=value` lines, which bash
then consumes with `eval`:

```bash
PARSE_OUTPUT=$(printf '%s' "$STDIN_JSON" | python3 -c '... print(f"CWD={cwd}") ...')
eval "$PARSE_OUTPUT"
```

`eval` **re-parses** each line as shell source. A bare `KEY=value` therefore goes
through word-splitting, backslash removal, globbing and command substitution.

Measured on bash 5, 2026-07-29:

| input line | resulting variable | |
|---|---|---|
| `FILE_PATH=/Users/me/My Docs/x.md` | **unset** | prefix-assignment + a failed command |
| `FILE_PATH=C:\proj\.mega-sdd\x.md` | `C:proj.mega-sddx.md` | every `\` eaten |
| `FILE_PATH=/tmp/$(touch ./PWNED)n.md` | `/tmp/n.md` | **and `./PWNED` is created** |

Affected hooks and fields:

| hook | fields through `eval` |
|---|---|
| `pre-tool-use` | `CWD`, `TOOL_NAME`, `TRANSCRIPT_PATH`, `SKILL_NAME`, `SESSION_ID` |
| `post-tool-use` | `CWD`, `TOOL_NAME`, `FILE_PATH`, `SKILL_NAME`, `AGENT_SUBAGENT_TYPE`, `AGENT_DESCRIPTION`, `SESSION_ID` |
| `stop` | `CWD`, `TRANSCRIPT_PATH`, `SESSION_ID`, `HOOK_EVENT`, `STOP_HOOK_ACTIVE` |
| `user-prompt-submit` | `CWD`, `TRANSCRIPT` |

`file_path` / `command` / `args` in `pre-tool-use` were already on a base64 channel
and were never affected — that precedent shows the hazard was understood for the
*obviously* hostile fields and simply not generalized. `stop:51` even carried the
comment *"eval needs key=value with no shell metacharacters; gate it"*; the gating
was never implemented.

## 3. Consequences

**Windows — the plugin is inert.** `cwd` arrives native (`C:\Users\me\proj`), so
`CWD` became `C:proj`. `resolve_project_root` has no separator to walk, `PROJECT_ROOT`
is garbage, no `.mega-sdd` is ever found. Every validator is invoked with a
nonexistent `--cwd`, every state file path is wrong, telemetry is written nowhere.
This sits **behind** the v5.4.0 `python3` guard: a team that follows the v5.4.0
remedy and installs Python still gets a plugin that does nothing.

**POSIX — silent partial loss.** Any path containing a space yields `FILE_PATH`
unset, and `post-tool-use` line 411 (`[ -z "$FILE_PATH" ] && exit 0`) then no-ops
the entire Write/Edit branch. Every validator dispatch is skipped for that write,
with no diagnostic. `AGENT_DESCRIPTION` is arbitrary model prose and effectively
always contains spaces.

Measured with a PATH-shim exec tally, writing a unit file inside a project at
`…/My Project/` (one space, an ordinary macOS/Windows folder name):

| write target | before | after |
|---|---:|---:|
| unit file under `…/My Project/` (one space) | **1** — the stdin parse, then `exit 0` | **28** |
| same unit file, no space in any path | 28 | 28 |

The 27 that never ran are the entire PostToolUse contribution for that write. The
after-figure matching the no-space case *exactly* is the point: the fix restores
identical behavior on the broken path, it does not introduce new behavior on the
working one.

**Execution surface.** A `file_path` containing `$(…)` or backticks is executed by
the hook, at hook privilege. Reached whenever such a path is written — no
adversary required, though it is trivially reachable by one.

## 4. Fix

Quote at the **producer**, where the value is still structured data:

```python
def emit(key, value):
    print(key + "=" + shlex.quote(str(value)))
```

`shlex.quote` is stdlib, costs no process, and produces POSIX shell quoting that
`eval` reverses exactly. `eval` is retained — the vulnerability was never `eval`
itself, it was handing `eval` unquoted input. Routing every field through a single
`emit()` also makes it structurally hard to reintroduce: a new unquoted field now
has to bypass the helper rather than merely follow the surrounding style.

Applied to all four hooks. The base64 channels are left as they are.

**One hardening to v5.4.1's own code, same class.** The `post-tool-use` fast-negative
short-circuit reads `cwd` from the raw JSON by taking the FIRST `"cwd"` in the
document. That is the top-level key for every payload Claude Code emits, but key
order is not a guarantee, and a `tool_input` value containing the literal `"cwd"`
earlier in the document would produce a garbage `SC_CWD` whose resolved root has no
`.mega-sdd` — a silent `exit 0` on a real mega-sdd project. It now short-circuits
only when `[ -d "$SC_CWD" ]`, so an unverifiable cwd falls through to the
authoritative parse instead. Fail-safe rather than fail-open, at zero fork cost.

## 5. Deliberately NOT in this change

**Separator normalization.** Two further Windows defects are now *reachable* but
were not touched here, so the field can attribute any behavior change to exactly
one commit:

- **D2** — `post-tool-use` has 12 `case "$FILE_PATH"` globs written with `/`. A
  native Windows path matches none of them, so the 6 backgrounded unit-write
  validators, the KB validators, codebase-map, binding, ui-quality, cross-cutting
  and factory-ledger dispatch never fire. The own-output guard
  (`*"/.mega-sdd/"*`) is also inert, so mega-sdd journals its own outputs, and
  `DIRTY_REL="${FILE_PATH#"$PROJECT_ROOT"/}"` leaks an absolute path.
- **D3** — `pre-tool-use`'s anti-self-bypass Write/Edit guard matches
  forward-slash patterns against `os.path.relpath` output. Proven with `ntpath`
  (Windows path semantics, runnable anywhere): for
  `C:\proj\.mega-sdd\.validation-blockers.json` the guard reports **inert**, and
  it stays inert when the model sends a forward-slash path because
  `ntpath.abspath` normalizes to backslashes regardless. **On Windows the forged-
  gate-verdict protection does not exist** — invariant #2.

**`write-fanout-no-megasdd-precondition`** (the ~120-spawn backlog item this
investigation started from) is **parked, not deferred**: its premise is that the
`$FILE_PATH` globs work, and D2 shows they do not on the target platform. It
cannot be scoped correctly until D2 lands. Re-rank it only after that.

## 6. Invariant impact

| Invariant | Before | After |
|---|---|---|
| #2 CONFLICT gate blocks | on Windows: never evaluated (PROJECT_ROOT garbage → no project found) | evaluated; D3 still open for the Write/Edit forge guard |
| #1/#3/#4/#5 | unchanged | unchanged |

**Behavior change worth calling out:** on POSIX, writes to paths containing a space
previously skipped the entire PostToolUse Write/Edit branch. They now run it. A
project with spaces in its paths will see validator state files appear, and
possibly blockers, that it never saw before. Those blockers were always true — they
were simply never computed. This is why the bump is MINOR.

## 7. Tests

`tests/hooks/hook-stdin-quoting.test.sh`:

- **A** round-trip: Windows path, space path, `$(…)` path and a multi-line
  quote/tab/`$HOME`/backtick description each survive `eval` byte-identically.
- **B** control: the verbatim pre-fix producer corrupts all three, so A is not
  vacuous. Both producers are written to **files** — nesting the control inside
  shell quoting made it a syntax error during development, which silently turned
  "control fails" into "control emitted nothing", and the harness now asserts
  each producer emits 3 lines before any assertion runs.
- **C** the `$(…)` path is not executed, with a live sentinel proving the pre-fix
  producer *does* execute it.
- **D** no hook retains a bare `KEY=` emission, and every one imports `shlex`.
- **E** on a Windows-shaped payload, `PROJECT_ROOT` (via eval'd `CWD`) and the
  v5.4.1 short-circuit's `SC_ROOT` (via raw-JSON parameter expansion) resolve to
  the same root. Before this fix they could not diverge only because one was
  garbage; now that both work, the agreement needs pinning.
