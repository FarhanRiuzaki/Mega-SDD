#!/usr/bin/env bash
# test-uat-annex-gate.sh — pins the §5 annex integration: check_execution's
# byte-compare against the shared renderer (ANNEX_FORGED — the recompute-at-gate
# doctrine), --annex idempotent rewrite, backward compat for pre-annex docs, and
# the teacher↔template §5 pair (spec 2026-08-12-playwright-embed-design.md §D2).
# Run </dev/null.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
SCAFFOLD="$P/scripts/build-uat-scaffold.sh"
E2E="$P/scripts/build-uat-e2e.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/vault"
mkdir -p "$V/uat"

PLACEHOLDER_CELL="__________"
EXEC_STATUS="[ ] Pass · [ ] Fail · [ ] Blocked"
ANNEX_PLACEHOLDER='_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._'

# clean §1–§4 fixture (human cells all placeholder) — the shapes check_execution pins
write_doc() { # $1 = annex body ('' = none)
cat > "$V/uat/UAT.md" <<EOF
# UAT — Demo

## 1. Pendahuluan

intro

## 2. Skenario & Langkah Uji

### UAT-001 — Login (F-U-001)

| No | Aksi | Expected Result | Actual Result | Status | Defect | Bukti |
|---|---|---|---|---|---|---|
| 1 | Buka login | Form tampil | $PLACEHOLDER_CELL | $EXEC_STATUS | $PLACEHOLDER_CELL | $PLACEHOLDER_CELL |

Pelaksana: $PLACEHOLDER_CELL · Tanggal: $PLACEHOLDER_CELL · Paraf: $PLACEHOLDER_CELL

## 3. RTM

| Flow (F-id) | Skenario | Status |
|---|---|---|
| F-U-001 | UAT-001 | $PLACEHOLDER_CELL |

## 4. Berita Acara

| Field | Nilai |
|---|---|
| Periode UAT | $PLACEHOLDER_CELL s.d. $PLACEHOLDER_CELL |
| Test cycle | $PLACEHOLDER_CELL |
| Referensi SIT | sit/SIT.md — berita acara SIT: $PLACEHOLDER_CELL |

**Keputusan:** [ ] Go · [ ] No-Go

| Peran | Nama | Tanggal | Tanda tangan | Status |
|---|---|---|---|---|
| Business Owner | $PLACEHOLDER_CELL | $PLACEHOLDER_CELL | $PLACEHOLDER_CELL | [ ] Diterima · [ ] Ditolak |
EOF
if [ -n "$1" ]; then printf '\n%s\n' "$1" >> "$V/uat/UAT.md"; fi
}

gate() { bash "$SCAFFOLD" --check-execution --vault="$V" --cwd="$WORK" </dev/null 2>&1; }

echo "── e: pre-annex doc (no §5) → backward compat ──"
write_doc ""
OUT=$(gate); RC=$?
[ "$RC" -eq 0 ] && ok "e1 no-§5 doc passes untouched" || fail "e1 rc=$RC: $OUT"

echo "── a: legit annex (placeholder, no evidence) → both paths pass ──"
write_doc "## 5. Lampiran — Eksekusi Otomatis (pre-UAT)

$ANNEX_PLACEHOLDER"
OUT=$(gate); RC=$?
[ "$RC" -eq 0 ] && ok "a1 --check-execution passes legit placeholder annex" || fail "a1 rc=$RC: $OUT"
# default-mode path (same function; run scaffold default against a vault with flows absent
# is heavy — the shared-function fact makes a1 cover both; pin the share instead)
grep -q "check_execution(uat_path)" "$SCAFFOLD" && [ "$(grep -c "check_execution(uat_path)" "$SCAFFOLD")" -ge 2 ] \
  && ok "a2 both call sites share check_execution()" || fail "a2 call sites diverged"

echo "── b: model-fabricated §5 row (no evidence on disk) → ANNEX_FORGED ──"
write_doc "## 5. Lampiran — Eksekusi Otomatis (pre-UAT)

