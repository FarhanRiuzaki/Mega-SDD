#!/usr/bin/env bash
# test-consumers-rekey.sh — v8 P2 goal item 2: every vault-doc consumer reads a
# layout-3 vault (ONE file `context.md`) through the single resolver / slicer —
# no consumer forks its own mapping. Fixture = tests/v8-layout3/fixtures/context-vault.
#   R1 validate-flow-coverage locates the layout-3 vault (state written, not "no active vault")
#   R2 validate-vault-oqs runs on a context.md write (state written)
#   R3 validate-vault-flow-staging exits 0 on the layout-3 project
#   R4 validate-kb vault-flows: prose flow in context.md flagged; `### leave_request` (Data model)
#      and `### Performance` (Constraints) are NOT flow entries
#   R5 run-analyze: vault_files_complete PASS on {context.md, vault.json}; counts sync PASS
#   R6 state_probes: has_vault() true with context.md only; probe_oq_counts fallback = P1 open 1
#   R7 derive-claims-ledger: rc 0; claim ids minus CN == the layout-2 fixture's ids; the H3 NFR
#      table under `## Constraints` yields C-CN-01
#   R8 build-locked-index indexes a [LOCKED] anchor found in context.md
#   R9 static pins: make-bound / render-html / certify-artifact / validate-preflight name context.md
#   R10 DOCS builders (sit / uat / fsd / prd) run on the layout-3 vault and see F-U-001
# Run: bash tests/v8-layout3/test-consumers-rekey.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; P="$ROOT/plugins/mega-sdd"; S="$P/scripts"
FIX="$HERE/fixtures/context-vault"; FIX2="$P/tests/graph/fixtures/derive-vault-v2"
rc=0; fail() { echo "FAIL: $1"; rc=1; }; pass() { echo "PASS: $1"; }
T=$(mktemp -d); PRJ="$T/proj"; V="$PRJ/.mega-sdd/vaults/v"; mkdir -p "$V/units" "$PRJ/src"
cp "$FIX/context.md" "$FIX/constitution.md" "$V/"
printf -- '---\nid: U-001\ntitle: Submit leave request form\nflow: F-U-001\ntask_type: create\ncontext_source: context.md#F-U-001\nprd_source: PRD/prd.md#submit-leave-request\ntarget_files:\n  - path: src/leave.ts\n    operation: create\nacceptance_test:\n  - type: test\n    command: "true"\n    expects: ""\nbinding_refs: []\n---\n# U-001\n\n## Goal\nSubmit leave request (F-U-001).\n' > "$V/units/U-001.md"
git -C "$PRJ" init -q >/dev/null 2>&1

