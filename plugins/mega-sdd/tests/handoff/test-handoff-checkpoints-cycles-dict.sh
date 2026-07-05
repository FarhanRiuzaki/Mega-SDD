#!/usr/bin/env bash
# test-handoff-checkpoints-cycles-dict.sh — pins the handoff `checkpoints:`/`cycles:`
# type contract in validate-handoff-yaml.sh.
#
# handoff-contract.md is UNAMBIGUOUS that both are DICT (object/mapping), not list:
#   - §Handoff YAML schema :45-48   `checkpoints:` block mapping {latest_step_id,
#                                    checkpoint_file, resume_command}
#   - §Handoff YAML schema :62-65   `cycles:` block mapping {cycle_count,
#                                    halts_auto_resolved, halts_escalated_to_user}
#   - machine-readable annotations :169-171 (checkpoints TYPE: object) and
#                                  :189-191 (cycles TYPE: object)
# The subfields halts_auto_resolved/halts_escalated_to_user are the only arrays,
# nested INSIDE the dict.
#
# Regression pinned: the validator classified checkpoints/cycles as LIST_FIELDS, so a
# canonical block-mapping producer output (real dict per the no-deps parser) failed
# `is_listish(dict)` and returned a SPURIOUS FAIL / handoff_type_mismatch against a
# conformant handoff. Fix moves both keys to DICT_FIELDS.
#
# CI-safe: bash + python3 only (the validator uses a no-deps YAML-subset parser).
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

# jget FILE FIELD — extract a value from the validator's JSON report file.
#   status                 -> top-level status string
#   halt_type              -> top-level halt_type
#   has_ckpt_cycle_error   -> "yes"/"no": any type_error mentions checkpoints|cycles
# (JSON is read from a file arg, NOT stdin — the python here-string would otherwise
#  hijack stdin and starve json.load.)
jget() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
field = sys.argv[2]
if field == "has_ckpt_cycle_error":
    errs = (d.get("details") or {}).get("type_errors") or []
    print("yes" if any(("checkpoints" in e) or ("cycles" in e) for e in errs) else "no")
else:
    print(d.get(field))
' "$1" "$2"
}

# ── Fixture 1 (GOOD): canonical block-mapping checkpoints + cycles ─────────────
# Per contract these are the correct shapes; the handoff MUST validate.
# status: halted with a non-empty blockers entry so the fixture stays valid even
# after Batch 8 lands a "blockers non-empty on halt" check (adjacent-region edit).
cat > "${ROOT}/good.txt" <<'EOF'
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-05T10:00:00Z
  status: halted
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:resolve-oq
    suggested_args: []
    rationale: "resume from checkpoint"
  blockers:
    - handoff_test_stub_blocker
  checkpoints:
    latest_step_id: claim-45
    checkpoint_file: /tmp/x/.internal/checkpoints/2026-07-05-bind-codebase-claim-45.jsonl
    resume_command: "/mega-sdd:bind-codebase --resume-from=claim-46"
  cycles:
    cycle_count: 2
    halts_auto_resolved:
      - bind_conflict
    halts_escalated_to_user:
      - constitution_drift
```
EOF

# ── Fixture 2 (BAD): checkpoints/cycles emitted as inline LISTS ────────────────
# The no-deps parser turns `[a, b]` into a REAL list (validate-handoff-yaml.sh
# :130-132), so post-fix `is_dictish(list)` is False and the wrong shape is caught.
# This fixture FLIPS: pre-fix a list was ACCEPTED (checkpoints/cycles in LIST_FIELDS),
# post-fix it is REJECTED — proving the DICT check specifically bites on the fix.
cat > "${ROOT}/bad.txt" <<'EOF'
```yaml
handoff:
  emitted_by: bind-codebase
  emitted_at: 2026-07-05T10:00:00Z
  status: completed
  artifacts: []
  next_action:
    suggested_skill: mega-sdd:generate-units
    suggested_args: []
    rationale: "next"
  blockers: []
  checkpoints: [a, b]
  cycles: [x, y]
```
EOF

echo "── GOOD fixture: canonical dict checkpoints/cycles must PASS ──"
bash "$VALIDATOR" --cwd="${ROOT}" --response-file="${ROOT}/good.txt" >"${ROOT}/good.json" 2>/dev/null
g_status="$(jget "${ROOT}/good.json" status)"
g_ckpt="$(jget "${ROOT}/good.json" has_ckpt_cycle_error)"
[ "$g_status" = "PASS" ] \
  && pass "G1: canonical checkpoints/cycles dict → status PASS" \
  || { fail "G1: canonical dict wrongly rejected (status=$g_status)"; cat "${ROOT}/good.json"; }
[ "$g_ckpt" = "no" ] \
  && pass "G2: no spurious checkpoints/cycles type_error" \
  || fail "G2: spurious checkpoints/cycles type_error emitted on a conformant handoff"

echo "── BAD fixture: inline-list checkpoints/cycles must FAIL ──"
bash "$VALIDATOR" --cwd="${ROOT}" --response-file="${ROOT}/bad.txt" >"${ROOT}/bad.json" 2>/dev/null
b_status="$(jget "${ROOT}/bad.json" status)"
b_halt="$(jget "${ROOT}/bad.json" halt_type)"
b_ckpt="$(jget "${ROOT}/bad.json" has_ckpt_cycle_error)"
[ "$b_status" = "FAIL" ] && [ "$b_halt" = "handoff_type_mismatch" ] \
  && pass "B1: wrong-shape (list) checkpoints/cycles → FAIL handoff_type_mismatch" \
  || { fail "B1: wrong-shape checkpoints/cycles not caught (status=$b_status halt=$b_halt)"; cat "${ROOT}/bad.json"; }
[ "$b_ckpt" = "yes" ] \
  && pass "B2: type_errors name the offending checkpoints/cycles fields" \
  || fail "B2: DICT check did not bite on list-shaped checkpoints/cycles"

echo
if [ "$fails" -eq 0 ]; then
  echo "test-handoff-checkpoints-cycles-dict: ALL PASS"
  exit 0
else
  echo "test-handoff-checkpoints-cycles-dict: $fails FAILURE(S)"
  exit 1
fi
