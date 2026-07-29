# Spec — `post-tool-use` dispatched on `/` globs against native paths (D2)

**Date:** 2026-07-29
**Status:** implemented (v5.7.0)
**Class:** P0. Windows-only. The PostToolUse validator tree never ran there.

---

## 1. Context

Last of the three defects opened by the 2026-07-28 Windows field report. D1 (`eval`
corrupting stdin values) shipped in v5.5.0; D3 (guards matching `/` patterns against
`os.path.relpath` output) in v5.6.0. This is **D2**, and closing it un-parks the
`write-fanout-no-megasdd-precondition` backlog item, whose premise was that these
globs work.

## 2. The defect

`hooks/post-tool-use` routes every validator through `case "$FILE_PATH"` globs
written with `/` — 12 of them — plus the own-output anti-feedback guard
(`*"/.mega-sdd/"*`) and a `DIRTY_REL="${FILE_PATH#"$PROJECT_ROOT"/}"` prefix strip.

Claude Code hands hooks **native** paths on Windows. `C:\proj\.mega-sdd\vaults\v1\units\U-001.md`
matches none of those patterns. Bash glob semantics are platform-identical, so this
reproduces exactly on any host — it is not an inference.

Consequences on Windows:

- The 6 background unit-write validators never fired: binding→units handoff,
  constitution propagation, starterkit conformance, flow-coverage,
  sibling-consistency, fan-out parity.
- The KB validators, codebase-map, binding, ui-quality, cross-cutting and
  factory-ledger dispatch never fired.
- The own-output guard leaked, so **mega-sdd journalled its own writes** into
  `.dirty-paths.jsonl` — the anti-feedback-loop the guard exists to prevent.
- `DIRTY_REL` recorded an absolute path where consumers expect a repo-relative one,
  because `PROJECT_ROOT` is `/`-normalized by `resolve_project_root` while
  `FILE_PATH` was not.

## 3. Measurement

PATH-shim exec tally on a unit write, decomposed so each layer gets the credit it
actually earns (counts are platform-invariant; only per-spawn cost differs):

| scenario | python3 execs |
|---|---:|
| POSIX baseline — `cwd=/`, `file_path=/` | 28 |
| **D2 isolated** — `cwd` normalized, `file_path` native | **11** |
| true pre-fix Windows — both native | 1 |
| fixed — both native, `OSTYPE=msys` | 28 |

**The globs alone account for 17 of the 28 dispatch steps.** The further collapse
from 11 to 1 is the `cwd`/`PROJECT_ROOT` path, addressed at the `eval` layer in
v5.5.0 and completed at the separator layer here.

## 4. Fix

One normalization, immediately after the `eval`, before any consumer:

```bash
case "${OSTYPE:-}" in
  msys*|cygwin*|win32*)
    CWD="${CWD:-}";             CWD="${CWD//\\//}"
    FILE_PATH="${FILE_PATH:-}"; FILE_PATH="${FILE_PATH//\\//}"
    ;;
esac
```

Normalizing **once, centrally** is deliberate: a per-site fix would leave the next
glob added to this file broken again. Validators receive the normalized value too,
which is strictly better — they glob with `/` as well, and python opens a
forward-slash Windows path without complaint. `$OSTYPE`-gated (a bash builtin, no
fork) so a POSIX filename legitimately containing a backslash is never rewritten.

### 4a. The near-miss — `:-` is load-bearing, not defensive noise

The file runs under `set -u`, and `FILE_PATH` is emitted **only** for Read/Write/Edit.
It is unset for every Bash, Skill and Agent call — the majority of tool calls.

- bash 3.2 (macOS, the dev machine) tolerates `${VAR//x/y}` on an unset name.
- **bash 5 treats it as an unbound-variable error, which under `set -u` kills the hook.**

Verified in Docker on `bash:5.3` — 5.3.15, the team's exact version — and then
against the real hook on bash 5.2 with `OSTYPE=msys`:

| tool call | bare form | `:-` form |
|---|---|---|
| Bash (FILE_PATH unset) | **exit 1** — `FILE_PATH: unbound variable` | exit 0 |
| Skill (FILE_PATH unset) | **exit 1** | exit 0 |
| Agent (FILE_PATH unset) | **exit 1** | exit 0 |
| Write (FILE_PATH set) | exit 0 | exit 0 |

The obvious one-line fix would have taken the hook down on 3 of 4 tool-call types,
on the exact platform this change is for, and **the dev machine could not have
noticed** — bash 3.2 passes it silently.

Also confirmed while validating the test harness: `OSTYPE` passed in the environment
IS inherited by a child bash (3.2 and 5.3 both), so the simulated-platform arms in
the test are real, not no-ops.

## 5. Invariant impact

| Invariant | Before | After |
|---|---|---|
| #2 quality-gate states (written by the PostToolUse validators) | never written on Windows — the gates read stale/absent state | written on both platforms |
| #1/#3/#4/#5 | unchanged | unchanged |

Partially mitigated before this fix by the execute-bolts gate re-deriving seven
states at gate time, which is why Windows users saw wrong-but-not-catastrophic
behavior rather than an obvious break. The advisory validators had no such backstop.

**Behavior change:** a Windows machine will now produce validator state files, and
possibly blockers, it has never produced. Those findings were always true — they
were never computed. MINOR, for the same reason v5.4.0 was.

## 6. Tests

`tests/hooks/post-tool-use-windows-paths.test.sh`.

A Windows path is simulated on POSIX by building the fixture at a real path and
sending that same path with `/` replaced by `\` — exactly what Windows would send
for that file. With `OSTYPE=msys` the hook normalizes it back, so dispatch is
observed end-to-end on a real filesystem.

- **A** — the Windows-shaped write reaches the same dispatch tree as the POSIX one
  (28 == 28).
- **B** — control: un-normalized, the same payload dispatches 1.
- **B2** — isolation: `cwd` clean, `file_path` native → 11, so the globs alone
  account for 17 of 28. Keeps the spec's claim honest rather than attributing the
  whole collapse to this defect.
- **C** — the hook exits 0 for Bash/Skill/Agent calls, where `FILE_PATH` is unset.
  On CI (bash 5) this is a live check for §4a; on macOS bash 3.2 it cannot fail,
  which is exactly why **D** also asserts the `:-` shape in the source, and that the
  normalization precedes the first `case "$FILE_PATH"`.

## 7. Follow-up now unblocked

`write-fanout-no-megasdd-precondition` (v5.4.0 spec §8, ~120 spawns) was parked
because its premise — that the `$FILE_PATH` globs work — was false. It now holds.
Re-scope it against the note recorded there: `validate-unit-spec.sh:325-342` reads
arbitrary source files to line-count a `path:line` grounding anchor, so it cannot be
gated to artifact-only writes on the same argument as the other six validators.
