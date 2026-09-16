#!/usr/bin/env bash
# L1 — deterministic top-up (spec docs/superpowers/specs/2026-09-16-clinic-levers-design.md §2, 8.3.0,
# MEASUREMENT PENDING). MEASURED on clinic lite 7.38.0 (research §2f): the controller topped up per
# burst; ready units waited ≈117 unit-min (= the 25 % idle). `derive-ready-units.sh` now emits
# `dispatch_plan` = cap − in-flight slots filled critical-path-first; the controller dispatches it
# VERBATIM. Pins: slots arithmetic from the ONE in-flight definition (vault_layouts.inflight_units) and
# the ONE cap (parallel_max), ordering by direct-dependent count, deferred list, slots=0 reason, and
# the prose clause. Run: bash tests/w2-fast-lane/test-l1-dispatch-plan.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units" "$V/bolts"
mk() { # $1 id  $2 depends_on yaml list ("" = none)
  { printf -- '---\nid: %s\ntitle: %s\ntask_type: create\ntarget_files:\n  - path: src/%s.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: x\n    expects: "OK"\n' "$1" "$1" "$1"
    [ -n "$2" ] && printf 'depends_on:\n%s\n' "$2"
    printf -- '---\n# %s\n\n## Implementation steps\n\n1. a\n' "$1"; } > "$V/units/$1.md"
}
mk U-001 ""; mk U-002 ""; mk U-003 ""; mk U-004 ""
mk U-005 $'  - U-001'; mk U-006 $'  - U-003'; mk U-007 $'  - U-003'      # U-003 has 2 dependents → first
mkdir -p "$V/bolts/U-001"; echo d > "$V/bolts/U-001/dispatch-prompt.md"   # U-001 in flight (no postflight)
run() { ( cd "$T" && bash "$S/derive-ready-units.sh" --cwd="$T" --vault="$V" 2>/dev/null ); }
J="$(run)"
python3 - "$J" <<'PY' && pass "a: cap 4 (default), U-001 in flight → slots 3; dispatch_now = U-003 (2 dependents) then U-002, U-004; deferred empty; dependents U-005/6/7 blocked" || fail "a: plan shape wrong: $J"
import json, sys
d = json.loads(sys.argv[1]); p = d["dispatch_plan"]
assert d["schema"] == "ready-units/2", d["schema"]
assert p["cap"] == 4 and p["in_flight"] == ["U-001"] and p["slots"] == 3, p
assert p["dispatch_now"] == ["U-003", "U-002", "U-004"], p["dispatch_now"]
assert p["deferred"] == [], p
assert sorted(b["unit"] for b in d["blocked"]) == ["U-005", "U-006", "U-007"], d["blocked"]
assert "NOW" in p["reason"], p["reason"]
PY
mkdir -p "$T/.mega-sdd"; printf 'parallel_max: 2\n' > "$T/.mega-sdd/config.yaml"
J="$(run)"
python3 - "$J" <<'PY' && pass "b: parallel_max 2 (config.yaml) → slots 1: dispatch_now=[U-003], deferred=[U-002,U-004]" || fail "b: cap from config not honoured: $J"
import json, sys
p = json.loads(sys.argv[1])["dispatch_plan"]
assert p["cap"] == 2 and p["slots"] == 1 and p["dispatch_now"] == ["U-003"] and p["deferred"] == ["U-002", "U-004"], p
PY
mkdir -p "$V/bolts/U-002"; echo d > "$V/bolts/U-002/dispatch-prompt.md"   # second in flight → cap reached
J="$(run)"
python3 - "$J" <<'PY' && pass "c: in_flight == cap → slots 0, dispatch_now empty, reason says wait for the next return (never a timer)" || fail "c: slots-0 reason wrong: $J"
import json, sys
p = json.loads(sys.argv[1])["dispatch_plan"]
assert p["slots"] == 0 and p["dispatch_now"] == [] and "next implementer return" in p["reason"] and "timer" in p["reason"], p
PY
sleep 1; echo '{"status":"pass"}' > "$V/bolts/U-002/postflight.json"           # U-002 leaves the in-flight window
J="$(run)"
python3 - "$J" <<'PY' && pass "d: postflight newer than dispatch-prompt frees the slot (ONE in-flight definition: vault_layouts.inflight_units)" || fail "d: slot not freed: $J"
import json, sys
p = json.loads(sys.argv[1])["dispatch_plan"]
assert p["in_flight"] == ["U-001"] and p["slots"] == 1 and p["dispatch_now"] == ["U-003"], p
PY
grep -q 'dispatch_plan.dispatch_now' "$ROOT/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md" && grep -q 'never composes a burst' "$ROOT/plugins/mega-sdd/skills/execute-bolts/references/batch-and-fanout.md" \
  && pass "e: execute-bolts lite clause makes dispatch_plan the ONLY dispatch source (verbatim, same message, never a burst)" || fail "e: prose clause missing"
grep -q 'MEASUREMENT PENDING' "$S/derive-ready-units.sh" && pass "f: the script header labels L1 MEASUREMENT PENDING (evidence-first: no measured claim until the xs runs)" || fail "f: measurement label missing"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
