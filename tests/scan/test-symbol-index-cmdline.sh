#!/usr/bin/env bash
# test-symbol-index-cmdline.sh — build-symbol-index.sh must keep every ast-grep
# command line under the host limit. Field report 2026-09-30 (Windows 11, Git
# Bash): 642 .ts/.tsx paths went into ONE chunk sized for POSIX ARG_MAX
# (256 KB); CreateProcessW caps the whole command line at 32,767 UTF-16 units,
# so Popen raised WinError 206, the index stayed absent and every JIT symbol
# claim bound as OQ. A shim ast-grep records each call's quoted command-line
# length; MEGA_SDD_CMDLINE_MAX forces the Windows accounting on any host.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
S="$REPO/plugins/mega-sdd/scripts/build-symbol-index.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FAIL=0; ok() { echo "  ok: $1"; }; bad() { echo "  FAIL: $1"; FAIL=1; }

mkdir -p "$T/bin" "$T/repo"
cat > "$T/bin/ast-grep" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && { echo "ast-grep 0.45.0"; exit 0; }
python3 - "$@" >> "$AG_LOG" <<'PY'
import subprocess, sys
a = ["ast-grep"] + sys.argv[1:]
paths = a[a.index("--") + 1:]
print(len(subprocess.list2cmdline(a).encode("utf-16-le")) // 2, len(paths), *paths)
PY
echo "[]"
SH
chmod +x "$T/bin/ast-grep"
D="$T/repo/apps/web/src/components/features/very-long-feature-directory-name/subfolder"
mkdir -p "$D"
for i in $(seq 1 642); do echo "export const c$i = 1" > "$D/component-with-a-long-descriptive-name-$i.tsx"; done
git -C "$T/repo" init -q && git -C "$T/repo" add -A && git -C "$T/repo" -c user.email=t@t -c user.name=t commit -qm init
if [ "$(python3 -c 'import sys; print(sys.platform)')" = win32 ]; then
  # CreateProcessW cannot exec a bash shim, so Windows runs the real thing: the
  # exact field shape (642 long paths, native limit, no override) must build.
  echo "── D: Windows, real ast-grep, native limit ──"
  if command -v ast-grep >/dev/null 2>&1; then
    bash "$S" --cwd="$T/repo" --out="$T/idx.json" >/dev/null 2>"$T/err"; rc=$?
    [ "$rc" = 0 ] && ok "D1 index built (exit 0)" || bad "D1 exit $rc: $(head -1 "$T/err")"
  else
    bad "D1 ast-grep not installed on this Windows host"
  fi
  [ "$FAIL" = 0 ] && echo "test-symbol-index-cmdline: ALL PASS" || { echo "test-symbol-index-cmdline: FAILED"; exit 1; }
  exit 0
fi
export PATH="$T/bin:$PATH" AG_LOG="$T/calls"

echo "── A: Windows accounting (32,000) ──"
: > "$AG_LOG"
MEGA_SDD_CMDLINE_MAX=32000 bash "$S" --cwd="$T/repo" --out="$T/idx.json" >/dev/null 2>"$T/err"; rc=$?
[ "$rc" = 0 ] && ok "A1 exit 0" || bad "A1 exit $rc: $(head -1 "$T/err")"
max=$(awk 'BEGIN{m=0} $1>m{m=$1} END{print m}' "$AG_LOG"); n=$(wc -l < "$AG_LOG" | tr -d ' ')
[ "$max" -le 32000 ] && ok "A2 longest command line $max <= 32000 ($n calls)" || bad "A2 command line $max > 32000"
[ "$n" -ge 2 ] && ok "A3 split into $n chunks" || bad "A3 one chunk only"
cov=$(awk '{for(i=3;i<=NF;i++) print $i}' "$AG_LOG" | sort -u | wc -l | tr -d ' ')
[ "$cov" = 642 ] && ok "A4 every file scanned once ($cov)" || bad "A4 scanned $cov of 642"

echo "── B: POSIX default unchanged ──"
: > "$AG_LOG"
bash "$S" --cwd="$T/repo" --out="$T/idx2.json" >/dev/null 2>&1; rc=$?
n=$(wc -l < "$AG_LOG" | tr -d ' ')
[ "$rc" = 0 ] && [ "$n" = 1 ] && ok "B1 one call for 642 paths (POSIX 256 KB budget)" || bad "B1 rc=$rc calls=$n"

echo "── C: a limit the rules alone fill ──"
MEGA_SDD_CMDLINE_MAX=2000 bash "$S" --cwd="$T/repo" --out="$T/idx3.json" >/dev/null 2>"$T/err3"; rc=$?
[ "$rc" = 4 ] && grep -q 'inline rules alone' "$T/err3" && ok "C1 exit 4 with a reason" || bad "C1 rc=$rc"

[ "$FAIL" = 0 ] && echo "test-symbol-index-cmdline: ALL PASS" || { echo "test-symbol-index-cmdline: FAILED"; exit 1; }
