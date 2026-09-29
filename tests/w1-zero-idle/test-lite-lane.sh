#!/usr/bin/env bash
# v8 P1 --lite lane plumbing (7.34.0 debt #2), re-pinned for 9.0 P1: lite
# (plan → execute-bolts) is the ONE pipeline. config.yaml `lane:` →
# state_probes.probe_lane defaults to lite; a retired `lane: standard` is read
# only so derive() can say it is ignored (derived.lane is always lite). One
# script rail: validate-preflight.sh --predictive refuses the execute-bolts hop
# while .plan-coverage-state.json is missing or FAIL — no config key switches it
# off; the only exemption is a migrated layout-2 vault (spec 2026-09-27 §4, §7 #12).
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
[ "$(probe)" = "lite" ] && pass "a: no config key → lane lite (9.0 default: the one pipeline)" || fail "a: default lane wrong: $(probe)"
printf 'spine: express\nlane: lite   # v8\n' > "$T/.mega-sdd/config.yaml"
[ "$(probe)" = "lite" ] && pass "b: config \`lane: lite\` → probe_lane lite (comment tolerated)" || fail "b: lite not read"
printf 'lane: turbo\n' > "$T/.mega-sdd/config.yaml"
[ "$(probe)" = "lite" ] && pass "c: unknown value → lite default (never a third lane)" || fail "c: unknown value leaked: $(probe)"
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
# 9.0: the retired `lane: standard` no longer switches the rail off (pre-9.0 it
# suppressed the check — that standard-lane branch is gone by design, spec §4).
# It is read only to be named as ignored: derived.lane stays lite + one note.
printf 'lane: standard\n' > "$T/.mega-sdd/config.yaml"; rm -f "$T/.mega-sdd/.plan-coverage-state.json"
OUT="$(bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts 2>/dev/null)"; RC=$?
DN=$(python3 -c "
import sys; sys.path.insert(0, '$S/_lib'); import state_probes as sp
d = sp.collect_state('$T').get('derived', {})
print(d.get('lane', 'MISSING'), any('lane: standard is retired' in n for n in d.get('notes', [])))" 2>&1 | tail -1)
echo "$OUT" | grep -q '"check": "lite_plan_coverage_pass", "status": "fatal"' && [ $RC -eq 3 ] && [ "$DN" = "lite True" ] \
  && pass "h: retired lane: standard ignored → rail still fatal (exit 3), derived.lane lite + retired note" || fail "h: lane: standard still gates (rc=$RC, derived=$DN)"
# the ONE exemption (spec §7 #12): a migrated layout-2 vault — classic-born units carry no prd_source
mkdir -p "$V/_meta/archive/layout2"
OUT="$(bash "$S/validate-preflight.sh" --predictive --cwd="$T" --chain=execute-bolts 2>/dev/null)"
! echo "$OUT" | grep -q 'lite_plan_coverage_pass' && pass "h2: migrated layout-2 vault (_meta/archive/layout2/) → rail exempt, no check emitted" || fail "h2: migrated vault not exempt"
rmdir "$V/_meta/archive/layout2"
# prose plumbing
# 9.0 repoint: the config doc's default is `lane: lite` with standard named retired;
# the front door names the retired config key in one line (it no longer reads
# derived.lane — always lite); execute-bolts 3.9 runs the lite lane only.
grep -q '^lane: lite .*`standard` is retired' "$P/references/project-config.md" && grep -q 'lane: standard | lite' "$P/skills/orchestrate-flow/SKILL.md" && grep -q '`lane: standard` (config) — retired in 9.0' "$P/commands/mega-sdd.md" && grep -q 'execute-bolts runs the lite lane only' "$P/skills/execute-bolts/SKILL.md" \
  && pass "i: config doc + orchestrate-flow derived block + front door + execute-bolts 3.9 name the one (lite) lane" || fail "i: prose plumbing incomplete"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
