#!/usr/bin/env bash
# analyze-parallelism.sh — deterministic DAG analysis of a mega-sdd vault's units.
#
# This is the DETERMINISTIC core extracted from skills/orchestrate-flow/references/diagnostics-procedures.md section analyze-parallelism
# (audit batch E / finding F4). The command self-labels its DAG math
# "DETERMINISTIC" (anti-halu rail) — depth / width / topological-wave layering /
# critical path / speedup / forks / joins / per-squad + per-module sub-DAGs /
# cross-edge counts / over-coupling CANDIDATES. All of that lives here.
#
# What STAYS in the command (human judgment — NOT here):
#   - The `→ Suggestion:` recommendations (Step 4 over-coupling advice + Step 7
#     hand-off routing). The script emits FACTS; the command interprets them.
#   - The over-coupling "no symbol cross-reference" sub-signal is NOT computed
#     (scanning unit bodies for symbol mentions is heuristic, not deterministic).
#     We surface only the deterministic basis: depends_on pairs with ZERO
#     target_files overlap, and cross-module depends_on edges.
#
# Read-only diagnostic: NO state-file writes, NO mkdir, NO mutation. `set -u`
# (pure read-only compute), never `set -euo`.
#
# Groupings (squad / module) are derived from each unit's OWN frontmatter
# `squad:` / `module:` field — `_meta/squads.yaml` / `_meta/modules.yaml` are
# NOT required (a vault may group via frontmatter alone). Units with no `module:`
# fall into "M-default"; no `squad:` → "default".
#
# Usage:
#   analyze-parallelism.sh [vault-path] [--cwd=<path>]
#                          [--per=squad|module|all] [--format=table|json|mermaid]
#                          [--module=<id>] [--squad=<id>] [--depth-only]
#   [vault-path]     Positional vault dir (a <slug>/ under .mega-sdd/vaults/).
#                    When omitted, the first vault with a units/ dir is auto-probed
#                    (canonical .mega-sdd/vaults/ then legacy docs/mega-sdd/vaults/).
#   --cwd=<path>     Project root to probe from (default: current directory).
#   --per=all        Grouping level for the report (default all).
#   --format=table   Output format (default table). json = machine-parseable;
#                    mermaid = graphviz for visual paste.
#   --module=<id>    Restrict analysis to one module.
#   --squad=<id>     Restrict analysis to one squad.
#   --depth-only     Emit depth + width metrics only (skip waves/forks/candidates).
#
# Exit: 0 = ok (metrics emitted)
#       1 = error / halt-equivalent (vault not found; vault.json corrupt;
#           DAG has a cycle — generate-units should have caught it, fail safe here)
#       2 = usage error (unknown flag / bad value / --cwd not a directory)
set -u

VAULT_ARG=""
CWD="."
PER="all"
FORMAT="table"
ONLY_MODULE=""
ONLY_SQUAD=""
DEPTH_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*)        CWD="${arg#*=}" ;;
    --per=*)        PER="${arg#*=}" ;;
    --format=*)     FORMAT="${arg#*=}" ;;
    --module=*)     ONLY_MODULE="${arg#*=}" ;;
    --squad=*)      ONLY_SQUAD="${arg#*=}" ;;
    --depth-only)   DEPTH_ONLY=1 ;;
    -h|--help)      sed -n '2,40p' "$0"; exit 0 ;;
    --*)            echo "analyze-parallelism: unknown argument: $arg" >&2; exit 2 ;;
    *)              # positional vault-path (first one wins)
                    if [ -z "$VAULT_ARG" ]; then VAULT_ARG="$arg";
                    else echo "analyze-parallelism: unexpected extra argument: $arg" >&2; exit 2; fi ;;
  esac
done

case "$PER" in squad|module|all) : ;; *) echo "analyze-parallelism: --per must be squad|module|all (got: $PER)" >&2; exit 2 ;; esac
case "$FORMAT" in table|json|mermaid) : ;; *) echo "analyze-parallelism: --format must be table|json|mermaid (got: $FORMAT)" >&2; exit 2 ;; esac

[ -d "$CWD" ] || { echo "analyze-parallelism: --cwd is not a directory: $CWD" >&2; exit 2; }

