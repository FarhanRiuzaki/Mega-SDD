#!/usr/bin/env bash
# test-blackbox-layout2.sh — v7 Fase 3 closing proof (i): END-TO-END on the
# CLINIC vault in the layout-2 4-file layout, down to units.
#
#   L1  seed: git project + the clinic 7-file vault (grounded in sample-prd-clinic.md)
#   L2  migrate-paths --vault-layout --apply  → 4 files, derive PASS, re-bind msg
#   L4  live validators on layout-2 writes (vault-flows Mermaid mandate, vault-oqs)
#   L5  binding with layout-2 vault_source refs (+1 active CONFLICT)
#       → derive-binding-json
#   L6  CONFLICT gate LIVE on layout-2: validate-handoff-binding-units BLOCKS
#       (conflict_unresolved), resolve → re-derive → conflict_unresolved clears
#   L7  unit write (vault_source: flows.md:F-U-001; binding_refs carries the
#       resolved CONFLICT-1) → validate-unit-spec PASS → the binding->units
#       gate PASSES (exit 0)
#   L8  validate-flow-coverage locates the layout-2 vault + units
#
# 9.0 P1b: derive-claims-ledger.sh, make-bound.sh and validate-binding-json.sh
# were deleted (no surviving executor). L3 (the ledger) was retired with its
# script; the L5 parity leg went with the validator; L6 keeps the CONFLICT gate
# on layout-2, re-pointed to its surviving carrier validate-handoff-binding-units
# (invariant #2), and dropped the bound/ doc-set + BIND-annotation assertions.
#
# Run: bash tests/blackbox/test-blackbox-layout2.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SCR="$REPO/plugins/mega-sdd/scripts"
CFIX="$REPO/tests/migrate-paths/fixtures/clinic-vault7"

rc=0
ok()  { printf '  \342\234\223 %s\n' "$*"; }
bad() { printf '  \342\234\227 FAIL: %s\n' "$*"; rc=1; }
stage(){ echo; echo "===== $1 ====="; }

WORK="$(mktemp -d 2>/dev/null || mktemp -d -t bbl2)"
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/clinic"
VAULT="$PROJ/.mega-sdd/vaults/clinic"

# ── L1 seed ──────────────────────────────────────────────────────────────────
stage "L1 seed: clinic project + 7-file vault"
mkdir -p "$PROJ/src/db/schema" "$PROJ/src/app" "$PROJ/.mega-sdd/vaults"
printf 'export const staff = {};\n' > "$PROJ/src/db/schema/staff.ts"
printf 'export function bookAppointment() {}\n' > "$PROJ/src/app/booking.ts"
cp -R "$CFIX" "$VAULT"
git -C "$PROJ" init -q
git -C "$PROJ" config user.email bb@t && git -C "$PROJ" config user.name bb
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: clinic baseline"
[ -f "$VAULT/00-index.md" ] && ok "clinic 7-file vault seeded" || bad "seed failed"

# ── L2 migrate to layout-2 ───────────────────────────────────────────────────
stage "L2 migrate-paths --vault-layout --apply"
OUT="$(bash "$SCR/migrate-paths.sh" --vault-layout --apply --cwd="$PROJ" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "migration rc=0" || bad "migration rc=$RC: $(echo "$OUT" | tail -3)"
echo "$OUT" | grep -q 'full re-bind required' && ok "mandatory re-bind message printed" || bad "re-bind message missing"
M=1; for f in vault.md model.md flows.md constraints.md vault.json; do [ -f "$VAULT/$f" ] || M=0; done
[ "$M" = 1 ] && [ ! -f "$VAULT/00-index.md" ] && ok "layout-2: 4 files + vault.json, legacy gone" || bad "layout incomplete"
python3 -c "
import json; d=json.load(open('$VAULT/vault.json'))
assert d.get('vault_layout')==2 and len(d['entities'])==4 and len(d['flows'])==3, d.get('vault_layout')
print('  ✓ vault.json: layout 2, 4 entities, 3 flows,', len(d['open_questions']), 'oqs')" || bad "vault.json shape wrong"

