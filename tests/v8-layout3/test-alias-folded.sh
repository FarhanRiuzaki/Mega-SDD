#!/usr/bin/env bash
# v8 P3 goal item 2 (8.0.0): generate-intent / bind-codebase / generate-units are FOLDED on
# the lite lane / a layout-3 vault — the alias is a predictive-preflight FATAL whose message
# says WHY in one line (owner amendment: a message to the team, not a bare redirect) and
# names the replacement hop; the classic lane on a layout-2 vault is byte-identical.
#   a  lane lite (config) → the three classic skills FATAL with KENAPA + the plan/bolts hop
#   b  `--lite` on the dispatch args alone (no config yet) → same, and plan is NOT off-lane
#   c  classic lane + a layout-3 vault present → bind/units folded (a plan-born vault has no
#      whole-vault binding to write), generate-intent stays free (a second vault is allowed)
#   d  classic lane + layout-2 vault → no alias FATAL (the old preconditions only)
#   e  the hook's predictive-preflight case list carries generate-intent + plan (a gate, not prose)
#   f  the re-keyed sync chain: lane lite + per-unit binding + change signal → rebind-units.sh
#      → plan --reconcile → execute-bolts --all --lite (never bind-codebase / generate-units)
#   g  classic lane + TWO vaults (layout-2 `app` + layout-3 `lite`), no --vault= → bind/units NOT folded
#      (the fold is per target vault, never project-wide — a mixed project keeps its classic vault runnable)
#   h  same project, `--vault=lite` → bind folded; `--vault=app` (and the dir form of lite) resolve per target
# Run: bash tests/v8-layout3/test-alias-folded.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pf() { # $1=dir $2=skill [$3=args]  → "STATUS check_id"
  local b64=""; [ -n "${3:-}" ] && b64="$(printf '%s' "$3" | base64)"
  bash "$S/validate-preflight.sh" --cwd="$1" --skill="mega-sdd:$2" ${b64:+--args-b64="$b64"} --quiet >/dev/null 2>&1
  python3 -c "import json;d=json.load(open('$1/.mega-sdd/.preflight-state.json'));print(d['status'], d.get('fatal_check_id'), (d.get('fatal_on_fail') or ''))"; }
A="$T/a"; mkdir -p "$A/.mega-sdd/vaults/app/units"; ( cd "$A" && git init -q . ); printf 'lane: lite\n' > "$A/.mega-sdd/config.yaml"
R="$(pf "$A" generate-units)"; echo "$R" | grep -q '^FATAL units_folded_into_plan' && echo "$R" | grep -q 'KENAPA' && echo "$R" | grep -q 'plan <prd> --lite' \
  && pass "a1: lane lite → generate-units FATAL units_folded_into_plan, KENAPA + plan hop named" || fail "a1: $R"
R="$(pf "$A" bind-codebase)"; echo "$R" | grep -q '^FATAL bind_folded_into_bolts' && echo "$R" | grep -q 'KENAPA' && echo "$R" | grep -q 'execute-bolts --all --lite' && echo "$R" | grep -q 'rebind-units.sh --units=all' \
  && pass "a2: lane lite → bind-codebase FATAL bind_folded_into_bolts, KENAPA + bolts hop + full-audit script named" || fail "a2: $R"
R="$(pf "$A" generate-intent)"; echo "$R" | grep -q '^FATAL intent_folded_into_plan' && echo "$R" | grep -q 'KENAPA' \
  && pass "a3: lane lite → generate-intent FATAL intent_folded_into_plan with KENAPA" || fail "a3: $R"
R="$(pf "$A" plan)"; echo "$R" | grep -q '^PASS' && pass "a4: lane lite → plan passes the lane check" || fail "a4: $R"
rm -f "$A/.mega-sdd/config.yaml"
R="$(pf "$A" plan '--lite --mode=new')"; echo "$R" | grep -q '^PASS' && pass "b1: --lite on the args, no config → plan NOT off-lane" || fail "b1: $R"
R="$(pf "$A" generate-units '--lite')"; echo "$R" | grep -q '^FATAL units_folded_into_plan' && pass "b2: --lite on the args → generate-units folded" || fail "b2: $R"
R="$(pf "$A" plan)"; echo "$R" | grep -q '^FATAL plan_off_lane' && pass "b3: no lane, no flag → plan_off_lane (unchanged)" || fail "b3: $R"
touch "$A/.mega-sdd/vaults/app/context.md"
R="$(pf "$A" bind-codebase)"; echo "$R" | grep -q '^FATAL bind_folded_into_bolts' && pass "c1: classic lane + layout-3 vault → bind folded" || fail "c1: $R"
R="$(pf "$A" generate-units)"; echo "$R" | grep -q '^FATAL units_folded_into_plan' && pass "c2: classic lane + layout-3 vault → units folded" || fail "c2: $R"
R="$(pf "$A" generate-intent)"; echo "$R" | grep -qv 'intent_folded' && pass "c3: classic lane + layout-3 vault → generate-intent NOT folded (a second vault is allowed)" || fail "c3: $R"
B="$T/b"; mkdir -p "$B/.mega-sdd/vaults/app/units"; ( cd "$B" && git init -q . ); echo "# v" > "$B/.mega-sdd/vaults/app/vault.md"
R="$(pf "$B" bind-codebase)"; echo "$R" | grep -qv 'folded' && pass "d1: classic lane + layout-2 vault → no alias FATAL on bind-codebase ($(echo "$R" | cut -d' ' -f1-2))" || fail "d1: $R"
R="$(pf "$B" generate-units)"; echo "$R" | grep -qv 'folded' && pass "d2: classic lane + layout-2 vault → no alias FATAL on generate-units" || fail "d2: $R"
grep -q 'mega-sdd:bind-codebase|mega-sdd:generate-units|mega-sdd:execute-bolts|mega-sdd:scan-codebase|mega-sdd:generate-intent|mega-sdd:plan)' "$P/hooks/pre-tool-use" \
  && pass "e: hook predictive-preflight case list carries generate-intent + plan" || fail "e: hook case list"
