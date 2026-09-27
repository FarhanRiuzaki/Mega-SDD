#!/usr/bin/env bash
# test-standards-lens-h1.sh — the standards lens rides with the quality lens only
# (2026-09-27, hypothesis H1 applied under the owner's cost mandate; evidence
# research/2026-08-30-lens-yield-field.md: standards 5 dispatches, 0 Critical,
# 1 unique fix; quality 5 dispatches, 22 fixes). Pins the lens SET per signal.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RT="$SCRIPT_DIR/../../plugins/mega-sdd/scripts/resolve-review-tier.sh"
fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# mk <file> <n_target_files> <hard-rules body>
mk() {
  local f="$1" n="$2" hr="$3" i
  { printf -- '---\nunit_id: U-001\ntask_type: create\ntarget_files:\n'
    for i in $(seq 1 "$n"); do printf '  - path: src/mod%s.ts\n    operation: create\n' "$i"; done
    printf 'acceptance_test:\n  - type: test\n    command: run\n    expects: ""\n---\n\n# Unit\n\n## Hard rules\n\n%s\n' "$hr"
  } > "$f"
}
lenses() { bash "$RT" --unit "$1" | python3 -c 'import json,sys; print(",".join(json.load(sys.stdin)["lenses"]))'; }
mk "$W/a.md" 2 "- keep it small"
[ "$(lenses "$W/a.md")" = "spec" ] && pass "2 files, no signal → spec only (minimal)" || fail "minimal: $(lenses "$W/a.md")"
mk "$W/b.md" 2 "- the password MUST be hashed"
[ "$(lenses "$W/b.md")" = "spec,security" ] && pass "security surface without quality → spec+security, no standards" || fail "security-only: $(lenses "$W/b.md")"
mk "$W/c.md" 3 "- keep it small"
[ "$(lenses "$W/c.md")" = "spec,quality,standards" ] && pass "3 files → quality, and standards rides with it" || fail "quality: $(lenses "$W/c.md")"
mk "$W/d.md" 4 "- the password MUST be hashed"
[ "$(lenses "$W/d.md")" = "spec,quality,security,standards" ] && pass "quality + security → all four" || fail "full: $(lenses "$W/d.md")"
[ "$fails" -eq 0 ] && echo "test-standards-lens-h1: ALL PASS" || { echo "test-standards-lens-h1: $fails FAIL"; exit 1; }
