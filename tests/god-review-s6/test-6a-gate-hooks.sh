#!/usr/bin/env bash
# test-6a-gate-hooks.sh — god-review stage 6, Batch 6A: gate/hook truth.
# Pins against the REAL hooks:
#   EB-GATE-1  the six bolt-stage states are re-derived at the execute-bolts gate —
#              a forged PASS is overwritten with current truth before the read.
#   B1 recompute  the postflight-evidence gate no longer trusts the recorded
#              postflight.json status: --recompute re-executes each committed
#              Hard-rule bolt from git/fs ground truth and OVERWRITES the artifact
#              before the state is derived. Here U-001's Hard rule GENUINELY FAILS
#              on recompute (a file it must produce is absent), so a forged
#              postflight PASS is overwritten to a real FAIL — the gate blocks on
#              ground truth, not on the (forgeable) recorded verdict.
#   EB-GATE-4  the B1/B2 evidence artifacts are Write/Edit-denied + Bash-tamper-guarded.
#   EB-GATE-5  python open-for-write / dd of= / install(1) on a protected state are
#              denied; python READ of the same state stays allowed.
#   EB-GATE-6  a state-litter .mega-sdd/ under a sub-dir never shadows the true root:
#              the gate DENIES from the sub-cwd too.
#   B3 state   .bolt-whitelist-state.json is rm-protected like its siblings.
# Run: bash tests/god-review-s6/test-6a-gate-hooks.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
VBA="${ROOT}/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
for f in "$PRE" "$VBA"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t gate6a)"
trap 'rm -rf "$WORK"' EXIT

drive() { # $1=fixture-cwd $2=tool_name $3=tool_input-json
  HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s6test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
'
}

mk_fixture() { # $1=dir — git project with one doc-format Hard-rule bolt commit (B1 obligation)
  local d="$1"
  # U-001's Hard rule REQUIRES src/needed.php to exist after the bolt, but the bolt
  # commit only creates app.php — so the rule GENUINELY FAILS on recompute (FILE_PRESENCE
  # missing). target_files lists only app.php and the bolt touches only app.php, so there
  # is no B3 whitelist violation to muddy the B1 assertion. A forged postflight PASS is
  # therefore overwritten to a real FAIL by --recompute at the gate.
  mkdir -p "$d/.mega-sdd/vaults/app/units" "$d/.mega-sdd/vaults/app/bolts"
  ( cd "$d" && git init -q . \
    && printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: app.php\n    operation: create\n---\n## Hard rules\n- file src/needed.php MUST exist after bolt\n' > .mega-sdd/vaults/app/units/U-001.md \
    && echo "code" > app.php \
    && git add -A \
    && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): implement thing" )
}

echo "── EB-GATE-1/5 + B1 recompute: forged PASS is overwritten by ground truth at gate time ──"
F1="$WORK/f1"; mk_fixture "$F1"
# hand-place forged PASS states (simulating a vector the Bash guard missed). The B1
# postflight state is forged PASS AND a forged postflight.json PASS artifact is planted —
# --recompute must re-execute U-001's Hard rule (FILE_PRESENCE src/needed.php, which is
# absent) and overwrite BOTH the artifact and the state to a genuine FAIL.
for st in .bolt-postflight-state.json .bolt-orphans-state.json .batch-suite-gate-state.json; do
  python3 -c "import json; json.dump({'status':'PASS','issues':[],'issues_count':0}, open('$F1/.mega-sdd/$st','w'))"
done
mkdir -p "$F1/.mega-sdd/vaults/app/bolts/U-001"
python3 -c "import json; json.dump({'unit_id':'U-001','status':'pass','head_sha':'x','written_by':'forged','rules':[{'type':'file_presence','verdict':'pass'}]}, open('$F1/.mega-sdd/vaults/app/bolts/U-001/postflight.json','w'))"
OUT=$(drive "$F1" "Skill" '{"skill":"mega-sdd:execute-bolts"}')
if printf '%s' "$OUT" | grep -q '"deny"' && printf '%s' "$OUT" | grep -q "postflight-evidence"; then
  ok "gate recomputes B1 from ground truth: forged postflight PASS overwritten, execute-bolts DENIED (B1 among the fails)"
else
  fail "forged PASS opened the gate (or B1 missing): $(printf '%s' "$OUT" | head -c 300)"
fi
if python3 -c "import json,sys; d=json.load(open('$F1/.mega-sdd/.bolt-postflight-state.json')); sys.exit(0 if d['status']=='FAIL' else 1)"; then
  ok "forged B1 state now records current truth (FAIL)"
else
  fail "B1 state still forged PASS after gate"
fi
# and the on-disk evidence artifact itself was overwritten from the forged PASS to a real fail
if python3 -c "import json,sys; d=json.load(open('$F1/.mega-sdd/vaults/app/bolts/U-001/postflight.json')); sys.exit(0 if d['status']=='fail' and d['written_by']!='forged' else 1)"; then
  ok "forged postflight.json artifact overwritten by the sanctioned recompute (status:fail)"
