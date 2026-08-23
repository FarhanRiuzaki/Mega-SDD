#!/usr/bin/env bash
# v7 Fase 7 — PRODUCTION-PATH spawn ceilings (spec: research/2026-08-23-v7-fase7-spawn-audit.md §0-§1).
#
# THE LESSON THIS FILE ENCODES (Fase-7 audit, user-mandated): a spawn pin must
# measure the PRODUCTION dispatch path, not the hook body called directly.
# test-tier-s-hooks.sh calls `bash $HOOKS/<name>` — which never saw the
# dispatcher chain (bash run-hook.sh → dirname → uname → bash <body> = 4 procs
# per matched event, ~0.88 s/event on Windows+Falcon). This suite derives the
# command to run FROM hooks.json itself, so any future dispatch change is
# measured automatically.
#
# Counting convention (parity with the audit tables): the hook command string is
# executed via /bin/sh -c by ABSOLUTE path (the harness shell is not counted —
# it stands in for Claude Code's own spawn), with a PATH shim counting every
# external exec the command makes, INCLUDING bash/dirname/uname. Numbers are
# CEILINGS (measured + margin), tightened in the same commit that lowers them
# (measure-last). Not counted: builtins, $( ) subshells, absolute-path execs —
# so Windows projections from these numbers are lower bounds.
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$REPO/plugins/mega-sdd"
HOOKS_JSON="$PLUGIN/hooks/hooks.json"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# ── dispatch commands derived from hooks.json (the production truth) ─────────
# One command per event we exercise; ${CLAUDE_PLUGIN_ROOT} substituted.
CMD_FILE="$WORK/cmds"
PLUGIN="$PLUGIN" HOOKS_JSON="$HOOKS_JSON" python3 - > "$CMD_FILE" <<'PY'
import json, os
root = os.environ["PLUGIN"]
h = json.load(open(os.environ["HOOKS_JSON"]))["hooks"]
for ev in ("SessionStart", "PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit"):
    cmd = h[ev][0]["hooks"][0]["command"].replace("${CLAUDE_PLUGIN_ROOT}", root)
    print(ev + "\t" + cmd)
PY
# bash-3.2-safe (the suite runner is /bin/bash on macOS): plain vars, no declare -A
CMD_SS=""; CMD_PRE=""; CMD_POST=""; CMD_STOP=""; CMD_UPS=""
while IFS=$'\t' read -r ev cmd; do
  case "$ev" in
    SessionStart) CMD_SS="$cmd" ;;
    PreToolUse) CMD_PRE="$cmd" ;;
    PostToolUse) CMD_POST="$cmd" ;;
    Stop) CMD_STOP="$cmd" ;;
    UserPromptSubmit) CMD_UPS="$cmd" ;;
  esac
done < "$CMD_FILE"
dispatch_cmd() {
  case "$1" in
    SessionStart) printf '%s' "$CMD_SS" ;;
    PreToolUse) printf '%s' "$CMD_PRE" ;;
    PostToolUse) printf '%s' "$CMD_POST" ;;
    Stop) printf '%s' "$CMD_STOP" ;;
    UserPromptSubmit) printf '%s' "$CMD_UPS" ;;
  esac
}
for ev in SessionStart PreToolUse PostToolUse Stop UserPromptSubmit; do
  [ -n "$(dispatch_cmd "$ev")" ] || { bad "hooks.json carries no $ev command"; echo "spawn-ceilings FAILED"; exit 1; }
done

