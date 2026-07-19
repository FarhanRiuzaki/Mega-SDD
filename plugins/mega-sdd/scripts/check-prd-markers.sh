#!/usr/bin/env bash
# check-prd-markers.sh — deterministic marker-preservation check for emit-prd
# (P5, spec docs/superpowers/specs/2026-07-19-v5-execution-spec.md P5 row;
# research §4 "emit-prd": [VERIFIED]/[INFERRED]/[OPEN] markers carried VERBATIM
# from KB claims into the PRD — an [INFERRED] claim may NOT be presented as
# fact).
#
# The rule this enforces (anti-fabrication, marker-preservation as an
# extraction rule): every PRD line that cites a knowledge-base source must
# carry the confidence marker of the claim it cites. Marker semantics:
#   - Line-anchored citation ([Source: …knowledge-base/….md:L12] or :12):
#     the marker set present on that KB line must appear VERBATIM on the PRD
#     line. A missing marker = MARKER_STRIPPED. A marker the KB line does NOT
#     carry (e.g. PRD says [VERIFIED] where KB says [INFERRED]) =
#     MARKER_UPGRADED — presenting an inferred claim as fact.
#   - File-level citation (no line anchor): if the cited KB file carries ANY
#     confidence marker, the PRD line must carry at least one marker =
#     MARKER_MISSING otherwise.
# Lines inside fenced code blocks are skipped (quoted terse notation rides in
# code spans per decision 4 and is not a claim surface).
#
# Usage:
#   check-prd-markers.sh --prd=<path-to-PRD.md> --cwd=<project-root> [--kb=<kb-root>]
# KB root default: <cwd>/.mega-sdd/knowledge-base → docs/knowledge-base →
# docs/mega-sdd/knowledge-base → old-reference/knowledge-base (routing probe
# order). No KB found → exit 0 with a note (forward-mode PRD has no KB claims).
# Exit: 0 = clean · 1 = ≥1 marker violation (lines + Indonesian keterangan)
#       2 = usage error
set -uo pipefail

PRD=""
CWD=""
KB=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --prd=*) PRD="${arg#*=}" ;;
    --cwd=*) CWD="${arg#*=}" ;;
    --kb=*)  KB="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[ -n "$PRD" ] && [ -f "$PRD" ] || { echo "ERROR: --prd=<PRD.md> required (file must exist)" >&2; exit 2; }
[ -n "$CWD" ] && [ -d "$CWD" ] || { echo "ERROR: --cwd=<project-root> required (dir must exist)" >&2; exit 2; }

PRD="$PRD" CWD="$CWD" KB="$KB" QUIET="$QUIET" python3 <<'PYEOF'
import os, re, sys

prd_path = os.path.abspath(os.environ["PRD"])
cwd = os.path.abspath(os.environ["CWD"])
kb_override = os.environ.get("KB") or None
quiet = os.environ.get("QUIET", "0") == "1"

KB_CANDIDATES = (
    os.path.join(cwd, ".mega-sdd", "knowledge-base"),
    os.path.join(cwd, "docs", "knowledge-base"),
    os.path.join(cwd, "docs", "mega-sdd", "knowledge-base"),
    os.path.join(cwd, "old-reference", "knowledge-base"),
)
kb_root = None
if kb_override:
    kb_root = os.path.abspath(kb_override)
    if not os.path.isdir(kb_root):
        print("ERROR: --kb dir not found: %s" % kb_root, file=sys.stderr)
        sys.exit(2)
else:
    for c in KB_CANDIDATES:
        if os.path.isdir(c):
            kb_root = c
            break
if kb_root is None:
    if not quiet:
        print("prd-markers: no knowledge base found — nothing to check (forward-mode PRD)")
    sys.exit(0)

MARKER_RE = re.compile(r"\[(VERIFIED|INFERRED|OPEN)\]")
SRC_RE = re.compile(r"\[Source:([^\]]*)\]")
KB_PATH_RE = re.compile(r"((?:[\w./-]*knowledge-base/)?[\w./-]+\.md)(?::L?(\d+))?")
FENCE_RE = re.compile(r"^\s*(```|~~~)")

def resolve_kb(cited):
    c = cited.strip().strip("`")
    # normalize away any prefix up to and including "knowledge-base/"
    idx = c.find("knowledge-base/")
    rel = c[idx + len("knowledge-base/"):] if idx != -1 else c
    for cand in (os.path.join(kb_root, rel), os.path.join(cwd, c)):
        p = os.path.abspath(cand)
        if os.path.isfile(p) and p.startswith(kb_root + os.sep):
            return p
    return None

_kb_cache = {}
def kb_lines(path):
    if path not in _kb_cache:
        _kb_cache[path] = open(path, encoding="utf-8", errors="surrogateescape").read().split("\n")
    return _kb_cache[path]

violations = []
checked = 0
in_fence = False
for lineno, line in enumerate(open(prd_path, encoding="utf-8", errors="surrogateescape").read().split("\n"), 1):
    if FENCE_RE.match(line):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    for sm in SRC_RE.finditer(line):
        body = sm.group(1)
        if "knowledge-base" not in body:
            continue
        pm = KB_PATH_RE.search(body)
        if not pm:
            continue
        kb_file = resolve_kb(pm.group(1))
        if kb_file is None:
            # unresolvable citations are build-citation-map.sh's lane (exit-1
            # citation_unresolvable) — not double-reported here
            continue
        checked += 1
        prd_markers = set(MARKER_RE.findall(line))
        if pm.group(2):
            n = int(pm.group(2))
            klines = kb_lines(kb_file)
            kb_line = klines[n - 1] if 1 <= n <= len(klines) else ""
            kb_markers = set(MARKER_RE.findall(kb_line))
            if not kb_markers:
                continue  # cited KB line carries no marker — nothing to preserve
            for m in kb_markers - prd_markers:
                violations.append("MARKER_STRIPPED %d %s:L%d [%s]" % (lineno, os.path.relpath(kb_file, cwd), n, m))
            for m in prd_markers - kb_markers:
                violations.append("MARKER_UPGRADED %d %s:L%d PRD=[%s] KB=%s" % (
                    lineno, os.path.relpath(kb_file, cwd), n, m,
                    "/".join("[%s]" % k for k in sorted(kb_markers))))
        else:
            file_markers = set(MARKER_RE.findall("\n".join(kb_lines(kb_file))))
            if file_markers and not prd_markers:
                violations.append("MARKER_MISSING %d %s (file carries %s)" % (
                    lineno, os.path.relpath(kb_file, cwd),
                    "/".join("[%s]" % k for k in sorted(file_markers))))

if violations:
    for v in violations:
        print(v)
    print("KETERANGAN: marker confidence KB ([VERIFIED]/[INFERRED]/[OPEN]) hilang atau")
    print("di-upgrade di PRD — klaim [INFERRED]/[OPEN] yang tampil tanpa marker (atau")
    print("sebagai [VERIFIED]) berarti dugaan disajikan sebagai fakta (anti-halu")
    print("invariant 5). Kembalikan marker VERBATIM dari klaim KB yang dikutip pada")
    print("setiap baris PRD di atas, lalu jalankan ulang check ini.")
    sys.exit(1)

if not quiet:
    print("prd-markers: clean (%d cited KB claim(s) checked, markers preserved verbatim)" % checked)
sys.exit(0)
PYEOF
exit $?