# f — the re-keyed sync chain (state engine): probe_binding.unit_bindings counts per-unit bindings and
#     the lite branch renders rebind-units.sh → plan --reconcile → execute-bolts --all --lite
python3 - "$S/_lib" "$T" <<'PY' && pass "f: probe_binding.unit_bindings counts bolts/U-*/binding.json; lite sync chain = derive-changed-paths → detect-drift → rebind-units.sh → plan --reconcile → execute-bolts --all --lite" || fail "f: state engine re-key"
import sys, os, json, inspect; sys.path.insert(0, sys.argv[1]); import state_probes as sp
v = os.path.join(sys.argv[2], "f", ".mega-sdd", "vaults", "app"); os.makedirs(os.path.join(v, "bolts", "U-001"), exist_ok=True); os.makedirs(os.path.join(v, "bolts", "U-002"), exist_ok=True)
open(os.path.join(v, "bolts", "U-001", "binding.json"), "w").write("{}")
assert sp.probe_binding(v)["unit_bindings"] == 1
src = inspect.getsource(sp)
assert 'binding.get("unit_bindings", 0) > 0' in src and 'scripts/rebind-units.sh --cwd . --vault %s --paths=@%s/.sync-changed-paths.txt' in src and '"plan --reconcile"' in src
i = src.index('if derived["lane"] == "lite" or vault.get("has_context_md"):'); j = src.index('"execute-bolts --all --lite"', i)
assert '"bind-codebase' not in src[i:j] and '"generate-units' not in src[i:j]   # chain ENTRIES only (comments may name them)
PY
# g — pins: one layout-3 vault beside a layout-2 vault must NOT fold the classic phases for the whole project
G="$T/g"; mkdir -p "$G/.mega-sdd/vaults/app/units" "$G/.mega-sdd/vaults/lite/units"; ( cd "$G" && git init -q . )
echo "# v" > "$G/.mega-sdd/vaults/app/vault.md"; touch "$G/.mega-sdd/vaults/lite/context.md"
R="$(pf "$G" bind-codebase)"; echo "$R" | grep -qv 'bind_folded_into_bolts' && pass "g1: classic lane + mixed vaults, no --vault= → bind-codebase NOT folded ($(echo "$R" | cut -d' ' -f1-2))" || fail "g1: $R"
R="$(pf "$G" generate-units)"; echo "$R" | grep -qv 'units_folded_into_plan' && pass "g2: classic lane + mixed vaults, no --vault= → generate-units NOT folded ($(echo "$R" | cut -d' ' -f1-2))" || fail "g2: $R"
# h — pins: `--vault=` on the dispatch args names the target; the fold follows THAT vault's layout
R="$(pf "$G" bind-codebase '--vault=lite')"; echo "$R" | grep -q '^FATAL bind_folded_into_bolts' && pass "h1: --vault=lite (layout-3 by name) → bind folded" || fail "h1: $R"
R="$(pf "$G" bind-codebase '--vault=app')"; echo "$R" | grep -qv 'bind_folded_into_bolts' && pass "h2: --vault=app (layout-2 by name) → bind NOT folded ($(echo "$R" | cut -d' ' -f1-2))" || fail "h2: $R"
R="$(pf "$G" bind-codebase "--vault=$G/.mega-sdd/vaults/lite")"; echo "$R" | grep -q '^FATAL bind_folded_into_bolts' && pass "h3: --vault=<dir> form of the layout-3 vault → bind folded" || fail "h3: $R"
R="$(pf "$G" generate-units '--vault=lite')"; echo "$R" | grep -q '^FATAL units_folded_into_plan' && pass "h4: --vault=lite → generate-units folded" || fail "h4: $R"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
