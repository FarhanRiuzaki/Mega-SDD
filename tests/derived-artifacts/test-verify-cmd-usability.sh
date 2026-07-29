#!/usr/bin/env bash
# test-verify-cmd-usability.sh
#
# Guards the ONE invariant that decides whether install-deps can tell a working
# tool from a broken one:
#
#     a `verify_cmd` must EXECUTE the tool, never merely look it up on PATH.
#
# Why this needs a mechanical guard rather than prose. Before 2026-07-30, 39 of the
# 46 `verify_cmd` values in tool-matrix.yaml were literally `command -v <tool>`.
# That made "run verify_cmd" and "test presence" the same operation for every tool
# except python3 — so the audit reported `✓ jd (command -v jd — RC=0)` and, more
# damagingly, reported a real interpreter for a Windows App Execution Alias stub
# that resolves on PATH, prints "Python was not found…" to stderr, and exits 49.
# A field run on a Windows 11 + Git Bash laptop shipped that false positive.
#
# `test-tool-matrix.sh` is structural — it checks that `verify_cmd` EXISTS, never
# what it contains — so nothing in the suite catches a regression here. This does.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX="$HERE/../../plugins/mega-sdd/skills/install-deps/references/tool-matrix.yaml"
rc=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; rc=1; }

[ -f "$MATRIX" ] || { echo "FAIL: matrix not found at $MATRIX"; exit 1; }

echo "verify_cmd usability invariant"

# ── 1. no verify_cmd may be a bare PATH lookup ───────────────────────────────
# `command -v` is permitted INSIDE a compound probe only if the command is also
# executed; the cheap way to express that invariant is "the value must not START
# with a lookup", since a lookup that runs first and short-circuits is exactly the
# presence test we are banning.
bad=$(grep -n 'verify_cmd:' "$MATRIX" | grep -E 'verify_cmd: *"(command -v|which |type )' || true)
if [ -z "$bad" ]; then
  pass "no verify_cmd is a bare PATH lookup (command -v / which / type)"
else
  fail "verify_cmd values that only test PRESENCE, not usability:"
  printf '%s\n' "$bad" | sed 's/^/      /'
fi

# ── 2. every verify_cmd must actually run something ──────────────────────────
total=$(grep -c 'verify_cmd:' "$MATRIX")
execish=$(grep 'verify_cmd:' "$MATRIX" | grep -cE '(--version|-V\b| version\b|-v\b)' || true)
if [ "$total" -gt 0 ] && [ "$execish" -eq "$total" ]; then
  pass "all $total verify_cmd values carry an execution probe"
else
  fail "only $execish of $total verify_cmd values look like an execution probe"
  grep -n 'verify_cmd:' "$MATRIX" | grep -vE '(--version|-V\b| version\b|-v\b)' | sed 's/^/      /'
fi

# ── 3. python3 must NOT be verified by the bare `python3` name alone ─────────
# The winget/python.org installer ships python.exe but never python3.exe, so on
# that route `python3 -V` fails even though Python is installed and working. The
# matrix must therefore carry a `python -V` row too; resolve-python.sh's ladder is
# what makes the distinction at runtime.
if grep -q 'verify_cmd: "python -V"' "$MATRIX"; then
  pass "a 'python -V' route exists (winget ships no python3.exe)"
else
  fail "no 'python -V' verify_cmd — the winget python3 route cannot verify"
fi

# ── 4. CONTROL: the detector fires on the exact historical defect ────────────
# Without this, a matrix that stopped containing verify_cmd at all would pass 1-3
# silently. Replay the pre-2026-07-30 shape on a temp copy and require a catch.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed 's/verify_cmd: "jd --version"/verify_cmd: "command -v jd"/' "$MATRIX" > "$TMP/mutated.yaml"
if ! grep -q 'verify_cmd: "command -v jd"' "$TMP/mutated.yaml"; then
  fail "control: could not construct the mutation — this test proves nothing"
else
  caught=$(grep -E 'verify_cmd: *"(command -v|which |type )' "$TMP/mutated.yaml" | wc -l | tr -d ' ')
  if [ "$caught" -ge 1 ]; then
    pass "control: the check catches a reintroduced 'command -v' verify_cmd"
  else
    fail "control: mutation NOT caught — checks 1-3 are vacuous"
  fi
fi

echo
if [ $rc -eq 0 ]; then echo "PASS: verify_cmd usability invariant"; else echo "FAIL: verify_cmd usability invariant"; fi
exit $rc
