#!/usr/bin/env bash
# test-handoff-gate-time-recompute.sh — v7 Fase 2 №2 contract (spec
# 2026-08-21-v7-weighted-routing-design.md §7.5 LANDED):
#
#   h1  content-hash dedup: re-validating IDENTICAL text is idempotent —
#       retry_count does NOT double-count (review R-4), state not rewritten.
#   h2  a CHANGED (fixed) text always re-runs fully and overwrites the state.
#   h3  gate-time recompute: a forged/stale FAIL state is OVERWRITTEN at
#       dispatch when the transcript's last assistant message carries a real
#       PASS handoff — the dispatch goes through.
#   h4  narration is not a handoff (review R-3): text containing "handoff:"
#       without a line-start emitted_by: must NOT be validated — the existing
#       FAIL state stays authoritative and the dispatch is blocked.
#   h5  the Stop leg is DEAD: hooks/stop no longer writes
#       .handoff-validation-state.json even when the transcript ends in a
#       bad handoff (gate time is the only writer).
#
# Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
V="$P/scripts/validate-handoff-yaml.sh"
PTU="$P/hooks/pre-tool-use"
STOP="$P/hooks/stop"
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "  ok: $1"; }
fail() { echo "  FAIL: $1"; rc=1; }

state_field() { # $1=state-file $2=key
  "$PY" -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]))" "$1" "$2" 2>/dev/null
}
mk_transcript() { # $1=path $2=assistant text
  "$PY" -c '
import json, sys
row = {"message": {"role": "assistant", "content": [{"type": "text", "text": sys.argv[2]}]}}
open(sys.argv[1], "w").write(json.dumps(row) + "\n")
' "$1" "$2"
}

# ── h1/h2: validator dedup ───────────────────────────────────────────────────
A="$TMP/a"; mkdir -p "$A/.mega-sdd"
ST="$A/.mega-sdd/.handoff-validation-state.json"
BAD=$'handoff:\n  emitted_by: mega-sdd:memory\n  status: completed\n'
printf '%s' "$BAD" | bash "$V" --cwd="$A" --skill-name="mega-sdd:memory" --quiet >/dev/null 2>&1
R1_RETRY=$(state_field "$ST" retry_count); R1_SHA=$(state_field "$ST" content_sha256)
printf '%s' "$BAD" | bash "$V" --cwd="$A" --skill-name="mega-sdd:memory" --quiet >/dev/null 2>&1
R2_RC=$?
R2_RETRY=$(state_field "$ST" retry_count)
[ "$R1_RETRY" = "1" ] && [ "$R2_RETRY" = "1" ] && [ "$R2_RC" -eq 1 ] && [ -n "$R1_SHA" ] \
  && pass "h1 identical text re-validated: retry_count stays 1 (no double-count), exit still FAIL" \
  || fail "h1 dedup broken: retry r1=$R1_RETRY r2=$R2_RETRY rc=$R2_RC sha=[$R1_SHA]"

GOOD=$'handoff:\n  emitted_by: mega-sdd:memory\n  emitted_at: 2026-08-22T00:00:00Z\n  status: completed\n  next_action:\n    suggested_skill: none\n    hint: "ok"\n'
printf '%s' "$GOOD" | bash "$V" --cwd="$A" --skill-name="mega-sdd:memory" --quiet >/dev/null 2>&1
R3_RC=$?
R3_STATUS=$(state_field "$ST" status); R3_SHA=$(state_field "$ST" content_sha256)
[ "$R3_RC" -eq 0 ] && [ "$R3_STATUS" = "PASS" ] && [ "$R3_SHA" != "$R1_SHA" ] \
  && pass "h2 changed (fixed) text re-runs fully: state overwritten to PASS, new hash" \
  || fail "h2 changed text did not re-run: rc=$R3_RC status=$R3_STATUS"

# ── h3: forged FAIL state overwritten by gate-time recompute ─────────────────
B="$TMP/b"; mkdir -p "$B/.mega-sdd"
SID="gt-sess"
printf '{"session_id": "%s", "chain_engaged": true, "engaged_sessions": {"%s": true}, "entries": {}}' "$SID" "$SID" \
  > "$B/.mega-sdd/.gateguard-state.json"
printf '{"status": "FAIL", "skill_name": "mega-sdd:other", "halt_type": "invalid_handoff", "retry_count": 1, "details": {"reason": "forged"}}' \
  > "$B/.mega-sdd/.handoff-validation-state.json"
T="$TMP/t-good.jsonl"
mk_transcript "$T" $'Selesai.\n\nhandoff:\n  emitted_by: mega-sdd:memory\n  emitted_at: 2026-08-22T00:00:00Z\n  status: completed\n  next_action:\n    suggested_skill: none\n    hint: "ok"\n'
OUT=$(printf '{"session_id":"%s","cwd":"%s","transcript_path":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:memory","args":""}}' "$SID" "$B" "$T" \
  | bash "$PTU" 2>/dev/null)
B_STATUS=$(state_field "$B/.mega-sdd/.handoff-validation-state.json" status)
if ! printf '%s' "$OUT" | grep -q "blocked by handoff validation" && [ "$B_STATUS" = "PASS" ]; then
  pass "h3 stale/forged FAIL state overwritten at dispatch (recompute from real handoff) — no block"
else
  fail "h3 gate-time recompute missing: status=$B_STATUS out=[${OUT:0:150}]"
fi

# ── h4: narration with 'handoff:' but no envelope must NOT overwrite FAIL ────
C="$TMP/c"; mkdir -p "$C/.mega-sdd"
printf '{"session_id": "%s", "chain_engaged": true, "engaged_sessions": {"%s": true}, "entries": {}}' "$SID" "$SID" \
  > "$C/.mega-sdd/.gateguard-state.json"
printf '%s' "$BAD" | bash "$V" --cwd="$C" --skill-name="mega-sdd:memory" --quiet >/dev/null 2>&1
T2="$TMP/t-narration.jsonl"
mk_transcript "$T2" "Gue lagi jelasin apa itu blok handoff: intinya kontrak antar skill."
OUT=$(printf '{"session_id":"%s","cwd":"%s","transcript_path":"%s","tool_name":"Skill","tool_input":{"skill":"mega-sdd:generate-intent","args":""}}' "$SID" "$C" "$T2" \
  | bash "$PTU" 2>/dev/null)
C_STATUS=$(state_field "$C/.mega-sdd/.handoff-validation-state.json" status)
if printf '%s' "$OUT" | grep -q "blocked by handoff validation" && [ "$C_STATUS" = "FAIL" ]; then
  pass "h4 narration not validated (R-3): FAIL state authoritative, dispatch blocked"
else
  fail "h4 narration bulldozed the state: status=$C_STATUS out=[${OUT:0:150}]"
fi

# ── h5: the Stop leg is dead ─────────────────────────────────────────────────
D="$TMP/d"; mkdir -p "$D/.mega-sdd/memory"
T3="$TMP/t-bad.jsonl"
mk_transcript "$T3" "$BAD"
( cd "$D" && printf '{"session_id":"s","cwd":"%s","transcript_path":"%s","stop_hook_active":false}' "$D" "$T3" \
  | bash "$STOP" >/dev/null 2>&1 )
[ ! -f "$D/.mega-sdd/.handoff-validation-state.json" ] \
  && pass "h5 Stop no longer writes the handoff state (leg removed; gate time is the only writer)" \
  || fail "h5 Stop still validates handoffs"

echo
if [ "$rc" -eq 0 ]; then echo "PASS handoff gate-time recompute contract"; else echo "FAIL handoff gate-time recompute contract"; fi
exit $rc
