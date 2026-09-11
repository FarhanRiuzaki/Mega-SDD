#!/usr/bin/env bash
# test-docs-resource.sh — v8 P2 goal item 4 (spec App. D): on a layout-3 vault FSD §1/§2 and
# PRD §1/§3 read the PRD FILE directly (heading sniff, verbatim quotes, cited); a section the
# PRD lacks → `[Pending — PRD §…]`, never invented. Layout-2 stays byte-identical (vault Overview).
#   S1–S3 prd_sniff: ID headings, § numbered H1 sections (clinic fixture), empty PRD
#   F1 FSD on layout-3: §1 background+scope quoted + cited to the PRD; §2 goals / non-goals
#   F2 FSD on layout-3 with the PRD absent → Pending markers, no vault text leaks in
#   F3 FSD on the layout-2 fixture + a PRD on disk → still cites vault/vault.md, never the PRD
#   P1 PRD builder on layout-3: §1 slots filled from the PRD (not model slots); §3 rows = PRD headings
#   P2 PRD builder on layout-3 with the PRD absent → §1 Pending (not a model slot)
# Run: bash tests/v8-layout3/test-docs-resource.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
FIX="$HERE/fixtures/context-vault"; FIX2="$P/tests/graph/fixtures/derive-vault-v2"
rc=0; fail() { echo "FAIL: $1"; rc=1; }; pass() { echo "PASS: $1"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# S — sniff unit
python3 - "$S/_lib" "$ROOT/tests/scenarios/sample-prd-clinic.md" <<'PYX' || rc=1
import sys; sys.path.insert(0, sys.argv[1]); import prd_sniff
md = "# PRD\n\n## Latar belakang\n\nSistem cuti.\n\n## Tujuan\n\nKurangi telepon.\n\n## Ruang lingkup\n\nSatu klinik.\n\n## Halaman Cuti\n\nForm cuti.\n\n## Halaman Riwayat\n\nTabel.\n\n## Data model\n\n```dbml\n```\n\n## Open questions\n\n- x\n"
s = prd_sniff.sniff(md)
assert s["background"]["heading"] == "Latar belakang" and s["goals"]["heading"] == "Tujuan" and s["scope"]["heading"] == "Ruang lingkup" and s["out_of_scope"] is None, s
assert [r["slug"] for r in s["requirements"]] == ["halaman-cuti", "halaman-riwayat"], s["requirements"]
assert prd_sniff.quote(s["background"]["body"]) == "Sistem cuti."
print("PASS: S1: ID headings → background/goals/scope + 2 requirement rows (meta sections skipped)")
c = prd_sniff.sniff(open(sys.argv[2], encoding="utf-8").read())
assert c["background"]["heading"].endswith("Executive Summary") and c["goals"]["heading"].endswith("Goals & Success Metrics") and c["out_of_scope"]["heading"].startswith("§7") and c["scope"] is None, {k: (v["heading"] if v else None) for k, v in c.items() if k != "requirements"}
assert len(c["requirements"]) == 6 and c["requirements"][0]["slug"].startswith("f-u-001"), [r["slug"] for r in c["requirements"]]
print("PASS: S2: clinic PRD (§-numbered H1 sections) → §1/§2/§7 + 6 flow-heading rows")
e = prd_sniff.sniff("# Title\n\nno sections here\n")
assert all(e[k] is None for k in ("background", "goals", "scope", "out_of_scope")) and e["requirements"] == []
print("PASS: S3: a PRD without those headings → all None (never invented)")
PYX
# fixture project (layout-3) + PRD on disk
PRJ="$T/proj"; V="$PRJ/.mega-sdd/vaults/v"; mkdir -p "$V" "$PRJ/PRD"; cp "$FIX/context.md" "$FIX/constitution.md" "$V/"; ( cd "$PRJ" && git init -q . )
cat > "$PRJ/PRD/demo-leave-prd.md" <<'MD'
# PRD — Demo Leave

## Latar belakang

Karyawan mengajukan cuti lewat telepon; pencatatan manual sering salah.

## Tujuan

Pengajuan cuti online dengan persetujuan manajer dalam 1 hari kerja.

## Ruang lingkup

Satu kantor cabang, 40 karyawan.

## Halaman Pengajuan Cuti

Form tanggal mulai/selesai + alasan.

## Halaman Riwayat Cuti

Tabel riwayat per karyawan.

## Out of scope

Integrasi payroll.
MD
bash "$S/derive-vault-json.sh" --vault="$V" </dev/null >/dev/null 2>&1 || fail "fixture derive failed"
# F1
bash "$S/build-fsd-core.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null >"$T/fsd1.log" 2>&1; R=$?
FSD="$V/fsd/FSD.md"
[ $R -eq 0 ] && grep -q 'Karyawan mengajukan cuti lewat telepon' "$FSD" && grep -q 'Satu kantor cabang' "$FSD" && pass "F1: FSD §1 quotes the PRD background + scope verbatim" || fail "F1: rc=$R ($(head -c 200 "$T/fsd1.log")) / §1 text missing"
grep -q 'PRD/demo-leave-prd.md §Latar belakang' "$FSD" && pass "F1: §1 cites the PRD file + heading" || fail "F1: §1 citation missing"
grep -q 'persetujuan manajer dalam 1 hari kerja' "$FSD" && grep -q 'Integrasi payroll' "$FSD" && pass "F1: §2 goals + non-goals from PRD §Tujuan / §Out of scope" || fail "F1: §2 content missing"
! grep -q 'not yet generated\]' "$FSD" || pass "F1: (other sections may be pending — fine)"
# F2 — PRD absent
rm -f "$PRJ/PRD/demo-leave-prd.md"
bash "$S/build-fsd-core.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null >/dev/null 2>&1
grep -q '\[Pending — PRD §Background / §Scope tidak ada di' "$FSD" && grep -q '\[Pending — PRD §Goals tidak ada' "$FSD" && grep -q '\[Pending — PRD §Out of scope tidak ada' "$FSD" && pass "F2: PRD absent → honest Pending markers (§1, §2 goals, §2 non-goals)" || fail "F2: pending markers missing"
! grep -q 'Demo leave system overview' "$FSD" && pass "F2: the vault Overview prose never leaks into §1 on layout-3" || fail "F2: vault Overview leaked into §1"
# F3 — layout-2 guard
PRJ2="$T/proj2"; V2="$PRJ2/.mega-sdd/vaults/v"; mkdir -p "$V2" "$PRJ2/PRD"; cp "$FIX2"/*.md "$V2/"; ( cd "$PRJ2" && git init -q . ); printf '# PRD\n\n## Background\n\nSHOULD-NOT-APPEAR\n' > "$PRJ2/PRD/prd.md"
bash "$S/derive-vault-json.sh" --vault="$V2" </dev/null >/dev/null 2>&1; python3 -c "
import json;p='$V2/vault.json';d=json.load(open(p));d['prd_path_at_generation']='PRD/prd.md';json.dump(d,open(p,'w'))"
bash "$S/build-fsd-core.sh" --vault="$V2" --cwd="$PRJ2" --quiet </dev/null >/dev/null 2>&1
! grep -q 'SHOULD-NOT-APPEAR' "$V2/fsd/FSD.md" && grep -q 'vault/vault.md' "$V2/fsd/FSD.md" && pass "F3: layout-2 vault still sources §1/§2 from vault.md, never the PRD (byte-identical lane)" || fail "F3: layout-2 behavior changed"
# P1 — PRD builder on layout-3
cat > "$PRJ/PRD/demo-leave-prd.md" <<'MD'
# PRD — Demo Leave

## Latar belakang

Karyawan mengajukan cuti lewat telepon.

## Tujuan

Pengajuan cuti online.

## Halaman Pengajuan Cuti

Form tanggal mulai/selesai + alasan.
MD
bash "$S/build-prd-core.sh" --out-root="$V" --vault="$V" --cwd="$PRJ" --mode=forward --quiet </dev/null >"$T/prd1.log" 2>&1; R=$?
PRD="$V/prd/PRD.md"
[ $R -eq 0 ] && grep -q 'Karyawan mengajukan cuti lewat telepon' "$PRD" && ! grep -q '{{section-1-background}}' "$PRD" && pass "P1: PRD §1 background filled VERBATIM from the PRD (no model slot)" || fail "P1: rc=$R ($(head -c 200 "$T/prd1.log")) / §1 slot"
grep -q 'Pengajuan cuti online' "$PRD" && ! grep -q '{{section-1-purpose}}' "$PRD" && pass "P1: PRD §1 purpose from PRD §Tujuan" || fail "P1: §1 purpose"
grep -q 'Halaman Pengajuan Cuti' "$PRD" && grep -q 'PRD/demo-leave-prd.md:L' "$PRD" && pass "P1: PRD §3 rows = PRD requirement headings, cited with line" || fail "P1: §3 rows missing"
# P2 — PRD absent
rm -f "$PRJ/PRD/demo-leave-prd.md"
bash "$S/build-prd-core.sh" --out-root="$V" --vault="$V" --cwd="$PRJ" --mode=forward --quiet </dev/null >/dev/null 2>&1
grep -q '\[Pending — PRD §Background tidak ada' "$PRD" && ! grep -q '{{section-1-background}}' "$PRD" && pass "P2: PRD absent → §1 Pending marker, NOT a model slot (nothing to invent)" || fail "P2: §1 absent handling"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
