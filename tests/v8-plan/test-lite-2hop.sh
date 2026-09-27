#!/usr/bin/env bash
# test-lite-2hop.sh — v8 P2 goal item 3: the 2-hop lite lane at the front door.
#   a state engine: lane lite + starterkit + PRD + no vault → `plan <prd> --lite --mode=existing`
#     → `execute-bolts --all --lite`; bare scaffold → --mode=new; 9.0: no lane key / the retired
#     `lane: standard` → the SAME one pipeline (the classic chain is gone; spec 2026-09-27 §2, §4)
#   b plan-born vault (context.md) with no units → `plan --regenerate` (never generate-units), with
#     or without the lane key
#   c predictive preflight: --chain=plan,execute-bolts on an empty lite project = 0 fatal (plan
#     produces vault/units/coverage — chain-aware); --chain=execute-bolts alone under lite stays fatal
#   d --skill=mega-sdd:plan: 9.0 retired the lane gate (plan_off_lane) — plan PASSes with or without
#     the lane key (plan_target_layout); a layout-2 TARGET vault → fatal plan_layout2_vault
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
# 9.0 (spec 2026-09-27 §2): the classic chain (generate-intent → scan → bind → generate-units) is
# removed, so the old "no lane → v7 generate-intent chain" pin is retired. Its surviving contrast:
# with NO lane key the engine proposes the exact same one pipeline, and generate-intent never appears.
LITE2HOP='["prd_no_vault", ["plan PRD/prd.md --lite --mode=existing", "execute-bolts --all --lite"]]'
[ "$(chain "$A")" = "$LITE2HOP" ] && ! echo "$(chain "$A")" | grep -q 'generate-intent' && pass "a: no lane key → the one pipeline (2-hop plan --mode=existing → execute-bolts), generate-intent never proposed" || fail "a: no-lane chain is not the one pipeline: $(chain "$A")"
# §4: the retired `lane: standard` selects no chain — same one pipeline + a one-line "ignored" note
printf 'lane: standard\n' > "$A/.mega-sdd/config.yaml"
NOTES=$(python3 -c "
import sys; sys.path.insert(0, '$S/_lib'); import state_probes as sp
print('\n'.join(sp.collect_state('$A')['derived'].get('notes') or []))" 2>/dev/null)
[ "$(chain "$A")" = "$LITE2HOP" ] && echo "$NOTES" | grep -q 'lane: standard is retired in 9.0 and ignored' && pass "a: retired lane: standard → same one pipeline + one-line ignored note" || fail "a: lane: standard not ignored: $(chain "$A") notes=[$NOTES]"
printf 'lane: lite\n' > "$A/.mega-sdd/config.yaml"
[ "$(chain "$A")" = "$LITE2HOP" ] && pass "a: lane lite + code → 2-hop plan --mode=existing → execute-bolts --all --lite" || fail "a: lite chain wrong: $(chain "$A")"
B="$T/b"; mk "$B" 0; printf 'lane: lite\n' > "$B/.mega-sdd/config.yaml"
echo "$(chain "$B")" | grep -q '"plan PRD/prd.md --lite --mode=new"' && pass "a: bare scaffold → --mode=new" || fail "a: scaffold mode wrong: $(chain "$B")"
# b — plan-born vault without units
C="$T/c"; mk "$C" 1; printf 'lane: lite\n' > "$C/.mega-sdd/config.yaml"; mkdir -p "$C/.mega-sdd/vaults/app"
sed 's/\[P1\]/[P2]/g' "$ROOT/tests/v8-layout3/fixtures/context-vault/context.md" > "$C/.mega-sdd/vaults/app/context.md"   # no P1 OQ → the oq_gate position must not outrank
bash "$S/derive-vault-json.sh" --vault="$C/.mega-sdd/vaults/app" </dev/null >/dev/null 2>&1
echo "$(chain "$C")" | grep -q '"lite_context_no_units", \["plan PRD/prd.md --lite --regenerate", "execute-bolts --all --lite"\]' && pass "b: layout-3 vault + 0 units under lite → plan --regenerate (never generate-units)" || fail "b: $(chain "$C")"
# 9.0: the classic ladder (generate-units) without the lane is retired — the same vault with NO lane
# key must take the same plan --regenerate hop, and generate-units is never proposed.
rm -f "$C/.mega-sdd/config.yaml"
echo "$(chain "$C")" | grep -q '"lite_context_no_units", \["plan PRD/prd.md --lite --regenerate", "execute-bolts --all --lite"\]' && ! echo "$(chain "$C")" | grep -q 'generate-units' && pass "b: same vault without the lane key → the same plan --regenerate (never generate-units)" || fail "b: no-lane ladder is not the one pipeline: $(chain "$C")"
# c — predictive preflight chain-aware for the 2-hop chain
OUT=$(bash "$S/validate-preflight.sh" --predictive --cwd="$A" --chain=plan,execute-bolts 2>/dev/null); R=$?
echo "$OUT" | grep -q '"status": "fatal"' && fail "c: 2-hop chain start reports a fatal: $(echo "$OUT" | grep fatal | head -2)" || pass "c: --chain=plan,execute-bolts on an empty lite project → 0 fatal (rc=$R)"
echo "$OUT" | grep -q '"check": "lite_plan_coverage_pass", "status": "ok"' && echo "$OUT" | grep -q '"check": "units_directory_present", "status": "ok"' && pass "c: coverage + units checks are chain-aware (produced by plan)" || fail "c: chain-aware checks not ok: $(echo "$OUT" | grep -E 'coverage|units_directory' | head -3)"
bash "$S/validate-preflight.sh" --predictive --cwd="$A" --chain=execute-bolts </dev/null >/dev/null 2>&1; [ $? -eq 3 ] && pass "c: --chain=execute-bolts alone under lite → still fatal (rail intact)" || fail "c: lite rail lost"
# d — plan dispatch preflight. 9.0: lite is the one pipeline, so the lane gate (plan_lane_lite /
# plan_off_lane) is retired; plan's dispatch check is now plan_target_layout (plan writes layout-3
# only and refuses a layout-2 TARGET vault — spec §4 migrate-paths --vault-layout=3, §7 #12).
OUT=$(bash "$S/validate-preflight.sh" --cwd="$B" --skill=mega-sdd:plan 2>/dev/null); R=$?
echo "$OUT" | grep -q '"check": "plan_target_layout", "status": "PASS"' && echo "$OUT" | grep -q '^{"status": "PASS"' && [ $R -eq 0 ] && pass "d: plan with lane lite → PASS (plan_target_layout)" || fail "d: lane-lite plan check (rc=$R): $(echo "$OUT" | head -c 300)"
rm -f "$B/.mega-sdd/config.yaml"; OUT=$(bash "$S/validate-preflight.sh" --cwd="$B" --skill=mega-sdd:plan 2>/dev/null); R=$?
echo "$OUT" | grep -q '"check": "plan_target_layout", "status": "PASS"' && ! echo "$OUT" | grep -q 'plan_off_lane' && [ $R -eq 0 ] && pass "d: plan with no lane key → PASS, no plan_off_lane gate (rc=$R)" || fail "d: no-lane plan not PASS (rc=$R): $(echo "$OUT" | head -c 300)"
mkdir -p "$B/.mega-sdd/vaults/old2"; printf '# vault\n' > "$B/.mega-sdd/vaults/old2/vault.md"   # layout-2: vault.md, no context.md
OUT=$(bash "$S/validate-preflight.sh" --cwd="$B" --skill=mega-sdd:plan --args-b64="$(printf 'PRD/prd.md --vault=old2' | base64 | tr -d '\n')" 2>/dev/null); R=$?
echo "$OUT" | grep -q '"fatal_check_id": "plan_layout2_vault"' && echo "$OUT" | grep -q 'migrate-paths --vault-layout=3' && [ $R -eq 1 ] && pass "d: plan into a layout-2 target vault → fatal plan_layout2_vault naming migrate-paths (rc=$R)" || fail "d: layout-2 target not fatal (rc=$R): $(echo "$OUT" | head -c 300)"
# e — prose
grep -q 'plan <input> --lite --mode=<existing|new>' "$P/commands/mega-sdd.md" && grep -q 'emits NO handoff YAML' "$P/commands/mega-sdd.md" && pass "e: front door Lane 1 names the 2-hop lite chain + no-handoff rule" || fail "e: front door prose"
grep -q 'P2 2-hop lane' "$P/skills/orchestrate-flow/SKILL.md" && pass "e: orchestrate-flow --lite line names the 2-hop lane" || fail "e: orchestrate-flow prose"
grep -q '^| \*\*Lane lite\*\*' "$P/skills/orchestrate-flow/references/routing-rules.md" && pass "e: routing-rules carries the lane-lite row" || fail "e: routing-rules row"
grep -q '^## Lite lane exemption' "$P/skills/orchestrate-flow/references/handoff-consumption.md" && pass "e: handoff-consumption documents the plan exemption" || fail "e: handoff-consumption"
# 9.0: the router's separate "Lite lane (…): `plan` … Default lane unchanged." line folded into
# "The pipeline" block — lite IS the pipeline. Same content pinned: plan → execute-bolts with JIT
# bind per unit, and plan writing context.md + units in ONE phase with ONE batched ask.
grep -qF 'plan <prd> (legacy: plan --kb=<kb-dir>) → execute-bolts --all (JIT bind per unit)' "$P/skills/using-mega-sdd/SKILL.md" && grep -qF '`plan` writes `context.md` + units in one phase, with ONE batched ask at the end' "$P/skills/using-mega-sdd/SKILL.md" && ! grep -q 'Default lane unchanged' "$P/skills/using-mega-sdd/SKILL.md" && pass "e: router names plan → execute-bolts as the one pipeline" || fail "e: router prose"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
