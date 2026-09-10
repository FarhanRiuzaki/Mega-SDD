#!/usr/bin/env bash
# v8 P1 --lite lane plumbing (7.34.0 debt #2): the flag has a DURABLE form —
# config.yaml `lane: lite` → state_probes.probe_lane → derived.lane — and one
# script rail: validate-preflight.sh --predictive refuses the execute-bolts hop
# under the lite lane while .plan-coverage-state.json is missing or FAIL.
# Standard lane: byte-identical behavior (no new check emitted).
# Run: bash tests/w1-zero-idle/test-lite-lane.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units"; echo '{"open_questions":[]}' > "$V/vault.json"
( cd "$T" && git init -q . )
probe() { python3 -c "
import sys; sys.path.insert(0, '$S/_lib'); import state_probes as sp
print(sp.probe_lane('$T'))"; }
[ "$(probe)" = "standard" ] && pass "a: no config key → lane standard (default)" || fail "a: default lane wrong: $(probe)"
printf 'spine: express\nlane: lite   # v8\n' > "$T/.mega-sdd/config.yaml"
[ "$(probe)" = "lite" ] && pass "b: config `lane: lite` → probe_lane lite (comment tolerated)" || fail "b: lite not read"
printf 'lane: turbo\n' > "$T/.mega-sdd/config.yaml"
[ "$(probe)" = "standard" ] && pass "c: unknown value → standard (never a third lane)" || fail "c: unknown value leaked"
# derived.lane through the state engine (same seam as derived.spine)
printf 'lane: lite\n' > "$T/.mega-sdd/config.yaml"
D=$(python3 -c "
import sys; sys.path.insert(0, '$S/_lib'); import state_probes as sp
print(sp.collect_state('$T').get('derived', {}).get('lane', 'MISSING'))" 2>&1 | tail -1)
case "$D" in lite) pass "d: derived.lane = lite via the state engine (collect_state)" ;; *) fail "d: derived.lane wrong: $D" ;; esac
# predictive rail: lite + execute-bolts in the chain + no coverage state → fatal
OUT="$(bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts 2>/dev/null)"; RC=$?
echo "$OUT" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' && [ $RC -eq 3 ] \
  && pass "e: lane lite + no .plan-coverage-state.json → fatal lite_plan_coverage_pass (exit 3)" || fail "e: rail missing (rc=$RC): $(echo "$OUT" | tail -2)"
echo '{"status":"FAIL","gaps":[{"slug":"x"}]}' > "$T/.mega-sdd/.plan-coverage-state.json"
bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts >/dev/null 2>&1; [ $? -eq 3 ] && pass "f: FAIL coverage state → still fatal" || fail "f: FAIL state passed"
echo '{"status":"PASS","gaps":[]}' > "$T/.mega-sdd/.plan-coverage-state.json"
OUT="$(bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts 2>/dev/null)"
echo "$OUT" | grep -q '"check": "lite_plan_coverage_pass", "status": "ok"' && pass "g: PASS coverage state → ok" || fail "g: PASS state not ok: $(echo "$OUT" | grep lite_)"
# standard lane: the check is never emitted (byte-identical v7 behavior)
printf 'lane: standard\n' > "$T/.mega-sdd/config.yaml"; rm -f "$T/.mega-sdd/.plan-coverage-state.json"
OUT="$(bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts 2>/dev/null)"
! echo "$OUT" | grep -q 'lite_plan_coverage_pass' && pass "h: standard lane → no lite check emitted" || fail "h: lite check leaked into standard lane"
# prose plumbing
grep -q '^lane: standard' "$P/references/project-config.md" && grep -q 'lane: standard | lite' "$P/skills/orchestrate-flow/SKILL.md" && grep -q 'derived.lane' "$P/commands/mega-sdd.md" && grep -q 'derived.lane: lite' "$P/skills/execute-bolts/SKILL.md" \
  && pass "i: config doc + orchestrate-flow derived block + front door + execute-bolts 3.9 name the durable lane" || fail "i: prose plumbing incomplete"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
