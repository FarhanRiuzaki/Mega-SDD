#!/usr/bin/env bash
# resolve-python.test.sh
#
# Pins scripts/_lib/resolve-python.sh — the stub-aware interpreter probe that
# replaces the broken `command -v python3` guard.
#
# The bug it closes (measured on a Windows 11 corporate laptop, 2026-07-28):
# `command -v python3` SUCCEEDS when only the Windows App Execution Alias stub
# is present, so the hooks' python3-absent fail-closed branch never fired and
# every gate exited 0 unevaluated. The probe must call that machine "no usable
# interpreter", not "python3 available".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/../../plugins/mega-sdd/scripts/_lib/resolve-python.sh"
BASH_BIN="$(command -v bash)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }

mkexe() { mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\nexit 0\n' > "$1"; chmod +x "$1"; }

# ── Case 1: real python3 first on PATH → usable, name returned verbatim ─────
mkexe "$TMP/real/python3"
out="$(PATH="$TMP/real" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
[ "$out" = "python3" ] && pass "real python3 -> 'python3'" || fail "real python3 -> [$out]"

# ── Case 2: THE WINDOWS BUG — only the WindowsApps alias stub exists ────────
# Shape copied from the real machine: .../AppData/Local/Microsoft/WindowsApps/
ALIAS="$TMP/win/AppData/Local/Microsoft/WindowsApps"
mkexe "$ALIAS/python3"; mkexe "$ALIAS/python"
out="$(PATH="$ALIAS" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
st=$?
if [ -z "$out" ] && [ "$st" -ne 0 ]; then
  pass "alias-only PATH -> NO interpreter (returns 1)"
else
  fail "alias-only PATH accepted the stub -> [$out] rc=$st"
fi

# and prove the old guard would have been fooled by this very same PATH
if PATH="$ALIAS" command -v python3 >/dev/null 2>&1; then
  pass "control: 'command -v python3' IS fooled by the stub (bug reproduced)"
else
  fail "control failed — the fixture no longer reproduces the original bug"
fi

# ── Case 3: alias shadows python3/python, but the `py` launcher is real ─────
mkexe "$TMP/launcher/py"
out="$(PATH="$ALIAS:$TMP/launcher" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
[ "$out" = "py -3" ] && pass "alias + real py -> 'py -3'" || fail "alias + real py -> [$out]"

# ── Case 4: alias FIRST, real python3 later on PATH → must NOT claim python3 ─
# Typing `python3` would still hit the stub, so returning that name would hand
# the caller a non-interpreter.
out="$(PATH="$ALIAS:$TMP/real" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
[ "$out" != "python3" ] && pass "shadowed python3 not claimed -> [$out]" \
                        || fail "returned 'python3' while the stub shadows it"

# ── Case 5: nothing at all on PATH ──────────────────────────────────────────
out="$(PATH="$TMP/empty" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
st=$?
if [ -z "$out" ] && [ "$st" -ne 0 ]; then pass "empty PATH -> no interpreter"
else fail "empty PATH -> [$out] rc=$st"; fi

# ── Case 6: case-insensitive alias match (Windows paths are case-insensitive) ─
CI="$TMP/ci/AppData/Local/Microsoft/windowsapps"
mkexe "$CI/python3"
out="$(PATH="$CI" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
[ -z "$out" ] && pass "lowercase 'windowsapps' also rejected" || fail "case-sensitive match missed -> [$out]"

# ── Case 7: .exe suffix resolution (Git Bash omits it in `command -v` output) ─
mkexe "$TMP/exe/python3.exe"
out="$(PATH="$TMP/exe" "$BASH_BIN" -c '. "$1"; mega_sdd_python && printf "%s" "$MEGA_SDD_PY"' _ "$LIB")"
[ "$out" = "python3" ] && pass "python3.exe resolves -> 'python3'" || fail "python3.exe -> [$out]"

# ── Case 8: ZERO FORKS — the probe must not spawn anything ──────────────────
SHIM="$TMP/shim"; CNT="$TMP/cnt"; mkdir -p "$SHIM" "$CNT"
for cmd in which command sed grep awk tr basename dirname; do
  real="$(command -v "$cmd" 2>/dev/null)" || continue
  [ -n "$real" ] || continue
  printf '#!/bin/sh\necho 1 >> "%s/%s"\nexec "%s" "$@"\n' "$CNT" "$cmd" "$real" > "$SHIM/$cmd"
  chmod +x "$SHIM/$cmd"
done
PATH="$SHIM:$TMP/real" "$BASH_BIN" -c '. "$1"; mega_sdd_python >/dev/null 2>&1' _ "$LIB"
forks=0
for f in "$CNT"/*; do [ -e "$f" ] && forks=$((forks + $(wc -l < "$f" | tr -d ' '))); done
[ "$forks" -eq 0 ] && pass "probe spawned 0 external processes" \
                   || fail "probe spawned $forks external processes (expected 0)"

# ── Case 9: memoized — repeated calls stay consistent ───────────────────────
out="$(PATH="$TMP/real" "$BASH_BIN" -c '. "$1"; mega_sdd_python; a="$MEGA_SDD_PY"; mega_sdd_python; printf "%s/%s" "$a" "$MEGA_SDD_PY"' _ "$LIB")"
[ "$out" = "python3/python3" ] && pass "memoized result is stable" || fail "memoization -> [$out]"

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
