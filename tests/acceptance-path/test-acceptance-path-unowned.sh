#!/usr/bin/env bash
# acceptance_path_unowned (spec 2026-08-29 Fase 4) — behavioural + wiring.
#
# SCOPE, corrected 2026-08-29 after reading the B3 observer: a TEST path is a
# SANCTIONED EXTRA. The implementer writes AND commits the acceptance test even
# when the unit does not list it in target_files, and B3 never flags it ("units
# often do not list it" — validate-bolt-artifacts.sh §whitelist scan). The
# HOST-AS400 U-001 halt was therefore an implementer misjudgment from an
# incomplete contract, NOT an unfinishable unit; that is fixed in
# agents/bolt-implementer.md, not by this gate.
#
# What this gate covers is the narrow, unambiguous remainder: a NON-sanctioned
# path that no unit owns and that does not exist — an acceptance command that
# can only ever fail. Section A3 pins the sanctioned predicate against B3: if
# this check were stricter than the observer it defers to, it would block the
# normal convention on every unit.
#
# The aggregator blocks per explicit halt_type, so recording the issue is not
# enough: section E pins the gate leg, without which the halt is inert.
set -u
err=0
ok()  { echo "  ok: $*"; }
bad() { echo "  FAIL: $*"; err=1; }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VAL="$ROOT/plugins/mega-sdd/scripts/validate-unit-spec.sh"
B3="$ROOT/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
PT="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
IMP="$ROOT/plugins/mega-sdd/agents/bolt-implementer.md"
[ -f "$VAL" ] || { echo "FATAL: validator missing"; exit 1; }

mk_unit() {   # DIR ID TARGETS_BLOCK ACCEPTANCE_CMD
  cat > "$1/.mega-sdd/vaults/demo/units/$2.md" <<MD
---
id: $2
title: unit $2
task_type: create
vault_source: vault.md#x
target_files:
$3
acceptance_test:
  - type: test
    command: $4
---
# $2

## Goal
x
MD
}

new_project() {
  local d; d=$(mktemp -d)
  mkdir -p "$d/.mega-sdd/vaults/demo/units"
  echo "$d"
}

count_ap() {
  python3 -c '
import json,sys
d=json.load(open(sys.argv[1]+"/.mega-sdd/.unit-spec-state.json"))
print(len([i for i in d.get("issues",[]) if i.get("halt_type")=="acceptance_path_unowned"]))
' "$1"
}

echo "── A: undeclared + nonexistent NON-sanctioned path → flagged ──"
A=$(new_project)
mk_unit "$A" U-001 "  - path: packages/contract/openapi.yaml
    operation: create" "node scripts/verify-contract.mjs"
bash "$VAL" --cwd="$A" --quiet >/dev/null 2>&1
[ "$(count_ap "$A")" = "1" ] && ok "A flagged the unowned acceptance path" || bad "A did NOT flag (got $(count_ap "$A"))"
python3 -c '
import json,sys
d=json.load(open(sys.argv[1]+"/.mega-sdd/.unit-spec-state.json"))
i=[x for x in d["issues"] if x.get("halt_type")=="acceptance_path_unowned"][0]
assert i["unowned_paths"]==["scripts/verify-contract.mjs"], i["unowned_paths"]
assert i["unit_id"]=="U-001", i["unit_id"]
print("  ok: A payload carries unit_id + the exact unowned path")
' "$A" || err=1

echo "── A2: an undeclared TEST path is SANCTIONED → silent (the field case) ──"
A2=$(new_project)
mk_unit "$A2" U-001 "  - path: packages/contract/openapi.yaml
    operation: create" "bun test apps/api/test/contract/openapi-coverage.test.ts"
mk_unit "$A2" U-002 "  - path: src/b.ts
    operation: create" "npx jest tests/models/leave-request.test.ts"
mk_unit "$A2" U-003 "  - path: src/c.go
    operation: create" "go test ./internal/svc/handler_test.go"
mk_unit "$A2" U-004 "  - path: src/d.py
    operation: create" "pytest api/test_billing.py"
bash "$VAL" --cwd="$A2" --quiet >/dev/null 2>&1
[ "$(count_ap "$A2")" = "0" ] \
  && ok "A2 sanctioned test paths not flagged (4 ecosystem shapes)" \
  || bad "A2 flagged a B3-sanctioned test path — this gate would block the normal convention"

echo "── A3: the sanctioned predicate has NOT drifted from B3 ──"
python3 -c '
import re,sys
R=sys.argv[1]
needle=r"(?:^|/)(?:tests?|spec|specs|__tests__)/|_test\.go$|Test\.php$|(?:^|/)test_[^/]+\.py$|\.(?:spec|test)\.[jt]sx?$"
b3=open(R+"/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh").read()
vu=open(R+"/plugins/mega-sdd/scripts/validate-unit-spec.sh").read()
assert needle in b3, "B3 predicate moved in validate-bolt-artifacts.sh — re-pin this test"
assert needle in vu, "validate-unit-spec.sh no longer carries the IDENTICAL B3 predicate (drift)"
print("  ok: A3 SANCTIONED_RX byte-identical in both scripts")
' "$ROOT" || err=1

