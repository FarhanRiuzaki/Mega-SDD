#!/usr/bin/env bash
# test-directive-advisory.sh — F-01(a) (spec 2026-08-30 §2.2).
#
# Field measurement: 256 of 278 postflight rules on a 36-unit run were prose
# directives; every one carried verdict `attested` from ONE free-text paragraph
# per unit; none could ever fail; the counterfactual "directives advisory" lost
# zero detections. A tier that cannot fail is a permission valve. This pins:
#   A  a directive-only unit → status pass, exit 0, verdict recorded as
#      directive_unverified, `directives` summary on the artifact
#   B  the B1 gate (recompute) does NOT flag it (no postflight_evidence_missing)
#   C  --attest-directives still records `attested` (the record is kept, the
#      gate does not depend on it)
#   D  carry-forward is IDEMPOTENT: two recomputes never stack the prefix
#   E  a MACHINE rule still fails and still gates (the detector is untouched)
#   F  validate-unit-spec.sh states the directive-ratio ADVISORY (never gating)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POST="$ROOT/plugins/mega-sdd/scripts/run-postflight-scan.sh"
VABS="$ROOT/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
VUS="$ROOT/plugins/mega-sdd/scripts/validate-unit-spec.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0
ok()  { echo "  ok: $*"; }
bad() { echo "  FAIL: $*"; err=1; }

repo="$WORK/repo"; V="$repo/.mega-sdd/vaults/v1"
mkdir -p "$V/units" "$repo/src"
( cd "$repo" && git init -q . && echo core > src/core.js && git add -A && git -c user.email=t@t -c user.name=t commit -q -m seed )
G() { git -C "$repo" -c user.email=t@t -c user.name=t "$@"; }
mkunit() { # uid rules...
  local uid="$1"; shift
  { printf -- '---\nunit_id: %s\ntask_type: create\ntarget_files:\n  - path: src/%s.js\n    operation: create\n---\n# %s\n\n## Hard rules\n\n' "$uid" "$uid" "$uid"
    for r in "$@"; do printf -- '- %s\n' "$r"; done
    printf '\n## Acceptance\n'; } > "$V/units/$uid.md"
}
J() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2], {"d": d}))' "$V/bolts/$1/postflight.json" "$2"; }

echo "── A: directive-only unit is advisory ──"
mkunit U-001 'MUST log every access to the audit trail' 'MUST NOT expose internal ids in responses'
G add .mega-sdd >/dev/null; G commit -q -m "spec: U-001" >/dev/null
echo u1 > "$repo/src/U-001.js"; G add src/U-001.js >/dev/null
G commit -q -m "feat(U-001): bolt

Unit: U-001" >/dev/null
out=$(bash "$POST" --cwd="$repo" --unit=U-001 2>&1); rc=$?
[ $rc -eq 0 ] && ok "A1 writer exits 0 with two unattested directives" || bad "A1 writer exit $rc: $out"
[ "$(J U-001 'd["status"]')" = "pass" ] && ok "A2 status pass" || bad "A2 status $(J U-001 'd["status"]')"
[ "$(J U-001 'sorted({r["verdict"] for r in d["rules"]})')" = "['directive_unverified']" ] \
  && ok "A3 verdicts still RECORDED as directive_unverified" || bad "A3 verdicts: $(J U-001 'sorted({r["verdict"] for r in d["rules"]})')"
[ "$(J U-001 'd["directives"]')" = "{'total': 2, 'attested': 0, 'unverified': 2}" ] \
  && ok "A4 artifact carries the directives summary" || bad "A4 summary: $(J U-001 'd.get("directives")')"
echo "$out" | grep -q "2 directive advisory" && ok "A5 pass line states the advisory count" || bad "A5 line: $out"

echo "── B: the B1 gate does not hold a directive-only unit ──"
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >"$WORK/b.out" 2>&1; rc=$?
[ $rc -eq 0 ] && ok "B1 gate PASS (rc=0)" || bad "B1 gate rc=$rc: $(head -c 300 "$WORK/b.out")"
grep -q '"unit_id": "U-001"' "$WORK/b.out" && bad "B2 U-001 flagged postflight_evidence_missing over directives" || ok "B2 U-001 not flagged"

echo "── C: attestation is still recorded ──"
bash "$POST" --cwd="$repo" --unit=U-001 --attest-directives="panel reviewed both" --quiet; rc=$?
[ "$(J U-001 'd["directives"]["attested"]')" = "2" ] && ok "C1 --attest-directives records attested ×2" || bad "C1 attested=$(J U-001 'd["directives"]["attested"]')"

echo "── D: carry-forward is idempotent ──"
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
EV=$(J U-001 'd["rules"][0]["evidence"]')
case "$EV" in
  *"carried from prior scan): attested"*) bad "D1 prefix STACKED after two recomputes: $EV" ;;
  "attested (carried from prior scan): panel reviewed both") ok "D1 exactly one carry prefix after two recomputes" ;;
  *) bad "D1 unexpected evidence: $EV" ;;
esac

echo "── E: a machine rule still fails and still gates ──"
mkunit U-002 'DO NOT modify src/core.js' 'MUST keep the audit trail'
G add .mega-sdd >/dev/null; G commit -q -m "spec: U-002" >/dev/null
echo u2 > "$repo/src/U-002.js"; echo tamper >> "$repo/src/core.js"; G add src/U-002.js src/core.js >/dev/null
G commit -q -m "feat(U-002): bolt

Unit: U-002" >/dev/null
bash "$POST" --cwd="$repo" --unit=U-002 --quiet; rc=$?
[ $rc -eq 1 ] && [ "$(J U-002 'd["status"]')" = "fail" ] && ok "E1 writer FAILS on the touched locked path (exit 1)" || bad "E1 rc=$rc status=$(J U-002 'd["status"]')"
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >"$WORK/e.out" 2>&1; rc=$?
[ $rc -eq 1 ] && grep -q '"unit_id": "U-002"' "$WORK/e.out" && ok "E2 gate flags U-002 (machine rule) and not U-001 (directives)" || bad "E2 rc=$rc $(head -c 200 "$WORK/e.out")"
grep -q '"unit_id": "U-001"' "$WORK/e.out" && bad "E3 U-001 flagged" || ok "E3 U-001 stays clear"

echo "── F: the directive-ratio advisory is STATED, never gating ──"
mkunit U-003 'MUST a' 'MUST b' 'MUST c' 'MUST NOT d' 'NEVER e'
bash "$VUS" --cwd="$repo" --quiet >/dev/null 2>&1
ST="$repo/.mega-sdd/.unit-spec-state.json"
python3 - "$ST" <<'EOF' && ok "F1 state carries hard_rules_directive_advisory naming the ratio and the v1 productions" || bad "F1 advisory missing/wrong"
import json, sys
d = json.load(open(sys.argv[1]))
adv = d.get("hard_rules_directive_advisory")
assert adv and "prose directives" in adv and "DO NOT modify <path>" in adv, adv
assert d["hard_rules_directive_prose"] >= 8, d
EOF
python3 - "$ST" <<'EOF' && ok "F2 the advisory adds NO issue (halt_type) — status untouched by it" || bad "F2 advisory leaked into issues[]"
import json, sys
d = json.load(open(sys.argv[1]))
assert not [i for i in d.get("issues", []) if "directive" in str(i.get("halt_type", ""))], d["issues"]
EOF

echo
[ $err -eq 0 ] && { echo "test-directive-advisory: ALL PASS"; exit 0; } || { echo "test-directive-advisory: FAILED"; exit 1; }
