#!/usr/bin/env bash
# validate-sibling-consistency.sh — code-delivery sharpening, Task B (decomposition).
#
# Per docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md §3 Slice B
# and plan docs/superpowers/plans/2026-06-01-sharpen-code-delivery-uiux.md §Task B.
#
# Cross-unit sibling-consistency gate: when a cross-cutting concern applies to a set of
# structurally-analogous sibling units, every sibling must implement it the SAME way
# (one consistent mechanism), and every declared FK column must declare its derived
# relation accessor. Catches the "fan-out divergence" defect (golden exemplar correct,
# siblings drift) proven in the tradefinance Phase-2 run.
#
# TECH-AGNOSTIC: hardcodes NO stack signature. Reads the active framework-convention
# pack via resolve-framework-pack.sh:
#   - `## Cross-cutting concerns` (cross_cutting_concerns:) — concern/applies_when/
#       spec_obligation. Absent in every pack of the chain => the concern check is
#       inert (no concern can match).
#   - `## Relation derivation` (relation_derivation.fk_to_accessor) — universal default
#       lives in _universal.md ({name}_id => belongs-to accessor `{name}`); a pack MAY
#       override casing/kind. Absent everywhere => relation check skips.
# If NEITHER section is declared anywhere => status: SKIP (graceful, never errors).
# Adding a stack = adding a pack; never editing this validator. Laravel is only the fixture.
#
# WHAT IT CHECKS (operates on UNIT SPECS — decomposition-stage gate; the runtime
# registration scan of generated SOURCE is slice C):
#   1. Inconsistent concern: group units by `module`+`scope` frontmatter (absent =>
#      one group / whole vault). For each pack concern whose `applies_when`
#      (has_column:<col>) matches a unit, assert the unit declares the `spec_obligation`
#      signature. A unit to which the concern applies but that does NOT declare the
#      obligation has diverged from its siblings => inconsistent[].
#   2. Missing relation: for each FK column a unit declares (a `<name>_id` on a line that
#      marks it a foreign key), assert the unit declares the derived relation accessor
#      (universal default: camelCase singular of `<name>`). Missing => missing_relations[].
#
# Usage: validate-sibling-consistency.sh --cwd=<project-root> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.sibling-consistency-state.json
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

STATE_FILE="${CWD}/.mega-sdd/.sibling-consistency-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2;
}

PACK_RESOLVER="${SCRIPT_DIR}/_lib/resolve-framework-pack.sh"
CONCERNS_SECTION=""
RELATION_SECTION=""
if [ -x "$PACK_RESOLVER" ]; then
  CONCERNS_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Cross-cutting concerns" --quiet 2>/dev/null) || CONCERNS_SECTION=""
  RELATION_SECTION=$(bash "$PACK_RESOLVER" --cwd="$CWD" --section="Relation derivation" --quiet 2>/dev/null) || RELATION_SECTION=""
fi

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" \
CONCERNS_SECTION="$CONCERNS_SECTION" RELATION_SECTION="$RELATION_SECTION" \
python3 <<'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
concerns_section = os.environ.get("CONCERNS_SECTION", "")
relation_section = os.environ.get("RELATION_SECTION", "")
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def write_and_exit(report, code):
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP", "validator": "sibling-consistency", "ts": ts, "reason": reason,
        "inconsistent": [], "missing_relations": [],
        "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


def first_yaml_block(section_text):
    m = re.search(r"```ya?ml\s*\n(.*?)```", section_text, re.DOTALL)
    return m.group(1) if m else section_text


# ── Parse `## Cross-cutting concerns` -> [{concern, applies_when, spec_obligation}] ──
def parse_concerns(text):
    if not text.strip():
        return []
    body = first_yaml_block(text)
    out, cur = [], None

    def flush():
        nonlocal cur
        if cur and cur.get("applies_when") and cur.get("spec_obligation"):
            out.append(cur)
        cur = None

    started = False
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        if re.match(r"^cross_cutting_concerns\s*:", stripped):
            started = True
            continue
        if not started:
            # tolerate a list that is not under the exact key (be lenient)
            if stripped.startswith("- ") and ("applies_when" in body):
                started = True
        if stripped.startswith("- "):
            flush()
            cur = {}
            stripped = stripped[2:].strip()
            if not stripped:
                continue
        if cur is None:
            continue
        m = re.match(r"([a-z_]+)\s*:\s*(.*)$", stripped)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip().strip('"').strip("'")
        if key in ("concern", "applies_when", "spec_obligation", "registration_signature"):
            cur[key] = val
    flush()
    return out


# relation_derivation: we implement the universal default (strip trailing _id ->
# camelCase accessor). Presence of the section (universal default or pack override)
# enables the relation check; total absence disables it.
def relation_enabled(text):
    return bool(text and ("fk_to_accessor" in text or "relation_derivation" in text))


concerns = parse_concerns(concerns_section)
rel_on = relation_enabled(relation_section)

