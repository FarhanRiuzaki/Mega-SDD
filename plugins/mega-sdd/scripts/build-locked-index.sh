#!/usr/bin/env bash
# build-locked-index.sh — map [LOCKED]-anchored source files for GateGuard
# (spec 2026-06-12-instincts-and-gateguard-design.md §B).
#
# Parses every vault's binding.md + bound/ docs + vault docs + constitution for
# lines carrying a [LOCKED] marker, extracts file anchors on the marker line
# (or up to 3 lines below — entity blocks list their source beneath), keeps only
# paths that exist in the project, and writes
# .mega-sdd/.locked-files-index.json  { files: { <rel-path>: [<source>:<line>] } }.
#
# No [LOCKED] markers anywhere (typical greenfield) → empty index → the
# GateGuard gate is inert. Exit 0 always (index build must never block work).
#
# Usage: build-locked-index.sh --cwd=<project-root>

set -uo pipefail
CWD=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
  esac
done
[ -n "$CWD" ] && [ -d "$CWD/.mega-sdd" ] || exit 0

CWD="$CWD" python3 <<'PYEOF' 2>/dev/null || true
import glob, json, os, re
from datetime import datetime, timezone

cwd = os.environ["CWD"]
PATH_RX = re.compile(
    r"([A-Za-z0-9_\-./]+\.(?:blade\.php|html\.erb|php|jsx|tsx|js|ts|py|go|rs|rb|java|kt|vue|svelte|sql|scss|css|twig|html))(?::\d+(?:-\d+)?)?"
)

sources = []
for pat in ("vaults/*/binding.md", "vaults/*/bound/*.md", "vaults/*/0[0-6]-*.md", "vaults/*/constitution.md"):
    sources += glob.glob(os.path.join(cwd, ".mega-sdd", pat))

files = {}
for src in sorted(sources):
    try:
        lines = open(src, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    rel_src = os.path.relpath(src, cwd)
    for i, line in enumerate(lines):
        if "[LOCKED]" not in line:
            continue
        # anchors on the marker line, else the first path within the next 3 lines
        window = [line] + lines[i + 1 : i + 4]
        hit = False
        for w in window:
            for m in PATH_RX.finditer(w):
                p = m.group(1)
                if os.path.isfile(os.path.join(cwd, p)):
                    files.setdefault(p, [])
                    ref = "%s:%d" % (rel_src, i + 1)
                    if ref not in files[p]:
                        files[p].append(ref)
                    hit = True
            if hit:
                break  # nearest anchor only — don't sweep unrelated paths below

out = {
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "sources_scanned": len(sources),
    "files": files,
}
idx = os.path.join(cwd, ".mega-sdd", ".locked-files-index.json")
tmp = idx + ".tmp"
with open(tmp, "w") as f:
    json.dump(out, f, indent=1)
os.replace(tmp, idx)
PYEOF
exit 0
