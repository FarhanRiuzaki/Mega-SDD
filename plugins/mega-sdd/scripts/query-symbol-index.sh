#!/usr/bin/env bash
# query-symbol-index.sh — pure-read filter over symbol-index.json (R1, spec
# 2026-08-02-reuse-first-grounding-index.md). Zero writes, zero net access.
#
# Usage:
#   query-symbol-index.sh [--cwd=<dir>] [--index=<path>]
#                         [--file=<prefix>] [--dir=<dir-prefix>] [--name=<substr>]
#                         [--kind=<substr>] [--limit=N]
# Filters AND together; matching is case-insensitive for --name.
# Output: file:line<TAB>kind<TAB>name<TAB>signature — one row per symbol,
# index order (file, line, kind). Exit: 0 ok (even zero rows) · 2 usage ·
# 3 index missing.

set -u
CWD="."; INDEX=""; FFILE=""; FDIR=""; FNAME=""; FKIND=""; LIMIT=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*)   CWD="${arg#--cwd=}" ;;
    --index=*) INDEX="${arg#--index=}" ;;
    --file=*)  FFILE="${arg#--file=}" ;;
    --dir=*)   FDIR="${arg#--dir=}" ;;
    --name=*)  FNAME="${arg#--name=}" ;;
    --kind=*)  FKIND="${arg#--kind=}" ;;
    --limit=*) LIMIT="${arg#--limit=}" ;;
    *) echo "usage: query-symbol-index.sh [--cwd=] [--index=] [--file=] [--dir=] [--name=] [--kind=] [--limit=N]" >&2; exit 2 ;;
  esac
done
case "$LIMIT" in *[!0-9]*) echo "query-symbol-index.sh: --limit must be an integer" >&2; exit 2 ;; esac
[ -n "$INDEX" ] || INDEX="$CWD/.mega-sdd/codebase/symbol-index.json"
[ -f "$INDEX" ] || { echo "query-symbol-index.sh: no index at $INDEX (run build-symbol-index.sh)" >&2; exit 3; }

INDEX="$INDEX" FFILE="$FFILE" FDIR="$FDIR" FNAME="$FNAME" FKIND="$FKIND" LIMIT="$LIMIT" python3 <<'PYEOF'
import json, os, re, sys

try:
    d = json.load(open(os.environ["INDEX"], encoding="utf-8"))
    if not isinstance(d, dict):
        raise ValueError("top-level is not an object")
except (OSError, ValueError) as e:
    print("query-symbol-index.sh: unreadable/corrupt index (%s) — rebuild via build-symbol-index.sh" % e,
          file=sys.stderr)
    sys.exit(3)

ffile = os.environ["FFILE"]; fdir = os.environ["FDIR"].rstrip("/")
if fdir == ".":
    fdir = ""  # repo root — dirname() of a root-level file is ""
fname = os.environ["FNAME"].lower(); fkind = os.environ["FKIND"]
limit = int(os.environ["LIMIT"] or 0)

def cell(v):
    # one TSV field: no tabs/newlines regardless of index content
    return re.sub(r"[\t\r\n]+", " ", "" if v is None else str(v))

n = 0
try:
    for s in d.get("symbols") or []:
        if not isinstance(s, dict):
            continue
        f = s.get("file") or ""
        if ffile and not f.startswith(ffile):
            continue
        if os.environ["FDIR"] and not (os.path.dirname(f) == fdir or
                                       os.path.dirname(f).startswith(fdir + "/") if fdir else os.path.dirname(f) == ""):
            continue
        if fname and fname not in (s.get("name") or "").lower():
            continue
        if fkind and fkind not in (s.get("kind") or ""):
            continue
        print("%s:%s\t%s\t%s\t%s" % (cell(f), cell(s.get("line")), cell(s.get("kind")),
                                     cell(s.get("name")), cell(s.get("signature"))))
        n += 1
        if limit and n >= limit:
            break
except BrokenPipeError:
    sys.stderr.close()
    sys.exit(0)
PYEOF
