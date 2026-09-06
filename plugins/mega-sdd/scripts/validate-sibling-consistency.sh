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

# ─── v7 Fase 2 merge group 9: this file also hosts its two pack-driven ────────
# siblings as modes (each folded VERBATIM; own state file, own exit semantics):
#   --cross-cutting  → the cross-cutting registration gate
#                      (.cross-cutting-state.json; BLOCKING via the aggregator)
#   --fanout-parity  → the fan-out parity check
#                      (.fanout-parity-state.json; ADVISORY, analyze-surfaced)
# No flag = the sibling-consistency gate below, byte-for-byte as before.
_SC_MODE=""
_SC_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --cross-cutting) _SC_MODE="cross-cutting" ;;
    --fanout-parity) _SC_MODE="fanout-parity" ;;
    *) _SC_ARGS+=("$arg") ;;
  esac
done
if [ "${#_SC_ARGS[@]}" -gt 0 ]; then set -- "${_SC_ARGS[@]}"; else set --; fi

if [ "$_SC_MODE" = "cross-cutting" ]; then
# ═══ mode: cross-cutting registration (merged validate-cross-cutting-registration.sh) ═══

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
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, state_file)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP", "validator": "cross-cutting-registration", "ts": ts, "reason": reason,
        "missing_registration": [], "summary": f"SKIP — {reason}",
        "next_action": "No action — this check does not apply to the current project/pack.",
    }, 0)


def yaml_blocks(t):
    """S6 EB-VAL-10: the resolver emits ONE `# --- from <pack>.md ---` block PER
    pack in the extends chain (most-specific first). Taking only the FIRST yaml
    fence silently dropped every base-pack concern the moment a project pack
    declared the section. Union ALL fences; the sibling ui-quality parser was
    already hardened the same way."""
    blocks = re.findall(r"```ya?ml\s*\n(.*?)```", t, re.DOTALL)
    return blocks if blocks else [t]


def parse_concerns_block(body):
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
        k = m.group(1)
        raw = m.group(2)
        # For path/glob keys, strip a trailing inline `# comment` BEFORE unquoting so an inline
        # doc comment on the value never becomes part of the glob (these keys never contain '#').
        if k in ("registration_target_glob", "registration_source_glob", "registration_exempt_glob",
                 "applies_when", "concern"):
            raw = re.sub(r"\s+#.*$", "", raw)
        v = raw.strip().strip('"').strip("'")
        if k in ("concern", "applies_when", "spec_obligation",
                 "registration_signature", "registration_target_glob", "registration_source_glob",
                 "registration_exempt_glob", "source_decl_regex", "target_decl_regex"):
            cur[k] = v
    flush()
    return out


def parse_concerns(text):
    if not text.strip():
        return []
    merged, seen = [], set()
    for body in yaml_blocks(text):
        for c in parse_concerns_block(body):
            key = c.get("concern") or c.get("registration_signature")
            if key in seen:
                continue  # dedup by concern id — first occurrence (most-specific pack) wins
            seen.add(key)
            merged.append(c)
    return merged


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


# S6 EB-VAL-4: the container-discovery signatures are PACK-DECLARED, never
# hardcoded — the old module-level `Schema::(create|table)` / `$table =` regexes
# were Laravel-only under a header claiming "hardcodes NO stack signature", so
# every non-Laravel pack with a has_column concern structurally false-PASSed
# (0 files scanned → "every model registers the concern"). Each concern now
# carries:
#   source_decl_regex — capture group 1 = the container (table) name declared
#                       alongside the applies_when column in a source file
#   target_decl_regex — capture group 1 = the container a target (model) binds to
# A has_column concern missing either key is NOT silently passed: it is
# recorded `not_evaluable` and the overall status degrades to SKIP (never PASS)
# so analyze surfaces the gap. Add a stack = add the keys to its pack.
CLASS_RE = re.compile(r"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)")


def read(path):
    try:
        with open(path, errors="replace") as f:
            return f.read()
    except Exception:
        return ""


def strip_comments(src):
    """ADV-06: remove // line, # line, and /* block */ comments before checking the
    registration signature, so a COMMENTED-OUT registration (e.g. `// addGlobalScope(new
    BranchScoped)`) does NOT satisfy the check and let a real leak pass. Conservative: only
    affects the registration scan; string-literal edge cases are acceptable here (a comment
    masking a real omission is the dangerous direction we must close)."""
    src = re.sub(r"/\*.*?\*/", " ", src, flags=re.DOTALL)
    out = []
    for line in src.splitlines():
        line = re.sub(r"//.*$", "", line)
        line = re.sub(r"(^|\s)#.*$", r"\1", line)
        out.append(line)
    return "\n".join(out)


