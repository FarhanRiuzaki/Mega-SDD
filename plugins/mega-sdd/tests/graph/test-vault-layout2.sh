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

# ── commit (b) arms: consumer re-key ─────────────────────────────────────────

# B1 — full derive on the layout-2 fixture: layout marker + doc fields + origin
T=$(mktemp -d)
cp -R "$FIX/derive-vault-v2" "$T/v2"
cp -R "$FIX/derive-vault" "$T/v1"; rm -f "$T/v1/vault.json"
if bash "$P/scripts/derive-vault-json.sh" --vault="$T/v2" </dev/null >/dev/null 2>&1 \
   && bash "$P/scripts/derive-vault-json.sh" --vault="$T/v1" </dev/null >/dev/null 2>&1; then
  pass "B1: derive-vault-json exits 0 on BOTH layouts"
else
  fail "B1: derive failed on a layout"
fi
B_OUT=$("$PY" - "$T" <<'EOF'
import json, sys
t = sys.argv[1]
v2 = json.load(open(t + "/v2/vault.json")); v1 = json.load(open(t + "/v1/vault.json"))
ok = []
ok.append(("B1-layout", v2.get("vault_layout") == 2 and "vault_layout" not in v1))
ok.append(("B1-docs", {e["doc"] for e in v2["entities"]} == {"model.md"}
           and {f["doc"] for f in v2["flows"]} == {"flows.md"}
           and {a["doc"] for a in v2["adrs"]} == {"vault.md"}
           and {o["doc"] for o in v2["open_questions"]} == {"constraints.md"}))
ok.append(("B1-origin", next(o for o in v2["open_questions"] if o["tag"] == "OQ-FL-2")
           .get("origin") == "flows.md#F-U-001"))
# B2 — cross-layout parity: same content modulo layout-carried fields.
# category is popped ONLY because the legacy roll-up fallback dies by design
# on layout-2 (bracket-first is the primary contract there).
def norm(d):
    d = dict(d)
    for k in ("generated_at", "vault_layout", "changelog", "sources"):
        d.pop(k, None)
    for cls in ("entities", "flows", "adrs", "open_questions"):
        for e in d.get(cls, []):
            for k in ("doc", "origin", "resolved_at", "deferred_at", "category"):
                e.pop(k, None)
    return d
ok.append(("B2-parity", norm(v1) == norm(v2)))
print(json.dumps(ok))
EOF
)
"$PY" - "$B_OUT" <<'EOF'
import json, sys
for name, v in json.loads(sys.argv[1]):
    print(("PASS: " if v else "FAIL: ") + name)
EOF
echo "$B_OUT" | grep -q 'false' && rc=1

# B3 — hard-header contract: a vault.md missing `## Decisions` FAILS loud
# (exit 2, message names the header) in BOTH the deriver and the ledger
cp -R "$FIX/derive-vault-v2" "$T/bad"
"$PY" - "$T/bad/vault.md" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("## Decisions", "## Keputusan")
open(p, "w").write(s)
EOF
OUT3=$(bash "$P/scripts/derive-vault-json.sh" --vault="$T/bad" </dev/null 2>&1); R3=$?
OUT3L=$(bash "$P/scripts/derive-claims-ledger.sh" --vault="$T/bad" </dev/null 2>&1); R3L=$?
[ "$R3" -eq 2 ] && echo "$OUT3" | grep -q '## Decisions' \
  && pass "B3: deriver hard-header FAIL (rc=2, names ## Decisions)" \
  || fail "B3: deriver hard-header (rc=$R3)"
[ "$R3L" -eq 2 ] && echo "$OUT3L" | grep -q '## Decisions' \
  && pass "B3: ledger hard-header FAIL (rc=2, names ## Decisions)" \
  || fail "B3: ledger hard-header (rc=$R3L)"

# B4 — OQ centralization rail: a stray OQ checkbox outside constraints.md FAILS
cp -R "$FIX/derive-vault-v2" "$T/stray"
printf -- '\n- [ ] **OQ-FL-9** [P2]: stray question\n' >> "$T/stray/flows.md"
OUT4=$(bash "$P/scripts/derive-vault-json.sh" --vault="$T/stray" </dev/null 2>&1); R4=$?
[ "$R4" -eq 2 ] && echo "$OUT4" | grep -q 'centralizes' \
  && pass "B4: stray OQ outside constraints.md FAILS loud (rc=2)" \
  || fail "B4: stray OQ rail (rc=$R4)"

# B5 — claims-ledger: same claim-id SET across layouts (DOC_CODE via section)
bash "$P/scripts/derive-claims-ledger.sh" --vault="$T/v2" </dev/null >/dev/null 2>&1
bash "$P/scripts/derive-claims-ledger.sh" --vault="$T/v1" </dev/null >/dev/null 2>&1
B5_OUT=$("$PY" - "$T" <<'EOF'
import json, sys
t = sys.argv[1]
a = {c["id"] for c in json.load(open(t + "/v1/claims-ledger.json"))["claims"]}
b = {c["id"] for c in json.load(open(t + "/v2/claims-ledger.json"))["claims"]}
srcs = {c["source"].rsplit(":", 1)[0] for c in json.load(open(t + "/v2/claims-ledger.json"))["claims"]}
print(("PASS: " if a == b else "FAIL: ") + "B5-idset")
print(("PASS: " if srcs <= {"vault.md", "model.md", "flows.md", "constraints.md"} else "FAIL: ") + "B5-sources")
EOF
)
echo "$B5_OUT"
echo "$B5_OUT" | grep -q '^FAIL' && rc=1

# B6 — vault-flows Mermaid mandate fires on a layout-2 flows.md write
PRJ="$T/proj"; mkdir -p "$PRJ/.mega-sdd/vaults/v"
cp "$FIX/derive-vault-v2/"*.md "$PRJ/.mega-sdd/vaults/v/"
"$PY" - "$PRJ/.mega-sdd/vaults/v/flows.md" <<'EOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
# strip the mermaid fence from F-U-001 -> prose flow, the mandate must FAIL it
s = s.replace("""**Flow**:
```mermaid
flowchart TD
    A["Fill form"] --> B["Validate dates"]
    B --> C["Create leave_request"]
```""", "**Flow**: fill form, validate dates, create leave_request")
open(p, "w").write(s)
EOF
bash "$P/scripts/validate-kb.sh" --surface=vault-flows --cwd="$PRJ" \
  --file-path="$PRJ/.mega-sdd/vaults/v/flows.md" </dev/null >"$T/vf.json" 2>&1
grep -q '"FAIL"\|missing_mermaid\|prose' "$T/vf.json" \
  && pass "B6: Mermaid mandate fires on layout-2 flows.md (prose flow flagged)" \
  || fail "B6: mandate did not fire on flows.md ($(head -c 150 "$T/vf.json"))"

# B7 — structural pins: hook case glob + validate-kb basename accept flows.md
grep -q '\*04-flows.md|\*/flows.md)' "$P/hooks/post-tool-use" \
  && pass "B7: post-tool-use case dispatches */flows.md" \
  || fail "B7: hook case glob missing flows.md"
grep -q '== "flows.md"' "$P/scripts/validate-kb.sh" \
  && pass "B7: validate-kb basename accepts flows.md" \
  || fail "B7: validate-kb basename missing flows.md"

rm -rf "$T"

[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
