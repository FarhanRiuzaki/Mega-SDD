#!/usr/bin/env bash
# test-t3-panel-evidence.sh — F-07 / F-08 / F-26 (spec 2026-08-30 §3.1, §3.2, §3.4).
#
# Field measurement: the panel + the L0 gates caught EVERY real high-class
# defect of the run, yet the panel left a trace on ≤17/36 units and L0 on 7/36,
# `merge-panel-findings.sh` ("the SOLE writer") wrote zero ledgers (3 were
# hand-written), and no artifact carried the plugin version that produced it.
# "Mandatory" was prose. This pins the mechanisms:
#   A  resolve-review-tier.sh --write persists <vault>/bolts/U-XXX/review-tier.json
#      (tier, lenses, plugin_version) — the OBLIGATION KEY (B4 precedent: keyed
#      at dispatch so legacy bolts never retro-block)
#   B  --panel-scan: a keyed, committed, non-minimal bolt with no
#      merge-panel-findings.sh ledger → panel_evidence_missing; with no
#      run-code-gates.sh l0-results.json → l0_evidence_missing; a keyed
#      MINIMAL bolt owes L0 only; an UNKEYED (legacy) bolt is advisory only
#   C  evidence written by the sanctioned writers clears both
#   D  the aggregator blocks execute-bolts on the state (and the in-run gate
#      drops the dispatched in-flight unit)
#   E  guards: findings.json / l0-results.json / review-tier.json are denied to
#      Write/Edit and to Bash tamper verbs; the sanctioned writer commands pass
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

echo "── A: review-tier.json is written at dispatch ──"
mkunit U-001 critical src/a.js src/b.js src/c.js src/d.js
OUT=$(bash "$S/resolve-review-tier.sh" --unit="$V/units/U-001.md" --write 2>&1); rc=$?
RT="$V/bolts/U-001/review-tier.json"
[ $rc -eq 0 ] && [ -f "$RT" ] && ok "A1 --write persists bolts/U-001/review-tier.json" || bad "A1 rc=$rc: $OUT"
[ "$(J "$RT" 'd["tier"]')" = "full" ] && ok "A2 tier recorded (full for risk: critical)" || bad "A2 tier=$(J "$RT" 'd["tier"]')"
[ "$(J "$RT" 'd["plugin_version"]')" = "$VER" ] && ok "A3 plugin_version stamped ($VER)" || bad "A3 plugin_version=$(J "$RT" 'd.get("plugin_version")')"
echo "$OUT" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read().strip().splitlines()[-1]); assert d["tier"]=="full"' && ok "A4 stdout JSON verdict unchanged" || bad "A4 stdout changed: $OUT"

echo "── B: obligations keyed on review-tier.json ──"
bolt U-001 src/a.js src/b.js src/c.js src/d.js
mkunit U-002 low src/e.js                      # legacy-shaped: NO review-tier.json
bolt U-002 src/e.js
bash "$S/validate-bolt-artifacts.sh" --cwd="$repo" --panel-scan >"$WORK/b.out" 2>&1; rc=$?
ST="$repo/.mega-sdd/.bolt-panel-state.json"
[ $rc -eq 1 ] && [ -f "$ST" ] && ok "B1 panel-scan FAILS with a keyed bolt lacking evidence" || bad "B1 rc=$rc $(head -c 200 "$WORK/b.out")"
[ "$(J "$ST" 'sorted(i["halt_type"] for i in d["issues"] if i["unit_id"]=="U-001")')" = "['l0_evidence_missing', 'panel_evidence_missing']" ] \
  && ok "B2 U-001 owes BOTH the panel ledger and the L0 record" || bad "B2 U-001 issues: $(J "$ST" 'd["issues"]')"
[ "$(J "$ST" '[i for i in d["issues"] if i["unit_id"]=="U-002"]')" = "[]" ] && ok "B3 unkeyed U-002 never blocks" || bad "B3 legacy U-002 flagged"
[ "$(J "$ST" 'd["legacy_advisory"]')" = "['U-002']" ] && ok "B4 ...but is named in legacy_advisory" || bad "B4 advisory=$(J "$ST" 'd.get("legacy_advisory")')"
# a keyed MINIMAL bolt owes L0 only
mkunit U-003 low src/f.js
bash "$S/resolve-review-tier.sh" --unit="$V/units/U-003.md" --write >/dev/null 2>&1
[ "$(J "$V/bolts/U-003/review-tier.json" 'd["tier"]')" = "minimal" ] || bad "B5 precondition: U-003 not minimal"
bolt U-003 src/f.js
bash "$S/validate-bolt-artifacts.sh" --cwd="$repo" --panel-scan >/dev/null 2>&1
[ "$(J "$ST" 'sorted(i["halt_type"] for i in d["issues"] if i["unit_id"]=="U-003")')" = "['l0_evidence_missing']" ] \
  && ok "B5 minimal tier owes L0 only (no panel ledger required)" || bad "B5 U-003 issues: $(J "$ST" '[i for i in d["issues"] if i["unit_id"]=="U-003"]')"

