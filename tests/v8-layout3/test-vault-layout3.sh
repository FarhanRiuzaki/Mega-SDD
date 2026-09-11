#!/usr/bin/env bash
# test-vault-layout3.sh — v8 P2 (spec 2026-09-10 §3 / App. C2): layout-3 = ONE
# file `context.md`, section grammar identical to layout-2, ONE resolver.
#   L1 detection (marker 3; layout-2 + legacy unchanged)
#   L2 resolve_doc: every legacy / layout-2 name → context.md on layout-3;
#      layout-2 mapping + legacy path byte-identical
#   L3 lock scalars from the context.md frontmatter
#   L4 v3_section slices by H2 (sibling `### <word>` never leaks across)
#   L5 v3_missing_headers contract (4 required, Decisions/Overview optional)
#   B1 derive-vault-json on layout-3: marker 3, doc = context.md, counts,
#      frontmatter pins mirrored (prd_path_at_generation / author / stakeholders)
#   B2 cross-layout parity vs the layout-2 fixture (same content)
#   B3 missing `## Flows` FAILS loud (rc=2, names the header)
#   B4 stray OQ checkbox outside `## Open Questions` FAILS loud
#   B5 layout-2 fixture still derives byte-identically (regression guard)
# Run: bash tests/v8-layout3/test-vault-layout3.sh </dev/null
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
FIX="$HERE/fixtures/context-vault"
FIX2="$P/tests/graph/fixtures/derive-vault-v2"
FIX1="$P/tests/graph/fixtures/derive-vault"
LIB="$P/scripts/_lib"
if [ -f "$LIB/resolve-python.sh" ]; then
  # shellcheck disable=SC1091
  . "$LIB/resolve-python.sh"
  if mega_sdd_python; then PY="$MEGA_SDD_PY"; else echo "SKIP: no usable python"; exit 0; fi
else echo "missing resolve-python.sh"; exit 1; fi
rc=0; fail() { echo "FAIL: $1"; rc=1; }; pass() { echo "PASS: $1"; }

T=$(mktemp -d)
cp -R "$FIX" "$T/v3"; cp -R "$FIX2" "$T/v2"; cp -R "$FIX1" "$T/v1"; rm -f "$T/v1/vault.json" "$T/v2/vault.json"
OUT=$("$PY" - "$LIB" "$T" <<'PYX'
import json, os, sys
lib, t = sys.argv[1], sys.argv[2]
sys.path.insert(0, lib)
import vault_md
r = []
md = open(t + "/v3/context.md", encoding="utf-8").read()
v2 = open(t + "/v2/vault.md", encoding="utf-8").read()
v1 = open(t + "/v1/00-index.md", encoding="utf-8").read()
r.append(("L1-marker", vault_md.vault_layout(md) == 3 and vault_md.vault_layout(v2) == 2 and vault_md.vault_layout(v1) == 1))
r.append(("L1-probe", vault_md.is_layout3_vault(t + "/v3") and not vault_md.is_layout3_vault(t + "/v2")
          and vault_md.vault_layout_of(t + "/v3") == 3 and vault_md.vault_layout_of(t + "/v2") == 2 and vault_md.vault_layout_of(t + "/v1") == 1))
names = ["00-index.md", "01-overview.md", "02-architecture.md", "03-data-model.md", "04-flows.md", "05-decisions.md", "06-constraints.md",
         "vault.md", "model.md", "flows.md", "constraints.md"]
r.append(("L2-v3", all(vault_md.resolve_doc(t + "/v3", n) == os.path.join(t + "/v3", "context.md") for n in names)))
r.append(("L2-v2", vault_md.resolve_doc(t + "/v2", "04-flows.md") == os.path.join(t + "/v2", "flows.md")
          and vault_md.resolve_doc(t + "/v2", "05-decisions.md") == os.path.join(t + "/v2", "vault.md")))
r.append(("L2-v1", vault_md.resolve_doc(t + "/v1", "04-flows.md") == os.path.join(t + "/v1", "04-flows.md")))
lk = vault_md.parse_vault_lock(md)
r.append(("L3-lock", lk == {"vault_version": "1.1", "project_shape": "web-app", "implementation_mode": "new",
                           "mode_migrate_after": None, "prd_status": "draft", "output_mode": "compact", "project_scale": "xs"}))
fl = vault_md.v3_section(md, "04-flows.md"); dm = vault_md.v3_section(md, "03-data-model.md"); dc = vault_md.v3_section(md, "05-decisions.md")
cn = vault_md.v3_section(md, "06-constraints.md")
r.append(("L4-slices", "### F-U-001" in fl and "D-001" not in fl and "Table user" in dm and "### Performance" not in dm
          and "### D-001" in dc and "### Performance" in cn and vault_md.v3_section(md, "00-index.md") == md))
errs = []
ents = vault_md.parse_data_model(dm, errs, doc_name="context.md")
r.append(("L4-no-leak", not errs and {e["name"] for e in ents} == {"user", "leave_request"}
          and next(e for e in ents if e["name"] == "leave_request").get("purpose") == "Leave request lifecycle"))
r.append(("L5-headers", vault_md.v3_missing_headers(md) == []
          and vault_md.v3_missing_headers(md.replace("## Constraints", "## Batasan")) == ["## Constraints"]
          and vault_md.v3_missing_headers(md.replace("## Decisions", "## Keputusan")) == []))
print(json.dumps(r))
PYX
) || { echo "FAIL: python harness crashed"; echo "$OUT"; rm -rf "$T"; exit 1; }
"$PY" -c 'import json,sys
for n,ok in json.loads(sys.argv[1]): print(("PASS: " if ok else "FAIL: ")+n)' "$OUT"
echo "$OUT" | grep -q 'false' && rc=1

