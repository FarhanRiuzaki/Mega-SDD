#!/usr/bin/env bash
# Contract test for measure-fork-ab.sh — the friction-guarded driver around the
# detect-drift context:fork A/B. It does NOT run the harness; it pins the two silent
# footguns the driver exists to catch, mechanically, from seeded telemetry:
#   (1) WRONG PLUGIN INSTANCE — an inline baseline that still forked (subagent_turns>0)
#       means the loaded plugin still has context:fork (e.g. the marketplace cache, not
#       the edited dev checkout). capture baseline MUST refuse it.
#   (2) UNCAPTURED FORK COST — a fork arm with subagent_turns==0 (SubagentStop didn't
#       fire, or the loaded instance lacks the fork). capture fork MUST refuse it.
# Plus: the baseline-confound raw numbers are RECORDED and never judged.
#
# Telemetry shape mirrors report-token-cost.sh's parser: turn_end_marker (inline) and
# subagent_end_marker (fork) with usage; skill_invoked sets the attributed skill.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$ROOT/plugins/mega-sdd/scripts/measure-fork-ab.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

[ -f "$DRIVER" ] || { echo "FAIL driver missing: $DRIVER"; exit 1; }

VAULT="$TMP/vault"
TEL="$VAULT/.mega-sdd/memory/telemetry.jsonl"
AB="$VAULT/.mega-sdd/.fork-ab"
mkdir -p "$VAULT/.mega-sdd/memory"

