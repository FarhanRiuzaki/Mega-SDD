#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD="${PLUGIN_ROOT}/scripts/build-graph.sh"
SRC="${SCRIPT_DIR}/fixtures/project"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$SRC/." "$TMP/"
rc=0

bash "$BUILD" --root "$TMP" >/dev/null 2>&1 || { echo "FAIL: builder errored"; rc=1; }
G="$TMP/.mega-sdd/graph.json"
[ -f "$G" ] || { echo "FAIL: graph.json not written"; rc=1; exit $rc; }

python3 - "$G" <<'PYEOF'
import json, sys
g = json.load(open(sys.argv[1]))
nodes = {n["id"]: n for n in g["nodes"]}
edges = g["edges"]
ok = True
def chk(c, m):
    global ok
    if not c: print("FAIL:", m); ok = False
# namespaced unit + claim ids
chk("sample-vault:U-001" in nodes, "U-001 not namespaced")
chk("sample-vault:C-001" in nodes, "C-001 not namespaced")
# code_anchor keyed by file (no :line in id)
ca = [n for n in g["nodes"] if n["type"]=="code_anchor"]
chk(all(":" not in n["id"].split("/")[-1] or not n["id"].split(":")[-1].isdigit() for n in ca), "anchor id has line")
# implements edge claim->anchor, inherits confidence, has evidence
imp = [e for e in edges if e["relation"]=="implements"]
chk(len(imp) >= 1, "no implements edge")
chk(all("evidence" in e and e["evidence"].get("artifact") for e in imp), "implements edge missing evidence")
# every edge has evidence (anti-hallucination)
chk(all("evidence" in e for e in edges), "edge without evidence")
# _meta freshness block present
chk("source_hashes" in g["_meta"] and "source_glob" in g["_meta"], "missing freshness meta")
chk("binding_stamps" in g["_meta"], "missing binding_stamps")
# no-dangling-edge: every edge source and target must exist in nodes
node_ids = set(nodes.keys())
for e in edges:
    chk(e["source"] in node_ids, f"dangling edge source: {e['source']} (relation={e['relation']})")
    chk(e["target"] in node_ids, f"dangling edge target: {e['target']} (relation={e['relation']})")
sys.exit(0 if ok else 1)
PYEOF
[ $? -eq 0 ] || rc=1
[ $rc -eq 0 ] && echo "PASS: test-build-graph"
exit $rc
