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

mkstate() { # $1=file $2=total $3=detect-drift-bucket
  cat > "$1" <<JSON
{ "status": "PASS", "have_telemetry": true, "turns": 10,
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

echo
if [ "$fail" -eq 0 ]; then echo "PASS measure-fork-tokens contract"; exit 0
else echo "measure-fork-tokens contract FAILED"; exit 1; fi
