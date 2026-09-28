#!/usr/bin/env bash
# 9.0 P1 (spec docs/superpowers/specs/2026-09-27-v9-simplification-design.md §2/§3/§4/§7):
# generate-intent / bind-codebase / generate-units / scan-codebase are REMOVED and lite
# (plan → execute-bolts) is the one pipeline. The 8.x lane-conditional fold aliases
# (intent_folded_into_plan / bind_folded_into_bolts / units_folded_into_plan), plan_off_lane
# and the classic lane they guarded are retired. What this file still pins:
#   a  a dispatch of a removed skill is a preflight FATAL `skill_removed_in_9` whose one-line
#      message says WHY (removed in 9.0 — a message to the team, not a bare redirect) and names
#      the replacement hop; the removal is never lane- or layout-conditional (lite config,
#      `--lite` args, a retired `lane: standard`, layout-3 vault, layout-2 vault all FATAL)
#   b  plan passes preflight on every lane input (lite config, `--lite` args, no lane, a retired
#      `lane: standard`) — lite is the one pipeline, there is no off-lane plan
#   e  the hook's predictive-preflight case list is exactly execute-bolts|plan (a gate, not prose)
#   f  the sync chain (state engine): per-unit binding + change signal on a layout-3 vault →
#      derive-changed-paths → detect-drift → rebind-units.sh → plan --reconcile →
#      execute-bolts --all --lite (never bind-codebase / generate-units)
#   g  plan's layout-2 refusal (plan_layout2_vault) on a MIXED project (layout-2 `app` +
#      layout-3 `lite`) with no target named → NOT fatal (per target vault, never project-wide)
#   h  same project: `--vault=<name|dir>` or the <prd> positional's slug names the target and the
#      refusal follows THAT vault's layout; a migrated vault (context.md) stays open (§7 #12)
# (Retired with the classic lane: the 8.x fold pins a–d/g/h on bind-codebase / generate-units /
#  generate-intent and b3 `plan_off_lane` — they pinned lane-conditional behaviour of removed skills.)
# Run: bash tests/v8-layout3/test-alias-folded.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pf() { # $1=dir $2=skill [$3=args]  → "STATUS check_id on_fail"
  local b64=""; [ -n "${3:-}" ] && b64="$(printf '%s' "$3" | base64)"
  rm -f "$1/.mega-sdd/.preflight-state.json"
  bash "$S/validate-preflight.sh" --cwd="$1" --skill="mega-sdd:$2" ${b64:+--args-b64="$b64"} --quiet >/dev/null 2>&1
  python3 -c "import json;d=json.load(open('$1/.mega-sdd/.preflight-state.json'));print(d['status'], d.get('fatal_check_id'), (d.get('fatal_on_fail') or ''))" 2>/dev/null || echo "NO_STATE"; }
# ── a: removed skills FATAL with WHY + the replacement hop ───────────────────────────────────
A="$T/a"; mkdir -p "$A/.mega-sdd/vaults/app/units"; ( cd "$A" && git init -q . ); printf 'lane: lite\n' > "$A/.mega-sdd/config.yaml"
R="$(pf "$A" generate-units)"; echo "$R" | grep -q '^FATAL skill_removed_in_9 ' && echo "$R" | grep -q 'generate-units was removed in 9.0' && echo "$R" | grep -q 'plan <prd> --regenerate' && echo "$R" | grep -q 'plan --reconcile' \
  && pass "a1: generate-units → FATAL skill_removed_in_9, WHY (removed in 9.0) + plan --regenerate / --reconcile hop named" || fail "a1: $R"
R="$(pf "$A" bind-codebase)"; echo "$R" | grep -q '^FATAL skill_removed_in_9 ' && echo "$R" | grep -q 'bind-codebase was removed in 9.0' && echo "$R" | grep -q 'execute-bolts --all --lite' && echo "$R" | grep -q 'binds each unit before building it' && echo "$R" | grep -q 'rebind-units.sh --units=all' \
  && pass "a2: bind-codebase → FATAL skill_removed_in_9, WHY + bolts JIT-bind hop + full-audit script named" || fail "a2: $R"
R="$(pf "$A" generate-intent)"; echo "$R" | grep -q '^FATAL skill_removed_in_9 ' && echo "$R" | grep -q 'generate-intent was removed in 9.0' && echo "$R" | grep -q 'plan <prd> --lite' && echo "$R" | grep -q 'plan --kb=<kb-dir>' \
  && pass "a3: generate-intent → FATAL skill_removed_in_9, WHY + plan <prd> / plan --kb hop named" || fail "a3: $R"
