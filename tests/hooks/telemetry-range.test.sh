#!/usr/bin/env bash
# telemetry-range.test.sh — pins spec 2026-08-17-token-lard-cuts-p1 D1+D2:
#   D1: ref_loaded records the ACTUAL Read range (read_offset/read_limit) and a
#       proportional est_read_tokens, while estimated_tokens keeps meaning
#       full-file (additive schema — consumers unbroken).
#   D2: session-start rotates telemetry.jsonl past 20k rows (one generation).
# Run </dev/null.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
PTU="$ROOT/plugins/mega-sdd/hooks/post-tool-use"
SS="$ROOT/plugins/mega-sdd/hooks/session-start"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { echo "PASS ($1)"; }
fail() { echo "FAIL ($1)"; rc=1; }
PY="${MEGA_SDD_TEST_PY:-python3}"
command -v "$PY" >/dev/null 2>&1 || { echo "SKIP (no python3)"; exit 0; }

# Fixture project with a mega-sdd-shaped ref file (matches is_megasdd_path globs).
P="$TMP/proj"
REF_DIR="$P/plugins/mega-sdd/skills/fixture-skill/references"
mkdir -p "$P/.mega-sdd/memory" "$REF_DIR"
# v7: arm the chain (spec 2026-08-21 §3.1) — the fan-out below is chain-scoped;
# this test pins VALIDATOR/telemetry behavior, so the fixture session is armed.
printf '{"session_id": "s", "chain_engaged": true, "entries": {}}' > "$P/.mega-sdd/.gateguard-state.json"
# 100 lines × 40 bytes ≈ 4000 bytes → estimated_tokens = 1000 exactly.
"$PY" -c "
with open('$REF_DIR/big-ref.md','w') as f:
    for i in range(100):
        f.write(('L%03d' % i).ljust(39) + '\n')
"
REF="$REF_DIR/big-ref.md"
TEL="$P/.mega-sdd/memory/telemetry.jsonl"

mk_read() { # $1=tool_input json
  "$PY" -c 'import json,sys; print(json.dumps({"session_id":"s","cwd":sys.argv[2],"tool_name":"Read","tool_input":json.loads(sys.argv[1])}))' "$1" "$P"
}
last_row() { tail -1 "$TEL" 2>/dev/null; }
run_ptu() { printf '%s' "$1" | bash "$PTU" >/dev/null 2>&1; }

echo "── a1: Read with offset+limit → range fields + proportional estimate ──"
: > "$TEL"
run_ptu "$(mk_read "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1], "offset": 10, "limit": 25}))' "$REF")")"
last_row | "$PY" -c '
import json,sys
d=json.loads(sys.stdin.read())
p=d["payload"]
assert d["event_type"]=="ref_loaded", d
assert p["read_offset"]==10 and p["read_limit"]==25, p
assert p["estimated_tokens"]==1000, p              # full-file meaning unchanged
assert p["est_read_tokens"]==250, p                # 1000 * 25/100
' 2>/dev/null && pass "a1 range fields + est_read_tokens=250 of 1000" || fail "a1 wrong row: $(last_row)"

echo "── a2: Read without range → null range, est == full ──"
: > "$TEL"
run_ptu "$(mk_read "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1]}))' "$REF")")"
last_row | "$PY" -c '
import json,sys
p=json.loads(sys.stdin.read())["payload"]
assert p["read_offset"] is None and p["read_limit"] is None, p
assert p["est_read_tokens"]==p["estimated_tokens"]==1000, p
' 2>/dev/null && pass "a2 full read → null range, est==full" || fail "a2 wrong row: $(last_row)"

echo "── a3: Bash cat load → null range (full-file, no shell-text parsing) ──"
: > "$TEL"
B64_PAYLOAD=$("$PY" -c 'import json,sys; print(json.dumps({"session_id":"s","cwd":sys.argv[2],"tool_name":"Bash","tool_input":{"command":"cat "+sys.argv[1]}}))' "$REF" "$P")
run_ptu "$B64_PAYLOAD"
last_row | "$PY" -c '
import json,sys
p=json.loads(sys.stdin.read())["payload"]
assert p["source_tool"]=="Bash", p
assert p["read_offset"] is None and p["read_limit"] is None, p
assert p["est_read_tokens"]==p["estimated_tokens"], p
' 2>/dev/null && pass "a3 Bash load → full, null range" || fail "a3 wrong row: $(last_row)"

echo "── a4: telemetry opt-out still writes nothing ──"
printf 'telemetry: false\n' > "$P/.mega-sdd/config.yaml"
: > "$TEL"
run_ptu "$(mk_read "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1], "limit": 5}))' "$REF")")"
[ ! -s "$TEL" ] && pass "a4 opt-out intact" || fail "a4 row written despite telemetry: false"
rm -f "$P/.mega-sdd/config.yaml"

echo "── a5: limit larger than the file clamps to full ──"
: > "$TEL"
run_ptu "$(mk_read "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1], "limit": 5000}))' "$REF")")"
last_row | "$PY" -c '
import json,sys
p=json.loads(sys.stdin.read())["payload"]
assert p["read_limit"]==5000, p
assert p["est_read_tokens"]==p["estimated_tokens"], p
' 2>/dev/null && pass "a5 oversized limit → est==full (min-clamp)" || fail "a5 wrong row: $(last_row)"

