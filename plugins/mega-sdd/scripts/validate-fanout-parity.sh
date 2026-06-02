#!/usr/bin/env bash
# validate-fanout-parity.sh — code-delivery intelligence, Iter-79 A2 (decomposition).
#
# Per docs/superpowers/audits/2026-06-02-intelligence-e2e/04-decomposition-delivery.md §A2.
#
# Fan-out PARITY gate: "LC is always the survivor." Sibling-consistency (slice B) checks
# that a cross-cutting concern is implemented the SAME WAY across siblings, and
# flow-coverage (slice A) sums artifacts per-flow TOTAL — so neither sees one sibling
# served RICHLY while a peer is under-served. This validator asserts presence-PARITY of
# the deliverable obligations across a sibling group: among the VIEW-BEARING siblings of a
# module/scope group, if ANY sibling declares an obligation (a `## UI contract`, a
# `type: render` acceptance test), EVERY view-bearing sibling must declare the same KIND of
# obligation. A sibling missing what its peers have = `fanout_parity_divergence`.
#
# RELATIVE-TO-PEERS, never an absolute bar: the check fires ONLY when ≥1 sibling already
# declares the obligation, so a legitimately-simpler sibling (or a solo unit, or a
# non-view-bearing unit) is never false-flagged. This is the direct fix for the survivor
# pattern proven in the tradefinance Phase-2 run (U-026 richly served; U-027..U-031 drifted).
#
# TECH-AGNOSTIC: hardcodes NO stack signature. Reads the active framework-convention pack
# via resolve-framework-pack.sh:
#   - `## UI quality signatures` (view_glob) — what counts as a view file (=> view-bearing).
# Absent in every pack of the chain => SKIP (the parity check needs a view_glob to know
# which siblings are view-bearing). Adding a stack = adding a pack; never editing this file.
#
# Usage: validate-fanout-parity.sh --cwd=<project-root> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.fanout-parity-state.json
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

STATE_FILE="${CWD}/.mega-sdd/.fanout-parity-state.json"
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
from collections import defaultdict
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
        "status": "SKIP", "validator": "fanout-parity", "ts": ts, "reason": reason,
        "divergences": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


# ── view_glob from pack §UI quality signatures (tech-agnostic; absent => SKIP) ──
m = re.search(r"^\s*view_glob\s*:\s*['\"]?([^'\"\n]+)['\"]?", ui_section, re.MULTILINE)
view_glob = m.group(1).strip() if m else None
if not view_glob:
    skip("pack declares no `## UI quality signatures` view_glob (cannot identify view-bearing units)")


def glob_to_regex(pat):
    # translate a glob with ** / * to a regex anchored at the end of a path
    pat = pat.strip()
    out, i = [], 0
    while i < len(pat):
        c = pat[i]
        if c == "*" and pat[i:i + 2] == "**":
            out.append(".*")
            i += 2
            if i < len(pat) and pat[i] == "/":
                i += 1
        elif c == "*":
            out.append("[^/]*")
            i += 1
        elif c == ".":
            out.append(r"\.")
            i += 1
        else:
            out.append(re.escape(c))
            i += 1
    return re.compile("(^|/)" + "".join(out) + "$")


VIEW_RE = glob_to_regex(view_glob)

vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_root):
    skip("no_vault (.mega-sdd/vaults/ absent)")


def find_units():
    best = []
    for d in sorted(glob.glob(os.path.join(vault_root, "*"))):
        if not os.path.isdir(d):
            continue
        base = os.path.basename(d)
        unit_dirs = [os.path.join(d, "units"), os.path.join(vault_root, base + "-bound", "units")]
        units = []
        for ud in unit_dirs:
            units += sorted(glob.glob(os.path.join(ud, "U-*.md")) + glob.glob(os.path.join(ud, "U-*", "unit.md")))
        if units:
            best.append(units)
    return max(best, key=len) if best else []


unit_paths = find_units()
if not unit_paths:
    skip("no active vault with units/U-*.md found")

FM_RE = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)


