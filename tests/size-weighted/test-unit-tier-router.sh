#!/usr/bin/env bash
# test-unit-tier-router.sh — size-weighted spec (2026-08-23 §1a, A1 option i,
# approved 2026-09-05) Step 1 pins: the resolver's `unit_tier` field.
#   - xs is reachable ONLY from a "minimal" verdict + small size-proxy
#     (acceptance_test 1..2 AND work items 1..3);
#   - absent/empty structure is NEVER small (unknown never lowers a tier);
#   - s/m/l are pure labels of the existing verdict — lenses/model untouched;
#   - --write persists unit_tier into review-tier.json (additive field).
# CI-safe: bash + python3 only.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RT="$REPO_ROOT/plugins/mega-sdd/scripts/resolve-review-tier.sh"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# mkunit $file $task_type $n_accept $body — 1 clean target file (minimal-eligible)
mkunit() {
  local f="$1" tt="$2" na="$3" body="$4" i
  {
    printf -- '---\nunit_id: U-001\ntask_type: %s\n' "$tt"
    printf 'target_files:\n  - path: app/Services/Report.php\n    operation: create\n'
    if [ "$na" -gt 0 ]; then
      printf 'acceptance_test:\n'
      for i in $(seq 1 "$na"); do
        printf -- '  - type: test\n    command: run-%s\n    expects: ""\n' "$i"
      done
    fi
    printf 'binding_refs:\n  - C-001\n---\n\n# Unit\n\n%s\n' "$body"
  } > "$f"
}

jval() { python3 -c "import json,sys;print(json.load(sys.stdin).get('$1'))"; }

STEPS2=$'## Implementation steps\n\n1. Buat method render.\n2. Panggil dari controller.'
STEPS4=$'## Implementation steps\n\n1. a\n2. b\n3. c\n4. d'

# 1. minimal + 2 steps + 1 acceptance -> xs
mkunit "$WORK/u-xs.md" create 1 "$STEPS2"
OUT=$(bash "$RT" --unit "$WORK/u-xs.md")
[ "$(echo "$OUT" | jval unit_tier)" = "xs" ] && pass "minimal + small proxy -> xs" || fail "xs case: $OUT"
# lenses/model must be IDENTICAL to a plain minimal verdict (label, not routing)
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['tier']=='minimal' and d['lenses']==['spec'] and d['implementer_model']=='sonnet', d" \
  && pass "xs never touches lenses/model routing" || fail "xs routing drifted: $OUT"

# 2. verify unit with small proxy -> xs (the other minimal leg)
mkunit "$WORK/u-vfy.md" verify 2 "$STEPS2"
[ "$(bash "$RT" --unit "$WORK/u-vfy.md" | jval unit_tier)" = "xs" ] \
  && pass "verify + small proxy -> xs" || fail "verify xs leg"

# 3. minimal but 4 implementation steps -> s (over work-item ceiling)
mkunit "$WORK/u-4s.md" create 1 "$STEPS4"
[ "$(bash "$RT" --unit "$WORK/u-4s.md" | jval unit_tier)" = "s" ] \
  && pass "4 steps -> s (proxy ceiling)" || fail "4-step ceiling"

# 4. minimal but 3 acceptance entries -> s
mkunit "$WORK/u-3a.md" create 3 "$STEPS2"
[ "$(bash "$RT" --unit "$WORK/u-3a.md" | jval unit_tier)" = "s" ] \
  && pass "3 acceptance entries -> s" || fail "acceptance ceiling"

# 5. DOCTRINE: minimal with NO steps/requirements section -> s, never xs
mkunit "$WORK/u-nosect.md" create 1 "Cuma prosa tanpa section kerja."
[ "$(bash "$RT" --unit "$WORK/u-nosect.md" | jval unit_tier)" = "s" ] \
  && pass "absent work section -> s (unknown never lowers)" || fail "absent-section doctrine"

