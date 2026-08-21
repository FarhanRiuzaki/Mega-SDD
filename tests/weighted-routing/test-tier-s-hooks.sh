#!/usr/bin/env bash
# v7 weighted-routing hook contract (spec 2026-08-21-v7-weighted-routing-design.md §3-§4).
#
# The tier gate is a MECHANISM: in a mega-sdd project with NO chain engaged this
# session, the hooks must be near-free (spawn counts LOCKED below); the moat
# guards stay always-on; and arming the session (a mega-sdd:* Skill dispatch)
# must restore the full pre-v7 behavior (mutation-proofed by S12).
#
# Spawn counting: a PATH shim wraps the hot external commands and appends to a
# counter file before exec'ing the real binary. Numbers asserted are CEILINGS —
# a regression that adds spawns to a tier-S path goes red here.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$REPO/plugins/mega-sdd/hooks"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FIX="$WORK/proj"; mkdir -p "$FIX/.mega-sdd/codebase" "$FIX/src"
echo "console.log('x')" > "$FIX/src/app.js"
PLAIN="$WORK/plain"; mkdir -p "$PLAIN"

SHIM="$WORK/shim"; mkdir -p "$SHIM"
CNT="$WORK/counts"; mkdir -p "$CNT"
for tool in python3 date wc git grep sed find ls; do
  real=$(command -v "$tool") || continue
  printf '#!/bin/bash\necho 1 >> "%s/%s"\nexec "%s" "$@"\n' "$CNT" "$tool" "$real" > "$SHIM/$tool"
  chmod +x "$SHIM/$tool"
