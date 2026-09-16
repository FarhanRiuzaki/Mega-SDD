#!/usr/bin/env bash
# doc-audit v8 debt gate (spec 2026-09-16 §1 #7) — validate-scope-flag.sh:
#   the PRD template + every sample PRD declare `scopes:` as a MAP
#   (`scopes:\n  BE:\n    name: …`), but the gate only parsed the inline / block-list
#   shapes, so a multi-scope PRD read as "no scopes" and --scope=<typo> sailed through.
#   Without --user-message-file the script `cat`s stdin — on a terminal that blocked forever.
#   The from-prompt seed (`<vault>/source/seed-PRD.md`) was never on the search list.
#   a  MAP form + --scope=XX          → FAIL, declared_scopes == [BE, FE]
#   b  MAP form + --scope=BE          → PASS (declared list unchanged)
#   c  inline `scopes: [BE, FE]`      → still parsed (regression guard for the old shape)
#   d  no --user-message-file, stdin from /dev/null → exits (rc 0 = no flag), never hangs
#   e  root PRD gone, seed at .mega-sdd/vaults/x/source/seed-PRD.md → found, --scope=XX FAILs
# Run: bash tests/surface/test-scope-flag-map.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts/validate-scope-flag.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd"
ST="$T/.mega-sdd/.scope-flag-state.json"
MAP_PRD='---
title: X
scopes:
  BE:
    name: "Backend"
    priority: 1
  FE:
    name: "Frontend"
    priority: 2
---
# body
'
printf '%s' "$MAP_PRD" > "$T/prd.md"
printf '/mega-sdd:generate-intent --scope=XX\n' > "$T/msg-xx"
printf '/mega-sdd:generate-intent --scope=BE\n' > "$T/msg-be"
run() { rm -f "$ST"; bash "$S" --cwd="$T" --user-message-file="$1" >/dev/null 2>&1; }

# a: the MAP shape yields the scope ids (first-indent keys), so an undeclared id is a FAIL
run "$T/msg-xx"; RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "a: MAP scopes + --scope=XX → FAIL scope_not_declared_in_prd, declared_scopes == [BE, FE]" || fail "a: MAP form not parsed (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert rc == 1 and d["status"] == "FAIL" and d["halt_type"] == "scope_not_declared_in_prd", (rc, d)
assert d["declared_scopes"] == ["BE", "FE"] and d["scope_requested"] == "XX", d
assert d["prd_path"] == "prd.md", d
EOF

# b: a declared id on the same MAP PRD passes (attribute keys name:/priority: are NOT scopes)
run "$T/msg-be"; RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "b: MAP scopes + --scope=BE → PASS, declared_scopes == [BE, FE]" || fail "b: declared scope rejected (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert rc == 0 and d["status"] == "PASS" and d["scope_requested"] == "BE", (rc, d)
assert d["declared_scopes"] == ["BE", "FE"], d
EOF

# c: the inline list shape still parses — the MAP branch only runs when the older shapes found nothing
printf -- '---\ntitle: X\nscopes: [BE, FE]\n---\n# body\n' > "$T/prd.md"
run "$T/msg-xx"; RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "c: inline scopes: [BE, FE] + --scope=XX → FAIL with the same declared list (regression guard)" || fail "c: inline shape regressed (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert rc == 1 and d["status"] == "FAIL" and d["declared_scopes"] == ["BE", "FE"], (rc, d)
EOF

# d: no --user-message-file + stdin from /dev/null → returns (empty message = no flag = PASS), never blocks
rm -f "$ST"
if command -v timeout >/dev/null 2>&1; then
  timeout 10 bash "$S" --cwd="$T" </dev/null >/dev/null 2>&1; RC=$?
else
  bash "$S" --cwd="$T" </dev/null >/dev/null 2>&1; RC=$?
fi
[ "$RC" -ne 124 ] && [ "$RC" -eq 0 ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d['status']=='PASS' and d['scope_requested'] is None,d" "$ST" \
  && pass "d: no --user-message-file, stdin=/dev/null → exits rc 0 (no flag → PASS), no hang" || fail "d: rc=$RC (124 = hung until timeout)"

# e: from-prompt seed location is on the PRD search list — the root PRD is gone, the seed carries the scopes
rm -f "$T/prd.md"; mkdir -p "$T/.mega-sdd/vaults/x/source"
printf '%s' "$MAP_PRD" > "$T/.mega-sdd/vaults/x/source/seed-PRD.md"
run "$T/msg-xx"; RC=$?
python3 - "$ST" "$RC" <<'EOF' && pass "e: seed at .mega-sdd/vaults/x/source/seed-PRD.md is found → --scope=XX FAILs against its scopes" || fail "e: from-prompt seed not searched (rc=$RC)"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
assert rc == 1 and d["status"] == "FAIL" and d["declared_scopes"] == ["BE", "FE"], (rc, d)
assert d["prd_path"] == ".mega-sdd/vaults/x/source/seed-PRD.md", d
EOF

echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