# All graph compute + rendering is deterministic python3 (no PyYAML — hand-parse
# frontmatter with regex, mirroring compute-unit-staleness.sh / validate-*.sh).
CWD="$CWD" VAULT_ARG="$VAULT_ARG" PER="$PER" FORMAT="$FORMAT" \
ONLY_MODULE="$ONLY_MODULE" ONLY_SQUAD="$ONLY_SQUAD" DEPTH_ONLY="$DEPTH_ONLY" \
python3 <<'PYEOF'
import glob
import json
import os
import re
import sys

cwd         = os.environ["CWD"]
vault_arg   = os.environ["VAULT_ARG"]
per         = os.environ["PER"]
fmt         = os.environ["FORMAT"]
only_module = os.environ["ONLY_MODULE"]
only_squad  = os.environ["ONLY_SQUAD"]
depth_only  = os.environ["DEPTH_ONLY"] == "1"


def die(msg, code):
    print("analyze-parallelism: " + msg, file=sys.stderr)
    sys.exit(code)


# --- Resolve vault dir --------------------------------------------------------
def has_units(d):
    return bool(glob.glob(os.path.join(d, "units", "U-*.md")) or
                glob.glob(os.path.join(d, "units", "U-*", "unit.md")))


if vault_arg:
    cand = vault_arg if os.path.isabs(vault_arg) else os.path.join(cwd, vault_arg)
    if not os.path.isdir(cand):
        die("vault not found: %s" % vault_arg, 1)
    vault_dir = cand
else:
    # Probe canonical then legacy vault containers; pick the first vault with units.
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

# vault.json is OPTIONAL (legacy units may predate it) but if present + corrupt → halt.
vault_name = os.path.basename(vault_dir.rstrip("/"))
vj_path = os.path.join(vault_dir, "vault.json")
if os.path.isfile(vj_path):
    try:
        with open(vj_path) as f:
            vj = json.load(f)
        vault_name = vj.get("name") or vj.get("slug") or vault_name
    except Exception as e:
        die("vault.json corrupt (%s): %s" % (vj_path, e), 1)

unit_files = sorted(glob.glob(os.path.join(vault_dir, "units", "U-*.md")) +
                    glob.glob(os.path.join(vault_dir, "units", "U-*", "unit.md")))
if not unit_files:
    die("vault has no units: %s" % vault_dir, 1)


# --- Frontmatter parsing (no PyYAML) ------------------------------------------
FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---", re.DOTALL)


def frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    return m.group(1) if m else ""


