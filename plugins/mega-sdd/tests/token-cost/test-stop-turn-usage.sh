#!/usr/bin/env bash
# test-stop-turn-usage.sh — v5.13.0: hooks/stop emits the WHOLE turn's usage.
#
# Pins the main-lane instrument. Before v5.13.0 the Stop hook recorded only the LAST
# assistant message's usage, which under-reported the turn ~11.6x aggregate (measured
# over 10 real session transcripts / 547 turns; median 9.5x, range 2.8-18.3x). It now
# sums every assistant message the turn appended.
#
# The contract has four parts, all pinned here:
#   1. WINDOW  — the main transcript is append-only for the whole session and this hook
#      fires every turn, so it must sum only what was appended SINCE the last firing.
#      Summing the file each time would re-emit the cumulative total every turn.
#   2. DEDUP   — the harness writes one JSONL record per content block, all sharing one
#      message.id and repeating the same usage. Count each message once. A message with
#      NO id has no identity to dedup on and must be counted individually.
#   3. ISOLATE — the cursor is per-session, so two concurrent sessions cannot ping-pong
#      one offset between two different transcripts (that would re-emit cumulative).
#   4. SIDECHAIN — subagent turns are billed by SubagentStop against their own nested
#      transcript; counting them here too would double-count the bolt/panel lane.
#
# Observe-only: the hook must exit 0 throughout. CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/stop"

