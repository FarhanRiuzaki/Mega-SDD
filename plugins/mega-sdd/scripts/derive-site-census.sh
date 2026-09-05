#!/usr/bin/env bash
# derive-site-census.sh — deterministic WRITE/CALL site inventory of a legacy
# tree (7.26.0, spec 2026-09-05-kb-verify-lane-design.md Fase 4 site-census).
#
# Field audit lesson (Host-AS400): the KB missed the 4th CFTPNT write site and
# 4 of 6 float write sites — per-file census guarantees MEMBERSHIP, not
# behavioral coverage. This derives the machine-checkable slice of behavior:
# every WRITE/UPDATE site and every cross-program CALL site, per stack idiom.
# validate-extract-census.sh then requires each site to be cited in the KB
# (exact line, ±2 tolerance, or inside a cited a-b range) — a missed site FAILs
# and the honest fix is a citation or an [OPEN].
#
# v1 idiom support: the rpg family (rpg / rpgle / rpg-copy — fixed-format
# C-specs; column 7 '*' comments excluded; opcodes glued to factor2:
# WRITERDDFLOT). Other stacks are recorded as "no idiom support" — the
# validator treats an unsupported stack as out of scope, never silently green.
# Idiom sheet: plugins/mega-sdd/references/legacy-idioms/rpg-as400.md.
#
# Usage: derive-site-census.sh --legacy=<dir> --kb-dir=<dir> [--quiet]
# Output: <kb-dir>/.site-census.json (deterministic; re-derived every run).
# Exit: 0 written · 2 usage/IO.

set -u
LEGACY=""; KB_DIR=""; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --legacy=*) LEGACY="${arg#--legacy=}" ;;
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --quiet)    QUIET=1 ;;
    *) echo "usage: derive-site-census.sh --legacy=<dir> --kb-dir=<dir> [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$LEGACY" ] && [ -d "$LEGACY" ] || { echo "derive-site-census.sh: --legacy missing or not a directory: '$LEGACY'" >&2; exit 2; }
[ -n "$KB_DIR" ] && [ -d "$KB_DIR" ] || { echo "derive-site-census.sh: --kb-dir missing or not a directory: '$KB_DIR'" >&2; exit 2; }

LEGACY="$LEGACY" KB_DIR="$KB_DIR" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

legacy = os.path.abspath(os.environ["LEGACY"])
kb_dir = os.environ["KB_DIR"]
quiet = os.environ["QUIET"] == "1"

census_path = os.path.join(kb_dir, "census.json")
if not os.path.isfile(census_path):
    print("derive-site-census.sh: no census.json in --kb-dir (run derive-extract-census.sh first)", file=sys.stderr)
    sys.exit(2)
census = json.load(open(census_path, encoding="utf-8"))

RPG_LANGS = {"rpg", "rpgle", "rpg-copy"}
# Fixed-format RPG: opcode field starts around col 28 and is GLUED to factor2
# (WRITERDDFLOT). We scan non-comment lines (col 7 != '*') for the write-class
# opcodes and CALL literals. Targets are record-format / program names.
WRITE_RE = re.compile(r"\b(?:WRITE|UPDAT|EXCPT)([A-Z][A-Z0-9#@$]{2,})")
CALL_RE = re.compile(r"\bCALL\s*'([^']+)'")

sites = []
stack_coverage = {}
for row in census.get("files", []):
    lang = row.get("lang", "?")
    if lang in RPG_LANGS:
        stack_coverage[lang] = "rpg-fixed-format idioms"
    else:
        stack_coverage.setdefault(lang, "no idiom support (v1: rpg family only)")
        continue
    p = os.path.join(legacy, row["path"])
    try:
        lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    for i, line in enumerate(lines, 1):
        # column 7 (index 6) '*' = comment/dead code in fixed-format RPG
        if len(line) > 6 and line[6] == "*":
            continue
        for m in WRITE_RE.finditer(line):
            sites.append({"kind": "write", "target": m.group(1),
                          "file": row["path"], "line": i})
        for m in CALL_RE.finditer(line):
            sites.append({"kind": "call", "target": m.group(1).strip(),
                          "file": row["path"], "line": i})

doc = {"generated_by": "mega-sdd:derive-site-census",
       "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
       "legacy_root": legacy,
       "stack_coverage": stack_coverage,
       "site_count": len(sites),
       "sites": sites}
out = os.path.join(kb_dir, ".site-census.json")
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=1, ensure_ascii=False)
    fh.write("\n")
os.replace(tmp, out)
if not quiet:
    covered = sorted(k for k, v in stack_coverage.items() if "no idiom" not in v)
    skipped = sorted(k for k, v in stack_coverage.items() if "no idiom" in v)
    print("site-census: %d site(s) (%d write, %d call); idioms: %s%s -> %s"
          % (len(sites), sum(1 for s in sites if s["kind"] == "write"),
             sum(1 for s in sites if s["kind"] == "call"),
             ",".join(covered) or "-",
             ("; no-idiom: " + ",".join(skipped)) if skipped else "", out))
PYEOF
