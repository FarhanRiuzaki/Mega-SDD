#!/usr/bin/env bash
# post-tool-use-windows-paths.test.sh
#
# Pins D2 (2026-07-29): hooks/post-tool-use dispatches everything through
# `case "$FILE_PATH"` globs written with "/". Claude Code hands hooks NATIVE paths
# on Windows, which match NONE of them — so on the team's machines the 6 background
# unit-write validators, the KB validators, codebase-map, binding, ui-quality,
# cross-cutting and factory-ledger dispatch never fired, the own-output
# anti-feedback guard leaked (mega-sdd journalled its own writes), and DIRTY_REL's
# prefix strip against an already-normalized PROJECT_ROOT left an absolute path.
#
# HOW A WINDOWS PATH IS SIMULATED ON POSIX: the fixture is built at a real POSIX
# path, then the payload sends that same path with "/" replaced by "\" — exactly
# what Windows would send for that file. With OSTYPE=msys the hook normalizes it
# back to the real path, so the dispatch can be observed end-to-end on a real
# filesystem. Bash glob semantics are platform-identical, so this is not an
# approximation of the matching behavior — it is the matching behavior.
#
# ALSO PINNED — the near-miss that made this fix dangerous: the normalization runs
# under `set -u`, and FILE_PATH is emitted ONLY for Read/Write/Edit. It is UNSET for
# every Bash, Skill and Agent call. bash 3.2 (macOS) tolerates `${VAR//x/y}` on an
# unset name; **bash 5 treats it as an unbound-variable error and kills the hook**
# (verified in bash 5.3.15 — the team's exact version — where the bare form exited 1
# with `FILE_PATH: unbound variable` on 3 of 4 tool-call types). The `:-` defaults
# are therefore load-bearing, and this file exercises those three tool types so CI's
# bash 5 catches any regression that macOS's bash 3.2 would wave through.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
HOOK="$ROOT/plugins/mega-sdd/hooks/post-tool-use"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

P="$TMP/proj"
mkdir -p "$P/.mega-sdd/vaults/v1/units" "$P/.mega-sdd/codebase" "$P/src"
printf 'x\n' > "$P/.mega-sdd/vaults/v1/units/U-001.md"

# exec tally: counts how far the hook actually got
SHIM="$TMP/shim"; CNT="$TMP/cnt"; mkdir -p "$SHIM" "$CNT"
REALPY="$(command -v "$PY")"
printf '#!/bin/sh\necho 1 >> "%s/py"\nexec "%s" "$@"\n' "$CNT" "$REALPY" > "$SHIM/python3"
chmod +x "$SHIM/python3"

mk() { # $1=tool $2=tool_input JSON $3=cwd
  "$PY" -c 'import json,sys; print(json.dumps({"session_id":"s","cwd":sys.argv[3],"tool_name":sys.argv[1],"tool_input":json.loads(sys.argv[2])}))' "$1" "$2" "$3"
}
tally() { # $1=payload $2=OSTYPE value -> prints exec count
  : > "$CNT/py"
  # Exec-count equality between arms is this test's PROXY for "Windows dispatches
  # like POSIX". The pack-resolver's derived cache (spec §4a-i) legitimately makes
  # a WARM run spawn fewer pythons than a COLD one, which breaks the proxy's
  # identical-starting-state assumption without touching the property under test —
  # so every tally starts cache-cold. (Deleting the cache is always safe: it is
  # derived and discardable by contract.)
  rm -rf "$P/.mega-sdd/.cache" 2>/dev/null
  printf '%s' "$1" | OSTYPE="$2" PATH="$SHIM:$PATH" bash "$HOOK" >/dev/null 2>&1
  wc -l < "$CNT/py" | tr -d ' '
}
bslash() { printf '%s' "$1" | tr '/' '\\'; }

UNIT="$P/.mega-sdd/vaults/v1/units/U-001.md"
FWD=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$UNIT")" "$P")
WIN=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$(bslash "$UNIT")")" "$(bslash "$P")")

