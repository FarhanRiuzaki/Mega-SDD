#!/usr/bin/env bash
# Functional: orphan-scan flags bolt commits without bolt-report.md; PASSes when
# the report exists; never false-positives on units that no longer exist.
set -u
err=0
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh
[ -x "$V" ] || { echo "validator missing/non-executable"; exit 1; }
VABS="$PWD/$V"

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
( cd "$repo" && git init -q . \
  && mkdir -p .mega-sdd/vaults/v1/units \
  && printf -- '---\nunit_id: U-001\n---\n# U-001\n' > .mega-sdd/vaults/v1/units/U-001.md \
  && echo code > app.js \
  && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-001 thing" \
  && echo more > b.js && git add . \
  && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-999 retired unit" )

# U-001 bolted, unit exists, no report -> FAIL listing exactly U-001 (U-999 has no unit file -> ignored)
out=$(bash "$VABS" --cwd="$repo" --orphan-scan); rc=$?
[ $rc -eq 1 ] || { echo "expected exit 1 on orphan, got $rc"; err=1; }
echo "$out" | grep -q '"status": "FAIL"' || { echo "expected FAIL state"; err=1; }
echo "$out" | grep -q '"unit_id": "U-001"' || { echo "U-001 orphan not flagged"; err=1; }
echo "$out" | grep -q '"unit_id": "U-999"' && { echo "false positive: U-999 has no unit file"; err=1; }
[ -f "$repo/.mega-sdd/.bolt-orphans-state.json" ] || { echo "state file not written"; err=1; }

# Backfill the report -> PASS
mkdir -p "$repo/.mega-sdd/vaults/v1/bolts/U-001"
echo "# Bolt Report — U-001" > "$repo/.mega-sdd/vaults/v1/bolts/U-001/bolt-report.md"
out=$(bash "$VABS" --cwd="$repo" --orphan-scan); rc=$?
[ $rc -eq 0 ] || { echo "expected exit 0 after backfill, got $rc"; err=1; }
echo "$out" | grep -q '"status": "PASS"' || { echo "expected PASS after backfill"; err=1; }

# Non-git dir -> silent no-op exit 0, no state
plain=$(mktemp -d); mkdir -p "$plain/.mega-sdd"
bash "$VABS" --cwd="$plain" --orphan-scan >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "non-git dir must exit 0"; err=1; }
[ -f "$plain/.mega-sdd/.bolt-orphans-state.json" ] && { echo "non-git dir must not write state"; err=1; }
rm -rf "$plain"
exit $err