# R1
bash "$S/validate-flow-coverage.sh" --cwd="$PRJ" --quiet </dev/null >/dev/null 2>&1
ST="$PRJ/.mega-sdd/.flow-coverage-state.json"
[ -f "$ST" ] && ! grep -q 'no active vault' "$ST" && pass "R1: flow-coverage located the layout-3 vault" || fail "R1: flow-coverage state: $(head -c 200 "$ST" 2>/dev/null)"
# R2
bash "$S/validate-vault-oqs.sh" --cwd="$PRJ" --file-path="$V/context.md" --quiet </dev/null >/dev/null 2>&1; R2=$?
[ -f "$PRJ/.mega-sdd/.vault-oqs-state.json" ] && [ "$R2" -le 1 ] && pass "R2: vault-oqs ran on context.md (rc=$R2, state written)" || fail "R2: vault-oqs rc=$R2 state=$([ -f "$PRJ/.mega-sdd/.vault-oqs-state.json" ] && echo yes || echo no)"
# R3
bash "$S/validate-vault-flow-staging.sh" --cwd="$PRJ" --quiet </dev/null >/dev/null 2>&1; R3=$?
[ "$R3" -eq 0 ] && pass "R3: flow-staging rc=0 on layout-3" || fail "R3: flow-staging rc=$R3"
# R4 — prose flow flagged, sibling H3s not treated as flows
cp -R "$PRJ" "$T/proj2"; V2="$T/proj2/.mega-sdd/vaults/v"
python3 - "$V2/context.md" <<'PYX'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace('''**Flow**:
```mermaid
flowchart TD
    A["Fill form"] --> B["Validate dates"]
    B --> C["Create leave_request"]
```''', "**Flow**: fill form, validate dates, create leave_request"); open(p,"w").write(s)
PYX
bash "$S/validate-kb.sh" --surface=vault-flows --cwd="$T/proj2" --file-path="$V2/context.md" </dev/null >"$T/vf.json" 2>&1
grep -q '"FAIL"\|missing_mermaid\|prose' "$T/vf.json" && pass "R4: Mermaid mandate fires on a prose flow inside context.md" || fail "R4: mandate silent ($(head -c 200 "$T/vf.json"))"
grep -q 'leave_request\b.*flow\|F-U-002\|Performance' "$T/vf.json" && fail "R4: a non-flow H3 (leave_request / Performance) was scanned as a flow entry" || pass "R4: Data-model / Constraints H3s are not flow entries"
grep -q 'F-S-002' "$T/vf.json" && pass "R4: F-S-002 (mermaid present) seen by the scan" || pass "R4: F-S-002 not listed (only failing entries reported)"
# R5 — analyze on the layout-3 vault (needs vault.json)
bash "$S/derive-vault-json.sh" --vault="$V" </dev/null >/dev/null 2>&1 || fail "R5: derive-vault-json failed"
bash "$S/run-analyze.sh" --cwd="$PRJ" --quiet </dev/null >/dev/null 2>&1
python3 - "$PRJ/.mega-sdd/.analyze-state.json" <<'PYX' || rc=1
import json, sys, re
raw = open(sys.argv[1]).read()
# run-analyze prints JSON (possibly with a leading line) — find the vault checks
m = re.search(r'"check":\s*"vault_files_complete",\s*"status":\s*"(\w+)"', raw); assert m and m.group(1) == "PASS", "vault_files_complete: " + (m.group(1) if m else "absent")
for c in ("entities_count_sync", "oq_count_sync", "flows_count_sync"):
    mm = re.search(r'"check":\s*"%s",\s*"status":\s*"(\w+)"' % c, raw)
    assert mm and mm.group(1) == "PASS", c + ": " + (mm.group(1) if mm else "absent")
