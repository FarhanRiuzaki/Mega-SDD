#!/usr/bin/env bash
# Functional (B1): the post-flight Hard-rule gate is enforced by the VALIDATOR, not
# prose. A committed create/extend/modify bolt whose unit has a non-empty ## Hard rules
# section must carry <vault>/bolts/U-XXX/postflight.json with all verdicts pass.
#   A. Hard-rule bolt + no postflight.json          -> FAIL postflight_evidence_missing
#   B. Hard-rule bolt + postflight.json all-pass    -> PASS
#   C. verify unit (skips post-flight) + no postflight -> not flagged
#   D. unit with EMPTY ## Hard rules + no postflight    -> not flagged
#   E. postflight.json present but a verdict violated   -> FAIL postflight_evidence_missing
#   F. non-git dir -> exit 0 no-op
set -u
err=0
V=plugins/mega-sdd/scripts/validate-bolt-artifacts.sh
[ -x "$V" ] || { echo "validator missing/non-executable"; exit 1; }
VABS="$PWD/$V"

mkunit() { # repo uid task_type hardrules(yes|no)
  mkdir -p "$1/.mega-sdd/vaults/v1/units"
  {
    printf -- '---\nunit_id: %s\ntask_type: %s\n---\n# %s\n\n' "$2" "$3" "$2"
    if [ "$4" = "yes" ]; then
      printf '## Hard rules\n\n- DO_NOT_MODIFY src/legacy/Core.php\n\n## Acceptance\n'
    else
      printf '## Hard rules\n\n_None._\n\n## Acceptance\n'
    fi
  } > "$1/.mega-sdd/vaults/v1/units/$2.md"
}
postflight() { # repo uid verdict(pass|violated)
  mkdir -p "$1/.mega-sdd/vaults/v1/bolts/$2"
  printf '{ "unit_id": "%s", "status": "%s", "rules": [ { "type": "DO_NOT_MODIFY", "verdict": "%s" } ] }\n' \
    "$2" "$([ "$3" = pass ] && echo pass || echo fail)" "$3" \
    > "$1/.mega-sdd/vaults/v1/bolts/$2/postflight.json"
}

repo=$(mktemp -d); trap 'rm -rf "$repo"' EXIT
( cd "$repo" && git init -q . )

