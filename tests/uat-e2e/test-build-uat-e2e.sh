#!/usr/bin/env bash
# test-build-uat-e2e.sh — pins scripts/build-uat-e2e.sh generation (all-fixme
# skeletons, sha stamps, refuse-overwrite) + --check anchor lint (the
# zero-invented-selector GATE; spec 2026-08-12-playwright-embed-design.md §D2).
# Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
SCRIPT="$P/scripts/build-uat-e2e.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/vault"
mkdir -p "$V/uat"

# Fixture: assembled UAT.md with §2 in the real grammar (xlsx-builder parse shape)
cat > "$V/uat/UAT.md" <<'EOF'
# UAT — Demo

## 1. Pendahuluan

intro

## 2. Skenario & Langkah Uji

### UAT-001 — Login nasabah (F-U-001)

| Field | Nilai |
|---|---|
| Flow | F-U-001 |

| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |
|---|---|---|---|---|---|---|
| 1 | Buka halaman login | Form login tampil | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |
| 2 | Isi kredensial valid | Redirect ke dashboard | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |

### UAT-002 — Daftar transaksi (F-U-002)

| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |
|---|---|---|---|---|---|---|
| 1 | Buka menu transaksi | Tabel transaksi tampil | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |

## 3. RTM

rtm

## 4. Berita Acara

ba
EOF
printf 'scaffold body\n' > "$V/uat/.uat-scaffold.md"

echo "── generation (default mode) ──"
OUT_GEN=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "g0 generation exit 0" || fail "g0 exit $RC: $OUT_GEN"
[ -f "$V/uat/e2e/UAT-001.spec.ts" ] && [ -f "$V/uat/e2e/UAT-002.spec.ts" ] \
  && ok "g1 one spec per scenario" || fail "g1 spec files missing"
if [ -f "$V/uat/e2e/UAT-001.spec.ts" ]; then
  S1="$V/uat/e2e/UAT-001.spec.ts"
  grep -q "test\.fixme('1\. Buka halaman login — manual')" "$S1" && ok "g2 step 1 = fixme with Aksi text" || fail "g2 fixme step missing"
  grep -q "test\.fixme('2\. Isi kredensial valid — manual')" "$S1" && ok "g3 step 2 = fixme" || fail "g3 fixme step 2 missing"
  grep -cq "await page\." "$S1" && fail "g4 generated spec carries a live action (must be all-fixme)" || ok "g4 all-fixme (zero live actions)"
  grep -q "// uat_md_sha256: [0-9a-f]\{64\}" "$S1" && ok "g5 uat_md sha stamped" || fail "g5 uat sha missing"
  grep -q "// scaffold_sha256: [0-9a-f]\{64\}" "$S1" && ok "g6 scaffold sha stamped" || fail "g6 scaffold sha missing"
  grep -q "test\.describe('UAT-001 — Login nasabah'" "$S1" && ok "g7 describe carries id+title" || fail "g7 describe wrong"
fi
[ -f "$V/uat/e2e/.gitignore" ] && grep -q "node_modules/" "$V/uat/e2e/.gitignore" \
  && ok "g8 .gitignore written" || fail "g8 .gitignore missing"
[ -f "$V/uat/e2e/playwright.config.ts" ] && grep -q "PREVIEW_URL" "$V/uat/e2e/playwright.config.ts" \
  && ok "g9 self-contained config reads PREVIEW_URL" || fail "g9 config missing"

echo "── refuse-overwrite (human/model substitutions never clobbered) ──"
# substitute a real action into UAT-001 (simulating the model step)
cat > "$V/uat/e2e/UAT-001.spec.ts" <<'EOF'
// generated-by: build-uat-e2e.sh
// uat_md_sha256: 0000000000000000000000000000000000000000000000000000000000000000
// scaffold_sha256: 0000000000000000000000000000000000000000000000000000000000000000
import { test, expect } from '@playwright/test';
test.describe('UAT-001 — Login nasabah', () => {
  test('1. Buka halaman login', async ({ page }) => {
    await page.goto('/login'); // source: routes/web.php:12
  });
  test.fixme('2. Isi kredensial valid — manual');
});
EOF
OUT_RE=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "r0 re-generation exit 0" || fail "r0 exit $RC"
echo "$OUT_RE" | grep -q "SKIP_EXISTING UAT-001" && ok "r1 SKIP_EXISTING printed" || fail "r1 no skip line: $OUT_RE"
grep -q "page.goto('/login')" "$V/uat/e2e/UAT-001.spec.ts" && ok "r2 substituted spec untouched" || fail "r2 spec clobbered"