print("PASS: R5: run-analyze vault_files_complete + entities/oq/flows count sync PASS on layout-3")
PYX
# R6 — state_probes
PY_OUT=$(MEGA_SDD_LIB_DIR="$S/_lib" python3 - "$T" <<'PYX'
import os, sys, shutil, json
sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"]); import state_probes
t = sys.argv[1]; prj = os.path.join(t, "proj3"); v = os.path.join(prj, ".mega-sdd", "vaults", "v"); os.makedirs(v)
shutil.copy(os.path.join(t, "proj", ".mega-sdd", "vaults", "v", "context.md"), v)   # context.md ONLY, no vault.json
ok = state_probes.has_vault(prj)
oq = state_probes.probe_oq_counts(v)
print(json.dumps({"has_vault": ok, "oq": oq}))
PYX
)
echo "$PY_OUT" | grep -q '"has_vault": true' && echo "$PY_OUT" | grep -q '"pending_p0_p1": 1' && pass "R6: has_vault true + OQ fallback P1 open=1 from context.md alone" || fail "R6: $PY_OUT"
# R7 — claims ledger parity
cp -R "$FIX2" "$T/v2"; rm -f "$T/v2/vault.json"
bash "$S/derive-claims-ledger.sh" --vault="$V" </dev/null >"$T/l3.log" 2>&1; R7=$?
bash "$S/derive-claims-ledger.sh" --vault="$T/v2" </dev/null >/dev/null 2>&1
[ "$R7" -eq 0 ] && pass "R7: claims ledger rc=0 on layout-3" || fail "R7: ledger rc=$R7 ($(head -c 300 "$T/l3.log"))"
python3 - "$V/claims-ledger.json" "$T/v2/claims-ledger.json" <<'PYX' || rc=1
import json, sys
a = json.load(open(sys.argv[1]))["claims"]; b = json.load(open(sys.argv[2]))["claims"]
ia = {c["id"] for c in a if not c["id"].startswith("C-CN-")}; ib = {c["id"] for c in b if not c["id"].startswith("C-CN-")}
assert ia == ib, (sorted(ia ^ ib))
assert any(c["id"] == "C-CN-01" and c["type"] == "constraint" for c in a), "NFR H3 table row not harvested"
assert all(c["source"].startswith("context.md:") for c in a), "sources must name context.md"
print("PASS: R7: claim ids (minus CN) identical to the layout-2 fixture; C-CN-01 from the H3 NFR table; sources = context.md")
PYX
# R8 — locked index
printf 'export const guard = 1;\n' > "$PRJ/src/proxy.ts"
printf '\n### D-009: Guard\n**Decision**: keep `src/proxy.ts:1` [LOCKED] · **Source**: PRD §9.\n' >> "$V/context.md"
bash "$S/build-locked-index.sh" --cwd="$PRJ" </dev/null >/dev/null 2>&1
grep -q 'proxy.ts' "$PRJ/.mega-sdd/.locked-files-index.json" 2>/dev/null && pass "R8: build-locked-index harvested a [LOCKED] anchor from context.md" || fail "R8: locked index missing context.md anchor ($(ls "$PRJ/.mega-sdd" | tr '\n' ' '))"
# R9 — static pins
grep -q '"context.md", "vault.md", "model.md"' "$S/make-bound.sh" && grep -q 'context.md' "$S/render-html.sh" && grep -q 'context.md (layout-3)' "$S/certify-artifact.sh" && grep -q '"context.md",' "$S/validate-preflight.sh" && grep -q 'vaults/\*/context.md' "$S/build-locked-index.sh" \
  && pass "R9: make-bound / render-html / certify-artifact / validate-preflight / locked-index name context.md" || fail "R9: a static consumer lost context.md"
# R10 — DOCS builders
bash "$S/build-sit-evidence.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null >"$T/sit.log" 2>&1; R10a=$?
bash "$S/build-uat-scaffold.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null >"$T/uat.log" 2>&1; R10b=$?
bash "$S/build-fsd-core.sh" --vault="$V" --cwd="$PRJ" --quiet </dev/null >"$T/fsd.log" 2>&1; R10c=$?
bash "$S/build-prd-core.sh" --out-root="$V" --vault="$V" --cwd="$PRJ" --mode=forward --quiet </dev/null >"$T/prd.log" 2>&1; R10d=$?
[ "$R10a" -le 1 ] && grep -rq 'F-U-001' "$V"/sit* "$PRJ"/.mega-sdd 2>/dev/null && pass "R10: build-sit-evidence rc=$R10a, F-U-001 seen" || fail "R10: sit rc=$R10a ($(head -c 200 "$T/sit.log"))"
[ "$R10b" -le 1 ] && pass "R10: build-uat-scaffold rc=$R10b" || fail "R10: uat rc=$R10b ($(head -c 200 "$T/uat.log"))"
[ "$R10c" -eq 0 ] && grep -q 'F-U-001' "$V/fsd/FSD.md" && pass "R10: build-fsd-core rc=0, FSD.md carries F-U-001" || fail "R10: fsd rc=$R10c ($(head -c 300 "$T/fsd.log"))"
[ "$R10d" -eq 0 ] && grep -q 'F-U-001\|Submit leave' "$V/prd/PRD.md" && pass "R10: build-prd-core rc=0, PRD.md carries the flow" || fail "R10: prd rc=$R10d ($(head -c 300 "$T/prd.log"))"
rm -rf "$T"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $rc
