#!/usr/bin/env bash
# test-token-cost-report.sh — Batch 1 (token), lever S4: cost-weighted reporting.
#
# Pins report-token-cost.sh: it rolls up telemetry.jsonl turn_end_marker /
# subagent_end_marker usage into a COST-WEIGHTED total (input x1, cache_read x0.1,
# output x5, cache_creation x1.25 @5m TTL / x2.00 @1h TTL — Opus price ratios),
# attributes cost per skill, and reports the raw/cost overstatement ratio. This is
# the fix for the field audit's headline: 176M RAW tokens were ~37M cost-equivalent
# because 91.9% were cache_read. Report-only — writes TOKEN-COST-REPORT.md +
# .token-cost-state.json, touches no gate. CI-safe: bash + python3 only.
#
# Case 3 pins the v5.13.0 TTL correction: cache_creation has TWO prices and the
# transcript states which applied. Where the hooks carried the split through, it is
# priced EXACTLY; where they did not (pre-v5.13.0 telemetry, Cases 1-2), it falls
# back to the per-lane default and the report must SAY it is assumed.
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

# Hand-computed expectations. This fixture carries NO TTL split (it is pre-v5.13.0
# telemetry), so cache_creation takes the LANE fallback: main x2.00, subagent x1.25.
#   scan turn  : 1000*1 + 2000*2.00 + 100000*0.1 + 500*5  = 17500 (raw 103500)
#   bind turn  :  500*1 +    0      +  50000*0.1 + 200*5  =  6500 (raw  50700)
#   bolts subag:    0   +    0      +      0     +1000*5  =  5000 (raw   1000)
#   TOTAL cost = 29000 | TOTAL raw = 155200 | ratio = 155200/29000 = 5.35 | turns = 3
bash "$REPORT" --cwd="$ROOT" --quiet >/dev/null 2>&1
STATE="$ROOT/.mega-sdd/.token-cost-state.json"
[ -f "$STATE" ] || { fail "state file .token-cost-state.json not written"; }

if [ -f "$STATE" ]; then
  CW="$(_field "$STATE" "['cost_weighted_total']")"
  RAW="$(_field "$STATE" "['raw_total']")"
  TURNS="$(_field "$STATE" "['turns']")"
  RATIO="$(_field "$STATE" "['overstatement_ratio']")"
  echo "  (cost_weighted=$CW raw=$RAW turns=$TURNS ratio=$RATIO)"
  [ "$CW" = "29000" ]  && pass "cost-weighted total = 29000" || fail "cost-weighted total = $CW (want 29000)"
  [ "$RAW" = "155200" ] && pass "raw total = 155200" || fail "raw total = $RAW (want 155200)"
  [ "$TURNS" = "3" ]   && pass "turns = 3 (incl. subagent marker)" || fail "turns = $TURNS (want 3)"
  # subagent_turns pins the fork-measurement integrity signal: exactly the count of
  # subagent_end_markers (here 1). (The fork-measurement comparator that read this was removed in v7;
  # 0 ⇒ SubagentStop never fired ⇒ fork cost uncapturable ⇒ verdict refused.
  SUBT="$(_field "$STATE" "['subagent_turns']")"
  [ "$SUBT" = "1" ]    && pass "subagent_turns = 1 (one subagent_end_marker)" || fail "subagent_turns = $SUBT (want 1)"
  [ "$RATIO" = "5.35" ] && pass "overstatement ratio = 5.35x" || fail "ratio = $RATIO (want 5.35)"

  # The lane fallback must be VISIBLE as an assumption, never worn as a measurement.
  PCTM="$(_field "$STATE" "['cache_creation_ttl']['pct_measured']")"
  ASSUMED="$(_field "$STATE" "['cache_creation_ttl']['assumed']")"
  [ "$PCTM" = "0.0" ]     && pass "pct_measured = 0 for pre-v5.13.0 telemetry" || fail "pct_measured = $PCTM (want 0.0)"
  [ "$ASSUMED" = "2000" ] && pass "all 2000 cache_creation tokens marked assumed" || fail "assumed = $ASSUMED (want 2000)"

  # Per-skill attribution: find each skill's cost in by_skill.
  SCAN_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:scan-codebase'),'MISSING'))" "$STATE")"
  BIND_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:bind-codebase'),'MISSING'))" "$STATE")"
  BOLT_C="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((s['cost_weighted'] for s in d['by_skill'] if s['skill']=='mega-sdd:execute-bolts'),'MISSING'))" "$STATE")"
  [ "$SCAN_C" = "17500" ] && pass "scan-codebase cost-weighted = 17500" || fail "scan cost = $SCAN_C (want 17500)"
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

