#!/usr/bin/env bash
# test-token-cost-report.sh — Batch 1 (token), lever S4: cost-weighted reporting.
#
# Pins report-token-cost.sh: it rolls up telemetry.jsonl turn_end_marker /
# subagent_end_marker usage into a COST-WEIGHTED total (input x1, cache_creation
# x1.25, cache_read x0.1, output x5 — Opus price ratios), attributes cost per
# skill, and reports the raw/cost overstatement ratio. This is the fix for the
# field audit's headline: 176M RAW tokens were ~37M cost-equivalent because 91.9%
# were cache_read. Report-only — writes TOKEN-COST-REPORT.md + .token-cost-state.json,
# touches no gate. CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT="$PLUGIN_ROOT/scripts/report-token-cost.sh"

[ -f "$REPORT" ] || { echo "FAIL: report-token-cost.sh not found at $REPORT"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
_field() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(eval('d'+sys.argv[2]))" "$1" "$2"; }

# ── Case 1: a realistic telemetry fixture with known usage ────────────────────
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.mega-sdd/memory"

# REALISTIC shapes (mirrors real telemetry): turn_end_marker carries a hardcoded
# emitter "skill":"orchestrate-flow"; the ACTIVE phase comes from the skill_invoked
# bracket (payload.skill_full_name). subagent_end_marker carries its OWN identity.
# The buggy attribution (reading the marker's own "skill") would lump turns 1+2 under
# orchestrate-flow — these assertions catch that.
cat > "$ROOT/.mega-sdd/memory/telemetry.jsonl" <<'JSONL'
{"event_type":"skill_invoked","skill":"orchestrate-flow","hook_source":"PostToolUse","payload":{"skill_full_name":"mega-sdd:scan-codebase"}}
{"event_type":"turn_end_marker","skill":"orchestrate-flow","hook_source":"Stop","payload":{"usage":{"input_tokens":1000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":100000,"output_tokens":500}}}
{"event_type":"skill_invoked","skill":"orchestrate-flow","hook_source":"PostToolUse","payload":{"skill_full_name":"mega-sdd:bind-codebase"}}
{"event_type":"turn_end_marker","skill":"orchestrate-flow","hook_source":"Stop","payload":{"usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":50000,"output_tokens":200}}}
{"event_type":"subagent_end_marker","skill":"mega-sdd:execute-bolts","agent_type":"mega-sdd:execute-bolts","hook_source":"SubagentStop","payload":{"skill_name":"mega-sdd:execute-bolts","agent_id":"abc123","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1000}}}
JSONL

# Hand-computed expectations:
#   scan turn  : 1000*1 + 2000*1.25 + 100000*0.1 + 500*5  = 16000 (raw 103500)
#   bind turn  :  500*1 +    0*1.25 +  50000*0.1 + 200*5  =  6500 (raw  50700)
#   bolts subag:    0   +    0      +      0      +1000*5  =  5000 (raw   1000)
#   TOTAL cost = 27500 | TOTAL raw = 155200 | ratio = 155200/27500 = 5.64 | turns = 3
bash "$REPORT" --cwd="$ROOT" --quiet >/dev/null 2>&1
STATE="$ROOT/.mega-sdd/.token-cost-state.json"
[ -f "$STATE" ] || { fail "state file .token-cost-state.json not written"; }

if [ -f "$STATE" ]; then
  CW="$(_field "$STATE" "['cost_weighted_total']")"
  RAW="$(_field "$STATE" "['raw_total']")"
  TURNS="$(_field "$STATE" "['turns']")"
  RATIO="$(_field "$STATE" "['overstatement_ratio']")"
  echo "  (cost_weighted=$CW raw=$RAW turns=$TURNS ratio=$RATIO)"
  [ "$CW" = "27500" ]  && pass "cost-weighted total = 27500" || fail "cost-weighted total = $CW (want 27500)"
  [ "$RAW" = "155200" ] && pass "raw total = 155200" || fail "raw total = $RAW (want 155200)"
  [ "$TURNS" = "3" ]   && pass "turns = 3 (incl. subagent marker)" || fail "turns = $TURNS (want 3)"
  [ "$RATIO" = "5.64" ] && pass "overstatement ratio = 5.64x" || fail "ratio = $RATIO (want 5.64)"

  # Per-skill attribution: find each skill's cost in by_skill.
  SCAN_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:scan-codebase'),'MISSING'))" "$STATE")"
  BIND_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:bind-codebase'),'MISSING'))" "$STATE")"
  BOLT_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:execute-bolts'),'MISSING'))" "$STATE")"
  [ "$SCAN_C" = "16000" ] && pass "scan-codebase cost-weighted = 16000" || fail "scan cost = $SCAN_C (want 16000)"
  [ "$BIND_C" = "6500" ]  && pass "bind-codebase cost-weighted = 6500" || fail "bind cost = $BIND_C (want 6500)"
  [ "$BOLT_C" = "5000" ]  && pass "execute-bolts (subagent) cost-weighted = 5000" || fail "bolts cost = $BOLT_C (want 5000)"

  # Regression guard: the marker's hardcoded emitter "skill":"orchestrate-flow" must
  # NOT capture turn cost — turns attribute to the skill_invoked bracket, not the emitter.
  OF_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if 'orchestrate-flow' in s['skill']),'ABSENT'))" "$STATE")"
  [ "$OF_C" = "ABSENT" ] && pass "emitter 'orchestrate-flow' is NOT mis-attributed turn cost" || fail "orchestrate-flow wrongly holds $OF_C cost (emitter-field bug)"
fi

REP="$ROOT/.mega-sdd/TOKEN-COST-REPORT.md"
[ -f "$REP" ] && pass "TOKEN-COST-REPORT.md written" || fail "TOKEN-COST-REPORT.md not written"
if [ -f "$REP" ]; then
  grep -q "Cost-weighted" "$REP" && pass "report shows Cost-weighted line" || fail "report missing Cost-weighted line"
  grep -q "execute-bolts" "$REP" && pass "report attributes the subagent skill" || fail "report missing per-skill attribution"
fi

# ── Case 2: no telemetry → graceful, exit 0, never blocks ─────────────────────
ROOT2="$(mktemp -d)"; mkdir -p "$ROOT2/.mega-sdd"
bash "$REPORT" --cwd="$ROOT2" --quiet >/dev/null 2>&1
RC=$?
[ "$RC" = "0" ] && pass "no-telemetry run exits 0 (report-only, never blocks)" || fail "no-telemetry exit = $RC (want 0)"
HT="$(_field "$ROOT2/.mega-sdd/.token-cost-state.json" "['have_telemetry']" 2>/dev/null || echo ERR)"
[ "$HT" = "False" ] && pass "have_telemetry=false recorded" || fail "have_telemetry = $HT (want False)"
rm -rf "$ROOT2"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-token-cost-report)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
