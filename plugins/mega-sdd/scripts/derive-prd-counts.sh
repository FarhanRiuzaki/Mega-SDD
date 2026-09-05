#!/usr/bin/env bash
# derive-prd-counts.sh — deterministic frontmatter-count writer for module
# PRDs (7.26.0, spec 2026-09-05-kb-verify-lane-design.md Fase 4).
#
# Field audit lesson (Host-AS400): agent-typed counts drifted in ALL 7 modules
# and the README roll-up inherited the drift. Counts that a script can derive
# must never be typed by a model. Derived per modules/*.prd.md body:
#   inferred_count  = [INFERRED] occurrences
#   open_count      = §6 OQ entries (- OQ-…)
#   locked_count    = [LOCKED] occurrences
#   intent_count    = explicit [INTENT] markers (untagged claims are
#                     default-verified and are NOT counted — by grammar)
#   artifact_count  = [ARTIFACT] occurrences
#   source_files_cited = source_files entries cited (path:line) in the body
# verified_count is NOT derivable (implicit-verified grammar) — left untouched
# when present, never invented.
#
# Usage: derive-prd-counts.sh --kb-dir=<dir> [--write] [--quiet]
#   default (check mode): report drift, exit 1 when any field differs/missing
#   --write: rewrite/insert the derived fields in each PRD's frontmatter
# Exit: 0 clean/written · 1 drift found (check mode) · 2 usage/IO.

set -u
KB_DIR=""; WRITE=0; QUIET=0
for arg in "$@"; do
  case "$arg" in
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --write)    WRITE=1 ;;
    --quiet)    QUIET=1 ;;
    *) echo "usage: derive-prd-counts.sh --kb-dir=<dir> [--write] [--quiet]" >&2; exit 2 ;;
  esac
done
[ -n "$KB_DIR" ] && [ -d "$KB_DIR" ] || { echo "derive-prd-counts.sh: --kb-dir missing or not a directory: '$KB_DIR'" >&2; exit 2; }

KB_DIR="$KB_DIR" WRITE="$WRITE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys

kb_dir = os.environ["KB_DIR"]
write = os.environ["WRITE"] == "1"
quiet = os.environ["QUIET"] == "1"

modules_dir = os.path.join(kb_dir, "modules")
prds = []
if os.path.isdir(modules_dir):
    prds = sorted(os.path.join(modules_dir, n)
                  for n in os.listdir(modules_dir) if n.endswith(".prd.md"))
if not prds:
    if not quiet:
        print("prd-counts: no modules/*.prd.md under %s — nothing to derive" % kb_dir)
    sys.exit(0)

DERIVED = ("inferred_count", "open_count", "locked_count",
           "intent_count", "artifact_count", "source_files_cited")

drift = 0
for p in prds:
    rel = os.path.relpath(p, kb_dir)
    text = open(p, encoding="utf-8", errors="replace").read()
    if not text.startswith("---"):
        print("prd-counts: %s: no frontmatter — skipped" % rel, file=sys.stderr)
        drift += 1
        continue
    end = text.find("\n---", 3)
    if end < 0:
        print("prd-counts: %s: unterminated frontmatter — skipped" % rel, file=sys.stderr)
        drift += 1
        continue
    fm_text, body = text[3:end], text[end + 4:]

    src_files = []
    in_sf = False
    for line in fm_text.splitlines():
        if re.match(r"^source_files:\s*$", line):
            in_sf = True
            continue
        if in_sf:
            lm = re.match(r"^\s+-\s+(.+?)\s*$", line)
            if lm:
                src_files.append(lm.group(1).strip("'\""))
                continue
            if re.match(r"^\S", line):
                in_sf = False

    sec6 = ""
    m6 = re.search(r"^##\s*6\.", body, re.MULTILINE)
    if m6:
        sec6 = body[m6.start():]
    derived = {
        "inferred_count": len(re.findall(r"\[INFERRED\]", body)),
        "open_count": len(re.findall(r"^\s*-\s*(?:\[[ xX]\]\s*)?OQ-", sec6, re.MULTILINE)),
        "locked_count": len(re.findall(r"\[LOCKED\]", body)),
        "intent_count": len(re.findall(r"\[INTENT\]", body)),
        "artifact_count": len(re.findall(r"\[ARTIFACT\]", body)),
        "source_files_cited": sum(1 for f in src_files
                                  if re.search(re.escape(f) + r":\d", body)),
    }

    current = {}
    for k in DERIVED:
        mm = re.search(r"^%s:\s*(\S+)\s*$" % re.escape(k), fm_text, re.MULTILINE)
        if mm:
            try:
                current[k] = int(mm.group(1))
            except ValueError:
                current[k] = None

    diffs = {k: (current.get(k), derived[k]) for k in DERIVED
             if current.get(k) != derived[k]}
    if not diffs:
        if not quiet:
            print("prd-counts: %s: clean" % rel)
        continue

    if write:
        new_lines = [ln for ln in fm_text.splitlines()
                     if not re.match(r"^(%s):" % "|".join(DERIVED), ln)]
        for k in DERIVED:
            new_lines.append("%s: %d" % (k, derived[k]))
        new_text = "---" + "\n".join([""] + new_lines) + "\n---" + text[end + 4:]
        tmp = p + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(new_text)
        os.replace(tmp, p)
        if not quiet:
            print("prd-counts: %s: rewrote %s" % (rel, ", ".join(sorted(diffs))))
    else:
        drift += 1
        for k, (cur, der) in sorted(diffs.items()):
            print("prd-counts: DRIFT %s: %s fm=%s derived=%d" % (rel, k, cur, der),
                  file=sys.stderr)

if not write and drift:
    print("prd-counts: %d PRD(s) drifted — run with --write" % drift, file=sys.stderr)
    sys.exit(1)
PYEOF
