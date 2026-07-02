#!/usr/bin/env bash
# Derive .mega-sdd/graph.json from existing artifacts. Deterministic, no code re-scan.
# Usage: build-graph.sh --root <project-root> [--out <output-path>]
set -u
ROOT="."; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;;
  --out) OUT="$2"; shift 2;; --out=*) OUT="${1#*=}"; shift;;
  *) shift;; esac; done

MEGA="${ROOT}/.mega-sdd"
[ -n "$OUT" ] || OUT="${MEGA}/graph.json"
HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo null)"

ROOT="$ROOT" OUT="$OUT" HEAD="$HEAD" python3 <<'PYEOF'
import json, os, re, hashlib, glob
from datetime import datetime, timezone

root = os.environ["ROOT"]; out = os.environ["OUT"]
head = os.environ["HEAD"]; head = None if head == "null" else head
mega = os.path.join(root, ".mega-sdd")

# When MEGA_SDD_FORCE_YAML_FALLBACK=1, skip PyYAML and use the hand-rolled
# parser even if PyYAML is importable. The test suite sets this so the
# block-style regression guard exercises the fallback on ANY runner (with or
# without PyYAML). Unset → normal PyYAML-preferred behavior.
_FORCE_FALLBACK = os.environ.get("MEGA_SDD_FORCE_YAML_FALLBACK") == "1"

try:
    if _FORCE_FALLBACK:
        raise ImportError  # force the except branch (the hand-rolled parser)
    import yaml
    def load_yaml(s):
        return yaml.safe_load(s) or {}
except ImportError:
    # PyYAML is frequently absent (e.g. system python3). This fallback is then
    # the LIVE parser, not a backstop — it must handle every artifact form the
    # mega-sdd pipeline actually emits: scalars (quoted/with comments), inline
    # lists, block-style scalar sequences, and a top-level list-of-dicts
    # (modules.yaml) with nested block sequences one level deep.
    def _scalar(v):
        """Normalize a scalar: strip matched surrounding quotes; strip an
        unquoted trailing comment. A quoted value keeps any '#' inside it."""
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
            return v[1:-1]
        v = re.sub(r'\s+#.*$', '', v).strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in ('"', "'"):
            return v[1:-1]
        return v

    def _inline_list(v):
        return [_scalar(x) for x in v[1:-1].split(',') if x.strip()]

    def _parse_dict_item(item_lines):
        """Parse the lines of one '- ' list item into a dict. Supports nested
        block-style scalar sequences one level deep (e.g. a module's blocks:)."""
        item_d = {}
        li, m = 0, len(item_lines)
        while li < m:
            lm = re.match(r'^\s*([A-Za-z0-9_]+):\s*(.*)$', item_lines[li])
            if not lm:
                li += 1
                continue
            lk, lv = lm.group(1), lm.group(2).strip()
            if lv == '[]':
                item_d[lk] = []; li += 1; continue
            if lv.startswith('[') and lv.endswith(']'):
                item_d[lk] = _inline_list(lv); li += 1; continue
            if lv != '':
                item_d[lk] = _scalar(lv); li += 1; continue
            # Empty value -> nested block scalar sequence
            sub, lj = [], li + 1
            while lj < m and re.match(r'^\s*-\s', item_lines[lj]):
                sub.append(_scalar(re.match(r'^\s*-\s*(.*)$', item_lines[lj]).group(1)))
                lj += 1
            item_d[lk] = sub
            li = lj
        return item_d

    def load_yaml(s):
        d = {}
        lines = s.splitlines()
        i, n = 0, len(lines)
        while i < n:
            m = re.match(r'^([A-Za-z0-9_]+):\s*(.*)$', lines[i])
            if not m:
                i += 1
                continue
            k, v = m.group(1), m.group(2).strip()
            if v == '[]':
                d[k] = []; i += 1; continue
            if v.startswith('[') and v.endswith(']'):
                d[k] = _inline_list(v); i += 1; continue
            if v != '':
                d[k] = _scalar(v); i += 1; continue
            # Empty value: collect the indented block that follows
            j = i + 1
            sub_lines = []
            while j < n and (lines[j].startswith(' ') or lines[j].startswith('\t')
                             or lines[j].strip() == ''):
                sub_lines.append(lines[j])
                j += 1
            marker_lines = [l for l in sub_lines if re.match(r'^(\s*)-(\s|$)', l)]
            if marker_lines:
                # Item-level indent = indentation of the FIRST '- ' marker.
                # Deeper markers belong to a nested block inside the current item.
                item_indent = len(re.match(r'^(\s*)-', marker_lines[0]).group(1))
                items, cur = [], None
                for l in sub_lines:
                    im = re.match(r'^(\s*)-\s*(.*)$', l)
                    if im and len(im.group(1)) == item_indent:
                        if cur is not None:
                            items.append(cur)
                        rest = im.group(2)
                        cur = [rest] if rest.strip() else []
                    elif cur is not None:
                        cur.append(l)
                if cur is not None:
                    items.append(cur)
                # list-of-dicts iff any item line is a "key:" mapping
                is_dict_list = any(
                    re.match(r'^\s*[A-Za-z0-9_]+:(\s|$)', il)
                    for it in items for il in it)
                if is_dict_list:
                    d[k] = [di for it in items if (di := _parse_dict_item(it))]
                else:
                    d[k] = [_scalar(it[0]) for it in items if it and it[0].strip()]
            # else: nested mapping under an empty key — not used by current artifacts
            i = j
        return d