missing_registration = []
not_evaluable = []
models_scanned = 0
concerns_evaluated = 0
for c in concerns:
    col_m = re.match(r"has_column\s*:\s*(.+)$", c.get("applies_when", "").strip())
    column = col_m.group(1).strip() if col_m else None
    if not column:
        continue
    src_decl = c.get("source_decl_regex")
    tgt_decl = c.get("target_decl_regex")
    if not src_decl or not tgt_decl:
        not_evaluable.append({"concern": c.get("concern", "?"),
                              "reason": "pack declares no source_decl_regex/target_decl_regex — "
                                        "the has_column container discovery cannot run on this stack"})
        continue
    try:
        reg_re = re.compile(c["registration_signature"])
        table_decl_re = re.compile(src_decl)
        model_table_re = re.compile(tgt_decl)
    except re.error as e:
        not_evaluable.append({"concern": c.get("concern", "?"),
                              "reason": "invalid regex in pack concern declaration: %s" % e})
        continue
    col_re = re.compile(r"\b" + re.escape(column) + r"\b")

    # FPP-3: pack-declared exemptions — models that carry the column but must NOT register
    # the concern (the SCOPE SOURCE, e.g. the auth User whose branch_id DRIVES scoping onto
    # others; self-scoping it would break auth). A pack lists them via registration_exempt_glob.
    exempt = set()
    ex_glob = c.get("registration_exempt_glob")
    if ex_glob:
        for eg in re.split(r"\s*,\s*", ex_glob):
            if eg:
                exempt |= {os.path.realpath(p) for p in glob.glob(os.path.join(cwd, eg), recursive=True)}

    # 1. Branch-scoped TABLES: tables a migration gives the column (exact names + token-sets).
    scoped_tables = set()
    scoped_tablesets = []
    src_files = [p for p in sorted(glob.glob(os.path.join(cwd, c["registration_source_glob"]), recursive=True))
                 if os.path.isfile(p)]
    if not src_files:
        # S6 EB-VAL-4: an empty source glob is a DISCOVERY failure, not a clean
        # bill — the old `continue` positively attested with zero files scanned.
        not_evaluable.append({"concern": c.get("concern", "?"),
                              "reason": "registration_source_glob '%s' matched no file — cannot "
                                        "discover %s containers" % (c["registration_source_glob"], column)})
        continue
    for src in src_files:
        content = read(src)
        if not col_re.search(content):
            continue
        for t in table_decl_re.findall(content):
            scoped_tables.add(t)
            scoped_tablesets.append(tokenize(t))
    if not scoped_tables:
        # Sources exist and were scanned; none declares the column → the concern
        # genuinely does not apply to this project (inert, per pack design).
        concerns_evaluated += 1
        continue

    # 2. Each model: branch-scoped iff its declared container is in the set (exact) or (no
    #    declaration) its class tokens overlap a scoped table's tokens. Scoped + no registration => miss.
    tgt_files = [p for p in sorted(glob.glob(os.path.join(cwd, c["registration_target_glob"]), recursive=True))
                 if os.path.isfile(p)]
    if not tgt_files:
        not_evaluable.append({"concern": c.get("concern", "?"),
                              "reason": "registration_target_glob '%s' matched no file while %d "
                                        "container(s) carry %s — the registration scan cannot run"
                                        % (c["registration_target_glob"], len(scoped_tables), column)})
        continue
    concerns_evaluated += 1
    for mp in tgt_files:
        if os.path.realpath(mp) in exempt:   # FPP-3: scope-source / pack-exempt model
            continue
        content = read(mp)
        models_scanned += 1
        tbl_m = model_table_re.search(content)
        is_scoped = False
        if tbl_m:
            is_scoped = tbl_m.group(1) in scoped_tables
        else:
            cls = CLASS_RE.search(content)
            ctoks = tokenize(cls.group(1)) if cls else set()
            is_scoped = any(ctoks & ts for ts in scoped_tablesets) if ctoks else False
        if not is_scoped:
            continue
        if not reg_re.search(strip_comments(content)):   # ADV-06: ignore commented-out registration
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

# S6 EB-VAL-4: PASS requires at least one concern actually EVALUATED. Concerns
# the stack cannot evaluate degrade to SKIP with per-concern detail — a positive
# "every model registers the concern" over zero scanned files is exactly the
# silent-leak class this gate exists to catch.
if missing_registration:
    status = "FAIL"
elif concerns_evaluated and not not_evaluable:
    status = "PASS"      # PASS only when EVERY declared concern was actually evaluated
else:
    status = "SKIP"      # any not_evaluable concern (or zero evaluated) → SKIP, never a
                         # clean PASS that hides an unchecked concern (S6 EB-VAL-4 honesty)
report = {
    "status": status, "validator": "cross-cutting-registration", "ts": ts,
    "summary": {
        "concerns_with_registration": len(concerns),
        "concerns_evaluated": concerns_evaluated,
        "concerns_not_evaluable": len(not_evaluable),
        "model_files_scanned": models_scanned,
        "missing_registration_count": len(missing_registration),
    },
    "missing_registration": missing_registration,
    "not_evaluable": not_evaluable,
    "next_action": (
        "In each flagged model, register the cross-cutting concern (e.g. add "
        "`static::addGlobalScope(new BranchScoped)` to booted()) so the branch-scoped table is "
        "actually filtered at runtime; re-run analyze or the execute-bolts gate (they re-derive). The next "
        "mega-sdd:execute-bolts is blocked until the registrations land."
    ) if status == "FAIL" else (
        "No action — every branch-scoped model registers the concern."
        if status == "PASS" else
        "SKIP — one or more declared concerns are not evaluable on this stack (see "
        "not_evaluable); a clean PASS is withheld until every concern can be checked. Add "
        "source_decl_regex + target_decl_regex to the pack's cross_cutting_concerns entries "
        "to enable the runtime registration scan."
    ),
}
write_and_exit(report, 0 if status != "FAIL" else 1)
PYEOF
exit $?
exit $?
fi

if [ "$_SC_MODE" = "fanout-parity" ]; then
# ═══ mode: fan-out parity (merged validate-fanout-parity.sh) ═══

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
    _tmp = state_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, state_file)
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
        "under-served unit(s), then re-run analyze / the execute-bolts gate (they re-derive)."
        if divergences else "No action — sibling deliverable obligations are at parity."
    ),
}
write_and_exit(report, 1 if status == "FAIL" else 0)
PYEOF
exit $?
fi


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
        "accessor for every FK column; then re-run analyze / the execute-bolts gate (they re-derive)."
    ) if status == "FAIL" else "No action — sibling concerns are consistent and FK relations are declared.",
}
write_and_exit(report, 0 if status == "PASS" else 1)
PYEOF
exit $?
