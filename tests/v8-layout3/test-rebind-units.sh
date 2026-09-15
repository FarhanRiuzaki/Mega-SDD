#!/usr/bin/env bash
# v8 P3 (spec 2026-09-10 §4 row "re-bind": `bind --paths=@` → `bolts --rebind=@paths`):
# rebind-units.sh = the lane-lite / layout-3 re-bind hop — scope by intersection with the
# changed paths (target_files ∪ ## Anchors ∪ existing_interfaces ∪ per-unit binding anchors),
# then the SAME sanctioned writers the JIT step uses (derive-unit-claims → write-unit-binding
# per unit → validate-handoff-binding-units --units=). Never a second grammar.
#   a  nothing intersects → exit 0, affected=[], gate in_sync, no binding written
#   b  a changed target path → exit 4, that unit re-bound (bolts/U-XXX/binding.json), gate PASS
#   c  ancestor-dir rule: a changed dir ABOVE an anchored file counts (both directions)
#   d  a per-unit binding anchor (not in the unit text) also pulls the unit in
#   e  a create-over-existing after the code moved → CONFLICT surfaced + gate FAIL (moat intact)
#   f  --units=all = every unit (sync --full-bind on the lite lane)
#   g  usage: no --paths and no --units=all → exit 2
# Run: bash tests/v8-layout3/test-rebind-units.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units" "$T/src/a" "$T/src/b" "$T/src/lib"
( cd "$T" && git init -q . && echo x > src/a/one.ts && echo y > src/b/two.ts && echo z > src/lib/util.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm i )
unit() { # id task_type path op [anchors-line]
  printf -- '---\nid: %s\ntitle: t\ntask_type: %s\nvault_source: context.md#f\ntarget_files:\n  - path: %s\n    operation: %s\nacceptance_test:\n  - type: test\n    command: x\n    expects: "ok"\n---\n# u\n\n## Anchors\n%s\n' "$1" "$2" "$3" "$4" "${5:-}" > "$V/units/$1.md"; }
unit U-001 extend src/a/one.ts modify "- src/a/one.ts:1 — x"
unit U-002 create src/c/new.ts create ""
unit U-003 extend src/b/two.ts modify "- src/lib/util.ts:1 — a helper (file anchor; the changed set names its DIR)"
unit U-004 create src/d/fresh.ts create ""
J() { python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(eval(sys.argv[2], {"d": d}))' "$1" "$2"; }

OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --paths=src/zzz.ts 2>&1)"; RC=$?
[ $RC -eq 0 ] && [ "$(J "$OUT" 'd["affected"]')" = "[]" ] && [ "$(J "$OUT" 'd["gate"]')" = "in_sync" ] && [ ! -e "$V/bolts/U-001/binding.json" ] \
  && pass "a: no intersection → exit 0, affected=[], gate in_sync, nothing written" || fail "a: rc=$RC $OUT"

printf 'src/a/one.ts\n' > "$T/changed.txt"
OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --paths=@"$T/changed.txt" 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ "$(J "$OUT" 'd["affected"]')" = "['U-001']" ] && [ "$(J "$OUT" 'd["gate"]')" = "PASS" ] && [ -f "$V/bolts/U-001/binding.json" ] && [ ! -e "$V/bolts/U-002/binding.json" ] \
  && pass "b: changed target path → exit 4, only U-001 re-bound (bolts/U-001/binding.json), gate PASS" || fail "b: rc=$RC $OUT"

OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --paths=src/lib 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ "$(J "$OUT" 'd["affected"]')" = "['U-003']" ] \
  && pass "c: a changed DIR (src/lib) above an anchored file pulls that unit in (ancestor rule, both directions)" || fail "c: rc=$RC $OUT"

# d: an anchor recorded only in the per-unit binding (symbol verdict anchor) pulls the unit in
python3 - "$V/bolts/U-001/binding.json" <<'PY'
import json, sys; p = sys.argv[1]; d = json.load(open(p))
d["claims"].append({"id": "C-U001-X1", "kind": "symbol", "expect": "src/b/two.ts:two", "source": "x", "verdict": "CONFIRMED", "state": "IMPLEMENTED", "anchor": "src/b/two.ts:1", "confidence": "high", "evidence": "t"})
json.dump(d, open(p, "w"), indent=1)
PY
OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --paths=src/b/two.ts 2>&1)"; RC=$?
echo "$(J "$OUT" 'd["affected"]')" | grep -q 'U-001' && echo "$(J "$OUT" 'd["affected"]')" | grep -q 'U-003' \
  && pass "d: per-unit binding anchor (src/b/two.ts in U-001's binding) + U-003's target both affected" || fail "d: rc=$RC $OUT"

# e: the code moved under a create unit → create-over-existing CONFLICT, gate FAIL
( cd "$T" && mkdir -p src/c && echo n > src/c/new.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm "hotfix: new.ts landed out of band" )
OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --paths=src/c/new.ts 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ "$(J "$OUT" 'd["affected"]')" = "['U-002']" ] && [ "$(J "$OUT" 'd["conflicts"]')" = "1" ] && [ "$(J "$OUT" 'd["gate"]')" = "FAIL" ] \
  && pass "e: create-over-existing after an out-of-band commit → 1 CONFLICT, gate FAIL (moat intact), next names resolve-oq --binding" || fail "e: rc=$RC $OUT"
grep -q 'conflict_unresolved' "$T/.mega-sdd/.validation-blockers.json" && pass "e2: .validation-blockers.json carries the drop" || fail "e2: blockers state: $(head -c 200 "$T/.mega-sdd/.validation-blockers.json" 2>/dev/null)"

OUT="$(bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" --units=all 2>&1)"; RC=$?
[ $RC -eq 4 ] && [ "$(J "$OUT" 'len(d["affected"])')" = "4" ] && [ -f "$V/bolts/U-004/binding.json" ] \
  && pass "f: --units=all re-binds every unit (lite-lane full audit)" || fail "f: rc=$RC $OUT"

bash "$S/rebind-units.sh" --cwd="$T" --vault="$V" >/dev/null 2>&1; [ $? -eq 2 ] && pass "g: no scope argument → exit 2" || fail "g: usage exit"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
