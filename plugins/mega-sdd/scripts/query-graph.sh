#!/usr/bin/env bash
# Impact/blast-radius query over .mega-sdd/graph.json. Lazy-rebuild when stale.
# v7 Fase 2 merge group 6: also hosts the per-module status rollup as the
# --modules mode (merged verbatim from the former list-modules.sh — reads
# modules.yaml + unit frontmatter + bolt-outcomes.json, read-only, no graph
# involvement; exit 0 rollup / 1 vault not found / 2 usage).
#   query-graph.sh --modules [vault-path] [--cwd=<p>] [--module=<id>] [--format=table|json]
set -u

# ─── --modules mode (merged list-modules.sh) — handled before the impact args ─
if [ "${1:-}" = "--modules" ]; then
shift
VAULT_ARG=""
CWD="."
ONLY_MODULE=""
FORMAT="table"

for arg in "$@"; do
  case "$arg" in
    --cwd=*)      CWD="${arg#*=}" ;;
    --module=*)   ONLY_MODULE="${arg#*=}" ;;
    --format=*)   FORMAT="${arg#*=}" ;;
    -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
    --*)          echo "list-modules: unknown argument: $arg" >&2; exit 2 ;;
    *)            if [ -z "$VAULT_ARG" ]; then VAULT_ARG="$arg";
                  else echo "list-modules: unexpected extra argument: $arg" >&2; exit 2; fi ;;
  esac
done

case "$FORMAT" in table|json) : ;; *) echo "list-modules: --format must be table|json (got: $FORMAT)" >&2; exit 2 ;; esac
[ -d "$CWD" ] || { echo "list-modules: --cwd is not a directory: $CWD" >&2; exit 2; }

# Deterministic compute + render in python3. YAML parsing mirrors build-graph.sh:
# PyYAML-preferred with a hand-rolled fallback (PyYAML is frequently absent on a
# system python3). MEGA_SDD_FORCE_YAML_FALLBACK=1 forces the fallback for tests.
CWD="$CWD" VAULT_ARG="$VAULT_ARG" ONLY_MODULE="$ONLY_MODULE" FORMAT="$FORMAT" \
python3 <<'PYEOF'
import glob
import json
import os
import re
import sys

cwd         = os.environ["CWD"]
vault_arg   = os.environ["VAULT_ARG"]
only_module = os.environ["ONLY_MODULE"]
fmt         = os.environ["FORMAT"]


def die(msg, code):
    print("list-modules: " + msg, file=sys.stderr)
    sys.exit(code)


# --- YAML (PyYAML-preferred, hand-rolled fallback) — mirrors build-graph.sh -----
_FORCE_FALLBACK = os.environ.get("MEGA_SDD_FORCE_YAML_FALLBACK") == "1"
try:
    if _FORCE_FALLBACK:
        raise ImportError
    import yaml
    def load_yaml(s):
        return yaml.safe_load(s) or {}
except ImportError:
    def _scalar(v):
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
            j = i + 1
            sub_lines = []
            while j < n and (lines[j].startswith(' ') or lines[j].startswith('\t')
                             or lines[j].strip() == ''):
                sub_lines.append(lines[j])
                j += 1
            marker_lines = [l for l in sub_lines if re.match(r'^(\s*)-(\s|$)', l)]
            if marker_lines:
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
                is_dict_list = any(
                    re.match(r'^\s*[A-Za-z0-9_]+:(\s|$)', il)
                    for it in items for il in it)
                if is_dict_list:
                    d[k] = [di for it in items if (di := _parse_dict_item(it))]
                else:
                    d[k] = [_scalar(it[0]) for it in items if it and it[0].strip()]
            i = j
        return d


def frontmatter_dict(path):
    try:
        txt = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return {}
    m = re.match(r'^---\n(.*?)\n---', txt, re.S)
    return load_yaml(m.group(1)) if m else {}


