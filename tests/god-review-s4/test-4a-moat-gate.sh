#!/usr/bin/env bash
# test-4a-moat-gate.sh — god-review stage 4, Batch 4A: moat-gate integrity.
# Pins the CONFLICT-gate enforcement chain end-to-end against the REAL hooks:
#
#   BC-GATE-1   moat state refreshes on BINDING writes (PostToolUse producer
#               dispatch) AND the execute-bolts PreToolUse gate self-heals a
#               stale/absent state (re-bind with fresh CONFLICTs can no longer
#               sail through on a stale PASS).
#   BC-BYPASS-1 Write/Edit of .validation-blockers.json is denied (guard used
#               to exist only on the Bash branch).
#   BC-BYPASS-2 a "tests/" comment token no longer disables the Bash guard;
#               genuine test-path operations still skip it.
#   BC-BINDING-DELETE  rm of a binding doc is denied; and the validator fails
#               closed (binding_missing) when units cite CONFLICT-IDs with zero
#               binding docs present.
#   BC-MSG-1    deny/next_action text routes conflict drops to resolve-oq, not
#               to the OQ-frontmatter fix.
#
# Run: bash tests/god-review-s4/test-4a-moat-gate.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PRE="${ROOT}/plugins/mega-sdd/hooks/pre-tool-use"
POST="${ROOT}/plugins/mega-sdd/hooks/post-tool-use"
VBU="${ROOT}/plugins/mega-sdd/scripts/validate-handoff-binding-units.sh"
for f in "$PRE" "$POST" "$VBU"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t moat4a)"
trap 'rm -rf "$WORK"' EXIT

# drive_hook <hook> <fixture> <tool_name> <tool_input-json> → stdout
drive_hook() {
  HOOK="$1" FIX="$2" TOOL="$3" TI="$4" python3 -c '
import json, os, subprocess
payload = {"cwd": os.environ["FIX"], "tool_name": os.environ["TOOL"],
           "tool_input": json.loads(os.environ["TI"]), "session_id": "s4test"}
r = subprocess.run(["bash", os.environ["HOOK"]], input=json.dumps(payload),
                   capture_output=True, text=True, timeout=120)
print(r.stdout, end="")
'
}

CLEAN_BINDING='# Binding Manifest

## Summary
- claims_total: 1
- confirmed: 1
- conflict: 0
- oq: 0

## Confirmed Claims (1)
- C-001 | 03-data-model.md:10 | app/models/User.php:5 | User has email
'
CONFLICT_BLOCK='## Conflicts (1) — BLOCKING
| ID | Vault Claim | Codebase Reality | Resolution Needed |
|---|---|---|---|
| CONFLICT-1 | vault says bearer auth | code uses sessions | KEEP_VAULT / KEEP_CODE |

### CONFLICT-1 — auth mechanism mismatch
- **Vault doc**: 04-flows.md §auth
- **Codebase artifact**: app/Http/Middleware/Auth.php
- **conflict_class**: semantic
- **resolution_complexity**: low
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT
'
UNIT_CITING='---
unit_id: U-001
task_type: create
binding_refs:
  - CONFLICT-1
---
# U-001
body
'

note "== 4A: moat-gate integrity (real hooks) =="

# ── Fixture: clean bind + unit → validator seeds PASS ──
F1="$WORK/f1"
mkdir -p "$F1/.mega-sdd/vaults/v1/units"
printf '%s' "$CLEAN_BINDING" > "$F1/.mega-sdd/vaults/v1/binding.md"
printf '%s' "$UNIT_CITING" | sed 's/  - CONFLICT-1//' > "$F1/.mega-sdd/vaults/v1/units/U-001.md"
bash "$VBU" --cwd="$F1" --quiet >/dev/null 2>&1
ST="$F1/.mega-sdd/.validation-blockers.json"
grep -q '"status": "PASS"' "$ST" && ok "seed: clean bind validates PASS" || fail "seed PASS expected: $(cat "$ST" 2>/dev/null | head -3)"

