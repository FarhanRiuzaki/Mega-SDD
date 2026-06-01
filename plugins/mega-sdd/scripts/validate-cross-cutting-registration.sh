#!/usr/bin/env bash
# validate-cross-cutting-registration.sh — code-delivery sharpening, Task C (execution).
#
# Per docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md §3 Slice C
# and plan docs/superpowers/plans/2026-06-01-sharpen-code-delivery-uiux.md §Task C.
#
# Per-sibling cross-cutting REGISTRATION scan — execution-fidelity gate. Where slice B
# (validate-sibling-consistency.sh) checks the UNIT SPECS declare a concern consistently,
# this checks the GENERATED SOURCE actually REGISTERS it. Catches the 2bdfc1b defect: 5 Phase-2
# models whose tables carry branch_id were branch-scoped, but the bolt never added the
# `addGlobalScope(new BranchScoped)` call in their booted() — a silent cross-branch leak. The
# specs were correct; the runtime registration was dropped.
#
# REAL-WORLD-GROUNDED DETECTION (verified against new-tradefinance-import 2bdfc1b): a model
# does NOT reference its table's columns in source — branch_id lives in the MIGRATION, not the
# model file. So "applies_when has_column:branch_id" is evaluated against the SCHEMA: the set of
# tables a migration gives the column. A model is branch-scoped iff its `$table` is in that set
# (exact), or (no `$table`) its class-name tokens overlap a branch-scoped table's tokens. The
# scope DEFINITION (no `$table`, class tokens don't overlap a data table) and legitimately
# unscoped models (table without the column) are excluded — no false positives.
#
# TECH-AGNOSTIC: hardcodes NO stack signature. Reads the active pack's `## Cross-cutting
# concerns` via resolve-framework-pack.sh — each concern's `applies_when`, `registration_signature`,
# `registration_target_glob` (model source), and `registration_source_glob` (where the column is
# declared — migrations/schema). A concern missing registration_signature + both globs => its
# runtime scan is skipped. No concern qualifies => status: SKIP. Add a stack = add a pack.
#
# Honest Fork-A boundary (spec §1.6): runs PostToolUse on written source; PreToolUse Branch 11
# blocks the NEXT mega-sdd:execute-bolts on FAIL (detect-and-block-next — a hook cannot un-write
# a file a bolt just wrote mid-turn).
#
# Usage: validate-cross-cutting-registration.sh --cwd=<project-root> [--quiet]
# Output: stdout JSON (--quiet suppresses); OVERWRITE <cwd>/.mega-sdd/.cross-cutting-state.json
# Exit: 0 = PASS or SKIP; 1 = FAIL; 2 = error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

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

STATE_FILE="${CWD}/.mega-sdd/.cross-cutting-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
CONCERNS_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  CONCERNS_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Cross-cutting concerns" --quiet 2>/dev/null) || CONCERNS_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" CONCERNS_SECTION="$CONCERNS_SECTION" \
python3 <<'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
concerns_section = os.environ.get("CONCERNS_SECTION", "")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def write_and_exit(report, code):
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP", "validator": "cross-cutting-registration", "ts": ts, "reason": reason,
        "missing_registration": [], "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


def first_yaml_block(t):
    m = re.search(r"```ya?ml\s*\n(.*?)```", t, re.DOTALL)
    return m.group(1) if m else t


def parse_concerns(text):
    if not text.strip():
        return []
    body = first_yaml_block(text)
    out, cur = [], None

    def flush():
        nonlocal cur
        if cur and cur.get("registration_signature"):
            out.append(cur)
        cur = None

    started = False
    for raw in body.splitlines():
        if not raw.strip():
            continue
        s = raw.strip()
        if re.match(r"^cross_cutting_concerns\s*:", s):
            started = True
            continue
        if not started and s.startswith("- ") and "applies_when" in body:
            started = True
        if s.startswith("- "):
            flush()
            cur = {}
            s = s[2:].strip()
            if not s:
                continue
        if cur is None:
            continue
        m = re.match(r"([a-z_]+)\s*:\s*(.*)$", s)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip().strip('"').strip("'")
        if k in ("concern", "applies_when", "spec_obligation",
                 "registration_signature", "registration_target_glob", "registration_source_glob"):
            cur[k] = v
    flush()
    return out


