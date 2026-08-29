#!/usr/bin/env bash
# B1 recompute-at-gate: `validate-bolt-artifacts.sh --postflight-scan --recompute`
# RE-EXECUTES each committed Hard-rule bolt's mechanical rules from git/fs ground truth
# and OVERWRITES its postflight.json before deriving state — a forged/stale evidence
# artifact cannot open the gate. Directives carry their prior attestation forward.
#   A. Rule-VIOLATING bolt + FORGED postflight.json=pass:
#        --postflight-scan (no recompute) -> PASS   (demonstrates the trust gap)
#        --postflight-scan --recompute    -> FAIL   (overwrites forged->fail; gate blocks)
#        and the on-disk artifact now records status:fail (ground truth on disk)
#   B. Honest passing bolt: --recompute keeps PASS (no false block).
#   C. Directive rule + attested postflight.json: --recompute carries attestation forward (PASS).
#   D. Obligation stickiness: unit's ## Hard rules blanked in the working tree AFTER the bolt,
#        forged pass -> --recompute STILL re-derives the rule from the bolt-commit text -> FAIL.
set -u
err=0
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh
[ -x "$V" ] || { echo "validator missing/non-executable"; exit 1; }
VABS="$PWD/$V"

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
( cd "$repo" && git init -q . && git config user.email t@t && git config user.name t && git config commit.gpgsign false )
mkdir -p "$repo/.mega-sdd/vaults/v1/units" "$repo/src"
printf 'export function keep(a,b){return a+b;}\n' > "$repo/src/core.js"
( cd "$repo" && git add . && git commit -qm seed >/dev/null )

mkunit(){ # uid rule_line
  mkdir -p "$repo/.mega-sdd/vaults/v1/units"
  { printf -- '---\nunit_id: %s\ntask_type: create\n---\n# %s\n\n## Hard rules\n\n- %s\n\n## Acceptance\n' "$1" "$1" "$2"; } \
    > "$repo/.mega-sdd/vaults/v1/units/$1.md"
}
forge(){ # uid status verdict type
  mkdir -p "$repo/.mega-sdd/vaults/v1/bolts/$1"
  printf '{ "unit_id":"%s","status":"%s","head_sha":"x","written_by":"forged","rules":[{"type":"%s","verdict":"%s"}] }\n' \
    "$1" "$2" "$4" "$3" > "$repo/.mega-sdd/vaults/v1/bolts/$1/postflight.json"
}
status_on_disk(){ python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["status"])' "$repo/.mega-sdd/vaults/v1/bolts/$1/postflight.json"; }

