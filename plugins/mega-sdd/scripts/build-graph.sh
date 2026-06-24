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

try:
    import yaml
    def load_yaml(s):
        return yaml.safe_load(s) or {}
except ImportError:
    def load_yaml(s):
        """Minimal YAML parser: handles scalar values, inline lists, and
        top-level list-of-dicts (the modules.yaml pattern). No PyYAML needed."""
        d = {}
        lines = s.splitlines()
        i = 0
        while i < len(lines):
            line = lines[i]
            m = re.match(r'^([A-Za-z0-9_]+):\s*(.*)$', line)
            if m:
                k, v = m.group(1), m.group(2).strip()
                # Inline empty list
                if v == '[]':
                    d[k] = []
                    i += 1
                    continue
                # Inline list
                if v.startswith('[') and v.endswith(']'):
                    d[k] = [x.strip() for x in v[1:-1].split(',') if x.strip()]
                    i += 1
                    continue
                # Non-empty scalar
                if v != '':
                    d[k] = v
                    i += 1
                    continue
                # Empty value: collect indented block
                j = i + 1
                sub_lines = []
                while j < len(lines) and (lines[j].startswith(' ') or
                                           lines[j].startswith('\t') or
                                           lines[j].strip() == ''):
                    sub_lines.append(lines[j])
                    j += 1
                sub_text = '\n'.join(sub_lines)
                # List of dicts pattern (modules.yaml)
                if re.search(r'^\s+-\s+', sub_text, re.M):
                    items = []
                    cur = None
                    for l in sub_lines:
                        item_m = re.match(r'^(\s+)-\s+(.*)', l)
                        if item_m:
                            if cur is not None:
                                items.append(cur)
                            rest = item_m.group(2).strip()
                            cur = [rest] if rest else []
                        elif cur is not None:
                            cur.append(l)
                    if cur is not None:
                        items.append(cur)
                    parsed = []
                    for item_lines in items:
                        item_d = {}
                        for l in item_lines:
                            lm = re.match(r'^\s*([A-Za-z0-9_]+):\s*(.*)$', l)
                            if lm:
                                lk, lv = lm.group(1), lm.group(2).strip()
                                if lv == '[]':
                                    item_d[lk] = []
                                elif lv.startswith('[') and lv.endswith(']'):
                                    item_d[lk] = [x.strip() for x in lv[1:-1].split(',') if x.strip()]
                                elif lv:
                                    item_d[lk] = lv
                        if item_d:
                            parsed.append(item_d)
                    d[k] = parsed
                i = j
            else:
                i += 1
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
    src_hashes[relp(vault_json)] = sha256(vault_json)

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
        src_hashes[relp(bj_path)] = sha256(bj_path)
        bj = json.load(open(bj_path, encoding="utf-8"))
        binding_stamps[vid] = {
            "provenance": bj.get("codebase_map_provenance"),
            "head_at_bind": bj.get("head"),
            "stale_vs_head": bool(head and bj.get("head") and head != bj.get("head"))
        }
        for c in bj.get("claims", []):
            cid = f"{vid}:{c['id']}"
            add_node(cid, "claim", c["id"],
                     {"verdict": c.get("verdict"), "state": c.get("state")},
                     relp(bj_path), "claims[]")

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
        src_hashes[relp(mpath)] = sha256(mpath)
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
        src_hashes[relp(upath)] = sha256(upath)
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
            pending(tid, "oq" if ref.startswith("OQ") else "claim", relp(upath), "binding_refs")
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
    src_hashes[relp(kbpath)] = sha256(kbpath)
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