echo "── A. a Windows-shaped unit write dispatches exactly like a POSIX one ──"
N_FWD=$(tally "$FWD" "darwin24")
N_WIN=$(tally "$WIN" "msys")
echo "   forward-slash payload : $N_FWD execs"
echo "   backslash payload     : $N_WIN execs (OSTYPE=msys)"
if [ "$N_FWD" -gt 5 ] && [ "$N_WIN" -eq "$N_FWD" ]; then
  pass "Windows path reaches the same dispatch tree ($N_WIN == $N_FWD)"
else
  fail "Windows path dispatched $N_WIN vs POSIX $N_FWD — globs still separator-bound"
fi

echo "── B. CONTROL: without normalization the same payload goes nowhere ──"
# OSTYPE left non-Windows, so the hook does NOT normalize — this is the pre-fix
# behavior on a Windows machine, reproduced exactly.
N_RAW=$(tally "$WIN" "darwin24")
echo "   backslash payload, no normalization : $N_RAW execs"
if [ "$N_RAW" -lt "$N_FWD" ]; then
  pass "control: un-normalized Windows path dispatches less ($N_RAW < $N_FWD) — A is not vacuous"
else
  fail "control: un-normalized path dispatched $N_RAW (>= $N_FWD) — A no longer pins a real defect"
fi

echo "── B2. ISOLATION: how much of that collapse is the FILE_PATH globs alone ──"
# cwd forward-slash (so PROJECT_ROOT resolves fine) but file_path backslash, with
# normalization off. Whatever is lost here is attributable to the case-globs and
# nothing else — the honest number for D2, separate from the cwd/PROJECT_ROOT path
# that v5.5.0 addressed at the eval layer.
MIXED=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$(bslash "$UNIT")")" "$P")
N_MIX=$(tally "$MIXED" "darwin24")
echo "   cwd normalized, FILE_PATH raw       : $N_MIX execs (vs $N_FWD when both are clean)"
if [ "$N_MIX" -lt "$N_FWD" ]; then
  pass "the globs alone account for $((N_FWD - N_MIX)) of $N_FWD dispatch steps"
else
  fail "isolating the globs showed no loss ($N_MIX vs $N_FWD) — the D2 claim is unsupported"
fi

echo "── C. the hook SURVIVES tool calls where FILE_PATH is unset (bash>=4.4 trap) ──"
# Under `set -u`, `${FILE_PATH//…}` on an unset name is fatal on bash >= 4.4.
# FILE_PATH is emitted only for Read/Write/Edit, so these three are the majority
# of tool calls. On CI (bash 5) this is a live check; on macOS bash 3.2 it is weaker.
echo "   running under bash ${BASH_VERSION%%(*}"
for t in Bash:'{"command":"echo hi"}' Skill:'{"skill":"orchestrate-flow"}' Agent:'{"subagent_type":"x","description":"y"}'; do
  name="${t%%:*}"; ti="${t#*:}"
  payload=$(mk "$name" "$ti" "$(bslash "$P")")
  printf '%s' "$payload" | OSTYPE=msys bash "$HOOK" >/dev/null 2>"$TMP/err"
  st=$?
  if [ $st -eq 0 ]; then pass "$name call (FILE_PATH unset) exits 0"
  else fail "$name call KILLED the hook (exit $st): $(head -1 "$TMP/err")"; fi
done

echo "── D. the guard against that trap is present in the source ──"
# Belt and braces: on bash 3.2 check C cannot fail, so assert the shape too.
if grep -qF 'FILE_PATH="${FILE_PATH:-}"' "$HOOK"; then
  pass "FILE_PATH is :-defaulted before pattern substitution"
else
  fail "FILE_PATH pattern substitution is not :-defaulted — fatal on bash >= 4.4 under set -u"
fi
# The normalization must precede the FIRST case-glob on FILE_PATH, or it fixes nothing.
norm_line=$(grep -n 'FILE_PATH="${FILE_PATH:-}"' "$HOOK" | head -1 | cut -d: -f1)
case_line=$(grep -n 'case "$FILE_PATH" in' "$HOOK" | head -1 | cut -d: -f1)
if [ -n "$norm_line" ] && [ -n "$case_line" ] && [ "$norm_line" -lt "$case_line" ]; then
  pass "normalization (line $norm_line) precedes the first FILE_PATH glob (line $case_line)"
else
  fail "normalization does not precede the first FILE_PATH glob (norm=$norm_line case=$case_line)"
fi

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
