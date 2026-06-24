#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD="${PLUGIN_ROOT}/scripts/build-graph.sh"
SRC="${SCRIPT_DIR}/fixtures/project"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$SRC/." "$TMP/"
rc=0

# Make TMP a git repo so HEAD resolves to a real sha that DIFFERS from the
# fixture binding.json `head` ("abc123fixture") — this drives the
# stale_vs_head staleness branch deterministically.
git -C "$TMP" init -q
git -C "$TMP" config user.email "test@example.com"
git -C "$TMP" config user.name "test"
git -C "$TMP" add -A
git -C "$TMP" commit -q -m "fixture" >/dev/null 2>&1

# Force the hand-rolled YAML fallback (even if PyYAML is installed) so the
# block-style regression guard below exercises the fallback parser on EVERY
# runner — otherwise PyYAML would silently handle the block-style YAML and the
# guard would no-op, re-masking the parser bug on PyYAML-equipped machines.
MEGA_SDD_FORCE_YAML_FALLBACK=1 bash "$BUILD" --root "$TMP" >/dev/null 2>&1 || { echo "FAIL: builder errored"; rc=1; }
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
def rel(r):
    return [e for e in edges if e["relation"] == r]

# namespaced unit + claim ids
chk("sample-vault:U-001" in nodes, "U-001 not namespaced")
chk("sample-vault:C-001" in nodes, "C-001 not namespaced")
# code_anchor keyed by file (no :line in id)
ca = [n for n in g["nodes"] if n["type"]=="code_anchor"]
chk(all(":" not in n["id"].split("/")[-1] or not n["id"].split(":")[-1].isdigit() for n in ca), "anchor id has line")
# implements edge claim->anchor, inherits confidence, has evidence
imp = rel("implements")
chk(len(imp) >= 1, "no implements edge")
chk(all("evidence" in e and e["evidence"].get("artifact") for e in imp), "implements edge missing evidence")
# every edge has evidence (anti-hallucination)
chk(all("evidence" in e for e in edges), "edge without evidence")
# _meta freshness block present
chk("source_hashes" in g["_meta"] and "source_glob" in g["_meta"], "missing freshness meta")
chk("binding_stamps" in g["_meta"], "missing binding_stamps")

# --- Block-style parsing: edges from block-style YAML sequences MUST appear ---
# U-002 uses block-style depends_on/binding_refs; modules.yaml uses block-style
# blocks/blocked_by; cif-customer uses block-style depends_on.
honors = {(e["source"], e["target"]) for e in rel("honors")}
chk(("sample-vault:U-002", "sample-vault:C-002") in honors, "missing honors edge from block-style binding_refs")
deps = {(e["source"], e["target"]) for e in rel("depends_on")}
chk(("sample-vault:U-002", "sample-vault:U-001") in deps, "missing depends_on edge from block-style depends_on")
blocks = {(e["source"], e["target"]) for e in rel("blocks")}
chk(("M-auth", "M-orders") in blocks, "missing blocks edge from block-style modules.yaml")
ddep = {(e["source"], e["target"]) for e in rel("domain_dep")}
chk(("cif-customer", "account-base") in ddep, "missing domain_dep edge from block-style KB depends_on")

# --- Quote artifacts: quoted scalars/list items must NOT keep their quotes ---
# U-002 has `module: "M-orders"`; its in_module edge target + the module node id
# must be bare M-orders (no quotes).
chk("M-orders" in nodes, "M-orders node missing (quote-stripping failed?)")
chk(all('"' not in nid and "'" not in nid for nid in nodes), "node id retains quote chars")
inmod = {(e["source"], e["target"]) for e in rel("in_module")}
chk(("sample-vault:U-002", "M-orders") in inmod, "in_module target retains quotes / wrong")

# --- stale_vs_head: real HEAD != binding.json head ("abc123fixture") -> true ---
bs = g["_meta"]["binding_stamps"].get("sample-vault", {})
chk(g["_meta"].get("head") not in (None, "abc123fixture"), "HEAD did not resolve to a real differing sha")
chk(bs.get("stale_vs_head") is True, f"stale_vs_head not true (got {bs.get('stale_vs_head')!r})")

# no-dangling-edge: every edge source and target must exist in nodes
node_ids = set(nodes.keys())
for e in edges:
    chk(e["source"] in node_ids, f"dangling edge source: {e['source']} (relation={e['relation']})")
    chk(e["target"] in node_ids, f"dangling edge target: {e['target']} (relation={e['relation']})")
print(f"nodes={len(g['nodes'])} edges={len(edges)} "
      f"(honors={len(honors)} depends_on={len(deps)} blocks={len(blocks)} domain_dep={len(ddep)})")
sys.exit(0 if ok else 1)
PYEOF
[ $? -eq 0 ] || rc=1
[ $rc -eq 0 ] && echo "PASS: test-build-graph"
exit $rc
