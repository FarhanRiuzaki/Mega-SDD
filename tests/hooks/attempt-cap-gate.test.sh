#!/usr/bin/env bash
# attempt-cap-gate.test.sh — spec docs/superpowers/specs/2026-09-20-hook-enforced-attempt-cap-design.md
#
# `--max-retries` was a number the controller was trusted to count; a count that
# lives in model context does not survive compaction or a --resume (field: U-008
# ran 4 fix rounds against a budget of 3). This pins the mechanism:
#   R  resolve-review-tier.sh resolves retry_budget + its source (default / flag /
#      config / xs-lite; the flag beats xs-lite; garbage is ignored, never trusted)
#   A  the hook counts a bolt-implementer dispatch ONLY on a final ALLOW and denies
#      the dispatch that would exceed 1 + retry_budget (review_critical_unresolved)
#   B  a dispatch denied by ANOTHER gate costs no budget
#   C  migration guarantee: no review-tier.json, or one without retry_budget
#      (written by an older plugin) → silent allow, no attempts.json
#   D  anti-self-bypass: Bash and Write/Edit on bolts/U-*/attempts.json are denied
#   E  merge-panel-findings.sh reports budget_left and prints gate: halt at 0
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOK="$PLUGIN/hooks/pre-tool-use"
RT="$PLUGIN/scripts/resolve-review-tier.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { echo "  ok: $1"; }
bad() { echo "  FAIL: $1"; fail=1; }
SID="attempt-cap-test"

drive() { printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }
agent_payload() { # $1=project $2=unit
  printf '{"session_id":"%s","cwd":"%s","tool_name":"Agent","tool_input":{"subagent_type":"mega-sdd:bolt-implementer","description":"bolt","prompt":"Read <vault>/bolts/%s/dispatch-prompt.md first. mega-sdd-trace:execute-bolts"}}' "$SID" "$1" "$2"
}
jget() { python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]))" "$1" "$2" 2>/dev/null; }

mkproj() { # $1=dir — an SDD project with one unit and NO bolt commit
  local f="$1" v="$1/.mega-sdd/vaults/app"
  mkdir -p "$v/units" "$v/bolts" "$f/src"
  printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: src/a.js\n    operation: create\nacceptance_test:\n  - type: test\n    command: "true"\n    expects: "ok"\n---\n# U-001\n\n## Goal\nship a.js\n\n## Implementation steps\n1. write src/a.js\n' > "$v/units/U-001.md"
  ( cd "$f" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -q -m seed )
}

echo "── R: retry_budget resolution ──"
P0="$WORK/r"; mkproj "$P0"; U="$P0/.mega-sdd/vaults/app/units/U-001.md"
OUT=$(bash "$RT" --unit "$U" 2>/dev/null)
printf '%s' "$OUT" | grep -q '"retry_budget":3' && printf '%s' "$OUT" | grep -q '"retry_budget_source":"default"' && ok "R1 default → 3 / default" || bad "R1 $OUT"
OUT=$(bash "$RT" --unit "$U" --max-retries=5 2>/dev/null)
printf '%s' "$OUT" | grep -q '"retry_budget":5' && printf '%s' "$OUT" | grep -q '"retry_budget_source":"flag"' && ok "R2 --max-retries=5 → 5 / flag" || bad "R2 $OUT"
printf 'parallel_max: 4\nmax_retries: 2\n' > "$P0/.mega-sdd/config.yaml"
OUT=$(bash "$RT" --unit "$U" 2>/dev/null)
printf '%s' "$OUT" | grep -q '"retry_budget":2' && printf '%s' "$OUT" | grep -q '"retry_budget_source":"config"' && ok "R3 config max_retries: 2 → 2 / config" || bad "R3 $OUT"
OUT=$(bash "$RT" --unit "$U" --max-retries=banana 2>/dev/null)
printf '%s' "$OUT" | grep -q '"retry_budget":2' && ok "R4 a garbage flag is ignored (falls to config), never trusted" || bad "R4 $OUT"
PYR=$(MEGA_SDD_LIB_DIR="$PLUGIN/scripts/_lib" python3 - "$P0" <<'PY'
import os, sys
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"]); import vault_layouts as v
root = sys.argv[1]; vr = os.path.join(root, ".mega-sdd", "vaults", "app")
print(v.retry_budget(root, vr, "xs", None, True), v.retry_budget(root, vr, "m", None, True),
      v.retry_budget(root, vr, "xs", "4", True), v.retry_budget(root, vr, "xs", None, False), v.retry_budget(root, vr, "xs", "-1", True))
PY
)
[ "$PYR" = "(1, 'xs-lite') (2, 'config') (4, 'flag') (2, 'config') (1, 'xs-lite')" ] \
  && ok "R5 xs-lite → 1; non-xs lite → config; the flag beats xs-lite; xs on the classic lane → config; a negative flag is ignored" || bad "R5 $PYR"
