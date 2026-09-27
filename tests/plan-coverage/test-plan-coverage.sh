#!/usr/bin/env bash
# v8 P1.d (spec 2026-09-10 Appendix F5): validate-plan-coverage.sh — every PRD anchor (H1-H3 that is not a
# body-less container) needs a decision: a unit's prd_source, an open OQ carrying [covers: <file>#<slug>], or a line
# in the vault's context.md "## Coverage exclusions" → else plan_coverage_gap. The only mechanical rail for the
# PRD→units gap.
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
Tidak dibangun di rilis ini:
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
mk U-001 $'prd_source:\n  - docs/PRD.md#halaman-beranda\n  - docs/PRD.md#non-functional'
mk U-002 $'prd_source:\n  - docs/PRD.md#halaman-kontak\n  - docs/PRD.md#f-u-001-kirim-pesan-kontak\n  - docs/PRD.md#data-model'
echo '{"open_questions":[]}' > "$V/vault.json"
cat > "$V/context.md" <<'MD'
# Company Profile Mini — Context

## Open Questions
- [ ] **OQ-CN-1** [P2] [business] [covers: docs/PRD.md#halaman-tentang-kami]: isi tim final?

## Coverage exclusions
- "Latar belakang" — konteks bisnis, tidak ada perilaku yang dibangun
- "Ruang lingkup" — ringkasan halaman; tiap halaman punya unit sendiri
- "Out of scope" — daftar yang tidak dibangun di rilis ini
- "Panel admin" — tercantum di Out of scope
- "Open questions" — PRD menyatakan tidak ada
MD

( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
ST="$T/.mega-sdd/.plan-coverage-state.json"
python3 - "$ST" "$RC" <<'EOF' && pass "a: 11 anchors = 6 covered (5 by unit — NFR / data model too —, 1 by an OQ [covers:]) + 5 declared → PASS exit 0" || fail "a: coverage verdict wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["anchors"] == 11 and d["covered"] == 6 and d["status"] == "PASS" and rc == 0 and d["gaps"] == [], d
assert sorted(x["slug"] for x in d["excluded"] if x["by"] == "declared") == sorted(
    ["latar-belakang", "ruang-lingkup", "out-of-scope", "panel-admin", "open-questions"]), d["excluded"]
assert [x["slug"] for x in d["oq_only"]] == ["halaman-tentang-kami"], d["oq_only"]
by = {c["slug"]: c["covered_by"] for c in d["covered_detail"]}
assert "unit" in by["halaman-beranda"] and "unit" in by["halaman-kontak"] and "unit" in by["f-u-001-kirim-pesan-kontak"], by
assert by["halaman-tentang-kami"].startswith("open question"), by
assert "panel-admin" not in by and "latar-belakang" not in by
EOF

setoq() {  # setoq '<OQ line>' → rewrite the context.md OQ line (the markdown is the OQ source; vault.json is derived later)
  python3 - "$V/context.md" "$1" <<'EOF'
import re, sys; p = sys.argv[1]; t = open(p).read()
open(p, "w").write(re.sub(r"(?m)^- \[.\] \*\*OQ-[^\n]*\n|^- none\n", (sys.argv[2] + "\n") if sys.argv[2] else "- none\n", t, count=1))
EOF
}
# b: mutation — drop the OQ → Tentang Kami becomes a gap → FAIL exit 1 (a declaration never stands in for it)
setoq ""
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "b: mutation — uncited heading → plan_coverage_gap (FAIL, exit 1, heading named)" || fail "b: gap not detected"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["status"] == "FAIL" and rc == 1 and [g["slug"] for g in d["gaps"]] == ["halaman-tentang-kami"], d["gaps"]
assert d["gaps"][0]["halt_type"] == "plan_coverage_gap" and "plan_coverage_gap" in d["next_action"]
EOF

# b2: an OQ the AI already DECIDED is closed — it must not count as coverage (a HUMAN answer still does)
setoq '- [x] **OQ-AR-7** [tech / recommend] [covers: docs/PRD.md#halaman-tentang-kami]: pakai komponen apa? → **Resolved v1.0** (AI decision, 2026-09-27): Card grid'
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "b2: heading cited ONLY by an AI-decided OQ → plan_coverage_gap (a decision is not an open item)" || fail "b2: AI-decided OQ still counted as coverage"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["status"] == "FAIL" and rc == 1 and [g["slug"] for g in d["gaps"]] == ["halaman-tentang-kami"], d
EOF
setoq '- [x] **OQ-CN-1** [P2] [business] [covers: docs/PRD.md#halaman-tentang-kami]: isi tim final? → **Resolved v1.1** (plan, 2026-09-27): empat orang'
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
[ $RC -eq 1 ] && pass "b3: a HUMAN-resolved OQ covers nothing either — the answer needs a unit or a declaration (F1)" || fail "b3: a resolved OQ still counted (rc=$RC)"
setoq '- [ ] **OQ-CN-1** [P2] [business]: "Halaman Tentang Kami" (PRD §12, docs/PRD.md#halaman-tentang-kami) — isi tim final?'
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
[ $RC -eq 1 ] && pass "b4: an open OQ quoting / §-citing / naming the heading's ref without [covers:] decides nothing" || fail "b4: an incidental citation counted (rc=$RC)"
setoq ""

# c: :line form covers the heading whose range contains the line
mk U-003 'prd_source: docs/PRD.md:12'
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
[ $RC -eq 0 ] && pass "c: prd_source :line inside the Tentang Kami range covers it → PASS" || fail "c: line-range coverage failed (rc=$RC)"

# c2: mutation — drop one declaration → that heading is a gap (no name is excluded by itself)
cp "$V/context.md" "$T/ctx.bak"; grep -v '"Out of scope"' "$T/ctx.bak" > "$V/context.md"
( cd "$T" && bash "$S" --cwd="$T" --prd="$T/docs/PRD.md" --vault="$V" --quiet ); RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "c2: mutation — an undeclared 'Out of scope' is a gap; its declared H3 'Panel admin' stays declared" || fail "c2: undeclared out-of-scope section not a gap"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert rc == 1 and [g["slug"] for g in d["gaps"]] == ["out-of-scope"] and '- "Out of scope" — <reason>' in d["next_action"], d["gaps"]
EOF
cp "$T/ctx.bak" "$V/context.md"

# d: usage
bash "$S" --cwd="$T" --prd="$T/docs/NOPE.md" --vault="$V" >/dev/null 2>&1; [ $? -eq 2 ] && pass "d: missing PRD → exit 2" || fail "d: usage exit wrong"

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