# A. create + Hard rules, bolt committed, NO postflight.json -> FAIL
mkunit "$repo" U-001 create yes
( cd "$repo" && echo c1 > src1.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-001" )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
[ $rc -eq 1 ] || { echo "A: expected exit 1, got $rc"; err=1; }
echo "$out" | grep -q 'postflight_evidence_missing' || { echo "A: expected postflight_evidence_missing"; err=1; }
echo "$out" | grep -q '"unit_id": "U-001"' || { echo "A: U-001 not flagged"; err=1; }

# B. add postflight.json all-pass -> PASS
postflight "$repo" U-001 pass
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
[ $rc -eq 0 ] || { echo "B: expected exit 0 after postflight added, got $rc"; err=1; }
echo "$out" | grep -q '"status": "PASS"' || { echo "B: expected PASS"; err=1; }

# C. verify unit with Hard rules + no postflight -> NOT flagged (verify skips post-flight)
mkunit "$repo" U-002 verify yes
( cd "$repo" && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-002" )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
[ $rc -eq 0 ] || { echo "C: verify unit must not require postflight, got $rc"; err=1; }
echo "$out" | grep -q '"unit_id": "U-002"' && { echo "C: false positive on verify unit"; err=1; }

# D. create unit with EMPTY Hard rules + no postflight -> NOT flagged
mkunit "$repo" U-003 create no
( cd "$repo" && echo c3 > src3.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-003" )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-003"' && { echo "D: false positive on empty-Hard-rules unit"; err=1; }

# E. a Hard-rule bolt whose postflight.json records a VIOLATED verdict -> FAIL
mkunit "$repo" U-004 modify yes
( cd "$repo" && echo c4 > src4.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-004" )
postflight "$repo" U-004 violated
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
[ $rc -eq 1 ] || { echo "E: expected exit 1 on violated postflight, got $rc"; err=1; }
echo "$out" | grep -q '"unit_id": "U-004"' || { echo "E: U-004 violated-postflight not flagged"; err=1; }

# helper: unit with a CUSTOM ## Hard rules heading line + a real rule
mkunit_heading() { # repo uid task_type heading_line
  mkdir -p "$1/.mega-sdd/vaults/v1/units"
  {
    printf -- '---\nunit_id: %s\ntask_type: %s\n---\n# %s\n\n' "$2" "$3" "$2"
    printf '%s\n\n- DO_NOT_MODIFY src/legacy/Core.php\n\n## Acceptance\n' "$4"
  } > "$1/.mega-sdd/vaults/v1/units/$2.md"
}
# helper: raw postflight.json body
postflight_raw() { # repo uid json
  mkdir -p "$1/.mega-sdd/vaults/v1/bolts/$2"
  printf '%s\n' "$3" > "$1/.mega-sdd/vaults/v1/bolts/$2/postflight.json"
}

# G. canonical TEMPLATE heading (trailing parenthetical, unit-schema.md:149) + real rule
#    + no postflight -> MUST FLAG. Regression: the gate must not go inert on the template.
mkunit_heading "$repo" U-005 create '## Hard rules  (validated at bolt time by execute-bolts pre/post-flight)'
( cd "$repo" && echo c5 > src5.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-005" )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-005"' || { echo "G: U-005 (template heading) not flagged — B1 gate INERT"; err=1; }

# H. capital-R heading `## Hard Rules` + real rule + no postflight -> MUST FLAG
mkunit_heading "$repo" U-006 create '## Hard Rules'
( cd "$repo" && echo c6 > src6.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-006" )
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-006"' || { echo "H: U-006 (capital-R heading) not flagged"; err=1; }

# I. vacuous postflight {} -> MUST FLAG (no valid evidence; scan never ran)
mkunit "$repo" U-007 create yes
( cd "$repo" && echo c7 > src7.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-007" )
postflight_raw "$repo" U-007 '{}'
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-007"' || { echo "I: empty {} postflight must FLAG (vacuous)"; err=1; }

# J. status:pass but EMPTY rules[] -> MUST FLAG (validated nothing)
mkunit "$repo" U-008 create yes
( cd "$repo" && echo c8 > src8.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-008" )
postflight_raw "$repo" U-008 '{ "status": "pass", "rules": [] }'
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-008"' || { echo "J: empty rules[] postflight must FLAG (vacuous)"; err=1; }

# E1. status:pass but a rule verdict:fail -> FLAG (pins the per-rule branch independently)
mkunit "$repo" U-009 modify yes
( cd "$repo" && echo c9 > src9.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-009" )
postflight_raw "$repo" U-009 '{ "status": "pass", "rules": [ { "type": "DO_NOT_MODIFY", "verdict": "fail" } ] }'
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-009"' || { echo "E1: rule verdict:fail must FLAG"; err=1; }

# E2. top status:fail but rule verdict:pass -> FLAG (pins the status branch independently)
mkunit "$repo" U-010 modify yes
( cd "$repo" && echo c10 > src10.php && git add . && git -c user.email=t@t -c user.name=t commit -qm "feat(bolt): U-010" )
postflight_raw "$repo" U-010 '{ "status": "fail", "rules": [ { "type": "DO_NOT_MODIFY", "verdict": "pass" } ] }'
out=$(bash "$VABS" --cwd="$repo" --postflight-scan); rc=$?
echo "$out" | grep -q '"unit_id": "U-010"' || { echo "E2: top status:fail must FLAG"; err=1; }

# F. non-git dir -> exit 0
plain=$(mktemp -d); mkdir -p "$plain/.mega-sdd"
bash "$VABS" --cwd="$plain" --postflight-scan >/dev/null 2>&1; rc=$?
[ $rc -eq 0 ] || { echo "F: non-git dir must exit 0, got $rc"; err=1; }
rm -rf "$plain"

[ $err -eq 0 ] && echo "ALL PASS (test-postflight-scan)" || echo "FAILED"
exit $err
