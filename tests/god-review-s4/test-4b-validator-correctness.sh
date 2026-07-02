#!/usr/bin/env bash
# test-4b-validator-correctness.sh — god-review stage 4, Batch 4B.
# Pins validate-handoff-binding-units.sh + validate-conflict-classification.sh
# correctness:
#
#   BC-GATE-2    resolution markers are STRUCTURAL — prose "resolved" / a benign
#                "✅ verified anchor" bullet no longer exempts an active CONFLICT;
#                heading markers and dedicated Resolution/Status lines DO.
#   BC-VAL-6     a `### C-NNN … — CONFLICT (BLOCKING)` claim-ID heading is an
#                active conflict; a plain C-NNN claim heading is not.
#   BC-HANDOFF-1 bind's numeric fresh-OQ form (OQ-001) is harvested and dropped
#                when uncited (was silently invisible).
#   BC-HANDOFF-2 OQ-IDs confined to the auto-resolved/recommendation sections are
#                advisory extras, NOT blocking drops (killed the deterministic
#                false-FAIL on clean brownfield runs).
#   BC-ADV-ID    CONFLICT-ADV-N is visible to validate-conflict-classification.
#
# Run: bash tests/god-review-s4/test-4b-validator-correctness.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
VBU="${ROOT}/plugins/mega-sdd/scripts/validate-handoff-binding-units.sh"
VCC="${ROOT}/plugins/mega-sdd/scripts/validate-conflict-classification.sh"
for f in "$VBU" "$VCC"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t val4b)"
trap 'rm -rf "$WORK"' EXIT

# mkfix <name> <binding-content> <unit-binding_refs-yaml-lines>
mkfix() {
  local d="$WORK/$1"
  mkdir -p "$d/.mega-sdd/vaults/v1/units"
  printf '%s\n' "$2" > "$d/.mega-sdd/vaults/v1/binding.md"
  { printf -- '---\nunit_id: U-001\nbinding_refs:\n'; printf '%s\n' "$3"; printf -- '---\nbody\n'; } \
    > "$d/.mega-sdd/vaults/v1/units/U-001.md"
  printf '%s' "$d"
}

note "== 4B: handoff-validator correctness =="

