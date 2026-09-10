#!/usr/bin/env bash
# v8 P1.f (spec 2026-09-10 App. F7; owner gate 2026-09-10 P1 ship condition):
# replay of the 10 CONFLICT classes the classic bind caught on the simkredit field
# run (training-nextjs binding.md rows C-001..C-004, C-006, C-007, C-020..C-023)
# through the JIT path: unit ## Claims → derive-unit-claims → write-unit-binding →
# validate-handoff-binding-units --units= → conflict_unresolved for ALL TEN,
# zero CONFIRMED-by-absence.
# Boundary (stated, not hidden): the four filesystem-shaped classes are verdicted by
# the script from a mini fixture repo; the six content-shaped classes (missing
# created_at ×4, money type, enum arity, field rename, JWT shape) are `text` claims
# — the model ladder E3 judges them at run time, so here they are replayed through
# the ladder's OUTPUT contract (--verdicts with an anchor), which is exactly what the
# writer + gate consume. What this proves: every class the field run produced flows
# through JIT to a blocking drop; what it cannot prove offline: the model's judgment.
# Run: bash tests/jit-bind/test-simkredit-conflict-replay.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/simkredit"; mkdir -p "$V/units" "$T/apps/api/prisma" "$T/apps/api/src/auth" "$T/apps/web/src/libs" "$T/apps/web/src/app/(blank-layout-pages)/register"
( cd "$T" && git init -q . \
  && printf 'model User {\n  id Int @id\n  nip String\n  password_hash String\n}\nmodel Product {\n  id Int @id\n  annual_rate BigInt\n}\nenum SimulationStatus { DRAFT SUBMITTED }\n' > apps/api/prisma/schema.prisma \
  && printf 'export const refresh = () => {}\n' > apps/api/src/auth/refresh.ts \
  && printf 'export const login = (username: string) => ({ roles: [], permissions: [] })\n' > apps/web/src/libs/auth.ts \
  && printf 'export default function Register() {}\n' > 'apps/web/src/app/(blank-layout-pages)/register/page.tsx' \
  && git add -A && git -c user.email=t@t -c user.name=t commit -qm seed )
cat > "$V/units/U-001.md" <<'MD'
---
id: U-001
title: simkredit replay — the ten field CONFLICT classes
task_type: extend
vault_source: model.md#user
target_files:
  - path: apps/api/prisma/schema.prisma
    operation: modify
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# u

## Claims
- C-U001-01 "User has created_at" — expect: prisma User.created_at column
- C-U001-02 "Product has created_at" — expect: prisma Product.created_at column
- C-U001-03 "Simulation has created_at" — expect: prisma Simulation.created_at column
- C-U001-04 "Installment has created_at" — expect: prisma Installment.created_at column
- C-U001-06 "money columns are Decimal(18,2)" — expect: prisma money columns Decimal(18,2)
- C-U001-07 "SimulationStatus has 3 values" — expect: prisma enum SimulationStatus 3 values
- C-U001-20 "login sends nip, not username" — expect: auth.ts login payload uses nip
- C-U001-21 "no refresh-rotation endpoint in the contract" — expect: apps/api/src/auth/refresh.ts — must-not-exist
- C-U001-22 "register page is deleted" — expect: apps/web/src/app/(blank-layout-pages)/register/page.tsx — must-not-exist
- C-U001-23 "JWT carries a single role" — expect: auth.ts JWT single role claim
MD
OUT="$(bash "$S/derive-unit-claims.sh" --cwd="$T" --vault="$V" --units=U-001 2>&1)"; RC=$?
W="$V/bolts/_wave-claims.json"
[ $RC -eq 0 ] && echo "$OUT" | grep -q '"text_claims": 8' && echo "$OUT" | grep -q '"fs_claims": 3' && pass "a: derive — 8 text (content-shaped) + 3 fs claims (2 must-not-exist + target modify)" || fail "a: derive counts wrong ($OUT)"
# ladder E3 output contract for the eight content-shaped classes (anchored CONFLICTs, as the field binding recorded them)
cat > "$T/verdicts.json" <<'EOF'
{"C-U001-01":{"verdict":"CONFLICT","state":"PARTIAL_FIELDS_MISSING","anchor":"apps/api/prisma/schema.prisma:1","confidence":"high","evidence":"ADD: [created_at]"},
 "C-U001-02":{"verdict":"CONFLICT","state":"PARTIAL_FIELDS_MISSING","anchor":"apps/api/prisma/schema.prisma:6","confidence":"high","evidence":"ADD: [created_at]"},
 "C-U001-03":{"verdict":"CONFLICT","state":"PARTIAL_FIELDS_MISSING","anchor":"apps/api/prisma/schema.prisma:1","confidence":"high","evidence":"model absent — ADD: [created_at]"},
 "C-U001-04":{"verdict":"CONFLICT","state":"PARTIAL_FIELDS_MISSING","anchor":"apps/api/prisma/schema.prisma:1","confidence":"high","evidence":"model absent — ADD: [created_at]"},
 "C-U001-06":{"verdict":"CONFLICT","state":"IMPLEMENTED","anchor":"apps/api/prisma/schema.prisma:8","confidence":"high","evidence":"type mismatch BigInt vs Decimal(18,2)"},
 "C-U001-07":{"verdict":"CONFLICT","state":"IMPLEMENTED","anchor":"apps/api/prisma/schema.prisma:10","confidence":"high","evidence":"enum has 2 values, vault requires 3"},
 "C-U001-20":{"verdict":"CONFLICT","state":"IMPLEMENTED","anchor":"apps/web/src/libs/auth.ts:1","confidence":"high","evidence":"code sends username, vault requires nip"},
 "C-U001-23":{"verdict":"CONFLICT","state":"IMPLEMENTED","anchor":"apps/web/src/libs/auth.ts:1","confidence":"high","evidence":"roles[] + permissions[] vs single role"}}
