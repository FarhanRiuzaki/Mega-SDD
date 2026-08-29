#!/usr/bin/env bash
# test-do-not-modify-touched-set.sh — F-06 (spec 2026-08-30 §1.2).
#
# The field run raised 6 DO_NOT_MODIFY halts — ALL false positives (sibling
# units changed a shared app.ts legitimately), 0 true positives — because the
# engine compared the working-tree sha against the pre-flight snapshot and gave
# that PRECEDENCE over the unit's own commit touched-set. This pins the fix:
#   A  a sibling's commit changes the locked path AFTER U-001's baseline →
#      U-001's recompute PASSES, with a NOTE on the evidence (not a verdict)
#   B  the unit's OWN commit touches the locked path → FAIL (unchanged)
#   C  pre-commit working-tree mode (no unit commit yet) → snapshot verdict
#      unchanged: a tampered locked path FAILS
#   D  the 15-stale-baselines class: a baseline whose path was since changed
#      by another unit is INERT for the committed unit
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRE="$ROOT/plugins/mega-sdd/scripts/run-preflight-scan.sh"
POST="$ROOT/plugins/mega-sdd/scripts/run-postflight-scan.sh"
VABS="$ROOT/plugins/mega-sdd/scripts/validate-bolt-artifacts.sh"
for f in "$PRE" "$POST" "$VABS"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
err=0
ok()  { echo "  ok: $*"; }
bad() { echo "  FAIL: $*"; err=1; }

repo="$WORK/repo"; V="$repo/.mega-sdd/vaults/v1"
mkdir -p "$V/units" "$repo/src"
( cd "$repo" && git init -q . && echo 'core' > src/core.js && git add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m seed )
G() { git -C "$repo" -c user.email=t@t -c user.name=t "$@"; }
mkunit() { # uid rule
  printf -- '---\nunit_id: %s\ntask_type: create\ntarget_files:\n  - path: src/%s.js\n    operation: create\n---\n# %s\n\n## Hard rules\n\n- %s\n\n## Acceptance\n' "$1" "$1" "$1" "$2" > "$V/units/$1.md"
}
status_of() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["status"])' "$V/bolts/$1/postflight.json"; }
evidence_of() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["rules"][0]["evidence"])' "$V/bolts/$1/postflight.json"; }

echo "── A: sibling changes the locked path after U-001's baseline ──"
mkunit U-001 'DO NOT modify src/core.js'
G add .mega-sdd >/dev/null; G commit -q -m "spec: U-001" >/dev/null
bash "$PRE" --cwd="$repo" --unit=U-001 --quiet; rc=$?
[ $rc -eq 0 ] && [ -f "$V/bolts/U-001/preflight.json" ] && ok "A0 baseline minted for U-001" || bad "A0 preflight rc=$rc"
echo 'u1' > "$repo/src/U-001.js"; G add src/U-001.js >/dev/null
G commit -q -m "feat(U-001): bolt

Unit: U-001" >/dev/null
# the sibling (its own unit, its own whitelist) legitimately changes core.js
mkunit U-002 'MUST keep the audit trail'
printf -- '---\nunit_id: U-002\ntask_type: modify\ntarget_files:\n  - path: src/core.js\n    operation: modify\n---\n# U-002\n\n## Acceptance\n' > "$V/units/U-002.md"
echo 'core v2 (by U-002)' > "$repo/src/core.js"; G add src/core.js .mega-sdd >/dev/null
G commit -q -m "feat(U-002): change core

Unit: U-002" >/dev/null
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
[ "$(status_of U-001)" = "pass" ] && ok "A1 U-001 PASSES — its own commits never touched src/core.js" \
  || bad "A1 U-001 false-FAILED on a sibling's legitimate change (the field's 6/6 false-positive class): $(evidence_of U-001)"
evidence_of U-001 | grep -q 'note: sha256 differs' && ok "A2 evidence carries the baseline-drift NOTE (informative, not a verdict)" \
  || bad "A2 drift note missing from evidence: $(evidence_of U-001)"
evidence_of U-001 | grep -q 'did not touch' && ok "A3 verdict text is the touched-set predicate" || bad "A3 verdict text is not touched-set: $(evidence_of U-001)"

echo "── B: the unit's OWN commit touches the locked path → FAIL ──"
mkunit U-003 'DO NOT modify src/core.js'
G add .mega-sdd >/dev/null; G commit -q -m "spec: U-003" >/dev/null
bash "$PRE" --cwd="$repo" --unit=U-003 --quiet >/dev/null 2>&1
echo 'u3' > "$repo/src/U-003.js"; echo 'tampered by U-003' >> "$repo/src/core.js"
G add src/U-003.js src/core.js >/dev/null
G commit -q -m "feat(U-003): bolt

Unit: U-003" >/dev/null
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
[ "$(status_of U-003)" = "fail" ] && ok "B1 U-003 FAILS — its own commit touched src/core.js" || bad "B1 real violation missed: $(evidence_of U-003)"
evidence_of U-003 | grep -q 'bolt commit touched' && ok "B2 evidence names the touch" || bad "B2 evidence text: $(evidence_of U-003)"

echo "── C: pre-commit working-tree mode keeps the snapshot verdict ──"
mkunit U-004 'DO NOT modify src/core.js'
G add .mega-sdd >/dev/null; G commit -q -m "spec: U-004" >/dev/null
bash "$PRE" --cwd="$repo" --unit=U-004 --quiet >/dev/null 2>&1
[ -f "$V/bolts/U-004/preflight.json" ] || bad "C0 baseline for U-004 not minted"
echo 'tamper before commit' >> "$repo/src/core.js"     # uncommitted, no U-004 commit exists
bash "$POST" --cwd="$repo" --unit=U-004 --quiet >/dev/null 2>&1
[ "$(status_of U-004)" = "fail" ] && ok "C1 working-tree tamper with no unit commit → FAIL via the snapshot (unchanged semantics)" \
  || bad "C1 working-tree mode lost its snapshot verdict: $(evidence_of U-004)"
evidence_of U-004 | grep -q 'working-tree mode' && ok "C2 evidence labels the mode" || bad "C2 evidence: $(evidence_of U-004)"
git -C "$repo" checkout -q -- src/core.js

echo "── D: the stale-baseline class is inert for committed units ──"
# U-001's baseline pinned the seed core.js; core.js has since changed twice by
# other units. A recompute of U-001 must stay PASS however many times it runs.
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
bash "$VABS" --cwd="$repo" --postflight-scan --recompute >/dev/null 2>&1
[ "$(status_of U-001)" = "pass" ] && ok "D1 U-001 stays PASS across recomputes with a stale baseline" || bad "D1 stale baseline re-flagged U-001"

echo
[ $err -eq 0 ] && { echo "test-do-not-modify-touched-set: ALL PASS"; exit 0; } || { echo "test-do-not-modify-touched-set: FAILED"; exit 1; }
