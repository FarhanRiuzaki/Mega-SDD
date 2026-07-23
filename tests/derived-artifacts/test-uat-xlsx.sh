#!/usr/bin/env bash
# test-uat-xlsx.sh — Task 4 (spec 2026-07-23-uat-docpack-and-doc-versioning-
# design.md): build-uat-xlsx.sh renders the assembled <vault>/uat/UAT.md into a
# real .xlsx (a ZIP of OOXML XML) using python3 STDLIB ONLY. The workbook is a
# DERIVED artifact — markdown stays canonical; the xlsx is the tester's fill-in
# surface, so execution cells are written EMPTY (never the markdown placeholder
# literals) and an already-present workbook is NEVER overwritten (a tester may
# have filled it).
#
#   1  exit 0; UAT-v0.1.xlsx created; stdout carries sheets= and version=0.1
#   2  valid zip (testzip() is None) + every xml part is well-formed (ElementTree);
#      namelist has [Content_Types].xml, xl/workbook.xml, xl/styles.xml, >=4 sheets
#   3  workbook.xml sheet names in pinned order: Rekap, RTM, UAT-001, UAT-002
#   4  UAT-001 sheet carries 'Aksi' header + first step action; Rekap carries
#      UAT-001 + UAT-002; RTM carries F-U-001
#   5  execution columns empty-by-construction — UAT-001 sheet xml contains NO
#      '__________' placeholder literal (blank cells for the tester to fill)
#   6  refuse-overwrite — second run → exit 3, REFUSE line, file sha unchanged
#   7  version naming — sidecar {"version":"0.3"} → new run makes UAT-v0.3.xlsx
#      alongside an untouched UAT-v0.1.xlsx
#   8  usage — missing UAT.md → exit 2; UAT.md without any '### UAT-' block → exit 1
#
# Run: bash tests/derived-artifacts/test-uat-xlsx.sh </dev/null
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCR="${ROOT}/plugins/mega-sdd/scripts"
BUILD="${SCR}/build-uat-xlsx.sh"
SCAFFOLD="${SCR}/build-uat-scaffold.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
ok()   { printf '  \342\234\223 %s\n' "$*"; }
fail() { printf '  \342\234\227 FAIL: %s\n' "$*"; FAILED=1; }
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t uatxlsx)"
trap 'rm -rf "$WORK"' EXIT

# ── check 0 (RED anchor): script must exist ──
[ -f "$BUILD" ] || { echo "missing ${BUILD}"; exit 1; }

PROJ="$WORK/proj"
VAULT="$PROJ/.mega-sdd/vaults/v1"
FRAG="$VAULT/uat/.uat-scaffold.md"
UATMD="$VAULT/uat/UAT.md"
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
---

## Goal
Create the leave route marker file.
EOF
cat > "$VAULT/units/U-002.md" <<'EOF'
---
id: U-002
title: Accrual job
vault_source: 04-flows.md:F-S-002
---

## Goal
Create the accrual marker file.
EOF
git -C "$PROJ" add -A && git -C "$PROJ" commit -qm "chore: fixture baseline" >/dev/null 2>&1

# ── build the deterministic scaffold fragment, then assemble a minimal UAT.md ──
bash "$SCAFFOLD" --vault="$VAULT" --cwd="$PROJ" </dev/null >/dev/null 2>&1

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
} > "$UATMD"
# Replace each `<!-- uat-steps:UAT-NNN -->` marker with two placeholder-literal
# step rows (cells 1-3 written, execution cells 4-7 are the markdown placeholders
# — the xlsx render must blank them).
python3 - "$UATMD" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
rows = ("| 1 | Buka halaman cuti | Form cuti tampil | __________ | "
        "[ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |\n"
        "| 2 | Isi tanggal cuti | Tanggal tervalidasi | __________ | "
        "[ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |")
t = re.sub(r"<!-- uat-steps:UAT-\S+ -->", rows, t)
open(p, "w", encoding="utf-8").write(t)
PY

note "== Task 4: build-uat-xlsx =="

UATX="$VAULT/uat/UAT-v0.1.xlsx"

