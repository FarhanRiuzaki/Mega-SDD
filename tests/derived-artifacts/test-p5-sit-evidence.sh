#!/usr/bin/env bash
# test-p5-sit-evidence.sh — P5 (v5 spec 2026-07-19-v5-execution-spec.md P5 row +
# decisions 5/9/10; research §4 "emit-sit"): build-sit-evidence.sh over a
# blackbox-style fixture with REAL evidence artifacts (acceptance.json written by
# the shipped run-acceptance-tests.sh B4 writer; postflight.json by the shipped
# run-postflight-scan.sh B1 writer).
#
#   1  maturity=planned before any evidence; §4 rows are [Pending — bolt U-XXX
#      belum dieksekusi]; NOTHING invented (no pass verdict anywhere)
#   2  TS id derivation 1:1 from F-*-NNN (TS-001 ← F-U-001, TS-002 ← F-S-002);
#      Mermaid carried VERBATIM; DoD items carried verbatim as expected outcomes
#   3  TC traceability rows TC ↔ TS ↔ F-id ↔ unit id from acceptance_test[]
#   4  REAL evidence: run-acceptance-tests.sh executes U-001 → §4.1 rows carry
#      status/rc/retried/output_head from the artifact; U-002 still Pending →
#      maturity=partial; pending_manual entry surfaced as a manual-test row
#   5  full coverage (U-002 executed too) → maturity=executed; postflight (B1)
#      row present from the real writer
#   6  sign-off: fragment body rows are placeholder LITERALS; --check-signoff
#      PASSes on a placeholder SIT.md and FAILs (exit 1, SIGNOFF_FILLED +
#      keterangan) on a model-filled row — the fabricated-record gate
#   7  multi-scope (decision 10): scoped vault → TS-BE-NNN ids + per-scope
#      sign-off heading
#
# Run: bash tests/derived-artifacts/test-p5-sit-evidence.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCR="${ROOT}/plugins/mega-sdd/scripts"
BUILD="${SCR}/build-sit-evidence.sh"
ACC="${SCR}/run-acceptance-tests.sh"
PF="${SCR}/run-postflight-scan.sh"
for f in "$BUILD" "$ACC" "$PF"; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t p5sit)"
trap 'rm -rf "$WORK"' EXIT

PROJ="$WORK/proj"
VAULT="$PROJ/.mega-sdd/vaults/v1"
FRAG="$VAULT/sit/.sit-evidence.md"
mkdir -p "$VAULT/units" "$PROJ/src"
git -C "$PROJ" init -q 2>/dev/null || git init -q "$PROJ"
git -C "$PROJ" config user.email p5@test && git -C "$PROJ" config user.name p5

printf '{"project_name":"p5-sit"}\n' > "$VAULT/vault.json"
cat > "$VAULT/04-flows.md" <<'MD'
# 04 — Flows

## User flows

### F-U-001: Submit leave request

**Flow**:
```mermaid
flowchart TD
    A["Fill form"] --> B["Validate dates"]
    B --> C["Create leave_request"]
```

**Definition of Done**:
- [ ] request row created
- [x] audit written

**Source**: PRD §3.1 (AC1-1)

## System flows

### F-S-002: Nightly accrual

**Flow**:
```mermaid
flowchart TD
    T(["cron 02:00"]) --> R["Read balances"]
```

**Definition of Done**:
- [ ] balances updated

**Source**: PRD §4
MD

cat > "$VAULT/units/U-001.md" <<'EOF'
---
id: U-001
title: Leave submit route
vault_source: 04-flows.md:F-U-001
target_files:
  - path: src/app.txt
    operation: create
acceptance_test:
  - type: test
    command: "cat src/app.txt"
    expects: "leave-route"
  - type: manual
    desc: "Verifikasi visual form cuti di browser"
---

## Goal
Create the leave route marker file.

## Hard rules
- file src/app.txt MUST exist after bolt
  Source: fixture rule
EOF
cat > "$VAULT/units/U-002.md" <<'EOF'
---
id: U-002
title: Accrual job
vault_source: 04-flows.md:F-S-002
target_files:
  - path: src/accrual.txt
    operation: create
