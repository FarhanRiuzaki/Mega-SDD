#!/usr/bin/env bash
# validate-ui-quality.sh — code-delivery sharpening, Task E (gate / UI quality).
#
# Per docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md §3 Slice E
# and plan docs/superpowers/plans/2026-06-01-sharpen-code-delivery-uiux.md §Task E.
#
# UI scaffold-tells quality gate. Scans GENERATED VIEW FILES (not unit specs — this is
# the gate-stage / post-write check, slice E) for raw-scaffold "tells" that must NOT
# ship, plus "required elements" a non-trivial view must contain.
#
# TECH-AGNOSTIC: this validator hardcodes NO stack signature (no .blade/@section/
# Str::title/Laravel literals in logic — comments only). It reads the active
# framework-convention pack via resolve-framework-pack.sh:
#   - `## UI quality signatures`  (view_glob / scaffold_tells / required_elements /
#       min_view_lines / scaffold_stub_glob) — REQUIRED; absent => SKIP.
# The tells + required_elements LISTS are MERGED (union, dedup by `id`) across the whole
# pack `extends` chain — a base pack (e.g. laravel.md) may declare stack-generic tells
# while a project pack (e.g. laravel-base-26.md) adds project-specific required elements;
# both apply. Scalars (view_glob, min_view_lines, scaffold_stub_glob) are
# first-occurrence-wins (most-specific pack overrides). No pack declaring the section
# => status: SKIP (graceful, never errors). Adding a stack = adding a pack; never
# editing this validator. Laravel/Vuexy is only the example + fixture.
#
# WHAT IT CHECKS (operating on the rendered VIEW FILES under --cwd):
#   For every file matching view_glob:
#     1. scaffold_tells: FAIL if ANY tell.regex matches (checked on EVERY view).
#     2. required_elements: FAIL if the view is NON-TRIVIAL (line count > min_view_lines)
#        and is MISSING any required.regex (trivial views / partials are exempt).
#   Each finding => violations[{file, id, kind, message, line}].
#
# Usage:
#   validate-ui-quality.sh --cwd=<project-root> [--file-path=<path>] [--quiet]
#   (--file-path is accepted for PostToolUse dispatch parity but the scan is
#    project-wide / current-truth, like flow-coverage; it is advisory context only.)
#
# Output:
#   stdout: JSON report (suppressed with --quiet)
#   side-effect: OVERWRITE-writes <cwd>/.mega-sdd/.ui-quality-blockers.json (current truth)
#   exit 0 = PASS or SKIP; exit 1 = FAIL; exit 2 = error

set -uo pipefail

CWD=""
QUIET=0
FILE_PATH=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# Resolve project root (walk UP to outermost .mega-sdd/ parent).
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2
  exit 2
fi

STATE_FILE="${CWD}/.mega-sdd/.ui-quality-blockers.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

# Pull the pack section via the shared resolver (tech-agnostic chokepoint).
# Exit 3 from the resolver = section absent in every pack of the chain (=> SKIP).
PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
UI_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  UI_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="UI quality signatures" --quiet 2>/dev/null) || UI_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" FILE_PATH="$FILE_PATH" \
UI_SECTION="$UI_SECTION" \
python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ui_section = os.environ.get("UI_SECTION", "")

ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


# ── Recursive glob matcher (pack view_glob uses `**` for any-depth) ───────────
# (cloned from validate-flow-coverage.sh — Python fnmatch mishandles `**`.)
def _glob_to_regex(pat):
    i = 0
    out = ["(?s:"]
    n = len(pat)
    while i < n:
        c = pat[i]
        if c == "*":
            if pat[i:i + 3] == "**/":
                out.append("(?:.*/)?")   # ** + slash => any depth incl. zero
                i += 3
                continue
            if pat[i:i + 2] == "**":
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
            i += 1
            continue
        if c == "?":
            out.append("[^/]")
        else:
            out.append(re.escape(c))
        i += 1
    out.append(r")\Z")
    return re.compile("".join(out))


_GLOB_CACHE = {}


def glob_match(path, pattern):
    rx = _GLOB_CACHE.get(pattern)
    if rx is None:
        rx = _glob_to_regex(pattern)
        _GLOB_CACHE[pattern] = rx
    if rx.match(path):
        return True
    return rx.match(path.split("/", 1)[-1]) is not None if "/" in path else False


def write_and_exit(report, code):
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, state_file)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP",
        "validator": "ui-quality",
        "ts": ts,
        "reason": reason,
        "views_scanned": 0,
        "violations": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


# ── Graceful SKIPs ───────────────────────────────────────────────────────────
# The whole gate is pack-declared. No `## UI quality signatures` section => SKIP.
if not ui_section.strip():
    skip("pack declares no '## UI quality signatures' section")


