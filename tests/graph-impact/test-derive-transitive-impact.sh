#!/usr/bin/env bash
# test-derive-transitive-impact.sh — pins scripts/derive-transitive-impact.sh,
# the graph layer's FIRST chain consumer (spec 2026-08-12-graph-assisted-
# reconcile.md D1): reverse-depends_on closure over unit nodes, fail-open on a
# missing/unbuildable graph (a lens, never a gate). Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
SCRIPT="$P/scripts/derive-transitive-impact.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PRJ="$WORK/prj"
V="$PRJ/.mega-sdd/vaults/app"
mkdir -p "$V/units"

# Fixture: U-001 <- U-002 <- U-003 (depends_on chains), U-004 isolated.
mk_unit() { # id, depends_on-csv ('' = none)
  {
    printf -- '---\nid: %s\ntask_type: create\nvault_source: F-U-001\n' "$1"
    if [ -n "$2" ]; then
      printf 'depends_on:\n'
      for d in $(echo "$2" | tr ',' ' '); do printf '  - %s\n' "$d"; done
    fi
    printf 'target_files:\n  - path: src/%s.py\n    operation: create\n---\n\n## Goal\nfixture\n' "$1"
  } > "$V/units/$1.md"
}
mk_unit U-001 ""
mk_unit U-002 "U-001"
mk_unit U-003 "U-002"
mk_unit U-004 ""
# minimal vault manifest so build-graph has a vault to walk
printf '{"vault_version": "1.0", "scopes": []}\n' > "$V/vault.json"
printf '# idx\n' > "$V/00-index.md"

run() { bash "$SCRIPT" --vault="$V" --project="$PRJ" --units="$1" </dev/null 2>&1; }

echo "── a: transitive closure (input excluded) ──"
OUT_A=$(run "U-001"); RC=$?
[ "$RC" -eq 0 ] && ok "a0 exit 0" || fail "a0 rc=$RC: $OUT_A"
echo "$OUT_A" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['graph_available'] is True, d
assert d['transitive'] == ['U-002','U-003'], d
assert 'U-001' not in d['transitive'], d
" 2>/dev/null && ok "a1 downstream of U-001 = [U-002, U-003], input excluded, sorted" || fail "a1 wrong output: $OUT_A"

echo "── b: isolated unit → empty ──"
OUT_B=$(run "U-004")
echo "$OUT_B" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['graph_available'] is True and d['transitive'] == [], d
" 2>/dev/null && ok "b1 isolated unit → empty transitive" || fail "b1 wrong: $OUT_B"

echo "── c: fail-open when the graph cannot build ──"
PRJ2="$WORK/prj2"; mkdir -p "$PRJ2"
printf 'not-a-dir' > "$PRJ2/.mega-sdd"   # a FILE where the dir must be → rebuild fails
OUT_C=$(bash "$SCRIPT" --vault="$PRJ2/nope" --project="$PRJ2" --units="U-001" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_C" | grep -q '"graph_available": false' \
  && ok "c1 unbuildable graph → graph_available:false, exit 0 (fail-open)" || fail "c1 rc=$RC out=$OUT_C"

echo "── d: usage ──"
bash "$SCRIPT" --vault="$V" </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "d1 missing --units → exit 2" || fail "d1 rc=$RC"

echo "── e: determinism ──"
OUT_E1=$(run "U-001"); OUT_E2=$(run "U-001")
[ "$OUT_E1" = "$OUT_E2" ] && ok "e1 two runs byte-equal" || fail "e1 nondeterministic"

echo "── f: multi-vault scoping (inline-round catch — no cross-contamination) ──"
V2="$PRJ/.mega-sdd/vaults/pay"; mkdir -p "$V2/units"
printf '{"vault_version": "1.0"}\n' > "$V2/vault.json"; printf '# i\n' > "$V2/00-index.md"
printf -- '---\nid: U-001\ntask_type: create\ntarget_files:\n  - path: p.py\n    operation: create\n---\n# g\n' > "$V2/units/U-001.md"
printf -- '---\nid: U-009\ntask_type: create\ndepends_on:\n  - U-001\ntarget_files:\n  - path: q.py\n    operation: create\n---\n# g\n' > "$V2/units/U-009.md"
OUT_F=$(run "U-001")
echo "$OUT_F" | grep -q "U-009" && fail "f1 cross-vault leak: pay's U-009 in app's closure" || ok "f1 bare id scoped to --vault (no cross-vault leak)"
echo "$OUT_F" | grep -q "U-002" && ok "f2 own-vault dependents still found" || fail "f2 own-vault closure lost: $OUT_F"

echo "── g: cycle termination ──"
printf -- '---\nid: U-005\ntask_type: create\ndepends_on:\n  - U-006\ntarget_files:\n  - path: e.py\n    operation: create\n---\n# g\n' > "$V/units/U-005.md"
printf -- '---\nid: U-006\ntask_type: create\ndepends_on:\n  - U-005\ntarget_files:\n  - path: f.py\n    operation: create\n---\n# g\n' > "$V/units/U-006.md"
OUT_G=$(run "U-005"); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT_G" | grep -q '"U-006"' && ok "g1 depends_on cycle terminates (seen-set BFS)" || fail "g1 rc=$RC out=$OUT_G"

echo "── z: syntax + doc pins ──"
bash -n "$SCRIPT" 2>/dev/null && ok "z1 bash -n clean" || fail "z1 syntax"
TT="$P/skills/generate-units/references/task-typing.md"
grep -q "derive-transitive-impact.sh" "$TT" && ok "z2 reconcile step 2.6 wired" || fail "z2 step 2.6 missing"
grep -q "verify-recommended" "$TT" && ok "z3 verify-recommended phrasing" || fail "z3 phrasing missing"
grep -qi "fail-open\|never blocks" "$TT" && ok "z4 fail-open wording" || fail "z4 fail-open missing"
grep -q "derive-transitive-impact\|transitive" "$P/skills/orchestrate-flow/references/routing-rules.md" && ok "z5 delta-lane sentence" || fail "z5 delta sentence missing"
grep -qi "blast-radius order\|blast radius" "$P/commands/sync.md" && ok "z6 sync triage ordering (D2)" || fail "z6 triage ordering missing"
# negative pin: NO new status enum value leaked into the state model
grep -rqE 'status: *(needs-verify|verify-recommended)' "$P/skills/generate-units" "$P/scripts/compute-unit-staleness.sh" \
  && fail "z7 a new status enum value leaked (advisory only!)" || ok "z7 no new status enum value"

echo
echo "derive-transitive-impact: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