concerns = [c for c in parse_concerns(concerns_section)
            if c.get("registration_signature") and c.get("registration_target_glob")
            and c.get("registration_source_glob")]
if not concerns:
    skip("pack declares no cross-cutting concern with registration_signature + registration_target_glob + registration_source_glob")

_STOP = {"table", "the", "of", "and", "for", "to"}


def tokenize(s):
    if not s:
        return set()
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", s)   # camelCase split
    s = re.sub(r"[^A-Za-z0-9]+", " ", s).lower()
    toks = set()
    for w in s.split():
        w = re.sub(r"s$", "", w)                       # crude singular
        if len(w) >= 2 and w not in _STOP:
            toks.add(w)
    return toks


TABLE_DECL_RE = re.compile(r"Schema::(?:create|table)\(\s*['\"]([^'\"]+)['\"]")
MODEL_TABLE_RE = re.compile(r"\$table\s*=\s*['\"]([^'\"]+)['\"]")
CLASS_RE = re.compile(r"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)")


def read(path):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except Exception:
        return ""


missing_registration = []
models_scanned = 0
for c in concerns:
    col_m = re.match(r"has_column\s*:\s*(.+)$", c.get("applies_when", "").strip())
    column = col_m.group(1).strip() if col_m else None
    if not column:
        continue
    try:
        reg_re = re.compile(c["registration_signature"])
    except re.error:
        continue
    col_re = re.compile(r"\b" + re.escape(column) + r"\b")

    # 1. Branch-scoped TABLES: tables a migration gives the column (exact names + token-sets).
    scoped_tables = set()
    scoped_tablesets = []
    for src in sorted(glob.glob(os.path.join(cwd, c["registration_source_glob"]), recursive=True)):
        if not os.path.isfile(src):
            continue
        content = read(src)
        if not col_re.search(content):
            continue
        for t in TABLE_DECL_RE.findall(content):
            scoped_tables.add(t)
            scoped_tablesets.append(tokenize(t))
    if not scoped_tables:
        continue

    # 2. Each model: branch-scoped iff its $table is in the set (exact) or (no $table) its
    #    class tokens overlap a scoped table's tokens. Branch-scoped + no registration => miss.
    for mp in sorted(glob.glob(os.path.join(cwd, c["registration_target_glob"]), recursive=True)):
        if not os.path.isfile(mp):
            continue
        content = read(mp)
        models_scanned += 1
        tbl_m = MODEL_TABLE_RE.search(content)
        is_scoped = False
        if tbl_m:
            is_scoped = tbl_m.group(1) in scoped_tables
        else:
            cls = CLASS_RE.search(content)
            ctoks = tokenize(cls.group(1)) if cls else set()
            is_scoped = any(ctoks & ts for ts in scoped_tablesets) if ctoks else False
        if not is_scoped:
            continue
        if not reg_re.search(content):
            missing_registration.append({
                "file": os.path.relpath(mp, cwd),
                "concern": c.get("concern", "?"),
                "table": tbl_m.group(1) if tbl_m else "(by class-name match)",
                "expected_registration": c["registration_signature"],
                "reason": (
                    f"model's table carries `{column}` (branch-scoped) but the source never "
                    f"registers the concern ({c['registration_signature']}) — e.g. the global "
                    "scope is declared but never attached in booted(); silent cross-branch leak."
                ),
            })

status = "FAIL" if missing_registration else "PASS"
report = {
    "status": status, "validator": "cross-cutting-registration", "ts": ts,
    "summary": {
        "concerns_with_registration": len(concerns),
        "model_files_scanned": models_scanned,
        "missing_registration_count": len(missing_registration),
    },
    "missing_registration": missing_registration,
    "next_action": (
        "In each flagged model, register the cross-cutting concern (e.g. add "
        "`static::addGlobalScope(new BranchScoped)` to booted()) so the branch-scoped table is "
        "actually filtered at runtime; re-save (PostToolUse re-validates). The next "
        "mega-sdd:execute-bolts is blocked until the registrations land."
    ) if status == "FAIL" else "No action — every branch-scoped model registers the concern.",
}
write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF
exit $?
