#!/usr/bin/env bash
# test-subagent-stop-telemetry.sh — Batch 1 (token), lever S3: subagent telemetry capture.
#
# Pins hooks/subagent-stop: on SubagentStop it reads the subagent's OWN transcript
# (agent_transcript_path), SUMS message.usage across ALL the subagent's turns, and emits
# a subagent_end_marker into telemetry.jsonl attributed to the agent_type. This closes the
# field-audit blind spot (SubagentStop never fires Stop -> the bolt phase emitted zero
# telemetry). Observe-only (exit 0, never blocks). Gated on telemetry.jsonl already
# existing (consistent with the turn_end_marker gate). CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/subagent-stop"

[ -f "$HOOK" ] || { echo "FAIL: hooks/subagent-stop not found at $HOOK"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.mega-sdd/memory"

# A subagent transcript with TWO turns carrying usage (sum != last-only).
#   turn1: in 10, cc 100, cr 1000, out 50
#   turn2: in  5, cc   0, cr 2000, out 80
#   SUM  : in 15, cc 100, cr 3000, out 130   (last-only would wrongly be turn2)
TRANSCRIPT="$ROOT/.mega-sdd/memory/fake-subagent.jsonl"
cat > "$TRANSCRIPT" <<'JSONL'
{"message":{"role":"assistant","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50}}}
{"message":{"role":"user","content":"go on"}}
{"message":{"role":"assistant","usage":{"input_tokens":5,"cache_creation_input_tokens":0,"cache_read_input_tokens":2000,"output_tokens":80}}}
JSONL

_stdin() {
  python3 - "$ROOT" "$TRANSCRIPT" <<'PY'
import json,sys
print(json.dumps({
  "session_id":"s1","cwd":sys.argv[1],"agent_id":"a1",
  "agent_type":"mega-sdd:bolt-implementer","agent_transcript_path":sys.argv[2],
  "hook_event_name":"SubagentStop"
}))
PY
}

# ── Case 1: telemetry.jsonl exists → emit a summed subagent_end_marker ─────────
: > "$ROOT/.mega-sdd/memory/telemetry.jsonl"   # gate: file must pre-exist
_stdin | bash "$HOOK"; RC=$?
[ "$RC" = "0" ] && pass "hook exits 0 (observe-only, never blocks)" || fail "exit = $RC (want 0)"

TEL="$ROOT/.mega-sdd/memory/telemetry.jsonl"
EV="$(grep subagent_end_marker "$TEL" 2>/dev/null | tail -1)"
[ -n "$EV" ] && pass "subagent_end_marker emitted" || fail "no subagent_end_marker in telemetry.jsonl"

if [ -n "$EV" ]; then
  echo "  ($EV)" | head -1
  CHK="$(printf '%s' "$EV" | python3 -c '
import json,sys
e=json.loads(sys.stdin.read()); u=e["payload"]["usage"]
exp={"input_tokens":15,"cache_creation_input_tokens":100,"cache_read_input_tokens":3000,"output_tokens":130}
print("USAGE_OK" if u==exp else f"USAGE_BAD:{u}")
print("SKILL_OK" if e["payload"]["skill_name"]=="mega-sdd:bolt-implementer" else "SKILL_BAD")
print("SRC_OK" if e.get("hook_source")=="SubagentStop" else "SRC_BAD")
')"
  echo "$CHK" | grep -q USAGE_OK && pass "usage SUMMED across turns (15/100/3000/130, not last-only)" || fail "usage wrong: $(echo "$CHK"|grep USAGE)"
  echo "$CHK" | grep -q SKILL_OK && pass "attributed to agent_type (mega-sdd:bolt-implementer)" || fail "skill_name wrong"
  echo "$CHK" | grep -q SRC_OK && pass "hook_source=SubagentStop" || fail "hook_source wrong"
fi

# Diagnostic line written regardless (proves the hook fired).
grep -q '"hook":"subagent-stop"' "$ROOT/.mega-sdd/memory/hook-debug.log" 2>/dev/null \
  && pass "hook-debug.log records the SubagentStop invocation" || fail "no hook-debug.log entry"

# Integration: report-token-cost.sh cost-weights the new marker.
#   cost = 15*1 + 100*1.25 + 3000*0.1 + 130*5 = 15 + 125 + 300 + 650 = 1090
bash "$PLUGIN_ROOT/scripts/report-token-cost.sh" --cwd="$ROOT" --quiet >/dev/null 2>&1
BOLT="$(python3 -c "import json;d=json.load(open('$ROOT/.mega-sdd/.token-cost-state.json'));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:bolt-implementer'),'MISSING'))" 2>/dev/null)"
[ "$BOLT" = "1090" ] && pass "report-token-cost cost-weights the subagent marker (1090)" || fail "bolt cost-weighted = $BOLT (want 1090)"

# ── Case 2: NO telemetry.jsonl → gated, no emit, still exits 0 + debug line ───
ROOT2="$(mktemp -d)"; mkdir -p "$ROOT2/.mega-sdd/memory"
T2="$ROOT2/.mega-sdd/memory/fake.jsonl"
printf '{"message":{"role":"assistant","usage":{"input_tokens":9,"output_tokens":9}}}\n' > "$T2"
python3 -c "import json;print(json.dumps({'session_id':'s','cwd':'$ROOT2','agent_id':'a','agent_type':'x','agent_transcript_path':'$T2'}))" | bash "$HOOK"; RC2=$?
[ "$RC2" = "0" ] && pass "no-telemetry: exits 0" || fail "no-telemetry exit = $RC2"
[ ! -f "$ROOT2/.mega-sdd/memory/telemetry.jsonl" ] && pass "no-telemetry: does NOT bootstrap telemetry.jsonl (gate honored)" || fail "telemetry.jsonl created despite gate"
grep -q '"hook":"subagent-stop"' "$ROOT2/.mega-sdd/memory/hook-debug.log" 2>/dev/null \
  && pass "no-telemetry: diagnostic still recorded" || fail "no debug line in gated case"
rm -rf "$ROOT2"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-subagent-stop-telemetry)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