acceptance_test:
  - type: test
    command: "cat src/accrual.txt"
    expects: "accrual"
---

## Goal
Create the accrual marker file.
EOF
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: fixture baseline"

note "== P5: build-sit-evidence =="

# ── 1: planned maturity — zero evidence, Pending rows, nothing invented ──
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'maturity=planned' \
  && ok "1: no evidence → maturity=planned (rc=0)" || fail "1: rc=$RC out: $OUT"
grep -q '\[Pending — bolt U-001 belum dieksekusi\]' "$FRAG" \
  && grep -q '\[Pending — bolt U-002 belum dieksekusi\]' "$FRAG" \
  && ok "1: absent evidence → literal [Pending — bolt U-XXX belum dieksekusi] rows" \
  || fail "1: Pending rows missing"
sed -n '/sit-evidence:§4/,/\/sit-evidence:§4/p' "$FRAG" | grep -qE '\| (pass|fail) \|' \
  && fail "1: §4 contains an invented verdict with no artifact present" \
  || ok "1: §4 carries NO invented pass/fail verdict (anti-fabrication)"

# ── 2: TS derivation + Mermaid/DoD verbatim ──
grep -q '^### TS-001 — Submit leave request (F-U-001)$' "$FRAG" \
  && grep -q '^### TS-002 — Nightly accrual (F-S-002)$' "$FRAG" \
  && ok "2: TS ids derived 1:1 from F-*-NNN (TS-001 ← F-U-001, TS-002 ← F-S-002)" \
  || fail "2: TS headings wrong"
grep -qF 'A["Fill form"] --> B["Validate dates"]' "$FRAG" \
  && grep -qF 'T(["cron 02:00"]) --> R["Read balances"]' "$FRAG" \
  && ok "2: Mermaid bodies carried VERBATIM" || fail "2: Mermaid not verbatim"
grep -q '^- \[ \] request row created$' "$FRAG" && grep -q '^- \[x\] audit written$' "$FRAG" \
  && ok "2: DoD items verbatim as expected outcomes (checkbox states preserved)" \
  || fail "2: DoD items not verbatim"

# ── 3: TC traceability matrix ──
grep -q '| TC-001 | TS-001 | F-U-001 | U-001 | test | `cat src/app.txt` |' "$FRAG" \
  && ok "3: TC row carries TC ↔ TS ↔ F-id ↔ unit traceability + command" \
  || fail "3: TC-001 traceability row wrong: $(grep 'TC-001' "$FRAG" | head -1)"
grep -q '| TC-003 | TS-002 | F-S-002 | U-002 |' "$FRAG" \
  && ok "3: numbering continues across units (TC-003 for U-002)" \
  || fail "3: TC numbering wrong: $(grep 'U-002' "$FRAG" | head -2)"

# ── 4: REAL B4 evidence for U-001 (shipped writer) → partial + manual row ──
printf 'leave-route\n' > "$PROJ/src/app.txt"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "feat(U-001): leave route marker"
bash "$ACC" --cwd="$PROJ" --unit=U-001 </dev/null >/dev/null 2>&1; RC=$?
[ "$RC" -eq 0 ] && [ -f "$VAULT/bolts/U-001/acceptance.json" ] \
  && ok "4: run-acceptance-tests.sh recorded real U-001 evidence" \
  || fail "4: B4 writer rc=$RC"
bash "$PF" --cwd="$PROJ" --unit=U-001 </dev/null >/dev/null 2>&1 || true
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'maturity=partial' \
  && ok "4: partial coverage (1/2 units) → maturity=partial" || fail "4: rc=$RC out: $OUT"
grep -q '| U-001 | 1 (test) | `cat src/app.txt` | pass | 0 | tidak |' "$FRAG" \
  && ok "4: §4.1 row carries status/rc/retried from the real artifact" \
  || fail "4: acceptance row wrong: $(grep 'U-001 | 1' "$FRAG" | head -1)"
