#!/usr/bin/env bash
# test-evidence-provenance.sh — F-08 / F-26 (spec 2026-08-30 §3.2, §3.4).
# (Was test-t3-panel-evidence.sh; the F-07 panel-evidence legs A/B/C1-2/C5-6/D
# went with --panel-scan and merge-panel-findings.sh in P3 C3.)
#
# Pins the surviving mechanisms:
#   C  run-code-gates.sh --write persists a stamped lens-inputs/U-XXX/l0-results.json
#   E  guards: findings.json / l0-results.json / review-tier.json are denied to
#      Write/Edit and to Bash tamper verbs; the sanctioned run-code-gates.sh passes
#   F  provenance: every writer stamps plugin_version + written_at
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
S="$ROOT/plugins/mega-sdd/scripts"; HOOK="$ROOT/plugins/mega-sdd/hooks/pre-tool-use"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0; ok(){ echo "  ok: $*"; }; bad(){ echo "  FAIL: $*"; err=1; }
VER=$(python3 -c "import json;print(json.load(open('$ROOT/plugins/mega-sdd/.claude-plugin/plugin.json'))['version'])")

repo="$WORK/repo"; V="$repo/.mega-sdd/vaults/v1"
mkdir -p "$V/units" "$repo/src"
( cd "$repo" && git init -q . && echo seed > src/seed.js && git add -A && git -c user.email=t@t -c user.name=t commit -q -m seed )
G(){ git -C "$repo" -c user.email=t@t -c user.name=t "$@"; }
mkunit(){ # uid risk files...
  local uid="$1" risk="$2"; shift 2
  { printf -- '---\nunit_id: %s\ntask_type: create\nrisk: %s\ntarget_files:\n' "$uid" "$risk"
    for f in "$@"; do printf -- '  - path: %s\n    operation: create\n' "$f"; done
    printf -- 'acceptance_test:\n  - type: test\n    command: "true"\n    expects: "ok"\n---\n# %s\n\n## Goal\nx\n\n## Acceptance criteria\n- a\n' "$uid"; } > "$V/units/$uid.md"
}
bolt(){ # uid files...
  local uid="$1"; shift
  for f in "$@"; do echo "$uid" > "$repo/$f"; G add "$f" >/dev/null; done
  G add .mega-sdd >/dev/null
  G commit -q -m "feat($uid): bolt

Unit: $uid" >/dev/null
}
J(){ python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$1" "$2"; }

echo "── fixture: three committed bolts + a suite run ──"
mkunit U-001 critical src/a.js src/b.js src/c.js src/d.js
bolt U-001 src/a.js src/b.js src/c.js src/d.js
mkunit U-002 low src/e.js
bolt U-002 src/e.js
mkunit U-003 low src/f.js
bolt U-003 src/f.js
bash "$S/run-full-suite.sh" --cwd="$repo" --runner="true" --quiet >/dev/null 2>&1 || true

echo "── C: the L0 record is script-written and stamped ──"
HEAD=$(git -C "$repo" rev-parse HEAD)
for u in U-001 U-003; do
  bash "$S/run-code-gates.sh" --cwd="$repo" --base="$HEAD~1" --head="$HEAD" --unit="$V/units/$u.md" --no-code-gates --write >/dev/null 2>&1
done
L0="$V/lens-inputs/U-001/l0-results.json"
[ -f "$L0" ] && [ "$(J "$L0" 'd.get("written_by")')" = "run-code-gates.sh" ] && ok "C3 run-code-gates --write persists lens-inputs/U-001/l0-results.json" || bad "C3 l0-results not written by the gate runner"
[ "$(J "$L0" 'd.get("plugin_version")')" = "$VER" ] && ok "C4 l0 record carries plugin_version" || bad "C4 plugin_version missing on l0"

drive(){ printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }
echo "── E: the three artifacts are guarded ──"
for f in "bolts/U-001/findings.json" "lens-inputs/U-001/l0-results.json" "bolts/U-001/review-tier.json"; do
  OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$V/$f\",\"content\":\"{}\"}}")
  printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' && ok "E: Write of $f denied" || bad "E: Write of $f ALLOWED"
  OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo '{}' > .mega-sdd/vaults/v1/$f\"}}")
  printf '%s' "$OUT" | grep -q '"deny"' && ok "E: Bash redirect into $f denied" || bad "E: Bash redirect into $f ALLOWED"
done
OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash $S/run-code-gates.sh --cwd=$repo --base=$HEAD~1 --head=$HEAD --unit=$V/units/U-001.md --write\"}}")
[ -z "$OUT" ] && ok "E: sanctioned run-code-gates.sh --write passes" || bad "E: run-code-gates blocked: $(printf '%s' "$OUT" | head -c 160)"

echo "── F: provenance on every writer ──"
bash "$S/run-preflight-scan.sh" --cwd="$repo" --unit=U-003 --quiet >/dev/null 2>&1 || true
bash "$S/run-postflight-scan.sh" --cwd="$repo" --unit=U-001 --quiet >/dev/null 2>&1 || true
bash "$S/run-acceptance-tests.sh" --cwd="$repo" --unit=U-001 --quiet >/dev/null 2>&1 || true
for a in "bolts/U-001/postflight.json" "bolts/U-001/acceptance.json" "bolts/_batch-suite.json"; do
  [ -f "$V/$a" ] || { bad "F: $a not written (precondition)"; continue; }
  [ "$(J "$V/$a" 'd.get("plugin_version")')" = "$VER" ] && [ -n "$(J "$V/$a" 'd.get("written_at")')" ] \
    && ok "F: $a stamped plugin_version + written_at" || bad "F: $a lacks provenance: $(J "$V/$a" '(d.get("plugin_version"), d.get("written_at"))')"
done
[ -n "$(J "$V/bolts/U-001/acceptance.json" 'd.get("duration_ms")')" ] && ok "F: acceptance.json carries duration_ms" || bad "F: acceptance duration_ms missing"

echo; [ $err -eq 0 ] && { echo "test-evidence-provenance: ALL PASS"; exit 0; } || { echo "test-evidence-provenance: FAILED"; exit 1; }
