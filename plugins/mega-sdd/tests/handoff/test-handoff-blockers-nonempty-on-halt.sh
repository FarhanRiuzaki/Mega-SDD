#!/usr/bin/env bash
# test-handoff-blockers-nonempty-on-halt.sh — pins the "status==halted REQUIRES a
# non-empty blockers array" check in validate-handoff-yaml.sh.
#
# handoff-contract.md §Status values (:249) "halted — ... blockers populated with
# one or more entries per halt-protocol" + §blockers (:163). A halt with an
# empty/absent blocker envelope hollows moat invariant #4 (halt taxonomy) — the
# recorded verdict shows a clean halt with no diagnosis / routed resolution.
#
# Scope is status==halted ONLY: a `paused` handoff with `blockers: []` is VALID and
# common (generate-intent surfaces P1-OQ triage via metrics.items_blocked with
# blockers: []; handoff-contract.md:7 skill-ref precedence). Case 2 below is the
# guard against a wrong "paused|halted" implementation.
#
# All fixtures carry `artifacts: []` so the Step-5 artifact-existence check cannot
# fire and mask the blockers check. Assertions key off the state/exit code +
# the SPECIFIC halt_type (invalid_handoff), never stdout prose.
#
# CI-safe: bash + python3 only (validator uses a no-deps YAML-subset parser).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-handoff-yaml.sh"

[ -f "$VALIDATOR" ] || { echo "FAIL: validator not found at $VALIDATOR"; exit 1; }

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

fails=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; fails=$((fails + 1)); }

# jget FILE FIELD — read a top-level field from the validator's JSON report.
jget() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get(sys.argv[2]))
' "$1" "$2"
}

# ── Case 1a (POSITIVE-FAIL): status halted + blockers: [] → FAIL invalid_handoff ─
cat > "${ROOT}/halt-empty.txt" <<'EOF'
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-05T10:00:00Z
  status: halted
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:resolve-oq
    suggested_args: []
    rationale: "resolve the conflict"
  blockers: []
```
EOF

# ── Case 1b (POSITIVE-FAIL): status halted + blockers omitted → FAIL ───────────
cat > "${ROOT}/halt-omitted.txt" <<'EOF'
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-05T10:00:00Z
  status: halted
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:resolve-oq
    suggested_args: []
    rationale: "resolve the conflict"
```
EOF

# ── Case 2 (NEGATIVE): status paused + blockers: [] → PASS (paused NOT caught) ──
cat > "${ROOT}/paused-empty.txt" <<'EOF'
```yaml
handoff:
  emitted_by: generate-intent
  emitted_at: 2026-07-05T10:00:00Z
  status: paused
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:resolve-oq
    suggested_args: []
    rationale: "P1 business OQs surfaced"
  blockers: []
  metrics:
    items_blocked: 3
```
EOF

# ── Case 3 (NEGATIVE): status halted + non-empty blockers → PASS ───────────────
cat > "${ROOT}/halt-nonempty.txt" <<'EOF'
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-05T10:00:00Z
  status: halted
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:resolve-oq
    suggested_args: []
    rationale: "resolve the conflict"
  blockers:
    - bind_conflict
```
EOF

run() { bash "$VALIDATOR" --cwd="${ROOT}" --response-file="$1" >"$2" 2>/dev/null; echo $?; }

echo "── Case 1a: halted + blockers:[] must FAIL invalid_handoff ──"
rc="$(run "${ROOT}/halt-empty.txt" "${ROOT}/1a.json")"
st="$(jget "${ROOT}/1a.json" status)"; ht="$(jget "${ROOT}/1a.json" halt_type)"
{ [ "$rc" = "1" ] && [ "$st" = "FAIL" ] && [ "$ht" = "invalid_handoff" ]; } \
  && pass "1a: halted + empty blockers → FAIL invalid_handoff (rc=$rc)" \
  || { fail "1a: expected FAIL/invalid_handoff, got rc=$rc status=$st halt=$ht"; cat "${ROOT}/1a.json"; }

echo "── Case 1b: halted + blockers omitted must FAIL invalid_handoff ──"
rc="$(run "${ROOT}/halt-omitted.txt" "${ROOT}/1b.json")"
st="$(jget "${ROOT}/1b.json" status)"; ht="$(jget "${ROOT}/1b.json" halt_type)"
{ [ "$rc" = "1" ] && [ "$st" = "FAIL" ] && [ "$ht" = "invalid_handoff" ]; } \
  && pass "1b: halted + omitted blockers → FAIL invalid_handoff (rc=$rc)" \
  || { fail "1b: expected FAIL/invalid_handoff, got rc=$rc status=$st halt=$ht"; cat "${ROOT}/1b.json"; }

echo "── Case 2: paused + blockers:[] must PASS (paused is NOT caught) ──"
rc="$(run "${ROOT}/paused-empty.txt" "${ROOT}/2.json")"
st="$(jget "${ROOT}/2.json" status)"
{ [ "$rc" = "0" ] && [ "$st" = "PASS" ]; } \
  && pass "2: paused + empty blockers → PASS (halted-only scope)" \
  || { fail "2: paused + empty blockers wrongly caught, got rc=$rc status=$st"; cat "${ROOT}/2.json"; }

echo "── Case 3: halted + non-empty blockers must PASS ──"
rc="$(run "${ROOT}/halt-nonempty.txt" "${ROOT}/3.json")"
st="$(jget "${ROOT}/3.json" status)"
{ [ "$rc" = "0" ] && [ "$st" = "PASS" ]; } \
  && pass "3: halted + non-empty blockers → PASS" \
  || { fail "3: halted + non-empty blockers wrongly failed, got rc=$rc status=$st"; cat "${ROOT}/3.json"; }

echo
if [ "$fails" -eq 0 ]; then
  echo "test-handoff-blockers-nonempty-on-halt: ALL PASS"
  exit 0
else
  echo "test-handoff-blockers-nonempty-on-halt: $fails FAILURE(S)"
  exit 1
fi
