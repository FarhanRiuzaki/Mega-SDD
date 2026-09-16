#!/usr/bin/env bash
# L2 — `validate-unit-spec.sh` dag_shape_advisory (spec docs/superpowers/specs/2026-09-16-clinic-levers-design.md
# §2, 8.3.0, MEASUREMENT PENDING). MEASURED on clinic lite 7.38.0 (research §2f): the plan DAG bound the
# wall once the panel barrier was gone — critical path 5 hops ≈ the whole bolt-stage, hub units, fat
# units. The validator now NAMES the critical path (depth > 4), hubs (>= 3 direct dependents) and split
# candidates (> 6 steps or > 4 target files) as an ADVISORY — never an issue / status / exit code; a
# well-shaped DAG yields null. Run: bash tests/unit-grammar-p1/test-dag-shape-advisory.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units"
mk() { # $1 id  $2 depends_on block ("" none)  $3 n target files  $4 n steps
  { printf -- '---\nid: %s\ntitle: %s\ntask_type: create\nvault_source: flows.md#F-U-001\ntarget_files:\n' "$1" "$1"
    for i in $(seq 1 "$3"); do printf '  - path: src/%s-%d.ts\n    operation: create\n' "$1" "$i"; done
    printf 'acceptance_test:\n  - type: test\n    command: x\n    expects: "OK"\n'
    [ -n "$2" ] && printf 'depends_on:\n%s\n' "$2"
    printf -- '---\n# u\n\n## Goal\n\nx\n\n## Implementation steps\n\n'
    for i in $(seq 1 "$4"); do printf '%d. step\n' "$i"; done; } > "$V/units/$1.md"
}
state() { ( cd "$T" && bash "$S/validate-unit-spec.sh" --cwd="$T" --quiet >/dev/null 2>&1 ); echo $?; }
# ── a: deep chain (5 hops) + a hub (3 dependents) + a fat unit ──
mk U-001 "" 1 2
mk U-002 $'  - U-001' 1 2; mk U-003 $'  - U-002' 1 2; mk U-004 $'  - U-003' 1 2; mk U-005 $'  - U-004' 1 2   # 5 hops
mk U-006 $'  - U-001' 1 2; mk U-007 $'  - U-001' 1 2                                                     # U-001 → 3 dependents (hub)
mk U-008 "" 5 8                                                                                            # fat: 5 files, 8 steps
RC=$(state); ST="$T/.mega-sdd/.unit-spec-state.json"; [ -f "$ST" ] || ST="$(ls "$T"/.mega-sdd/.unit-spec*.json 2>/dev/null | head -1)"
python3 - "$ST" "$RC" <<'PY' && pass "a: depth 5 named with its critical path, hub U-001 (3 dependents), split candidate U-008 (5 files / 8 steps); status PASS, rc 0, no issue leaked" || fail "a: advisory shape wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2]); a = d["dag_shape_advisory"]
assert a and a["depth"] == 5 and a["depth_budget"] == 4, a
assert a["critical_path"] == ["U-005", "U-004", "U-003", "U-002", "U-001"], a["critical_path"]
assert a["hubs"] == [{"unit_id": "U-001", "dependents": 3}], a["hubs"]
assert a["split_candidates"] == [{"unit_id": "U-008", "steps": 8, "target_files": 5}], a["split_candidates"]
assert a["cycle_suspected"] is False
assert not any("dag" in (i.get("halt_type") or "") for i in d["issues"]), "advisory leaked into issues"
assert "dag_shape_advisory" in d["next_action"] and "never a halt" in d["next_action"]
assert d["status"] == "PASS" and rc == 0, (d["status"], rc)
PY
# ── b: well-shaped DAG → null, next_action silent about the DAG ──
rm -f "$V/units/U-005.md" "$V/units/U-007.md" "$V/units/U-008.md"   # depth 4, U-001 has 2 dependents, no fat unit
RC=$(state)
python3 - "$ST" "$RC" <<'PY' && pass "b: depth 4 / 2 dependents / lean units → advisory null, next_action carries no DAG sentence" || fail "b: false advisory"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["dag_shape_advisory"] is None, d["dag_shape_advisory"]
assert "DAG shape" not in d["next_action"], d["next_action"]
PY
# ── c: prose — the plan procedure reads the advisory and reshapes before presenting ──
P="$ROOT/plugins/mega-sdd/skills/plan/references/plan-procedure.md"
grep -q 'dag_shape_advisory' "$P" && grep -q 'depth ≤ 4' "$P" && pass "c: plan-procedure carries the DAG rails (depth ≤ 4, hub, split) and reads dag_shape_advisory" || fail "c: plan procedure lacks the DAG rails"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
