#!/usr/bin/env bash
# validate-ui-deferral.sh — code-delivery intelligence, Iter-79 B1 (delivery).
#
# Per docs/superpowers/audits/2026-06-02-intelligence-e2e/04-decomposition-delivery.md §B1.
#
# Closes the SANCTIONED UI-deferral bypass: a bolt commits a raw-scaffold view and
# discharges the UI obligation by pointing at a FUTURE polish unit. validate-ui-quality
# (Branch 8) fences scaffold *tells* on the written view, but a scaffold that happens not to
# trip a tell regex still ships, and the bolt's own prose deferral ("scaffold kept; UI polish
# deferred to a later unit") is never checked against the unit's `## UI contract`. This is the
# DOMINANT fixture failure: bolts/U-027..U-030 bolt-reports literally say "scaffold kept" and
# commit anyway (the feedback_simplification_flawless "no deferred-to-next-iter" anti-pattern).
#
# SIGNATURE (deterministic): for each committed bolt-report, if (a) the unit it implements
# carries a `## UI contract` AND (b) the bolt-report contains a UI-deferral tell co-occurring
# with a view reference → `ui_obligation_deferred`. A bolt with NO UI contract, or one whose
# report simply describes finished work, is never flagged. Honest Fork-A detect-and-block-next:
# cannot un-commit, but blocks the NEXT execute-bolts until the deferred UI is realized.
#
# TECH-AGNOSTIC: view reference uses the pack §UI quality signatures view_glob; absent => the
# view-coupling check falls back to generic view words (view/template/component) so the gate
# still works, but a pack with no UI signatures makes the whole check SKIP. The deferral tells
# are generic English. The `## UI contract` obligation is a unit-structural marker.
#
# Usage: validate-ui-deferral.sh --cwd=<project-root> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.ui-deferral-state.json
# Exit: 0 = PASS or SKIP; 1 = FAIL; 2 = error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) : ;;
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

STATE_FILE="${CWD}/.mega-sdd/.ui-deferral-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
UI_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  UI_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="UI quality signatures" --quiet 2>/dev/null) || UI_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" UI_SECTION="$UI_SECTION" \
python3 <<'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ui_section = os.environ.get("UI_SECTION", "")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def write_and_exit(report, code):
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP", "validator": "ui-deferral", "ts": ts, "reason": reason,
        "deferrals": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


# The pack must declare UI signatures for this gate to be meaningful (a stack with no UI
# obligation has nothing to defer). Absent => SKIP (tech-agnostic, no false positives).
if not re.search(r"view_glob\s*:", ui_section):
    skip("pack declares no `## UI quality signatures` (no UI obligation to defer)")

m = re.search(r"^\s*view_glob\s*:\s*['\"]?([^'\"\n]+)['\"]?", ui_section, re.MULTILINE)
view_glob = m.group(1).strip() if m else None


def glob_to_regex(pat):
    out, i = [], 0
    while i < len(pat):
        c = pat[i]
        if pat[i:i + 2] == "**":
            out.append(".*"); i += 2
            if i < len(pat) and pat[i] == "/":
                i += 1
        elif c == "*":
            out.append("[^/]*"); i += 1
        elif c == ".":
            out.append(r"\."); i += 1
        else:
            out.append(re.escape(c)); i += 1
    return re.compile("(^|/)" + "".join(out))


VIEW_RE = glob_to_regex(view_glob) if view_glob else None
GENERIC_VIEW_RE = re.compile(r"\b(view|views|template|templates|component|components|blade|\.vue|\.jsx|\.tsx)\b", re.IGNORECASE)

# UI-deferral tells — generic English admissions that UI work was NOT finished this bolt.
DEFERRAL_RE = re.compile(
    r"scaffold\s+kept"
    r"|(?:ui|polish|styl\w+|responsive\w*)\b[^.\n]{0,40}\bdefer"
    r"|defer\w*\b[^.\n]{0,40}\b(?:ui|polish|view|blade|later|future|dedicated|closeout|wave|unit)"
    r"|polish\s+(?:pass\s+)?deferred"
    r"|TODO[:\s][^.\n]{0,40}\b(?:ui|polish|styl|view)",
    re.IGNORECASE,
)


