#!/usr/bin/env bash
# test-anchor-freshness.sh — P4 anchor-freshness preflight (the preflight test
# family). check-anchor-freshness.sh resolves every ## Anchors `file:line`
# against git-tracked ground truth BEFORE dispatch:
#   fresh pass · stale line halt (anchor_missing + keterangan naming the
#   anchor + remedy) · deleted file halt · already-bolted ADVISORY (exit 0 —
#   commit-keyed: legacy/bolted units never retro-block) · no-anchors no-op ·
#   placeholder lines skipped.
# Run: bash tests/postflight-evidence/test-anchor-freshness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CAF="$ROOT/plugins/mega-sdd/scripts/check-anchor-freshness.sh"
[ -f "$CAF" ] || { echo "missing $CAF"; exit 1; }

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t anchfr)"
trap 'rm -rf "$WORK"' EXIT

F="$WORK/f1"
mkdir -p "$F/.mega-sdd/vaults/app/units" "$F/src"
( cd "$F" && git init -q . )
printf 'line1\nline2\nline3\n' > "$F/src/svc.php"
mk_unit() { # $1=anchor-line
  cat > "$F/.mega-sdd/vaults/app/units/U-010.md" <<EOF
---
id: U-010
task_type: extend
target_files:
  - path: src/svc.php
    operation: modify
acceptance_test:
  - type: test
    command: "true"
---

## Goal
Anchor fixture.

## Anchors
$1
<file:line placeholder — template noise, must be skipped>
EOF
}
mk_unit "- src/svc.php:2 — the anchor (binding C-001)"
( cd "$F" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "seed" )

echo "── fresh pass ──"
OUT=$(bash "$CAF" --cwd="$F" --unit=U-010 </dev/null 2>&1); RC=$?
[ $RC -eq 0 ] && printf '%s' "$OUT" | grep -q "1 anchor(s) fresh" \
  && ok "fresh anchor resolves (exit 0)" || fail "fresh anchor rejected rc=$RC: $OUT"

echo "── stale line → halt anchor_missing ──"
mk_unit "- src/svc.php:99 — the anchor (binding C-001)"
OUT=$(bash "$CAF" --cwd="$F" --unit=U-010 </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && printf '%s' "$OUT" | grep -q "HALT anchor_missing" \
   && printf '%s' "$OUT" | grep -q "src/svc.php:99" \
   && printf '%s' "$OUT" | grep -q "line_out_of_range"; then
  ok "line past EOF → exit 1, anchor_missing names the stale anchor"
else fail "stale-line halt broken rc=$RC: $OUT"; fi
# keterangan contract: Indonesian keterangan carries the remedy, not a bare code
printf '%s' "$OUT" | grep -q "Keterangan:" && printf '%s' "$OUT" | grep -q "mega-sdd:sync" \
  && ok "keterangan present (anchor + remedy: sync/re-bind or fix the unit)" \
  || fail "keterangan missing from anchor_missing halt"

echo "── deleted file → halt anchor_missing ──"
mk_unit "- src/gone.php:1 — vanished evidence"
OUT=$(bash "$CAF" --cwd="$F" --unit=U-010 </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && printf '%s' "$OUT" | grep -q "src/gone.php:1" \
   && printf '%s' "$OUT" | grep -q "file_missing"; then
  ok "untracked/deleted anchor file → exit 1 anchor_missing (file_missing)"
else fail "deleted-file halt broken rc=$RC: $OUT"; fi

echo "── already-bolted unit → ADVISORY only (commit-keyed, never retro-block) ──"
( cd "$F" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-010): bolt landed

Unit: U-010" )
OUT=$(bash "$CAF" --cwd="$F" --unit=U-010 </dev/null 2>&1); RC=$?
if [ $RC -eq 0 ] && printf '%s' "$OUT" | grep -q "advisory" && printf '%s' "$OUT" | grep -q "never retro-blocked"; then
  ok "stale anchor on a bolted unit → WARN advisory, exit 0 (legacy lane)"
else fail "bolted-unit advisory lane broken rc=$RC: $OUT"; fi

echo "── no anchors → no-op pass ──"
F2="$WORK/f2"
mkdir -p "$F2/.mega-sdd/vaults/app/units"
( cd "$F2" && git init -q . )
printf -- '---\nid: U-011\ntask_type: create\ntarget_files:\n  - path: a.txt\n    operation: create\nacceptance_test:\n  - type: test\n    command: "true"\n---\n\n## Goal\nNo anchors.\n' > "$F2/.mega-sdd/vaults/app/units/U-011.md"
( cd "$F2" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "seed" )
OUT=$(bash "$CAF" --cwd="$F2" --unit=U-011 </dev/null 2>&1); RC=$?
[ $RC -eq 0 ] && ok "unit without ## Anchors → exit 0 (nothing to verify)" || fail "no-anchors lane broken rc=$RC: $OUT"

echo
[ "$FAILED" -eq 0 ] && { echo "test-anchor-freshness: ALL PASS"; exit 0; } || { echo "test-anchor-freshness: FAILURES"; exit 1; }