grep -q 'Verifikasi visual form cuti di browser | MENUNGGU EKSEKUSI MANUAL |' "$FRAG" \
  && ok "4: pending_manual entry surfaced as a manual-test row awaiting execution" \
  || fail "4: manual row missing"
grep -q '\[Pending — bolt U-002 belum dieksekusi\]' "$FRAG" \
  && ok "4: U-002 still honest-Pending" || fail "4: U-002 Pending row lost"
grep -q '`bolts/U-001/acceptance.json` (sha256: `pending`)' "$FRAG" \
  && ok "4: §4 cites only EXISTING evidence artifacts (pending stamp literal)" \
  || fail "4: §4 citation footer wrong"

# ── 5: full coverage → executed; B1 row present ──
printf 'accrual\n' > "$PROJ/src/accrual.txt"
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "feat(U-002): accrual marker"
bash "$ACC" --cwd="$PROJ" --unit=U-002 </dev/null >/dev/null 2>&1
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'maturity=executed' \
  && ok "5: full passing coverage → maturity=executed" || fail "5: rc=$RC out: $OUT"
grep -q '| U-001 | pass | 1 |' "$FRAG" \
  && ok "5: §4.3 B1 postflight verdict row from the real writer" \
  || fail "5: postflight row wrong: $(sed -n '/4.3/,/4.4/p' "$FRAG" | grep 'U-001')"

# ── 6: sign-off placeholder grammar — the fabricated-record gate ──
grep -q '| QA Lead | __________ | __________ | __________ | \[ \] Diterima · \[ \] Ditolak |' "$FRAG" \
  && ok "6: fragment sign-off body rows are placeholder LITERALS" \
  || fail "6: placeholder rows wrong"
mkdir -p "$VAULT/sit"
{ printf -- '---\ntitle: SIT fixture\n---\n\n# SIT\n\n## 5. Sign-off\n\n'
  sed -n '/sit-evidence:§5/,/\/sit-evidence:§5/p' "$FRAG" | grep '^|'
} > "$VAULT/sit/SIT.md"
OUT=$(bash "$BUILD" --check-signoff --vault="$VAULT" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "6: --check-signoff PASSes on placeholder-literal rows" \
  || fail "6: clean check rc=$RC out: $OUT"
sed -i.bak 's/| QA Lead | __________ | __________ | __________ |/| QA Lead | Budi Santoso | 2026-07-19 | (ttd) |/' "$VAULT/sit/SIT.md"
OUT=$(bash "$BUILD" --check-signoff --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'SIGNOFF_FILLED' && echo "$OUT" | grep -q 'FABRICATED'; then
  ok "6: GATE FIRED — filled sign-off row → exit 1 + SIGNOFF_FILLED + fabricated-record keterangan"
else fail "6: filled row not blocked rc=$RC out: $OUT"; fi
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && ok "6: default mode also refuses re-emission over a forged SIT.md (exit 1)" \
  || fail "6: default-mode guard rc=$RC"
mv "$VAULT/sit/SIT.md.bak" "$VAULT/sit/SIT.md"

# ── 7: multi-scope ids (decision 10) ──
python3 - "$VAULT/vault.json" <<'PY'
import json, sys
p = sys.argv[1]
v = json.load(open(p))
v["scope_metadata"] = {"id": "BE", "name": "Backend"}
json.dump(v, open(p, "w"), indent=1)
PY
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
grep -q '^### TS-BE-001 — Submit leave request (F-U-001)$' "$FRAG" \
  && grep -q '| TC-BE-001 | TS-BE-001 | F-U-001 | U-001 |' "$FRAG" \
  && ok "7: scoped vault → TS-BE-NNN / TC-BE-NNN ids carry the scope" \
  || fail "7: scoped ids wrong: $(grep 'TS-BE' "$FRAG" | head -2)"
grep -q '^### Sign-off — Scope BE$' "$FRAG" \
  && ok "7: per-scope sign-off table heading" || fail "7: scope sign-off heading missing"

if [ "$FAILED" -eq 0 ]; then note "PASS: P5 sit-evidence suite"; exit 0
else note "FAIL: P5 sit-evidence suite"; exit 1; fi