# --- Resolve vault dir (mirror analyze-parallelism.sh) ------------------------
def has_units(d):
    return bool(glob.glob(os.path.join(d, "units", "U-*.md")) or
                glob.glob(os.path.join(d, "units", "U-*", "unit.md")))


if vault_arg:
    cand = vault_arg if os.path.isabs(vault_arg) else os.path.join(cwd, vault_arg)
    if not os.path.isdir(cand):
        die("vault not found: %s" % vault_arg, 1)
    vault_dir = cand
else:
    vault_dir = None
    for container in (os.path.join(cwd, ".mega-sdd", "vaults"),
                      os.path.join(cwd, "docs", "mega-sdd", "vaults")):
        if not os.path.isdir(container):
            continue
        for slug in sorted(glob.glob(os.path.join(container, "*"))):
            if os.path.isdir(slug) and has_units(slug):
                vault_dir = slug
                break
        if vault_dir:
            break
    if not vault_dir:
        die("no vault with units/ found under .mega-sdd/vaults/ or docs/mega-sdd/vaults/ "
            "(pass a vault-path explicitly)", 1)

vault_name = os.path.basename(vault_dir.rstrip("/"))
vj_path = os.path.join(vault_dir, "vault.json")
if os.path.isfile(vj_path):
    try:
        with open(vj_path) as f:
            vj = json.load(f)
        vault_name = vj.get("title") or vj.get("name") or vj.get("slug") or vault_name
    except Exception as e:
        die("vault.json corrupt (%s): %s" % (vj_path, e), 1)

# --- Load modules.yaml (or .auto, or synthesize M-default) --------------------
modules_source = "modules.yaml"
mpath = os.path.join(vault_dir, "_meta", "modules.yaml")
if not os.path.isfile(mpath):
    apath = os.path.join(vault_dir, "_meta", "modules.yaml.auto")
    if os.path.isfile(apath):
        mpath, modules_source = apath, "modules.yaml.auto"
    else:
        mpath, modules_source = None, "implicit (M-default)"

raw_modules = []
if mpath:
    try:
        doc = load_yaml(open(mpath, encoding="utf-8", errors="replace").read())
    except Exception as e:
        die("modules.yaml unreadable (%s): %s" % (mpath, e), 1)
    raw_modules = doc.get("modules") or []
    if not isinstance(raw_modules, list):
        raw_modules = []

# normalize module records
def as_list(v):
    if v is None:
        return []
    return v if isinstance(v, list) else [v]

modules = []
for m in raw_modules:
    if not isinstance(m, dict) or not m.get("id"):
        continue
    modules.append({
        "id": str(m["id"]).strip(),
        "name": str(m.get("name") or "").strip(),
        "dod": [str(x) for x in as_list(m.get("dod"))],
        "priority": str(m.get("priority") or "").strip(),
        "blocked_by": [str(x).strip() for x in as_list(m.get("blocked_by"))],
        "blocks": [str(x).strip() for x in as_list(m.get("blocks"))],
    })

defined_ids = {m["id"] for m in modules}
modules_defined = bool(modules)

# --- Unit membership (frontmatter `module:`) ----------------------------------
unit_files = sorted(glob.glob(os.path.join(vault_dir, "units", "U-*.md")) +
                    glob.glob(os.path.join(vault_dir, "units", "U-*", "unit.md")))
unit_module = {}        # unit_id -> module id (or "M-default" / "M-unassigned")
for uf in unit_files:
    fm = frontmatter_dict(uf)
    uid = str(fm.get("id") or fm.get("unit_id") or
              os.path.splitext(os.path.basename(uf))[0]).strip()
    mod = str(fm.get("module") or "").strip()
    if modules_defined:
        unit_module[uid] = mod if mod in defined_ids else "M-unassigned"
    else:
        unit_module[uid] = mod or "M-default"

# If no modules.yaml, synthesize from whatever module ids the units carry
# (typically just M-default); guarantees at least one row when units exist.
if not modules_defined:
    seen = []
    for uid in unit_module:
        mid = unit_module[uid]
        if mid not in seen:
            seen.append(mid)
    modules = [{"id": mid, "name": "", "dod": [], "priority": "",
                "blocked_by": [], "blocks": []} for mid in (seen or ["M-default"])]
    defined_ids = {m["id"] for m in modules}