echo "── --check anchor lint ──"
mkdir -p "$WORK/routes"
printf '%s\n' 1 2 3 4 5 6 7 8 9 10 11 12 > "$WORK/routes/web.php"
OUT_C1=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --check </dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] && ok "c1 good anchor resolves (exit 0)" || fail "c1 exit $RC: $OUT_C1"
# break the anchor: point at a line beyond EOF
sed -i.bak 's|// source: routes/web.php:12|// source: routes/web.php:99|' "$V/uat/e2e/UAT-001.spec.ts"
OUT_C2=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --check </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT_C2" | grep -q "ANCHOR_UNRESOLVED" && ok "c2 bad anchor → ANCHOR_UNRESOLVED exit 1" || fail "c2 rc=$RC out=$OUT_C2"
# remove the anchor entirely
sed -i.bak 's| // source: routes/web.php:99||' "$V/uat/e2e/UAT-001.spec.ts"
OUT_C3=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --check </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT_C3" | grep -q "ANCHOR_MISSING" && ok "c3 anchorless action → ANCHOR_MISSING exit 1" || fail "c3 rc=$RC out=$OUT_C3"
# all-fixme spec passes
OUT_C4=$(bash "$SCRIPT" --vault="$WORK/v2" --cwd="$WORK" --check </dev/null 2>&1); RC=$?
[ "$RC" -eq 2 ] && ok "c4 missing vault → exit 2 usage" || fail "c4 rc=$RC"

echo "── scoped ids ──"
V2="$WORK/vault2"; mkdir -p "$V2/uat"
cat > "$V2/uat/UAT.md" <<'EOF'
## 2. Skenario

### UAT-BE-001 — API kredit (F-S-001)

| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |
|---|---|---|---|---|---|---|
| 1 | Panggil endpoint | 200 | __________ | [ ] Pass · [ ] Fail · [ ] Blocked | __________ | __________ |

## 3. RTM
EOF
printf 's\n' > "$V2/uat/.uat-scaffold.md"
bash "$SCRIPT" --vault="$V2" --cwd="$WORK" </dev/null >/dev/null 2>&1
[ -f "$V2/uat/e2e/UAT-BE-001.spec.ts" ] && ok "s1 scoped id spec name" || fail "s1 scoped spec missing"

echo "── v: anchor lint — variable indirection (round M2) + pin parity (round M5) ──"
cat > "$V/uat/e2e/UAT-002.spec.ts" <<'EOF'
// generated-by: build-uat-e2e.sh
import { test, expect } from '@playwright/test';
test('1. indirected', async ({ page }) => {
  const btn = page.locator('#totally-invented-selector');
  await btn.click();
});
EOF
OUT_V1=$(bash "$SCRIPT" --vault="$V" --cwd="$WORK" --check </dev/null 2>&1); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT_V1" | grep -q "ANCHOR_MISSING" && ok "v1 locator-variable indirection caught (definition line needs anchor)" || fail "v1 rc=$RC out=$OUT_V1"
# the @playwright/test pin in the script matches the live-arm fixture pin (registry-rot parity)
SCRIPT_PIN=$(grep -oE '@playwright/test": "[0-9.]+' "$SCRIPT" | grep -oE '[0-9.]+$')
FIX_PIN=$(grep -oE '@playwright/test": "[0-9.]+' "$ROOT/tests/uat-e2e/test-uat-run-skips.sh" | grep -oE '[0-9.]+$' | head -1)
[ -n "$SCRIPT_PIN" ] && [ "$SCRIPT_PIN" = "$FIX_PIN" ] && ok "v2 @playwright/test pin parity (script $SCRIPT_PIN == fixture)" || fail "v2 pin drift: script=$SCRIPT_PIN fixture=$FIX_PIN"

bash -n "$SCRIPT" 2>/dev/null && ok "z1 bash -n clean" || fail "z1 syntax"

echo
echo "build-uat-e2e: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
