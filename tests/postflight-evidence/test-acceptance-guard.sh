#!/usr/bin/env bash
# P4 (v5 spec P4 row): the B4 acceptance evidence acceptance.json is
# hook-guarded like preflight.json/postflight.json (W4 precedent). The gate
# READS the artifact (B2-style — never re-executes tests in a hook), so one
# plain Write of {status:pass} would clear a documented hard block — the write
# guard is the load-bearing closure.
# Drives the REAL PreToolUse hook (test-preflight-guard drive() harness):
#   - Write/Edit of <vault>/bolts/U-XXX/acceptance.json -> denied
#   - Bash redirect / rm / python open-for-write targeting it -> denied
#   - the sanctioned writer invocation (run-acceptance-tests.sh) -> NOT blocked
#   - regression pins: preflight.json + postflight.json + _batch-suite.json
#     Write still denied ((pre|post)flight regexes intact); a NON-vault
#     bolts/.../acceptance.json is NOT Write-denied (vault-prefix anchor kept)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
[ -f "$PRE" ] || { echo "missing $PRE"; exit 1; }

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t accguard)"
trap 'rm -rf "$WORK"' EXIT

drive() { # $1=fixture-cwd $2=tool_name $3=tool_input-json
  HOOK="$PRE" FIX="$1" TOOL="$2" TI="$3" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "b4guard"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
' </dev/null
}

# fixture: a real git project with a vault + one v5-keyed bolt (NOT plugin-dev,
# NOT under a tests/examples/fixtures path — mktemp lives outside the repo)
F="$WORK/f1"
mkdir -p "$F/.mega-sdd/vaults/app/units" "$F/.mega-sdd/vaults/app/bolts/U-001"
( cd "$F" && git init -q . \
  && printf -- '---\nid: U-001\ntask_type: create\ntarget_files:\n  - path: app.py\n    operation: create\nacceptance_test:\n  - type: test\n    command: "true"\n    expects: ""\n---\n\n## Goal\nGuard fixture.\n' > .mega-sdd/vaults/app/units/U-001.md \
  && echo "x = 1" > app.py \
  && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): bolt

Unit: U-001
SDD-Acceptance: v5" )

echo "── P4: acceptance.json Write/Edit guard ──"
# NB: assert BOTH the reason text AND the decision field (W4 lesson — a
# deny→ask downgrade must never stay green).
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/acceptance.json\",\"content\":\"{\\\"status\\\":\\\"pass\\\"}\"}")
if printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -qi "acceptance" \
   && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"'; then
  ok "Write of acceptance.json denied (decision=deny; evidence-artifact reason names acceptance)"
else
  fail "Write of acceptance.json allowed or not a hard deny: $(printf '%s' "$OUT" | head -c 300)"
fi
OUT=$(drive "$F" "Edit" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/acceptance.json\",\"old_string\":\"fail\",\"new_string\":\"pass\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Edit of acceptance.json denied (decision=deny)" || fail "Edit of acceptance.json allowed or not a hard deny"
# the deny text names the sanctioned writer
printf '%s' "$OUT" | grep -q "run-acceptance-tests.sh" \
  && ok "deny message names run-acceptance-tests.sh as the sanctioned writer" || fail "deny message does not route to the sanctioned writer"

echo "── P4: Bash tamper verbs ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"echo '{\\\"status\\\":\\\"pass\\\"}' > .mega-sdd/vaults/app/bolts/U-001/acceptance.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "Bash redirect into acceptance.json denied" || fail "Bash redirect into acceptance.json allowed"
OUT=$(drive "$F" "Bash" "{\"command\":\"rm .mega-sdd/vaults/app/bolts/U-001/acceptance.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "rm of acceptance.json denied" || fail "rm of acceptance.json allowed"
OUT=$(drive "$F" "Bash" "{\"command\":\"python3 -c 'import json; json.dump({\\\"status\\\":\\\"pass\\\"}, open(\\\".mega-sdd/vaults/app/bolts/U-001/acceptance.json\\\",\\\"w\\\"))'\"}")
printf '%s' "$OUT" | grep -q "open-for-write" && ok "python open-for-write targeting acceptance.json denied" || fail "python open-for-write allowed"
OUT=$(drive "$F" "Bash" "{\"command\":\"rm .mega-sdd/.bolt-acceptance-state.json\"}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "rm of .bolt-acceptance-state.json denied (state joins the guard)" || fail "rm of acceptance gate state allowed"

echo "── P4: sanctioned writer passes the guard ──"
OUT=$(drive "$F" "Bash" "{\"command\":\"bash ${ROOT}/plugins/mega-sdd/scripts/run-acceptance-tests.sh --cwd=$F --unit=U-001\"}")
[ -z "$OUT" ] && ok "run-acceptance-tests.sh invocation NOT blocked" || fail "sanctioned writer blocked: $(printf '%s' "$OUT" | head -c 200)"

echo "── regressions: (pre|post)flight + _batch-suite pins intact ──"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/preflight.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Write of preflight.json still denied" || fail "preflight regression: Write allowed"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/U-001/postflight.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Write of postflight.json still denied" || fail "postflight regression: Write allowed"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/.mega-sdd/vaults/app/bolts/_batch-suite.json\",\"content\":\"{}\"}")
printf '%s' "$OUT" | grep -q "evidence artifact" && printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "Write of _batch-suite.json still denied" || fail "_batch-suite regression: Write allowed"
mkdir -p "$F/bolts/U-1"
OUT=$(drive "$F" "Write" "{\"file_path\":\"$F/bolts/U-1/acceptance.json\",\"content\":\"{}\"}")
if printf '%s' "$OUT" | grep -q "evidence artifact"; then
  fail "non-vault bolts/U-1/acceptance.json false-blocked (S6 EB-VAL-7 vault-prefix anchor lost)"
else
  ok "non-vault acceptance.json path NOT Write-denied (vault-prefix anchor preserved)"
fi

echo
[ "$FAILED" -eq 0 ] && { echo "test-acceptance-guard: ALL PASS"; exit 0; } || { echo "test-acceptance-guard: FAILURES"; exit 1; }
