#!/usr/bin/env bash
# v8 P2 W2 fast lane (lane lite; research/2026-09-11-v8-p2-report.md §1): unit-level
# readiness via derive-ready-units.sh + the three lite clauses in execute-bolts prose.
# The DEFAULT lane keeps its pinned "Wave boundary = review boundary" sentence.
# Run: bash tests/w2-fast-lane/test-w2-lite.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units" "$T/src"
( cd "$T" && git init -q . && printf 'a\n' > src/a.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm i )
H="$(cd "$T" && shasum -a 256 src/a.ts | cut -c1-64)"
unit() { printf -- '---\nid: %s\ntitle: t\ntask_type: create\nvault_source: model.md#a\ndepends_on: [%s]\ntarget_files:\n  - path: src/a.ts\n    operation: modify\nacceptance_test:\n  - type: test\n    command: x\n    expects: "OK"\n---\n# u\n' "$1" "$2" > "$V/units/$1.md"; }
unit U-001 ""; unit U-002 "U-001"; unit U-003 "U-002"; unit U-004 "U-005"; unit U-005 ""; unit U-006 "U-001, U-007"; unit U-007 ""
done_unit() { mkdir -p "$V/bolts/$1"; printf -- '---\nunit: %s\nstatus: completed\ntarget_hashes:\n  src/a.ts: %s\n---\n# r\n' "$1" "$H" > "$V/bolts/$1/bolt-report.md"; echo '{"status":"pass"}' > "$V/bolts/$1/acceptance.json"; [ "${2:-}" = "nopost" ] || echo '{"status":"pass"}' > "$V/bolts/$1/postflight.json"; }
done_unit U-001; done_unit U-007 nopost
mkdir -p "$V/bolts/U-005"; echo '{"schema":"unit-quarantine/1","unit":"U-005","halt_type":"acceptance_red","reason":"x"}' > "$V/bolts/U-005/quarantine.json"
OUT="$(bash "$S/derive-ready-units.sh" --cwd="$T" --vault="$V" 2>&1)"; RC=$?
python3 - "$OUT" "$RC" <<'EOF2' && pass "a: ready = deps implemented with acceptance+postflight pass (U-002); blocked = dep without postflight (U-006 waits U-007), dep quarantined (U-004 waits U-005), dep not done (U-003); done = U-001; quarantined = U-005" || fail "a: ready set wrong (rc=$RC): $OUT"
import json, sys
d = json.loads(sys.argv[1]); assert int(sys.argv[2]) == 0
assert d["ready"] == ["U-002"], d["ready"]
blocked = {b["unit"]: b["waiting_on"] for b in d["blocked"]}
assert blocked == {"U-003": ["U-002"], "U-004": ["U-005"], "U-006": ["U-007"]}, blocked
assert d["done"] == ["U-001"] and d["quarantined"] == ["U-005"], (d["done"], d["quarantined"])
assert "U-007" in d["in_progress"], d["in_progress"]
EOF2
bash "$S/derive-ready-units.sh" --cwd="$T" >/dev/null 2>&1; [ $? -eq 2 ] && pass "b: missing --vault → exit 2" || fail "b: usage exit wrong"
EB="$P/skills/execute-bolts"
grep -qF 'Wave boundary = review boundary' "$EB/references/batch-and-fanout.md" && grep -q 'Lane lite (v8 W2' "$EB/references/batch-and-fanout.md" && grep -q 'derive-ready-units.sh' "$EB/references/batch-and-fanout.md" \
  && pass "c: default wave barrier sentence intact; lite clause names the readiness script and the blocking rules" || fail "c: batch-and-fanout prose"
grep -q 'lane lite (v8 W2) + `unit_tier: xs`: the fix-round budget is 1' "$EB/references/review-panel.md" && pass "d: xs fix-round budget 1 under lite, then quarantine" || fail "d: review-panel prose"
grep -q 'w2_model_cell: xs→sonnet' "$EB/SKILL.md" && grep -q 'Lane lite (v8 W2 measured cell)' "$EB/SKILL.md" && pass "e: xs→sonnet cell under lite recorded in the bolt-report, override chain intact" || fail "e: SKILL model routing prose"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
