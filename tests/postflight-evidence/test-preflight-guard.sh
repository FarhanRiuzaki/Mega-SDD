#!/usr/bin/env bash
# W4 (spec 2026-07-19-w-batch-script-derive.md): the B1 pre-flight BASELINE
# preflight.json is hook-guarded like postflight.json. scan_unit gives a present
# sha/signature snapshot PRECEDENCE over commit evidence, so a forged baseline
# laundered a DO_NOT_MODIFY/SIGNATURE violation past B1 — the write guard is the
# load-bearing closure (with the writer's own post-hoc refusal).
# Drives the REAL PreToolUse hook (test-6a drive() harness):
#   - Write/Edit of <vault>/bolts/U-XXX/preflight.json -> denied
#   - Bash redirect / rm / python open-for-write targeting it -> denied
#   - the sanctioned writer invocation (run-preflight-scan.sh) -> NOT blocked
#   - regression: postflight.json Write still denied; a NON-vault
#     bolts/.../preflight.json is NOT Write-denied (S6 EB-VAL-7 anchor kept)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
[ -f "$PRE" ] || { echo "missing $PRE"; exit 1; }

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t pfguard)"
trap 'rm -rf "$WORK"' EXIT

drive() { # $1=fixture-cwd $2=tool_name $3=tool_input-json
  HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "w4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
' </dev/null
}

# fixture: a real git project with a vault + one Hard-rule unit (NOT plugin-dev,
# NOT under a tests/examples/fixtures path — mktemp lives outside the repo)
F="$WORK/f1"
mkdir -p "$F/.mega-sdd/vaults/app/units" "$F/.mega-sdd/vaults/app/bolts/U-001"
( cd "$F" && git init -q . \
  && printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n  - path: app.php\n    operation: create\n---\n## Hard rules\n- DO NOT modify app.php\n' > .mega-sdd/vaults/app/units/U-001.md \
  && echo "code" > app.php \
  && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m "seed" )

echo "── W4: preflight.json Write/Edit guard ──"
# NB: the reason TEXT alone is not a block — the decision field carries the
# deny; assert BOTH so a deny→ask downgrade can never stay green (the reason
# string survives any decision downgrade).
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/preflight.json\",\"content\":\"{}\"}")
if printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -qi "preflight" \
   && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"'; then
  ok "Write of preflight.json denied (decision=deny; evidence-artifact reason names preflight)"
else
  fail "Write of preflight.json allowed or not a hard deny: $(printf '%s' "$OUT" | head -c 300)"
fi
OUT=$(drive "$F" "Edit" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/preflight.json\",\"old_string\":\"a\",\"new_string\":\"b\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Edit of preflight.json denied (decision=deny)" || fail "Edit of preflight.json allowed or not a hard deny"

echo "── W4: Bash tamper verbs ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"echo '{}' > .mega-sdd/vaults/app/bolts/U-001/preflight.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "Bash redirect into preflight.json denied" || fail "Bash redirect into preflight.json allowed"
OUT=$(drive "$F" "Bash" "{\"command\":\"rm .mega-sdd/vaults/app/bolts/U-001/preflight.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "rm of preflight.json denied" || fail "rm of preflight.json allowed"
# F-06 (spec 2026-08-30 §1.2): the field recovery path renamed the baseline AWAY
# (`mv preflight.json preflight.stale.json`) and sailed through because the old
# regex only matched the protected name in the DESTINATION argument.
OUT=$(drive "$F" "Bash" "{\"command\":\"mv .mega-sdd/vaults/app/bolts/U-001/preflight.json .mega-sdd/vaults/app/bolts/U-001/preflight.stale.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "mv of preflight.json to a non-protected name denied (source position)" \
  || fail "mv preflight.json -> preflight.stale.json ALLOWED — the field recovery path still removes a baseline"
OUT=$(drive "$F" "Bash" "{\"command\":\"cp .mega-sdd/vaults/app/bolts/U-001/preflight.json /tmp/pf-backup.json\"}")
[ -z "$OUT" ] && ok "cp of preflight.json OUT (a read) still allowed" || fail "cp preflight.json out false-blocked: $(printf '%s' "$OUT" | head -c 160)"
OUT=$(drive "$F" "Bash" "{\"command\":\"python3 -c 'import json; json.dump({\\\"rules\\\":[]}, open(\\\".mega-sdd/vaults/app/bolts/U-001/preflight.json\\\",\\\"w\\\"))'\"}")
printf '%s' "$OUT" | grep -q "open-for-write" && ok "python open-for-write targeting preflight.json denied" || fail "python open-for-write allowed"

echo "── W4: sanctioned writer passes the guard ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"bash ${ROOT}/plugins/mega-sdd/scripts/run-preflight-scan.sh --cwd=$F --unit=U-001\"}")
[ -z "$OUT" ] && ok "run-preflight-scan.sh invocation NOT blocked" || fail "sanctioned writer blocked: $(printf '%s' "$OUT" | head -c 200)"

echo "── regressions ──"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/postflight.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Write of postflight.json still denied (decision=deny)" || fail "postflight regression: Write allowed or not a hard deny"
mkdir -p "$F/bolts/U-1"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/bolts/U-1/preflight.json\",\"content\":\"{}\"}")
if printf '%s' "$OUT" | grep -q "evidence artifact"; then
  fail "non-vault bolts/U-1/preflight.json false-blocked (S6 EB-VAL-7 vault-prefix anchor lost)"
else
  ok "non-vault preflight.json path NOT Write-denied (vault-prefix anchor preserved)"
fi

echo
[ "$FAILED" -eq 0 ] && { echo "test-preflight-guard: ALL PASS"; exit 0; } || { echo "test-preflight-guard: FAILURES"; exit 1; }
