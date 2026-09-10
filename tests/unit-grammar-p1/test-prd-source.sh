#!/usr/bin/env bash
# v8 P1.a (spec 2026-09-10-v8-fused-pipeline-design.md Appendix F1): unit grammar
# additions — `prd_source` RESOLVED when present (halt prd_source_unresolvable),
# `context_source` accepted as the vault_source alias, registry parity, template +
# schema teach the new fields, writer diet documented.
# Run: bash tests/unit-grammar-p1/test-prd-source.sh </dev/null
set -u
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
VAL="$P/scripts/validate-unit-spec.sh"
[ -f "$VAL" ] || { echo "FATAL: validator missing"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
U="$T/.mega-sdd/vaults/demo/units"; mkdir -p "$U" "$T/docs"
cat > "$T/docs/PRD.md" <<'MD'
# PRD — Company Profile Mini

## Halaman Beranda
konten statis.

## Halaman Kontak
Form nama/email/pesan.

### F-U-001: Kirim pesan kontak
1. isi form
MD
mk_unit() {   # ID FRONTMATTER_EXTRA (may be multi-line)
  { printf -- '---\nid: %s\ntitle: unit %s\ntask_type: create\n' "$1" "$1"; printf '%s\n' "$2"; cat <<'MD'
target_files:
  - path: src/x.ts
    operation: create
acceptance_test:
  - type: test
    command: npm test
    expects: "passed"
---
# unit

## Goal
x
MD
  } > "$U/$1.md"
}
mk_unit U-001 $'vault_source: flows.md#F-U-001\nprd_source: docs/PRD.md#halaman-kontak'
mk_unit U-002 $'vault_source: flows.md#F-U-001\nprd_source: docs/PRD.md:7'
mk_unit U-003 $'vault_source: flows.md#F-U-001\nprd_source:\n  - docs/PRD.md#halaman-beranda\n  - docs/PRD.md#halaman-yang-tidak-ada'
mk_unit U-004 $'context_source: flows.md#F-U-001'
mk_unit U-005 $'vault_source: flows.md#F-U-001'
mk_unit U-006 $'vault_source: flows.md#F-U-001\nprd_source: docs/MISSING.md#x'
mk_unit U-007 $'vault_source: flows.md#F-U-001\nprd_source: docs/PRD.md:999'
mk_unit U-008 $'vault_source: flows.md#F-U-001\nprd_source: docs/PRD.md#f-u-001-kirim-pesan-kontak'

( cd "$T" && bash "$VAL" --cwd="$T" --quiet >/dev/null 2>&1 ); RC=$?
ST="$T/.mega-sdd/.unit-spec-state.json"
[ -f "$ST" ] || { fail "state not written"; exit 1; }

python3 - "$ST" "$RC" <<'EOF' && pass "a: prd_source resolves heading slug, :line, list, F-id heading; unresolvable slug/file/line → prd_source_unresolvable" || fail "a: resolution verdicts wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
bad = sorted((i["unit_id"], i["prd_source"]) for i in d["issues"] if i["halt_type"] == "prd_source_unresolvable")
assert bad == [("U-003", "docs/PRD.md#halaman-yang-tidak-ada"), ("U-006", "docs/MISSING.md#x"), ("U-007", "docs/PRD.md:999")], bad
ok_units = {"U-001", "U-002", "U-004", "U-005", "U-008"}
assert not any(i.get("unit_id") in ok_units for i in d["issues"]), [i for i in d["issues"] if i.get("unit_id") in ok_units]
assert d["status"] == "FAIL" and rc == 1
EOF

python3 - "$ST" <<'EOF' && pass "b: context_source alone satisfies the presence check (alias of vault_source); legacy unit without prd_source is silent" || fail "b: alias / legacy handling wrong"
import json, sys
d = json.load(open(sys.argv[1]))
assert not any(i.get("unit_id") == "U-004" and i["halt_type"] == "unit_underspecified" for i in d["issues"])
assert not any(i.get("unit_id") == "U-005" for i in d["issues"])
assert all(r["unit_id"] != "U-004" for r in d.get("vault_source_advisory", [])), d.get("vault_source_advisory")
EOF

# c: mutation — fixing U-003's bad slug clears its issue
mk_unit U-003 $'vault_source: flows.md#F-U-001\nprd_source:\n  - docs/PRD.md#halaman-beranda\n  - docs/PRD.md#halaman-kontak'
( cd "$T" && bash "$VAL" --cwd="$T" --quiet >/dev/null 2>&1 )
python3 - "$ST" <<'EOF' && pass "c: mutation — corrected list resolves, U-003 issue gone (U-006/U-007 remain)" || fail "c: mutation did not clear"
import json, sys
d = json.load(open(sys.argv[1]))
bad = sorted(i["unit_id"] for i in d["issues"] if i["halt_type"] == "prd_source_unresolvable")
assert bad == ["U-006", "U-007"], bad
EOF

# d: registry parity + authoring surfaces
grep -q 'prd_source_unresolvable' "$P/references/halt-protocol.md" && grep -q '^### prd_source_unresolvable' "$P/references/halt-families/units.md" \
  && pass "d1: prd_source_unresolvable registered in the enum/index + units family" || fail "d1: registry missing the halt"
grep -qE '^prd_source: ' "$P/skills/generate-units/references/unit-schema.md" && grep -qE '^context_source: ' "$P/skills/generate-units/references/unit-schema.md" \
  && pass "d2: unit-schema documents prd_source + context_source" || fail "d2: schema missing fields"
grep -qE '^## Claims' "$P/skills/generate-units/references/unit-schema.md" && grep -qE '^## Claims' "$P/skills/generate-units/references/templates/unit.md" \
  && pass "d3: ## Claims section taught by schema + template" || fail "d3: Claims section missing"
grep -q 'prd_source:' "$P/skills/generate-units/references/templates/unit.md" && grep -q 'prd_source' "$P/skills/generate-units/SKILL.md" \
  && pass "d4: template + SKILL Step 10 carry prd_source" || fail "d4: writer surfaces missing prd_source"
grep -q 'acceptance_test\[\].ears' "$P/skills/generate-units/SKILL.md" && grep -q 'writer diet' "$P/skills/generate-units/references/unit-schema.md" \
  && pass "d5: zero-reader writer diet stated at SKILL + schema" || fail "d5: writer diet missing"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