| Skenario | Status | Run | Bukti |
|---|---|---|---|
| UAT-001 | 5/0/0 | 20260812T000000Z | \`evidence/UAT-001/20260812T000000Z\` |"
OUT=$(gate); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "ANNEX_FORGED" && ok "b1 fabricated annex → ANNEX_FORGED exit 1" || fail "b1 rc=$RC out=$(echo "$OUT" | head -2)"
echo "$OUT" | grep -qi "lampiran" && ok "b2 keterangan mentions the annex" || fail "b2 keterangan lacks annex wording"

echo "── b3: fence-wrapped forged content cannot hide ──"
write_doc '## 5. Lampiran — Eksekusi Otomatis (pre-UAT)

```
| UAT-001 | 99/0/0 | forged | forged |
```

'"$ANNEX_PLACEHOLDER"
OUT=$(gate); RC=$?
[ "$RC" -eq 1 ] && ok "b3 fenced forged content still ANNEX_FORGED" || fail "b3 fenced content escaped (rc=$RC)"

echo "── c/g: evidence on disk + --annex → gate passes; idempotent ──"
write_doc "## 5. Lampiran — Eksekusi Otomatis (pre-UAT)

$ANNEX_PLACEHOLDER"
TS="20260812T090000Z"
mkdir -p "$V/uat/evidence/UAT-001/$TS"
UAT_SHA=$(python3 -c "import hashlib;print(hashlib.sha256(open('$V/uat/UAT.md','rb').read()).hexdigest())")
python3 - "$V/uat/evidence/UAT-001/$TS/result.json" <<EOF
import json
json.dump({"written_by":"uat-run.sh","run_ts":"$TS","status":{"pass":2,"fail":0,"skip":0},
  "spec_sha256":"ab","uat_md_sha256":"WILLPATCH","scaffold_sha256":"cd",
  "preview_url":"http://x","duration_s":3,"playwright_exit":0}, open("$V/uat/evidence/UAT-001/$TS/result.json","w"))
EOF
# d: evidence exists but doc still placeholder → ANNEX_FORGED (stale doc must re-run --annex)
OUT=$(gate); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "ANNEX_FORGED" && ok "d1 evidence-on-disk + placeholder doc → forged (re-run --annex)" || fail "d1 rc=$RC"
# now run --annex → doc matches recompute → gate passes
bash "$E2E" --vault="$V" --cwd="$WORK" --annex </dev/null >/dev/null 2>&1
OUT=$(gate); RC=$?
[ "$RC" -eq 0 ] && ok "c1 post---annex doc passes the gate" || fail "c1 rc=$RC: $(echo "$OUT" | head -3)"
grep -q "| UAT-001 |" "$V/uat/UAT.md" && ok "c2 annex table rendered into UAT.md" || fail "c2 table missing"
BEFORE=$(cat "$V/uat/UAT.md")
bash "$E2E" --vault="$V" --cwd="$WORK" --annex </dev/null >/dev/null 2>&1
[ "$BEFORE" = "$(cat "$V/uat/UAT.md")" ] && ok "g1 --annex idempotent" || fail "g1 second --annex changed the doc"

echo "── h: STALE end-to-end (old uat_md_sha256) ──"
# the result.json above carries WILLPATCH ≠ real sha → renderer marks STALE, gate matches
grep -q "STALE — bukti dari versi dokumen sebelumnya" "$V/uat/UAT.md" \
  && ok "h1 STALE marker rendered (sha mismatch honest)" || fail "h1 STALE missing"

echo "── f: §4 checks still fire with §5 present ──"
python3 - "$V/uat/UAT.md" <<'EOF'
import io,sys
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
s=s.replace("| Business Owner | __________ |","| Business Owner | Budi |",1)
open(p,"w",encoding="utf-8").write(s)
EOF
OUT=$(gate); RC=$?
[ "$RC" -eq 1 ] && echo "$OUT" | grep -q "SIGNOFF_FILLED" && ok "f1 filled sign-off above §5 still caught" || fail "f1 rc=$RC out=$(echo "$OUT" | head -2)"

echo "── p: teacher↔template §5 pair present ──"
TEMPLATE="$P/skills/emit-uat/references/uat-template.md"
TEACHER="$P/skills/emit-uat/references/uat-sections.md"
grep -qF '{{annex_eksekusi_otomatis}}' "$TEMPLATE" && ok "p1 template carries the annex slot" || fail "p1 slot missing in template"
grep -qF '{{annex_eksekusi_otomatis}}' "$TEACHER" && ok "p2 teacher names the annex slot" || fail "p2 slot missing in teacher"
grep -qF "$ANNEX_PLACEHOLDER" "$TEMPLATE" && grep -qF "$ANNEX_PLACEHOLDER" "$TEACHER" \
  && ok "p3 placeholder literal in BOTH homes" || fail "p3 placeholder literal missing somewhere"
grep -qF '## 5. Lampiran — Eksekusi Otomatis (pre-UAT)' "$TEMPLATE" && ok "p4 template §5 heading exact" || fail "p4 heading drifted"
grep -qiE 'always.?(present|filled)|selalu (ada|terisi)' "$TEACHER" && ok "p5 always-filled rule stated in teacher" || fail "p5 always-filled rule missing"
grep -qF 'adds no rules of its own' "$TEMPLATE" && ok "p6 template pointer literal survives (p12 d2)" || fail "p6 pointer literal broken"
grep -qF '| 1 | <Aksi> | <Expected Result> |' "$TEMPLATE" && fail "p7 killed row literal reappeared (p12 d3)" || ok "p7 killed row literal absent"

echo
echo "uat-annex-gate: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
