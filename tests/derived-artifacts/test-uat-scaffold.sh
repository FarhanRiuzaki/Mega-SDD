#!/usr/bin/env bash
# test-uat-scaffold.sh — Task 3 (spec 2026-07-23-uat-docpack-and-doc-versioning-
# design.md §3): build-uat-scaffold.sh over a blackbox-style fixture. The UAT
# scaffold is the deterministic sidecar of the UAT doc-pack — every table / id /
# placeholder is script-computed; the model writes only §2 narrative + step rows
# (replacing the `<!-- uat-steps:UAT-NNN -->` markers). A filled execution /
# sign-off cell = a fabricated UAT record → the --check-execution gate catches it.
#
#   1  fragment written; stdout maturity=draft scenarios=2 units=2 sit=absent;
#      WARN_SIT printed (SEOJK entry-gate probe, warn-only)
#   2  §1 flows table (| UAT | TS | Flow | Judul | Tipe |) w/ UAT-001/TS-001
#      alignment; entry-criteria table w/ SEOJK berita-acara-SIT row; exit table
#   3  §2 `### UAT-001 —` block: metadata table placeholders, Mermaid VERBATIM,
#      DoD verbatim, step-table header + `<!-- uat-steps:UAT-001 -->` marker
#   4  §3 RTM row joins F-U-001 ↔ UAT-001 ↔ TS-001 ↔ U-001 w/ Status UAT ______
#   5  §4 berita acara: info table, outstanding-defects row, the exact Keputusan
#      literal, sign-off table (UAT Lead/Business Owner/Product Owner)
#   6  SIT probe: stamped SIT.md maturity=executed → sit=executed, NO WARN_SIT
#   7  multi-scope: 2nd vault scope FE, 1st BE → UAT-BE-001 + Scope col + per-
#      scope sign-off headings
#   8  --check-execution on a well-formed filled UAT.md → exit 0 'uat-execution: clean'
#   9  --check-execution violations: EXECUTION_FILLED / STEPS_MISSING /
#      SIGNOFF_FILLED / BA_FILLED (+ keterangan)
#  10  usage: no --vault → exit 2; bad vault dir → exit 2
#
# Run: bash tests/derived-artifacts/test-uat-scaffold.sh </dev/null
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCR="${ROOT}/plugins/mega-sdd/scripts"
BUILD="${SCR}/build-uat-scaffold.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t uatscaf)"
trap 'rm -rf "$WORK"' EXIT

# ── check 0 (RED anchor): script must exist ──
[ -f "$BUILD" ] || { echo "missing ${BUILD}"; exit 1; }

PROJ="$WORK/proj"
VAULT="$PROJ/.mega-sdd/vaults/v1"
FRAG="$VAULT/uat/.uat-scaffold.md"
mkdir -p "$VAULT/units" "$PROJ/src"
git -C "$PROJ" init -q 2>/dev/null || git init -q "$PROJ"
git -C "$PROJ" config user.email uat@test && git -C "$PROJ" config user.name uat

printf '{"project_name":"UAT Demo Sistem Cuti"}\n' > "$VAULT/vault.json"
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
---

## Goal
Create the leave route marker file.
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

note "== Task 3: build-uat-scaffold =="

# ── 1: default emit — draft maturity, scenario/unit counts, SIT absent + WARN ──
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'maturity=draft' \
   && echo "$OUT" | grep -q 'scenarios=2' \
   && echo "$OUT" | grep -q 'units=2' \
   && echo "$OUT" | grep -q 'sit=absent'; then
  ok "1: stdout maturity=draft scenarios=2 units=2 sit=absent (rc=0)"
else fail "1: stdout wrong rc=$RC out: $OUT"; fi
[ -f "$FRAG" ] && ok "1: fragment written to <vault>/uat/.uat-scaffold.md" \
  || fail "1: fragment not written"
echo "$OUT" | grep -q 'WARN_SIT' && echo "$OUT" | grep -q 'SEOJK 21/2017' \
  && ok "1: WARN_SIT printed (SIT absent — SEOJK entry-gate probe, warn-only)" \
  || fail "1: WARN_SIT missing: $OUT"

# ── 2: §1 flows table + entry/exit criteria ──
grep -qF '| UAT | TS | Flow | Judul | Tipe |' "$FRAG" \
  && ok "2: §1 flows table header" || fail "2: §1 header missing"
