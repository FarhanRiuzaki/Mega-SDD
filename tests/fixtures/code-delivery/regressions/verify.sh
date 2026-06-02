#!/usr/bin/env bash
# verify.sh — regression DoD for the 2026-06-02 E2E-audit CRITICAL fixes.
#   TAE2E-01: sibling-consistency must NOT false-FAIL / block a non-Laravel (_universal) FK project.
#   ADV-01:   a non-UTF-8 byte in a vault file must NOT crash a validator into a silent fail-open
#             (the validator must still WRITE its state file and exit cleanly).
# Run: bash tests/fixtures/code-delivery/regressions/verify.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../../.." && pwd)"
SCRIPTS="${PLUGIN_ROOT}/plugins/mega-sdd/scripts"
FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
read_state() { python3 -c "
import json
try: print(json.load(open('$1')).get('status'))
except Exception as e: print('ERR:'+str(e))
" 2>/dev/null; }

# ─── TAE2E-01: non-Laravel FK project must NOT FAIL (graceful PASS/SKIP, no block) ───
note "=== TAE2E-01: sibling-consistency on a non-Laravel (_universal) FK project (expect NOT FAIL) ==="
P1="$HERE/tae2e-nonlaravel-fk"
bash "$SCRIPTS/validate-sibling-consistency.sh" --cwd="$P1" --quiet
EXIT1=$?
ST1=$(read_state "$P1/.mega-sdd/.sibling-consistency-state.json")
note "non-laravel-fk: status=$ST1 exit=$EXIT1"
case "$ST1" in
  PASS|SKIP) : ;;
  *) fail "non-Laravel FK project must be PASS or SKIP, got '$ST1' (TAE2E-01 regression — would BLOCK a non-Laravel stack)";;
esac
[ "$EXIT1" = "0" ] || fail "non-Laravel FK: exit expected 0 (non-blocking), got '$EXIT1'"

# ─── ADV-01: non-UTF-8 byte must NOT crash flow-coverage into a silent fail-open ───
note ""
note "=== ADV-01: flow-coverage on a vault with an invalid-UTF-8 byte (expect a state file written, no crash) ==="
P2="$HERE/adv01-utf8-failopen"
bash "$SCRIPTS/validate-flow-coverage.sh" --cwd="$P2" --quiet >/dev/null 2>&1
EXIT2=$?
STATE2="$P2/.mega-sdd/.flow-coverage-state.json"
if [ -f "$STATE2" ]; then
  ST2=$(read_state "$STATE2")
  note "utf8-failopen: state WRITTEN, status=$ST2 exit=$EXIT2 (pre-fix: crash => NO state file => silent fail-open)"
  case "$ST2" in
    PASS|FAIL|SKIP) : ;;
    *) fail "flow-coverage wrote an unparseable/odd state on bad UTF-8: '$ST2'";;
  esac
else
  fail "ADV-01 regression: flow-coverage CRASHED on the non-UTF-8 byte — no state file written (silent fail-open: the gate is disabled)"
fi

note ""
# ─── ADV-02/03: a MERMAID maker-checker flow must be DETECTED (was a silent PASS) ───
note ""
note "=== ADV-02/03: vault-oqs must detect a mermaid/bullet maker-checker workflow (expect a workflow rail fires) ==="
P3="$HERE/adv02-mermaid-workflow"
VJSON="$P3/.mega-sdd/vaults/demo-phase/vault.json"
bash "$SCRIPTS/validate-vault-oqs.sh" --cwd="$P3" --file-path="$VJSON" --quiet
S3="$P3/.mega-sdd/.vault-oqs-state.json"
if [ -f "$S3" ]; then
  WF=$(python3 -c "
import json
d=json.load(open('$S3'))
print(1 if any(i.get('halt_type') in ('operator_surface_missing','design_source_oq_missing') for i in d.get('issues',[])) else 0)
" 2>/dev/null)
  note "mermaid-workflow: workflow_rail_fired=$WF (pre-fix: numbered-only parser => 0 => silent PASS)"
  [ "$WF" = "1" ] || fail "ADV-02/03 regression: a mermaid maker-checker flow was NOT detected — both operator-UX rails inert (silent PASS)"
else
  fail "ADV-02/03: vault-oqs wrote no state file for the mermaid fixture"
fi

note ""
if [ "$FAILED" -eq 0 ]; then
  note "ALL ASSERTIONS PASS — TAE2E-01 + ADV-01 + ADV-02/03 regressions are fixed."
  exit 0
else
  note "VERIFY FAILED — a CRITICAL/HIGH audit fix regressed."; exit 1
fi