# --- telemetry seeders (one arm's run each) ---------------------------------
seed_fork() {   # a real fork: cost lives in a subagent_end_marker => subagent_turns>0
  cat > "$TEL" <<'JSON'
{"event_type":"skill_invoked","payload":{"skill_full_name":"detect-drift"}}
{"event_type":"subagent_end_marker","payload":{"skill_name":"detect-drift","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":100,"output_tokens":1000}}}
JSON
}
seed_baseline() {  # inline no-fork: cost in turn_end_marker, NO subagent => subagent_turns==0
  cat > "$TEL" <<'JSON'
{"event_type":"skill_invoked","payload":{"skill_full_name":"detect-drift"}}
{"event_type":"turn_end_marker","payload":{"usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000000,"output_tokens":2000}}}
JSON
}
seed_baseline_but_forked() {  # THE footgun #1: "baseline" run that actually forked
  cat > "$TEL" <<'JSON'
{"event_type":"skill_invoked","payload":{"skill_full_name":"detect-drift"}}
{"event_type":"subagent_end_marker","payload":{"skill_name":"detect-drift","usage":{"input_tokens":500,"cache_creation_input_tokens":0,"cache_read_input_tokens":100,"output_tokens":1000}}}
JSON
}
cap() { # $1=arm [$2=extra flag]
  if [ $# -ge 2 ]; then bash "$DRIVER" capture "$1" --cwd="$VAULT" "$2" 2>&1
  else bash "$DRIVER" capture "$1" --cwd="$VAULT" 2>&1; fi
}

# ============================================================================
# 1) capture fork (subagent_turns>0) => OK, fork.json + manifest written
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_fork
out=$(cap fork); rc=$?
if [ $rc -eq 0 ]; then ok "capture fork with a real subagent ⇒ exit 0"
else bad "capture fork should exit 0, got $rc: $out"; fi
[ -f "$AB/fork.json" ] && ok "fork.json snapshot written" || bad "fork.json not written"
grep -q '"subagent_turns": 1' "$AB/manifest.json" 2>/dev/null \
  && ok "manifest records fork subagent_turns=1" || bad "manifest missing fork subagent_turns"

# ============================================================================
# 2) capture fork WITHOUT a subagent (subagent_turns==0) => REFUSE (footgun #2)
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline   # inline telemetry under the FORK arm = no fork happened
out=$(cap fork); rc=$?
if [ $rc -eq 2 ]; then ok "capture fork with subagent_turns=0 ⇒ exit 2 (refuse)"
else bad "capture fork with no subagent should exit 2, got $rc: $out"; fi
printf '%s' "$out" | grep -qi 'SubagentStop\|context: fork' \
  && ok "fork refusal names SubagentStop / context:fork (actionable)" || bad "fork refusal not actionable: $out"
[ -f "$AB/fork.json" ] && bad "refused fork capture must NOT write fork.json" || ok "no fork.json on refusal"

# ============================================================================
# 3) capture baseline inline (subagent_turns==0) => OK + confound note
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline
out=$(cap baseline); rc=$?
if [ $rc -eq 0 ]; then ok "capture baseline inline ⇒ exit 0"
else bad "capture baseline inline should exit 0, got $rc: $out"; fi
[ -f "$AB/baseline.json" ] && ok "baseline.json snapshot written" || bad "baseline.json not written"
printf '%s' "$out" | grep -qi 'confound' && ok "baseline capture prints the confound note" \
  || bad "baseline capture missing confound note: $out"
printf '%s' "$out" | grep -q '1000000' && ok "confound note reports the raw cache_read proxy" \
  || bad "confound note missing raw cache_read figure: $out"
grep -q '"subagent_turns": 0' "$AB/manifest.json" 2>/dev/null \
  && ok "manifest records baseline subagent_turns=0" || bad "manifest missing baseline subagent_turns=0"

# ============================================================================
# 4) capture baseline that ACTUALLY FORKED (subagent_turns>0) => REFUSE (footgun #1)
#    This is the wrong-plugin-instance catch: stripped the dev file, loaded the cache.
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline_but_forked
out=$(cap baseline); rc=$?
if [ $rc -eq 2 ]; then ok "capture baseline that forked ⇒ exit 2 (wrong-instance refuse)"
else bad "capture baseline with subagent_turns>0 should exit 2, got $rc: $out"; fi
printf '%s' "$out" | grep -qi 'cache\|instance' \
  && ok "baseline refusal names the loaded-instance/cache footgun" || bad "baseline refusal not actionable: $out"
printf '%s' "$out" | grep -qi 'reset\|telemetry' \
  && ok "baseline refusal also names the un-reset-telemetry cause" || bad "baseline refusal omits the telemetry-reset cause: $out"
[ -f "$AB/baseline.json" ] && bad "refused baseline capture must NOT write baseline.json" || ok "no baseline.json on refusal"

# ============================================================================
# 5) capture with no usable telemetry (0 turns) => REFUSE
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
: > "$TEL"   # empty telemetry => 0 turns
out=$(cap fork); rc=$?
if [ $rc -eq 2 ]; then ok "capture with 0 turns ⇒ exit 2 (nothing to capture)"
else bad "capture with empty telemetry should exit 2, got $rc: $out"; fi

# ============================================================================
# 6) compare before both arms captured => exit 2 with guidance
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_fork; cap fork >/dev/null 2>&1   # only fork captured
out=$(bash "$DRIVER" compare --cwd="$VAULT" 2>&1); rc=$?
if [ $rc -eq 2 ]; then ok "compare with a missing arm ⇒ exit 2"
else bad "compare missing baseline should exit 2, got $rc: $out"; fi
printf '%s' "$out" | grep -qi 'baseline' && ok "compare names the missing arm" || bad "compare error unclear: $out"

# ============================================================================
# 7) full A/B: capture both, compare => WIN + confound recorded, judged:false
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline; cap baseline >/dev/null 2>&1   # heavy inline baseline (cost ~111000)
seed_fork;     cap fork     >/dev/null 2>&1    # light fork (cost ~5510)
out=$(bash "$DRIVER" compare --cwd="$VAULT" 2>&1); rc=$?
if [ $rc -eq 0 ]; then ok "compare baseline≫fork ⇒ exit 0 (WIN)"
else bad "compare should WIN (baseline 111000 ≫ fork 5510), got $rc: $out"; fi
printf '%s' "$out" | grep -qi 'WIN' && ok "compare output names the WIN verdict" || bad "compare missing verdict: $out"
printf '%s' "$out" | grep -qi 'confound' && ok "compare surfaces the confound line" || bad "compare hides the confound: $out"
[ -f "$AB/result.json" ] && ok "result.json written" || bad "result.json not written"
grep -q '"judged": false' "$AB/result.json" 2>/dev/null \
  && ok "result records confound.judged=false (tool never judges representativeness)" \
  || bad "result.json missing judged:false"
grep -q '"baseline_cache_read_input_tokens": 1000000' "$AB/result.json" 2>/dev/null \
  && ok "result records the raw baseline cache_read proxy" || bad "result.json missing cache_read proxy"

# ============================================================================
# 8) compare enforces --require-subagent through the driver (fork arm captured w/o sub)
#    (Cannot happen via capture — capture refuses it — but a hand-planted fork.json must
#     still be rejected by the compare guard, proving the driver never drops it.)
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline; cap baseline >/dev/null 2>&1
mkdir -p "$AB"
cat > "$AB/fork.json" <<'JSON'
{ "status": "PASS", "have_telemetry": true, "turns": 8, "subagent_turns": 0,
  "raw_total": 27550, "cost_weighted_total": 5510,
  "by_skill": [ {"skill": "detect-drift", "turns": 8, "raw": 27550, "cost_weighted": 5510, "pct_cost": 100.0} ] }
JSON
out=$(bash "$DRIVER" compare --cwd="$VAULT" 2>&1); rc=$?
if [ $rc -eq 2 ]; then ok "compare rejects a fork snapshot with subagent_turns=0 (--require-subagent)"
else bad "compare must exit 2 on subagent_turns=0 fork, got $rc: $out"; fi

# ============================================================================
# 9) status + reset
# ============================================================================
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
seed_baseline; cap baseline >/dev/null 2>&1
out=$(bash "$DRIVER" status --cwd="$VAULT" 2>&1)
printf '%s' "$out" | grep -qi 'baseline.*captured' && ok "status shows a captured arm" || bad "status wrong: $out"
printf '%s' "$out" | grep -qi 'fork.*not captured' && ok "status shows the pending arm" || bad "status missing pending arm: $out"
bash "$DRIVER" reset --cwd="$VAULT" >/dev/null 2>&1
[ -d "$AB" ] && bad "reset should remove the .fork-ab dir" || ok "reset clears captured arms"

echo
if [ "$fail" -eq 0 ]; then echo "PASS measure-fork-ab contract"; exit 0
else echo "measure-fork-ab contract FAILED"; exit 1; fi
