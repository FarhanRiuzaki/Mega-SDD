#!/usr/bin/env bash
# test-analyze-aggregate-parity.sh — Round-3 audit gap R3-11.
#
# run-analyze.sh has two modes:
#   FULL           — re-runs validators; discovery-gated ones (unit_spec, bolt_artifacts,
#                    fsd_slots, kb_*) report SKIP when no in-scope files exist.
#   AGGREGATE-ONLY — reads state files off disk (cheap, no re-run; used by the Stop hook).
#
# Bug: aggregate-only trusted a discovery-gated validator's on-disk status even when the
# source files were gone — so a STALE FAIL left by a prior chain was reported as a live
# FAIL, while FULL on the same tree reports SKIP/PASS. The two modes disagreed.
#
# This pins the invariant: on the SAME tree, FULL and AGGREGATE-ONLY produce the SAME
# overall verdict. We force the divergence (stale FAIL state file, no source file) and
# assert parity. Report-only path — the moat reads .validation-blockers.json directly,
# never this aggregate, so the fix cannot weaken any gate.
#
# CI-safe: bash + python3 only.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANALYZE="$PLUGIN_ROOT/scripts/run-analyze.sh"

[ -f "$ANALYZE" ] || { echo "FAIL: run-analyze.sh not found at $ANALYZE"; exit 1; }

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

_overall() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['status'])" "$1/.mega-sdd/.analyze-state.json"; }
_status_of() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['boundaries'][sys.argv[2]]['status'])" "$1/.mega-sdd/.analyze-state.json" "$2"; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/.mega-sdd"

# 1. FULL baseline on a tree with no discovery-gated source files.
bash "$ANALYZE" --cwd="$ROOT" --quiet >/dev/null 2>&1
FULL_OVERALL="$(_overall "$ROOT")"
FULL_FSD="$(_status_of "$ROOT" fsd_slots)"

# 2. Plant a STALE FAIL for a discovery-gated validator, with NO matching source file.
printf '{"status":"FAIL","checked_file":"vaults/v1/fsd/FSD.md","issues_count":1}\n' \
  > "$ROOT/.mega-sdd/.fsd-slots-state.json"

# 3. AGGREGATE-ONLY on the same tree.
bash "$ANALYZE" --cwd="$ROOT" --aggregate-only --quiet >/dev/null 2>&1
AGG_OVERALL="$(_overall "$ROOT")"
AGG_FSD="$(_status_of "$ROOT" fsd_slots)"

echo "  (FULL: overall=$FULL_OVERALL fsd_slots=$FULL_FSD | AGGREGATE: overall=$AGG_OVERALL fsd_slots=$AGG_FSD)"

# Sanity: the fixture must actually exercise the bug surface — FULL must NOT itself be FAIL,
# else parity would hold trivially and prove nothing.
if [ "$FULL_OVERALL" = "FAIL" ]; then
  fail "fixture invalid: FULL overall is FAIL — perturbation cannot be distinguished"
fi

# Core invariant: same tree -> same overall verdict in both modes.
if [ "$AGG_OVERALL" = "$FULL_OVERALL" ]; then
  pass "FULL and AGGREGATE-ONLY agree on overall verdict ($AGG_OVERALL)"
else
  fail "mode divergence: FULL=$FULL_OVERALL but AGGREGATE-ONLY=$AGG_OVERALL (stale state trusted)"
fi

# And the discovery-gated boundary must SKIP (not FAIL on a phantom file) in aggregate-only.
if [ "$AGG_FSD" = "SKIP" ]; then
  pass "aggregate-only marks fsd_slots SKIP when no FSD.md exists (mirrors FULL)"
else
  fail "aggregate-only fsd_slots=$AGG_FSD (expected SKIP — read stale state instead)"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "test-analyze-aggregate-parity: ALL PASS"
  exit 0
else
  echo "test-analyze-aggregate-parity: $fails FAILURE(S)"
  exit 1
fi