# ── PATH shim counter (audit-widened tool list) ──────────────────────────────
SHIM="$WORK/shim"; mkdir -p "$SHIM"
CNT="$WORK/counts"; mkdir -p "$CNT"
for tool in bash python3 date wc git grep sed find ls awk dirname uname base64 head tail tr cat mktemp cp rm mv sort cut stat; do
  real=$(command -v "$tool" 2>/dev/null) || continue
  case "$real" in /*) ;; *) continue ;; esac
  printf '#!/bin/bash\necho 1 >> "%s/%s"\nexec "%s" "$@"\n' "$CNT" "$tool" "$real" > "$SHIM/$tool"
  chmod +x "$SHIM/$tool"
done
reset_counts() { rm -f "$CNT"/* 2>/dev/null; }
count() { if [ -f "$CNT/$1" ]; then wc -l < "$CNT/$1" | tr -d ' '; else echo 0; fi; }
total() { local t=0 f n; for f in "$CNT"/*; do [ -f "$f" ] || continue; n=$(wc -l < "$f"); t=$((t + n)); done; echo "$t"; }

# run_ev <event> <json> [cwd]  — production dispatch under the shim.
run_ev() {
  local cmd json cwd
  cmd="$(dispatch_cmd "$1")"; json="$2"; cwd="${3:-$WORK}"
  ( cd "$cwd" && printf '%s' "$json" | HOME="$SSHOME" PATH="$SHIM:$PATH" /bin/sh -c "$cmd" ) 2>/dev/null
  sleep 1  # async children finish appending
}

# ── fixtures ─────────────────────────────────────────────────────────────────
PLAIN="$WORK/plain"; mkdir -p "$PLAIN"
SSHOME="$WORK/sshome"; mkdir -p "$SSHOME/.claude/commands"
printf '%s\n' '<!-- mega-sdd-front-door-wrapper v1 — managed by the mega-sdd plugin -->' \
  > "$SSHOME/.claude/commands/mega-sdd.md"
mkfix() {
  mkdir -p "$1/.mega-sdd/codebase" "$1/src"
  echo "console.log('x')" > "$1/src/app.js"
  printf '{"generated_by":"build-symbol-index.sh","head_commit":"abc","symbols":[]}' \
    > "$1/.mega-sdd/codebase/symbol-index.json"
  ( cd "$1" && git init -q . && git -c user.email=t@t -c user.name=t add -A \
    && git -c user.email=t@t -c user.name=t commit -q -m x ) >/dev/null 2>&1
}
FIXA="$WORK/unarmed"; mkfix "$FIXA"
FIXB="$WORK/armed";   mkfix "$FIXB"
mkdir -p "$FIXB/.mega-sdd/vaults/v1/units"
echo "unit" > "$FIXB/.mega-sdd/vaults/v1/units/U-001.md"
SID="sess-spawn-ceilings"
printf '{"session_id":"%s","chain_engaged":true,"entries":{},"engaged_sessions":{"%s":true}}' "$SID" "$SID" \
  > "$FIXB/.mega-sdd/.gateguard-state.json"
TRANS="$WORK/transcript.jsonl"
printf '{"message":{"role":"user","content":"lanjut"}}\n{"message":{"role":"assistant","content":"ok."}}\n' > "$TRANS"

# ── C1: UserPromptSubmit, SDD project — gateway tag through the real dispatch ─
reset_counts
OUT=$(run_ev UserPromptSubmit "{\"session_id\":\"s\",\"cwd\":\"$FIXA\"}")
[ "$(total)" -le 2 ] && [ "$OUT" = "mega-sdd-trace:turn" ] \
  && ok "C1 UPS SDD: ≤2 spawns via production dispatch ($(total)), tag intact" \
  || bad "C1 UPS SDD: spawns=$(total) out=[$OUT]"

# ── C2: PreToolUse Edit tier-S — the '0 fork' contract, dispatcher included ──
reset_counts
OUT=$(run_ev PreToolUse "{\"session_id\":\"s\",\"cwd\":\"$FIXA\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIXA/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}")
[ "$(total)" -le 2 ] && [ -z "$OUT" ] \
  && ok "C2 PRE Edit tier-S: ≤2 spawns incl dispatcher ($(total))" \
  || bad "C2 PRE Edit tier-S: spawns=$(total) out=[${OUT:0:60}]"

# ── C3: PostToolUse Write tier-S — journal leg ───────────────────────────────
reset_counts
run_ev PostToolUse "{\"session_id\":\"s\",\"cwd\":\"$FIXA\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXA/src/app.js\"}}" >/dev/null
grep -q '"path":"src/app.js"' "$FIXA/.mega-sdd/codebase/.dirty-paths.jsonl" 2>/dev/null && ROW=1 || ROW=0
[ "$(total)" -le 3 ] && [ "$ROW" -eq 1 ] \
  && ok "C3 POST Write tier-S: ≤3 spawns ($(total)), journal row intact" \
  || bad "C3 POST Write tier-S: spawns=$(total) row=$ROW"

# ── C4: Stop SDD, turn-gated steady state (2nd fire) ─────────────────────────
run_ev Stop "{\"session_id\":\"s\",\"cwd\":\"$FIXA\",\"transcript_path\":\"/nonexistent\"}" >/dev/null
reset_counts
run_ev Stop "{\"session_id\":\"s\",\"cwd\":\"$FIXA\",\"transcript_path\":\"/nonexistent\"}" >/dev/null
[ "$(total)" -le 12 ] \
  && ok "C4 Stop SDD steady (turn-gated): ≤12 spawns ($(total))" \
  || bad "C4 Stop SDD steady: spawns=$(total)"

# ── C5: SessionStart SDD — anchor injection budget ───────────────────────────
reset_counts
OUT=$(run_ev SessionStart '{"source":"startup","session_id":"s"}' "$FIXA")
printf '%s' "$OUT" | grep -q "EXTREMELY_IMPORTANT" && ANCH=1 || ANCH=0
[ "$(total)" -le 15 ] && [ "$ANCH" -eq 1 ] \
  && ok "C5 SessionStart SDD: ≤15 spawns ($(total)), anchor intact" \
  || bad "C5 SessionStart SDD: spawns=$(total) anchor=$ANCH"

# ── C6: PreToolUse Edit ARMED — the gated path still fires ───────────────────
reset_counts
run_ev PreToolUse "{\"session_id\":\"$SID\",\"cwd\":\"$FIXB\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FIXB/src/app.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}" >/dev/null
[ "$(total)" -le 8 ] \
  && ok "C6 PRE Edit armed: ≤8 spawns ($(total), python=$(count python3))" \
  || bad "C6 PRE Edit armed: spawns=$(total)"

# ── C7: PostToolUse ARMED unit write — validator fan-out era ceiling ─────────
reset_counts
run_ev PostToolUse "{\"session_id\":\"$SID\",\"cwd\":\"$FIXB\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$FIXB/.mega-sdd/vaults/v1/units/U-001.md\"}}" >/dev/null
sleep 2
[ "$(total)" -le 100 ] \
  && ok "C7 POST unit write armed: ≤100 spawns ($(total), python=$(count python3))" \
  || bad "C7 POST unit write armed: spawns=$(total)"

# ── C8: PreToolUse Skill execute-bolts — gate aggregator budget + moat proof ─
reset_counts
run_ev PreToolUse "{\"session_id\":\"$SID\",\"cwd\":\"$FIXB\",\"transcript_path\":\"$TRANS\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"\"}}" >/dev/null
[ "$(total)" -le 120 ] && [ -f "$FIXB/.mega-sdd/.validation-blockers.json" ] \
  && ok "C8 PRE execute-bolts gate: ≤120 spawns ($(total)), moat state re-derived at gate" \
  || bad "C8 PRE execute-bolts gate: spawns=$(total) moat=$([ -f "$FIXB/.mega-sdd/.validation-blockers.json" ] && echo yes || echo no)"

# ── C9: PreToolUse Edit non-SDD cwd — the everywhere-else floor ──────────────
reset_counts
run_ev PreToolUse "{\"session_id\":\"s\",\"cwd\":\"$PLAIN\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$PLAIN/x.js\",\"old_string\":\"a\",\"new_string\":\"b\"}}" >/dev/null
[ "$(total)" -le 2 ] \
  && ok "C9 PRE Edit non-SDD: ≤2 spawns ($(total))" \
  || bad "C9 PRE Edit non-SDD: spawns=$(total)"

echo
if [ "$fail" -eq 0 ]; then echo "PASS production-path spawn ceilings"; exit 0
else echo "production-path spawn ceilings FAILED"; exit 1; fi
