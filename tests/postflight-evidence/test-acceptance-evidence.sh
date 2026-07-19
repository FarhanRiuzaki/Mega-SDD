#!/usr/bin/env bash
# test-acceptance-evidence.sh — B4 (P4 v4.96.0): the acceptance-evidence writer
# + the commit-keyed gate. Drives the REAL scripts:
#   writer matrix — pass / fail+retry-once (decision 9) / expects-substring /
#     pending_manual / timeout / L0 syntax rung (no retry);
#   artifact schema pins — written_by / executed_at / 40-hex head_sha /
#     entries[]{type,command,expects,rc,retried,pass,output_head<=500B} /
#     status enum;
#   commit-keying (the migration guarantee) — a LEGACY bolt (no SDD-Acceptance
#     trailer) NEVER blocks (advisory only); a v5-keyed bolt blocks on
#     absent (acceptance_evidence_missing), red (acceptance_red), broken syntax
#     (build_broken), and stale evidence (a newer bolt commit uncovers it).
# Run: bash tests/postflight-evidence/test-acceptance-evidence.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCR="$ROOT/plugins/mega-sdd/scripts"
RAT="$SCR/run-acceptance-tests.sh"
VBA="$SCR/validate-bolt-artifacts.sh"
for f in "$RAT" "$VBA"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t accev)"
trap 'rm -rf "$WORK"' EXIT

mk_project() { # $1=dir $2=acceptance_yaml_lines $3=commit-trailer-block ("" = legacy)
  local d="$1"
  mkdir -p "$d/.mega-sdd/vaults/app/units"
  ( cd "$d" && git init -q . )
  {
    printf -- '---\nid: U-001\ntask_type: create\ntarget_files:\n  - path: app.py\n    operation: create\n'
    printf 'acceptance_test:\n%b' "$2"
    printf -- '---\n\n## Goal\nB4 fixture.\n'
  } > "$d/.mega-sdd/vaults/app/units/U-001.md"
  printf 'x = 1\n' > "$d/app.py"
  ( cd "$d" && git add -A \
    && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): bolt${3:+

$3}" )
}
AJ() { echo "$1/.mega-sdd/vaults/app/bolts/U-001/acceptance.json"; }
jget() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(eval('d'+sys.argv[2]))" "$1" "$2"; }

echo "── writer: pass (expects substring present) + schema pins ──"
P1="$WORK/p1"; mk_project "$P1" '  - type: test\n    command: "echo hello-world"\n    expects: "hello"\n  - type: manual\n    desc: "operator checks dashboard"\n' "Unit: U-001
SDD-Acceptance: v5"
OUT=$(bash "$RAT" --cwd="$P1" --unit=U-001 </dev/null 2>&1); RC=$?
[ $RC -eq 0 ] && [ -f "$(AJ "$P1")" ] && ok "writer exit 0 + artifact written" || fail "writer rc=$RC: $OUT"
echo "$OUT" | grep -q "acceptance U-001: pass" && ok "quiet-gates one-line pass output" || fail "pass output not one-line: $OUT"
python3 - "$(AJ "$P1")" <<'PY' && ok "artifact schema pins hold (keys, 40-hex sha, status enum, entry shapes)" || fail "artifact schema pins broken"
import json, re, sys
d = json.load(open(sys.argv[1]))
assert d["written_by"] == "run-acceptance-tests.sh"
assert d["unit_id"] == "U-001" and d["executed_at"]
assert re.fullmatch(r"[0-9a-f]{40}", d["head_sha"])
assert d["status"] in ("pass", "fail", "pending_manual_only") and d["status"] == "pass"
ex = [e for e in d["entries"] if "pass" in e]
pm = [e for e in d["entries"] if e.get("pending_manual")]
assert ex and pm, (ex, pm)
for e in ex:
    assert set(("type", "command", "expects", "rc", "retried", "pass", "output_head")) <= set(e)
    assert len(e["output_head"].encode()) <= 500
# L0 syntax rung ran over the bolt's changed .py file (python3 always present here)
assert any(e["type"] == "syntax" and e["pass"] for e in ex)
# pending_manual entries are recorded, never executed (no rc/pass keys)
assert all("rc" not in e and "pass" not in e for e in pm)
PY

