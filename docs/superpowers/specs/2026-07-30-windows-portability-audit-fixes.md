# Spec — Windows portability audit fixes (v5.12.0)

**Status:** implemented
**Date:** 2026-07-30
**Audit this traces to:** [`research/2026-07-29-windows-portability-audit.md`](../../../research/2026-07-29-windows-portability-audit.md)

## Why

A six-finder audit swept the plugin's whole transitive closure — `SKILL.md` → `references/`
→ `scripts/` → `_lib/` → `hooks/` — for Windows/Git-Bash failure modes and produced 27
findings that survived adversarial refutation (4 `hang`, 7 `silent-wrong`, 13 `degraded`,
3 `cosmetic`).

This spec covers the five that were **safely verifiable from macOS**. The rest are recorded
in the audit; the ones tagged `NEEDS-WINDOWS` are collected there as a single Git Bash
script for the team to run once.

Deliberately **not** in scope: `scripts-hardcode-python3-no-resolver` (84 of 94 scripts
hardcode `python3`, one consumes `$MEGA_SDD_PY`), which is the audit's worst finding but a
much larger change than an audit-response batch should carry.

## The five changes

### 1. `.gitattributes` — `crlf-no-gitattributes`

The install path is a `git clone` (verified: `~/.claude/plugins/marketplaces/mega-sdd/.git`,
remote `FarhanRiuzaki/Mega-SDD.git`), `core.autocrlf` is unset there so it inherits the
machine's global config, and no `.gitattributes` existed anywhere. Git for Windows' default
installer option is `core.autocrlf=true`.

Measured effect of CRLF on these scripts — three independent breakages from one file:
`set -u\r` → `set: -: invalid option`; `case "$1" in\r` → syntax error; and a heredoc
terminator `PYEOF\r` never matching `<<'PYEOF'` (the plugin has 124 heredocs across 87
files). Under real bash 5.3, `hooks/run-hook.sh` exits **RC=2 dispatching nothing.**

`* text=auto eol=lf`, **not** `*.sh` — the eight hook entry points are extensionless. The
binary list was derived by probing every tracked file, not guessed.

**Limit, stated because it matters:** adding `.gitattributes` does not renormalize an
existing clone. A machine already holding CRLF must re-clone the plugin cache.

### 2. Bounded subprocess calls in `scripts/*.sh` — `preflight-astgrep-unbounded-twin`

`run-preflight-scan.sh:225` ran a repo-wide `ast-grep scan` per v2 Hard rule, per unit,
unbounded — while its byte-identical twin at `_lib/postflight_rules.py:547` was bounded in
v5.10.0 with the rationale written in the repo itself. `execute-bolts/SKILL.md:59` makes
this a mandatory per-unit call and `:130` forbids skipping it.

**Why v5.10.0 missed it, which is the more useful lesson:**
`tests/hooks/bounded-subprocess.test.sh` globbed `scripts/_lib/*.py` only. Python embedded
as heredocs inside `.sh` files was never parsed — 13 `subprocess.run` calls, 12 unbounded,
invisible to the guard written specifically to prevent this class. The matcher now also
extracts heredoc Python from `scripts/*.sh` and from the extensionless files in `hooks/`.

*A guard whose scope is narrower than the class it claims to cover reports green forever.*

### 3. Spawn-cost gate for `generate-units` Step 7.5 — `pagerank-symbolgraph-ungated`

Step 7.5 rebuilt a full-repo tree-sitter symbol graph with no gate; tree-sitter spawns one
process per FILE, so 10,000 files is ~37 min at the measured 220 ms/spawn while the prose
documented "~5-10s" (a POSIX-calibrated figure, now removed).

Mirrors the shipped scan-codebase gate: `N × per_spawn`, 60 s threshold, AskUserQuestion
with keterangan per option, no silent engine downgrade, plus an `--auto` policy so the gate
is not a no-op in the autonomous lane.

**`N` has exactly one owner** (`references/pagerank-targeting.md §Spawn-cost gate`) and a
two-tier source: **Tier 1** reads scan-codebase's persisted enumeration
(`.mega-sdd/codebase/.scan/files.z`, one spawn, exact); **Tier 2**, only when that file is
absent, falls back to `codebase-map.md` §2 as a **FLOOR** with the `truncated_sections`
rail. The branch condition is repeated inline at both decision surfaces on purpose — an
agent that runs Step 7.5 without loading the reference would otherwise read a capped §2,
land under 60 s, and build.