touch "$P0/.mega-sdd/vaults/app/context.md"
PYR=$(MEGA_SDD_LIB_DIR="$PLUGIN/scripts/_lib" python3 -c "
import os,sys; sys.path.insert(0, os.environ['MEGA_SDD_LIB_DIR']); import vault_layouts as v
print(v.retry_budget('$P0', '$P0/.mega-sdd/vaults/app', 'xs'))")
[ "$PYR" = "(1, 'xs-lite')" ] && ok "R6 a layout-3 vault (context.md) reads as lane lite without a flag" || bad "R6 $PYR"

echo "── A: count on ALLOW, deny past the budget ──"
F="$WORK/a"; mkproj "$F"; V="$F/.mega-sdd/vaults/app"
bash "$RT" --unit "$V/units/U-001.md" --write --max-retries=1 >/dev/null 2>&1
AT="$V/bolts/U-001/attempts.json"
[ "$(jget "$V/bolts/U-001/review-tier.json" retry_budget)" = "1" ] && ok "A0 --write persisted retry_budget: 1" || bad "A0 review-tier.json: $(cat "$V/bolts/U-001/review-tier.json" 2>/dev/null | head -c 200)"
OUT=$(drive "$(agent_payload "$F" U-001)")
[ -z "$OUT" ] && [ "$(jget "$AT" dispatches)" = "1" ] && ok "A1 1st dispatch allowed, dispatches=1" || bad "A1 out=[$(printf '%s' "$OUT" | head -c 160)] n=$(jget "$AT" dispatches)"
OUT=$(drive "$(agent_payload "$F" U-001)")
[ -z "$OUT" ] && [ "$(jget "$AT" dispatches)" = "2" ] && ok "A2 2nd dispatch (the 1 retry) allowed, dispatches=2" || bad "A2 out=[$(printf '%s' "$OUT" | head -c 160)] n=$(jget "$AT" dispatches)"
OUT=$(drive "$(agent_payload "$F" U-001)")
printf '%s' "$OUT" | grep -q '"deny"' && printf '%s' "$OUT" | grep -q 'review_critical_unresolved' && printf '%s' "$OUT" | grep -q '2 bolt-implementer dispatch' \
  && printf '%s' "$OUT" | grep -q 'source: flag' && printf '%s' "$OUT" | grep -q 'Keterangan' \
  && ok "A3 3rd dispatch DENIED — halt type, count, budget source and keterangan in the reason" || bad "A3 $(printf '%s' "$OUT" | head -c 300)"
[ "$(jget "$AT" dispatches)" = "2" ] && ok "A4 the denied dispatch cost no budget (still 2)" || bad "A4 n=$(jget "$AT" dispatches)"
[ "$(jget "$AT" written_by)" = "pre-tool-use" ] && ok "A5 attempts.json stamped by its sole writer" || bad "A5 $(cat "$AT")"
rm -f "$AT"
OUT=$(drive "$(agent_payload "$F" U-001)")
[ -z "$OUT" ] && [ "$(jget "$AT" dispatches)" = "1" ] && ok "A6 human reset (attempts.json removed) re-opens the unit" || bad "A6 out=[$(printf '%s' "$OUT" | head -c 160)]"

echo "── B: a dispatch another gate denies costs no budget ──"
G="$WORK/b"; mkproj "$G"; VG="$G/.mega-sdd/vaults/app"
bash "$RT" --unit "$VG/units/U-001.md" --write >/dev/null 2>&1
# a SECOND unit with a bolt commit and no bolt-report = an orphan that is NOT in
# flight, so the run gate denies U-001's dispatch for a reason that is not the cap
printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: src/z.js\n    operation: create\n---\n# U-002\n\n## Acceptance\n' > "$VG/units/U-002.md"
( cd "$G" && echo x > src/z.js && git add src/z.js .mega-sdd && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-002): bolt

Unit: U-002" )
OUT=$(drive "$(agent_payload "$G" U-001)")
if printf '%s' "$OUT" | grep -q '"deny"'; then
  [ ! -f "$VG/bolts/U-001/attempts.json" ] && ok "B1 denied by another gate ($(printf '%s' "$OUT" | grep -o 'bolt-orphans' | head -1)) → no attempts.json written" || bad "B1 a denied dispatch was counted: $(cat "$VG/bolts/U-001/attempts.json")"
else bad "B1 fixture did not provoke another gate: [$(printf '%s' "$OUT" | head -c 200)]"; fi

echo "── C: migration guarantee ──"
C="$WORK/c"; mkproj "$C"; VC="$C/.mega-sdd/vaults/app"
OUT=$(drive "$(agent_payload "$C" U-001)")
[ -z "$OUT" ] && [ ! -f "$VC/bolts/U-001/attempts.json" ] && ok "C1 no review-tier.json → silent allow, nothing written" || bad "C1 out=[$(printf '%s' "$OUT" | head -c 160)]"
mkdir -p "$VC/bolts/U-001"; printf '{"tier":"standard","unit_id":"U-001","written_by":"resolve-review-tier.sh"}' > "$VC/bolts/U-001/review-tier.json"
for i in 1 2 3 4 5 6; do OUT=$(drive "$(agent_payload "$C" U-001)"); done
printf '%s' "$OUT" | grep -q 'attempt-cap\|spent its implementer budget' && bad "C2 a review-tier.json WITHOUT retry_budget was capped (retro-block)" || ok "C2 older review-tier.json (no retry_budget) is never capped"
[ ! -f "$VC/bolts/U-001/attempts.json" ] && ok "C3 …and never counted" || bad "C3 attempts.json written without a budget"

echo "── D: anti-self-bypass ──"
bash_payload() { printf '{"session_id":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$SID" "$F" "$1"; }
write_payload() { printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"{}"}}' "$SID" "$F" "$1"; }
OUT=$(drive "$(bash_payload "echo '{}' > .mega-sdd/vaults/app/bolts/U-001/attempts.json")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "D1 a Bash redirect onto attempts.json is denied" || bad "D1 Bash write not denied: [$(printf '%s' "$OUT" | head -c 200)]"
OUT=$(drive "$(bash_payload "rm -f .mega-sdd/vaults/app/bolts/U-001/attempts.json")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "D2 a Bash rm of attempts.json is denied (the reset is the human's)" || bad "D2 rm not denied: [$(printf '%s' "$OUT" | head -c 200)]"
OUT=$(drive "$(write_payload "$V/bolts/U-001/attempts.json")")
printf '%s' "$OUT" | grep -q '"deny"' && ok "D3 a Write to attempts.json is denied" || bad "D3 Write not denied: [$(printf '%s' "$OUT" | head -c 200)]"

echo "── E: merge-panel-findings early verdict ──"
MV="$WORK/m/vault"; mkdir -p "$MV/bolts/U-001" "$WORK/m/in"
cat > "$WORK/m/in/sec.txt" <<'EOF'
FINDINGS:
critical | src/a.js:3 | secret in code | hard-coded token
EOF
printf '{"tier":"standard","retry_budget":1,"retry_budget_source":"flag"}' > "$MV/bolts/U-001/review-tier.json"
printf '{"schema":1,"unit":"U-001","dispatches":1}' > "$MV/bolts/U-001/attempts.json"
O1=$(bash "$PLUGIN/scripts/merge-panel-findings.sh" --vault="$MV" --unit=U-001 --head=abc1234 --round=1 --spec-verdict=pass --lens=security:"$WORK/m/in/sec.txt" 2>/dev/null)
printf '%s' "$O1" | grep -q '"budget_left":1' && printf '%s' "$O1" | grep -q '"gate":"re-dispatch"' && ok "E1 budget left → gate re-dispatch, budget_left 1" || bad "E1 $O1"
printf '{"schema":1,"unit":"U-001","dispatches":2}' > "$MV/bolts/U-001/attempts.json"
O2=$(bash "$PLUGIN/scripts/merge-panel-findings.sh" --vault="$MV" --unit=U-001 --head=abc1235 --round=2 --spec-verdict=pass --lens=security:"$WORK/m/in/sec.txt" 2>/dev/null)
printf '%s' "$O2" | grep -q '"budget_left":0' && printf '%s' "$O2" | grep -q '"gate":"halt"' && ok "E2 budget spent + a Critical still open → gate halt" || bad "E2 $O2"
rm -f "$MV/bolts/U-001/review-tier.json"
O3=$(bash "$PLUGIN/scripts/merge-panel-findings.sh" --vault="$MV" --unit=U-001 --head=abc1236 --round=3 --spec-verdict=pass --lens=security:"$WORK/m/in/sec.txt" 2>/dev/null)
printf '%s' "$O3" | grep -q '"budget_left":null' && printf '%s' "$O3" | grep -q '"gate":"re-dispatch"' && ok "E3 no budget record → unknown never invents a halt" || bad "E3 $O3"

[ "$fail" -eq 0 ] && echo "ALL PASS" || echo "SOME FAILED"
exit $fail