def parse_unit(path):
    with open(path, errors="replace") as f:
        text = f.read()
    fm = {}
    fmm = FM_RE.match(text)
    if fmm:
        for line in fmm.group(1).splitlines():
            mm = re.match(r"^([a-zA-Z_]+)\s*:\s*(.*)$", line)
            if mm:
                fm[mm.group(1)] = mm.group(2).strip().strip('"').strip("'")
    uid = fm.get("unit_id") or os.path.splitext(os.path.basename(path))[0]
    return uid, fm, text


def is_view_bearing(body):
    """A unit is view-bearing iff any path token in its body matches the pack view_glob.
    Scans the whole body so a `## Target files` fenced block OR an inline path both count."""
    for tok in re.findall(r"[A-Za-z0-9_./*-]+", body):
        if "/" in tok and VIEW_RE.search(tok):
            return True
    return False


def has_ui_contract(body):
    return bool(re.search(r"^#{2,4}\s+UI contract\b", body, re.MULTILINE | re.IGNORECASE))


def has_render_test(full_text):
    """Structured acceptance_test of type/kind `render` (block or inline-list form).
    Mirror of validate-unit-spec.sh _has_render_acceptance_test — never a prose bullet."""
    at = re.search(r"^acceptance_test\s*:\s*(.*?)(?:^\S|\Z)", full_text, re.DOTALL | re.MULTILINE)
    if not at:
        return False
    region = at.group(1)
    if re.search(r"(?:type|kind)\s*:\s*[\"']?render[\"']?\b", region):
        return True
    if "[" in region and re.search(r"[\[,]\s*[\"']?render[\"']?\s*[,\]]", region):
        return True
    return False


units = []
for p in unit_paths:
    uid, fm, text = parse_unit(p)
    units.append({"uid": uid, "fm": fm, "body": text})

groups = defaultdict(list)
for u in units:
    key = (u["fm"].get("module", "_all"), u["fm"].get("scope", "_all"))
    groups[key].append(u)

# Obligations checked for presence-parity among VIEW-BEARING siblings.
OBLIGATIONS = [
    ("ui_contract", lambda u: has_ui_contract(u["body"]), "a `## UI contract` section"),
    ("render_test", lambda u: has_render_test(u["body"]), "a `type: render` acceptance test"),
]

divergences = []
groups_checked = 0
for gkey, members in groups.items():
    view_members = [u for u in members if is_view_bearing(u["body"])]
    if len(view_members) < 2:
        continue  # need ≥2 view-bearing siblings for a parity comparison
    groups_checked += 1
    for ob_key, pred, label in OBLIGATIONS:
        declarers = [u for u in view_members if pred(u)]
        if not declarers or len(declarers) == len(view_members):
            continue  # uniform (all or none) => consistent; only mixed = divergence
        for u in view_members:
            if not pred(u):
                divergences.append({
                    "halt_type": "fanout_parity_divergence",
                    "unit": u["uid"],
                    "obligation": ob_key,
                    "module": gkey[0], "scope": gkey[1],
                    "expected": label,
                    "reason": (
                        f"view-bearing sibling(s) {sorted(d['uid'] for d in declarers)} declare "
                        f"{label} but this unit does not — fan-out richness divergence "
                        f"(the survivor is served better than its peers)"
                    ),
                })

status = "FAIL" if divergences else "PASS"
report = {
    "status": status, "validator": "fanout-parity", "ts": ts,
    "summary": {
        "units_checked": len(units),
        "sibling_groups_with_view_parity": groups_checked,
        "view_glob": view_glob,
        "divergence_count": len(divergences),
    },
    "divergences": divergences,
    "next_action": (
        "Bring every view-bearing sibling in a module/scope group to parity: if one sibling "
        "declares a `## UI contract` or a `type: render` acceptance test, every view-bearing "
        "sibling must declare the same KIND of obligation. Add the missing obligation(s) to the "
        "under-served unit(s), then re-save (PostToolUse re-validates)."
        if divergences else "No action — sibling deliverable obligations are at parity."
    ),
}
write_and_exit(report, 1 if status == "FAIL" else 0)
PYEOF
