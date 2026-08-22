#!/usr/bin/env bash
# test-vault-layout2.sh — v7 Fase 3 commit (a): parser + dual-layout read.
#   - vault_md.vault_layout() detection (marker-gated, legacy = 1)
#   - parse_vault_lock frontmatter-first on layout-2, byte-identical legacy path
#   - the gating hazard: LEGACY 00-index frontmatter carries vault_version but
#     NO vault_layout marker — it must NOT be read frontmatter-first
#   - OQ `[origin: file#anchor]` grammar (present → origin field, clean text;
#     absent → no origin key)
#   - active-vault locator dual-probe (flows.md first, 04-flows.md fallback):
#     functional on validate-flow-coverage, structural pin on validate-vault-oqs
# Run: bash plugins/mega-sdd/tests/graph/test-vault-layout2.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$(cd "$HERE/../.." && pwd)"   # plugin root
FIX="$P/tests/graph/fixtures"
LIB="$P/scripts/_lib"

if [ -f "$LIB/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$LIB/resolve-python.sh"
  if mega_sdd_python; then PY="$MEGA_SDD_PY"; else
    echo "SKIP: no usable python interpreter"; exit 0
  fi
else
  echo "missing resolve-python.sh"; exit 1
fi

rc=0
fail() { echo "FAIL: $1"; rc=1; }
pass() { echo "PASS: $1"; }

OUT=$("$PY" - "$LIB" "$FIX" <<'EOF'
import json, sys
lib, fix = sys.argv[1], sys.argv[2]
sys.path.insert(0, lib)
import vault_md

def read(p):
    return open(p, encoding="utf-8").read()

res = []
v2 = read(fix + "/derive-vault-v2/vault.md")
v1 = read(fix + "/derive-vault/00-index.md")

# L1 — layout detection
res.append(("L1", vault_md.vault_layout(v2) == 2 and vault_md.vault_layout(v1) == 1))

# L2 — layout-2 lock values from frontmatter
lk = vault_md.parse_vault_lock(v2)
res.append(("L2", lk == {
    "vault_version": "1.1", "project_shape": "web-app",
    "implementation_mode": "new", "mode_migrate_after": None,
    "prd_status": "draft", "output_mode": "compact"}))

# L3 — legacy lock values BYTE-IDENTICAL to the pre-Fase-3 read
lk1 = vault_md.parse_vault_lock(v1)
res.append(("L3", lk1 == {
    "vault_version": "1.1", "project_shape": "web-app",
    "implementation_mode": "new", "mode_migrate_after": None,
    "prd_status": "draft", "output_mode": "compact"}))

# L4 — gating: frontmatter WITHOUT the marker (the legacy-00-index shape) is
# NOT read even when it carries vault_version; bullets still win
tricky = ('---\nvault_version: "9.9"\nprd_status: final\n---\n\n'
          "# X\n\n## Vault Lock Status\n\n- **Vault version**: v1.0\n")
lkt = vault_md.parse_vault_lock(tricky)
res.append(("L4", lkt == {"vault_version": "1.0"}))

# L5 — precedence: frontmatter WINS over a residual bullet section on layout-2
both = ('---\nvault_layout: 2\nvault_version: "2.0"\n---\n\n'
        "# X\n\n## Vault Lock Status\n\n- **Vault version**: v1.0\n- **PRD status**: draft\n")
lkb = vault_md.parse_vault_lock(both)
res.append(("L5", lkb.get("vault_version") == "2.0" and lkb.get("prd_status") == "draft"))

# L6 — OQ origin grammar on the centralized constraints.md
errors = []
oqs = vault_md.parse_open_questions(
    "constraints.md", read(fix + "/derive-vault-v2/constraints.md"), errors)
by = {o["tag"]: o for o in oqs}
res.append(("L6-count", not errors and len(oqs) == 7))
res.append(("L6-origin", by["OQ-AR-1"].get("origin") == "vault.md#Architecture"
            and by["OQ-DM-1"].get("origin") == "model.md#Entities"
            and by["OQ-FL-2"].get("origin") == "flows.md#F-U-001"))
res.append(("L6-absent", "origin" not in by["OQ-CN-3"] and "origin" not in by["OQ-CN-4"]))
res.append(("L6-text", by["OQ-AR-1"].get("text") == "which test framework?"
            and by["OQ-DM-1"].get("text") == "which ID type?"))
res.append(("L6-status", by["OQ-AR-7"]["status"] == "deferred"
            and by["OQ-DM-1"]["status"] == "resolved"
            and by["OQ-AR-9"]["status"] == "out_of_scope"
            and by["OQ-AR-7"].get("origin") == "vault.md#Architecture"))
res.append(("L6-brackets", by["OQ-AR-1"].get("category") == "tech"
            and by["OQ-AR-1"].get("resolution_mode") == "scan"
            and by["OQ-AR-1"].get("classification_confidence") == "high"
            and by["OQ-AR-1"].get("resolver_owner") == "scan codebase-map §test_frameworks"))

# L7 — origin grammar is layout-agnostic (an old-layout doc line parses too)
legacy_line = "- [ ] **OQ-AR-5** [P2] [origin: 04-flows.md#F-U-009]: which retry cap?\n"
lo = vault_md.parse_open_questions("02-architecture.md", legacy_line, [])
res.append(("L7", len(lo) == 1 and lo[0].get("origin") == "04-flows.md#F-U-009"
            and lo[0].get("text") == "which retry cap?"))

print(json.dumps(res))
EOF
) || { echo "FAIL: python harness crashed"; echo "$OUT"; exit 1; }

"$PY" - "$OUT" <<'EOF' | while IFS= read -r line; do echo "$line"; done
import json, sys
for name, ok in json.loads(sys.argv[1]):
    print(("PASS: " if ok else "FAIL: ") + name)
EOF
echo "$OUT" | grep -q 'false' && rc=1

# L8 — functional locator: a layout-2 vault (flows.md, NO 04-flows.md) is FOUND
# by validate-flow-coverage (state file written, not the "no active vault" skip)
T=$(mktemp -d)
mkdir -p "$T/.mega-sdd/vaults/v/units"
cat > "$T/.mega-sdd/vaults/v/flows.md" <<'MD'
# Flows

### F-U-001: Demo

**Flow**:
```mermaid
flowchart TD
    A["x"] --> B["y"]
```

**Definition of Done**:
- [ ] done
MD
printf -- '---\nid: U-001\ntitle: t\nflow: F-U-001\n---\nbody\n' > "$T/.mega-sdd/vaults/v/units/U-001.md"
bash "$P/scripts/validate-flow-coverage.sh" --cwd="$T" --quiet </dev/null >/dev/null 2>&1
ST="$T/.mega-sdd/.flow-coverage-state.json"
if [ -f "$ST" ] && ! grep -q 'no active vault' "$ST"; then
  pass "L8: layout-2 vault located by validate-flow-coverage (flows.md probe)"
else
  fail "L8: layout-2 vault NOT located (state: $(cat "$ST" 2>/dev/null | head -c 200))"
fi
rm -rf "$T"

# L9 — structural pin: both locators carry the dual probe
for f in "$P/scripts/validate-vault-oqs.sh" "$P/scripts/validate-flow-coverage.sh"; do
  grep -q 'def _flows_path' "$f" && grep -q '"flows.md"' "$f" && grep -q '"04-flows.md"' "$f" \
    && pass "L9: $(basename "$f") dual-probe present" \
    || fail "L9: $(basename "$f") dual-probe missing"
done

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
