#!/usr/bin/env bash
# v8 P1.d (spec 2026-09-10 Appendix F5): validate-plan-coverage.sh — PRD requirement
# anchors (H2/H3 minus meta + out-of-scope) vs units' prd_source ∪ OQ citations →
# plan_coverage_gap. The only mechanical rail for the PRD→units prose gap.
# Run: bash tests/plan-coverage/test-plan-coverage.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts/validate-plan-coverage.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units" "$T/docs"
cat > "$T/docs/PRD.md" <<'MD'
# PRD — Company Profile Mini

## Latar belakang
teks.

## Ruang lingkup
tiga halaman.

## Halaman Beranda
konten.

## Halaman Tentang Kami
profil.

## Halaman Kontak
form.

### F-U-001: Kirim pesan kontak
1. isi form

## Data model
```dbml
Table contact_messages { id integer }
```

## Non-functional
| Kategori | Requirement |
|---|---|
| Performa | < 2 detik |

## Out of scope
### Panel admin
tidak dibangun.

## Open questions
- tidak ada
MD
mk() { cat > "$V/units/$1.md" <<MD
---
id: $1
title: $1
task_type: create
vault_source: flows.md#F-U-001
$2
target_files:
  - path: src/$1.ts
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: ""
---
# u
MD
}
mk U-001 'prd_source: docs/PRD.md#halaman-beranda'
mk U-002 $'prd_source:\n  - docs/PRD.md#halaman-kontak\n  - docs/PRD.md#f-u-001-kirim-pesan-kontak'
echo '{"open_questions":[{"tag":"OQ-CN-1","text":"Halaman Tentang Kami — isi tim final?","status":"open"}]}' > "$V/vault.json"

( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
ST="$T/.mega-sdd/.plan-coverage-state.json"
python3 - "$ST" "$RC" <<'EOF' && pass "a: 4 anchors (3 halaman + F-U-001); meta + out-of-scope excluded; all covered (2 by unit, 1 by OQ citation) → PASS exit 0" || fail "a: coverage verdict wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["anchors"] == 4 and d["status"] == "PASS" and rc == 0 and d["gaps"] == [], d
by = {c["slug"]: c["covered_by"] for c in d["covered_detail"]}
assert "unit" in by["halaman-beranda"] and "unit" in by["halaman-kontak"] and "unit" in by["f-u-001-kirim-pesan-kontak"], by
assert by["halaman-tentang-kami"].startswith("open question"), by
assert "panel-admin" not in by and "latar-belakang" not in by
EOF

# b: mutation — drop the OQ → Tentang Kami becomes a gap → FAIL exit 1
echo '{"open_questions":[]}' > "$V/vault.json"
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "b: mutation — uncited heading → plan_coverage_gap (FAIL, exit 1, heading named)" || fail "b: gap not detected"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["status"] == "FAIL" and rc == 1 and [g["slug"] for g in d["gaps"]] == ["halaman-tentang-kami"], d["gaps"]
assert d["gaps"][0]["halt_type"] == "plan_coverage_gap" and "plan_coverage_gap" in d["next_action"]
EOF

# c: :line form covers the heading whose range contains the line
mk U-003 'prd_source: docs/PRD.md:12'
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
[ $RC -eq 0 ] && pass "c: prd_source :line inside the Tentang Kami range covers it → PASS" || fail "c: line-range coverage failed (rc=$RC)"

# d: usage
bash "$S" --cwd="$T" --prd="$T/docs/NOPE.md" --vault="$V" >/dev/null 2>&1; [ $? -eq 2 ] && pass "d: missing PRD → exit 2" || fail "d: usage exit wrong"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