# ── Parse the pack section ────────────────────────────────────────────────────
# CRITICAL: the resolver emits ONE `# --- from <pack>.md ---` block PER pack in the
# extends chain (most-specific first). A base pack may declare scaffold_tells while a
# project pack declares required_elements (the brief splits them across laravel.md +
# laravel-base-26.md). So we MUST union the LIST keys across ALL yaml fences — taking
# only the first fence would silently drop one of the lists. Scalars use
# first-occurrence-wins (most-specific pack, emitted first, overrides).
def parse_ui_section(text):
    """Return {view_glob, min_view_lines, scaffold_stub_glob, scaffold_tells[],
    required_elements[]}. Lists are unioned across all ```yaml fences and deduped by
    `id` (first occurrence — most-specific pack — wins on id collision)."""
    blocks = re.findall(r"```ya?ml\s*\n(.*?)```", text, re.DOTALL)
    if not blocks:
        blocks = [text]

    out = {
        "view_glob": None,
        "min_view_lines": None,
        "scaffold_stub_glob": None,
        "scaffold_tells": [],
        "required_elements": [],
    }
    seen_tell_ids = set()
    seen_req_ids = set()

    def add_item(target, seen, item):
        iid = item.get("id")
        if not iid or not item.get("regex"):
            return
        if iid in seen:
            return
        seen.add(iid)
        target.append({
            "id": iid,
            "regex": item["regex"],
            "message": item.get("message", ""),
        })

    for body in blocks:
        # Track which list we are inside (scaffold_tells / required_elements) and the
        # current list item being accumulated.
        cur_list = None        # "tell" | "req" | None
        cur_item = None
        list_indent = None     # indent of the `- ` item markers in the active list

        def flush():
            nonlocal cur_item
            if cur_item is not None:
                if cur_list == "tell":
                    add_item(out["scaffold_tells"], seen_tell_ids, cur_item)
                elif cur_list == "req":
                    add_item(out["required_elements"], seen_req_ids, cur_item)
            cur_item = None

        for raw in body.splitlines():
            if not raw.strip():
                continue
            stripped = raw.strip()
            indent = len(raw) - len(raw.lstrip())

            # full-line comment
            if stripped.startswith("#"):
                continue

            # Top-level list switches (only when at column 0 / minimal indent).
            m_list = re.match(r"^(scaffold_tells|required_elements)\s*:\s*$", stripped)
            if m_list and indent == 0:
                flush()
                cur_list = "tell" if m_list.group(1) == "scaffold_tells" else "req"
                list_indent = None
                continue

            # Top-level scalars (only at column 0, and only first occurrence wins).
            m_scalar = re.match(r"^(view_glob|min_view_lines|scaffold_stub_glob)\s*:\s*(.*)$", stripped)
            if m_scalar and indent == 0:
                flush()
                cur_list = None
                key = m_scalar.group(1)
                val = _unquote(m_scalar.group(2))
                if out[key] is None and val != "":
                    out[key] = val
                continue

            # Inside an active list?
            if cur_list is not None:
                # A new list item: `- id: ...` (possibly inline first key).
                if stripped.startswith("- "):
                    if list_indent is None:
                        list_indent = indent
                    # A dedent below the list's item indent ends the list.
                    if indent < list_indent:
                        flush()
                        cur_list = None
                        continue
                    flush()
                    cur_item = {}
                    rest = stripped[2:].strip()
                    kv = re.match(r"^([a-z_]+)\s*:\s*(.*)$", rest)
                    if kv:
                        cur_item[kv.group(1)] = _unquote(kv.group(2))
                    continue
                # A continuation key line for the current item (`  regex: ...`).
                if cur_item is not None:
                    # dedent to/under the item marker that is NOT a `- ` => list ended
                    if list_indent is not None and indent <= list_indent and not stripped.startswith("- "):
                        flush()
                        cur_list = None
                        # fall through: re-evaluate this line as top-level below is
                        # complex; cheap path — just stop the list and ignore the line
                        # unless it is a known top-level key (handled next iteration is
                        # not possible, so handle inline):
                        m_l2 = re.match(r"^(scaffold_tells|required_elements)\s*:\s*$", stripped)
                        if m_l2 and indent == 0:
                            cur_list = "tell" if m_l2.group(1) == "scaffold_tells" else "req"
                            list_indent = None
                        continue
                    kv = re.match(r"^([a-z_]+)\s*:\s*(.*)$", stripped)
                    if kv:
                        cur_item[kv.group(1)] = _unquote(kv.group(2))
                    continue

        flush()

    if out["view_glob"] is None:
        out["view_glob"] = ""
    # min_view_lines default = 20 (per _template.md schema).
    try:
        out["min_view_lines"] = int(str(out["min_view_lines"]).strip()) if out["min_view_lines"] else 20
    except (ValueError, TypeError):
        out["min_view_lines"] = 20
    return out


def _unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        return v[1:-1]
    return v


