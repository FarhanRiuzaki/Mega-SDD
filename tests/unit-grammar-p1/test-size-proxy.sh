#!/usr/bin/env bash
# test-size-proxy.sh — direct pins of _lib/unit_tier.size_proxy (the `unit_tier: xs`
# size class, spec 2026-08-23 §1a; shared by validate-unit-spec.sh xs_body_advisory).
# Re-homed from tests/size-weighted/test-unit-tier-router.sh cases 1-9 so the size rule
# stays pinned without the router (P3 plan research/2026-09-28-p3-deletion-plan.md §3d):
#   - small = acceptance_test 1..2 AND at least one work-item section AND every present
#     section within 1..3 items;
#   - absent/empty structure is NEVER small (unknown never lowers a tier);
#   - case 2 is the only pin of the column-0 stop rule: the acceptance_test block ends
#     at the next column-0 key, so the binding_refs items are not counted.
# CI-safe: bash + python3 only.
# Run: bash tests/unit-grammar-p1/test-size-proxy.sh </dev/null
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/plugins/mega-sdd/scripts/_lib"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# mkunit $file $task_type $n_accept $body — the router test's fixture, byte-for-byte
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

# sp $file $py_assert — split frontmatter/body the way the scripts do, then assert on size_proxy
sp() {
  python3 - "$LIB" "$1" "$2" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
from unit_tier import size_proxy
text = open(sys.argv[2], encoding="utf-8").read()
fm, body = "", text
if text.startswith("---"):
    end = text.find("\n---", 3)
    if end > 0:
        fm, body = text[3:end], text[end + 4:]
d = size_proxy(fm, body)
assert eval(sys.argv[3], {}, dict(d)), d
EOF
}

STEPS2=$'## Implementation steps\n\n1. Buat method render.\n2. Panggil dari controller.'
STEPS4=$'## Implementation steps\n\n1. a\n2. b\n3. c\n4. d'

# 1. 2 steps + 1 acceptance -> small
mkunit "$WORK/u-xs.md" create 1 "$STEPS2"
sp "$WORK/u-xs.md" 'size_small and n_accept == 1 and n_steps == 2 and n_reqs is None' \
  && pass "1: 1 acceptance + 2 steps -> small" || fail "1: small case"

# 2. 2 acceptance entries followed by a binding_refs list -> small, n_accept == 2 (column-0 stop)
mkunit "$WORK/u-vfy.md" verify 2 "$STEPS2"
sp "$WORK/u-vfy.md" 'size_small and n_accept == 2' \
  && pass "2: acceptance block stops at the next column-0 key (binding_refs not counted)" || fail "2: column-0 stop rule"

# 3. 4 implementation steps -> not small (over the work-item ceiling)
mkunit "$WORK/u-4s.md" create 1 "$STEPS4"
sp "$WORK/u-4s.md" 'not size_small and n_steps == 4' \
  && pass "3: 4 steps -> not small" || fail "3: step ceiling"

# 4. 3 acceptance entries -> not small
mkunit "$WORK/u-3a.md" create 3 "$STEPS2"
sp "$WORK/u-3a.md" 'not size_small and n_accept == 3' \
  && pass "4: 3 acceptance entries -> not small" || fail "4: acceptance ceiling"

# 5. DOCTRINE: no steps/requirements section -> not small
mkunit "$WORK/u-nosect.md" create 1 "Cuma prosa tanpa section kerja."
sp "$WORK/u-nosect.md" 'not size_small and n_steps is None and n_reqs is None' \
  && pass "5: absent work section -> not small (unknown never lowers)" || fail "5: absent-section doctrine"

# 6. DOCTRINE: zero acceptance_test entries -> not small
mkunit "$WORK/u-noacc.md" create 0 "$STEPS2"
sp "$WORK/u-noacc.md" 'not size_small and n_accept == 0' \
  && pass "6: no acceptance entries -> not small" || fail "6: no-acceptance doctrine"

# 7. DOCTRINE: empty Implementation steps section (0 items) -> not small
mkunit "$WORK/u-empty.md" create 1 $'## Implementation steps\n\n(nanti)'
sp "$WORK/u-empty.md" 'not size_small and n_steps == 0' \
  && pass "7: empty steps section -> not small" || fail "7: empty-section doctrine"

# 8. Legacy grammar: ## Requirements bullets (no Implementation steps) -> small
mkunit "$WORK/u-req.md" create 1 $'## Requirements\n\n- render laporan\n- format tanggal'
sp "$WORK/u-req.md" 'size_small and n_reqs == 2 and n_steps is None' \
  && pass "8: legacy Requirements bullets -> small" || fail "8: legacy grammar leg"

# 9. Both sections present, Requirements over the ceiling -> not small (BOTH must fit)
mkunit "$WORK/u-both.md" create 1 $'## Requirements\n\n- a\n- b\n- c\n- d\n\n'"$STEPS2"
sp "$WORK/u-both.md" 'not size_small and n_reqs == 4 and n_steps == 2' \
  && pass "9: both sections, one over the ceiling -> not small" || fail "9: both-sections ceiling"

echo
if [ "$fails" -eq 0 ]; then echo "OK: all size_proxy pins green"; exit 0
else echo "FAILURES: $fails"; exit 1; fi