# 6. DOCTRINE: minimal with zero acceptance_test entries -> s, never xs
mkunit "$WORK/u-noacc.md" create 0 "$STEPS2"
[ "$(bash "$RT" --unit "$WORK/u-noacc.md" | jval unit_tier)" = "s" ] \
  && pass "no acceptance entries -> s (no evidence of small)" || fail "no-acceptance doctrine"

# 7. DOCTRINE: empty Implementation steps section (0 items) -> s
mkunit "$WORK/u-empty.md" create 1 $'## Implementation steps\n\n(nanti)'
[ "$(bash "$RT" --unit "$WORK/u-empty.md" | jval unit_tier)" = "s" ] \
  && pass "empty steps section -> s" || fail "empty-section doctrine"

# 8. Legacy grammar: ## Requirements bullets (no Implementation steps) -> xs
mkunit "$WORK/u-req.md" create 1 $'## Requirements\n\n- render laporan\n- format tanggal'
[ "$(bash "$RT" --unit "$WORK/u-req.md" | jval unit_tier)" = "xs" ] \
  && pass "legacy Requirements bullets -> xs" || fail "legacy grammar leg"

# 9. Both sections present, Requirements over ceiling -> s (BOTH must fit)
mkunit "$WORK/u-both.md" create 1 $'## Requirements\n\n- a\n- b\n- c\n- d\n\n'"$STEPS2"
[ "$(bash "$RT" --unit "$WORK/u-both.md" | jval unit_tier)" = "s" ] \
  && pass "both sections, one over ceiling -> s" || fail "both-sections ceiling"

# 10. Label mapping: standard -> m, full -> l
mkunit3() { # 3 clean files => standard
  printf -- '---\nunit_id: U-002\ntask_type: create\ntarget_files:\n  - path: a/One.php\n    operation: create\n  - path: a/Two.php\n    operation: create\n  - path: a/Three.php\n    operation: create\nbinding_refs:\n  - C-001\n---\n\n# Unit\n\n%s\n' "$STEPS2" > "$1"
}
mkunit3 "$WORK/u-std.md"
[ "$(bash "$RT" --unit "$WORK/u-std.md" | jval unit_tier)" = "m" ] \
  && pass "standard -> m" || fail "standard label"
printf -- '---\nunit_id: U-003\ntask_type: create\nrisk: critical\ntarget_files:\n  - path: a/One.php\n    operation: create\nbinding_refs:\n  - C-001\n---\n\n# Unit\n\n%s\n' "$STEPS2" > "$WORK/u-full.md"
[ "$(bash "$RT" --unit "$WORK/u-full.md" | jval unit_tier)" = "l" ] \
  && pass "full -> l" || fail "full label"

# 11. Overcapture pin (found during step 1): scalar-list target_files must
# STOP at the next column-0 key — binding_refs items are not paths. Before
# the fix this 2-file unit measured target_files:5 and false-fired file_count.
printf -- '---\nunit_id: U-009\ntask_type: create\ntarget_files:\n  - app/One.php\n  - app/Two.php\nbinding_refs:\n  - C-001\n  - C-002\n  - C-003\n---\n\n# Unit\n\n%s\n' "$STEPS2" > "$WORK/u-scalar.md"
OUT=$(bash "$RT" --unit "$WORK/u-scalar.md")
echo "$OUT" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['target_files']==2 and d['tier']=='minimal' and 'file_count' not in d['signals_fired'], d" \
  && pass "scalar-list target_files stops at next key (no DOTALL overcapture)" || fail "overcapture: $OUT"

# 12. --write persists unit_tier into review-tier.json (additive)
VAULT="$WORK/vault"; mkdir -p "$VAULT/units"
mkunit "$VAULT/units/U-001.md" create 1 "$STEPS2"
bash "$RT" --unit "$VAULT/units/U-001.md" --write >/dev/null
UT=$(jval unit_tier < "$VAULT/bolts/U-001/review-tier.json")
[ "$UT" = "xs" ] && pass "--write persists unit_tier" || fail "persisted unit_tier=$UT"

echo
if [ "$fails" -eq 0 ]; then echo "OK: all unit-tier router pins green"; exit 0
else echo "FAILURES: $fails"; exit 1; fi
