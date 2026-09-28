#!/usr/bin/env bash
# test-inflight-units.sh — pins _lib/vault_layouts.inflight_units, which is kept
# (its result feeds the unit_binding.py done-rule on legacy leftovers). Re-homed from
# tests/wave-rail/test-wave-commit-rail.sh (P3 plan research/2026-09-28-p3-deletion-plan.md
# §3d): a unit is in flight while bolts/U-XXX/dispatch-prompt.md exists and
# postflight.json is absent or older than it.
# Run: bash tests/v9/test-inflight-units.sh </dev/null
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }

F="$WORK/proj"; V="$F/.mega-sdd/vaults/app"
mkdir -p "$V/bolts/U-007" "$F/src"
echo "dispatch" > "$V/bolts/U-007/dispatch-prompt.md"     # in flight (no postflight)

# $1 = expected list as a Python literal
check() {
  python3 - "$REPO/plugins/mega-sdd/scripts/_lib" "$F" "$1" <<'EOF'
import ast, sys
sys.path.insert(0, sys.argv[1]); import vault_layouts
got = vault_layouts.inflight_units(sys.argv[2])
assert got == ast.literal_eval(sys.argv[3]), got
EOF
}

check '["U-007"]' && ok "dispatch-prompt.md without postflight.json -> U-007 in flight" || bad "inflight_units missed U-007"

# postflight.json newer than dispatch-prompt.md closes the window (explicit mtimes, no sleep)
echo '{"status":"pass"}' > "$V/bolts/U-007/postflight.json"
python3 -c 'import os,sys; os.utime(sys.argv[1], (1000, 1000)); os.utime(sys.argv[2], (2000, 2000))' \
  "$V/bolts/U-007/dispatch-prompt.md" "$V/bolts/U-007/postflight.json"
check '[]' && ok "newer postflight.json -> nothing in flight" || bad "window did not close on a newer postflight.json"

echo
[ "$fail" -eq 0 ] && { echo "inflight_units: ALL PASS"; exit 0; } || { echo "inflight_units: FAILED"; exit 1; }
