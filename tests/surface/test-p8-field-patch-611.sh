#!/usr/bin/env bash
# test-p8-field-patch-611.sh — v6.1.1 field-patch proof
# F1: vault.json OQ ids count as declarations for the handoff validator
#     (express-born vaults have no binding.md; 25 false oq_id_extra measured).
# F2: unit-schema.md teaches expects as a SUBSTRING matcher, never a description.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
V="$P/scripts/validate-handoff-binding-units.sh"
FAIL=0
note() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# ── F1 live arms: fixture vault, no binding docs ─────────────────────────────
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.mega-sdd/vaults/v1/units"
cd "$T" && git init -q .
cat > "$T/.mega-sdd/vaults/v1/vault.json" <<'EOF'
{"open_questions": [{"tag": "OQ-AR-1", "status": "open"}, {"id": "OQ-DM-2", "status": "open"}]}
EOF
cat > "$T/.mega-sdd/vaults/v1/units/U-001.md" <<'EOF'
---
unit: U-001
binding_refs:
  - OQ-AR-1
  - OQ-DM-2
---
# U-001
EOF
bash "$V" --cwd="$T" --quiet || note "F1a validator rc nonzero on vault-declared OQs"
python3 - "$T/.mega-sdd/.validation-blockers.json" <<'EOF' || note "F1b vault-declared OQ still flagged as extra"
import json, sys
d = json.load(open(sys.argv[1]))
extras = [e for e in d.get("extras", []) if e.get("type") == "oq_id_extra"]
assert extras == [], extras
assert d.get("summary", {}).get("oq_ids_in_vault") == 2
EOF

# negative arm: an id in NEITHER binding nor vault.json must STILL be flagged
cat > "$T/.mega-sdd/vaults/v1/units/U-002.md" <<'EOF'
---
unit: U-002
binding_refs:
  - OQ-GHOST-9
---
# U-002
EOF
bash "$V" --cwd="$T" --quiet
python3 - "$T/.mega-sdd/.validation-blockers.json" <<'EOF' || note "F1c undeclared OQ id no longer flagged (fail-open regression)"
import json, sys
d = json.load(open(sys.argv[1]))
ghost = [e for e in d.get("extras", []) if e.get("type") == "oq_id_extra" and e.get("oq_id") == "OQ-GHOST-9"]
assert len(ghost) == 1, d.get("extras")
EOF

# fail-closed arm: unreadable vault.json contributes nothing (ghost still flagged, no crash)
echo '{broken' > "$T/.mega-sdd/vaults/v1/vault.json"
bash "$V" --cwd="$T" --quiet || note "F1d validator crashed on unreadable vault.json"
python3 - "$T/.mega-sdd/.validation-blockers.json" <<'EOF' || note "F1e unreadable vault.json widened the universe"
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("summary", {}).get("oq_ids_in_vault") == 0
ids = {e.get("oq_id") for e in d.get("extras", []) if e.get("type") == "oq_id_extra"}
assert "OQ-AR-1" in ids and "OQ-GHOST-9" in ids, ids
EOF

# ── F2 schema + template pins ────────────────────────────────────────────────
US="$P/skills/generate-units/references/unit-schema.md"
UT="$P/skills/generate-units/references/templates/unit.md"
# description-shape CLASS pin, both teachers: any expects value containing the
# words pass/passes/succeeds/works (quoted or not) is the poison shape
for f in "$US" "$UT"; do
  grep -Eq 'expects: *"?(passes|pass|succeeds|works)"?( |$)' "$f" \
    && note "F2a $(basename "$f") teaches a description-shaped expects"
done
grep -q "SUBSTRING MATCHER" "$US" || note "F2b substring contract sentence missing"
grep -q "LEAVE IT" "$US" || note "F2c empty-when-no-literal rule missing"
grep -q "never a description" "$UT" || note "F2d template lacks the substring/empty note"

if [ "$FAIL" -eq 0 ]; then echo "PASS: p8 field patch (v6.1.1)"; exit 0; fi
echo "FAILURES: $FAIL"; exit 1
