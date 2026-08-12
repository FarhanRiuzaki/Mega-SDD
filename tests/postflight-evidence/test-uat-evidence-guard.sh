#!/usr/bin/env bash
# P2 v6.10.0 (spec 2026-08-12-playwright-embed-design.md §D2): the UAT automated
# evidence artifact <vault>/uat/evidence/**/result.json is hook-guarded like the
# B1/B2/B4 artifacts — the §5 annex renderer READS it (recompute-at-gate), so a
# hand-written {status:{pass:N}} would launder fabricated "Pass" rows through
# the legitimate render path (the prose-asserts-closed-breach class).
# Drives the REAL PreToolUse hook (test-acceptance-guard drive() harness):
#   - Write/Edit of <vault>/uat/evidence/UAT-001/<ts>/result.json -> denied
#   - Bash redirect / rm / python open-for-write targeting it -> denied
#   - the sanctioned writer invocation (uat-run.sh) -> NOT blocked
#   - a NON-vault uat/evidence/.../result.json is NOT denied (vault anchor)
#   - regression: bolts acceptance.json Write still denied
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
[ -f "$PRE" ] || { echo "missing $PRE"; exit 1; }

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t uatguard)"
trap 'rm -rf "$WORK"' EXIT

drive() { # $1=fixture-cwd $2=tool_name $3=tool_input-json
  HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "uatguard"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
' </dev/null
}

# fixture: real git project with a vault — mktemp lives OUTSIDE the repo
# (plugin-dev-mode exemption), and the evidence layout carries NO
# tests/examples/fixtures segment (run dirs are UTC timestamps by contract).
F="$WORK/f1"
EV="$F/.mega-sdd/vaults/app/uat/evidence/UAT-001/20260812T100000Z"
mkdir -p "$EV"
( cd "$F" && git init -q . && echo x > x.txt && git add x.txt \
  && git -c user.email=t@t -c user.name=t commit -q -m init )

RJ="$EV/result.json"

echo "── result.json Write/Edit guard (deny text + decision, W4 lesson) ──"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$RJ\",\"content\":\"{\\\"status\\\":{\\\"pass\\\":9}}\"}")
if printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"'; then
  ok "Write of result.json denied (reason + decision)"
else fail "Write not denied: $OUT"; fi

OUT=$(drive "$F" "Edit" "{\"file_path\":\"$RJ\",\"old_string\":\"a\",\"new_string\":\"b\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Edit of result.json denied" || fail "Edit not denied: $OUT"

printf '%s' "$OUT" | grep -q "uat-run.sh" \
  && ok "deny message names the sanctioned writer uat-run.sh" || fail "writer not named: $OUT"

echo "── Bash-lane tamper verbs ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"echo '{}' > $RJ\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Bash redirect into result.json denied" || fail "redirect not denied: $OUT"

OUT=$(drive "$F" "Bash" "{\"command\":\"rm -f $RJ\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "rm of result.json denied" || fail "rm not denied: $OUT"

OUT=$(drive "$F" "Bash" "{\"command\":\"python3 -c \\\"open('$RJ','w').write('{}')\\\"\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "python open-for-write denied" || fail "python write not denied: $OUT"

echo "── sanctioned writer + precision negatives ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"bash /x/plugins/mega-sdd/scripts/uat-run.sh --vault=$F/.mega-sdd/vaults/app --cwd=$F --url=http://localhost:3000\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && fail "sanctioned uat-run.sh invocation wrongly blocked: $OUT" || ok "uat-run.sh invocation NOT blocked (never names the artifact)"

# NON-vault evidence path (a user project's own uat/evidence) must NOT be denied
NV="$F/myapp/uat/evidence/UAT-001/20260812T100000Z/result.json"
mkdir -p "$(dirname "$NV")"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$NV\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && fail "non-vault result.json wrongly denied (anchor lost)" || ok "non-vault uat/evidence Write NOT denied (vault anchor holds)"

echo "── cross-artifact regression ──"
mkdir -p "$F/.mega-sdd/vaults/app/bolts/U-001"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/acceptance.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "bolts acceptance.json still denied" || fail "acceptance.json regression: $OUT"

echo
if [ "$FAILED" -eq 0 ]; then echo "PASS: uat evidence guard suite"; exit 0; else echo "FAIL: uat evidence guard suite"; exit 1; fi