def scalar(fm, key):
    """Top-level `key: value` scalar (value may be quoted). Returns '' if absent."""
    m = re.search(r"(?m)^%s:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return ""
    v = m.group(1).strip()
    if v.startswith("#") or v == "":
        return ""
    v = v.split("  #", 1)[0].strip()  # strip trailing inline comment
    return v.strip("'\"")


def list_field(fm, key):
    """Parse a frontmatter list in BOTH forms:
       inline   `key: [U-001, U-002]`  (also `key: []`)
       block    `key:\n  - U-001\n  - U-002`
    Mirrors the kb output surface's dual-format handling (validate-kb.sh)."""
    m = re.search(r"(?m)^%s:[ \t]*(.*)$" % re.escape(key), fm)
    if not m:
        return []
    inline = m.group(1).strip()
    if inline.startswith("["):
        inner = inline[1:inline.rfind("]")] if "]" in inline else inline[1:]
        return [x.strip().strip("'\"") for x in inner.split(",") if x.strip()]
    if inline and not inline.startswith("#"):
        # single inline scalar treated as 1-element list
        return [inline.strip("'\"")]
    # block list: consume following `  - item` lines
    items = []
    after = fm[m.end():]
    for line in after.split("\n"):
        bm = re.match(r"^[ \t]+-[ \t]+(.+?)[ \t]*$", line)
        if bm:
            val = bm.group(1).strip()
            if val.startswith("#"):
                continue
            items.append(val.strip("'\""))
        elif line.strip() == "":
            continue
        else:
            break  # dedent / next key ends the block
    return items


def target_paths(fm):
    """Collect target_files[].path entries (block list-of-maps). Heuristic-free:
    just the literal `path:` values inside the target_files: block."""
    m = re.search(r"(?m)^target_files:[ \t]*$", fm)
    if not m:
        # inline empty form `target_files: []` → no paths
        return set()
    paths = set()
    after = fm[m.end():]
    for line in after.split("\n"):
        if re.match(r"^[ \t]", line) or line.strip() == "":
            pm = re.search(r"(?m)path:[ \t]*(.+?)[ \t]*$", line)
            if pm:
                paths.add(pm.group(1).strip().strip("'\""))
            elif line.strip() == "":
                continue
            else:
                # an indented non-path line (e.g. `operation:`) — stay in block
                continue
        else:
            break  # dedent ends the block
    return paths


# --- Load units ---------------------------------------------------------------
units = {}        # uid -> {module, squad, deps, targets, file}
order = []        # uid in file order (stable wave tie-break)
for uf in unit_files:
    try:
        with open(uf, encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        continue
    fm = frontmatter(text)
    uid = scalar(fm, "id")
    if not uid:
        # Fallback: derive U-id from filename (e.g. "U-001 Widget.md" / "U-001.md").
        base = os.path.basename(uf)
        fm_id = re.match(r"(U-[0-9A-Za-z]+)", base)
        uid = fm_id.group(1) if fm_id else os.path.splitext(base)[0]
    module = scalar(fm, "module") or "M-default"
    squad = scalar(fm, "squad") or "default"
    deps = list_field(fm, "depends_on")
    targets = target_paths(fm)
    units[uid] = {"module": module, "squad": squad, "deps": deps,
                  "targets": targets, "file": os.path.relpath(uf, cwd)}
    order.append(uid)

# Drop dependency edges that point at unknown units (dangling deps don't crash math).
known = set(units)
for u in units.values():
    u["deps"] = [d for d in u["deps"] if d in known]


# --- Optional grouping filter (--module / --squad) ----------------------------
def in_scope(uid):
    if only_module and units[uid]["module"] != only_module:
        return False
    if only_squad and units[uid]["squad"] != only_squad:
        return False
    return True


# --- Core DAG math ------------------------------------------------------------
def dag_metrics(node_ids):
    """Compute layering + metrics for the sub-DAG induced by node_ids.
    Edge u->v means v depends_on u (u must finish first)."""
    nodes = set(node_ids)
    # in-set deps only (sub-DAG)
    deps = {n: [d for d in units[n]["deps"] if d in nodes] for n in nodes}
    # out-degree (forks) / in-degree (joins)
    out_deg = {n: 0 for n in nodes}
    in_deg = {n: len(deps[n]) for n in nodes}
    for n in nodes:
        for d in deps[n]:
            out_deg[d] += 1
    # Kahn topological layering → waves; detect cycle if not all nodes assigned.
    level = {}
    remaining = dict(deps)
    ready = sorted([n for n in nodes if not remaining[n]],
                   key=lambda x: order.index(x) if x in order else x)
    cur = 0
    placed = set()
    while ready:
        for n in ready:
            level[n] = cur
            placed.add(n)
        nxt = []
        for n in sorted(nodes, key=lambda x: order.index(x) if x in order else x):
            if n in placed:
                continue
            if all(d in placed for d in remaining[n]):
                nxt.append(n)
        ready = nxt
        cur += 1
    if len(placed) != len(nodes):
        cyc = sorted(nodes - placed)
        return {"cycle": cyc}
    # waves[i] = node ids at level i
    n_waves = (max(level.values()) + 1) if level else 0
    waves = [[] for _ in range(n_waves)]
    for n in sorted(nodes, key=lambda x: order.index(x) if x in order else x):
        waves[level[n]].append(n)
    depth = n_waves  # longest chain length (in nodes) == number of waves
    max_width = max((len(w) for w in waves), default=0)
    # Critical path: longest chain by node count (one representative path).
    longest = {}
    def chain_len(n):
        if n in longest:
            return longest[n]
        if not deps[n]:
            longest[n] = (1, [n])
        else:
            best = max((chain_len(d) for d in deps[n]), key=lambda t: t[0])
            longest[n] = (best[0] + 1, best[1] + [n])
        return longest[n]
    crit_len, crit_path = 0, []
    for n in nodes:
        cl, cp = chain_len(n)
        if cl > crit_len:
            crit_len, crit_path = cl, cp
    forks = sorted([n for n in nodes if out_deg[n] >= 2],
                   key=lambda x: (-out_deg[x], x))
    joins = sorted([n for n in nodes if in_deg[n] >= 2],
                   key=lambda x: (-in_deg[x], x))
    total = len(nodes)
    # Speedup = sequential (one-bolt-per-unit) / parallel-wall-clock (one-min-per-wave),
    # i.e. total_units / depth under unlimited-parallel 1-bolt/min. Matches the
    # command's worked example: 13 units / depth 4 → 3.25x.
    speedup = round(total / depth, 2) if depth else 0.0
    return {
        "cycle": None,
        "total_units": total,
        "depth": depth,
        "max_width": max_width,
        "total_waves": n_waves,
        "waves": waves,
        "out_degree": out_deg,
        "in_degree": in_deg,
        "forks": [{"unit": n, "dependents": out_deg[n]} for n in forks],
        "joins": [{"unit": n, "deps": in_deg[n]} for n in joins],
        "critical_path": crit_path,
        "critical_path_len": crit_len,
        "estimated_wallclock_min": depth,
        "sequential_min": total,
        "parallelism_speedup": speedup,
    }


def over_coupling_candidates(node_ids):
    """DETERMINISTIC basis only (no body-symbol heuristic):
       (a) depends_on pairs whose target_files sets are DISJOINT, and
       (b) cross-module depends_on edges.
    Surfaced as CANDIDATES for the command to turn into suggestions."""
    nodes = set(node_ids)
    out = []
    for n in sorted(nodes, key=lambda x: order.index(x) if x in order else x):
        for d in units[n]["deps"]:
            if d not in nodes:
                continue
            t_n, t_d = units[n]["targets"], units[d]["targets"]
            disjoint = bool(t_n) and bool(t_d) and not (t_n & t_d)
            cross_mod = units[n]["module"] != units[d]["module"]
            if disjoint or cross_mod:
                out.append({
                    "unit": n,
                    "depends_on": d,
                    "zero_target_overlap": disjoint,
                    "cross_module": cross_mod,
                    "unit_module": units[n]["module"],
                    "dep_module": units[d]["module"],
                })
    return out


def cross_edge_counts(node_ids):
    nodes = set(node_ids)
    xmod = xsquad = 0
    for n in nodes:
        for d in units[n]["deps"]:
            if d not in nodes:
                continue
            if units[n]["module"] != units[d]["module"]:
                xmod += 1
            if units[n]["squad"] != units[d]["squad"]:
                xsquad += 1
    return xmod, xsquad


# --- Whole-vault DAG (respecting any --module/--squad filter) ------------------
scoped = [u for u in order if in_scope(u)]
if not scoped:
    die("no units match the requested --module/--squad filter", 1)

overall = dag_metrics(scoped)
if overall.get("cycle"):
    die("DAG has a cycle (units: %s) — generate-units should have rejected this; "
        "refusing to emit metrics" % ", ".join(overall["cycle"]), 1)

xmod_all, xsquad_all = cross_edge_counts(scoped)


def group_block(group_field, label_filter):
    """Per-grouping (squad|module) sub-DAG metrics."""
    groups = {}
    for u in scoped:
        key = units[u][group_field]
        groups.setdefault(key, []).append(u)
    out = {}
    for key in sorted(groups):
        m = dag_metrics(groups[key])
        if m.get("cycle"):
            continue  # cross-group edges can't cycle a within-group sub-DAG; defensive
        xmod, xsquad = cross_edge_counts(groups[key])
        out[key] = {
            "units": m["total_units"],
            "depth": m["depth"],
            "max_width": m["max_width"],
            "total_waves": m["total_waves"],
            "waves": m["waves"],
            "forks": m["forks"],
            "cross_module_edges": xmod,
            "cross_squad_edges": xsquad,
            "estimated_wallclock_min": m["estimated_wallclock_min"],
            "parallelism_speedup": m["parallelism_speedup"],
        }
    return out


squads = group_block("squad", only_squad) if (per in ("squad",) or per == "all") else {}
modules = group_block("module", only_module) if (per in ("module",) or per == "all") else {}

over_coupling = [] if depth_only else over_coupling_candidates(scoped)

result = {
    "vault": vault_name,
    "vault_dir": os.path.relpath(vault_dir, cwd),
    "total_units": overall["total_units"],
    "modules": len({units[u]["module"] for u in scoped}),
    "squads": len({units[u]["squad"] for u in scoped}),
    "depth": overall["depth"],
    "max_width": overall["max_width"],
    "total_waves": overall["total_waves"],
    "waves": overall["waves"],
    "forks": overall["forks"],
    "joins": overall["joins"],
    "critical_path": overall["critical_path"],
    "critical_path_len": overall["critical_path_len"],
    "cross_module_edges": xmod_all,
    "cross_squad_edges": xsquad_all,
    "estimated_wallclock_min": overall["estimated_wallclock_min"],
    "sequential_min": overall["sequential_min"],
    "parallelism_speedup": overall["parallelism_speedup"],
    "per_squad": squads,
    "per_module": modules,
    "suspected_over_coupling": over_coupling,
    "bottlenecks": [
        {"unit": n, "dependents": d["dependents"],
         "on_critical_path": n in set(overall["critical_path"])}
        for d in overall["forks"] for n in [d["unit"]]
    ] if not depth_only else [],
}


# --- Rendering ----------------------------------------------------------------
def render_json():
    print(json.dumps(result, indent=2))


def render_mermaid():
    print("```mermaid")
    print("graph LR")
    by_squad = {}
    for u in scoped:
        by_squad.setdefault(units[u]["squad"], []).append(u)
    for sq in sorted(by_squad):
        print("  subgraph %s" % sq)
        for u in by_squad[sq]:
            nid = u.replace("-", "")
            print("    %s[%s]" % (nid, u))
        print("  end")
    for u in scoped:
        for d in units[u]["deps"]:
            if d in set(scoped):
                print("  %s --> %s" % (d.replace("-", ""), u.replace("-", "")))
    print("```")


def render_table():
    print("Vault: %s" % result["vault"])
    print("Total units: %d | Modules: %d | Squads: %d"
          % (result["total_units"], result["modules"], result["squads"]))
    print("")
    print("Overall DAG:")
    print("  Depth: %d (longest chain)" % result["depth"])
    print("  Max parallel width: %d" % result["max_width"])
    print("  Total waves: %d" % result["total_waves"])
    if depth_only:
        return
    print("")
    print("Topological waves:")
    for i, w in enumerate(result["waves"], 1):
        tag = "%d parallel" % len(w) if len(w) > 1 else "1 sequential"
        print("  Wave %d: %s  (%s)" % (i, " ".join(w), tag))
    print("")
    print("Critical chain (longest path): %s (%d hops)"
          % (" -> ".join(result["critical_path"]), max(result["critical_path_len"] - 1, 0)))
    if result["forks"]:
        print("Forks (high out-degree): "
              + ", ".join("%s (%d dependents)" % (f["unit"], f["dependents"]) for f in result["forks"]))
    if result["joins"]:
        print("Joins (high in-degree): "
              + ", ".join("%s (%d deps)" % (j["unit"], j["deps"]) for j in result["joins"]))
    print("Cross-module edges: %d | Cross-squad edges: %d"
          % (result["cross_module_edges"], result["cross_squad_edges"]))
    print("")
    print("Estimated wall-clock (1 bolt/min, unlimited parallel): ~%d min"
          % result["estimated_wallclock_min"])
    print("Sequential equivalent: ~%d min" % result["sequential_min"])
    print("Parallelism speedup: %sx" % result["parallelism_speedup"])
    if per in ("squad", "all") and result["per_squad"]:
        print("")
        print("Per-squad:")
        for sq, m in result["per_squad"].items():
            print("  %s: units=%d depth=%d max_width=%d speedup=%sx (cross-squad edges: %d)"
                  % (sq, m["units"], m["depth"], m["max_width"], m["parallelism_speedup"], m["cross_squad_edges"]))
    if per in ("module", "all") and result["per_module"]:
        print("")
        print("Per-module:")
        for mod, m in result["per_module"].items():
            print("  %s: units=%d depth=%d max_width=%d (cross-module edges: %d)"
                  % (mod, m["units"], m["depth"], m["max_width"], m["cross_module_edges"]))
    if result["suspected_over_coupling"]:
        print("")
        print("Suspected over-coupling CANDIDATES (deterministic basis; review — never auto-removed):")
        for c in result["suspected_over_coupling"]:
            reasons = []
            if c["zero_target_overlap"]:
                reasons.append("zero target_files overlap")
            if c["cross_module"]:
                reasons.append("cross-module (%s -> %s)" % (c["dep_module"], c["unit_module"]))
            print("  %s depends_on %s — %s" % (c["unit"], c["depends_on"], "; ".join(reasons)))


if fmt == "json":
    render_json()
elif fmt == "mermaid":
    render_mermaid()
else:
    render_table()

sys.exit(0)
PYEOF
