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
# so /mega-sdd:analyze surfaces the gap. Add a stack = add the keys to its pack.
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
        "actually filtered at runtime; re-save (PostToolUse re-validates). The next "
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
