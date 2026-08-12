#!/usr/bin/env bash
# derive-transitive-impact.sh — the graph layer's first CHAIN consumer
# (spec 2026-08-12-graph-assisted-reconcile.md D1).
#
# Given changed unit ids, answers: which OTHER units depend on them,
# transitively? (reverse-`depends_on` closure over unit nodes — the reconcile
# pass step 2 is hash-deterministic and therefore blind to a dependency that
# changed while the unit's own files did not; this fills exactly that gap.)
#
# ADVISORY BY CONTRACT: output feeds the "verify-recommended (transitive
# impact)" list in SYNC-REPORT / the delta handoff. It never assigns `status:`,
# never gates. FAIL-OPEN: a missing/unbuildable graph yields
# {"graph_available": false, "transitive": []} exit 0 — the graph is a lens,
# never a gate (the /graph skill doctrine).
#
# Freshness: the same hash-checked lazy rebuild query-graph.sh uses.
# Usage: derive-transitive-impact.sh --vault=<dir> --project=<root> --units=<csv>
# Exit: 0 always (data) · 2 usage.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"

VAULT=""; PROJECT=""; UNITS=""
for arg in "$@"; do
  case "$arg" in
    --vault=*)   VAULT="${arg#*=}" ;;
    --project=*) PROJECT="${arg#*=}" ;;
    --units=*)   UNITS="${arg#*=}" ;;
    *) echo "usage: derive-transitive-impact.sh --vault=<dir> --project=<root> --units=<csv>" >&2; exit 2 ;;
  esac
done
[ -n "$UNITS" ] || { echo "usage: --units=<csv of unit ids> required" >&2; exit 2; }
[ -n "$PROJECT" ] || PROJECT="$(pwd)"

fail_open() {
  printf '{"graph_available": false, "input": [%s], "transitive": [], "reason": "%s"}\n' \
    "$(echo "$UNITS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | paste -sd, -)" "$1"
  exit 0
}

G="$PROJECT/.mega-sdd/graph.json"

# ── freshness: lazy rebuild, identical policy to query-graph.sh ──
NEED_BUILD=1
if [ -f "$G" ]; then
  ROOT="$PROJECT" G="$G" python3 <<'PYEOF'
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
if [ "$NEED_BUILD" -eq 1 ]; then
  bash "${PLUGIN_ROOT}/scripts/build-graph.sh" --root "$PROJECT" >/dev/null 2>&1 \
    || fail_open "graph rebuild failed (build-graph.sh nonzero) — proceeding without transitive expansion"
fi
[ -f "$G" ] || fail_open "graph.json absent after rebuild — proceeding without transitive expansion"

G="$G" UNITS="$UNITS" VAULT_BASE="$(basename "${VAULT:-}")" python3 <<'PYEOF' || fail_open "graph.json unreadable"
import json, os
from collections import defaultdict, deque

g = json.load(open(os.environ["G"]))
inputs = [u.strip() for u in os.environ["UNITS"].split(",") if u.strip()]

# graph unit ids are VAULT-PREFIXED ("app:U-001"); the reconcile pass speaks
# bare local ids — accept both, traverse prefixed, emit bare. A bare id is
# scoped to --vault's basename FIRST (inline-round catch: two vaults both
# carrying U-001 cross-contaminated the closure without this); suffix match
# is the fallback only when the vault yields no hit.
unit_ids = {n["id"] for n in g.get("nodes", []) if n.get("type") == "unit"}
vault_base = os.environ.get("VAULT_BASE", "")
def resolve(u):
    if u in unit_ids:
        return [u]
    if vault_base and (vault_base + ":" + u) in unit_ids:
        return [vault_base + ":" + u]
    return [gid for gid in unit_ids if gid.endswith(":" + u)]
start = set()
for u in inputs:
    start.update(resolve(u))

# reverse depends_on: edge "app:U-002" -[depends_on]-> "app:U-001" means U-002
# depends on U-001, so a change in U-001 impacts U-002 — traverse target->source.
rev = defaultdict(list)
for e in g.get("edges", []):
    if e.get("relation") == "depends_on" and e.get("source") in unit_ids:
        rev[e["target"]].append(e["source"])

seen = set(start)
q = deque(start)
hit = set()
while q:
    cur = q.popleft()
    for dep in rev.get(cur, []):
        if dep not in seen:
            seen.add(dep)
            hit.add(dep)
            q.append(dep)

def bare(gid):
    return gid.rsplit(":", 1)[-1]
transitive = sorted({bare(gid) for gid in hit} - set(inputs))

print(json.dumps({
    "graph_available": True,
    "input": sorted(inputs),
    "transitive": transitive,
}, indent=0).replace("\n", " ").replace("  ", " "))
PYEOF
exit 0