if not concerns and not rel_on:
    skip("pack declares neither '## Cross-cutting concerns' nor '## Relation derivation'")

vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_root):
    skip("no_vault (.mega-sdd/vaults/ absent)")


# ── Locate the active vault (most units); support <vault>/units and -bound ──
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
    with open(path) as f:
        text = f.read()
    fm = {}
    m = FM_RE.match(text)
    if m:
        for line in m.group(1).splitlines():
            mm = re.match(r"^([a-zA-Z_]+)\s*:\s*(.*)$", line)
            if mm:
                fm[mm.group(1)] = mm.group(2).strip().strip('"').strip("'")
    uid = fm.get("unit_id") or os.path.splitext(os.path.basename(path))[0]
    return uid, fm, text


def camel_singular_accessor(col):
    """branch_id -> branch ; import_lc_id -> importLc (universal default accessor name)."""
    base = re.sub(r"_id$", "", col)
    parts = [p for p in base.split("_") if p]
    if not parts:
        return base
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


def declared_fk_columns(body):
    """A declared FK column = a `<name>_id` token appearing on a line that marks it a
    foreign key (the token 'FK' or 'foreign' on the same line). Deduped. This avoids
    matching FK names mentioned only in prose (e.g. 'isolation via lc_id correlation')."""
    cols = set()
    for line in body.splitlines():
        if re.search(r"\b(fk|foreign)\b", line, re.IGNORECASE):
            for m in re.finditer(r"\b([a-z][a-z0-9]*(?:_[a-z0-9]+)*_id)\b", line, re.IGNORECASE):
                cols.add(m.group(1).lower())
    return cols


def column_present(body, col):
    return re.search(r"\b" + re.escape(col) + r"\b", body) is not None


def accessor_declared(body, accessor):
    # the relation method appears as `accessor(` (allow leading word-boundary, any case)
    return re.search(r"\b" + re.escape(accessor) + r"\s*\(", body, re.IGNORECASE) is not None


units = []
for p in unit_paths:
    uid, fm, text = parse_unit(p)
    units.append({"uid": uid, "fm": fm, "body": text})

# ── Group siblings by module+scope (absent => single "_all" group) ──
from collections import defaultdict
groups = defaultdict(list)
for u in units:
    key = (u["fm"].get("module", "_all"), u["fm"].get("scope", "_all"))
    groups[key].append(u)

# ── 1. Inconsistent cross-cutting concern across siblings ──
inconsistent = []
for concern in concerns:
    aw = concern["applies_when"]
    m = re.match(r"has_column\s*:\s*(.+)$", aw.strip())
    col = m.group(1).strip() if m else None
    oblig_re = re.compile(concern["spec_obligation"])
    for gkey, members in groups.items():
        # which members the concern applies to
        applicable = [u for u in members if (col and column_present(u["body"], col))]
        if len(applicable) < 1:
            continue
        satisfying = [u for u in applicable if oblig_re.search(u["body"])]
        # divergence: a member to which the concern applies but that does NOT declare
        # the obligation, while at least one sibling group-member does (true drift) OR
        # the concern applies and it simply isn't declared (uniform miss is also wrong).
        for u in applicable:
            if not oblig_re.search(u["body"]):
                inconsistent.append({
                    "unit": u["uid"],
                    "concern": concern.get("concern", "?"),
                    "module": gkey[0], "scope": gkey[1],
                    "applies_when": aw,
                    "expected": f"declare {concern['spec_obligation']} (sibling(s) {sorted(s['uid'] for s in satisfying)} do)",
                    "reason": "cross-cutting concern applies (sibling group shares it) but this unit declares a different/no mechanism — fan-out divergence",
                })

# ── 2. Missing relation accessor for declared FK columns ──
missing_relations = []
if rel_on:
    for u in units:
        for col in sorted(declared_fk_columns(u["body"])):
            accessor = camel_singular_accessor(col)
            if not accessor_declared(u["body"], accessor):
                missing_relations.append({
                    "unit": u["uid"],
                    "fk_column": col,
                    "expected_accessor": accessor + "()",
                    "reason": f"declares FK column `{col}` but no derived relation accessor `{accessor}()` — under-specified relation",
                })

status = "FAIL" if (inconsistent or missing_relations) else "PASS"
report = {
    "status": status, "validator": "sibling-consistency", "ts": ts,
    "summary": {
        "units_checked": len(units),
        "sibling_groups": len(groups),
        "concerns_loaded": len(concerns),
        "inconsistent_count": len(inconsistent),
        "missing_relations_count": len(missing_relations),
    },
    "inconsistent": inconsistent,
    "missing_relations": missing_relations,
    "next_action": (
        "Make every sibling unit sharing a cross-cutting concern declare the SAME "
        "mechanism (the concern's spec_obligation), and declare the derived relation "
        "accessor for every FK column; then re-save the unit (PostToolUse re-validates)."
    ) if status == "FAIL" else "No action — sibling concerns are consistent and FK relations are declared.",
}
write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF
exit $?
