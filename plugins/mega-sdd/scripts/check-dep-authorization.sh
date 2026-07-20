#!/usr/bin/env bash
# check-dep-authorization.sh — execute-bolts code gate 6 (anti-over-engineering).
#
# The WAJIB "pas, like an expert dev, no over-engineering" bar, as a mechanism:
# gate 5 (validate-new-deps.sh) already blocks HALLUCINATED packages; this gate
# asks the different question an expert reviewer asks — "did the UNIT actually
# sanction this dependency, or did the bolt pull in a whole library the spec
# never asked for?" A bolt that adds an unlisted dependency is scope creep.
#
# ADVISORY-FIRST (research §7): this always exits 0 and emits findings for the
# review panel + bolt-report — it never halts. The blocking escalation (after
# field soak) is deliberately deferred, and when it lands it is commit-keyed
# like B4 so legacy bolts never retro-block.
#
# Legacy-safe by construction: a unit with NO `allowed_new_deps:` key is a v4/
# pre-v5 unit → the gate DEGRADES to a no-op (enforced=false), never a finding.
# An explicit empty list (`allowed_new_deps: []`) means "no new deps sanctioned"
# → any added package is flagged. A populated list is the allowlist.
#
# Usage: check-dep-authorization.sh --unit <unit.md> --base <sha> --head <sha> [--cwd <dir>]
# Exit: always 0 (advisory). JSON on stdout.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
UNIT=""; BASE=""; HEAD=""; CWD="."
while [ $# -gt 0 ]; do case "$1" in
  --unit) UNIT="${2:-}"; shift 2;;   --unit=*) UNIT="${1#*=}"; shift;;
  --base) BASE="${2:-}"; shift 2;;   --base=*) BASE="${1#*=}"; shift;;
  --head) HEAD="${2:-}"; shift 2;;   --head=*) HEAD="${1#*=}"; shift;;
  --cwd)  CWD="${2:-}";  shift 2;;   --cwd=*)  CWD="${1#*=}";  shift;;
  *) shift;;
esac; done
[ -n "$UNIT" ] && [ -n "$BASE" ] && [ -n "$HEAD" ] || {
  echo "usage: check-dep-authorization.sh --unit <unit.md> --base <sha> --head <sha> [--cwd <dir>]" >&2; exit 0; }

export CDA_UNIT="$UNIT" CDA_BASE="$BASE" CDA_HEAD="$HEAD" CDA_CWD="$CWD" CDA_LIB="$SCRIPT_DIR/_lib"
python3 <<'PYEOF'
import json, os, re, sys
sys.path.insert(0, os.environ["CDA_LIB"])
from dep_manifest import added_deps

unit = os.environ["CDA_UNIT"]
base, head, cwd = os.environ["CDA_BASE"], os.environ["CDA_HEAD"], os.environ["CDA_CWD"]

def parse_allowed(path):
    """Return (present: bool, allowed: set[str]). Absent key => (False, set()).

    Parses the `allowed_new_deps:` frontmatter entry without a YAML dependency —
    handles inline `[a, b]` / `[]` and block `- item` lists."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return (False, set())
    # frontmatter only (first --- ... --- block); avoid matching body prose.
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    fm = m.group(1) if m else text
    lines = fm.splitlines()
    for i, line in enumerate(lines):
        km = re.match(r"^allowed_new_deps:\s*(.*)$", line)
        if not km:
            continue
        rest = km.group(1).strip()
        if rest.startswith("["):                       # inline list (incl. [])
            inner = rest[1:rest.rfind("]")] if "]" in rest else rest[1:]
            items = [x.strip().strip('"').strip("'") for x in inner.split(",")]
            return (True, {x for x in items if x})
        if rest and not rest.startswith("#"):           # scalar on the same line
            return (True, {rest.strip('"').strip("'")})
        allowed = set()                                 # block list on next lines
        for nxt in lines[i + 1:]:
            bm = re.match(r"^\s+-\s*(.+?)\s*$", nxt)
            if bm:
                allowed.add(bm.group(1).strip().strip('"').strip("'"))
            elif nxt.strip() == "" or nxt.startswith(" "):
                continue
            else:
                break
        return (True, allowed)
    return (False, set())

present, allowed = parse_allowed(unit)
added = added_deps(base, head, cwd)

if not present:
    print(json.dumps({
        "unit": os.path.basename(unit),
        "enforced": False,
        "added_deps": added,
        "unauthorized": [],
        "note": "allowed_new_deps absent (v4/pre-v5 unit) — dep-authorization not enforced",
    }, indent=2))
    sys.exit(0)

unauthorized = [e for e in added if e["package"] not in allowed]
warning = None
if unauthorized:
    pkgs = ", ".join(sorted(e["package"] for e in unauthorized))
    # keterangan (Indonesian human-facing, per the interaction contract)
    warning = (f"dependency baru tidak diotorisasi unit: {pkgs} — bolt menambah "
               f"library yang tidak ada di `allowed_new_deps` unit ini (dugaan "
               f"over-engineering / scope creep). Tinjau: benar-benar perlu, atau "
               f"pakai yang sudah ada? Jika memang perlu, tambahkan ke "
               f"`allowed_new_deps` unit. (advisory — tidak memblok)")

print(json.dumps({
    "unit": os.path.basename(unit),
    "enforced": True,
    "allowed_new_deps": sorted(allowed),
    "added_deps": added,
    "unauthorized": unauthorized,
    "finding": "dep_unauthorized" if unauthorized else None,
    "warning": warning,
}, indent=2))
sys.exit(0)  # advisory-first — never blocks
PYEOF