# ── BC-GATE-1 (PreToolUse self-heal): re-bind introduces CONFLICT, state stale ──
sleep 1  # bash-3.2 -nt is whole-second; make the binding STRICTLY newer than state
printf '%s\n%s' "$CLEAN_BINDING" "$CONFLICT_BLOCK" > "$F1/.mega-sdd/vaults/v1/binding.md"
printf '%s' "$UNIT_CITING" > "$F1/.mega-sdd/vaults/v1/units/U-001.md"
grep -q '"status": "PASS"' "$ST" && ok "pre-condition: state is STALE PASS after conflict re-bind (no validator ran)" || fail "pre-condition broken"
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-GATE-1: execute-bolts DENIED on stale-PASS + fresh CONFLICT (gate self-heals)" || fail "BC-GATE-1: gate opened over an unresolved CONFLICT (out: ${OUT:0:200})"
echo "$OUT" | grep -q "resolve-oq" && ok "BC-MSG-1: deny routes conflict drops to resolve-oq" || fail "BC-MSG-1: deny lacks the resolve-oq route"
grep -q '"status": "FAIL"' "$ST" && ok "BC-GATE-1: self-heal rewrote the moat state to FAIL" || fail "BC-GATE-1: state still stale"

# ── BC-GATE-1 (absent state + binding docs exist) ──
rm -f "$ST"
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-GATE-1: ABSENT state + active CONFLICT → still denied (absent≠allow when bindings exist)" || fail "BC-GATE-1: absent-state bypass survives"

# ── BC-GATE-1 (v7.5.0 №D repin: the PostToolUse producer dispatch is DELETED) ──
# The binding-write early-warning leg died with the fan-out. The MOAT is the
# gate-time re-derive — already proven by the two arms above (stale-PASS
# self-heal + absent-state deny at the execute-bolts dispatch). Negative pin:
# a binding write must now be a pure journal event (no moat state minted).
rm -f "$ST"
drive_hook "$POST" "$F1" "Write" "{\"file_path\": \"$F1/.mega-sdd/vaults/v1/binding.md\"}" >/dev/null
sleep 1
if [ -f "$ST" ]; then
  fail "BC-GATE-1: a PostToolUse binding write minted moat state — the fan-out grew back (№D)"
else
  ok "BC-GATE-1: binding write is journal-only; the moat re-derives at the gate (arms above)"
fi
# and the gate still recovers it immediately after:
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && [ -f "$ST" ] \
  && ok "BC-GATE-1: next execute-bolts dispatch re-derives the moat state and denies" \
  || fail "BC-GATE-1: gate-time re-derive lost after the binding write"

# ── recovery: structural resolution re-opens the gate ──
python3 - "$F1" <<'PY'
import sys, os
p = os.path.join(sys.argv[1], ".mega-sdd/vaults/v1/binding.md")
s = open(p).read().replace("### CONFLICT-1 — auth mechanism mismatch",
    "### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — auth mechanism mismatch")
open(p, "w").write(s)
PY
OUT=$(drive_hook "$PRE" "$F1" "Skill" '{"skill": "mega-sdd:execute-bolts"}')
echo "$OUT" | grep -q '"permissionDecision": "deny"' && fail "recovery: resolved marker should re-open the gate (out: ${OUT:0:160})" || ok "recovery: structural ✅ RESOLVED heading re-opens the gate (self-heal saw the fresh write)"

