#!/usr/bin/env bash
# test-uat-annex-render.sh — pins scripts/_lib/uat_annex.py, the SINGLE source of
# §5 annex truth (spec 2026-08-12-playwright-embed-design.md §D2; B1 recompute
# precedent: --annex WRITES this render, check_execution BYTE-COMPARES it).
# Run </dev/null like the sibling suites.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

# shellcheck disable=SC1091
. "$P/scripts/_lib/resolve-python.sh" 2>/dev/null || PYBIN=python3
PY="${PYBIN:-python3}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
V="$WORK/vault"
mkdir -p "$V/uat"
printf '# UAT doc body v1\nsome content\n' > "$V/uat/UAT.md"
UAT_SHA=$("$PY" - "$V/uat/UAT.md" <<'EOF'
import hashlib,sys
print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())
EOF
)

render() { "$PY" - "$V" <<EOF
import sys
sys.path.insert(0, "$P/scripts/_lib")
import uat_annex
sys.stdout.write(uat_annex.render_annex(sys.argv[1]))
EOF
}

echo "── uat_annex.py render contract ──"

# (a) no evidence → heading + placeholder literal
OUT_A=$(render "$V")
echo "$OUT_A" | head -1 | grep -qF '## 5. Lampiran — Eksekusi Otomatis (pre-UAT)' \
  && ok "a1 heading literal exact" || fail "a1 heading wrong: $(echo "$OUT_A" | head -1)"
echo "$OUT_A" | grep -qF '_Belum ada eksekusi otomatis — lampiran ini terisi setelah uat-run.sh dijalankan._' \
  && ok "a2 placeholder literal exact" || fail "a2 placeholder missing"

# (b) one Pass evidence pack → table row
TS1="20260812T100000Z"
mkdir -p "$V/uat/evidence/UAT-001/$TS1"
"$PY" - "$V/uat/evidence/UAT-001/$TS1/result.json" "$UAT_SHA" <<'EOF'
import json,sys
json.dump({"written_by":"uat-run.sh","run_ts":"20260812T100000Z",
  "status":{"pass":3,"fail":0,"skip":1},
  "spec_sha256":"deadbeef","uat_md_sha256":sys.argv[2],"scaffold_sha256":"cafe",
  "preview_url":"http://localhost:3000","duration_s":12,"playwright_exit":0},
  open(sys.argv[1],"w"))
EOF
OUT_B=$(render "$V")
echo "$OUT_B" | grep -qF '| Skenario | Status | Run | Bukti |' && ok "b1 table header" || fail "b1 table header missing"
echo "$OUT_B" | grep -q 'UAT-001.*3/0/1.*20260812T100000Z' && ok "b2 row: id + counts + run-ts" || fail "b2 row wrong: $(echo "$OUT_B" | grep UAT-001)"
echo "$OUT_B" | grep -qF 'evidence/UAT-001/20260812T100000Z' && ok "b3 bukti path" || fail "b3 bukti path missing"

# (c) sha mismatch → STALE literal
printf 'changed doc v2\n' >> "$V/uat/UAT.md"
OUT_C=$(render "$V")
echo "$OUT_C" | grep -qF 'STALE — bukti dari versi dokumen sebelumnya, jalankan ulang' \
  && ok "c1 STALE marker on sha mismatch" || fail "c1 STALE missing"
# restore doc for later arms
printf '# UAT doc body v1\nsome content\n' > "$V/uat/UAT.md"

# (d) corrupt result.json → UNREADABLE (fail closed)
mkdir -p "$V/uat/evidence/UAT-002/$TS1"
printf 'not json' > "$V/uat/evidence/UAT-002/$TS1/result.json"
OUT_D=$(render "$V")
echo "$OUT_D" | grep -q 'UAT-002.*UNREADABLE — jalankan ulang' && ok "d1 UNREADABLE fail-closed" || fail "d1 UNREADABLE missing"

# (e) determinism
OUT_E1=$(render "$V"); OUT_E2=$(render "$V")
[ "$OUT_E1" = "$OUT_E2" ] && ok "e1 two renders byte-equal" || fail "e1 nondeterministic render"

# (f) newest run wins
TS2="20260812T110000Z"
mkdir -p "$V/uat/evidence/UAT-001/$TS2"
"$PY" - "$V/uat/evidence/UAT-001/$TS2/result.json" "$UAT_SHA" <<'EOF'
import json,sys
json.dump({"written_by":"uat-run.sh","run_ts":"20260812T110000Z",
  "status":{"pass":4,"fail":0,"skip":0},
  "spec_sha256":"deadbeef","uat_md_sha256":sys.argv[2],"scaffold_sha256":"cafe",
  "preview_url":"http://localhost:3000","duration_s":9,"playwright_exit":0},
  open(sys.argv[1],"w"))
EOF
OUT_F=$(render "$V")
echo "$OUT_F" | grep -q 'UAT-001.*20260812T110000Z' && ok "f1 newest run-ts rendered" || fail "f1 newest run not picked"
echo "$OUT_F" | grep -q 'UAT-001.*20260812T100000Z' && fail "f2 old run leaked" || ok "f2 old run not rendered"
# rows sorted by scenario id
FIRST_ID=$(echo "$OUT_F" | grep -oE 'UAT-00[0-9]' | head -1)
[ "$FIRST_ID" = "UAT-001" ] && ok "f3 rows sorted by id" || fail "f3 sort order wrong"

echo
echo "uat-annex-render: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