### 4. Batched hashing for `--shallow-scan` — `shallow-scan-hash-fanout`

The invalidation gate is pure prose (no script implements it), and it said "compare each
source file's sha256" with no batching instruction — one spawn per file, *before* the
v5.11.0 spawn-cost gate's `N` even exists. Measured: 2,000 files = 2,000 spawns / 50,413 ms
per-file vs 1 spawn / 319 ms batched (**158×**). Under EDR a hash spawn costs the same
~220 ms as a tree-sitter spawn, so the unbatched "fast path" burned 2,000 spawns to avoid
1,990 — net-negative on Windows.

Now: one batched `xargs -0` invocation reading a persisted enumeration, the hashing folded
into the gate's estimate (`N_hash + N_extract`), and the Windows net-negative stated so the
model can advise correctly.

**The enumeration walk was also under-pruning.** `-path './node_modules' -prune` anchors at
the repo root, so a monorepo's `packages/*/node_modules/` and `sub/vendor/` were enumerated
and hashed. Proven with a scratch repo; changed to `-type d -name` pruning at both walk sites.

### 5. `timeout -k` and a resolved bounding prefix — `timeout-without-k-native-windows-child`

Three prose sites carried a bare `timeout 10`. GNU `timeout` sends SIGTERM then **waits**;
`-k` is the escalation to SIGKILL.

**Severity is `degraded`, not `hang`** — the audit verified against primary sources
(cygwin.com `kill` docs; `git-for-windows/msys2-runtime` PR#15, PR#16, commit `c967bd8`)
that MSYS2 injects an `ExitProcess` thread and escalates to `TerminateProcess` after ~10 s.
SIGTERM lands; the worst case is a bounded ~10 s delay. `-k 2` is kept because it makes the
ceiling explicit and immediate rather than relying on that escalation.

Two further defects fixed at the same sites:

- **Stock macOS ships neither `timeout` nor `gtimeout`.** A literal prefix returns rc 127,
  which the verdict table routed to `missing` — every *installed* tool reported missing.
  Live since v5.9.0. Now a three-limb resolver (`timeout` → `gtimeout` → empty) re-run per
  Bash invocation, and **the absence of the bounding utility can never become a verdict
  about the probed tool.**
- **A compound `verify_cmd` escaped the bound.** Seven matrix rows read
  `tree-sitter --version || tree-sitter-cli --version`; substituted bare, the shell parses
  `||` at the top level, so only the first limb is bounded, the fallback runs unbounded, and
  `||` returns the *last* status — swallowing the 124/137 the bound just produced. Wrapped
  as `$BOUND sh -c "<verify_cmd>"`.

## Verification

Every fix carries a test with a control and a vacuity guard. Two rounds of adversarial
review ran over the patches; both found real defects the implementers had introduced, and
those were repaired.

Two tests were strengthened past their assignment because a reviewer proved they could be
defeated:

- `test-shallow-scan-hash-batching.sh` accepted `xargs -0 -n1` (one hasher process per path
  — the exact fan-out it exists to forbid, reintroduced by a two-character edit) and a
  `hash_one() { sha256sum "$1"; }` wrapper called from a loop. Both now fail; `-n 128`
  still passes, so a legitimate chunked batch is not a false positive.
- `test-pagerank-spawn-gate.sh` gained a **cross-file control**. An earlier revision of
  `pagerank-targeting.md` claimed files.z "lives in a `mktemp -d` scratch file … gone by the
  time this skill runs", while `scan-procedure.md` says in bold that it is written to a
  deterministic path and explicitly *not* a `mktemp`. The test asserted only that the
  citation existed, never that it matched the cited file — so a fabrication sat green.
  Invariant 5 is only enforced if something reads **both ends** of a citation.

## What this batch does not close

- `scripts-hardcode-python3-no-resolver` — the audit's worst finding, live today.
- The `hooks/` invocations of `validate-bolt-artifacts.sh` are `>/dev/null 2>&1 || true`,
  so a non-zero exit is discarded and the aggregator reads the previous state file.
- `hooks.json` declares no explicit `timeout` on any hook.
- Every `NEEDS-WINDOWS` item in the audit remains unproven; no Windows machine was
  available. Wall-clock figures are projections from platform-invariant spawn counts times
  the measured 0.22 s/spawn oracle.
