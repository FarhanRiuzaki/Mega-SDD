#!/usr/bin/env bash
# Impact/blast-radius query over .mega-sdd/graph.json. Lazy-rebuild when stale.
set -u
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
if [ -f "$G" ]; then
  ROOT="$ROOT" G="$G" python3 <<'PYEOF'
import json,os,glob,hashlib,sys
root=os.environ["ROOT"]; g=json.load(open(os.environ["G"]))
meta=g.get("_meta",{}); old=meta.get("source_hashes",{})
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

# adjacency (downstream = follow reverse of authored edges: who depends on me)
fwd=defaultdict(list); rev=defaultdict(list)
for e in g["edges"]:
    fwd[e["source"]].append(e); rev[e["target"]].append(e)
adj = rev if direction=="downstream" else fwd
key = (lambda e: e["source"]) if direction=="downstream" else (lambda e: e["target"])

seen={start}; q=deque([start]); hits=defaultdict(list)
while q:
    cur=q.popleft()
    for e in adj[cur]:
        nxt=key(e)
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