# ── L4 live validators on layout-2 writes ────────────────────────────────────
stage "L4 validators: vault-flows + vault-oqs on layout-2"
OUT="$(bash "$SCR/validate-kb.sh" --surface=vault-flows --cwd="$PROJ" --file-path="$VAULT/flows.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "vault-flows Mermaid mandate PASS on flows.md" || bad "vault-flows rc=$RC: $OUT"
# This assertion used to read "PASS on constraints.md" and was VACUOUS: the validator's path
# gate did not know the layout-2 names, exited 0 without checking anything and wrote no state —
# the same blind spot that made `analyze` report PASS on every layout-2 vault. Two real steps now:
#  (a) the validator RUNS on the layout-2 OQ home and catches what the migrated legacy vault
#      really carries — two `[tech / recommend]` OQs with none of the four required fields;
#  (b) those two are "where does the app run" and "is a paid licence acceptable": under the
#      business-only rule that is the stakeholder's call, so the repair is `[business]` — and then
#      the PASS is a real one.
OQST="$PROJ/.mega-sdd/.vault-oqs-state.json"; rm -f "$OQST"
bash "$SCR/validate-vault-oqs.sh" --cwd="$PROJ" --file-path="$VAULT/constraints.md" --quiet </dev/null >/dev/null 2>&1; RC=$?
python3 - "$OQST" "$RC" <<'PYV' && ok "validate-vault-oqs RUNS on layout-2 constraints.md (state written) and flags the 2 underspecified recommend OQs" || bad "vault-oqs did not run / did not flag the migrated vault (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["checked_file"].endswith("constraints.md") and d["status"] == "FAIL" and rc == 1, (d["status"], rc)
under = sorted(i["oq_id"] for i in d["issues"] if i["halt_type"] == "oq_recommend_underspecified")
assert under == ["OQ-CLINIC-005", "OQ-CLINIC-006"], under
PYV
python3 - "$VAULT/constraints.md" <<'PYR'
import re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s2 = re.sub(r"(\*\*OQ-CLINIC-00[56]\*\* \[P[123]\] )\[tech / recommend\]", r"\1[business]", s)
assert s2 != s, "the two tech/recommend OQ lines were not found in constraints.md"
open(p, "w", encoding="utf-8").write(s2)
PYR
bash "$SCR/derive-vault-json.sh" --vault="$VAULT" </dev/null >/dev/null 2>&1 || bad "re-derive after the [business] re-tag failed"
OUT="$(bash "$SCR/validate-vault-oqs.sh" --cwd="$PROJ" --file-path="$VAULT/constraints.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "validate-vault-oqs PASS on constraints.md once hosting + paid-licence are [business] (a real PASS)" || bad "vault-oqs rc=$RC after re-tag: $(printf '%s' "$OUT" | grep -E 'halt_type|detail' | head -4)"

# ── L5 binding with layout-2 refs ────────────────────────────────────────────
stage "L5 binding write (layout-2 vault_source) -> stamp -> derive"
DM_LN=$(grep -n '^Table appointment' "$VAULT/model.md" | head -1 | cut -d: -f1)
FL_LN=$(grep -n '^### F-U-001' "$VAULT/flows.md" | head -1 | cut -d: -f1)
ST_LN=$(grep -n '^Table staff' "$VAULT/model.md" | head -1 | cut -d: -f1)
[ -n "$DM_LN" ] && [ -n "$FL_LN" ] && [ -n "$ST_LN" ] || bad "anchor lines not found (dm=$DM_LN fl=$FL_LN st=$ST_LN)"
write_binding() { # $1 = 1 active conflict / 2 resolved
  local V="CONFLICT" H="### CONFLICT-1 — staff entity collision" R=""
  if [ "$1" = "2" ]; then
    V="CONFIRMED"
    H="### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — staff entity collision"
    R="- **Resolution**: ✅ RESOLVED (KEEP_VAULT) 2026-08-22 — vault correct; code change lands via U-001"
  fi
  cat > "$VAULT/binding.md" <<EOF
---
vault: clinic
codebase_map: .mega-sdd/codebase/codebase-map.md
bound_at: 2026-08-22T00:00:00Z
strict: false
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: $(git -C "$PROJ" rev-parse HEAD)
---

# Binding Manifest

## Summary
- claims_total: 3
- confirmed: 2
- conflict: $([ "$1" = "1" ] && echo 1 || echo 0)
- oq: 0

## Confirmed Claims (2)
- C-001 | model.md:$DM_LN | src/db/schema/staff.ts:1 | appointment entity planned
- C-002 | flows.md:$FL_LN | src/app/booking.ts:1 | booking flow exists

## Implementation State Map (3 — ALWAYS 6 columns; the Field diff cell is \`n/a\` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | PARTIAL | src/db/schema/staff.ts:1 | high | n/a |
| C-002 | CONFIRMED | IMPLEMENTED | src/app/booking.ts:1 | high | (exact match) |
| C-003 | $V | UNKNOWN | src/db/schema/staff.ts:1 | medium | n/a |

## Conflicts ($([ "$1" = "1" ] && echo "1) — BLOCKING" || echo "0)"))

$H
- **Claim**: C-003
- **Vault claim**: vault staff entity owns working_hours (model.md:$ST_LN)
- **Codebase reality**: pre-existing staff schema already defines shape (src/db/schema/staff.ts:1)
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: $([ "$1" = "1" ] && echo "CONFLICT (BLOCKING)" || echo "CONFIRMED")
- **Suggested action**: KEEP_VAULT — vault staff is the target entity (src/db/schema/staff.ts:1)
$R

## Open Questions (0)
EOF
}
write_binding 1
OUT="$(bash "$SCR/derive-binding-json.sh" --vault "$VAULT" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "derive-binding-json (phase-0 stamp) rc=0" || bad "derive rc=$RC: $OUT"

