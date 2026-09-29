#!/usr/bin/env bash
# test-s7c-review-panel.sh — God-review S7 Batch C: the L0 secret-scan fallback contracts.
#
# Findings (archive ~/.mega-sdd/god-review-s7/panel.md):
#   S7-GATES-9  fallback secret scan word-split argv → spaced filenames unscanned
#   r1-5        a failed git diff in the fallback must be a visible error, never clean
# (P3 C3: the review-panel pins went with review-panel.md and the lens agents.)
#
# Run: bash tests/god-review-s7/test-s7c-review-panel.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="${ROOT}/plugins/mega-sdd"
SSC="${P}/scripts/secret-scan.sh"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
W="$(mktemp -d 2>/dev/null || mktemp -d -t s7c)"
trap 'rm -rf "$W"' EXIT

echo "== S7-C: L0 secret-scan fallback contracts =="

# ── S7-GATES-9 (behavioral): a planted key in a SPACED filename is caught by the fallback ──
STUB="$W/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\nexit 3\n' > "$STUB/gitleaks"; chmod +x "$STUB/gitleaks"  # force the fallback
R="$W/sec"; mkdir -p "$R"
( cd "$R" && git init -q . && git config user.email t@t && git config user.name t )
echo "clean" > "$R/app.py"
( cd "$R" && git add -A && git commit -qm "chore: base" )
B=$(git -C "$R" rev-parse HEAD)
mkdir -p "$R/config files"
printf 'aws_key = "AKIAIOSFODNN7EXAMPLE"\n' > "$R/config files/prod settings.py"
( cd "$R" && git add -A && git commit -qm "feat: leak in spaced path" )
H=$(git -C "$R" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --code --base="$B" --head="$H" --cwd="$R" 2>/dev/null); RC=$?
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'prod settings.py'; then
  ok "GATES-9: spaced filename SCANNED and the planted key caught (was: word-split → silently unscanned)"
else
  fail "GATES-9: spaced filename still unscanned (rc=$RC): $(printf '%s' "$OUT" | head -c200)"
fi

# ── review r2-2: non-ASCII (git-C-quoted) filename must still be scanned ──
printf 'aws2 = "AKIAIOSFODNN7EXAMPLE"\n' > "$R/naïve-config.py"
( cd "$R" && git add -A && git commit -qm "feat: leak in quoted path" )
H2=$(git -C "$R" rev-parse HEAD)
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --code --base="$H" --head="$H2" --cwd="$R" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q 'na.*ve-config.py' \
  && ok "r2-2: git-C-quoted (non-ASCII) filename SCANNED (core.quotepath=off)" \
  || fail "r2-2: quoted filename still silently unscanned (rc=$RC)"

# ── review r1-5: a failed git diff in the fallback is a VISIBLE error, never clean ──
OUT=$(PATH="$STUB:$PATH" bash "$SSC" --code --base=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef --head="$H2" --cwd="$R" 2>"$W/.e12"); RC=$?
[ "$RC" -eq 2 ] && grep -q 'CANNOT run' "$W/.e12" && printf '%s' "$OUT" | grep -q '"skipped": true' \
  && ok "r1-5: unresolvable revision range → exit 2 + skipped:true (was: zero-file clean scan)" \
  || fail "r1-5: dead range still reads as clean (rc=$RC)"

if [ "$FAILED" -eq 0 ]; then echo "ALL S7-C OK"; else echo "S7-C had failures"; fi
exit $FAILED
