#!/usr/bin/env bash
# v8 P3 (8.0.0) — the lite-lane / layout-3 Mode D sync chain, FIXTURE-DRIVEN (not source
# inspection): the state engine on a plan-born project (context.md + per-unit bindings, no
# codebase-map, no binding.md, symbol index as the freshness substrate) must reach
# maintenance_sync on both change channels and render the re-keyed chain
#   derive-changed-paths.sh → detect-drift --scope=@ → rebind-units.sh --paths=@ → plan --reconcile
#   → execute-bolts --all --lite
# and the scripted hops of that chain must actually run on the fixture = scenario-12 replayed on
# the lite lane (tests/scenarios/scenario-12-continuous-sync.md, "Lite lane" section).
#   a  git channel (HEAD moved past the index stamp) → maintenance_sync + the 5-hop lite chain,
#      never bind-codebase / generate-units
#   b  hop 1 + hop 3 replayed: derive-changed-paths.sh writes .sync-changed-paths.txt with the
#      touched target; rebind-units.sh --paths=@ re-binds ONLY the affected unit (exit 4, gate PASS)
#   c  journal channel (dirty rows, stamp == HEAD) → the same chain
#   d  classic control: layout-2 vault + binding.md + no lane key → the classic chain is byte-for-byte
#      what it was (bind-codebase --paths=@ … --express → generate-units --reconcile → execute-bolts)
#   e  context.md WITHOUT `lane: lite` (plan-born vault, classic session) → still the lite chain
#      (the vault layout decides, not the flag)
#   f  stamp refreshed to HEAD + journal consumed → NOT maintenance_sync (no vacuous re-run — the
#      scenario-12 "re-run → in sync" pass criterion)
# Run: bash tests/v8-layout3/test-state-sync-lite.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
J() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$1/.mega-sdd/state.json" "$2" 2>/dev/null; }
ds() { bash "$S/derive-state.sh" --cwd="$1" </dev/null >/dev/null 2>&1; }
idx() { printf '{"generated_by":"build-symbol-index.sh","head_commit":"%s","symbols":[]}\n' "$(git -C "$1" rev-parse HEAD)" > "$1/.mega-sdd/codebase/symbol-index.json"; }
unit() { # dir id path
  printf -- '---\nid: %s\ntitle: t\ntask_type: extend\nvault_source: context.md#flows\ntarget_files:\n  - path: %s\n    operation: modify\nacceptance_test:\n  - type: test\n    command: x\n    expects: "ok"\n---\n# u\n\n## Anchors\n- %s:1 — x\n' "$2" "$3" "$3" > "$1/.mega-sdd/vaults/app/units/$2.md"; }
lite_fixture() { # $1=dir  $2=with-lane-key (1/0)
  local F="$1" V="$1/.mega-sdd/vaults/app"
  mkdir -p "$F/src/a" "$F/.mega-sdd/codebase" "$V/units" "$V/bolts/U-001"
  printf 'export const one = 1;\n' > "$F/src/a/one.ts"; printf '{"name":"x"}\n' > "$F/package.json"
  [ "$2" = 1 ] && printf 'lane: lite\n' > "$F/.mega-sdd/config.yaml"
  printf -- '---\ndoc_id: context\ntype: context\nvault_layout: 3\nmode: new\n---\n# app\n\n## Overview\n\nx\n\n## Flows\n\ny\n' > "$V/context.md"
  printf '{"vault_version":"1.0","mode":"new","open_questions":[]}\n' > "$V/vault.json"
  unit "$F" U-001 src/a/one.ts; unit "$F" U-002 src/a/two.ts
  printf '{"schema":"unit-binding/1","unit":"U-001","claims":[]}\n' > "$V/bolts/U-001/binding.json"
  ( cd "$F" && git init -q . && G "$F" add -A && G "$F" commit -qm base ) >/dev/null 2>&1
  idx "$F"
}

# a — git channel on the lite lane
A="$T/a"; lite_fixture "$A" 1
printf 'export const one = 2;\n' > "$A/src/a/one.ts"; G "$A" commit -qam "hotfix out of band" >/dev/null
ds "$A"
POS="$(J "$A" "d['derived']['position']")"; LANE="$(J "$A" "d['derived']['lane']")"; SIG="$(J "$A" "d['derived']['change_signal']['index_stamp_matches_head']")"
CHAIN="$(J "$A" "chr(10).join(d['derived']['proposed_next'])")"
[ "$POS" = maintenance_sync ] && [ "$LANE" = lite ] && [ "$SIG" = no ] \
  && pass "a1: lite + context.md + per-unit binding, HEAD past the index stamp → position=maintenance_sync (lane=lite, index_stamp_matches_head=no)" \
  || fail "a1: pos=$POS lane=$LANE sig=$SIG"