grep -qF '| UAT-001 | TS-001 | F-U-001 | Submit leave request | user |' "$FRAG" \
  && ok "2: UAT-001/TS-001 aligned 1:1 (F-U-001)" \
  || fail "2: alignment row wrong: $(grep 'UAT-001' "$FRAG" | head -1)"
grep -qF '| Berita acara SIT diterima dari pengembang (SEOJK 21/2017 §2.3.1.5) | [ ] |' "$FRAG" \
  && ok "2: entry-criteria SEOJK berita-acara-SIT row" || fail "2: SEOJK entry row missing"
grep -qF '**Kriteria masuk (entry):**' "$FRAG" && grep -qF '**Kriteria keluar (exit):**' "$FRAG" \
  && grep -qF '| Berita acara UAT ditandatangani (§4) | [ ] |' "$FRAG" \
  && ok "2: entry + exit criteria tables present" || fail "2: entry/exit tables incomplete"

# ── 3: §2 scenario block ──
grep -qF '### UAT-001 — Submit leave request (F-U-001)' "$FRAG" \
  && ok "3: §2 scenario heading (### UAT-001 —)" || fail "3: §2 heading wrong"
grep -qF '| Prioritas | __________ |' "$FRAG" \
  && grep -qF '| Prasyarat | __________ |' "$FRAG" \
  && grep -qF '| Data uji | __________ |' "$FRAG" \
  && ok "3: metadata table placeholder rows" || fail "3: metadata placeholders missing"
grep -qF '| Unit terkait | U-001 |' "$FRAG" \
  && ok "3: Unit terkait resolved via vault_source (U-001)" || fail "3: Unit terkait wrong"
grep -qF 'A["Fill form"] --> B["Validate dates"]' "$FRAG" \
  && grep -qF 'T(["cron 02:00"]) --> R["Read balances"]' "$FRAG" \
  && ok "3: Mermaid bodies carried VERBATIM" || fail "3: Mermaid not verbatim"
grep -qF -- '- [ ] request row created' "$FRAG" && grep -qF -- '- [x] audit written' "$FRAG" \
  && ok "3: DoD items verbatim (checkbox states preserved)" || fail "3: DoD not verbatim"
grep -qF '| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |' "$FRAG" \
  && ok "3: step-table header" || fail "3: step-table header missing"
grep -qF '<!-- uat-steps:UAT-001 -->' "$FRAG" \
  && ok "3: per-scenario step marker (uat-steps:UAT-001)" || fail "3: marker missing"

# ── 4: §3 RTM ──
grep -qF '| F-U-001 | Submit leave request | UAT-001 | TS-001 | U-001 | __________ |' "$FRAG" \
  && ok "4: §3 RTM joins F-id ↔ UAT ↔ TS ↔ Unit + Status UAT __________" \
  || fail "4: RTM row wrong: $(grep 'F-U-001' "$FRAG" | grep 'UAT-001' | head -1)"

# ── 5: §4 berita acara ──
grep -qF '#### Berita Acara User Acceptance Test' "$FRAG" \
  && ok "5: §4 berita-acara heading" || fail "5: §4 heading missing"
grep -qF '| Periode UAT | __________ s.d. __________ |' "$FRAG" \
  && grep -qF '| 1 | __________ | __________ | __________ |' "$FRAG" \
  && ok "5: info table Periode row + outstanding-defects placeholder row" \
  || fail "5: §4 info/defects rows missing"
grep -qF '**Keputusan:** [ ] Go · [ ] No-Go' "$FRAG" \
  && ok "5: exact Keputusan literal" || fail "5: Keputusan literal wrong"
grep -qF '| UAT Lead | __________ | __________ | __________ | [ ] Diterima · [ ] Ditolak |' "$FRAG" \
  && grep -qF '| Business Owner | __________' "$FRAG" \
  && grep -qF '| Product Owner | __________' "$FRAG" \
  && ok "5: sign-off table all-placeholder rows (UAT Lead/Business Owner/Product Owner)" \
  || fail "5: sign-off rows wrong"

# ── 6: SIT probe — stamped SIT.md maturity=executed ──
mkdir -p "$VAULT/sit"
cat > "$VAULT/sit/SIT.md" <<'EOF'
---
title: SIT fixture
---

<!-- mega-sdd:doc-control
doc: sit
maturity: executed
position: emitted
generated_at: 2026-07-23T00:00:00Z
version: 1.0
status: approved
-->

