#!/usr/bin/env bash
# derive-extract-census.sh — deterministic census of a legacy codebase for the
# extract-intelligence PRD-kontrak lane (spec
# 2026-08-26-extract-revamp-contract-design.md).
#
# The census IS the completeness contract: extraction is done when every file
# row here is claimed by exactly one module PRD and cited inside it
# (validate-extract-census.sh recomputes that from the artifacts — B1-recompute
# pattern). It also absorbs the two retired runtime files: `.scan-meta.json`
# (stack detection → `stacks`) and the extracted-kb freshness snapshot
# (`source_files_sha256_map` → per-file `sha256`).
#
# Enumeration = _lib/code_enum.py — the SAME source set as the symbol index
# (logs, data, backups, vendor trees excluded by construction; a `.php.bak`
# has extension `.bak` and never enters the census).
#
# Usage:
#   derive-extract-census.sh --legacy=<dir> --kb-dir=<dir> [--quiet]
#     --legacy   legacy source root to census (required)
#     --kb-dir   extraction output home; census written to <kb-dir>/census.json
# Exit: 0 written · 2 usage/IO.
#
# Determinism: identical legacy tree → byte-identical census.json except
# generated_at. Module rows are a PROPOSAL (top-level-dir grouping) — the
# skill confirms the split with the human (>1 module) before dispatch; the
# CONFIRMED mapping's ground truth is the module PRDs' own frontmatter,
# never this file.

set -u
LEGACY=""; KB_DIR=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --legacy=*) LEGACY="${arg#--legacy=}" ;;
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --quiet)    QUIET=1 ;;
    *) echo "usage: derive-extract-census.sh --legacy=<dir> --kb-dir=<dir> [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$LEGACY" ] && [ -d "$LEGACY" ] || { echo "derive-extract-census.sh: --legacy missing or not a directory: '$LEGACY'" >&2; exit 2; }
[ -n "$KB_DIR" ] || { echo "derive-extract-census.sh: --kb-dir required" >&2; exit 2; }
mkdir -p "$KB_DIR" 2>/dev/null || { echo "derive-extract-census.sh: cannot create --kb-dir: $KB_DIR" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

LEGACY="$LEGACY" KB_DIR="$KB_DIR" QUIET="$QUIET" python3 <<'PYEOF'
import hashlib, json, os, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import code_enum                   # noqa: E402

legacy = os.path.abspath(os.environ["LEGACY"])
kb_dir = os.environ["KB_DIR"]
quiet = os.environ["QUIET"] == "1"

files, git_ok = code_enum.enumerate_code_files(legacy)

rows, total_lines = [], 0
for rel in files:
    p = os.path.join(legacy, rel)
    try:
        with open(p, "rb") as fh:
            data = fh.read()
    except OSError:
        # enumerated but unreadable (permissions, broken symlink) — record
        # honestly as a zero-content row; the extraction agent will hit the
        # same wall and the gap surfaces as [OPEN], never silently dropped
        rows.append({"path": rel, "lang": code_enum.EXTS.get(os.path.splitext(rel)[1], "?"),
                     "lines": 0, "bytes": 0, "sha256": None, "unreadable": True})
        continue
    lines = data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)
    total_lines += lines
    rows.append({"path": rel,
                 "lang": code_enum.EXTS.get(os.path.splitext(rel)[1], "?"),
                 "lines": lines, "bytes": len(data),
                 "sha256": hashlib.sha256(data).hexdigest()})

stacks = sorted({r["lang"] for r in rows if r["lang"] != "?"})

# Entry-point hint (advisory input to the module proposal, nothing gates on
# it): common entrypoint basenames at any depth.
ENTRY_NAMES = {"index", "main", "app", "server", "cli", "run", "start"}
entry_points = sorted(r["path"] for r in rows
                      if os.path.splitext(os.path.basename(r["path"]))[0].lower() in ENTRY_NAMES)

# Module PROPOSAL: group by first path segment; root-level files form one
# module named after the legacy dir basename. Deterministic, judgment-free —
# the human confirms/reshapes the split when >1 module is proposed.
groups = {}
root_name = os.path.basename(legacy.rstrip(os.sep)) or "root"
for r in rows:
    seg = r["path"].split("/", 1)
    name = seg[0] if len(seg) > 1 else root_name
    groups.setdefault(name, []).append(r)
modules = [{"name": n,
            "files": [r["path"] for r in grp],
            "lines": sum(r["lines"] for r in grp)}
           for n, grp in sorted(groups.items())]

doc = {"census_version": 1,
       "generated_by": "mega-sdd:derive-extract-census",
       "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "legacy_root": legacy,
       "enumeration": "git" if git_ok else "walk",
       "file_count": len(rows), "total_lines": total_lines,
       "stacks": stacks, "entry_points": entry_points,
       "proposed_modules": modules,
       "files": rows}

out = os.path.join(kb_dir, "census.json")
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=1, ensure_ascii=False, sort_keys=False)
    fh.write("\n")
os.replace(tmp, out)
if not quiet:
    print("census: %d code files, %d lines, stacks=%s, %d proposed module(s) -> %s"
          % (len(rows), total_lines, ",".join(stacks) or "-", len(modules), out))
PYEOF