# ── Case 3: TTL split present → cache_creation priced EXACTLY, not assumed ────
# This is the v5.13.0 correction. The hooks carry usage.cache_creation.ephemeral_*
# through as cache_creation_{5m,1h}_input_tokens, so the report prices the real rate
# instead of guessing a TTL. Also pins per-model attribution (the Phase 1b question:
# "what tier did the bolt lane actually run at" is answered from telemetry, not a
# special run).
ROOT3="$(mktemp -d)"; mkdir -p "$ROOT3/.mega-sdd/memory"
cat > "$ROOT3/.mega-sdd/memory/telemetry.jsonl" <<'JSONL'
{"event_type":"turn_end_marker","skill":"orchestrate-flow","hook_source":"Stop","payload":{"model":"claude-opus-5","usage":{"input_tokens":0,"cache_creation_input_tokens":10000,"cache_creation_5m_input_tokens":4000,"cache_creation_1h_input_tokens":6000,"cache_read_input_tokens":0,"output_tokens":0}}}
{"event_type":"subagent_end_marker","skill":"mega-sdd:bolt-implementer","agent_type":"mega-sdd:bolt-implementer","hook_source":"SubagentStop","payload":{"model":"claude-sonnet-5","skill_name":"mega-sdd:bolt-implementer","usage":{"input_tokens":0,"cache_creation_input_tokens":1000,"cache_creation_5m_input_tokens":1000,"cache_creation_1h_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}
JSONL
# main   : 4000*1.25 + 6000*2.00 = 5000 + 12000 = 17000
# subagt : 1000*1.25                             =  1250
# TOTAL  = 18250 | raw = 11000 (split keys are a BREAKDOWN of cache_creation,
#                              never summed into raw — that would double-count)
bash "$REPORT" --cwd="$ROOT3" --quiet >/dev/null 2>&1
S3="$ROOT3/.mega-sdd/.token-cost-state.json"
if [ -f "$S3" ]; then
  CW3="$(_field "$S3" "['cost_weighted_total']")"
  RAW3="$(_field "$S3" "['raw_total']")"
  PCT3="$(_field "$S3" "['cache_creation_ttl']['pct_measured']")"
  M5="$(_field "$S3" "['cache_creation_ttl']['measured_5m']")"
  M1="$(_field "$S3" "['cache_creation_ttl']['measured_1h']")"
  [ "$CW3" = "18250" ] && pass "TTL-exact cost = 18250 (4000@1.25 + 6000@2.00 + 1000@1.25)" \
                       || fail "TTL-exact cost = $CW3 (want 18250)"
  [ "$RAW3" = "11000" ] && pass "split keys excluded from raw_total (no double-count)" \
                        || fail "raw_total = $RAW3 (want 11000 — split keys leaked into raw)"
  [ "$PCT3" = "100.0" ] && pass "pct_measured = 100 when the split is present" || fail "pct_measured = $PCT3 (want 100.0)"
  [ "$M5" = "5000" ] && pass "measured_5m = 5000 across both lanes" || fail "measured_5m = $M5 (want 5000)"
  [ "$M1" = "6000" ] && pass "measured_1h = 6000" || fail "measured_1h = $M1 (want 6000)"
  OP="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((m['cost_weighted'] for m in d['by_model'] if m['model']=='claude-opus-5'),'MISSING'))" "$S3")"
  SN="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((m['cost_weighted'] for m in d['by_model'] if m['model']=='claude-sonnet-5'),'MISSING'))" "$S3")"
  [ "$OP" = "17000" ] && pass "by_model attributes 17000 to claude-opus-5" || fail "opus cost = $OP (want 17000)"
  [ "$SN" = "1250" ]  && pass "by_model attributes 1250 to claude-sonnet-5" || fail "sonnet cost = $SN (want 1250)"
fi
REP3="$ROOT3/.mega-sdd/TOKEN-COST-REPORT.md"
grep -q "100% measured" "$REP3" 2>/dev/null && pass "report states TTL was 100% measured" \
  || fail "report does not state the TTL was measured"
grep -q "claude-opus-5" "$REP3" 2>/dev/null && pass "report renders the By model table" || fail "report missing By model table"
rm -rf "$ROOT3"

# ── Case 4: partial split → residual falls back to the lane, and is LABELLED ──
# Guards the silent-drop failure mode: a split that does not account for the whole
# cache_creation total must charge the remainder, not discard or over-credit it.
ROOT4="$(mktemp -d)"; mkdir -p "$ROOT4/.mega-sdd/memory"
cat > "$ROOT4/.mega-sdd/memory/telemetry.jsonl" <<'JSONL'
{"event_type":"turn_end_marker","skill":"orchestrate-flow","hook_source":"Stop","payload":{"usage":{"input_tokens":0,"cache_creation_input_tokens":1000,"cache_creation_5m_input_tokens":200,"cache_creation_1h_input_tokens":300,"cache_read_input_tokens":0,"output_tokens":0}}}
JSONL
# 200*1.25 + 300*2.00 + residual 500*2.00 (main lane) = 250 + 600 + 1000 = 1850
bash "$REPORT" --cwd="$ROOT4" --quiet >/dev/null 2>&1
S4="$ROOT4/.mega-sdd/.token-cost-state.json"
if [ -f "$S4" ]; then
  CW4="$(_field "$S4" "['cost_weighted_total']")"
  AS4="$(_field "$S4" "['cache_creation_ttl']['assumed']")"
  PCT4="$(_field "$S4" "['cache_creation_ttl']['pct_measured']")"
  [ "$CW4" = "1850" ] && pass "residual charged at the lane rate (cost = 1850)" || fail "cost = $CW4 (want 1850)"
  [ "$AS4" = "500" ]  && pass "residual 500 recorded as assumed" || fail "assumed = $AS4 (want 500)"
  [ "$PCT4" = "50.0" ] && pass "pct_measured = 50 on a partial split" || fail "pct_measured = $PCT4 (want 50.0)"
fi
grep -q "lane-assumed" "$ROOT4/.mega-sdd/TOKEN-COST-REPORT.md" 2>/dev/null \
  && pass "report flags the mixed measured/assumed state" || fail "report does not flag the mixed state"
rm -rf "$ROOT4"

# ── Case 5: --price-table → billed cost from raw types, unpriced NEVER invented ──
# v7.1 routing gate: the flip decision needs gateway-price-weighted cost. The billed
# section prices ONLY what the table covers; a model or token type missing from the
# table lands in unpriced_tokens and the report says the total is a lower bound.
ROOT5="$(mktemp -d)"; mkdir -p "$ROOT5/.mega-sdd/memory"
cat > "$ROOT5/.mega-sdd/memory/telemetry.jsonl" <<'JSONL'
{"event_type":"subagent_end_marker","skill":"mega-sdd:bolt-implementer","agent_type":"mega-sdd:bolt-implementer","hook_source":"SubagentStop","payload":{"model":"claude-sonnet-5","skill_name":"mega-sdd:bolt-implementer","usage":{"input_tokens":1000000,"cache_creation_input_tokens":2000000,"cache_creation_5m_input_tokens":2000000,"cache_creation_1h_input_tokens":0,"cache_read_input_tokens":10000000,"output_tokens":100000}}}
{"event_type":"subagent_end_marker","skill":"mega-sdd:bolt-implementer","agent_type":"mega-sdd:bolt-implementer","hook_source":"SubagentStop","payload":{"model":"claude-haiku-4-5","skill_name":"mega-sdd:bolt-implementer","usage":{"input_tokens":500000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":200000}}}
JSONL
cat > "$ROOT5/prices.yaml" <<'YAML'
# office gateway price list (per MTok)
currency: USD
claude-sonnet-5:
  input: 3.0
  output: 15.0
  cache_read: 0.3
  cache_creation_5m: 3.75
YAML
# sonnet: 1M*3/1M + 2M*3.75/1M + 10M*0.3/1M + 0.1M*15/1M = 3 + 7.5 + 3 + 1.5 = 15.0
#         (no cache_creation_1h/unknown tokens; all types priced -> unpriced 0)
# haiku : NOT in the table -> billed 0, ALL 700000 raw tokens unpriced
bash "$REPORT" --cwd="$ROOT5" --price-table="$ROOT5/prices.yaml" --quiet >/dev/null 2>&1
S5="$ROOT5/.mega-sdd/.token-cost-state.json"
if [ -f "$S5" ]; then
  BT="$(_field "$S5" "['billed']['total']")"
  BC="$(_field "$S5" "['billed']['currency']")"
  UP="$(_field "$S5" "['billed']['unpriced_tokens_total']")"
  SONB="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((b['billed'] for b in d['billed']['by_model'] if b['model']=='claude-sonnet-5'),'MISSING'))" "$S5")"
  HAIB="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));b=next((b for b in d['billed']['by_model'] if b['model']=='claude-haiku-4-5'),None);print('%s/%s'%(b['billed'],b['unpriced_tokens']) if b else 'MISSING')" "$S5")"
  [ "$BT" = "15.0" ]  && pass "billed total = 15.0 (hand-computed from price table)" || fail "billed total = $BT (want 15.0)"
  [ "$BC" = "USD" ]   && pass "currency label read from the table" || fail "currency = $BC (want USD)"
  [ "$SONB" = "15.0" ] && pass "sonnet billed = 15.0" || fail "sonnet billed = $SONB (want 15.0)"
  [ "$HAIB" = "0.0/700000" ] && pass "un-tabled model billed 0 with ALL tokens unpriced (never invented)" \
                             || fail "haiku billed/unpriced = $HAIB (want 0.0/700000)"
  [ "$UP" = "700000" ] && pass "unpriced_tokens_total = 700000" || fail "unpriced total = $UP (want 700000)"
fi
grep -q "LOWER BOUND" "$ROOT5/.mega-sdd/TOKEN-COST-REPORT.md" 2>/dev/null \
  && pass "report flags the billed total as a lower bound when tokens are unpriced" \
  || fail "report does not flag unpriced tokens as a lower bound"
# unreadable table -> section says so, exit stays 0, nothing estimated
bash "$REPORT" --cwd="$ROOT5" --price-table="$ROOT5/nope.yaml" --quiet >/dev/null 2>&1
RC5=$?
ST5="$(_field "$S5" "['billed']['status']")"
[ "$RC5" = "0" ] && [ "$ST5" = "price_table_unreadable" ] \
  && pass "unreadable price table -> status recorded, exit 0, no estimate" \
  || fail "unreadable table: rc=$RC5 status=$ST5 (want 0 / price_table_unreadable)"
rm -rf "$ROOT5"

# ── Case 6: --vault → per-bolt model_used table from bolt-reports (v7.1 audit) ──
ROOT6="$(mktemp -d)"; mkdir -p "$ROOT6/.mega-sdd/memory" "$ROOT6/vault/bolts/U-001" "$ROOT6/vault/bolts/U-002"
cat > "$ROOT6/.mega-sdd/memory/telemetry.jsonl" <<'JSONL'
{"event_type":"turn_end_marker","skill":"orchestrate-flow","hook_source":"Stop","payload":{"usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10}}}
JSONL
cat > "$ROOT6/vault/bolts/U-001/bolt-report.md" <<'MD'
---
unit: U-001
status: success
---
# Bolt Report — U-001
bolt_self_report:
  model_used: "Claude Haiku 4.5"
  confidence: 0.9
MD
cat > "$ROOT6/vault/bolts/U-002/bolt-report.md" <<'MD'
---
unit: U-002
status: success
---
# Bolt Report — U-002
bolt_self_report:
  model_used: "Sonnet 5"
  escalated_from: "haiku"
  confidence: 0.8
MD
bash "$REPORT" --cwd="$ROOT6" --vault="$ROOT6/vault" --quiet >/dev/null 2>&1
S6="$ROOT6/.mega-sdd/.token-cost-state.json"
if [ -f "$S6" ]; then
  B1M="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((b['model_used'] for b in d['by_bolt'] if b['unit']=='U-001'),'MISSING'))" "$S6")"
  B2E="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(next((b['escalated_from'] for b in d['by_bolt'] if b['unit']=='U-002'),'MISSING'))" "$S6")"
  [ "$B1M" = "Claude Haiku 4.5" ] && pass "by_bolt U-001 model_used read verbatim" || fail "U-001 model_used = '$B1M'"
  [ "$B2E" = "haiku" ] && pass "by_bolt U-002 escalated_from recorded (cascade hop)" || fail "U-002 escalated_from = '$B2E'"
fi
grep -q "By bolt (model_used" "$ROOT6/.mega-sdd/TOKEN-COST-REPORT.md" 2>/dev/null \
  && pass "report renders the By bolt table" || fail "report missing the By bolt table"
# no flags -> no new sections, no by_bolt/billed keys (backward compat)
bash "$REPORT" --cwd="$ROOT6" --quiet >/dev/null 2>&1
NOB="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print('billed' in d or 'by_bolt' in d)" "$S6")"
[ "$NOB" = "False" ] && pass "without flags, state carries neither billed nor by_bolt (compat)" \
                     || fail "flagless run leaked billed/by_bolt keys"
rm -rf "$ROOT6"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-token-cost-report)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