EOF
bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-001 --claims="$W" --verdicts="$T/verdicts.json" >/dev/null 2>&1; RC=$?
python3 - "$V/bolts/U-001/binding.json" "$RC" <<'EOF' && pass "b: writer — 10/10 field CONFLICT classes recorded CONFLICT (2 fs by script, 8 via the ladder contract), 0 CONFIRMED-by-absence, target-modify fs claim CONFIRMED" || fail "b: verdict set wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2]); assert rc == 0
by = {c["id"]: c for c in d["claims"]}
ten = ["C-U001-01","C-U001-02","C-U001-03","C-U001-04","C-U001-06","C-U001-07","C-U001-20","C-U001-21","C-U001-22","C-U001-23"]
assert all(by[i]["verdict"] == "CONFLICT" for i in ten), {i: by[i]["verdict"] for i in ten}
assert by["C-U001-21"]["evidence"].startswith("fs:") and by["C-U001-22"]["evidence"].startswith("fs:")
assert all(by[i]["anchor"] for i in ten if by[i]["kind"] == "text"), "text CONFLICTs must carry anchors"
assert d["summary"]["CONFLICT"] == 10 and d["summary"]["OQ"] == 0, d["summary"]
EOF
bash "$S/validate-handoff-binding-units.sh" --cwd="$T" --units=U-001 --quiet >/dev/null 2>&1; RC=$?
python3 - "$T/.mega-sdd/.validation-blockers.json" "$RC" <<'EOF' && pass "c: gate — --units=U-001 → FAIL with 10 conflict_unresolved drops sourced from bolts/U-001/binding.json (the hook denies on this)" || fail "c: gate drops wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
ds = [x for x in d["drops"] if x["type"] == "conflict_unresolved" and x.get("unit_id") == "U-001"]
assert d["status"] == "FAIL" and rc == 1 and len(ds) == 10 and all("binding.json" in x["source_binding"] for x in ds), (d["status"], len(ds))
EOF
# d: resolving all ten via the writer clears the unit-scoped gate
for i in 01 02 03 04 06 07 20 21 22 23; do bash "$S/write-unit-binding.sh" --cwd="$T" --vault="$V" --unit=U-001 --resolve=C-U001-$i=KEEP_VAULT --by=user >/dev/null 2>&1 || fail "d: resolve C-U001-$i failed"; done
bash "$S/validate-handoff-binding-units.sh" --cwd="$T" --units=U-001 --quiet >/dev/null 2>&1; RC=$?
[ $RC -eq 0 ] && pass "d: all ten resolved KEEP_VAULT via the sole writer → gate PASS" || fail "d: gate still FAIL after resolutions (rc=$RC)"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