# M-unassigned pseudo-module (only if some unit fell through)
unassigned = [u for u, mid in unit_module.items() if mid == "M-unassigned"]
if unassigned and "M-unassigned" not in defined_ids:
    modules.append({"id": "M-unassigned", "name": "(no module match)", "dod": [],
                    "priority": "", "blocked_by": [], "blocks": []})
    defined_ids.add("M-unassigned")

if only_module:
    if only_module not in defined_ids:
        die("unknown module: %s (valid: %s)" %
            (only_module, ", ".join(sorted(defined_ids)) or "none"), 2)

# --- Per-unit status from bolt-outcomes.json (latest entry wins) --------------
status_of = {}          # unit_id -> "completed" | "halted_*" | None
bo_path = os.path.join(vault_dir, ".memory", "bolt-outcomes.json")
if os.path.isfile(bo_path):
    try:
        bo = json.load(open(bo_path))
        for b in bo.get("bolts", []) or []:
            uid = str(b.get("unit_id") or "").strip()
            st = b.get("status")
            if uid and st:
                status_of[uid] = st     # append-only → last wins = current
    except Exception:
        pass                            # tolerate a malformed/absent memory file


def dod_done(item):
    return bool(re.match(r'^\[[xX]\]', item.strip()))


# --- Compute per-module rollup ------------------------------------------------
def members(mid):
    return [u for u, m in unit_module.items() if m == mid]

rollup = {}
for m in modules:
    mem = members(m["id"])
    total = len(mem)
    completed = sum(1 for u in mem if status_of.get(u) == "completed")
    in_prog = sum(1 for u in mem if str(status_of.get(u) or "").startswith("halted"))
    pending = total - completed - in_prog
    dod_total = len(m["dod"])
    dod_done_n = sum(1 for it in m["dod"] if dod_done(it))
    if total == 0:
        label = "no-units"
    elif completed == 0:
        label = "not-started"
    elif completed < total:
        label = "in-progress"
    elif dod_total and dod_done_n < dod_total:
        label = "units-complete"
    else:
        label = "completed"
    rollup[m["id"]] = {
        "id": m["id"], "name": m["name"], "priority": m["priority"],
        "status": label,
        "units": {"completed": completed, "in_progress": in_prog,
                  "pending": pending, "total": total},
        "dod": {"done": dod_done_n, "total": dod_total},
        "blocked_by": m["blocked_by"], "pending_units": [u for u in sorted(mem)
                     if status_of.get(u) != "completed"],
    }

# blocked_by resolution (a blocker is satisfied iff its module status == completed)
def satisfied(mid):
    r = rollup.get(mid)
    return r is not None and r["status"] == "completed"

for r in rollup.values():
    r["blocked_by_resolved"] = [{"id": b, "satisfied": satisfied(b)} for b in r["blocked_by"]]

# actionable = a started-or-startable module that is NOT itself complete and whose
# blockers are all satisfied (deterministic; the command phrases the suggestion)
actionable = [r["id"] for r in rollup.values()
              if r["status"] in ("not-started", "in-progress", "units-complete")
              and all(b["satisfied"] for b in r["blocked_by_resolved"])]

order = [m["id"] for m in modules]
if only_module:
    order = [only_module]

# --- Render -------------------------------------------------------------------
def fmt_blocked(r):
    if not r["blocked_by_resolved"]:
        return "(none)"
    parts = []
    for b in r["blocked_by_resolved"]:
        parts.append("%s (%s)" % (b["id"], "ok" if b["satisfied"] else "pending"))
    return ", ".join(parts)


total_units = len(unit_files)

if fmt == "json":
    print(json.dumps({
        "vault": vault_name,
        "modules_source": modules_source,
        "total_units": total_units,
        "module_count": len([m for m in modules if m["id"] != "M-unassigned"]),
        "modules": [rollup[mid] for mid in order],
        "actionable": [a for a in actionable if (not only_module or a == only_module)],
    }, indent=2))
    sys.exit(0)

