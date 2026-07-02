#!/usr/bin/env bash
# test-5a-gate-state.sh — god-review stage 5, Batch 5A: gate-state integrity.
# Pins the unit-stage gate mechanics against the REAL hooks:
#
#   GU-HOOK-1  .unit-spec-state.json is PROJECT-WIDE (never last-writer-wins):
#              a violating unit blocks execute-bolts even when a clean sibling
#              was validated after it.
#   GU-HOOK-2  quality-gate state files are rm-protected (Bash) + Write/Edit-
#              denied; and even a deleted state cannot open the gate (gate-time
#              re-derivation).
#   GU-HOOK-3  a unit written via Bash (no Write-tool dispatch) is still gated
#              at execute-bolts time (gate-time re-scan).
#   GU-HOOK-5  a violating unit in a SMALLER vault blocks despite a bigger
#              clean vault (all-vault scanning) — flow-coverage side is pinned
#              in 5C; here the unit-spec side.
#
# Run: bash tests/god-review-s5/test-5a-gate-state.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
POST="${ROOT}/plugins/mega-sdd/hooks/post-tool-use"
VUS="${ROOT}/plugins/mega-sdd/scripts/validate-unit-spec.sh"
for f in "$PRE" "$POST" "$VUS"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t gate5a)"
trap 'rm -rf "$WORK"' EXIT

drive_hook() { # $1=hook $2=fixture $3=tool_name $4=tool_input-json
  HOOK="$1" FIX="$2" TOOL="$3" TI="$4" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s5test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=180)
print(r.stdout, end="")
'
}

mk_bad_verify() { # $1=path — verify+HIGH with an ungrounded criterion
cat > "$1" <<'EOF'
---
unit_id: U-001
title: Verify billing
task_type: verify
target_files: []
vault_source: 03-data-model.md
grounding_confidence: HIGH
acceptance_test:
  - type: unit
    assert: billing works
---
## Anchors
- src/billing.py:1

## Acceptance criteria
- billing computes tax [ungrounded]
EOF
}
mk_clean_create() { # $1=path $2=uid
cat > "$1" <<EOF
---
unit_id: $2
title: Clean create
task_type: create
target_files:
  - src/new_feature.py
vault_source: 04-flows.md
acceptance_test:
  - type: unit
    assert: feature works
---
## Implementation steps
Build it with care and directive prose that satisfies every soft check in one sentence of more than fifteen words.
EOF
}

note "== 5A: gate-state integrity (real hooks) =="

F1="$WORK/f1"; mkdir -p "$F1/.mega-sdd/vaults/demo/units" "$F1/src"
printf 'line1\nline2\n' > "$F1/src/billing.py"
mk_bad_verify "$F1/.mega-sdd/vaults/demo/units/U-001.md"
mk_clean_create "$F1/.mega-sdd/vaults/demo/units/U-002.md" "U-002"

# ── GU-HOOK-1: validate the CLEAN unit LAST (the old mask), then gate ──
drive_hook "$POST" "$F1" "Write" "{\"file_path\": \"$F1/.mega-sdd/vaults/demo/units/U-002.md\"}" >/dev/null
sleep 1  # PostToolUse backgrounds validators
ST="$F1/.mega-sdd/.unit-spec-state.json"
python3 -c "
import json, sys
d = json.load(open('$ST'))
files = {i.get('file') for i in d['issues']}
sys.exit(0 if d['status'] == 'FAIL' and any('U-001' in (f or '') for f in files) else 1)
" && ok "GU-HOOK-1: clean-sibling dispatch keeps U-001's FAIL in the merged state (no last-writer-wins)" \
  || fail "GU-HOOK-1: state lost U-001's violation after U-002 write: $(cat "$ST" 2>/dev/null | head -4)"
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && echo "$OUT" | grep -q "verify_grounding_untrusted" \
  && ok "GU-HOOK-1: execute-bolts DENIED on the masked-order fixture (A1 gate real for N-1 units)" \
  || fail "GU-HOOK-1: gate opened over the violating non-last unit (out: ${OUT:0:160})"

# ── GU-HOOK-2: state rm via Bash denied; Write forged-PASS denied; deleted state still gated ──
OUT=$(drive_hook "$PRE" "$F1" "Bash" "{\"command\": \"rm $F1/.mega-sdd/.unit-spec-state.json\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "GU-HOOK-2: rm .unit-spec-state.json DENIED (anti-self-bypass)" || fail "GU-HOOK-2: rm allowed"
OUT=$(drive_hook "$PRE" "$F1" "Write" "{\"file_path\": \"$F1/.mega-sdd/.flow-coverage-state.json\", \"content\": \"{}\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "GU-HOOK-2: forged-PASS Write of .flow-coverage-state.json DENIED" || fail "GU-HOOK-2: forged Write allowed"
rm -f "$ST"  # simulate an out-of-band deletion (outside the agent)
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "GU-HOOK-2: DELETED state cannot open the gate (gate-time re-derivation)" \
  || fail "GU-HOOK-2: absent state = fail-open survives (out: ${OUT:0:160})"

# ── GU-HOOK-3: unit written via Bash (no Write dispatch) still gated ──
F2="$WORK/f2"; mkdir -p "$F2/.mega-sdd/vaults/demo/units" "$F2/src"
printf 'line1\n' > "$F2/src/billing.py"
mk_clean_create "$F2/.mega-sdd/vaults/demo/units/U-001.md" "U-001"
bash "$VUS" --cwd="$F2" --quiet >/dev/null 2>&1   # seed a PASS state
grep -q '"status": "PASS"' "$F2/.mega-sdd/.unit-spec-state.json" || fail "GU-HOOK-3: seed PASS failed"
mk_bad_verify "$F2/.mega-sdd/vaults/demo/units/U-002.md"   # lands like a bash heredoc — no hook dispatch
OUT=$(drive_hook "$PRE" "$F2" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "GU-HOOK-3: Bash-written violating unit gated at execute-bolts (stale PASS re-derived)" \
  || fail "GU-HOOK-3: bash-written unit sails through on stale PASS (out: ${OUT:0:160})"

# ── GU-HOOK-5 (unit-spec side): violation in the SMALLER vault blocks ──
F3="$WORK/f3"; mkdir -p "$F3/.mega-sdd/vaults/big/units" "$F3/.mega-sdd/vaults/small/units" "$F3/src"
printf 'line1\n' > "$F3/src/billing.py"
for i in 1 2 3; do mk_clean_create "$F3/.mega-sdd/vaults/big/units/U-00$i.md" "U-00$i"; done
mk_bad_verify "$F3/.mega-sdd/vaults/small/units/U-001.md"
OUT=$(drive_hook "$PRE" "$F3" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' \
  && ok "GU-HOOK-5: smaller vault's violation blocks despite the bigger clean vault" \
  || fail "GU-HOOK-5: multi-vault mask survives (out: ${OUT:0:160})"

# ── regression: a fully clean project still passes the gate ──
F4="$WORK/f4"; mkdir -p "$F4/.mega-sdd/vaults/demo/units"
mk_clean_create "$F4/.mega-sdd/vaults/demo/units/U-001.md" "U-001"
OUT=$(drive_hook "$PRE" "$F4" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' \
  && fail "regression: clean project falsely blocked (out: ${OUT:0:200})" \
  || ok "regression: clean project passes the gate"

if [ "$FAILED" -eq 0 ]; then note "ALL 5A OK"; else note "5A had failures"; fi
exit $FAILED