H1="$(echo "$CHAIN" | sed -n 1p)"; H2="$(echo "$CHAIN" | sed -n 2p)"; H3="$(echo "$CHAIN" | sed -n 3p)"; H4="$(echo "$CHAIN" | sed -n 4p)"; H5="$(echo "$CHAIN" | sed -n 5p)"
case "$H1" in "scripts/derive-changed-paths.sh --vault "*) : ;; *) fail "a2: hop1 '$H1'";; esac
case "$H2" in "detect-drift --scope=@"*/.sync-changed-paths.txt) : ;; *) fail "a2: hop2 '$H2'";; esac
case "$H3" in "scripts/rebind-units.sh --cwd . --vault "*" --paths=@"*/.sync-changed-paths.txt) : ;; *) fail "a2: hop3 '$H3'";; esac
[ "$H4" = "plan --reconcile" ] || fail "a2: hop4 '$H4'"
[ "$H5" = "execute-bolts --all --lite" ] || fail "a2: hop5 '$H5'"
[ "$(echo "$CHAIN" | wc -l | tr -d ' ')" = 5 ] && ! echo "$CHAIN" | grep -q 'bind-codebase\|generate-units' \
  && pass "a2: 5-hop lite chain = derive-changed-paths.sh → detect-drift --scope=@ → rebind-units.sh --paths=@ → plan --reconcile → execute-bolts --all --lite (no bind-codebase / generate-units)" \
  || fail "a2: chain = $(echo "$CHAIN" | tr '\n' '|')"

# b — replay hop 1 + hop 3 on the fixture (scenario-12 Act 3 on the lite lane)
VP="${H1##* }"; VABS="$A/$VP"; [ -d "$VABS" ] || VABS="$VP"   # the vault path exactly as hop 1 renders it (cwd-relative)
( cd "$A" && bash "$S/derive-changed-paths.sh" --cwd="$A" --vault="$VABS" >/dev/null 2>&1 ); RC=$?
[ $RC -eq 0 ] && grep -qx 'src/a/one.ts' "$VABS/.sync-changed-paths.txt" \
  && pass "b1: hop 1 derive-changed-paths.sh (rc=0) wrote .sync-changed-paths.txt with the out-of-band file" \
  || fail "b1: rc=$RC set=$(cat "$VABS/.sync-changed-paths.txt" 2>/dev/null | tr '\n' ',')"
OUT="$(bash "$S/rebind-units.sh" --cwd="$A" --vault="$VABS" --paths=@"$VABS/.sync-changed-paths.txt" 2>&1)"; RC=$?
AFF="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["affected"], d["gate"])' "$OUT" 2>/dev/null)"
# 8.8.0 state anchor (spec 2026-09-25 §9, D22): the hotfix rewrote the ANCHORED line
# (src/a/one.ts:1) and no own-commit trail or label token explains it, so the re-bind now
# reports that drift honestly as a CONFLICT for a human (until 8.7.x it passed on range-fit
# alone). The claim-scoping this case pins is unchanged: ONLY U-001 is re-bound.
DRIFT="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(any(c["verdict"]=="CONFLICT" and "anchor_content_drift" in (c.get("evidence") or "") for c in d["claims"]))' "$VABS/bolts/U-001/binding.json" 2>/dev/null)"
[ $RC -eq 4 ] && [ "$AFF" = "['U-001'] FAIL" ] && [ "$DRIFT" = True ] && [ ! -e "$VABS/bolts/U-002/binding.json" ] \
  && pass "b2: hop 3 rebind-units.sh --paths=@ → exit 4, ONLY U-001 re-bound; its drifted anchor is a CONFLICT (D22), U-002 untouched (claim-scoped, not a full re-bind)" \
  || fail "b2: rc=$RC aff=$AFF drift=$DRIFT out=${OUT:0:200}"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("unit")=="U-001" and isinstance(d.get("claims"), list) and len(d["claims"])>0' "$VABS/bolts/U-001/binding.json" 2>/dev/null \
  && pass "b3: bolts/U-001/binding.json rewritten by the sanctioned JIT writer (claims present)" || fail "b3: binding.json content"

