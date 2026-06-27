#!/usr/bin/env bash
# Contract test for measure-fork-tokens.sh — the A/B comparator that decides
# whether the detect-drift context:fork actually wins on cost-weighted tokens,
# the precondition (CLAUDE.md + moat-token-tradeoff memory) before extending
# fork to scan-codebase / bind-codebase. It does NOT re-instrument; it diffs two
# .token-cost-state.json snapshots produced by report-token-cost.sh.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/plugins/mega-sdd/scripts/measure-fork-tokens.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

[ -f "$SCRIPT" ] || { echo "FAIL comparator missing: $SCRIPT"; exit 1; }

mkstate() { # $1=file $2=total $3=detect-drift-bucket $4=subagent_turns(default 8)
  cat > "$1" <<JSON
{ "status": "PASS", "have_telemetry": true, "turns": 10, "subagent_turns": ${4:-8},
  "raw_total": $(( $2 * 5 )), "cost_weighted_total": $2,
  "by_skill": [ {"skill": "detect-drift", "turns": 8, "raw": $(( $3 * 5 )), "cost_weighted": $3, "pct_cost": 80.0} ] }
JSON
}

# baseline (no fork) heavier than fork (main) — the expected WIN shape
mkstate "$TMP/baseline.json" 605000 500000
mkstate "$TMP/fork.json"     400000 300000

# --- 1) total compare: fork < baseline => WIN (exit 0) ----------------------
if out=$(bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork.json" 2>&1); then
  ok "fork<baseline ⇒ exit 0 (WIN)"
  printf '%s' "$out" | grep -qiE 'WIN' && ok "output names the WIN verdict" || bad "output missing WIN verdict: $out"
  printf '%s' "$out" | grep -qE '605000|605' && ok "output reports baseline figure" || bad "baseline figure absent: $out"
else bad "fork<baseline should exit 0, got non-zero: $out"; fi

# --- 2) no-win: fork >= baseline => exit 1 ----------------------------------
mkstate "$TMP/fork_heavy.json" 700000 600000
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork_heavy.json" >/dev/null 2>&1; then
  bad "fork>baseline should exit 1 (NO-WIN) but exited 0"
else ok "fork>baseline ⇒ exit 1 (NO-WIN)"; fi

# --- 3) per-skill compare via --skill ---------------------------------------
# detect-drift bucket: baseline 500000 vs fork 300000 => WIN
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork.json" --skill=detect-drift >/dev/null 2>&1; then
  ok "--skill compares the named bucket (WIN)"
else bad "--skill=detect-drift should WIN (500000>300000)"; fi

# --- 4) margin gate: require fork >= margin below baseline -------------------
# fork 400000 vs baseline 605000 = ~33.9% below; margin 0.50 not met => NO-WIN
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork.json" --margin=0.50 >/dev/null 2>&1; then
  bad "margin 0.50 unmet (only ~34% below) should exit 1"
else ok "--margin enforces a minimum win threshold"; fi
# margin 0.10 IS met (34% > 10%) => WIN
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork.json" --margin=0.10 >/dev/null 2>&1; then
  ok "--margin satisfied ⇒ WIN"
else bad "margin 0.10 met (~34% below) should exit 0"; fi

# --- 5) missing input fails loudly (not silently 'win') ---------------------
if bash "$SCRIPT" --baseline="$TMP/none.json" --fork="$TMP/fork.json" >/dev/null 2>&1; then
  bad "missing baseline file should NOT exit 0"
else ok "missing input fails closed (non-zero)"; fi

# --- 6) --require-subagent: fork with subagent_turns=0 ⇒ ERROR (exit 2) ------
# This is the SubagentStop-didn't-fire footgun: a fork whose cost was never captured.
# A verdict on it would be a phantom; the guard must refuse, not silently compare.
mkstate "$TMP/fork_nosub.json" 400000 300000 0      # subagent_turns=0
out=$(bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork_nosub.json" --require-subagent 2>&1)
rc=$?
if [ "$rc" -eq 2 ]; then ok "--require-subagent rejects fork with 0 subagent turns (exit 2)"
else bad "--require-subagent should exit 2 on subagent_turns=0, got $rc: $out"; fi
printf '%s' "$out" | grep -qi 'SubagentStop' && ok "guard message names SubagentStop (actionable)" \
  || bad "guard message should mention SubagentStop: $out"
# baseline arm is NOT guarded: a no-fork baseline with subagent_turns=0 is legitimate.
mkstate "$TMP/base_nosub.json" 605000 500000 0
if bash "$SCRIPT" --baseline="$TMP/base_nosub.json" --fork="$TMP/fork.json" --require-subagent >/dev/null 2>&1; then
  ok "--require-subagent checks the FORK arm only (baseline subagent_turns=0 is fine)"
else bad "--require-subagent must not reject a legitimate inline baseline (subagent_turns=0)"; fi

# --- 7) --require-subagent satisfied ⇒ normal verdict (fork has subagent telemetry) -
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork.json" --require-subagent >/dev/null 2>&1; then
  ok "--require-subagent satisfied (fork subagent_turns>0) ⇒ WIN verdict proceeds"
else bad "--require-subagent should pass when fork has subagent_turns>0"; fi

# --- 8) --require-subagent on a LEGACY snapshot (no subagent_turns field) ⇒ fail closed -
# A pre-this-change .token-cost-state.json has no subagent_turns; it cannot prove the
# fork cost was captured, so the guard must refuse (exit 2), not assume success.
cat > "$TMP/fork_legacy.json" <<'JSON'
{ "status": "PASS", "have_telemetry": true, "turns": 10,
  "raw_total": 2000000, "cost_weighted_total": 400000,
  "by_skill": [ {"skill": "detect-drift", "turns": 8, "raw": 1500000, "cost_weighted": 300000, "pct_cost": 75.0} ] }
JSON
if bash "$SCRIPT" --baseline="$TMP/baseline.json" --fork="$TMP/fork_legacy.json" --require-subagent >/dev/null 2>&1; then
  bad "legacy fork snapshot (no subagent_turns) must fail closed under --require-subagent"
else ok "--require-subagent fails closed on a legacy snapshot missing subagent_turns"; fi

echo
if [ "$fail" -eq 0 ]; then echo "PASS measure-fork-tokens contract"; exit 0
else echo "measure-fork-tokens contract FAILED"; exit 1; fi