echo "── B: path declared by the SAME unit → silent ──"
B=$(new_project)
mk_unit "$B" U-001 "  - path: packages/contract/openapi.yaml
    operation: create
  - path: scripts/verify-contract.mjs
    operation: create" "node scripts/verify-contract.mjs"
bash "$VAL" --cwd="$B" --quiet >/dev/null 2>&1
[ "$(count_ap "$B")" = "0" ] && ok "B own-declared path not flagged" || bad "B false-flagged a declared path"

echo "── C: path declared by ANOTHER unit → silent (DAG-wide ownership) ──"
C=$(new_project)
mk_unit "$C" U-001 "  - path: packages/contract/openapi.yaml
    operation: create" "node scripts/verify-contract.mjs"
mk_unit "$C" U-002 "  - path: scripts/verify-contract.mjs
    operation: create" "node scripts/verify-contract.mjs"
bash "$VAL" --cwd="$C" --quiet >/dev/null 2>&1
[ "$(count_ap "$C")" = "0" ] && ok "C sibling-owned path not flagged" || bad "C false-flagged a sibling-owned path (ownership is not cross-unit)"

echo "── D: undeclared but EXISTING path → silent (pre-existing input) ──"
D=$(new_project)
mkdir -p "$D/config"; echo '{}' > "$D/config/jest.setup.json"
mk_unit "$D" U-001 "  - path: src/a.ts
    operation: create" "npx jest --config config/jest.setup.json"
bash "$VAL" --cwd="$D" --quiet >/dev/null 2>&1
[ "$(count_ap "$D")" = "0" ] && ok "D existing path not flagged" || bad "D false-flagged an existing file"

echo "── D2: non-path command shapes stay silent (false-positive floor) ──"
D2=$(new_project)
mk_unit "$D2" U-001 "  - path: src/a.ts
    operation: create" "npm test"
mk_unit "$D2" U-002 "  - path: src/b.ts
    operation: create" "pytest tests/"
mk_unit "$D2" U-003 "  - path: src/c.ts
    operation: create" "bunx @redocly/cli lint --format=stylish"
mk_unit "$D2" U-004 "  - path: src/d.ts
    operation: create" "go test ./..."
bash "$VAL" --cwd="$D2" --quiet >/dev/null 2>&1
[ "$(count_ap "$D2")" = "0" ] && ok "D2 bare/glob/dir/scope commands not flagged" || bad "D2 false-flagged a non-path token"

echo "── E: the gate leg is wired (else the halt is recorded and ignored) ──"
grep -q 'acceptance_path_unowned' "$PT" && ok "E1 pre-tool-use reads the halt_type" || bad "E1 gate leg missing — halt would never block"
grep -q 'acceptance-path' "$PT" && ok "E2 gate leg is named" || bad "E2 gate leg name missing"
bash -n "$PT" && ok "E3 pre-tool-use shell syntax ok" || bad "E3 pre-tool-use syntax error"
bash -n "$VAL" && ok "E4 validator shell syntax ok" || bad "E4 validator syntax error"
grep -q 'acceptance_path_unowned' "$ROOT/plugins/mega-sdd/references/halt-protocol.md" \
  && ok "E5 registered in the canonical halt registry" || bad "E5 not in halt-protocol.md"
grep -q '### acceptance_path_unowned' "$ROOT/plugins/mega-sdd/references/halt-families/bolts.md" \
  && ok "E6 has a halt-family guidance entry" || bad "E6 no family entry"

echo "── F: the implementer contract states the sanctioned extras (the real fix) ──"
grep -q 'sanctioned extras' "$IMP" && ok "F1 implementer told target_files ∪ sanctioned extras" || bad "F1 implementer still says target_files alone"
grep -qi 'COMMIT the acceptance test even when the unit does not list it' "$IMP" \
  && ok "F2 implementer told to commit the unlisted acceptance test" \
  || bad "F2 the instruction that prevents the false scope_creep_detected is missing"
grep -qi 'never park a written test outside the repo' "$IMP" \
  && ok "F3 parking the test outside the repo is forbidden" \
  || bad "F3 nothing forbids parking the test outside the repo (fake acceptance evidence)"

rm -rf "$A" "$A2" "$B" "$C" "$D" "$D2"
echo "──────────────────────────────"
[ $err -eq 0 ] && echo "acceptance-path: ALL PASS" || echo "acceptance-path: FAILED"
exit $err