def frontmatter(path):
    txt = open(path, encoding="utf-8").read()
    m = re.match(r'^---\n(.*?)\n---', txt, re.S)
    return (load_yaml(m.group(1)) if m else {}), txt

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""): h.update(chunk)
    return h.hexdigest()

nodes, node_ids, edges = {}, set(), []
src_hashes = {}
GLOBS = [".mega-sdd/vaults/*/vault.json", ".mega-sdd/vaults/*/binding.json",
         ".mega-sdd/vaults/*/units/*.md", ".mega-sdd/vaults/*/_meta/modules.yaml",
         ".mega-sdd/knowledge-base/**/*.md"]

def relp(p): return os.path.relpath(p, root)

# Freshness hashing is decoupled from node contribution: hash EVERY file matching
# a source glob, mirroring query-graph.sh's pre-check exactly (same GLOBS, same
# recursive flag, same relpath). This guarantees the builder's source_hashes
# key-set == the query's hashed key-set, so a domain-less KB file, an overview/
# index file, or a `_`-prefixed unit (none of which contribute a node) no longer
# makes set(cur) != set(old) and force a rebuild on every query.
for pat in GLOBS:
    for p in glob.glob(os.path.join(root, pat), recursive=True):
        src_hashes[relp(p)] = sha256(p)

def add_node(nid, ntype, label, attrs, artifact, field):
    if nid in node_ids:
        if attrs: nodes[nid]["attrs"].update(attrs)
        nodes[nid]["attrs"].pop("pending", None)
        return
    node_ids.add(nid)
    nodes[nid] = {"id": nid, "type": ntype, "label": label or nid,
                  "attrs": attrs or {}, "source": {"artifact": artifact, "field": field}}

def pending(nid, ntype, artifact, field):
    if nid not in node_ids:
        node_ids.add(nid)
        nodes[nid] = {"id": nid, "type": ntype, "label": nid, "attrs": {"pending": True},
                      "source": {"artifact": artifact, "field": field}}

def anchor_id(s):
    """Normalize file:line -> file path only."""
    return re.sub(r':\d+(-\d+)?$', '', s.strip())

def add_edge(s, t, rel, conf, artifact, field):
    edges.append({"source": s, "target": t, "relation": rel, "confidence": conf,
                  "evidence": {"artifact": artifact, "field": field}})

binding_stamps = {}