# ── L6 CONFLICT gate LIVE on layout-2 ────────────────────────────────────────
stage "L6 validate-handoff-binding-units: block on CONFLICT, clear once resolved"
BLK="$PROJ/.mega-sdd/.validation-blockers.json"
OUT="$(bash "$SCR/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet </dev/null 2>&1)"; RC=$?
if [ $RC -eq 1 ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d['status']=='FAIL' and [x for x in d['drops'] if x['type']=='conflict_unresolved' and x.get('conflict_id')=='CONFLICT-1'], d" "$BLK" 2>/dev/null; then
  ok "GATE FIRED on layout-2: active CONFLICT-1 blocks the binding->units boundary (exit 1, conflict_unresolved)"
else bad "expected a conflict_unresolved block, rc=$RC: $OUT $(head -c 300 "$BLK" 2>/dev/null)"; fi
write_binding 2
bash "$SCR/derive-binding-json.sh" --vault "$VAULT" </dev/null >/dev/null 2>&1
OUT="$(bash "$SCR/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet </dev/null 2>&1)"; RC=$?
if python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert not [x for x in d['drops'] if x['type']=='conflict_unresolved'], d['drops']" "$BLK" 2>/dev/null; then
  ok "resolved CONFLICT-1 no longer blocks as unresolved (rc=$RC until a unit carries it — L7)"
else bad "resolved binding still conflict_unresolved, rc=$RC: $OUT $(head -c 300 "$BLK" 2>/dev/null)"; fi

# ── L7 unit ──────────────────────────────────────────────────────────────────
stage "L7 unit write (vault_source: flows.md) + validate-unit-spec + binding->units gate"
mkdir -p "$VAULT/units"
cat > "$VAULT/units/U-001.md" <<'EOF'
---
id: U-001
title: Appointment schema + unique booked-slot constraint
vault_source: flows.md:F-U-001
task_type: create
binding_refs:
  - C-001
  - CONFLICT-1
target_files:
  - path: src/db/schema/appointment.ts
    operation: create
acceptance_test:
  - type: test
    command: "test -f src/db/schema/appointment.ts && echo schema present"
    expects: "schema present"
mutability: "INTENT — booking shape follows PRD §Clinic.1 F-U-001"
---

## Goal
Create the appointment Drizzle schema per vault model.md §Entities with the unique (doctor_id, start_time) constraint (BR-002).

## Context (read first)
Per binding C-001 the staff schema exists; this unit adds the appointment table only.

## Anchors
- src/db/schema/staff.ts:1 — staff schema (binding C-001)

## Hard rules
- DO NOT modify src/db/schema/staff.ts
  Source: binding C-001 — Better Auth owns the staff schema per PRD §6.3

## Anti-patterns
- Don't relax the unique (doctor_id, start_time) constraint.

## Implementation steps
Create src/db/schema/appointment.ts per model.md §Entities. Do not touch the staff schema.

## Acceptance criteria
See frontmatter `acceptance_test` (structured authority).
EOF
OUT="$(bash "$SCR/validate-unit-spec.sh" --cwd="$PROJ" --file-path="$VAULT/units/U-001.md" </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "validate-unit-spec PASS on the layout-2 unit" || bad "unit spec rc=$RC: $OUT"
OUT="$(bash "$SCR/validate-handoff-binding-units.sh" --cwd="$PROJ" --quiet </dev/null 2>&1)"; RC=$?
[ $RC -eq 0 ] && ok "binding->units gate PASS on layout-2 once U-001 carries the resolved CONFLICT-1 (rc=0)" \
  || bad "binding->units gate rc=$RC after resolve + unit write: $OUT $(head -c 300 "$BLK" 2>/dev/null)"

# ── L8 flow coverage locates the layout-2 vault ──────────────────────────────
stage "L8 validate-flow-coverage on layout-2"
OUT="$(bash "$SCR/validate-flow-coverage.sh" --cwd="$PROJ" --quiet </dev/null 2>&1)"; RC=$?
ST="$PROJ/.mega-sdd/.flow-coverage-state.json"
if [ -f "$ST" ] && ! grep -q 'no active vault' "$ST"; then
  ok "layout-2 vault located (flows.md + units) — state written (rc=$RC)"
else bad "flow-coverage did not locate the vault: $(head -c 150 "$ST" 2>/dev/null)"; fi

echo
if [ $rc -eq 0 ]; then echo "VERDICT: LAYOUT-2 PIPELINE E2E OK (clinic, down to units)"; else echo "VERDICT: FAILURES PRESENT"; fi
exit $rc
