#!/usr/bin/env bash
# test-t3-expects-gate.sh — F-18 (spec 2026-08-30 §3.3).
#
# Field measurement: acceptance.json recorded `expects: ""` on 69/69 entries, so
# B4 measured `rc == 0` of a test the same model wrote — and never observed a
# single failure in a run where 18 fix commits came from OTHER catchers.
# `run-acceptance-tests.sh:220` makes an empty `expects` vacuously true. This pins:
#   A  validate-unit-spec.sh records acceptance_expects_missing per unit for a
#      command-bearing `type: test` entry with empty/absent expects (manual and
#      render entries are exempt)
#   B  the execute-bolts Skill entry (inline's only gate) is never held by
#      acceptance_expects_missing (no retro-block of an already-running
#      project); since P3 no gate reads it (plan Step 5 and analyze fail on it)
#   C  the writer records expects_missing + output_tail, so a log-flooded
#      output no longer eats the pass/fail line
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugins/mega-sdd/scripts"; HOOK="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }
repo="$WORK/repo"; V="$repo/.mega-sdd/vaults/v1"
mkdir -p "$V/units" "$V/bolts" "$repo/src"
( cd "$repo" && git init -q . && echo seed > src/seed.js && git add -A && git -c user.email=t@t -c user.name=t commit -q -m seed )
G(){ git -C "$repo" -c user.email=t@t -c user.name=t "$@"; }
J(){ python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$1" "$2"; }
unit(){ # uid acceptance-yaml-lines...
  local uid="$1"; shift
  { printf -- '---\nunit_id: %s\ntask_type: create\ntarget_files:\n  - path: src/%s.js\n    operation: create\nacceptance_test:\n' "$uid" "$uid"
    for l in "$@"; do printf -- '%s\n' "$l"; done
    printf -- '---\n# %s\n\n## Goal\nx\n' "$uid"; } > "$V/units/$uid.md"
}

echo "── A: the validator names the vacuous entries ──"
unit U-001 '  - type: test' '    command: "echo 3 passed"'                                   # empty expects
unit U-002 '  - type: test' '    command: "echo 3 passed"' '    expects: "3 passed"'          # honest
unit U-003 '  - type: manual' '    desc: "operator checks the screen"' '  - type: render' '    command: "echo ok"'   # exempt kinds
bash "$S/validate-unit-spec.sh" --cwd="$repo" --quiet >/dev/null 2>&1
ST="$repo/.mega-sdd/.unit-spec-state.json"
[ "$(J "$ST" 'sorted(i["unit_id"] for i in d["issues"] if i["halt_type"]=="acceptance_expects_missing")')" = "['U-001']" ] \
  && ok "A1 exactly U-001 flagged acceptance_expects_missing (honest + exempt kinds silent)" \
  || bad "A1 flagged: $(J "$ST" '[ (i["unit_id"], i["halt_type"]) for i in d["issues"] ]')"
J "$ST" '[i for i in d["issues"] if i["halt_type"]=="acceptance_expects_missing"][0]["detail"]' | grep -q "expects" \
  && ok "A2 detail explains the vacuous rc==0 and the fix (add expects)" || bad "A2 detail unhelpful"

echo "── B: the Skill entry is never held by expects ──"
drive(){ printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }
OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--all\"}}")
if printf '%s' "$OUT" | grep -q 'acceptance_expects_missing'; then bad "B4 execute-bolts Skill entry held by acceptance_expects_missing (would freeze a running project)"; else ok "B4 the execute-bolts Skill entry (inline's only gate) is never held by acceptance_expects_missing"; fi

echo "── C: the writer records what it could not verify ──"
unit U-004 '  - type: test' '    command: "for i in $(seq 1 200); do echo log line $i; done; echo FINAL: 7 passed"'
echo u4 > "$repo/src/U-004.js"; G add src/U-004.js .mega-sdd >/dev/null
G commit -q -m "feat(U-004): bolt

Unit: U-004
SDD-Acceptance: v5" >/dev/null
bash "$S/run-acceptance-tests.sh" --cwd="$repo" --unit=U-004 --quiet >/dev/null 2>&1
A="$V/bolts/U-004/acceptance.json"
[ "$(J "$A" 'd.get("expects_missing")')" = "1" ] && ok "C1 acceptance.json counts expects_missing" || bad "C1 expects_missing=$(J "$A" 'd.get("expects_missing")')"
J "$A" '[e for e in d["entries"] if e.get("type")=="test"][0].get("output_tail","")' | grep -q "FINAL: 7 passed" \
  && ok "C2 output_tail keeps the pass/fail line that output_head lost to the log flood" || bad "C2 output_tail missing the final line"
J "$A" '[e for e in d["entries"] if e.get("type")=="test"][0]["output_head"]' | grep -q "FINAL" && bad "C2b precondition: head unexpectedly contains FINAL" || ok "C2b (precondition) output_head is flooded by the log"

echo; [ $err -eq 0 ] && { echo "test-t3-expects-gate: ALL PASS"; exit 0; } || { echo "test-t3-expects-gate: FAILED"; exit 1; }