else
  fail "forged postflight.json artifact survived the gate recompute"
fi

echo "── EB-GATE-4: evidence artifacts guarded (Write + Bash) ──"
OUT=$(drive "$F1" "Write" "{\"file_path\":\"$F1/.mega-sdd/vaults/app/bolts/_batch-suite.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && ok "Write of _batch-suite.json denied" || fail "Write of _batch-suite.json allowed"
OUT=$(drive "$F1" "Write" "{\"file_path\":\"$F1/.mega-sdd/vaults/app/bolts/U-001/postflight.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && ok "Write of postflight.json denied" || fail "Write of postflight.json allowed"
OUT=$(drive "$F1" "Bash" "{\"command\":\"echo '{\\\"status\\\":\\\"green\\\"}' > .mega-sdd/vaults/app/bolts/_batch-suite.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "Bash redirect into _batch-suite.json denied" || fail "Bash redirect into _batch-suite.json allowed"
# the sanctioned writer invocation must NOT be blocked
OUT=$(drive "$F1" "Bash" "{\"command\":\"bash ${ROOT}/plugins/mega-sdd/scripts/run-full-suite.sh --cwd=$F1 --runner=true --quiet\"}")
[ -z "$OUT" ] && ok "run-full-suite.sh invocation passes the guard" || fail "sanctioned writer blocked: $(printf '%s' "$OUT" | head -c 200)"

echo "── EB-GATE-5: new Bash write verbs ──"
OUT=$(drive "$F1" "Bash" "{\"command\":\"python3 -c 'import json; json.dump({\\\"status\\\":\\\"PASS\\\"}, open(\\\".mega-sdd/.bolt-postflight-state.json\\\",\\\"w\\\"))'\"}")
printf '%s' "$OUT" | grep -q "open-for-write" && ok "python open-for-write denied" || fail "python open-for-write allowed"
OUT=$(drive "$F1" "Bash" "{\"command\":\"dd if=/dev/null of=.mega-sdd/.unit-spec-state.json\"}")
printf '%s' "$OUT" | grep -q "dd of=" && ok "dd of= denied" || fail "dd of= allowed"
OUT=$(drive "$F1" "Bash" "{\"command\":\"install /tmp/x .mega-sdd/.factory-ledger-state.json\"}")
printf '%s' "$OUT" | grep -q "install(1)" && ok "install(1) denied" || fail "install(1) allowed"
OUT=$(drive "$F1" "Bash" "{\"command\":\"python3 -c 'import json; print(json.load(open(\\\".mega-sdd/.bolt-postflight-state.json\\\")))'\"}")
[ -z "$OUT" ] && ok "python READ of protected state allowed" || fail "python read denied: $(printf '%s' "$OUT" | head -c 200)"
OUT=$(drive "$F1" "Bash" "{\"command\":\"rm .mega-sdd/.bolt-whitelist-state.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "rm of .bolt-whitelist-state.json denied" || fail "rm of whitelist state allowed"

echo "── EB-GATE-6: litter root never shadows the true root ──"
F2="$WORK/f2"; mk_fixture "$F2"
mkdir -p "$F2/sub/.mega-sdd"   # pure state litter — NOT substantive
python3 -c "import json; json.dump({'status':'PASS'}, open('$F2/sub/.mega-sdd/.analyze-state.json','w'))"
OUT=$(drive "$F2/sub" "Skill" '{"skill":"mega-sdd:execute-bolts"}')
if printf '%s' "$OUT" | grep -q '"deny"'; then
  ok "gate from sub-cwd resolves to the TRUE root and DENIES (B1 FAIL visible)"
else
  fail "litter root forked gate truth — execute-bolts allowed from sub-cwd"
fi
# a SUBSTANTIVE nested project keeps its own root (fixture-in-repo safety):
# any deny must come from ITS OWN gates (here: predictive preflight — no units),
# never from the parent's B1 postflight FAIL.
F3="$WORK/f3"; mk_fixture "$F3"
mkdir -p "$F3/nested-proj/.mega-sdd/vaults/x/units"
( cd "$F3/nested-proj" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "init" )
OUT=$(drive "$F3/nested-proj" "Skill" '{"skill":"mega-sdd:execute-bolts"}')
if printf '%s' "$OUT" | grep -q "postflight-evidence"; then
  fail "substantive nested project inherited the parent's B1 FAIL (root escape)"
elif printf '%s' "$OUT" | grep -q "$F3/nested-proj/.mega-sdd"; then
  ok "substantive nested project keeps its own root (own-gate state paths)"
elif [ -z "$OUT" ]; then
  ok "substantive nested project keeps its own (clean) root"
else
  fail "unexpected deny for nested project: $(printf '%s' "$OUT" | head -c 200)"
fi

echo
[ "$FAILED" -eq 0 ] && { echo "test-6a-gate-hooks: ALL PASS"; exit 0; } || { echo "test-6a-gate-hooks: FAILURES"; exit 1; }