# table
print("Vault: %s  (%s)" % (vault_name, modules_source))
print("Total units: %d | Modules: %d" %
      (total_units, len([m for m in modules if m["id"] != "M-unassigned"])))
print()
hdr = "%-16s %-26s %-15s %-7s %-6s %-9s %s" % (
    "ID", "Name", "Status", "Units", "DoD", "Priority", "Blocked-by")
print(hdr)
print("-" * len(hdr))
for mid in order:
    r = rollup[mid]
    units_c = "%d/%d" % (r["units"]["completed"], r["units"]["total"])
    dod_c = "%d/%d" % (r["dod"]["done"], r["dod"]["total"])
    print("%-16s %-26s %-15s %-7s %-6s %-9s %s" % (
        r["id"], (r["name"] or "")[:26], r["status"], units_c, dod_c,
        r["priority"] or "-", fmt_blocked(r)))

if unassigned:
    print()
    print("⚠  %d unit(s) have no module match (M-unassigned): %s" %
          (len(unassigned), ", ".join(sorted(unassigned))))

# deterministic cross-module facts (the command turns these into hand-off prose)
blocked_notes = []
for mid in order:
    r = rollup[mid]
    unmet = [b["id"] for b in r["blocked_by_resolved"] if not b["satisfied"]]
    if unmet and r["status"] != "completed":
        blocked_notes.append("%s blocked-by %s" % (r["id"], ", ".join(unmet)))
if blocked_notes:
    print()
    for note in blocked_notes:
        print("⚠  %s" % note)
if actionable:
    print()
    print("Unblocked & actionable: %s" %
          ", ".join(a for a in actionable if (not only_module or a == only_module)))
PYEOF
exit $?
fi

ROOT="."; TARGET=""; DIR="downstream"
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;;
  --impact) TARGET="$2"; shift 2;; --impact=*) TARGET="${1#*=}"; shift;;
  --upstream) DIR="upstream"; shift;; --downstream) DIR="downstream"; shift;;
  *) shift;; esac; done
[ -n "$TARGET" ] || { echo "usage: query-graph.sh --root <p> --impact <id|file[:line]> [--upstream|--downstream]" >&2; exit 3; }

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEGA="${ROOT}/.mega-sdd"; G="${MEGA}/graph.json"

# --- Freshness: rebuild if missing, path-set changed, or any source hash moved ---
NEED_BUILD=1
# v6.20.0: a graph built by an OLDER builder carries that builder's source_glob,
# so a newly-added source (the code layer) would never be globbed and the graph
# would stay layer-blind forever. Read the builder's own version — single source
# of truth, no duplicated constant — and force one rebuild when it moved.
BUILDER_VER="$(grep -m1 -oE 'build-graph@[0-9]+\.[0-9]+\.[0-9]+' "${PLUGIN_ROOT}/scripts/build-graph.sh" 2>/dev/null || true)"
if [ -f "$G" ]; then
  ROOT="$ROOT" G="$G" BUILDER_VER="$BUILDER_VER" python3 <<'PYEOF'
import json,os,glob,hashlib,sys
root=os.environ["ROOT"]; g=json.load(open(os.environ["G"]))
meta=g.get("_meta",{}); old=meta.get("source_hashes",{})
_bv=os.environ.get("BUILDER_VER","")
if _bv and meta.get("generated_by") != _bv:
    sys.exit(7)          # builder moved -> rebuild once (new sources may exist)
def sh(p):
    h=hashlib.sha256()
    with open(p,"rb") as f:
        for c in iter(lambda:f.read(65536),b""): h.update(c)
    return h.hexdigest()
cur={}
for pat in meta.get("source_glob",[]):
    for p in glob.glob(os.path.join(root,pat), recursive=True):
        cur[os.path.relpath(p,root)]=sh(p)