# B1/B2/B5 — derive on all three layouts
for v in v3 v2 v1; do
  bash "$P/scripts/derive-vault-json.sh" --vault="$T/$v" </dev/null >"$T/$v.log" 2>&1 \
    && pass "B1: derive-vault-json rc=0 on $v" || { fail "B1: derive failed on $v ($(head -c 300 "$T/$v.log"))"; }
done
B_OUT=$("$PY" - "$T" <<'PYX'
import json, sys
t = sys.argv[1]
v3 = json.load(open(t + "/v3/vault.json")); v2 = json.load(open(t + "/v2/vault.json")); v1 = json.load(open(t + "/v1/vault.json"))
ok = []
ok.append(("B1-layout", v3.get("vault_layout") == 3 and v2.get("vault_layout") == 2 and "vault_layout" not in v1))
ok.append(("B1-docs", {e["doc"] for e in v3["entities"]} == {"context.md"} and {f["doc"] for f in v3["flows"]} == {"context.md"}
           and {a["doc"] for a in v3["adrs"]} == {"context.md"} and {o["doc"] for o in v3["open_questions"]} == {"context.md"}))
ok.append(("B1-counts", len(v3["entities"]) == 2 and len(v3["flows"]) == 2 and len(v3["adrs"]) == 2 and len(v3["open_questions"]) == 7
           and {e["name"] for e in v3["entities"]} == {"user", "leave_request"}))
ok.append(("B1-pins", v3.get("prd_path_at_generation") == "PRD/demo-leave-prd.md" and v3.get("author") == "Farhan ITEC"
           and v3.get("stakeholders") == ["PM demo", "Tech Lead demo"] and v3.get("project_scale") == "xs"
           and v3.get("prd_sha256", "").startswith("0000")))
ok.append(("B1-origin", next(o for o in v3["open_questions"] if o["tag"] == "OQ-FL-2").get("origin") == "context.md#F-U-001"))
def norm(d):
    d = dict(d)
    for k in ("generated_at", "vault_layout", "changelog", "sources", "project_scale", "prd_path_at_generation", "prd_sha256", "author", "stakeholders"):
        d.pop(k, None)
    for cls in ("entities", "flows", "adrs", "open_questions"):
        for e in d.get(cls, []):
            for k in ("doc", "origin", "resolved_at", "deferred_at", "category"):
                e.pop(k, None)
    return d
ok.append(("B2-parity-v3-v2", norm(v3) == norm(v2)))
ok.append(("B5-v2-unchanged", norm(v2) == norm(v1)))
print(json.dumps(ok))
PYX
)
"$PY" -c 'import json,sys
for n,ok in json.loads(sys.argv[1]): print(("PASS: " if ok else "FAIL: ")+n)' "$B_OUT"
echo "$B_OUT" | grep -q 'false' && rc=1

# B3 — hard-header: missing `## Flows` FAILS loud
cp -R "$FIX" "$T/bad"; "$PY" - "$T/bad/context.md" <<'PYX'
import sys; p=sys.argv[1]; s=open(p).read().replace("## Flows", "## Alur"); open(p,"w").write(s)
PYX
OUT3=$(bash "$P/scripts/derive-vault-json.sh" --vault="$T/bad" </dev/null 2>&1); R3=$?
[ "$R3" -eq 2 ] && echo "$OUT3" | grep -q '## Flows' && pass "B3: missing ## Flows → rc=2 naming the header" || fail "B3: rc=$R3 ($(echo "$OUT3" | head -c 200))"

# B4 — stray OQ outside `## Open Questions` FAILS loud
cp -R "$FIX" "$T/stray"; "$PY" - "$T/stray/context.md" <<'PYX'
import sys; p=sys.argv[1]; s=open(p).read().replace("## Decisions\n", "- [ ] **OQ-FL-9** [P2]: stray question\n\n## Decisions\n"); open(p,"w").write(s)
PYX
OUT4=$(bash "$P/scripts/derive-vault-json.sh" --vault="$T/stray" </dev/null 2>&1); R4=$?
[ "$R4" -eq 2 ] && echo "$OUT4" | grep -q 'centralizes' && pass "B4: stray OQ outside ## Open Questions → rc=2" || fail "B4: rc=$R4 ($(echo "$OUT4" | head -c 200))"

rm -rf "$T"
[ $rc -eq 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $rc