# ── BC-GATE-2: prose vocabulary does NOT resolve ──
B_PROSE='# Binding Manifest
### CONFLICT-1 — ticket status enum
- **Vault doc**: 03-data-model.md
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: must be RESOLVED with the security team before release'
F=$(mkfix prose "$B_PROSE" "  - CONFLICT-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "BC-GATE-2: Suggested-action prose 'RESOLVED' does NOT exempt (FAIL kept)" || fail "BC-GATE-2: prose vocabulary opened the gate (rc=$RC)"

B_CHECK='# Binding Manifest
### CONFLICT-1 — auth mismatch
- **Vault doc**: 04-flows.md
- ✅ verified anchor: app/Http/Auth.php:10
- **Verdict**: CONFLICT (BLOCKING)'
F=$(mkfix check "$B_CHECK" "  - CONFLICT-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "BC-GATE-2: benign '✅ verified anchor' bullet does NOT exempt" || fail "BC-GATE-2: checkmark bullet opened the gate (rc=$RC)"

B_HEADRES='# Binding Manifest
### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — auth mismatch
- **Vault doc**: 04-flows.md
- **Verdict**: CONFLICT (BLOCKING)'
F=$(mkfix headres "$B_HEADRES" "  - CONFLICT-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "BC-GATE-2: heading-line ✅ RESOLVED marker resolves" || fail "BC-GATE-2: heading marker not honored (rc=$RC)"

B_LINERES='# Binding Manifest
### CONFLICT-2 — field naming
- **Vault doc**: 03-data-model.md
- **Verdict**: CONFLICT (BLOCKING)
- **Resolution**: ✅ RESOLVED (KEEP_CODE) 2026-07-02 — vault patched to match code'
F=$(mkfix lineres "$B_LINERES" "  - CONFLICT-2")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "BC-GATE-2: dedicated '- **Resolution**:' line resolves" || fail "BC-GATE-2: Resolution line not honored (rc=$RC)"

# ── BC-VAL-6: C-NNN heading with BLOCKING verdict = active conflict ──
B_CNNN='# Binding Manifest
### C-004 (Phase 1 surface): ConsumptionReason enum cases — CONFLICT (BLOCKING)
- **Vault doc**: 03-data-model.md
- **Verdict**: CONFLICT (BLOCKING)'
F=$(mkfix cnnn "$B_CNNN" "")
J=$(bash "$VBU" --cwd="$F" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && echo "$J" | grep -q '"conflict_id": "C-004"' \
  && ok "BC-VAL-6: C-004 BLOCKING heading detected as active conflict" \
  || fail "BC-VAL-6: C-NNN blocking form still invisible (rc=$RC)"

B_CLAIM='# Binding Manifest
### C-012 field detail
Some notes about the claim; nothing blocking here.'
F=$(mkfix claim "$B_CLAIM" "")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "BC-VAL-6: plain C-NNN claim heading (no BLOCKING verdict) is NOT a conflict" || fail "BC-VAL-6: claim-ID false positive (rc=$RC)"

# ── BC-HANDOFF-1 (+ round-2 FRESH-OQ): numeric form harvested; pending = advisory ──
B_OQNUM='# Binding Manifest
## Open Questions (1)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | which cache TTL? | 04-flows.md:12 | N/A (fresh OQ) |'
F=$(mkfix oqnum "$B_OQNUM" "")
J=$(bash "$VBU" --cwd="$F" 2>/dev/null); RC=$?
[ "$RC" -eq 0 ] && echo "$J" | grep -q '"oq_id_pending_uncited"' && echo "$J" | grep -q '"oq_id": "OQ-001"' \
  && ok "r2 FRESH-OQ: pending OQ-001 uncited → PASS + advisory oq_id_pending_uncited (no resolution ⇒ nothing to cite; was a new deterministic false-block)" \
  || fail "r2 FRESH-OQ: pending fresh OQ handling wrong (rc=$RC): $(echo "$J" | head -4)"
F=$(mkfix oqnumcited "$B_OQNUM" "  - OQ-001")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "BC-HANDOFF-1: cited OQ-001 passes" || fail "BC-HANDOFF-1: cited numeric OQ false-drops (rc=$RC)"
# LIVE-section OQ (woven into Suggested Hard Rules — resolution shaped evidence) keeps the drop
B_OQLIVE='# Binding Manifest
## Suggested Unit Hard Rules
| Source | Suggested rule | Applies to units derived from |
|---|---|---|
| OQ-AR-2 resolution (jwt) | AUTH middleware mandatory | U-derived-from-C-003 |'
F=$(mkfix oqlive "$B_OQLIVE" "")
J=$(bash "$VBU" --cwd="$F" 2>/dev/null); RC=$?
[ "$RC" -eq 1 ] && echo "$J" | grep -q '"oq_id_dropped"' \
  && ok "BC-HANDOFF-1: LIVE-section OQ (evidence-woven) uncited → still a blocking drop" \
  || fail "BC-HANDOFF-1: live-section OQ drop lost (rc=$RC)"

# ── BC-HANDOFF-2: auto-resolved-section OQs are advisory, not blocking ──
B_AR='# Binding Manifest
## Tech-OQ Auto-Resolved (Scan) (1)
| OQ-ID | Category | Question | Scan target | Resolution | Citations |
|---|---|---|---|---|---|
| OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |'
F=$(mkfix ar "$B_AR" "")
J=$(bash "$VBU" --cwd="$F" 2>/dev/null); RC=$?
[ "$RC" -eq 0 ] && ok "BC-HANDOFF-2: auto-resolved OQ-AR-1 uncited → PASS (no false gate-block on clean runs)" || fail "BC-HANDOFF-2: clean brownfield run still false-FAILs (rc=$RC): $(echo "$J" | head -5)"
echo "$J" | grep -q '"oq_id_resolved_uncited"' && ok "BC-HANDOFF-2: surfaced as advisory extra (oq_id_resolved_uncited)" || fail "BC-HANDOFF-2: advisory extra missing"

# live + pending/resolved overlap → LIVE wins (fail-closed)
B_BOTH="$B_AR
## Suggested Unit Hard Rules
| Source | Suggested rule | Applies to |
|---|---|---|
| OQ-AR-1 resolution | phpunit mandatory | all |"
F=$(mkfix both "$B_BOTH" "")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "BC-HANDOFF-2: ID in BOTH live + resolved sections counts as LIVE (fail-closed)" || fail "BC-HANDOFF-2: live/resolved overlap fails open (rc=$RC)"

# ── round-2 marker-grammar regressions (fix-review findings) ──
B_TITLEWORD='# Binding Manifest
### CONFLICT-1 — vault says tickets are auto-resolved by the agent
- **Vault doc**: 03-data-model.md
- **Verdict**: CONFLICT (BLOCKING)'
F=$(mkfix titleword "$B_TITLEWORD" "  - CONFLICT-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "r2 S4-1: domain word 'auto-resolved' in the TITLE does not resolve (FAIL kept)" || fail "r2 S4-1: title vocabulary opened the gate (rc=$RC)"

B_NOTRES='# Binding Manifest
### CONFLICT-1 — auth mismatch
- **Vault doc**: 04-flows.md
- **Verdict**: CONFLICT (BLOCKING)
- **Status**: NOT RESOLVED — blocked on architecture call'
F=$(mkfix notres "$B_NOTRES" "  - CONFLICT-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "r2 S4-2: negated 'Status: NOT RESOLVED' does not resolve (FAIL kept)" || fail "r2 S4-2: negated status opened the gate (rc=$RC)"

B_PROSEMENTION='# Binding Manifest
### C-007 — auth uses Sanctum
Historical note: this superseded the earlier CONFLICT (BLOCKING) once code aligned.'
F=$(mkfix prosemention "$B_PROSEMENTION" "")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && ok "r2 S4-3: mid-prose 'CONFLICT (BLOCKING)' mention in a C-NNN claim block is NOT an active conflict" || fail "r2 S4-3: prose mention false-blocks (rc=$RC)"

# ── BC-ADV-ID: CONFLICT-ADV-N visible to both validators ──
B_ADV='# Binding Manifest
### CONFLICT-ADV-1 — advisor: suspected false CONFIRMED on C-003
- **Vault doc**: 02-architecture.md
- **Verdict**: CONFLICT (BLOCKING)'
F=$(mkfix adv "$B_ADV" "  - CONFLICT-ADV-1")
bash "$VBU" --cwd="$F" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "BC-ADV-ID: handoff validator blocks on unresolved CONFLICT-ADV-1" || fail "BC-ADV-ID: handoff validator misses ADV form (rc=$RC)"
bash "$VCC" --cwd="$F" --quiet >/dev/null 2>&1
CCS="$F/.mega-sdd/.conflict-classification-state.json"
python3 -c "
import json, sys
d = json.load(open('$CCS'))
sys.exit(0 if d.get('status') == 'WARN' and d.get('conflicts_total') == 1 else 1)
" && ok "BC-ADV-ID: classification validator sees CONFLICT-ADV-1 (WARN, total=1 — was SKIP/0)" || fail "BC-ADV-ID: classification still blind: $(cat "$CCS" 2>/dev/null | head -3)"

# classification validator: prose 'resolved' no longer exempts (mirror rule)
B_CCPROSE='# Binding Manifest
### CONFLICT-3 — status vocabulary
- **Vault doc**: 03-data-model.md
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: tickets can be marked resolved by the agent'
F=$(mkfix ccprose "$B_CCPROSE" "  - CONFLICT-3")
bash "$VCC" --cwd="$F" --quiet >/dev/null 2>&1
python3 -c "
import json, sys
d = json.load(open('$F/.mega-sdd/.conflict-classification-state.json'))
sys.exit(0 if d.get('conflicts_resolved') == 0 else 1)
" && ok "BC-GATE-2 (mirror): classification validator no longer counts prose-'resolved' as resolved" || fail "BC-GATE-2 (mirror): prose still resolves in classification validator"

if [ "$FAILED" -eq 0 ]; then note "ALL 4B OK"; else note "4B had failures"; fi
exit $FAILED