# ── A. rule-VIOLATING bolt (touches its own DO_NOT_MODIFY file) + forged pass ──
mkunit U-001 'DO NOT modify src/core.js'
( cd "$repo" && echo '// tampered' >> src/core.js && git add . && git commit -qm "feat(U-001): bolt

Unit: U-001" >/dev/null )
forge U-001 pass pass DO_NOT_MODIFY

# A1: no recompute -> trusts the forged pass
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
[ $rc -eq 0 ] || { echo "A1: expected PASS (forged trusted) got rc=$rc"; err=1; }

# A2: recompute -> overwrites forged->fail, gate FAILS
out=$(bash "$VABS" --cwd="$repo" --postflight-scan --recompute); rc=$?
[ $rc -eq 1 ] || { echo "A2: expected FAIL under recompute, got rc=$rc"; err=1; }
echo "$out" | grep -q 'postflight_evidence_missing' || { echo "A2: expected postflight_evidence_missing"; err=1; }
echo "$out" | grep -q '"unit_id": "U-001"' || { echo "A2: U-001 not flagged"; err=1; }
[ "$(status_on_disk U-001)" = "fail" ] || { echo "A2: on-disk artifact not overwritten to fail (got $(status_on_disk U-001))"; err=1; }

# ── B. honest passing bolt (DO_NOT_MODIFY on a file it does NOT touch) ──
mkunit U-002 'DO NOT modify src/core.js'
( cd "$repo" && echo n2 > src/n2.js && git add .mega-sdd src/n2.js && git commit -qm "feat(U-002): bolt

Unit: U-002" >/dev/null )
# recompute writes the honest evidence itself; U-002 must NOT be flagged (U-001 still is)
out=$(bash "$VABS" --cwd="$repo" --postflight-scan --recompute); rc=$?
echo "$out" | grep -q '"unit_id": "U-002"' && { echo "B: honest bolt U-002 falsely flagged"; err=1; }
[ "$(status_on_disk U-002)" = "pass" ] || { echo "B: honest U-002 not recorded pass (got $(status_on_disk U-002))"; err=1; }

# ── C. directive rule + attested postflight.json: attestation carried forward ──
mkunit U-003 'MUST log all access to the audit trail'
( cd "$repo" && echo n3 > src/n3.js && git add .mega-sdd src/n3.js && git commit -qm "feat(U-003): bolt

Unit: U-003" >/dev/null )
# prior artifact records the directive as attested (as run-postflight-scan.sh --attest-directives would)
mkdir -p "$repo/.mega-sdd/vaults/v1/bolts/U-003"
printf '{ "unit_id":"U-003","status":"pass","head_sha":"x","written_by":"run-postflight-scan.sh","rules":[{"type":"directive","rule":"MUST log all access to the audit trail","verdict":"attested","evidence":"attested: reviewed"}] }\n' \
  > "$repo/.mega-sdd/vaults/v1/bolts/U-003/postflight.json"
out=$(bash "$VABS" --cwd="$repo" --postflight-scan --recompute); rc=$?
echo "$out" | grep -q '"unit_id": "U-003"' && { echo "C: attested directive U-003 falsely flagged (carry-forward failed)"; err=1; }
[ "$(status_on_disk U-003)" = "pass" ] || { echo "C: attested U-003 not pass after recompute (got $(status_on_disk U-003))"; err=1; }
# and a directive with NO prior attestation must be directive_unverified -> flagged
mkunit U-004 'MUST log all access to the audit trail'
( cd "$repo" && echo n4 > src/n4.js && git add .mega-sdd src/n4.js && git commit -qm "feat(U-004): bolt

Unit: U-004" >/dev/null )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan --recompute); rc=$?
# F-01(a) 7.10.0: an un-attested directive is ADVISORY — it is recorded as
# directive_unverified but never forms the B1 verdict (256/278 field rules were
# directives; none could fail). The unit must NOT be flagged.
echo "$out" | grep -q '"unit_id": "U-004"' && { echo "D0: un-attested directive U-004 flagged — directives gate again (F-01a regression)"; err=1; }
grep -q 'directive_unverified' "$repo/.mega-sdd/vaults/v1/bolts/U-004/postflight.json" || { echo "D0: directive_unverified no longer RECORDED for U-004"; err=1; }

# ── D. obligation stickiness: blank the unit's Hard rules in the working tree, forge pass ──
mkunit U-005 'DO NOT modify src/core.js'
( cd "$repo" && echo '// tamper5' >> src/core.js && git add . && git commit -qm "feat(U-005): bolt

Unit: U-005" >/dev/null )
# retroactively blank U-005's Hard rules in the working tree + forge a pass
printf -- '---\nunit_id: U-005\ntask_type: create\n---\n# U-005\n\n## Hard rules\n\n_None._\n\n## Acceptance\n' \
  > "$repo/.mega-sdd/vaults/v1/units/U-005.md"
forge U-005 pass pass DO_NOT_MODIFY
out=$(bash "$VABS" --cwd="$repo" --postflight-scan --recompute); rc=$?
echo "$out" | grep -q '"unit_id": "U-005"' || { echo "D: stickiness — blanked-in-worktree U-005 must still be re-derived from bolt-commit text and FAIL"; err=1; }
[ "$(status_on_disk U-005)" = "fail" ] || { echo "D: U-005 not overwritten to fail (got $(status_on_disk U-005))"; err=1; }

[ $err -eq 0 ] && echo "PASS: test-postflight-recompute (B1 recompute-at-gate)" || echo "FAIL: test-postflight-recompute"
exit $err
