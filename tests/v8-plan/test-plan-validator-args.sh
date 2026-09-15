#!/usr/bin/env bash
# 8.0.3 item 2 — the plan skill told the controller to run
#   validate-sibling-consistency.sh --cwd=<root> --vault=<vault>
# but the script takes NO --vault= (exit 2 "unknown arg"). Since bd1159c (2026-09-11) every lite run's
# PLAN-phase call failed first (xs lite 7.37.1, clinic lite 7.37.1, xs lite 7.38.0 run #1/#2, F.4) and
# the controller re-ran it without --vault within a minute; the execute-bolts gate ALSO re-derives the
# state with the right args (hooks/pre-tool-use, `wait` before the aggregator) — so the gate never ran
# blind, but the instruction was wrong and a piped `| tail; echo $?` reported the usage error as rc=0.
#   a  --vault= → exit 2 AND a `STATUS: ERROR` line on STDOUT (visible through any pipe)
#   b  the documented piped idiom: ${PIPESTATUS[0]} is 2, `$?` after tail is 0 (why the rule exists)
#   c  --cwd=<fixture> is the valid form: exit is 0 or 1, never 2
#   d  plan/SKILL.md + plan-procedure.md carry `--cwd=<root>` with NO --vault for this validator,
#      and the procedure carries the read-the-exit-code rule
#   e  the execute-bolts gate re-derives the state with `--cwd` (both modes) before reading it
# Run: bash tests/v8-plan/test-plan-validator-args.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts/validate-sibling-consistency.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; mkdir -p "$T/.mega-sdd/vaults/app/units"; ( cd "$T" && git init -q . )
OUT="$(bash "$S" --cwd="$T" --vault="$T/.mega-sdd/vaults/app" 2>/dev/null)"; RC=$?
[ $RC -eq 2 ] && echo "$OUT" | grep -q '^STATUS: ERROR unknown arg: --vault=' && pass "a: --vault= → exit 2 + STATUS: ERROR on stdout" || fail "a: rc=$RC out=$OUT"
bash "$S" --cwd="$T" --vault=x 2>&1 | tail -3 >/dev/null; PS=${PIPESTATUS[0]}; LAST=$?
[ "$PS" -eq 2 ] && [ "$LAST" -eq 0 ] && pass "b: piped idiom: \$? after tail = 0 (the swallow), PIPESTATUS[0] = 2 (the truth)" || fail "b: PIPESTATUS=$PS last=$LAST"
bash "$S" --cwd="$T" --quiet >/dev/null 2>&1; RC=$?; [ $RC -ne 2 ] && pass "c: --cwd=<root> is the valid form (rc=$RC, not a usage error)" || fail "c: rc=$RC"
SK="$P/skills/plan/SKILL.md"; PR="$P/skills/plan/references/plan-procedure.md"
! grep -q 'validate-sibling-consistency.sh --cwd=<root> --vault' "$SK" "$PR" && grep -q 'validate-sibling-consistency.sh --cwd=<root>`' "$SK" && grep -q 'validate-sibling-consistency.sh --cwd=<root>`' "$PR" && grep -q "Read every validator's exit code directly" "$PR" \
  && pass "d: plan docs call the validator with --cwd only + carry the read-the-exit-code rule" || fail "d: plan docs"
grep -q 'validate-sibling-consistency.sh" --cwd="$PROJECT_ROOT" --quiet' "$P/hooks/pre-tool-use" && grep -q 'validate-sibling-consistency.sh" --cross-cutting --cwd="$PROJECT_ROOT" --quiet' "$P/hooks/pre-tool-use" \
  && pass "e: execute-bolts gate re-derives sibling-consistency (both modes) with --cwd before reading the state" || fail "e: hook re-derive"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