# SIT
EOF
OUT=$(bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'sit=executed' \
   && ! echo "$OUT" | grep -q 'WARN_SIT'; then
  ok "6: SIT executed → sit=executed, NO WARN_SIT (entry gate satisfied)"
else fail "6: SIT probe wrong rc=$RC out: $OUT"; fi

# ── 7: multi-scope (first vault BE, second FE) ──
VAULT2="$PROJ/.mega-sdd/vaults/v2"
mkdir -p "$VAULT2/units"
printf '{"project_name":"UAT Demo","scope_metadata":{"id":"FE","name":"Frontend"}}\n' > "$VAULT2/vault.json"
cat > "$VAULT2/04-flows.md" <<'MD'
# 04 — Flows

## User flows

### F-U-001: Render leave form

**Flow**:
```mermaid
flowchart TD
    A["Open form"] --> B["Submit"]
```

**Definition of Done**:
- [ ] form renders
MD
cat > "$VAULT2/units/U-101.md" <<'EOF'
---
id: U-101
title: Leave form view
vault_source: 04-flows.md:F-U-001
---

## Goal
Render.
EOF
# make first vault scoped BE
python3 - "$VAULT/vault.json" <<'PY'
import json, sys
p = sys.argv[1]
v = json.load(open(p))
v["scope_metadata"] = {"id": "BE", "name": "Backend"}
json.dump(v, open(p, "w"), indent=1)
PY
OUT=$(bash "$BUILD" --vault="$VAULT" --vault="$VAULT2" --cwd="$PROJ" </dev/null 2>&1); RC=$?
grep -qF '| UAT-BE-001 | TS-BE-001 | F-U-001 | Submit leave request | user |' "$FRAG" \
  && ok "7: scoped ids carry scope (UAT-BE-001 / TS-BE-001)" \
  || fail "7: scoped ids wrong: $(grep 'UAT-BE' "$FRAG" | head -1)"
grep -qF '| Scope | UAT | TS | Flow | Judul | Tipe |' "$FRAG" \
  && ok "7: §1 Scope column prepended in multi-scope" || fail "7: Scope column missing"
grep -qF '### Sign-off — Scope BE' "$FRAG" && grep -qF '### Sign-off — Scope FE' "$FRAG" \
  && ok "7: per-scope sign-off headings (Scope BE + Scope FE)" || fail "7: scope sign-off headings missing"
# 7: --check-execution must stay multi-scope aware — a CLEAN merged UAT.md whose
#    §3 RTM header carries the Scope column must NOT false-positive as RTM_FILLED
MSUAT="$VAULT/uat/UAT.md"
{
  printf -- '---\ntitle: UAT\n---\n\n# UAT\n\n'
  printf '## 1. Ruang Lingkup & Kriteria\n\n'; sed -n '/uat-scaffold:§1 /,/\/uat-scaffold:§1 /p' "$FRAG"
  printf '\n## 2. Skenario UAT\n\n'; sed -n '/uat-scaffold:§2 /,/\/uat-scaffold:§2 /p' "$FRAG"
  printf '\n## 3. Matriks Ketertelusuran\n\n'; sed -n '/uat-scaffold:§3 /,/\/uat-scaffold:§3 /p' "$FRAG"
  printf '\n## 4. Berita Acara\n\n'; sed -n '/uat-scaffold:§4 /,/\/uat-scaffold:§4 /p' "$FRAG"
} > "$MSUAT"
python3 - "$MSUAT" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
row = "| 1 | Buka halaman | Form tampil | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |"
open(p, "w", encoding="utf-8").write(re.sub(r"<!-- uat-steps:UAT-\S+ -->", row, t))
PY
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'uat-execution: clean'; then
  ok "7: --check-execution multi-scope aware — clean merged UAT.md → exit 0 (no RTM_FILLED on Scope-prefixed §3 header)"
else fail "7: multi-scope check false-positive rc=$RC out: $OUT"; fi
rm -f "$MSUAT"
# restore single-scope vault for the remaining checks
printf '{"project_name":"UAT Demo Sistem Cuti"}\n' > "$VAULT/vault.json"
bash "$BUILD" --vault="$VAULT" --cwd="$PROJ" </dev/null >/dev/null 2>&1

# ── build a well-formed assembled UAT.md from the fragment (## N. sections;
#    markers replaced with a filled step row: cells 1-3 written, 4/6/7
#    placeholder, 5 = EXEC_STATUS) ──
UATMD="$VAULT/uat/UAT.md"
build_uat_md() {
  local out="$1"
  {
    printf -- '---\ntitle: UAT\n---\n\n# UAT\n\n'
    printf '## 1. Ruang Lingkup & Kriteria\n\n'
    sed -n '/uat-scaffold:§1 /,/\/uat-scaffold:§1 /p' "$FRAG"
    printf '\n## 2. Skenario UAT\n\n'
    sed -n '/uat-scaffold:§2 /,/\/uat-scaffold:§2 /p' "$FRAG"
    printf '\n## 3. Matriks Ketertelusuran\n\n'
    sed -n '/uat-scaffold:§3 /,/\/uat-scaffold:§3 /p' "$FRAG"
    printf '\n## 4. Berita Acara\n\n'
    sed -n '/uat-scaffold:§4 /,/\/uat-scaffold:§4 /p' "$FRAG"
  } > "$out"
  python3 - "$out" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
row = "| 1 | Buka halaman cuti | Form cuti tampil | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |"
t = re.sub(r"<!-- uat-steps:UAT-\S+ -->", row, t)
open(p, "w", encoding="utf-8").write(t)
PY
}

# ── 8: --check-execution clean ──
build_uat_md "$UATMD"
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'uat-execution: clean'; then
  ok "8: well-formed UAT.md (steps filled, execution cells placeholder) → exit 0 clean"
else fail "8: clean check rc=$RC out: $OUT"; fi

# ── 9: --check-execution violations ──
# (a) filled Status cell 'Pass' → EXECUTION_FILLED
build_uat_md "$UATMD"
sed -i.bak 's/\[ \] Pass · \[ \] Fail · \[ \] Blocked/Pass/' "$UATMD"; rm -f "$UATMD.bak"
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'EXECUTION_FILLED'; then
  ok "9a: filled Status cell 'Pass' → EXECUTION_FILLED, exit 1"
else fail "9a: rc=$RC out: $OUT"; fi

# (b) leftover uat-steps marker → STEPS_MISSING
build_uat_md "$UATMD"
python3 - "$UATMD" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
# put a marker back on the first filled step row
t = t.replace("| 1 | Buka halaman cuti | Form cuti tampil | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |",
              "<!-- uat-steps:UAT-001 -->", 1)
open(p, "w", encoding="utf-8").write(t)
PY
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'STEPS_MISSING'; then
  ok "9b: leftover uat-steps marker → STEPS_MISSING, exit 1"
else fail "9b: rc=$RC out: $OUT"; fi

# (c) filled §4 sign-off Nama → SIGNOFF_FILLED
build_uat_md "$UATMD"
sed -i.bak 's/| UAT Lead | __________ | __________ | __________ |/| UAT Lead | Budi Santoso | __________ | __________ |/' "$UATMD"; rm -f "$UATMD.bak"
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'SIGNOFF_FILLED'; then
  ok "9c: filled §4 sign-off Nama → SIGNOFF_FILLED, exit 1"
else fail "9c: rc=$RC out: $OUT"; fi

# (d) keputusan line altered to [x] Go → BA_FILLED
build_uat_md "$UATMD"
sed -i.bak 's/\*\*Keputusan:\*\* \[ \] Go · \[ \] No-Go/**Keputusan:** [x] Go · [ ] No-Go/' "$UATMD"; rm -f "$UATMD.bak"
OUT=$(bash "$BUILD" --check-execution --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 1 ] && echo "$OUT" | grep -q 'BA_FILLED'; then
  ok "9d: altered keputusan '[x] Go' → BA_FILLED, exit 1"
else fail "9d: rc=$RC out: $OUT"; fi

# keterangan present on a violation run
echo "$OUT" | grep -qi 'KETERANGAN' && echo "$OUT" | grep -qi 'fabrikasi' \
  && ok "9: fabricated-record keterangan (Indonesian) printed after violations" \
  || fail "9: keterangan missing: $OUT"

# ── 10: usage errors ──
OUT=$(bash "$BUILD" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "10: no --vault → exit 2" || fail "10: no-vault rc=$RC (want 2)"
OUT=$(bash "$BUILD" --vault="$PROJ/nope" --cwd="$PROJ" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "10: bad vault dir → exit 2" || fail "10: bad-vault rc=$RC (want 2)"

if [ "$FAILED" -eq 0 ]; then note "PASS: Task 3 uat-scaffold suite"; exit 0
else note "FAIL: Task 3 uat-scaffold suite"; exit 1; fi