R="$(pf "$A" scan-codebase)"; echo "$R" | grep -q '^FATAL skill_removed_in_9 ' && echo "$R" | grep -q 'scan-codebase was removed in 9.0' && echo "$R" | grep -q 'scripts/ground.sh' \
  && pass "a4: scan-codebase → FATAL skill_removed_in_9, WHY + GROUND hop named" || fail "a4: $R"
# a5 — the removal is unconditional: every lane input and vault layout that used to decide the 8.x fold
a5=0; a5_why=""
chk5() { # $1=label $2=dir [$3=args]
  local s r; for s in generate-intent bind-codebase generate-units; do
    r="$(pf "$2" "$s" "${3:-}")"; echo "$r" | grep -q '^FATAL skill_removed_in_9 ' || { a5=1; a5_why="$a5_why [$1/$s: $r]"; }
  done; }
rm -f "$A/.mega-sdd/config.yaml"; chk5 "no-config+--lite" "$A" '--lite'
printf 'lane: standard\n' > "$A/.mega-sdd/config.yaml"; chk5 "lane-standard" "$A"; rm -f "$A/.mega-sdd/config.yaml"
touch "$A/.mega-sdd/vaults/app/context.md"; chk5 "layout-3-vault" "$A"; chk5 "layout-3-vault+--vault" "$A" '--vault=app'
B="$T/b"; mkdir -p "$B/.mega-sdd/vaults/app/units"; ( cd "$B" && git init -q . ); echo "# v" > "$B/.mega-sdd/vaults/app/vault.md"
chk5 "layout-2-vault" "$B"; chk5 "layout-2-vault+--vault" "$B" '--vault=app'
[ $a5 -eq 0 ] && pass "a5: removal is never lane/layout-conditional (no config+--lite, lane: standard, layout-3, layout-2, ±--vault= all FATAL skill_removed_in_9)" || fail "a5:$a5_why"
# ── b: plan is never off-lane ───────────────────────────────────────────────────────────────
Bp="$T/bp"; mkdir -p "$Bp/.mega-sdd/vaults/app/units"; ( cd "$Bp" && git init -q . )
printf 'lane: lite\n' > "$Bp/.mega-sdd/config.yaml"
R="$(pf "$Bp" plan)"; echo "$R" | grep -q '^PASS' && pass "b1: lane lite config → plan passes preflight" || fail "b1: $R"
rm -f "$Bp/.mega-sdd/config.yaml"
R="$(pf "$Bp" plan '--lite --mode=new')"; echo "$R" | grep -q '^PASS' && pass "b2: --lite on the args, no config → plan passes preflight" || fail "b2: $R"
R="$(pf "$Bp" plan)"; echo "$R" | grep -q '^PASS' && pass "b3: no lane, no flag → plan passes preflight (plan_off_lane retired in 9.0)" || fail "b3: $R"
printf 'lane: standard\n' > "$Bp/.mega-sdd/config.yaml"
R="$(pf "$Bp" plan)"; echo "$R" | grep -q '^PASS' && pass "b4: retired lane: standard in config → plan still passes (spec §4: no longer selects a chain)" || fail "b4: $R"
# ── e: the hook gate arm ────────────────────────────────────────────────────────────────────
grep -qE '^[[:space:]]+mega-sdd:execute-bolts\|mega-sdd:plan\)[[:space:]]*$' "$P/hooks/pre-tool-use" \
  && ! grep -qE 'mega-sdd:(bind-codebase|generate-units|scan-codebase|generate-intent)\|mega-sdd:(execute-bolts|plan)' "$P/hooks/pre-tool-use" \
  && pass "e: hook predictive-preflight case list is exactly execute-bolts|plan (no removed skill in the arm)" || fail "e: hook case list"