# ── 1: default render → exit 0, UAT-v0.1.xlsx, stdout sheets=/version=0.1 ──
OUT=$(bash "$BUILD" --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'sheets=' \
   && echo "$OUT" | grep -q 'version=0.1'; then
  ok "1: stdout carries sheets= and version=0.1 (rc=0)"
else fail "1: stdout/rc wrong rc=$RC out: $OUT"; fi
[ -f "$UATX" ] && ok "1: UAT-v0.1.xlsx written" || fail "1: UAT-v0.1.xlsx not created"

# ── 2: valid zip + well-formed XML + required parts + >=4 sheets ──
python3 - "$UATX" <<'PY'
import sys, zipfile
import xml.etree.ElementTree as ET
z = zipfile.ZipFile(sys.argv[1])
assert z.testzip() is None, "CRC failure in zip"
names = z.namelist()
for part in ("[Content_Types].xml", "xl/workbook.xml", "xl/styles.xml"):
    assert part in names, "missing part: %s" % part
sheets = [n for n in names if n.startswith("xl/worksheets/sheet") and n.endswith(".xml")]
assert len(sheets) >= 4, "want >=4 worksheet parts, got %d" % len(sheets)
# every xml/rels part must be well-formed (the escaping class testzip cannot see)
for n in names:
    if n.endswith((".xml", ".rels")):
        ET.fromstring(z.read(n))
print("ZIP_OK")
PY
if [ $? -eq 0 ]; then
  ok "2: valid zip, well-formed XML parts, required parts + >=4 sheets"
else fail "2: zip/xml validation failed"; fi

# ── helper: dump a named sheet's xml (name -> sheetN.xml via workbook order) ──
dump_sheet() { # $1=zip $2=sheetname
  python3 - "$1" "$2" <<'PY'
import sys, zipfile, re
z = zipfile.ZipFile(sys.argv[1])
wb = z.read("xl/workbook.xml").decode("utf-8")
names = re.findall(r'<sheet name="([^"]+)"', wb)
idx = names.index(sys.argv[2])
sys.stdout.write(z.read("xl/worksheets/sheet%d.xml" % (idx + 1)).decode("utf-8"))
PY
}

# ── 3: pinned sheet order ──
ORDER=$(python3 - "$UATX" <<'PY'
import sys, zipfile, re
z = zipfile.ZipFile(sys.argv[1])
wb = z.read("xl/workbook.xml").decode("utf-8")
print(" ".join(re.findall(r'<sheet name="([^"]+)"', wb)))
PY
)
if [ "$ORDER" = "Rekap RTM UAT-001 UAT-002" ]; then
  ok "3: sheet order pinned (Rekap RTM UAT-001 UAT-002)"
else fail "3: sheet order wrong: '$ORDER'"; fi

# ── 4: content greps ──
S1=$(dump_sheet "$UATX" "UAT-001")
REKAP=$(dump_sheet "$UATX" "Rekap")
RTM=$(dump_sheet "$UATX" "RTM")
if echo "$S1" | grep -q 'Aksi' && echo "$S1" | grep -q 'Buka halaman cuti'; then
  ok "4: UAT-001 sheet carries 'Aksi' header + first step action"
else fail "4: UAT-001 content missing header/action"; fi
if echo "$REKAP" | grep -q 'UAT-001' && echo "$REKAP" | grep -q 'UAT-002'; then
  ok "4: Rekap sheet lists UAT-001 + UAT-002"
else fail "4: Rekap missing scenario ids"; fi
echo "$RTM" | grep -q 'F-U-001' \
  && ok "4: RTM sheet carries F-U-001" || fail "4: RTM missing F-U-001"

# ── 5: execution cells empty-by-construction (no placeholder literal) ──
if echo "$S1" | grep -q '__________'; then
  fail "5: UAT-001 sheet still carries '__________' placeholder"
else ok "5: UAT-001 execution cells blank (no '__________' literal)"; fi

# ── 6: refuse-overwrite (never clobber a tester-filled workbook) ──
SHA1=$(shasum -a 256 "$UATX" | cut -d' ' -f1)
OUT=$(bash "$BUILD" --vault="$VAULT" </dev/null 2>&1); RC=$?
SHA2=$(shasum -a 256 "$UATX" | cut -d' ' -f1)
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q 'REFUSE' && [ "$SHA1" = "$SHA2" ]; then
  ok "6: existing UAT-v0.1.xlsx → exit 3, REFUSE line, file unchanged"
else fail "6: refuse lane wrong rc=$RC sha_eq=$([ "$SHA1" = "$SHA2" ] && echo y || echo n) out: $OUT"; fi

# ── 7: version naming from sidecar ──
printf '{"schema":1,"doc":"uat","version":"0.3","status":"draft","history":[]}\n' \
  > "$VAULT/uat/.doc-history.json"
OUT=$(bash "$BUILD" --vault="$VAULT" </dev/null 2>&1); RC=$?
if [ "$RC" -eq 0 ] && [ -f "$VAULT/uat/UAT-v0.3.xlsx" ] && [ -f "$UATX" ] \
   && echo "$OUT" | grep -q 'version=0.3'; then
  ok "7: sidecar version 0.3 → UAT-v0.3.xlsx alongside untouched UAT-v0.1.xlsx"
else fail "7: version-named render wrong rc=$RC out: $OUT"; fi
[ "$SHA1" = "$(shasum -a 256 "$UATX" | cut -d' ' -f1)" ] \
  && ok "7: UAT-v0.1.xlsx untouched by the 0.3 run" || fail "7: UAT-v0.1.xlsx was modified"

# ── 8: usage — missing UAT.md → exit 2; scenario-less UAT.md → exit 1 (FRESH vault
#      so neither an existing target nor a sidecar masks the parse lane) ──
VAULT8="$PROJ/.mega-sdd/vaults/v8"
mkdir -p "$VAULT8/uat"
OUT=$(bash "$BUILD" --vault="$VAULT8" </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "8: missing UAT.md → exit 2" || fail "8: missing-UAT rc=$RC (want 2)"
printf -- '---\ntitle: UAT\n---\n\n# UAT\n\n## 2. Skenario\n\nNo scenarios here.\n' \
  > "$VAULT8/uat/UAT.md"
OUT=$(bash "$BUILD" --vault="$VAULT8" </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && ok "8: UAT.md without any '### UAT-' block → exit 1" \
  || fail "8: no-scenario rc=$RC (want 1) out: $OUT"

if [ "$FAILED" -eq 0 ]; then note "PASS: Task 4 uat-xlsx suite"; exit 0
else note "FAIL: Task 4 uat-xlsx suite"; exit 1; fi
