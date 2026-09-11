#!/usr/bin/env bash
# test-lite-2hop.sh — v8 P2 goal item 3: the 2-hop lite lane at the front door.
#   a state engine: lane lite + starterkit + PRD + no vault → `plan <prd> --lite --mode=existing`
#     → `execute-bolts --all --lite`; bare scaffold → --mode=new; no lane → classic chain unchanged
#   b plan-born vault (context.md) with no units under lite → `plan --regenerate` (never generate-units)
#   c predictive preflight: --chain=plan,execute-bolts on an empty lite project = 0 fatal (plan
#     produces vault/units/coverage — chain-aware); --chain=execute-bolts alone under lite stays fatal
#   d --skill=mega-sdd:plan off-lane → fatal plan_off_lane; on-lane → PASS
#   e prose: front door, orchestrate-flow, routing-rules, handoff-consumption, using-mega-sdd
# Run: bash tests/v8-plan/test-lite-2hop.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
rc=0; fail() { echo "FAIL: $1"; rc=1; }; pass() { echo "PASS: $1"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mk() { # $1=dir $2=with-code(1/0)
  mkdir -p "$1/PRD" "$1/.mega-sdd"; ( cd "$1" && git init -q . ); echo '{"name":"app","dependencies":{"next":"16.0.0"}}' > "$1/package.json"
  printf '# PRD\n\n## Latar belakang\n\nx\n\n## Halaman Beranda\n\ny\n' > "$1/PRD/prd.md"
  [ "$2" = 1 ] && { mkdir -p "$1/src"; echo 'export const a = 1;' > "$1/src/index.js"; }
}
chain() { python3 -c "
import sys, json; sys.path.insert(0, '$S/_lib'); import state_probes as sp
d = sp.collect_state('$1')['derived']; print(json.dumps([d['position'], d['proposed_next']]))" 2>/dev/null; }
# a
A="$T/a"; mk "$A" 1
# express (index/ast-grep present) renders `generate-intent PRD/prd.md`; a host without ast-grep (CI)
# renders the classic scan-first spine `generate-intent PRD/prd.md --scan=…` — both are the v7 chain
echo "$(chain "$A")" | grep -q '"generate-intent PRD/prd.md' && ! echo "$(chain "$A")" | grep -q '"plan ' && pass "a: no lane → v7 chain (generate-intent hop, express or classic spine), plan never proposed" || fail "a: classic chain changed: $(chain "$A")"
printf 'lane: lite\n' > "$A/.mega-sdd/config.yaml"
[ "$(chain "$A")" = '["prd_no_vault", ["plan PRD/prd.md --lite --mode=existing", "execute-bolts --all --lite"]]' ] && pass "a: lane lite + code → 2-hop plan --mode=existing → execute-bolts --all --lite" || fail "a: lite chain wrong: $(chain "$A")"
B="$T/b"; mk "$B" 0; printf 'lane: lite\n' > "$B/.mega-sdd/config.yaml"
echo "$(chain "$B")" | grep -q '"plan PRD/prd.md --lite --mode=new"' && pass "a: bare scaffold → --mode=new" || fail "a: scaffold mode wrong: $(chain "$B")"
# b — plan-born vault without units
C="$T/c"; mk "$C" 1; printf 'lane: lite\n' > "$C/.mega-sdd/config.yaml"; mkdir -p "$C/.mega-sdd/vaults/app"
sed 's/\[P1\]/[P2]/g' "$ROOT/tests/v8-layout3/fixtures/context-vault/context.md" > "$C/.mega-sdd/vaults/app/context.md"   # no P1 OQ → the oq_gate position must not outrank
bash "$S/derive-vault-json.sh" --vault="$C/.mega-sdd/vaults/app" </dev/null >/dev/null 2>&1
echo "$(chain "$C")" | grep -q '"lite_context_no_units", \["plan PRD/prd.md --lite --regenerate", "execute-bolts --all --lite"\]' && pass "b: layout-3 vault + 0 units under lite → plan --regenerate (never generate-units)" || fail "b: $(chain "$C")"
rm -f "$C/.mega-sdd/config.yaml"
echo "$(chain "$C")" | grep -q 'generate-units' && pass "b: same vault without the lane → classic ladder unchanged (generate-units)" || fail "b: classic ladder changed: $(chain "$C")"
# c — predictive preflight chain-aware for the 2-hop chain
OUT=$(bash "$S/validate-preflight.sh" --predictive --cwd="$A" --chain=plan,execute-bolts 2>/dev/null); R=$?
echo "$OUT" | grep -q '"status": "fatal"' && fail "c: 2-hop chain start reports a fatal: $(echo "$OUT" | grep fatal | head -2)" || pass "c: --chain=plan,execute-bolts on an empty lite project → 0 fatal (rc=$R)"
echo "$OUT" | grep -q '"check": "lite_plan_coverage_pass", "status": "ok"' && echo "$OUT" | grep -q '"check": "units_directory_present", "status": "ok"' && pass "c: coverage + units checks are chain-aware (produced by plan)" || fail "c: chain-aware checks not ok: $(echo "$OUT" | grep -E 'coverage|units_directory' | head -3)"
bash "$S/validate-preflight.sh" --predictive --cwd="$A" --chain=execute-bolts </dev/null >/dev/null 2>&1; [ $? -eq 3 ] && pass "c: --chain=execute-bolts alone under lite → still fatal (rail intact)" || fail "c: lite rail lost"
# d — plan lane check
OUT=$(bash "$S/validate-preflight.sh" --cwd="$B" --skill=mega-sdd:plan 2>/dev/null); echo "$OUT" | grep -q 'plan_lane_lite' && ! echo "$OUT" | grep -q 'plan_off_lane' && pass "d: plan on the lite lane → PASS" || fail "d: on-lane plan check: $(echo "$OUT" | head -c 200)"
rm -f "$B/.mega-sdd/config.yaml"; OUT=$(bash "$S/validate-preflight.sh" --cwd="$B" --skill=mega-sdd:plan 2>/dev/null); R=$?
echo "$OUT" | grep -q 'plan_off_lane' && [ $R -ne 0 ] && pass "d: plan off-lane → fatal plan_off_lane (rc=$R)" || fail "d: off-lane not fatal (rc=$R): $(echo "$OUT" | head -c 200)"
# e — prose
grep -q 'plan <input> --lite --mode=<existing|new>' "$P/commands/mega-sdd.md" && grep -q 'emits NO handoff YAML' "$P/commands/mega-sdd.md" && pass "e: front door Lane 1 names the 2-hop lite chain + no-handoff rule" || fail "e: front door prose"
grep -q 'P2 2-hop lane' "$P/skills/orchestrate-flow/SKILL.md" && pass "e: orchestrate-flow --lite line names the 2-hop lane" || fail "e: orchestrate-flow prose"
grep -q '^| \*\*Lane lite\*\*' "$P/skills/orchestrate-flow/references/routing-rules.md" && pass "e: routing-rules carries the lane-lite row" || fail "e: routing-rules row"
grep -q '^## Lite lane exemption (v8 P2)' "$P/skills/orchestrate-flow/references/handoff-consumption.md" && pass "e: handoff-consumption documents the plan exemption" || fail "e: handoff-consumption"
grep -q 'Lite lane (`--lite` / config `lane: lite`, v8 P2, opt-in): `plan`' "$P/skills/using-mega-sdd/SKILL.md" && pass "e: router mentions the lite lane" || fail "e: router prose"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