echo "── C: sanctioned writers clear the obligations ──"
HEAD=$(git -C "$repo" rev-parse HEAD)
cat > "$WORK/spec.txt" <<'EOF'
FINDINGS:
minor | src/a.js:1 | nit | style
VERDICT: pass
EOF
bash "$S/merge-panel-findings.sh" --vault="$V" --unit=U-001 --head="$HEAD" --round=1 --spec-verdict=pass --lens=spec:"$WORK/spec.txt" >/dev/null 2>&1
FJ="$V/bolts/U-001/findings.json"
[ "$(J "$FJ" 'd.get("written_by")')" = "merge-panel-findings.sh" ] && ok "C1 ledger carries written_by" || bad "C1 written_by=$(J "$FJ" 'd.get("written_by")')"
[ "$(J "$FJ" 'd.get("plugin_version")')" = "$VER" ] && ok "C2 ledger carries plugin_version" || bad "C2 plugin_version missing"
for u in U-001 U-003; do
  bash "$S/run-code-gates.sh" --cwd="$repo" --base="$HEAD~1" --head="$HEAD" --unit="$V/units/$u.md" --no-code-gates --write >/dev/null 2>&1
done
L0="$V/lens-inputs/U-001/l0-results.json"
[ -f "$L0" ] && [ "$(J "$L0" 'd.get("written_by")')" = "run-code-gates.sh" ] && ok "C3 run-code-gates --write persists lens-inputs/U-001/l0-results.json" || bad "C3 l0-results not written by the gate runner"
[ "$(J "$L0" 'd.get("plugin_version")')" = "$VER" ] && ok "C4 l0 record carries plugin_version" || bad "C4 plugin_version missing on l0"
bash "$S/validate-bolt-artifacts.sh" --cwd="$repo" --panel-scan >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] && [ "$(J "$ST" 'd["status"]')" = "PASS" ] && ok "C5 panel-scan PASS once both records exist" || bad "C5 rc=$rc issues=$(J "$ST" 'd["issues"]')"
# a HAND-WRITTEN ledger is not evidence
python3 -c "import json;json.dump({'schema':1,'unit':'U-001','attempt':1,'findings':[]},open('$FJ','w'))"
bash "$S/validate-bolt-artifacts.sh" --cwd="$repo" --panel-scan >/dev/null 2>&1; rc=$?
[ $rc -eq 1 ] && ok "C6 a ledger without the writer stamp is NOT evidence (forged/hand-written)" || bad "C6 hand-written ledger accepted"
bash "$S/merge-panel-findings.sh" --vault="$V" --unit=U-001 --head="$HEAD" --round=1 --spec-verdict=pass --lens=spec:"$WORK/spec.txt" >/dev/null 2>&1

echo "── D: the gate reads the state ──"
drive(){ printf '%s' "$1" | bash "$HOOK" 2>/dev/null; }
# provoke: U-001 keyed, remove its l0 record → FAIL
rm -f "$L0"
bash "$S/run-full-suite.sh" --cwd="$repo" --runner="true" --quiet >/dev/null 2>&1 || true
OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--all\"}}")
printf '%s' "$OUT" | grep -q 'panel-evidence' && printf '%s' "$OUT" | grep -q 'l0_evidence_missing' \
  && ok "D1 execute-bolts denied: panel-evidence gate names l0_evidence_missing for U-001" || bad "D1 gate silent or wrong: $(printf '%s' "$OUT" | head -c 300)"
mkdir -p "$V/bolts/U-001"; echo d > "$V/bolts/U-001/dispatch-prompt.md"   # U-001 back in flight
OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"mega-sdd:bolt-implementer\",\"prompt\":\"UNIT: U-001 x\\nREAD FIRST, IN FULL: $V/bolts/U-001/dispatch-prompt.md\"}}")
if printf '%s' "$OUT" | grep -q 'panel-evidence'; then bad "D2 in-run gate held the in-flight unit's own pending panel evidence"; else ok "D2 in-run: in-flight U-001's pending evidence does not deny its dispatch"; fi
rm -f "$V/bolts/U-001/dispatch-prompt.md"
bash "$S/run-code-gates.sh" --cwd="$repo" --base="$HEAD~1" --head="$HEAD" --unit="$V/units/U-001.md" --no-code-gates --write >/dev/null 2>&1

echo "── E: the three artifacts are guarded ──"
for f in "bolts/U-001/findings.json" "lens-inputs/U-001/l0-results.json" "bolts/U-001/review-tier.json"; do
  OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$V/$f\",\"content\":\"{}\"}}")
  printf '%s' "$OUT" | grep -q '"permissionDecision": "deny"' && ok "E: Write of $f denied" || bad "E: Write of $f ALLOWED"
  OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo '{}' > .mega-sdd/vaults/v1/$f\"}}")
  printf '%s' "$OUT" | grep -q '"deny"' && ok "E: Bash redirect into $f denied" || bad "E: Bash redirect into $f ALLOWED"
done
OUT=$(drive "{\"session_id\":\"s\",\"cwd\":\"$repo\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"bash $S/merge-panel-findings.sh --vault=$V --unit=U-001 --head=$HEAD --round=2 --spec-verdict=pass --verifier=$WORK/spec.txt\"}}")
[ -z "$OUT" ] && ok "E: sanctioned merge-panel-findings.sh invocation passes" || bad "E: sanctioned writer blocked: $(printf '%s' "$OUT" | head -c 160)"
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

echo; [ $err -eq 0 ] && { echo "test-t3-panel-evidence: ALL PASS"; exit 0; } || { echo "test-t3-panel-evidence: FAILED"; exit 1; }
