#!/usr/bin/env bash
# post-tool-use-windows-paths.test.sh
#
# Pins D2 (2026-07-29; repinned v7.5.0 No.D): hooks/post-tool-use matches paths
# with "/"-written globs, and Claude Code hands hooks NATIVE paths on Windows.
# The validator fan-out this file originally counted is DELETED (No.D) — the
# SURVIVING D2 surface is the dirty-paths JOURNAL: without normalization a
# Windows write is never journaled (or journaled with an absolute/garbage
# DIRTY_REL), and the own-output anti-feedback guard leaks. The arms below pin
# journal-row parity between a POSIX payload and its backslash twin.
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
# v7: arm the chain (spec 2026-08-21-v7-weighted-routing-design.md §3.1) — the
# validator fan-out is chain-scoped; this test pins VALIDATOR behavior, so the
# fixture session must be armed the way a real chain session is.
printf '{"session_id": "s", "chain_engaged": true, "entries": {}}' > "$P/.mega-sdd/.gateguard-state.json"
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

SRC="$P/src/app.js"
printf 'x\n' > "$SRC"
DJ="$P/.mega-sdd/codebase/.dirty-paths.jsonl"
jrow() { tail -1 "$DJ" 2>/dev/null; }
jcount() { [ -f "$DJ" ] && wc -l < "$DJ" | tr -d ' ' || echo 0; }
fire() { # $1=payload $2=OSTYPE
  printf '%s' "$1" | OSTYPE="$2" bash "$HOOK" >/dev/null 2>&1
}
FWD=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$SRC")" "$P")
WIN=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$(bslash "$SRC")")" "$(bslash "$P")")

echo "-- A. a Windows-shaped source write journals exactly like a POSIX one --"
rm -f "$DJ"
fire "$FWD" "darwin24"
ROW_FWD=$(jrow)
rm -f "$DJ"
fire "$WIN" "msys"
ROW_WIN=$(jrow)
echo "   posix row : $ROW_FWD"
echo "   win row   : $ROW_WIN"
if printf '%s' "$ROW_FWD" | grep -q '"path":"src/app.js"' \
   && printf '%s' "$ROW_WIN" | grep -q '"path":"src/app.js"'; then
  pass "Windows payload journals the same repo-relative row as POSIX"
else
  fail "Windows path journaled wrong/no row (posix=[$ROW_FWD] win=[$ROW_WIN])"
fi

echo "-- B. CONTROL: without normalization the same payload journals NOTHING --"
rm -f "$DJ"
fire "$WIN" "darwin24"   # pre-fix behavior: no OSTYPE normalization
N_RAW=$(jcount)
if [ "$N_RAW" -eq 0 ]; then
  pass "control: un-normalized Windows payload journals 0 rows - A is not vacuous"
else
  fail "control: un-normalized payload journaled $N_RAW row(s) - A no longer pins a real defect"
fi

echo "-- B2. own-output guard holds under Windows separators --"
UNIT="$P/.mega-sdd/vaults/v1/units/U-001.md"
WUNIT=$(mk Write "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$(bslash "$UNIT")")" "$(bslash "$P")")
rm -f "$DJ"
fire "$WUNIT" "msys"
N_OWN=$(jcount)
if [ "$N_OWN" -eq 0 ]; then
  pass "a Windows-shaped write UNDER .mega-sdd is never journaled (anti-feedback guard normalized)"
else
  fail "own-output guard leaked under backslashes ($N_OWN row(s))"
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
