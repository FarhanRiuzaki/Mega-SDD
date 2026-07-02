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
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, state_file)
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


def parse_accessor_form(text):
    """Pack-declared relation accessor SHAPE (TAE2E-01 fix — never hardcode the Eloquent
    paren idiom in the validator core). 'call' => `accessor(` (Laravel/ActiveRecord);
    'attribute'/'any' => the accessor name as a word (Django attribute, etc.). Default
    'any' so a stack the pack does not specialize is matched permissively, never false-FAILed."""
    m = re.search(r"accessor_form\s*:\s*([a-z]+)", text or "")
    return m.group(1).strip() if m else "any"


concerns = parse_concerns(concerns_section)
rel_on = relation_enabled(relation_section)
accessor_form = parse_accessor_form(relation_section)

if not concerns and not rel_on:
    skip("pack declares neither '## Cross-cutting concerns' nor '## Relation derivation'")

vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_root):
    skip("no_vault (.mega-sdd/vaults/ absent)")


# ── Locate units in ALL vaults (S5 GU-HOOK-5: the most-units heuristic silently
# un-gated every smaller vault); support <vault>/units and -bound. Units are
# vault-tagged so sibling groups never span vaults. ──
def find_units():
    tagged = []
    seen = set()
    for d in sorted(glob.glob(os.path.join(vault_root, "*"))):
        if not os.path.isdir(d):
            continue
        base = os.path.basename(d)
        # S5 round-2: a legacy `<vault>-bound/` sibling belongs to its base vault —
        # the base probe below absorbs its units; a standalone -bound candidate
        # double-tagged every unit (duplicated groups + inflated issue counts).
        if base.endswith("-bound") and os.path.isdir(os.path.join(vault_root, base[:-6])):
            continue
        unit_dirs = [os.path.join(d, "units"), os.path.join(vault_root, base + "-bound", "units")]
        for ud in unit_dirs:
            for u in sorted(glob.glob(os.path.join(ud, "U-*.md")) + glob.glob(os.path.join(ud, "U-*", "unit.md"))):
                rp = os.path.realpath(u)
                if rp not in seen:
                    seen.add(rp)
                    tagged.append((base, u))
    return tagged


unit_paths = find_units()
if not unit_paths:
    skip("no active vault with units/U-*.md found")

FM_RE = re.compile(r"^---\s*\n(.*?)\n---", re.DOTALL)


def parse_unit(path):
    with open(path, errors="replace") as f:
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
    """A declared FK column = a `<name>_id` token that is either (a) backticked
    (`branch_id` — a structured column reference), or (b) on a line marking it a foreign
    key (FK/foreign/column/uuid/$table->). Deduped. ADV-05 broadening: backticked columns
    count even without an 'FK' keyword, while still excluding FK names mentioned only in
    free prose (e.g. 'isolation via lc_id correlation' — not backticked, no keyword)."""
    cols = set()
    FK_ID = r"([a-z][a-z0-9]*(?:_[a-z0-9]+)*_id)"
    # (a) backticked column references anywhere
    for m in re.finditer(r"`" + FK_ID + r"`", body, re.IGNORECASE):
        cols.add(m.group(1).lower())
    # (b) FK-marked / schema-context lines
    for line in body.splitlines():
        if re.search(r"\b(fk|foreign|column)\b|uuid|\$table->", line, re.IGNORECASE):
            for m in re.finditer(r"\b" + FK_ID + r"\b", line, re.IGNORECASE):
                cols.add(m.group(1).lower())
    return cols


def column_present(body, col):
    return re.search(r"\b" + re.escape(col) + r"\b", body) is not None


def accessor_declared(body, accessor, form="any"):
    """TAE2E-01: honor the pack-declared accessor SHAPE rather than hardcoding the paren
    call. form='call' => `accessor(` (Laravel belongsTo, ActiveRecord); 'attribute'/'any'
    => the accessor name as a word (Django `branch = ForeignKey(...)`, attribute access)."""
    if form == "call":
        return re.search(r"\b" + re.escape(accessor) + r"\s*\(", body, re.IGNORECASE) is not None
    return re.search(r"\b" + re.escape(accessor) + r"\b", body, re.IGNORECASE) is not None