# ── BC-BYPASS-1: Write/Edit of the moat state file is denied ──
F2="$WORK/f2"; mkdir -p "$F2/.mega-sdd"
OUT=$(drive_hook "$PRE" "$F2" "Write" "{\"file_path\": \"$F2/.mega-sdd/.validation-blockers.json\", \"content\": \"{}\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-BYPASS-1: Write of .validation-blockers.json denied" || fail "BC-BYPASS-1: forged-PASS Write allowed"
OUT=$(drive_hook "$PRE" "$F2" "Edit" "{\"file_path\": \"$F2/.mega-sdd/.validation-blockers.json\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-BYPASS-1: Edit of the moat state denied" || fail "BC-BYPASS-1: Edit allowed"
OUT=$(drive_hook "$PRE" "$F2" "Write" "{\"file_path\": \"$F2/src/app.py\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && fail "BC-BYPASS-1: ordinary source Write must stay allowed" || ok "BC-BYPASS-1: ordinary Write unaffected"
# round-2 S4R-2: .plan-pending has a DOCUMENTED skill-body Write path (orchestrate-flow
# Plan mode) — the Write/Edit deny is scoped to the moat state only.
OUT=$(drive_hook "$PRE" "$F2" "Write" "{\"file_path\": \"$F2/.mega-sdd/.plan-pending\", \"content\": \"{}\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && fail "r2 S4R-2: Plan-mode .plan-pending Write must stay allowed (documented skill write path)" || ok "r2 S4R-2: .plan-pending Write allowed (Plan mode intact); tamper protection stays on the Bash branch"
# round-2 ABSPATH: a real project living under an examples/ path segment keeps the guard
F2E="$WORK/examples/proj"; mkdir -p "$F2E/.mega-sdd"
OUT=$(drive_hook "$PRE" "$F2E" "Write" "{\"file_path\": \"$F2E/.mega-sdd/.validation-blockers.json\", \"content\": \"{}\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "r2 ABSPATH: project under an examples/ path segment still guarded (exemption is PROJECT_ROOT-relative)" || fail "r2 ABSPATH: examples/-path project silently loses the Write guard"
OUT=$(drive_hook "$PRE" "$F2E" "Bash" "{\"command\": \"rm $F2E/.mega-sdd/.validation-blockers.json\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "r2 ABSPATH: Bash guard also PROJECT_ROOT-relative (examples/-path project still guarded)" || fail "r2 ABSPATH: examples/-path project loses the Bash guard"

# ── BC-BYPASS-2: comment token no longer disables the Bash guard ──
OUT=$(drive_hook "$PRE" "$F2" "Bash" "{\"command\": \"rm $F2/.mega-sdd/.validation-blockers.json # cleanup for tests/\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-BYPASS-2: rm + tests/ comment token still DENIED" || fail "BC-BYPASS-2: comment-token bypass survives"
OUT=$(drive_hook "$PRE" "$F2" "Bash" "{\"command\": \"rm $F2/tests/fixtures/.validation-blockers.json\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && fail "BC-BYPASS-2: genuine tests/-path rm should skip the guard" || ok "BC-BYPASS-2: genuine test-path operation still exempt"

# ── BC-BINDING-DELETE: rm of a binding doc denied; validator fails closed ──
OUT=$(drive_hook "$PRE" "$F1" "Bash" "{\"command\": \"rm $F1/.mega-sdd/vaults/v1/binding.md\"}")
echo "$OUT" | grep -q '"permissionDecision": "deny"' && ok "BC-BINDING-DELETE: rm binding.md denied by the Bash guard" || fail "BC-BINDING-DELETE: rm binding.md allowed"
F3="$WORK/f3"
mkdir -p "$F3/.mega-sdd/vaults/v1/units"
printf '%s' "$UNIT_CITING" > "$F3/.mega-sdd/vaults/v1/units/U-001.md"
J=$(bash "$VBU" --cwd="$F3" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && echo "$J" | grep -q '"binding_missing"' \
  && ok "BC-BINDING-DELETE: units citing CONFLICT-IDs + zero binding docs → FAIL binding_missing (validator backstop)" \
  || fail "BC-BINDING-DELETE: deletion re-validates to PASS (rc=$RC)"

# ── BC-MSG-1: validator next_action is drop-type aware ──
echo "$J" | grep -q "resolve-oq" && ok "BC-MSG-1: validator next_action routes to resolve-oq for conflict-class drops" || fail "BC-MSG-1: next_action still OQ-only"

if [ "$FAILED" -eq 0 ]; then note "ALL 4A OK"; else note "4A had failures"; fi
exit $FAILED
