#!/usr/bin/env bash
# validate-extract-census.sh — the extraction completeness gate for the
# PRD-kontrak lane (spec 2026-08-26-extract-revamp-contract-design.md).
#
# "Done" is contracted to the census, not to a wave count: extraction is
# complete when EVERY file row in census.json is (a) claimed by exactly one
# module PRD (frontmatter `source_files:`), (b) that PRD exists under
# <kb-dir>/modules/*.prd.md with sane frontmatter, (c) the file is cited
# (path:line) at least once in its PRD body, and (d) every PRD carries an
# `## Open Questions` section (explicit absence beats silent omission).
# Everything is recomputed from census.json + the PRD artifacts on every run
# (B1-recompute pattern) — there is no trusted intermediate state.
#
# Usage:
#   validate-extract-census.sh --kb-dir=<dir> [--quiet]
# Exit: 0 PASS or SKIP (no census.json — pre-PRD-kontrak KB, nothing to
#       gate) · 1 FAIL (findings listed; state file carries them) · 2 usage.
# State: <kb-dir>/.extract-census-state.json (re-derived every run).

set -u
KB_DIR=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --quiet)    QUIET=1 ;;
    *) echo "usage: validate-extract-census.sh --kb-dir=<dir> [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$KB_DIR" ] && [ -d "$KB_DIR" ] || { echo "validate-extract-census.sh: --kb-dir missing or not a directory: '$KB_DIR'" >&2; exit 2; }

KB_DIR="$KB_DIR" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

kb_dir = os.environ["KB_DIR"]
quiet = os.environ["QUIET"] == "1"
state_path = os.path.join(kb_dir, ".extract-census-state.json")

def write_state(status, findings):
    doc = {"status": status,
           "generated_by": "mega-sdd:validate-extract-census",
           "checked_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "findings": findings}
    tmp = state_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(doc, fh, indent=1, ensure_ascii=False)
        fh.write("\n")
    os.replace(tmp, state_path)

census_path = os.path.join(kb_dir, "census.json")
if not os.path.isfile(census_path):
    # pre-PRD-kontrak KB (numbered tree) — nothing to gate here; the legacy
    # validators own that grammar. SKIP is an answer, never a silent pass.
    write_state("SKIP", {"note": "no census.json — pre-PRD-kontrak knowledge base"})
    if not quiet:
        print("extract-census: SKIP (no census.json)")
    sys.exit(0)

try:
    with open(census_path, encoding="utf-8") as fh:
        census = json.load(fh)
    census_files = [r["path"] for r in census.get("files", [])]
except (ValueError, OSError, KeyError, TypeError) as e:
    write_state("FAIL", {"census_unreadable": str(e)})
    print("extract-census: FAIL — census.json unreadable: %s" % e, file=sys.stderr)
    sys.exit(1)

modules_dir = os.path.join(kb_dir, "modules")
prd_paths = []
if os.path.isdir(modules_dir):
    prd_paths = sorted(os.path.join(modules_dir, n)
                       for n in os.listdir(modules_dir) if n.endswith(".prd.md"))

findings = {"unclaimed": [], "double_claimed": [], "phantom_claims": [],
            "uncited": [], "bad_frontmatter": [], "missing_oq_section": []}

if not prd_paths:
    findings["no_module_prds"] = ("census present (%d files) but no modules/*.prd.md — extraction not started or wrote elsewhere"
                                  % len(census_files))
    write_state("FAIL", findings)
    print("extract-census: FAIL — %s" % findings["no_module_prds"], file=sys.stderr)
    sys.exit(1)

def parse_frontmatter(text):
    """Minimal hand parser (no yaml dep): top --- block; scalar keys +
    the source_files '- item' list. Returns (dict, body)."""
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end < 0:
        return None, text
    fm_text, body = text[3:end], text[end + 4:]
    fm, cur_list = {}, None
    for line in fm_text.splitlines():
        if not line.strip():
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val == "" or val == "|":
                fm[key] = []
                cur_list = key
            else:
                fm[key] = val.strip("'\"")
                cur_list = None
        elif cur_list is not None:
            lm = re.match(r"^\s*-\s*(.+?)\s*$", line)
            if lm:
                fm[cur_list].append(lm.group(1).strip("'\""))
    return fm, body

claims = {}   # census path -> [prd relnames]
for p in prd_paths:
    rel = os.path.relpath(p, kb_dir).replace(os.sep, "/")
    try:
        text = open(p, encoding="utf-8", errors="replace").read()
    except OSError as e:
        findings["bad_frontmatter"].append({"prd": rel, "issue": "unreadable: %s" % e})
        continue
    fm, body = parse_frontmatter(text)
    if fm is None:
        findings["bad_frontmatter"].append({"prd": rel, "issue": "no YAML frontmatter"})
        continue
    for key in ("generated_by", "domain", "source_files"):
        if key not in fm:
            findings["bad_frontmatter"].append({"prd": rel, "issue": "missing frontmatter key: %s" % key})
    src = fm.get("source_files")
    src_list = src if isinstance(src, list) else []
    for f in src_list:
        claims.setdefault(f, []).append(rel)
        if f not in census_files:
            findings["phantom_claims"].append({"prd": rel, "path": f})
        else:
            # cited at least once in the body as path:line
            if not re.search(re.escape(f) + r":\d", body):
                findings["uncited"].append({"prd": rel, "path": f})
    if not re.search(r"^##+\s+.*Open Questions", body, re.MULTILINE):
        findings["missing_oq_section"].append(rel)

for f in census_files:
    owners = claims.get(f, [])
    if not owners:
        findings["unclaimed"].append(f)
    elif len(owners) > 1:
        findings["double_claimed"].append({"path": f, "prds": owners})

failed = any(v for v in findings.values())
status = "FAIL" if failed else "PASS"
write_state(status, findings)
if failed:
    for k, v in findings.items():
        if v:
            print("extract-census: %s: %s" % (k, json.dumps(v, ensure_ascii=False)[:400]),
                  file=sys.stderr)
    print("extract-census: FAIL", file=sys.stderr)
    sys.exit(1)
if not quiet:
    print("extract-census: PASS — %d census files fully claimed + cited across %d module PRD(s)"
          % (len(census_files), len(prd_paths)))
PYEOF
