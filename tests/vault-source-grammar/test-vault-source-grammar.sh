#!/usr/bin/env bash
# vault_source grammar (v8 P0, 2026-09-10 — spec 2026-09-10-v8-fused-pipeline-design.md
# Appendix B.3 + census research/2026-09-10-v8-consumer-census.md "Koreksi"):
# ONE canonical unit form `<doc>.md#<anchor>` documented in unit-schema.md and
# reported — ADVISORY ONLY — by validate-unit-spec.sh as the top-level state key
# `vault_source_advisory`. Field + fixture units carry four shapes today, so the
# contract this suite pins is: every drifted shape is NAMED, the canonical one is
# silent, and NOTHING about status / issues / exit code moves.
# Run: bash tests/vault-source-grammar/test-vault-source-grammar.sh </dev/null
set -u
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VAL="$ROOT/plugins/mega-sdd/scripts/validate-unit-spec.sh"
SCHEMA="$ROOT/plugins/mega-sdd/skills/generate-units/references/unit-schema.md"
TPL="$ROOT/plugins/mega-sdd/skills/generate-units/references/templates/unit.md"
[ -f "$VAL" ] || { echo "FATAL: validator missing"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
U="$T/.mega-sdd/vaults/demo/units"; mkdir -p "$U"
mk_unit() {   # ID VAULT_SOURCE
  cat > "$U/$1.md" <<MD
---
id: $1
title: unit $1
task_type: create
vault_source: $2
target_files:
  - path: src/$1.ts
    operation: create
acceptance_test:
  - type: test
    command: npm test -- $1
    expects: "passed"
---
# $1

## Goal
x
MD
}
mk_unit U-001 'flows.md#F-U-001'                 # canonical
mk_unit U-002 '04-flows.md:F-U-001'              # legacy colon separator (fixture shape)
mk_unit U-003 '02-architecture.md §Widget module' # legacy section sign (fixture shape)
mk_unit U-004 '03-data-model.md'                 # bare doc, no anchor (field shape)
mk_unit U-005 'docs/spec.md#x'                   # not a vault doc at all

run() { ( cd "$T" && bash "$VAL" --cwd="$T" --quiet >/dev/null 2>&1; echo $? ); }
RC="$(run)"
ST="$T/.mega-sdd/.unit-spec-state.json"
[ -f "$ST" ] || { fail "state file not written"; echo; exit 1; }

python3 - "$ST" "$RC" <<'EOF' && pass "a: five shapes → 4 advisory rows with named shapes; canonical unit silent" || fail "a: advisory rows wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
adv = {r["unit_id"]: r["shape"] for r in d.get("vault_source_advisory", [])}
assert adv == {"U-002": "legacy_colon_separator", "U-003": "legacy_section_sign",
               "U-004": "no_anchor", "U-005": "unknown_doc"}, adv
assert all(r["canonical_form"] == "<doc>.md#<anchor>" for r in d["vault_source_advisory"])
EOF

python3 - "$ST" "$RC" <<'EOF' && pass "b: advisory never gates — status PASS, issues empty, exit 0, sentence in next_action" || fail "b: advisory leaked into status/issues/exit"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["status"] == "PASS", d["status"]
assert d["issues_count"] == 0 and d["issues"] == [], d["issues"]
assert rc == 0, rc
assert "4 unit(s) carry a non-canonical vault_source" in d["next_action"], d["next_action"]
assert "never a halt" in d["next_action"]
EOF

# c: MUTATION — fixing the legacy units to the canonical form empties the list
mk_unit U-002 'flows.md#F-U-001'
mk_unit U-003 'vault.md#Widget-module'
mk_unit U-004 'model.md#leave_request'
mk_unit U-005 'constraints.md#NFR-1'
RC="$(run)"
python3 - "$ST" "$RC" <<'EOF' && pass "c: mutation — all canonical → advisory list empty, next_action carries no advisory sentence" || fail "c: mutation did not clear the advisory"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert d["vault_source_advisory"] == [], d["vault_source_advisory"]
assert "non-canonical" not in d["next_action"], d["next_action"]
assert rc == 0
EOF

# d: legacy doc names are part of the doc set (read-tolerated), constitution.md too
mk_unit U-002 '02-architecture.md#auth'
mk_unit U-003 'constitution.md#F9'
RC="$(run)"
python3 - "$ST" <<'EOF' && pass "d: legacy 0N-*.md#anchor and constitution.md#anchor count as canonical" || fail "d: doc set too narrow"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["vault_source_advisory"] == [], d["vault_source_advisory"]
EOF

# e: the authoring contract teaches ONE form (schema + template agree on `#`)
grep -qE '^vault_source: <doc>\.md#<anchor>' "$SCHEMA" \
  && pass "e1: unit-schema.md documents vault_source as <doc>.md#<anchor>" \
  || fail "e1: unit-schema.md vault_source line not canonical"
grep -q 'vault_source_advisory' "$SCHEMA" \
  && pass "e2: unit-schema.md names the advisory state key (reader ↔ writer agree)" \
  || fail "e2: schema does not name vault_source_advisory"
grep -qE '^vault_source: <e\.g\., vault\.md#' "$TPL" \
  && pass "e3: templates/unit.md example uses the # form" \
  || fail "e3: template example drifted from the # form"
! grep -q 'vault-file:section' "$SCHEMA" \
  && pass "e4: the retired `<vault-file:section>` wording is gone" \
  || fail "e4: retired wording still present"

echo
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