[ -f "$HOOK" ] || { echo "FAIL: hooks/stop not found at $HOOK"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.mega-sdd/memory"
TEL="$ROOT/.mega-sdd/memory/telemetry.jsonl"
: > "$TEL"   # gate: telemetry.jsonl must pre-exist

TR="$ROOT/transcript.jsonl"

# Fire the hook for a given session id, return the last turn_end_marker payload.
_fire() {
  python3 -c "
import json,sys
print(json.dumps({'session_id':sys.argv[1],'cwd':sys.argv[2],'transcript_path':sys.argv[3],
                  'hook_event_name':'Stop','stop_hook_active':False}))" "$1" "$ROOT" "$TR" \
  | bash "$HOOK" >/dev/null 2>&1
  return 0
}
_last() { grep turn_end_marker "$TEL" 2>/dev/null | tail -1; }
_usage() {
  printf '%s' "$1" | python3 -c '
import json,sys
try: print(json.dumps(json.loads(sys.stdin.read())["payload"].get("usage",{}),sort_keys=True))
except Exception: print("{}")'
}
_field() {
  printf '%s' "$1" | python3 -c '
import json,sys
try: print(json.loads(sys.stdin.read())["payload"].get(sys.argv[1],"MISSING"))
except Exception: print("ERR")' "$2"
}

# ── Case 1: one turn, 2 messages, each written as 3 blocks sharing a message.id ─
# Blind summing would report 3x. Last-message-only would report m2 alone.
#   m1: in 10, cc 100, cr 1000, out 50   (cc split: 40 @5m + 60 @1h)
#   m2: in  5, cc 200, cr 2000, out 80   (cc split:  0 @5m + 200 @1h)
#   turn total: in 15, cc 300, cr 3000, out 130 | 5m 40 | 1h 260
cat > "$TR" <<'JSONL'
{"type":"user","message":{"role":"user","content":"go"}}
{"type":"assistant","isSidechain":false,"message":{"id":"m1","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50,"cache_creation":{"ephemeral_5m_input_tokens":40,"ephemeral_1h_input_tokens":60}}}}
{"type":"assistant","isSidechain":false,"message":{"id":"m1","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50,"cache_creation":{"ephemeral_5m_input_tokens":40,"ephemeral_1h_input_tokens":60}}}}
{"type":"assistant","isSidechain":false,"message":{"id":"m1","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50,"cache_creation":{"ephemeral_5m_input_tokens":40,"ephemeral_1h_input_tokens":60}}}}
{"type":"assistant","isSidechain":false,"message":{"id":"m2","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":5,"cache_creation_input_tokens":200,"cache_read_input_tokens":2000,"output_tokens":80,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":200}}}}
{"type":"assistant","isSidechain":false,"message":{"id":"m2","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":5,"cache_creation_input_tokens":200,"cache_read_input_tokens":2000,"output_tokens":80,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":200}}}}
JSONL

_fire "sess-A"
EV1="$(_last)"
[ -n "$EV1" ] && pass "turn_end_marker emitted" || fail "no turn_end_marker emitted"
U1="$(_usage "$EV1")"
EXP1='{"cache_creation_1h_input_tokens": 260, "cache_creation_5m_input_tokens": 40, "cache_creation_input_tokens": 300, "cache_read_input_tokens": 3000, "input_tokens": 15, "output_tokens": 130}'
[ "$U1" = "$EXP1" ] && pass "turn SUMMED across messages and DEDUPED by message.id" \
                    || fail "usage = $U1 (want $EXP1)"
[ "$(_field "$EV1" messages)" = "2" ] && pass "messages = 2 (6 records, 2 distinct ids)" \
                                      || fail "messages = $(_field "$EV1" messages) (want 2)"
[ "$(_field "$EV1" model)" = "claude-opus-5" ] && pass "model captured (unblocks per-tier attribution)" \
                                               || fail "model = $(_field "$EV1" model)"

# ── Case 2: next turn appends m3 → emit ONLY m3, never the cumulative total ────
cat >> "$TR" <<'JSONL'
{"type":"user","message":{"role":"user","content":"more"}}
{"type":"assistant","isSidechain":false,"message":{"id":"m3","role":"assistant","model":"claude-opus-5","usage":{"input_tokens":1,"cache_creation_input_tokens":7,"cache_read_input_tokens":9,"output_tokens":3,"cache_creation":{"ephemeral_5m_input_tokens":7,"ephemeral_1h_input_tokens":0}}}}
JSONL
_fire "sess-A"
U2="$(_usage "$(_last)")"
EXP2='{"cache_creation_1h_input_tokens": 0, "cache_creation_5m_input_tokens": 7, "cache_creation_input_tokens": 7, "cache_read_input_tokens": 9, "input_tokens": 1, "output_tokens": 3}'
[ "$U2" = "$EXP2" ] && pass "second firing emits ONLY the new window (no O(N^2) re-emit)" \
                    || fail "window leaked prior turns: $U2 (want $EXP2)"

# ── Case 3: no new messages → emits empty usage, not a repeat of the last turn ─
_fire "sess-A"
U3="$(_usage "$(_last)")"
[ "$U3" = "{}" ] && pass "idle firing emits {} (a double Stop cannot re-bill a turn)" \
                 || fail "idle firing re-emitted usage: $U3"

# ── Case 4: sidechain records are SubagentStop's lane — must not be counted here ─
cat >> "$TR" <<'JSONL'
{"type":"assistant","isSidechain":true,"message":{"id":"sub1","role":"assistant","usage":{"input_tokens":999,"cache_creation_input_tokens":999,"cache_read_input_tokens":999,"output_tokens":999}}}
{"type":"assistant","isSidechain":false,"message":{"id":"m4","role":"assistant","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":4}}}
JSONL
_fire "sess-A"
U4="$(_usage "$(_last)")"
case "$U4" in
  *999*) fail "sidechain usage double-counted into the main lane: $U4" ;;
  *) pass "sidechain records skipped (no double-count vs SubagentStop)" ;;
esac
[ "$(_field "$(_last)" messages)" = "1" ] && pass "only the main-lane message counted" \
                                          || fail "messages = $(_field "$(_last)" messages) (want 1)"

# ── Case 5: a SECOND concurrent session must not inherit session A's cursor ────
# A shared cursor would see a path/offset mismatch, reset, and re-sum the WHOLE
# transcript — emitting the cumulative total. Per-session cursors make that impossible.
TR_B="$ROOT/transcript-b.jsonl"
cat > "$TR_B" <<'JSONL'
{"type":"assistant","isSidechain":false,"message":{"id":"b1","role":"assistant","usage":{"input_tokens":6,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":6}}}
JSONL
python3 -c "
import json,sys
print(json.dumps({'session_id':'sess-B','cwd':sys.argv[1],'transcript_path':sys.argv[2],
                  'hook_event_name':'Stop','stop_hook_active':False}))" "$ROOT" "$TR_B" \
  | bash "$HOOK" >/dev/null 2>&1
UB="$(_usage "$(_last)")"
case "$UB" in
  *'"input_tokens": 6'*) pass "session B billed independently (per-session cursor)" ;;
  *) fail "session B usage wrong: $UB" ;;
esac
# ...and session A's cursor survived B's firing — A stays at EOF, emits {}.
_fire "sess-A"
[ "$(_usage "$(_last)")" = "{}" ] && pass "session A cursor unharmed by session B (no ping-pong)" \
                                  || fail "session A re-emitted after B fired: $(_usage "$(_last)")"

# ── Case 6: truncated/rewritten transcript → skip to EOF, never re-count from 0 ─
# For an instrument, one under-reported turn beats one fabricated spike.
printf '%s\n' '{"type":"assistant","isSidechain":false,"message":{"id":"z1","role":"assistant","usage":{"input_tokens":1,"output_tokens":1}}}' > "$TR"
_fire "sess-A"
UZ="$(_usage "$(_last)")"
[ "$UZ" = "{}" ] && pass "truncation resets to EOF (no fabricated spike)" \
                 || fail "truncation re-counted the file: $UZ"

# ── Case 7: id-less messages are counted individually (cannot dedup without id) ─
cat >> "$TR" <<'JSONL'
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","usage":{"input_tokens":3,"output_tokens":3}}}
{"type":"assistant","isSidechain":false,"message":{"role":"assistant","usage":{"input_tokens":3,"output_tokens":3}}}
JSONL
_fire "sess-A"
EVN="$(_last)"
[ "$(_field "$EVN" messages)" = "2" ] && pass "two id-less messages counted as 2, not collapsed" \
                                      || fail "id-less messages collapsed: messages=$(_field "$EVN" messages)"
case "$(_usage "$EVN")" in
  *'"input_tokens": 6'*) pass "id-less messages summed (6 = 3+3)" ;;
  *) fail "id-less sum wrong: $(_usage "$EVN")" ;;
esac

# ── Case 8: observe-only — the hook never blocks, even with a garbage transcript ─
printf 'not json at all\n' > "$TR"
python3 -c "
import json,sys
print(json.dumps({'session_id':'sess-C','cwd':sys.argv[1],'transcript_path':sys.argv[2],
                  'hook_event_name':'Stop','stop_hook_active':False}))" "$ROOT" "$TR" \
  | bash "$HOOK" >/dev/null 2>&1
RC=$?
[ "$RC" = "0" ] && pass "malformed transcript still exits 0 (never blocks a turn)" || fail "exit = $RC (want 0)"

echo
if [ "$fails" -eq 0 ]; then echo "ALL PASS (test-stop-turn-usage)"; exit 0
else echo "FAILED: $fails assertion(s)"; exit 1; fi
