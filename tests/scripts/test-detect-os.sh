#!/usr/bin/env bash
# S3 (spec 2026-08-11-audit-phase2b-scripts-and-owners.md) — detect-os.sh
# contract: verbatim port of os-detection.md:16-119, three-line
# OS:/PKG_MGR:/FALLBACKS: output, exit 0 always.
# Run: bash tests/scripts/test-detect-os.sh </dev/null
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../.." || exit 2
S="plugins/mega-sdd/scripts/detect-os.sh"
rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

[ -x "$S" ] && pass "script is executable" || fail "script not executable (chmod +x needed)"

out=$(bash "$S" </dev/null); src=$?
[ "$src" -eq 0 ] && pass "exit 0 on this host" || fail "exit code $src (must be 0 always)"

n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
[ "$n" -eq 3 ] && pass "emits exactly 3 lines" || fail "emitted $n lines (expected 3): $out"

printf '%s\n' "$out" | sed -n '1p' | grep -q '^OS: ' \
  && pass "line 1 carries the OS: key" || fail "line 1 not 'OS: ...': $(printf '%s\n' "$out" | sed -n '1p')"
printf '%s\n' "$out" | sed -n '2p' | grep -q '^PKG_MGR: ' \
  && pass "line 2 carries the PKG_MGR: key" || fail "line 2 not 'PKG_MGR: ...'"
printf '%s\n' "$out" | sed -n '3p' | grep -q '^FALLBACKS:' \
  && pass "line 3 carries the FALLBACKS: key" || fail "line 3 not 'FALLBACKS: ...'"

# OS token must be one of the ref's enum values (outcome table)
os_tok=$(printf '%s\n' "$out" | sed -n '1p' | awk '{print $2}')
case "$os_tok" in
  macos|linux|wsl|windows-bash|unknown) pass "OS token '$os_tok' in the ref enum" ;;
  *) fail "OS token '$os_tok' outside the ref enum" ;;
esac

# Host-specific assertion: this suite runs on macOS/Linux dev + CI hosts
if [ "$(uname -s)" = "Darwin" ]; then
  printf '%s\n' "$out" | sed -n '1p' | grep -q '^OS: macos ' \
    && pass "darwin host detected as macos" || fail "darwin host not detected as macos"
elif [ "$(uname -s)" = "Linux" ]; then
  printf '%s\n' "$out" | sed -n '1p' | grep -Eq '^OS: (linux|wsl) ' \
    && pass "linux host detected as linux/wsl" || fail "linux host not detected as linux/wsl"
fi

# Mutation/negative probe: with a stripped PATH no manager or fallback can
# resolve — PKG_MGR must derive from PATH (never hardcoded), OS family must
# survive (case on $OSTYPE, no external command), and the 3-line contract must
# hold even when sw_vers/sed are unreachable.
out2=$(PATH=/nonexistent /bin/bash "$S" </dev/null 2>/dev/null); src2=$?
[ "$src2" -eq 0 ] && pass "stripped-PATH run still exits 0" || fail "stripped-PATH run exited $src2"
n2=$(printf '%s\n' "$out2" | wc -l | tr -d ' ')
[ "$n2" -eq 3 ] && pass "stripped-PATH run still emits 3 lines" || fail "stripped-PATH run emitted $n2 lines"
printf '%s\n' "$out2" | grep -Eq '^PKG_MGR: (none|cargo-fallback)' \
  && pass "stripped PATH yields PKG_MGR none/cargo-fallback (detection is PATH-derived)" \
  || fail "stripped PATH still names a manager: $(printf '%s\n' "$out2" | sed -n '2p')"
fb2=$(printf '%s\n' "$out2" | sed -n '3p')
case "$fb2" in
  "FALLBACKS:"|"FALLBACKS: ") pass "stripped PATH yields empty FALLBACKS" ;;
  *) fail "stripped PATH still lists fallbacks: $fb2" ;;
esac

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
