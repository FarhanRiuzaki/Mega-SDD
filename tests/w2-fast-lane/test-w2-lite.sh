#!/usr/bin/env bash
# v8 P2 W2 fast lane (research/2026-09-11-v8-p2-report.md §1): unit-level readiness via
# derive-ready-units.sh + the three W2 clauses in execute-bolts prose.
# 9.0 P1: the lite pipeline is the ONLY pipeline (lane:standard / the classic spine retired,
# docs/superpowers/specs/2026-09-27-v9-simplification-design.md), so the DEFAULT lane's
# "Wave boundary = review boundary" barrier sentence is retired and the W2 clauses are no
# longer lane-conditional ("execute-bolts runs the lite lane only").
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
BF="$EB/references/batch-and-fanout.md"
grep -qF 'Unit-level readiness replaces the wave barrier (v8 W2; execute-bolts runs the lite lane only)' "$BF" \
  && grep -qF 'bash <plugin-root>/scripts/derive-ready-units.sh --cwd=<root> --vault=<vault>' "$BF" \
  && grep -qF 'A dependency that is quarantined, red, stale, or missing evidence BLOCKS its dependents' "$BF" \
  && grep -qF 'never by cap-sized slices with a barrier' "$BF" && ! grep -qF 'Wave boundary = review boundary' "$BF" \
  && pass "c: readiness clause (unconditional — lite is the only lane) names the readiness script and the blocking rules; retired wave barrier gone" || fail "c: batch-and-fanout prose"
# v8 P3 (research/2026-09-15-v8-p3-report.md §2): per-unit pipelining rules + the cap doc drift (5 → parallel_max 4)
grep -q 'P3 pipelining rules' "$EB/references/batch-and-fanout.md" && grep -q 'panel_pending_units' "$EB/references/batch-and-fanout.md" \
  && grep -q 'never batch the panels of a slice' "$EB/references/batch-and-fanout.md" && grep -q 'top up dispatch to the cap' "$EB/references/batch-and-fanout.md" \
  && pass "f: lite clause carries the P3 pipelining rules (panel per unit, top-up to cap, panel-pending gate semantics)" || fail "f: batch-and-fanout P3 prose"
grep -q 'default \*\*4\*\* concurrent' "$EB/references/batch-and-fanout.md" && grep -q 'default \*\*4\*\* concurrent' "$EB/references/squad-subagent.md" \
  && ! grep -q 'default \*\*5\*\* concurrent' "$EB/references/batch-and-fanout.md" "$EB/references/squad-subagent.md" \
  && pass "g: in-flight cap documented as parallel_max default 4 in both references (no 5 left)" || fail "g: cap doc drift"
python3 - "$S/_lib" <<'EOF3' && pass "h: vault_layouts.parallel_max is importable with the documented default" || fail "h: vault_layouts.parallel_max"
import sys, os, tempfile; sys.path.insert(0, sys.argv[1]); import vault_layouts
d = tempfile.mkdtemp(); assert vault_layouts.parallel_max(d) == 4
os.makedirs(os.path.join(d, ".mega-sdd")); open(os.path.join(d, ".mega-sdd", "config.yaml"), "w").write("lane: lite\nparallel_max: 2   # cap\n")
assert vault_layouts.parallel_max(d) == 2
EOF3
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