# ── f: the re-keyed sync chain (state engine) ───────────────────────────────────────────────
# probe_binding.unit_bindings counts per-unit bindings; the maintenance_sync branch (layout-3 only —
# a layout-2 vault routes to needs_migration first) renders the 5-hop lite chain in order.
python3 - "$S/_lib" "$T" <<'PY' && pass "f: probe_binding.unit_bindings counts bolts/U-*/binding.json; sync chain = derive-changed-paths → detect-drift → rebind-units.sh → plan --reconcile → execute-bolts --all --lite" || fail "f: state engine re-key"
import sys, os, inspect; sys.path.insert(0, sys.argv[1]); import state_probes as sp
v = os.path.join(sys.argv[2], "f", ".mega-sdd", "vaults", "app"); os.makedirs(os.path.join(v, "bolts", "U-001"), exist_ok=True); os.makedirs(os.path.join(v, "bolts", "U-002"), exist_ok=True)
open(os.path.join(v, "bolts", "U-001", "binding.json"), "w").write("{}")
assert sp.probe_binding(v)["unit_bindings"] == 1
src = inspect.getsource(sp)
assert 'binding.get("unit_bindings", 0) > 0' in src
i = src.index('return finish("maintenance_sync", ['); j = src.index('])', i); block = src[i:j]
# the gate before the chain: a layout-2 vault never reaches the lite sync chain (it migrates first)
k = src.index('binding.get("unit_bindings", 0) > 0'); g = src.rindex('if not vault.get("has_context_md"):', 0, i)
seg = src[g:i]; assert k < g and 'return needs_migration()' in seg and seg.count('return ') == 1, seg
hops = ['"scripts/derive-changed-paths.sh --vault %s"', '"detect-drift --scope=@%s/.sync-changed-paths.txt"',
        # rebind-units.sh parses only the `--cwd=` / `--vault=` forms (its usage line) — the hop must use them
        '"scripts/rebind-units.sh --cwd=. --vault=%s --paths=@%s/.sync-changed-paths.txt"',
        '"plan --reconcile"', '"execute-bolts --all --lite"']
pos = [block.index(h) for h in hops]; assert pos == sorted(pos), pos
assert '"bind-codebase' not in block and '"generate-units' not in block
PY
# ── g/h: plan's layout-2 refusal is per TARGET vault, never project-wide ────────────────────
G="$T/g"; mkdir -p "$G/.mega-sdd/vaults/app/units" "$G/.mega-sdd/vaults/lite/units"; ( cd "$G" && git init -q . )
echo "# v" > "$G/.mega-sdd/vaults/app/vault.md"; touch "$G/.mega-sdd/vaults/lite/context.md"
R="$(pf "$G" plan)"; echo "$R" | grep -q '^PASS' && pass "g1: mixed vaults, no target named → plan NOT refused (never project-wide)" || fail "g1: $R"
R="$(pf "$G" plan '--kb=kb')"; echo "$R" | grep -q '^PASS' && pass "g2: mixed vaults, plan --kb (no resolvable target) → NOT refused" || fail "g2: $R"
R="$(pf "$G" plan '--vault=app')"; echo "$R" | grep -q '^FATAL plan_layout2_vault ' && echo "$R" | grep -q 'migrate-paths --vault-layout=3 --vault=.mega-sdd/vaults/app' \
  && pass "h1: --vault=app (layout-2 by name) → FATAL plan_layout2_vault naming the migrate-paths hop" || fail "h1: $R"
R="$(pf "$G" plan '--vault=lite')"; echo "$R" | grep -q '^PASS' && pass "h2: --vault=lite (layout-3 by name) → plan NOT refused" || fail "h2: $R"
R="$(pf "$G" plan "--vault=$G/.mega-sdd/vaults/app")"; echo "$R" | grep -q '^FATAL plan_layout2_vault ' && pass "h3: --vault=<dir> form of the layout-2 vault → refused" || fail "h3: $R"
echo '# prd' > "$G/prd-app.md"; echo '# prd' > "$G/PRD_Lite.md"
R="$(pf "$G" plan 'prd-app.md --lite')"; echo "$R" | grep -q '^FATAL plan_layout2_vault ' && pass "h4: <prd> positional slug → vaults/app (layout-2) → refused" || fail "h4: $R"
R="$(pf "$G" plan 'PRD_Lite.md')"; echo "$R" | grep -q '^PASS' && pass "h5: <prd> positional slug → vaults/lite (layout-3) → NOT refused" || fail "h5: $R"
touch "$G/.mega-sdd/vaults/app/context.md"
R="$(pf "$G" plan '--vault=app --regenerate')"; echo "$R" | grep -q '^PASS' && pass "h6: migrated vault (layout-2 docs + context.md) → plan --regenerate open (spec §7 #12)" || fail "h6: $R"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
