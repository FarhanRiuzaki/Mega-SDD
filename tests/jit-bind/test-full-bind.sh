#!/usr/bin/env bash
# `sync --full-bind` (7.34.0, spec 2026-09-10 C4/§4 amendment; P1 debt #3): the
# whole-vault JIT sweep = the same three scripts with --units=all. Proves: `all`
# expands to every unit (both layouts), one open CONFLICT anywhere blocks under
# --units=all, and the front door + orchestrator name the button.
# Run: bash tests/jit-bind/test-full-bind.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units/U-003" "$T/src"
( cd "$T" && git init -q . && printf 'x\n' > src/exists.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm i )
unit() { printf -- '---\nid: %s\ntitle: t\ntask_type: create\nvault_source: model.md#a\ntarget_files:\n  - path: %s\n    operation: create\nacceptance_test:\n  - type: test\n    command: x\n    expects: "OK"\n---\n# u\n' "$1" "$2"; }
unit U-001 src/new1.ts > "$V/units/U-001.md"
unit U-002 src/exists.ts > "$V/units/U-002.md"          # create on an EXISTING file → fs CONFLICT
unit U-003 src/new3.ts > "$V/units/U-003/unit.md"       # directory layout
OUT="$(bash "$S/derive-unit-claims.sh" --cwd="$T" --vault="$V" --units=all 2>&1)"; RC=$?
[ $RC -eq 0 ] && echo "$OUT" | grep -q '"units": 3' && python3 -c "import json;d=json.load(open('$V/bolts/_wave-claims.json'));assert d['units']==['U-001','U-002','U-003'],d['units']" \
  && pass "a: --units=all → every unit, both layouts, sorted (3)" || fail "a: expansion wrong rc=$RC: $OUT"
for u in U-001 U-002 U-003; do bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=$u --claims="$V/bolts/_wave-claims.json" >/dev/null 2>&1 || fail "b: writer failed for $u"; done
python3 -c "import json;d=json.load(open('$V/bolts/U-002/binding.json'));assert d['summary']['CONFLICT']==1,d['summary']" && pass "b: U-002 create-on-existing → CONFLICT recorded by script (0 model tokens)" || fail "b: CONFLICT not recorded"
bash "$S/validate-handoff-binding-units.sh" --cwd="$T" --units=all --quiet >/dev/null 2>&1; RC=$?
python3 - "$T/.mega-sdd/.validation-blockers.json" "$RC" <<'EOF2' && pass "c: --units=all → all 3 LISTED, U-002's open CONFLICT is a BLOCKING drop (FAIL, exit 1)" || fail "c: full-bind gate wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
ju = {j["unit_id"]: j for j in d["jit_units"]}
assert set(ju) == {"U-001", "U-002", "U-003"} and all(j["listed"] for j in ju.values()), ju
assert d["status"] == "FAIL" and rc == 1 and any(x["type"] == "conflict_unresolved" and x["unit_id"] == "U-002" for x in d["drops"]), d["status"]
EOF2
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --resolve=C-U002-fs-01=KEEP_CODE --by=user >/dev/null 2>&1 || true
CID=$(python3 -c "import json;d=json.load(open('$V/bolts/U-002/binding.json'));print([c['id'] for c in d['claims'] if c['verdict']=='CONFLICT'][0])")
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-002 --resolve="$CID=KEEP_CODE" --by=user >/dev/null 2>&1
bash "$S/validate-handoff-binding-units.sh" --cwd="$T" --units=all --quiet >/dev/null 2>&1; [ $? -eq 0 ] && pass "d: resolved via the writer → --units=all PASS" || fail "d: still FAIL after resolution"
# e: derive refuses `all` on an empty vault (never a silent no-op sweep)
E="$T/.mega-sdd/vaults/empty"; mkdir -p "$E/units"; bash "$S/derive-unit-claims.sh" --cwd="$T" --vault="$E" --units=all >/dev/null 2>&1; [ $? -eq 2 ] && pass "e: --units=all on an empty vault → exit 2 (a sweep of nothing is an error, not a pass)" || fail "e: empty sweep passed"
# f: prose — the button is documented where BA/QA look
grep -q 'audit sinkronisasi penuh = `sync --full-bind`' "$P/commands/sync.md" && grep -q -- '--full-bind' "$P/skills/orchestrate-flow/SKILL.md" && grep -q -- '--full-bind' "$P/skills/execute-bolts/references/jit-bind-and-quarantine.md" && grep -q -- '\[--full-bind\]' "$P/skills/orchestrate-flow/references/sync-digest.md" \
  && pass "f: front door sentence (owner amendment) + orchestrator forwarding + JIT reference + sync report mode line" || fail "f: prose missing"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