echo "── writer: fail + exactly ONE bounded auto-retry (decision 9) ──"
P2="$WORK/p2"; mk_project "$P2" '  - type: test\n    command: "false"\n    expects: ""\n' "Unit: U-001
SDD-Acceptance: v5"
OUT=$(bash "$RAT" --cwd="$P2" --unit=U-001 </dev/null 2>&1); RC=$?
[ $RC -eq 1 ] && ok "writer exit 1 on failing entry" || fail "expected exit 1, rc=$RC"
python3 - "$(AJ "$P2")" <<'PY' && ok "failing test entry: retried=true, pass=false, status=fail" || fail "retry-once not recorded"
import json, sys
d = json.load(open(sys.argv[1]))
e = [x for x in d["entries"] if x.get("type") == "test"][0]
assert d["status"] == "fail" and e["retried"] is True and e["pass"] is False and e["rc"] != 0
PY

echo "── writer: expects-substring is load-bearing (rc 0 but substring absent = fail) ──"
P3="$WORK/p3"; mk_project "$P3" '  - type: test\n    command: "echo actual-output"\n    expects: "never-printed"\n' "Unit: U-001
SDD-Acceptance: v5"
OUT=$(bash "$RAT" --cwd="$P3" --unit=U-001 </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
e=[x for x in d['entries'] if x.get('type')=='test'][0]
assert e['rc']==0 and e['pass'] is False and e['retried'] is True" "$(AJ "$P3")"; then
  ok "exit-0 command with absent expects substring records FAIL (after the one retry)"
else fail "expects-substring not enforced rc=$RC"; fi

echo "── writer: pending_manual only (no executable entry) ──"
P4="$WORK/p4"
mkdir -p "$P4/.mega-sdd/vaults/app/units"
( cd "$P4" && git init -q . )
printf -- '---\nid: U-001\ntask_type: create\ntarget_files:\n  - path: notes.txt\n    operation: create\nacceptance_test:\n  - type: manual\n    desc: "human-only check"\n---\n\n## Goal\nManual only.\n' > "$P4/.mega-sdd/vaults/app/units/U-001.md"
echo note > "$P4/notes.txt"
( cd "$P4" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): manual bolt

Unit: U-001
SDD-Acceptance: v5" )
OUT=$(bash "$RAT" --cwd="$P4" --unit=U-001 </dev/null 2>&1); RC=$?
if [ $RC -eq 0 ] && [ "$(jget "$(AJ "$P4")" "['status']")" = "pending_manual_only" ]; then
  ok "manual-only unit: status pending_manual_only, exit 0 (never executed, never fails)"
else fail "pending_manual_only lane broken rc=$RC: $OUT"; fi

echo "── writer: bounded timeout recorded as failure ──"
P5="$WORK/p5"; mk_project "$P5" '  - type: test\n    command: "sleep 5"\n    expects: ""\n' "Unit: U-001
SDD-Acceptance: v5"
OUT=$(bash "$RAT" --cwd="$P5" --unit=U-001 --timeout=1 </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
e=[x for x in d['entries'] if x.get('type')=='test'][0]
assert e['rc']==124 and 'TIMEOUT' in e['output_head'] and e['retried'] is True" "$(AJ "$P5")"; then
  ok "timeout → rc 124 + TIMEOUT evidence + the one bounded retry, exit 1"
else fail "timeout lane broken rc=$RC: $OUT"; fi

echo "── writer: L0 syntax rung — broken .py fails with NO retry ──"
P6="$WORK/p6"
mkdir -p "$P6/.mega-sdd/vaults/app/units"
( cd "$P6" && git init -q . )
printf -- '---\nid: U-001\ntask_type: create\ntarget_files:\n  - path: bad.py\n    operation: create\nacceptance_test:\n  - type: manual\n    desc: "manual"\n---\n\n## Goal\nBroken syntax.\n' > "$P6/.mega-sdd/vaults/app/units/U-001.md"
printf 'def broken(:\n' > "$P6/bad.py"
( cd "$P6" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m "feat(U-001): broken bolt

Unit: U-001
SDD-Acceptance: v5" )
OUT=$(bash "$RAT" --cwd="$P6" --unit=U-001 </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
e=[x for x in d['entries'] if x.get('type')=='syntax'][0]
assert d['status']=='fail' and e['pass'] is False and e['retried'] is False" "$(AJ "$P6")"; then
  ok "syntax failure recorded with retried=false (deterministic — no retry)"
else fail "syntax rung broken rc=$RC: $OUT"; fi

echo "── commit-keying: legacy bolt (no trailer) NEVER blocks ──"
L1="$WORK/l1"; mk_project "$L1" '  - type: test\n    command: "false"\n    expects: ""\n' ""
OUT=$(bash "$VBA" --cwd="$L1" --acceptance-scan </dev/null 2>&1); RC=$?
if [ $RC -eq 0 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
assert d['status']=='PASS' and d['v5_keyed_units']==0 and d['legacy_advisory']==['U-001']" "$L1/.mega-sdd/.bolt-acceptance-state.json"; then
  ok "legacy bolt with NO acceptance.json: state PASS, advisory-only (never retro-blocked)"
else fail "legacy bolt blocked (migration guarantee broken) rc=$RC: $OUT"; fi

echo "── commit-keying: v5-keyed bolt blocks on ABSENT evidence ──"
V1="$WORK/v1"; mk_project "$V1" '  - type: test\n    command: "true"\n    expects: ""\n' "Unit: U-001
SDD-Acceptance: v5"
OUT=$(bash "$VBA" --cwd="$V1" --acceptance-scan </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
assert d['status']=='FAIL' and [i['halt_type'] for i in d['issues']]==['acceptance_evidence_missing']" "$V1/.mega-sdd/.bolt-acceptance-state.json"; then
  ok "v5-keyed bolt, absent acceptance.json → FAIL acceptance_evidence_missing"
else fail "v5 absent-evidence lane broken rc=$RC: $OUT"; fi
# ... and the REAL PreToolUse gate names it in the deny
PRE="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
OUT=$(HOOK="$PRE" FIX="$V1" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": "Skill",
           "tool_input": {"skill": "mega-sdd:execute-bolts"}, "session_id": "b4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
' </dev/null)
if printf '%s' "$OUT" | grep -q '"deny"' && printf '%s' "$OUT" | grep -q "acceptance_evidence_missing"; then
  ok "REAL gate: execute-bolts denied naming acceptance_evidence_missing"
else fail "gate did not deny on v5 missing evidence: $(printf '%s' "$OUT" | head -c 200)"; fi

echo "── commit-keying: v5-keyed bolt blocks on RED evidence ──"
bash "$RAT" --cwd="$P2" --unit=U-001 </dev/null >/dev/null 2>&1 || true  # red artifact already recorded
OUT=$(bash "$VBA" --cwd="$P2" --acceptance-scan </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
assert [i['halt_type'] for i in d['issues']]==['acceptance_red']" "$P2/.mega-sdd/.bolt-acceptance-state.json"; then
  ok "v5-keyed bolt, red artifact → FAIL acceptance_red"
else fail "acceptance_red lane broken rc=$RC: $OUT"; fi

echo "── commit-keying: syntax-only failure maps to build_broken ──"
OUT=$(bash "$VBA" --cwd="$P6" --acceptance-scan </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
assert [i['halt_type'] for i in d['issues']]==['build_broken']" "$P6/.mega-sdd/.bolt-acceptance-state.json"; then
  ok "all-failing-entries-are-syntax → FAIL build_broken (not acceptance_red)"
else fail "build_broken split broken rc=$RC: $OUT"; fi

echo "── freshness: a NEWER v5 bolt commit uncovers old evidence (B2 covers() mirror) ──"
V2="$WORK/v2"; mk_project "$V2" '  - type: test\n    command: "true"\n    expects: ""\n' "Unit: U-001
SDD-Acceptance: v5"
bash "$RAT" --cwd="$V2" --unit=U-001 </dev/null >/dev/null 2>&1
bash "$VBA" --cwd="$V2" --acceptance-scan --quiet </dev/null && ok "fresh evidence passes the scan" || fail "fresh evidence rejected"
( cd "$V2" && echo "y = 2" >> app.py && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m "fix(U-001): follow-up bolt

Unit: U-001
SDD-Acceptance: v5" )
OUT=$(bash "$VBA" --cwd="$V2" --acceptance-scan </dev/null 2>&1); RC=$?
if [ $RC -eq 1 ] && python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
i=d['issues'][0]; assert i['halt_type']=='acceptance_evidence_missing' and 'STALE' in i['detail']" "$V2/.mega-sdd/.bolt-acceptance-state.json"; then
  ok "stale evidence (newer bolt commit not covered) → acceptance_evidence_missing STALE"
else fail "staleness anchor broken rc=$RC: $OUT"; fi

echo
[ "$FAILED" -eq 0 ] && { echo "test-acceptance-evidence: ALL PASS"; exit 0; } || { echo "test-acceptance-evidence: FAILURES"; exit 1; }
