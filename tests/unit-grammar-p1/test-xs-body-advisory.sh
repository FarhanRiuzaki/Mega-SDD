#!/usr/bin/env bash
# v8 P1 F1(e) (spec 2026-09-10 App. F1e): validate-unit-spec.sh `xs_body_advisory` —
# an xs-class unit (router size proxy: acceptance 1..2 AND steps 1..3, ONE
# implementation in _lib/unit_tier.py) whose body exceeds the xs diet (Goal 1
# line · Context <= 2 sentences · Anti-patterns/Out of scope sourced per item)
# is LISTED, never an issue / status / exit-code change. Non-xs units are
# never listed however fat their body is.
# Run: bash tests/unit-grammar-p1/test-xs-body-advisory.sh </dev/null
set -u
rc=0; pass() { echo "PASS: $1"; }; fail() { echo "FAIL: $1"; rc=1; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; S="$ROOT/plugins/mega-sdd/scripts"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
V="$T/.mega-sdd/vaults/demo"; mkdir -p "$V/units"
mk() { # $1 id  $2 steps  $3 body
  cat > "$V/units/$1.md" <<MD
---
id: $1
title: $1
task_type: create
vault_source: flows.md#F-U-001
target_files:
  - path: src/$1.ts
    operation: create
acceptance_test:
  - type: test
    command: x
    expects: "OK"
---
# u

$3

## Implementation steps

$2
MD
}
FAT=$'## Goal\n\nBuat tombol simpan.\nTombol ini juga harus punya ikon.\n\n## Context (read first)\n\nKalimat satu. Kalimat dua. Kalimat tiga.\n\n## Anti-patterns\n\n- Jangan pakai inline style.\n- Jangan bypass middleware auth (routes/web.php:34)\n\n## Out of scope\n\n- Filter/sort.\n- Export — belongs to U-009'
LEAN=$'## Goal\n\nBuat tombol simpan.\n\n## Context (read first)\n\nKalimat satu. Kalimat dua.\n\n## Out of scope\n\n- Export — belongs to U-009'
mk U-001 $'1. a\n2. b' "$FAT"                      # xs class, over budget
mk U-002 $'1. a\n2. b' "$LEAN"                     # xs class, within budget
mk U-003 $'1. a\n2. b\n3. c\n4. d' "$FAT"          # NOT xs (4 steps) — fat body allowed
( cd "$T" && bash "$S/validate-unit-spec.sh" --cwd="$T" --quiet >/dev/null 2>&1 ); RC=$?
ST="$T/.mega-sdd/.unit-spec-state.json"; [ -f "$ST" ] || ST="$(ls "$T"/.mega-sdd/.unit-spec*.json 2>/dev/null | head -1)"
python3 - "$ST" "$RC" <<'EOF2' && pass "a: xs over-budget unit listed with Goal lines=2, Context sentences=3, 1 unsourced Anti-pattern, 1 unsourced Out-of-scope; lean xs + non-xs units NOT listed; status/exit untouched" || fail "a: advisory shape wrong"
import json, sys
d = json.load(open(sys.argv[1])); rc = int(sys.argv[2])
adv = d["xs_body_advisory"]
assert [a["unit_id"] for a in adv] == ["U-001"], adv
over = {o["section"]: o for o in adv[0]["over"]}
assert over["Goal"]["value"] == 2 and over["Goal"]["budget"] == 1, over
assert over["Context (read first)"]["value"] == 3, over
assert over["Anti-patterns"]["value"] == 1 and over["Out of scope"]["value"] == 1, over
assert not any(i.get("halt_type", "").startswith("xs") for i in d["issues"]), "advisory leaked into issues"
assert "xs_body_advisory" in d["next_action"] and "never a halt" in d["next_action"]
assert d["status"] == "PASS" and rc == 0, (d["status"], rc)
EOF2
# b: the proxy is ONE implementation — router and validator agree on the class
python3 - "$ROOT" <<'EOF2' && pass "b: _lib/unit_tier.py is the single size proxy (resolver imports it; validator imports it)" || fail "b: proxy duplicated"
import sys, re
root = sys.argv[1]
r = open(root + "/plugins/mega-sdd/scripts/resolve-review-tier.sh").read()
v = open(root + "/plugins/mega-sdd/scripts/validate-unit-spec.sh").read()
assert "from unit_tier import size_proxy" in r and "from unit_tier import size_proxy" in v
assert r.count("def _section_items") == 0, "resolver still carries the inline proxy"
EOF2
# c: prose — writer contract names the diet and the advisory
P="$ROOT/plugins/mega-sdd"
grep -q 'xs_body_advisory' "$P/skills/generate-units/SKILL.md" && grep -q 'xs' "$P/skills/generate-units/references/templates/unit.md" && grep -q 'xs body diet' "$P/skills/generate-units/references/unit-schema.md" \
  && pass "c: generate-units Step 10 + template + schema carry the xs body diet" || fail "c: writer prose missing the diet"
echo; [ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
