#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for the dispatch-prompt enrichment gate (Task F).
#
# Asserts validate-dispatch-prompt.sh FLAGS the bad/ fixture (a ui_ux unit's emitted
# bolts/**/dispatch-prompt.md that carries the UI/UX slice line but NO injected design
# tokens and NO view/component exemplar — only a controller code example) with BOTH
# `tokens_not_injected` AND `exemplar_missing`, and PASSES the good/ fixture (same unit
# whose prompt carries a `Design tokens:` line + a `Pattern: view` code exemplar).
#
# VACUOUS-PASS GUARD: both fixtures are rooted with .mega-sdd/codebase/
# starterkit-context.yaml (framework_pack: laravel-base-26, so view_glob resolves) and a
# real ui_ux-relevance dispatch-prompt.md under the canonical
# .mega-sdd/vaults/<phase>/bolts/U-XXX/ path. Each assertion checks prompts_checked >= 1,
# so a green result proves a real parse — not a SKIP masquerading as exit 0. The
# in-scope signal (starterkit_relevance: ui_ux) is INDEPENDENT of the verdict signal
# (tokens/exemplar markers): bad/ is correctly classified ui_ux and FAILs (does not SKIP).
#
# Run: bash tests/fixtures/code-delivery/dispatch-prompt/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-dispatch-prompt.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }

if [ ! -f "$VALIDATOR" ]; then
  fail "validate-dispatch-prompt.sh not found at $VALIDATOR"
  exit 1
fi

read_state() { # <state_file> <python-expr-on-d>
  python3 -c "
import json,sys
try:
    d=json.load(open('$1'))
    print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null
}

# ─── BAD fixture: must FAIL with tokens_not_injected + exemplar_missing ──────
note "=== BAD fixture (expect FAIL: tokens_not_injected + exemplar_missing) ==="
bash "$VALIDATOR" --cwd="$HERE/bad" --quiet
BAD_EXIT=$?
BAD_STATE="$HERE/bad/.mega-sdd/.dispatch-prompt-state.json"
[ -f "$BAD_STATE" ] || fail "bad: state file not written at $BAD_STATE"

BAD_STATUS=$(read_state "$BAD_STATE" "d.get('status')")
BAD_CHECKED=$(read_state "$BAD_STATE" "d.get('prompts_checked',0)")
BAD_ISSUES=$(read_state "$BAD_STATE" "sorted({i['issue'] for i in d.get('issues',[])})")
note "bad: status=$BAD_STATUS exit=$BAD_EXIT prompts_checked=$BAD_CHECKED"
note "bad: issues = $BAD_ISSUES"

[ "$BAD_STATUS" = "FAIL" ] || fail "bad: status expected FAIL, got '$BAD_STATUS'"
[ "$BAD_EXIT" = "1" ] || fail "bad: exit expected 1 (FAIL), got '$BAD_EXIT'"
[ "$BAD_CHECKED" -ge 1 ] 2>/dev/null || fail "bad: prompts_checked expected >=1 (real parse, not SKIP), got '$BAD_CHECKED'"

for iid in tokens_not_injected exemplar_missing; do
  HIT=$(read_state "$BAD_STATE" "sum(1 for i in d.get('issues',[]) if i.get('issue')=='$iid')")
  if [ "$HIT" = "0" ] || [ "${HIT:0:4}" = "ERR:" ]; then
    fail "bad: expected issue '$iid' to fire, but it did not"
  else
    note "  OK issue fired: $iid (x$HIT)"
  fi
done

# ─── GOOD fixture: must PASS, no issues, real parse ─────────────────────────
note ""
note "=== GOOD fixture (expect PASS) ==="
bash "$VALIDATOR" --cwd="$HERE/good" --quiet
GOOD_EXIT=$?
GOOD_STATE="$HERE/good/.mega-sdd/.dispatch-prompt-state.json"
[ -f "$GOOD_STATE" ] || fail "good: state file not written at $GOOD_STATE"

GOOD_STATUS=$(read_state "$GOOD_STATE" "d.get('status')")
GOOD_CHECKED=$(read_state "$GOOD_STATE" "d.get('prompts_checked',0)")
GOOD_ISSUES=$(read_state "$GOOD_STATE" "len(d.get('issues',[]))")
note "good: status=$GOOD_STATUS exit=$GOOD_EXIT prompts_checked=$GOOD_CHECKED issues=$GOOD_ISSUES"

[ "$GOOD_STATUS" = "PASS" ] || fail "good: status expected PASS, got '$GOOD_STATUS'"
[ "$GOOD_EXIT" = "0" ] || fail "good: exit expected 0 (PASS), got '$GOOD_EXIT'"
[ "$GOOD_CHECKED" -ge 1 ] 2>/dev/null || fail "good: prompts_checked expected >=1 (real parse, not SKIP), got '$GOOD_CHECKED'"
[ "$GOOD_ISSUES" = "0" ] || fail "good: issues expected 0, got '$GOOD_ISSUES'"

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — validator flags bad/, passes good/ (both via a real parse)."
  exit 0
else
  note "VERIFY FAILED — see FAIL lines above."
  exit 1
fi