for vault_json in sorted(glob.glob(os.path.join(mega, "vaults", "*", "vault.json"))):
    vdir = os.path.dirname(vault_json)
    vid = os.path.basename(vdir)

    # vault node: bare slug per schema ("vault (slug) stays bare")
    add_node(vid, "vault", vid, {}, relp(vault_json), "vault.json")

    vj = json.load(open(vault_json, encoding="utf-8"))

    # Build flow_doc_index for Resolution 1 (covers edge)
    # Maps basename(doc) -> namespaced flow id, to resolve vault_source references
    flow_doc_index = {}
    for fl in vj.get("flows", []):
        fid = f"{vid}:{fl['id']}"
        add_node(fid, "flow", fl.get("title", fl["id"]), {"doc": fl.get("doc")},
                 relp(vault_json), "flows[]")
        if fl.get("doc"):
            doc_basename = os.path.basename(fl["doc"])
            flow_doc_index[doc_basename] = fid
        for kb in fl.get("_kb_source", []) or []:
            # kb_source edges: flow -> kb_domain (domain id = stem of kb path)
            dom = os.path.splitext(os.path.basename(kb))[0]
            pending(dom, "kb_domain", relp(vault_json), "flows[]._kb_source")
            add_edge(fid, dom, "kb_source", "VERIFIED", relp(vault_json), "flows[]._kb_source")

    # binding.json -> claims + implements + covers
    bj_path = os.path.join(vdir, "binding.json")
    if os.path.exists(bj_path):
        bj = json.load(open(bj_path, encoding="utf-8"))
        binding_stamps[vid] = {
            "provenance": bj.get("codebase_map_provenance"),
            "head_at_bind": bj.get("head"),
            "stale_vs_head": bool(head and bj.get("head") and head != bj.get("head"))
        }
        for c in bj.get("claims", []):
            cid = f"{vid}:{c['id']}"
            # S5 GU-GRAPH-CONFLICT-1: carry the v4.57.0 sidecar fields — the
            # impact lens must distinguish a resolved-KEEP_VAULT conflict from a
            # live one, and a truncation-UNKNOWN from a dynamic-route UNKNOWN.
            _attrs = {"verdict": c.get("verdict"), "state": c.get("state")}
            if c.get("state_reason"):
                _attrs["state_reason"] = c.get("state_reason")
            if c.get("resolution"):
                _attrs["resolution"] = c.get("resolution")
            add_node(cid, "claim", c["id"], _attrs, relp(bj_path), "claims[]")

            # implements: claim -> code_anchor (file path only, line in attrs)
            anc = c.get("anchor")
            if anc and anc not in ("—", "n/a", None):
                for piece in re.split(r'\s*\+\s*', anc):
                    piece = piece.strip()
                    if not piece:
                        continue
                    if ":" in piece or "/" in piece or re.search(r'\.(php|py|ts|js|rb|go|java|cs|ex)$', piece):
                        aid = anchor_id(piece)
                        if not aid:
                            continue
                        line_part = piece[len(aid):].lstrip(":")
                        line_val = line_part if line_part else None
                        add_node(aid, "code_anchor", aid,
                                 {"line": line_val} if line_val else {},
                                 relp(bj_path), "claims[].anchor")
                        # Resolution 3: confidence = claim confidence OR verdict OR "VERIFIED"
                        conf = c.get("confidence") or c.get("verdict") or "VERIFIED"
                        add_edge(cid, aid, "implements", conf, relp(bj_path), "claims[].anchor")

            # covers: claim -> flow (Resolution 1: only emit when vault_source resolves to a known flow)
            vs = c.get("vault_source")
            if vs and vs not in ("—", "n/a", None):
                # Strip line number from vault_source (e.g. "04-flows.md:12" -> "04-flows.md")
                vs_file = re.sub(r':\d+(-\d+)?$', '', str(vs))
                vs_basename = os.path.basename(vs_file)
                flow_target = flow_doc_index.get(vs_basename)
                if flow_target:
                    add_edge(cid, flow_target, "covers", "VERIFIED", relp(bj_path), "claims[].vault_source")
                # else: cannot resolve to a known flow node -> OMIT (Resolution 1)

    # modules.yaml: module nodes + blocks edges
    # Resolution 2: module id is used bare, verbatim (e.g. M-auth), no namespacing
    mpath = os.path.join(vdir, "_meta", "modules.yaml")
    if os.path.exists(mpath):
        my = load_yaml(open(mpath, encoding="utf-8").read())
        for mod in (my.get("modules") or []):
            mid = mod.get("id")
            if not mid:
                continue
            add_node(mid, "module", mid, {}, relp(mpath), "modules[]")
            for b in mod.get("blocks", []) or []:
                pending(b, "module", relp(mpath), "modules[].blocks")
                add_edge(mid, b, "blocks", "VERIFIED", relp(mpath), "modules[].blocks")

    # units: unit nodes + depends_on + honors + in_module edges
    for upath in sorted(glob.glob(os.path.join(vdir, "units", "*.md"))):
        if os.path.basename(upath).startswith("_"):
            continue
        fm, _ = frontmatter(upath)
        uid_local = os.path.splitext(os.path.basename(upath))[0]
        uid = f"{vid}:{uid_local}"
        add_node(uid, "unit", uid_local,
                 {"module": fm.get("module"), "task_type": fm.get("task_type"), "squad": fm.get("squad")},
                 relp(upath), "frontmatter")
        for dep in fm.get("depends_on", []) or []:
            tid = f"{vid}:{dep}"
            pending(tid, "unit", relp(upath), "depends_on")
            add_edge(uid, tid, "depends_on", "VERIFIED", relp(upath), "frontmatter.depends_on")
        for ref in fm.get("binding_refs", []) or []:
            tid = f"{vid}:{ref}"
            # S5 GU-GRAPH-CONFLICT-1: the CONFLICT-NNN refs the moat REQUIRES
            # units to carry were typed "claim" — permanently-pending mislabeled
            # nodes on the impact lens. Type them by their real namespace.
            _rt = "oq" if ref.startswith("OQ") else ("conflict" if ref.startswith("CONFLICT") else "claim")
            pending(tid, _rt, relp(upath), "binding_refs")
            add_edge(uid, tid, "honors", "VERIFIED", relp(upath), "frontmatter.binding_refs")
        # Resolution 2: module id bare
        mod = fm.get("module")
        if mod:
            pending(mod, "module", relp(upath), "frontmatter.module")
            add_edge(uid, mod, "in_module", "VERIFIED", relp(upath), "frontmatter.module")

# KB domains: kb_domain nodes + domain_dep edges
for kbpath in sorted(glob.glob(os.path.join(mega, "knowledge-base", "**", "*.md"), recursive=True)):
    fm, _ = frontmatter(kbpath)
    dom = fm.get("domain")
    if not dom:
        continue
    add_node(dom, "kb_domain", dom,
             {"classification": fm.get("classification")},
             relp(kbpath), "frontmatter")
    for d in fm.get("depends_on", []) or []:
        pending(d, "kb_domain", relp(kbpath), "depends_on")
        add_edge(dom, d, "domain_dep", "VERIFIED", relp(kbpath), "frontmatter.depends_on")

graph = {
    "schema_version": "1.0",
    "_meta": {
        "derived": True,
        "generated_by": "build-graph@1.0.0",
        "built_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "head": head,
        "source_glob": GLOBS,
        "source_hashes": src_hashes,
        "binding_stamps": binding_stamps,
    },
    "nodes": list(nodes.values()),
    "edges": edges,
}

os.makedirs(os.path.dirname(out), exist_ok=True)
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(graph, f, indent=2)
os.replace(tmp, out)
print(f"graph.json: {len(nodes)} nodes, {len(edges)} edges -> {out}")
PYEOF
