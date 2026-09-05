#!/usr/bin/env bash
# derive-project-scale.sh — deterministic project-scale signal from PRD structure
# (size-weighted spec 2026-08-23 §2, approved 2026-09-05; greenfield lane only).
#
# Counts screens / entities / flows from DOCUMENT STRUCTURE (headings, tables,
# list items, DBML blocks, F-X-NNN flow ids) — never model judgment — and
# prints one JSON line:
#   {"project_scale":"xs"|"standard","screens":N,"entities":N,"flows":N,"reason":"..."}
#
# Rule (spec §2 threshold, tera-ed against tests/scenarios/sample-prd-clinic.md
# — the calibration run is pinned in tests/size-weighted/test-project-scale.sh):
#   xs        <=> 1 <= screens <= 3 AND entities <= 2 AND flows <= 3
#   standard  <=> everything else — INCLUDING zero screen evidence (a document
#                 whose structure this parser cannot read is NOT small; unknown
#                 gets the FULL treatment, never the diet).
# The flows guard is a calibration amendment (recorded in the spec): the clinic
# corpus PRD carries 6 F-X-NNN flows — a multi-flow product is not xs even when
# its screen section is unparseable.
#
# FAIL-OPEN: unreadable/absent file, no interpreter, any parse error -> exit 0
# with project_scale=standard and the reason recorded. This script can only
# ever SHRINK the vault ceremony; it must never block a generation.
#
# Counting (deterministic, EN+ID; "view(s)" is deliberately NOT a screen word —
# "Doctor views schedule" is a verb and false-fired on the calibration corpus):
#   screens  = max( per-screen headings (text has screen|page|layar|halaman),
#                   items under a screen-section heading (screens|pages|
#                   surfaces|halaman|layar): list items or table body rows,
#                   body rows of the first table whose header row has a screen
#                   word incl. "surface" )
#   entities = max( DBML `Table <name>` blocks,
#                   headings with an entity word (entity|entitas),
#                   items under a data-model/entities section heading )
#   flows    = distinct F-<letter>-<digits> ids in headings
set -u
PRD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --prd=*) PRD="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "usage: derive-project-scale.sh --prd=<file> [--quiet]" >&2; exit 2 ;;
  esac
done

_std() {  # fail-open: standard + reason, exit 0
  [ "$QUIET" -eq 1 ] || printf '{"project_scale":"standard","screens":0,"entities":0,"flows":0,"reason":"%s"}\n' "$1"
  exit 0
}
[ -n "$PRD" ] || { echo "usage: derive-project-scale.sh --prd=<file> [--quiet]" >&2; exit 2; }
[ -f "$PRD" ] || _std "prd_unreadable"

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPY="${SCRIPT_DIR}/_lib/resolve-python.sh"
if [ -f "$_RPY" ]; then
  # shellcheck disable=SC1090
  . "$_RPY"
  mega_sdd_python || _std "no_interpreter"
else
  MEGA_SDD_PY="python3"
fi

V_PRD="$PRD" V_QUIET="$QUIET" $MEGA_SDD_PY - <<'PYEOF'
import json, os, re, sys

try:
    text = open(os.environ["V_PRD"], encoding="utf-8", errors="replace").read()
except OSError:
    text = None
quiet = os.environ.get("V_QUIET", "0") == "1"


def emit(scale, screens, entities, flows, reason):
    if not quiet:
        print(json.dumps({"project_scale": scale, "screens": screens,
                          "entities": entities, "flows": flows,
                          "reason": reason}, separators=(",", ":")))
    sys.exit(0)


if text is None:
    emit("standard", 0, 0, 0, "prd_unreadable")

SCREEN_HEAD_W = r"(?:screens?|pages?|layar|halaman)"          # per-screen headings
SCREEN_SECT_W = r"(?:screens?|pages?|surfaces?|layar|halaman)"  # section names
ENTITY_W = r"(?:entit(?:y|ies)|entitas)"
DM_SECT_W = r"(?:data\s+models?|entit(?:y|ies)|entitas|model\s+data)"

lines = text.splitlines()
HEAD_RE = re.compile(r"^(#{1,6})[ \t]+(.+)$")


def section_items(sect_word_rx):
    """Item count of the FIRST section whose heading matches sect_word_rx.
    Items = top-level list bullets OR table body rows inside the section
    (whichever the section actually uses); section ends at the next heading
    of the same or shallower level."""
    for i, ln in enumerate(lines):
        m = HEAD_RE.match(ln)
        if not (m and re.search(r"(?i)\b%s\b" % sect_word_rx, m.group(2))):
            continue
        level = len(m.group(1))
        bullets, rows, in_table = 0, 0, False
        for row in lines[i + 1:]:
            hm = HEAD_RE.match(row)
            if hm and len(hm.group(1)) <= level:
                break
            s = row.lstrip()
            if s.startswith("|"):
                if re.match(r"^\s*\|[\s:|-]+\|\s*$", row):
                    in_table = True
                elif in_table:
                    rows += 1
            elif re.match(r"^[-*][ \t]+\S", s) or re.match(r"^\d+[.)][ \t]+\S", s):
                bullets += 1
        return max(bullets, rows)
    return 0


def first_table_rows(header_word_rx):
    for i, ln in enumerate(lines[:-1]):
        if not (ln.lstrip().startswith("|") and re.search(r"(?i)\b%s\b" % header_word_rx, ln)):
            continue
        if not re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            continue
        n = 0
        for row in lines[i + 2:]:
            if not row.lstrip().startswith("|"):
                break
            n += 1
        return n
    return 0


headings = [m.group(2) for m in (HEAD_RE.match(l) for l in lines) if m]
h_screens = {h.strip().lower() for h in headings
             if re.search(r"(?i)\b%s\b" % SCREEN_HEAD_W, h)}
h_entities = {h.strip().lower() for h in headings
              if re.search(r"(?i)\b%s\b" % ENTITY_W, h)}
dbml_tables = set(re.findall(r"(?mi)^[ \t]*Table[ \t]+([A-Za-z_][\w.]*)", text))
flow_ids = {m.upper() for h in headings
            for m in re.findall(r"\b(F-[A-Z]+-\d+)\b", h)}

screens = max(len(h_screens), section_items(SCREEN_SECT_W),
              first_table_rows(r"(?:surfaces?|%s)" % SCREEN_SECT_W))
entities = max(len(dbml_tables), len(h_entities), section_items(DM_SECT_W))
flows = len(flow_ids)

if 1 <= screens <= 3 and entities <= 2 and flows <= 3:
    emit("xs", screens, entities, flows, "structure_within_xs_threshold")
emit("standard", screens, entities, flows,
     "no_screen_evidence" if screens == 0 else "above_xs_threshold")
PYEOF
rc=$?
[ "$rc" -eq 0 ] || _std "interpreter_error"
