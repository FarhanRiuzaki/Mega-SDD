#!/usr/bin/env bash
# resolve-project-root.test.sh
#
# Pins the 2026-07-28 Windows hang fix in scripts/_lib/resolve-project-root.sh —
# the helper sourced by 9 hooks and 43 scripts.
#
# Root cause it guards: the walk-up loop used `d=$(dirname "$d")` and terminated
# only on `[ "$d" != "/" ]`. On Git Bash `dirname C:` returns `C:` — a FIXED
# POINT — so a Windows cwd spun the loop forever, forking one bash.exe+dirname.exe
# per iteration (measured 220 ms/iteration on a Windows 11 + CrowdStrike laptop)
# inside the BLOCKING PreToolUse hook.
#
# What this test pins:
#   A. EQUIVALENCE — on POSIX paths the new implementation returns byte-identical
#      output to the pre-fix reference implementation, across every documented
#      resolution rule (substantive root, litter shadowing, greenfield, legacy
#      layouts, nested-.mega-sdd guard, no-candidate fallback).
#   B. TERMINATION — Windows drive paths, backslash paths, bare relative names
#      and pathological input all terminate. A regression HANGS, so every
#      termination case runs under a hard timeout.
#   C. ZERO FORKS — the walk spawns no `dirname`/`basename` processes at all.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../../plugins/mega-sdd/scripts/_lib/resolve-project-root.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