# c — journal channel (stamp == HEAD, dirty rows)
C="$T/c"; lite_fixture "$C" 1
printf '{"p":"src/a/one.ts"}\n{"p":"src/a/two.ts"}\n' > "$C/.mega-sdd/codebase/.dirty-paths.jsonl"
ds "$C"
POS="$(J "$C" "d['derived']['position']")"; ROWS="$(J "$C" "d['derived']['change_signal']['dirty_journal_rows']")"; H3="$(J "$C" "d['derived']['proposed_next'][2]")"
[ "$POS" = maintenance_sync ] && [ "$ROWS" = 2 ] && case "$H3" in "scripts/rebind-units.sh "*) true;; *) false;; esac \
  && pass "c: journal channel (2 rows, stamp == HEAD) → maintenance_sync with the rebind-units.sh hop" || fail "c: pos=$POS rows=$ROWS hop3=$H3"

# d — classic control: layout-2 + binding.md + no lane key → the classic chain unchanged
D="$T/d"; mkdir -p "$D/src/a" "$D/.mega-sdd/codebase" "$D/.mega-sdd/vaults/app/units"
printf 'export const one = 1;\n' > "$D/src/a/one.ts"; printf '{"name":"x"}\n' > "$D/package.json"
for n in 00-index 01-goals 02-architecture 03-data-model 04-flows 05-decisions 06-constraints; do printf '# %s\n' "$n" > "$D/.mega-sdd/vaults/app/$n.md"; done
printf '{"vault_version":"1.0","mode":"existing","open_questions":[]}\n' > "$D/.mega-sdd/vaults/app/vault.json"
printf -- '---\nid: U-001\n---\n' > "$D/.mega-sdd/vaults/app/units/U-001.md"
printf '# binding\n\n## Implementation State Map (0 — ALWAYS 6 columns)\n| Claim ID | Verdict | State | Anchor | Confidence | Field diff |\n|---|---|---|---|---|---|\n## Conflicts (0) — BLOCKING\n' > "$D/.mega-sdd/vaults/app/binding.md"
( cd "$D" && git init -q . && G "$D" add -A && G "$D" commit -qm base ) >/dev/null 2>&1; idx "$D"
printf 'export const one = 2;\n' > "$D/src/a/one.ts"; G "$D" commit -qam hotfix >/dev/null
ds "$D"
POS="$(J "$D" "d['derived']['position']")"; CHAIN="$(J "$D" "chr(10).join(d['derived']['proposed_next'])")"
[ "$POS" = maintenance_sync ] && echo "$CHAIN" | sed -n 3p | grep -q '^bind-codebase --paths=@.*--express$' && [ "$(echo "$CHAIN" | sed -n 4p)" = "generate-units --reconcile" ] && [ "$(echo "$CHAIN" | sed -n 5p)" = "execute-bolts" ] && ! echo "$CHAIN" | grep -q 'rebind-units\|plan --reconcile' \
  && pass "d: classic control (layout-2 + binding.md, no lane key) → bind-codebase --paths=@ --express → generate-units --reconcile → execute-bolts (unchanged)" \
  || fail "d: pos=$POS chain=$(echo "$CHAIN" | tr '\n' '|')"

# e — context.md without the lane key → the vault layout decides
E="$T/e"; lite_fixture "$E" 0
printf 'export const one = 2;\n' > "$E/src/a/one.ts"; G "$E" commit -qam hotfix >/dev/null
ds "$E"
POS="$(J "$E" "d['derived']['position']")"; LANE="$(J "$E" "d['derived']['lane']")"; H3="$(J "$E" "d['derived']['proposed_next'][2]")"; H4="$(J "$E" "d['derived']['proposed_next'][3]")"
[ "$POS" = maintenance_sync ] && [ "$LANE" != lite ] && case "$H3" in "scripts/rebind-units.sh "*) true;; *) false;; esac && [ "$H4" = "plan --reconcile" ] \
  && pass "e: layout-3 vault in a classic-lane session (lane=$LANE) → still rebind-units.sh → plan --reconcile (the layout decides, never bind-codebase on a per-unit-bound vault)" \
  || fail "e: pos=$POS lane=$LANE hop3=$H3 hop4=$H4"

# f — stamp refreshed + journal consumed → no vacuous re-run
idx "$A"; rm -f "$A/.mega-sdd/codebase/.dirty-paths.jsonl"
ds "$A"
POS="$(J "$A" "d['derived']['position']")"; SIG="$(J "$A" "d['derived']['change_signal']['index_stamp_matches_head']")"
[ "$POS" != maintenance_sync ] && [ "$SIG" = yes ] \
  && pass "f: index stamp == HEAD and no journal → position=$POS (not maintenance_sync: re-running sync stops at 'in sync')" \
  || fail "f: pos=$POS sig=$SIG"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