units = []
for vname, p in unit_paths:
    uid, fm, text = parse_unit(p)
    units.append({"vault": vname, "uid": uid, "fm": fm, "body": text})

# ── Group siblings by vault+module+scope (absent => single "_all" group per
# vault — S5: sibling groups never span vaults) ──
from collections import defaultdict
groups = defaultdict(list)
for u in units:
    key = (u["vault"], u["fm"].get("module", "_all"), u["fm"].get("scope", "_all"))
    groups[key].append(u)

# ── applies_when operators (Iter-79 N-1) ──
# Two pack-declared forms, both per-unit predicates:
#   has_column:<col>     — unit body references the FK/column (static declaration).
#   flow_step:<regex>    — unit body cites a flow step matching the regex (a SHARED
#                          runtime side-effect obligation, e.g. the maker-checker
#                          inbox-surfacing write). Lets a pack require that every
#                          sibling whose flow includes step X declares the same
#                          implementation obligation — closes the af49ede inbox-parity
#                          gap (a side-effect, not a column-concern). Stack-agnostic:
#                          when no unit cites the step, the concern is inert.
def concern_predicate(aw):
    aw = (aw or "").strip()
    mc = re.match(r"has_column\s*:\s*(.+)$", aw)
    if mc:
        col = mc.group(1).strip()
        return lambda u: column_present(u["body"], col)
    mf = re.match(r"flow_step\s*:\s*(.+)$", aw)
    if mf:
        try:
            fr = re.compile(mf.group(1).strip(), re.IGNORECASE)
        except re.error:
            return lambda u: False
        return lambda u: bool(fr.search(u["body"]))
    return lambda u: False


# ── 1. Inconsistent cross-cutting concern across siblings ──
inconsistent = []
for concern in concerns:
    aw = concern["applies_when"]
    applies = concern_predicate(aw)
    oblig_re = re.compile(concern["spec_obligation"])
    for gkey, members in groups.items():
        # which members the concern applies to
        applicable = [u for u in members if applies(u)]
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
                    "vault": gkey[0], "module": gkey[1], "scope": gkey[2],
                    "applies_when": aw,
                    "expected": f"declare {concern['spec_obligation']} (sibling(s) {sorted(s['uid'] for s in satisfying)} do)",
                    "reason": "cross-cutting concern applies (sibling group shares it) but this unit declares a different/no mechanism — fan-out divergence",
                })

# ── 2. Relation accessor divergence ACROSS SIBLINGS (FPP-4 + TAE2E-01 fix) ──
# Not an absolute "every FK must spell its accessor" rule (that false-positived solo +
# convention-derived units and hardcoded the Eloquent paren shape). Instead: within a
# sibling group, for each FK column, flag a unit ONLY when a SIBLING declares the relation
# accessor and this unit does not — a genuine fan-out divergence. Uniform groups (all
# declare, or all rely on ORM convention) are consistent and never flagged; a solo unit has
# no sibling to diverge from. Accessor SHAPE is pack-declared (accessor_form), so a
# non-Laravel stack is never false-FAILed for not using the paren-call idiom.
missing_relations = []
if rel_on:
    for gkey, members in groups.items():
        col_units = defaultdict(list)
        for u in members:
            for col in declared_fk_columns(u["body"]):
                col_units[col].append(u)
        for col, us in col_units.items():
            accessor = camel_singular_accessor(col)
            declarers = [u for u in us if accessor_declared(u["body"], accessor, accessor_form)]
            non_declarers = [u for u in us if not accessor_declared(u["body"], accessor, accessor_form)]
            if declarers and non_declarers:   # divergence only
                for u in non_declarers:
                    missing_relations.append({
                        "unit": u["uid"],
                        "fk_column": col,
                        "vault": gkey[0], "module": gkey[1], "scope": gkey[2],
                        "expected_accessor": accessor,
                        "reason": f"sibling(s) {sorted(d['uid'] for d in declarers)} declare the `{accessor}` relation for FK `{col}` but this unit does not — fan-out divergence (relation under-specified relative to siblings)",
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