def unit_has_ui_contract(unit_text):
    return bool(re.search(r"^#{2,4}\s+UI contract\b", unit_text, re.MULTILINE | re.IGNORECASE))


# Map bolt unit-id -> unit file text (search both unit layouts, bound + unbound).
def load_units():
    out = {}
    for up in sorted(
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*.md")) +
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*", "unit.md")) +
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*.md")) +
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*", "unit.md"))
    ):
        try:
            txt = open(up, errors="replace").read()
        except Exception:
            continue
        fm = re.search(r"^---\s*\n(.*?)\n---", txt, re.DOTALL)
        uid = None
        if fm:
            mm = re.search(r"^(?:unit_id|id)\s*:\s*(\S+)", fm.group(1), re.MULTILINE)
            if mm:
                uid = mm.group(1).strip().strip('"').strip("'")
        if not uid:
            base = os.path.basename(os.path.dirname(up)) if up.endswith("unit.md") else os.path.splitext(os.path.basename(up))[0]
            mm = re.match(r"(U-\d+)", base)
            uid = mm.group(1) if mm else base
        out.setdefault(uid, txt)
    return out


units = load_units()

bolt_reports = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "bolts", "U-*", "bolt-report.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "bolts", "U-*", "bolt-report.md"))
)
if not bolt_reports:
    skip("no bolt-reports found (.mega-sdd/vaults/*/bolts/U-*/bolt-report.md)")

deferrals = []
reports_scanned = 0
for br in bolt_reports:
    m = re.search(r"/bolts/(U-[^/]+)/bolt-report\.md$", br)
    uid_dir = m.group(1) if m else None
    uid = re.match(r"(U-\d+)", uid_dir or "")
    uid = uid.group(1) if uid else uid_dir
    try:
        report = open(br, errors="replace").read()
    except Exception:
        continue
    reports_scanned += 1

    unit_text = units.get(uid) or units.get(uid_dir) or ""
    if not unit_text or not unit_has_ui_contract(unit_text):
        continue  # only a unit that PROMISED a UI contract can defer it

    dm = DEFERRAL_RE.search(report)
    if not dm:
        continue
    # require the deferral to be view-coupled (a view path OR generic view word in the report)
    view_coupled = bool((VIEW_RE and VIEW_RE.search(report)) or GENERIC_VIEW_RE.search(report))
    if not view_coupled:
        continue
    snippet = re.sub(r"\s+", " ", report[max(0, dm.start() - 20):dm.end() + 40]).strip()
    deferrals.append({
        "halt_type": "ui_obligation_deferred",
        "unit": uid,
        "bolt_report": os.path.relpath(br, cwd),
        "tell": snippet,
        "reason": (
            f"{uid} carries a `## UI contract` but its bolt-report defers the UI obligation "
            f"to a future unit ('{snippet}') — a sanctioned scaffold-kept bypass. The contract's "
            f"states must be realized in THIS bolt, not deferred."
        ),
    })

status = "FAIL" if deferrals else "PASS"
report = {
    "status": status, "validator": "ui-deferral", "ts": ts,
    "summary": {
        "bolt_reports_scanned": reports_scanned,
        "units_with_ui_contract": sum(1 for t in units.values() if unit_has_ui_contract(t)),
        "deferral_count": len(deferrals),
    },
    "deferrals": deferrals,
    "next_action": (
        "Realize each flagged unit's `## UI contract` required_states in the committed view "
        "instead of deferring to a future polish unit, then re-run the bolt (PostToolUse "
        "re-validates)."
        if deferrals else "No action — no UI obligation was deferred."
    ),
}
write_and_exit(report, 1 if status == "FAIL" else 0)
PYEOF