echo "── a6: absurd 21-digit limit → treated as absent (round catch) ──"
: > "$TEL"
run_ptu "$(mk_read "$("$PY" -c 'import json,sys; print(json.dumps({"file_path": sys.argv[1], "limit": 999999999999999999999}))' "$REF")")"
last_row | "$PY" -c '
import json,sys
p=json.loads(sys.stdin.read())["payload"]
assert p["read_limit"] is None, p
assert p["est_read_tokens"]==p["estimated_tokens"], p
' 2>/dev/null && pass "a6 out-of-range limit → null, est==full" || fail "a6 wrong row: $(last_row)"

echo "── r1: session-start rotates a >20k-row telemetry file ──"
R="$TMP/rot"; mkdir -p "$R/.mega-sdd/memory"
"$PY" -c "
with open('$R/.mega-sdd/memory/telemetry.jsonl','w') as f:
    for i in range(20001):
        f.write('{\"event_type\":\"x\"}\n')
"
( cd "$R" && printf '{"source":"startup","session_id":"s"}' | bash "$SS" >/dev/null 2>&1 )
# The fresh file is recreated lazily by the next append — absent-or-small both count.
FRESH_ROWS=$(wc -l < "$R/.mega-sdd/memory/telemetry.jsonl" 2>/dev/null | tr -d ' '); FRESH_ROWS=${FRESH_ROWS:-0}
if [ -f "$R/.mega-sdd/memory/telemetry.jsonl.1" ] && \
   [ "$(wc -l < "$R/.mega-sdd/memory/telemetry.jsonl.1" | tr -d ' ')" -eq 20001 ] && \
   [ "$FRESH_ROWS" -lt 100 ]; then
  pass "r1 rotated to .1, fresh file lazy-recreated"
else
  fail "r1 rotation missing: $(ls -la "$R/.mega-sdd/memory/" 2>/dev/null | tr '\n' ' ')"
fi

echo "── r2: a small file is untouched ──"
R2="$TMP/rot2"; mkdir -p "$R2/.mega-sdd/memory"
printf '{"event_type":"x"}\n{"event_type":"x"}\n' > "$R2/.mega-sdd/memory/telemetry.jsonl"
( cd "$R2" && printf '{"source":"startup","session_id":"s"}' | bash "$SS" >/dev/null 2>&1 )
if [ ! -f "$R2/.mega-sdd/memory/telemetry.jsonl.1" ] && \
   [ "$(head -2 "$R2/.mega-sdd/memory/telemetry.jsonl" | grep -c '"x"')" -eq 2 ]; then
  pass "r2 small file untouched, no .1 minted"
else
  fail "r2 small file was rotated or mutated"
fi

echo "── r3: rotation clobbers an existing .1 (single generation, no .2) ──"
"$PY" -c "
with open('$R/.mega-sdd/memory/telemetry.jsonl','w') as f:
    for i in range(20001):
        f.write('{\"event_type\":\"y\"}\n')
"
( cd "$R" && printf '{"source":"startup","session_id":"s"}' | bash "$SS" >/dev/null 2>&1 )
if [ ! -f "$R/.mega-sdd/memory/telemetry.jsonl.2" ] && \
   grep -q '"y"' "$R/.mega-sdd/memory/telemetry.jsonl.1" 2>/dev/null; then
  pass "r3 .1 replaced in place, no .2 generation"
else
  fail "r3 second rotation wrong: $(ls "$R/.mega-sdd/memory/" 2>/dev/null | tr '\n' ' ')"
fi

echo "── r4: a DIRECTORY at .1 → rotation fails open, file never buried (round catch) ──"
R4="$TMP/rot4"; mkdir -p "$R4/.mega-sdd/memory/telemetry.jsonl.1"
"$PY" -c "
with open('$R4/.mega-sdd/memory/telemetry.jsonl','w') as f:
    for i in range(20001):
        f.write('{\"event_type\":\"w\"}\n')
"
( cd "$R4" && printf '{"source":"startup","session_id":"s"}' | bash "$SS" >/dev/null 2>&1 ); ST=$?
if [ "$ST" -eq 0 ] && [ -f "$R4/.mega-sdd/memory/telemetry.jsonl" ] && \
   [ ! -e "$R4/.mega-sdd/memory/telemetry.jsonl.1/telemetry.jsonl" ]; then
  pass "r4 dir at .1 → skip rotation, nothing buried, hook exit 0"
else
  fail "r4 rotation into a directory (or hook died, rc=$ST)"
fi

echo "── z: opt-out also skips rotation (guard scope) ──"
R3="$TMP/rot3"; mkdir -p "$R3/.mega-sdd/memory"
printf 'telemetry: false\n' > "$R3/.mega-sdd/config.yaml"
"$PY" -c "
with open('$R3/.mega-sdd/memory/telemetry.jsonl','w') as f:
    for i in range(20001):
        f.write('{\"event_type\":\"z\"}\n')
"
( cd "$R3" && printf '{"source":"startup","session_id":"s"}' | bash "$SS" >/dev/null 2>&1 )
[ ! -f "$R3/.mega-sdd/memory/telemetry.jsonl.1" ] && pass "z opt-out project never rotated" || fail "z rotation ran under telemetry: false"

echo
[ $rc -eq 0 ] && echo "ALL PASS"
exit $rc