sys.exit(0 if (set(cur)==set(old) and all(old.get(k)==v for k,v in cur.items())) else 7)
PYEOF
  [ $? -eq 0 ] && NEED_BUILD=0
fi
[ "$NEED_BUILD" -eq 1 ] && bash "${PLUGIN_ROOT}/scripts/build-graph.sh" --root "$ROOT" >/dev/null

ROOT="$ROOT" G="$G" TARGET="$TARGET" DIR="$DIR" python3 <<'PYEOF'
import json,os,re
from collections import defaultdict, deque
g=json.load(open(os.environ["G"]))
target=os.environ["TARGET"]; direction=os.environ["DIR"]
nodes={n["id"]:n for n in g["nodes"]}

# staleness banner
stale=[v for v,s in g["_meta"].get("binding_stamps",{}).items() if s.get("stale_vs_head")]
if stale:
    print(f"Warning: Blast-radius from binding(s) {', '.join(stale)} stamped before current HEAD "
          f"({g['_meta'].get('head')}). Anchors may be stale -- run /mega-sdd:sync.\n")

# resolve target: exact node id, else file-normalized code_anchor
def norm_anchor(s): return re.sub(r':\d+(-\d+)?$','',s.strip())
start=None
if target in nodes: start=target
else:
    na=norm_anchor(target)
    if na in nodes: start=na
if not start:
    print(f"No node matches '{target}'. Known anchors: "
          + ", ".join(n['id'] for n in g['nodes'] if n['type']=='code_anchor')[:400])
    raise SystemExit(0)

# Traversal is per-relation directional.
#   DOWNSTREAM ("what is impacted by X"):
#     - DEPENDENCY relations {implements, honors, depends_on} are followed in
#       REVERSE (target->source) -> finds "what depends on me".
#     - STRUCTURAL relations {in_module, covers, kb_source, blocks, domain_dep}
#       are followed FORWARD (source->target) -> ENRICHES each reached node with
#       the module / flow / kb_domain / blocked-module it attaches to.
#     BFS runs over the UNION so e.g. a reached unit follows in_module forward to
#     its module, a reached claim follows covers forward to its flow, and that
#     flow follows kb_source forward to its kb_domain.
#   UPSTREAM ("what X depends on / traces to"): all-forward, unchanged.
DEP_RELS = {"implements", "honors", "depends_on"}
STRUCT_RELS = {"in_module", "covers", "kb_source", "blocks", "domain_dep"}

fwd=defaultdict(list); dep_rev=defaultdict(list); struct_fwd=defaultdict(list)
for e in g["edges"]:
    fwd[e["source"]].append(e)
    if e["relation"] in DEP_RELS:
        dep_rev[e["target"]].append(e)
    if e["relation"] in STRUCT_RELS:
        struct_fwd[e["source"]].append(e)

def neighbors(cur):
    """Return [(edge, next_node)] for the current node, honoring direction.
    Chain strings always print authored direction (source -[rel]-> target)."""
    if direction == "downstream":
        return ([(e, e["source"]) for e in dep_rev[cur]]
                + [(e, e["target"]) for e in struct_fwd[cur]])
    return [(e, e["target"]) for e in fwd[cur]]

seen={start}; q=deque([start]); hits=defaultdict(list)
while q:
    cur=q.popleft()
    for e, nxt in neighbors(cur):
        chain=f"{e['source']} -[{e['relation']}]-> {e['target']}  ({e['evidence']['artifact']}:{e['evidence']['field']})"
        t=nodes.get(nxt,{}).get("type","?")
        hits[t].append(chain)
        if nxt not in seen:
            seen.add(nxt); q.append(nxt)

print(f"Impact ({direction}) of {start}:\n")
if not any(hits.values()):
    print("  (no dependents found)")
for t in ("claim","unit","module","flow","kb_domain","oq","code_anchor"):
    if hits.get(t):
        print(f"## {t} ({len(hits[t])})")
        for c in hits[t]: print("  -", c)
        print()
PYEOF