done
reset_counts() { rm -f "$CNT"/* 2>/dev/null; }
count() { if [ -f "$CNT/$1" ]; then wc -l < "$CNT/$1" | tr -d ' '; else echo 0; fi; }
total() { local t=0 f n; for f in "$CNT"/*; do [ -f "$f" ] || continue; n=$(wc -l < "$f"); t=$((t + n)); done; echo "$t"; }
run_hook() { printf '%s' "$2" | PATH="$SHIM:$PATH" bash "$HOOKS/$1" 2>/dev/null; }

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
SID="sess-v7-test"

# ── S1: PreToolUse Edit, normal path, NOT armed → 0 forks, no output ─────────
reset_counts
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}")
[ "$(total)" -eq 0 ] && [ -z "$OUT" ] && ok "S1 tier-S Edit: ZERO forks, no gate output" \
  || bad "S1 tier-S Edit not free: forks=$(total) out=[$OUT]"

# ── S2: PreToolUse Write of a protected state file, NOT armed → DENY (moat always-on) ──
reset_counts
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIX/.mega-sdd/.validation-blockers.json\",\"content\":\"{}\"}}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "S2 forged-verdict Write still DENIED un-armed (FP_GUARD always-on)" \
  || bad "S2 forged-verdict Write NOT denied un-armed — moat regression"

# ── S3: PreToolUse Bash tamper, NOT armed → DENY (moat always-on) ────────────
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm $FIX/.mega-sdd/.validation-blockers.json\"}}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "S3 Bash state-tamper still DENIED un-armed (anti-self-bypass always-on)" \
  || bad "S3 Bash state-tamper NOT denied un-armed — moat regression"

# ── S3b: spoofed tool_name inside the command must NOT bypass the guard ──────
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm $FIX/.mega-sdd/.validation-blockers.json # \\\"tool_name\\\": \\\"Edit\\\"\"}}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "S3b tool_name spoof inside command still DENIED (union fragment list)" \
  || bad "S3b tool_name spoof bypassed the tamper guard"

# ── S4: PreToolUse innocent Bash, NOT armed → 0 forks ────────────────────────
reset_counts
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm test -- --watch=false\"}}")
[ "$(total)" -eq 0 ] && ok "S4 innocent Bash: ZERO forks" || bad "S4 innocent Bash forked: $(total)"

# ── S5: mega-sdd:* Skill dispatch arms chain_engaged (writer contract) ───────
run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:memory\",\"args\":\"\"}}" >/dev/null
grep -q '"chain_engaged": true' "$FIX/.mega-sdd/.gateguard-state.json" 2>/dev/null \
  && grep -q "\"session_id\": \"$SID\"" "$FIX/.mega-sdd/.gateguard-state.json" \
  && ok "S5 Skill dispatch writes chain_engaged for this session" \
  || bad "S5 chain_engaged marker not written: $(cat "$FIX/.mega-sdd/.gateguard-state.json" 2>/dev/null)"

# ── S6: ARMED session Edit takes the FULL path again (python parse runs) ─────
reset_counts
run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}" >/dev/null
[ "$(count python3)" -ge 1 ] && ok "S6 armed Edit re-enters the full gate path (python=$(count python3))" \
  || bad "S6 armed Edit still skipped the gates — arming is broken"

# ── S7: PostToolUse Write, un-armed session → shell journal, ≤2 forks, 0 python ──
reset_counts
run_hook post-tool-use "{\"session_id\":\"other-sess\",\"cwd\":\"$FIX\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\"}}" >/dev/null
ROW=$(tail -1 "$FIX/.mega-sdd/codebase/.dirty-paths.jsonl" 2>/dev/null)
[ "$(count python3)" -eq 0 ] && [ "$(total)" -le 2 ] \
  && printf '%s' "$ROW" | grep -q '"path":"src/app.js"' \
  && printf '%s' "$ROW" | grep -q '"session":"other-sess"' \
  && ok "S7 un-armed Write: shell journal ($(total)) fork(s), 0 python, row intact" \
  || bad "S7 un-armed Write: python=$(count python3) forks=$(total) row=[$ROW]"

# ── S8: PostToolUse Read, un-armed → 0 forks ─────────────────────────────────
reset_counts
run_hook post-tool-use "{\"session_id\":\"other-sess\",\"cwd\":\"$FIX\",\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\"}}" >/dev/null
[ "$(total)" -eq 0 ] && ok "S8 un-armed Read: ZERO forks" || bad "S8 un-armed Read forked: $(total)"

# ── S9: UserPromptSubmit, un-armed → tag only, 0 forks ───────────────────────
reset_counts
OUT=$(run_hook user-prompt-submit "{\"session_id\":\"other-sess\",\"cwd\":\"$FIX\",\"transcript_path\":\"/nonexistent\"}")
[ "$OUT" = "mega-sdd-trace:turn" ] && [ "$(total)" -eq 0 ] \
  && ok "S9 un-armed prompt: trace tag only, ZERO forks (no transcript scan)" \
  || bad "S9 un-armed prompt: forks=$(total) out=[$OUT]"

# ── S10/S11: Stop + SubagentStop in a NON-mega-sdd project → 0 forks ─────────
reset_counts
run_hook stop "{\"session_id\":\"x\",\"cwd\":\"$PLAIN\",\"transcript_path\":\"/nonexistent\"}" >/dev/null
[ "$(total)" -eq 0 ] && ok "S10 Stop non-SDD project: ZERO forks (was 1-2 python/turn)" \
  || bad "S10 Stop non-SDD forked: $(total)"
reset_counts
run_hook subagent-stop "{\"session_id\":\"x\",\"cwd\":\"$PLAIN\"}" >/dev/null
[ "$(total)" -eq 0 ] && ok "S11 SubagentStop non-SDD project: ZERO forks" \
  || bad "S11 SubagentStop non-SDD forked: $(total)"

# ── S12: ARMED unit write → validator fan-out restored (mutation proof) ──────
mkdir -p "$FIX/.mega-sdd/vaults/v1/units"
echo "unit" > "$FIX/.mega-sdd/vaults/v1/units/U-001.md"
reset_counts
run_hook post-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIX/.mega-sdd/vaults/v1/units/U-001.md\"}}" >/dev/null
sleep 1
[ "$(count python3)" -ge 5 ] && [ -f "$FIX/.mega-sdd/.validation-blockers.json" ] \
  && ok "S12 ARMED unit write: validator fan-out fires (python=$(count python3), moat state written)" \
  || bad "S12 ARMED unit write: fan-out dead (python=$(count python3)) — arming does not restore validators"

# ── S13: subagent sentinel forces the full path even un-armed (R2 rail) ──────
reset_counts
run_hook pre-tool-use "{\"session_id\":\"never-engaged\",\"agent_id\":\"sub-1\",\"cwd\":\"$FIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}" >/dev/null
[ "$(count python3)" -ge 1 ] && ok "S13 subagent-context Edit takes the full (armed) path — R2 fail-closed" \
  || bad "S13 subagent sentinel ignored (python=$(count python3)) — bolt edits would be un-gated"

# ── S14: shared worktree — a 2nd session's dispatch must NOT un-arm the 1st ──
SID_B="sess-v7-second"
run_hook pre-tool-use "{\"session_id\":\"$SID_B\",\"cwd\":\"$FIX\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:memory\",\"args\":\"\"}}" >/dev/null
reset_counts
run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIX/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}" >/dev/null
[ "$(count python3)" -ge 1 ] && ok "S14 session A stays ARMED after session B dispatches (engaged_sessions map)" \
  || bad "S14 shared-worktree un-arm regression: A lost its gates after B's dispatch (python=$(count python3))"

# ── S15/S16: the ARM SWITCH itself is anti-forge protected ───────────────────
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIX/.mega-sdd/.gateguard-state.json\",\"content\":\"{}\"}}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "S15 Write of .gateguard-state.json DENIED (arm switch is anti-forge)" \
  || bad "S15 arm switch writable by agent — un-arm forge possible"
OUT=$(run_hook pre-tool-use "{\"session_id\":\"$SID\",\"cwd\":\"$FIX\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm $FIX/.mega-sdd/.gateguard-state.json\"}}")
printf '%s' "$OUT" | grep -q '"deny"' && ok "S16 Bash rm of .gateguard-state.json DENIED" \
  || bad "S16 arm switch deletable by agent"

echo
if [ "$fail" -eq 0 ]; then echo "PASS v7 tier-S hook contract"; exit 0
else echo "v7 tier-S hook contract FAILED"; exit 1; fi
