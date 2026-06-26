#!/usr/bin/env bash
# Functional (B2): the final full-suite gate is enforced by the VALIDATOR, not prose.
# A code-bearing bolt run must leave a green `_batch-suite.json` at HEAD covering the
# newest bolt commit; otherwise the next run is halted. Mirrors the orphan-scan model.
#   1. bolt commit + no _batch-suite.json        -> FAIL batch_suite_gate_missing
#   2. bolt commit + _batch-suite.json status red -> FAIL batch_suite_red
#   3. bolt commit + green _batch-suite.json @HEAD -> PASS
#   4. green gate, then a NON-bolt commit (README) -> still PASS (not over-aggressive)
#   5. green gate, then a NEW feat(bolt) commit     -> FAIL (stale: new bolt uncovered)
#   6. no bolt commits at all                       -> PASS (nothing to gate)
#   7. non-git dir                                  -> exit 0 no-op, no state
set -u
err=0
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh
[ -x "$V" ] || { echo "validator missing/non-executable"; exit 1; }
VABS="$PWD/$V"

mkunit() { # repo unitid : write a code-bearing unit (non-empty target_files)
  mkdir -p "$1/.mega-sdd/vaults/v1/units"
  printf -- '---\nunit_id: %s\ntask_type: create\ntarget_files:\n  - path: app_%s.js\n    operation: create\n---\n# %s\n' \
    "$2" "$2" "$2" > "$1/.mega-sdd/vaults/v1/units/$2.md"
}
greengate() { # repo sha : write a green _batch-suite.json stamped at sha
  mkdir -p "$1/.mega-sdd/vaults/v1/bolts"
  printf '{ "command": "yarn test", "status": "green", "passed": 5, "failed": 0, "todo": 0, "head_sha": "%s", "units": ["U-001"], "bypass_commits": [] }\n' \
    "$2" > "$1/.mega-sdd/vaults/v1/bolts/_batch-suite.json"
}

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
( cd "$repo" && git init -q . )
mkunit "$repo" U-001
( cd "$repo" && echo "code1" > app_U-001.js && git add . \
  && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-001 thing" )

# 1. bolt commit, no gate artifact -> FAIL batch_suite_gate_missing
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 1 ] || { echo "1: expected exit 1 (no gate), got $rc"; err=1; }
echo "$out" | grep -q '"status": "FAIL"' || { echo "1: expected FAIL"; err=1; }
echo "$out" | grep -q 'batch_suite_gate_missing' || { echo "1: expected batch_suite_gate_missing halt"; err=1; }

# 2. red gate -> FAIL batch_suite_red
HEAD=$(git -C "$repo" rev-parse HEAD)
mkdir -p "$repo/.mega-sdd/vaults/v1/bolts"
printf '{ "status": "red", "passed": 4, "failed": 1, "head_sha": "%s", "units": ["U-001"] }\n' "$HEAD" \
  > "$repo/.mega-sdd/vaults/v1/bolts/_batch-suite.json"
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 1 ] || { echo "2: expected exit 1 (red), got $rc"; err=1; }
echo "$out" | grep -q 'batch_suite_red' || { echo "2: expected batch_suite_red halt"; err=1; }

# 3. green gate @HEAD -> PASS
greengate "$repo" "$HEAD"
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 0 ] || { echo "3: expected exit 0 (green@HEAD), got $rc"; err=1; }
echo "$out" | grep -q '"status": "PASS"' || { echo "3: expected PASS"; err=1; }

# 4. a NON-bolt commit after the green gate must NOT trip the gate (no new bolt work)
( cd "$repo" && echo "readme" > README.md && git add . \
  && git -c user.email=t@t -c user.name=t commit -qm "docs: readme" )
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 0 ] || { echo "4: non-bolt commit must not trip the gate, got $rc"; err=1; }

# 4b. an OUT-OF-BAND code commit (non-bolt subject, real source file) after the green
#     gate -> FAIL. This is the out-of-band half of the B2 incident: a hotfix / manual
#     edit / git pull that touches source without a bolt must invalidate the green suite.
( cd "$repo" && echo "hotfix" > app_hotfix.js && git add . \
  && git -c user.email=t@t -c user.name=t commit -qm "hotfix: tweak limit" )
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 1 ] || { echo "4b: out-of-band code commit must invalidate the green suite, got $rc"; err=1; }
echo "$out" | grep -q 'batch_suite_gate_missing' || { echo "4b: expected batch_suite_gate_missing on out-of-band edit"; err=1; }
# re-green at HEAD so case 5 starts from a covered state
greengate "$repo" "$(git -C "$repo" rev-parse HEAD)"
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 0 ] || { echo "4b: re-green@HEAD must PASS, got $rc"; err=1; }

# 5. a NEW bolt commit after the green gate -> stale -> FAIL
mkunit "$repo" U-002
( cd "$repo" && echo "code2" > app_U-002.js && git add . \
  && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-002 thing" )
out=$(bash "$VABS" --cwd="$repo" --batch-suite-gate); rc=$?
[ $rc -eq 1 ] || { echo "5: expected exit 1 (stale gate, new bolt), got $rc"; err=1; }
echo "$out" | grep -q 'batch_suite_gate_missing' || { echo "5: expected batch_suite_gate_missing on stale gate"; err=1; }

# 6. fresh repo with NO bolt commits -> PASS (nothing to gate)
clean=$(mktemp -d); ( cd "$clean" && git init -q . && mkdir -p .mega-sdd/vaults/v1 )
bash "$VABS" --cwd="$clean" --batch-suite-gate >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "6: no bolt commits must PASS, got $rc"; err=1; }
rm -rf "$clean"

# 8. a (bolt) commit touching ONLY .mega-sdd/ (verify-only bolt report) is NOT
#    code-bearing -> must NOT activate the gate -> PASS (pins the code-bearing filter).
vo=$(mktemp -d); ( cd "$vo" && git init -q . )
mkdir -p "$vo/.mega-sdd/vaults/v1/bolts/U-V"
printf 'verify report\n' > "$vo/.mega-sdd/vaults/v1/bolts/U-V/bolt-report.md"
( cd "$vo" && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-V verify" )
out=$(bash "$VABS" --cwd="$vo" --batch-suite-gate); rc=$?
[ $rc -eq 0 ] || { echo "8: verify-only (.mega-sdd-only) bolt must not require a suite gate, got $rc"; err=1; }
echo "$out" | grep -q '"status": "PASS"' || { echo "8: expected PASS for .mega-sdd-only bolt"; err=1; }
rm -rf "$vo"

# 7. non-git dir -> exit 0 no-op
plain=$(mktemp -d); mkdir -p "$plain/.mega-sdd"
bash "$VABS" --cwd="$plain" --batch-suite-gate >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "7: non-git dir must exit 0, got $rc"; err=1; }
rm -rf "$plain"

[ $err -eq 0 ] && echo "ALL PASS (test-batch-suite-gate)" || echo "FAILED"
exit $err