cfg = parse_ui_section(ui_section)
view_glob = cfg["view_glob"]
min_view_lines = cfg["min_view_lines"]
scaffold_tells = cfg["scaffold_tells"]
required_elements = cfg["required_elements"]

if not view_glob:
    skip("'## UI quality signatures' present but declares no view_glob")
if not scaffold_tells and not required_elements:
    skip("'## UI quality signatures' present but declares no scaffold_tells or required_elements")


# ── Compile regexes (tolerate (?i) inline; last-resort literal escape) ────────
def compile_re(pat):
    flags = 0
    if pat.startswith("(?i)"):
        flags |= re.IGNORECASE
        pat = pat[4:]
    try:
        return re.compile(pat, flags)
    except re.error:
        return re.compile(re.escape(pat), flags)


for t in scaffold_tells:
    t["_re"] = compile_re(t["regex"])
for r in required_elements:
    r["_re"] = compile_re(r["regex"])


# ── Discover view files under --cwd matching view_glob ────────────────────────
# Walk the tree once; match each project-relative path against view_glob. Exclude
# anything under .mega-sdd/ (our own artifacts), .git/, node_modules/, vendor/.
SKIP_DIRS = {".git", ".mega-sdd", "node_modules", "vendor", "storage", ".idea", "__pycache__"}
view_files = []
for root, dirs, files in os.walk(cwd):
    dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
    for fn in files:
        full = os.path.join(root, fn)
        rel = os.path.relpath(full, cwd)
        if glob_match(rel, view_glob):
            view_files.append((full, rel))
view_files.sort(key=lambda x: x[1])


def line_of(text, pos):
    return text[:pos].count("\n") + 1


def is_partial(rel, stub_glob):
    """FPP-2: a partial / component / included fragment does NOT own its page layout —
    its parent supplies @extends + the responsive grid — so required_elements (layout-extends,
    responsive) must NOT be required of it. scaffold_tells STILL apply (a raw-scaffold tell is a
    defect anywhere). Detection: basename starts with `_` (Blade/Rails partial convention),
    OR the path sits under a partials/components/layouts segment, OR it matches the pack's
    declared scaffold_stub_glob. Pure path heuristics → tech-agnostic across stacks."""
    norm = rel.replace("\\", "/")
    base = os.path.basename(norm)
    if base.startswith("_"):
        return True
    segs = norm.split("/")
    if any(s in ("_partials", "partials", "components", "layouts", "partial", "shared") for s in segs):
        return True
    if stub_glob and glob_match(norm, stub_glob):
        return True
    return False


# ── Scan each view ────────────────────────────────────────────────────────────
violations = []
for full, rel in view_files:
    try:
        with open(full, errors="replace") as f:
            text = f.read()
    except Exception:
        continue
    n_lines = text.count("\n") + 1

    # scaffold_tells — checked on EVERY view (a tell is a defect regardless of size).
    for t in scaffold_tells:
        m = t["_re"].search(text)
        if m:
            violations.append({
                "file": rel,
                "id": t["id"],
                "kind": "scaffold_tell",
                "message": t["message"],
                "line": line_of(text, m.start()),
            })

    # required_elements — only on NON-TRIVIAL, NON-PARTIAL views (FPP-2): a partial /
    # component / modal fragment is @include'd into a parent that owns the layout + grid.
    if n_lines > min_view_lines and not is_partial(rel, cfg.get("scaffold_stub_glob")):
        for r in required_elements:
            if not r["_re"].search(text):
                violations.append({
                    "file": rel,
                    "id": r["id"],
                    "kind": "required_element_missing",
                    "message": r["message"],
                    "line": 0,
                })


# ── Verdict ──────────────────────────────────────────────────────────────────
status = "FAIL" if violations else "PASS"
tells_n = sum(1 for v in violations if v["kind"] == "scaffold_tell")
missing_n = sum(1 for v in violations if v["kind"] == "required_element_missing")
report = {
    "status": status,
    "validator": "ui-quality",
    "ts": ts,
    "view_glob": view_glob,
    "min_view_lines": min_view_lines,
    "views_scanned": len(view_files),
    "summary": {
        "views_scanned": len(view_files),
        "scaffold_tells_matched": tells_n,
        "required_elements_missing": missing_n,
        "tell_ids_loaded": [t["id"] for t in scaffold_tells],
        "required_ids_loaded": [r["id"] for r in required_elements],
    },
    "violations": violations,
    "next_action": (
        "Fix the raw-scaffold tells (humanize titles/labels, resolve FK ids to a human "
        "label via the relation, format money, replace native alert/confirm with the "
        "project notification idiom) and add the missing required elements (app layout "
        "extend + responsive grid) to the flagged view file(s), then re-save (PostToolUse "
        "re-validates)."
    ) if status == "FAIL" else "No action — every scanned view is clean of scaffold tells and carries the required elements.",
}

write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
