# Spec — hook guards matched `/` patterns against OS-native paths (D3)

**Date:** 2026-07-29
**Status:** implemented (v5.6.0)
**Class:** P0. Invariant #2 — the forged-gate-verdict protection did not exist on Windows.

---

## 1. Context

`2026-07-29-hook-stdin-eval-quoting.md` §5 recorded two Windows separator defects
that were *reachable* once `eval` stopped corrupting the values, and deliberately
left them out of v5.5.0 so any field-reported behavior change could be attributed
to exactly one release. This is **D3**. D2 remains open.

## 2. The defect

Two guards in `hooks/pre-tool-use` derive a project-relative path with
`os.path.relpath` and then match it against **forward-slash** patterns.
`os.path.relpath` returns **OS-native** separators.

### 2a. Anti-self-bypass Write/Edit guard

```python
rel = os.path.relpath(p, root)
...
if any(rel == ".mega-sdd/" + g or rel.endswith("/.mega-sdd/" + g) for g in _GUARDED):
    print("protected")
elif re.search(r"(?:^|/)(?:\.mega-sdd/vaults/[^/]+|…)/bolts/…", rel):
    print("evidence")
```

On Windows `rel` is `.mega-sdd\.validation-blockers.json`. Neither equality, the
`endswith`, nor the evidence regex can match. **Every** forged gate verdict passes:

| write target | POSIX | Windows (pre-fix) |
|---|---|---|
| `.mega-sdd/.validation-blockers.json` | blocked | **allowed** |
| `.mega-sdd/.unit-spec-state.json` | blocked | **allowed** |
| `<vault>/bolts/U-001/postflight.json` (B1) | blocked | **allowed** |
| `<vault>/bolts/_batch-suite.json` (B2) | blocked | **allowed** |

There is **no input shape that worked**. A model sending a forward-slash path does
not rescue it — `ntpath.abspath` re-normalizes to backslashes before `relpath` runs.

The `tests|examples|fixtures` exemption above it fails the same way, which is
fail-*closed* (over-blocking) and therefore much less severe, but it is the same bug.

### 2b. LOCKED-index guard

`.mega-sdd/.locked-index.json` is a **committed, team-shared** artifact. Its keys
were written with `os.path.relpath` (`build-locked-index.sh`) and looked up with
`os.path.relpath` (`pre-tool-use`). Consistent on one machine, broken across a
mixed team: an index built on macOS carries `src/app/Legacy.php`, a Windows
teammate looks up `src\app\Legacy.php`, the lookup misses and the LOCKED guard goes
inert for that teammate. The reverse breaks the macOS devs.

This one is not Windows-only — it is a **shared-artifact portability** bug that a
single-platform team would never see.

## 3. Fix

Normalize to `/` at all three sites, guarded on `os.sep` so a POSIX filename
legitimately containing a backslash is never rewritten:

```python
if os.sep != "/":
    rel = rel.replace(os.sep, "/")
```

- `hooks/pre-tool-use` — anti-self-bypass guard, **before** the exemption test so
  that exemption is fixed too.
- `hooks/pre-tool-use` — LOCKED-index lookup.
- `scripts/build-locked-index.sh` — key writer, making the committed artifact
  platform-neutral (`/` is also the natural JSON convention). Writer and consumer
  now normalize identically, so an index is portable in both directions.

No behavior change on POSIX: `os.sep == "/"` makes every one of these a no-op.
Verified end-to-end against the real hook — the three forged artifacts still DENY
and an ordinary source write still passes.

## 4. Invariant impact

| Invariant | Before | After |
|---|---|---|
| #2 anti-self-bypass (forged gate verdict) | **absent on Windows** — every guarded state and evidence artifact writable | enforced on both platforms |
| #4 LOCKED mutability tier | guard inert for any teammate on the other OS | enforced from a portable index |
| #1/#3/#5 | unchanged | unchanged |

**Behavior change worth calling out:** a Windows machine that has been freely
writing gate state files will now be blocked. Those writes were always violations —
they were simply never detected. MINOR, not patch, for the same reason v5.4.0 was.

## 5. Tests

`tests/hooks/guard-path-separators.test.sh` — the technique matters as much as the
cases: **`ntpath` is Python's Windows path module and imports on any platform**, so
`ntpath.abspath`/`ntpath.relpath` reproduce exact Windows semantics from macOS. No
Windows machine, no CI runner, no emulation.

- **A** — 9 write targets × {posix, windows} produce identical verdicts, including
  the `tests/` exemption.
- **B** — control: without the normalization, all 4 forged artifacts are UNBLOCKED
  under Windows semantics, and a forward-slash input does not rescue it. A is
  therefore not vacuous.
- **C** — anti-drift: the test transcribes the guard logic, so it asserts the
  shipped hook still carries the exact tokens it transcribed (and that there are
  **two** normalization sites). A transcription that drifts from its source stops
  testing anything, silently.
- **D** — a Windows lookup hits a POSIX-built index; pre-fix it missed.

## 6. Still open

**D2** — `post-tool-use` has 12 `case "$FILE_PATH"` globs written with `/`, which
match no native Windows path, disabling the 6 background unit-write validators, the
KB validators, codebase-map, binding, ui-quality, cross-cutting and factory-ledger
dispatch, plus the own-output anti-feedback guard (so mega-sdd journals its own
outputs) and `DIRTY_REL`'s prefix strip. `write-fanout-no-megasdd-precondition`
stays parked until D2 lands — see the v5.4.0 spec §8.