# ── the PRE-FIX implementation, verbatim, as the equivalence oracle ──────────
# Only the walk differs; the candidate/substantive rules are copied unchanged so
# a divergence can only come from the loop mechanics under test.
_ref_has_bound_vault() {
  local root="$1" b
  for b in "$root"/*-bound "$root"/*/*-bound "$root"/docs/mega-sdd/vaults/*-bound; do
    if [ -d "$b/units" ] || [ -d "$b/bolts" ]; then return 0; fi
  done
  return 1
}
ref_resolve() {
  local d="${1:-$PWD}"
  local orig="$d"
  local first_match=""
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -d "$d/.mega-sdd" ] && [ "$(basename "$d")" != ".mega-sdd" ]; then
      if [ -z "$first_match" ]; then first_match="$d"; fi
      if [ -d "$d/.mega-sdd/vaults" ] || [ -d "$d/.mega-sdd/knowledge-base" ] \
         || [ -d "$d/.mega-sdd/codebase" ] || [ -f "$d/.mega-sdd/config.yaml" ] \
         || [ -f "$d/.mega-sdd/factory-ledger.json" ] || [ -d "$d/.mega-sdd/memory" ] \
         || [ -d "$d/docs/mega-sdd/vaults" ] || _ref_has_bound_vault "$d"; then
        echo "$d"; return 0
      fi
    fi
    d=$(dirname "$d")
  done
  if [ -n "$first_match" ]; then echo "$first_match"; return 0; fi
  echo "$orig"
}

# shellcheck disable=SC1090
. "$LIB"

# ── run a command under a hard timeout; 124 = hung ──────────────────────────
with_timeout() {
  local secs="$1"; shift
  local out; out="$TMP/.to.$$"
  ( "$@" >"$out" 2>/dev/null ) & local p=$!
  { sleep "$secs"; kill -9 "$p" 2>/dev/null; } >/dev/null 2>&1 & local w=$!
  wait "$p" 2>/dev/null; local r=$?
  kill "$w" 2>/dev/null
  cat "$out" 2>/dev/null; rm -f "$out"
  [ "$r" -ge 128 ] && return 124
  return 0
}

# ─────────────────────────────────────────────────────────────────────────────
echo "── A. EQUIVALENCE vs pre-fix reference (POSIX paths) ──"

R="$TMP/repo"
# substantive canonical root, with a deep subtree beneath it
mkdir -p "$R/proj/.mega-sdd/vaults" "$R/proj/src/app/http/controllers"
# litter root nested inside it (state files only — must NOT shadow the parent)
mkdir -p "$R/proj/sub/.mega-sdd"
: > "$R/proj/sub/.mega-sdd/.unit-spec-state.json"
# greenfield: .mega-sdd exists but is empty
mkdir -p "$R/green/.mega-sdd" "$R/green/src"
# legacy docs/mega-sdd/vaults layout
mkdir -p "$R/legacy/.mega-sdd" "$R/legacy/docs/mega-sdd/vaults/v1-bound/units"
# legacy *-bound sibling vault
mkdir -p "$R/bound/.mega-sdd" "$R/bound/v1-bound/units"
# a decoy dir merely NAMED *-bound (must not count as a vault)
mkdir -p "$R/decoy/.mega-sdd" "$R/decoy/io-bound"
# no .mega-sdd anywhere
mkdir -p "$R/plain/src/deep"
# the nested .mega-sdd/.mega-sdd defensive guard
mkdir -p "$R/nested/.mega-sdd/.mega-sdd/x"
: > "$R/nested/.mega-sdd/config.yaml"
# PHANTOM-ROOT-ONLY: a .mega-sdd carrying a nested .mega-sdd, with NO substantive
# root anywhere up the chain. This is the exact shape the `!= ".mega-sdd"` guard
# exists to protect (helper header: a phantom root must never be elected), and the
# only shape where a trailing-slash basename divergence changes the ANSWER rather
# than just an intermediate. Found by an adversarial audit, 2026-07-29.
mkdir -p "$R/phantom/.mega-sdd/.mega-sdd/x"

CASES="
$R/proj
$R/proj/src/app/http/controllers
$R/proj/sub
$R/proj/sub/.mega-sdd
$R/green
$R/green/src
$R/legacy
$R/legacy/docs/mega-sdd/vaults/v1-bound
$R/bound
$R/bound/v1-bound/units
$R/decoy
$R/decoy/io-bound
$R/plain
$R/plain/src/deep
$R/nested/.mega-sdd/.mega-sdd/x
$R
/
$TMP
$R/proj/
$R/proj/.mega-sdd/
$R/proj/.mega-sdd//
$R/green/
$R/phantom/.mega-sdd/
$R/phantom/.mega-sdd
$R/plain/src/deep/
"
eq_fail=0
for c in $CASES; do
  [ -n "$c" ] || continue
  got="$(resolve_project_root "$c")"
  want="$(ref_resolve "$c")"
  if [ "$got" != "$want" ]; then
    echo "   DIVERGED for [$c]: new=[$got] ref=[$want]"
    eq_fail=1
  fi
done
[ "$eq_fail" -eq 0 ] && pass "byte-identical to pre-fix reference across 25 POSIX cases (incl. the trailing-slash class)" \
                     || fail "output diverged from pre-fix reference"

# ─────────────────────────────────────────────────────────────────────────────
echo "── B. TERMINATION (a regression HANGS these) ──"

# B1: Windows drive path with backslashes, under a simulated Git Bash OSTYPE.
out="$(with_timeout 8 env OSTYPE=msys bash -c '. "$1"; resolve_project_root "C:\\Users\\me\\proj"' _ "$LIB")"
if [ $? -eq 124 ]; then fail "backslash Windows path HUNG (the original bug)"
else pass "backslash Windows path terminates -> [$out]"; fi

# B2: forward-slash Windows path (already-normalized form) must stop at the drive root.
out="$(with_timeout 8 env OSTYPE=msys bash -c '. "$1"; resolve_project_root "C:/Users/me/proj"' _ "$LIB")"
if [ $? -eq 124 ]; then fail "C:/ path HUNG at the drive-root fixed point"
else pass "C:/ path terminates -> [$out]"; fi

# B3: the bare drive root itself — `dirname C:` == `C:` is the exact fixed point.
out="$(with_timeout 8 env OSTYPE=msys bash -c '. "$1"; resolve_project_root "C:"' _ "$LIB")"
if [ $? -eq 124 ]; then fail "bare drive root C: HUNG"
else pass "bare drive root terminates -> [$out]"; fi

# B4: bare relative name — `dirname a` == `.`, then `dirname .` == `.` forever.
out="$(with_timeout 8 bash -c '. "$1"; resolve_project_root "relname"' _ "$LIB")"
if [ $? -eq 124 ]; then fail "bare relative name HUNG"
else pass "bare relative name terminates -> [$out]"; fi

# B4b: CONTROL — the PRE-FIX reference MUST hang on that same input, proving the
# defect is not Windows-only and that B4 is a real fix rather than a no-op. Run
# from a directory with no .mega-sdd so the `.` attractor is actually reached.
( cd "$TMP" && with_timeout 8 ref_resolve "relname" >/dev/null 2>&1 )
if [ $? -eq 124 ]; then
  pass "control: pre-fix reference HANGS on a relative name (defect reproduced here, not just on Windows)"
else
  fail "control: pre-fix reference terminated — B4 no longer pins a real defect"
fi

# B5: "." must not spin.
out="$(with_timeout 8 bash -c '. "$1"; resolve_project_root "."' _ "$LIB")"
if [ $? -eq 124 ]; then fail "'.' HUNG"
else pass "'.' terminates -> [$out]"; fi

# B6: empty input falls back to $PWD and terminates.
out="$(with_timeout 8 bash -c 'cd /; . "$1"; resolve_project_root ""' _ "$LIB")"
if [ $? -eq 124 ]; then fail "empty input HUNG"
else pass "empty input terminates -> [$out]"; fi

# B7: absurdly deep path trips the guard rather than walking unbounded.
deep="/$(printf 'x/%.0s' $(seq 1 200))end"
out="$(with_timeout 8 bash -c '. "$1"; resolve_project_root "$2"' _ "$LIB" "$deep")"
if [ $? -eq 124 ]; then fail "200-level path HUNG"
else pass "200-level path terminates (iteration guard)"; fi

# ─────────────────────────────────────────────────────────────────────────────
echo "── C. ZERO FORKS in the walk ──"
# PATH shims tally any dirname/basename exec. On Git Bash each such exec is a
# real CreateProcess scanned by the EDR — the cost this fix exists to remove.
SHIM="$TMP/shim"; CNT="$TMP/cnt"; mkdir -p "$SHIM" "$CNT"
for cmd in dirname basename; do
  real="$(command -v "$cmd")"
  printf '#!/bin/sh\necho 1 >> "%s/%s"\nexec "%s" "$@"\n' "$CNT" "$cmd" "$real" > "$SHIM/$cmd"
  chmod +x "$SHIM/$cmd"
done
PATH="$SHIM:$PATH" bash -c '. "$1"; resolve_project_root "$2" >/dev/null' _ "$LIB" "$R/proj/src/app/http/controllers"
forks=0
for f in "$CNT"/*; do [ -e "$f" ] && forks=$((forks + $(wc -l < "$f" | tr -d ' '))); done
if [ "$forks" -eq 0 ]; then pass "walk spawned 0 dirname/basename processes"
else fail "walk spawned $forks dirname/basename processes (expected 0)"; fi

# and prove the shim actually counts, so a 0 above is meaningful not vacuous
PATH="$SHIM:$PATH" bash -c 'dirname /a/b >/dev/null'
sentinel=0
for f in "$CNT"/*; do [ -e "$f" ] && sentinel=$((sentinel + $(wc -l < "$f" | tr -d ' '))); done
if [ "$sentinel" -gt 0 ]; then pass "fork counter is live (sentinel registered)"
else fail "fork counter never fires — the 0 above is vacuous"; fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
