#!/usr/bin/env bash
# validate-starterkit-conformance.sh — [HOOK-VALIDATE] starterkit pattern conformance.
#
# Checks that generated unit target_files conform to starterkit patterns
# extracted in starterkit-context.yaml §patterns. Structural checks:
# - File location matches pattern location (e.g., controllers in app/Http/Controllers/)
# - File naming matches pattern naming (e.g., {Model}Controller.php)
#
# Walking-skeleton: controller pattern only. Expand to model/request/service later.
#
# Usage: validate-starterkit-conformance.sh --cwd=<project> [--quiet]
# Output: <cwd>/.mega-sdd/.starterkit-conformance-state.json
# Exit: 0=PASS/SKIP, 1=FAIL, 2=error

set -uo pipefail

CWD=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --quiet) QUIET=1 ;;
  esac
done
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi


if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.starterkit-conformance-state.json"
SK_FILE="${CWD}/.mega-sdd/codebase/starterkit-context.yaml"

if [ ! -f "$SK_FILE" ]; then
  echo '{"status":"SKIP","detail":"no starterkit-context.yaml"}' > "$STATE_FILE" 2>/dev/null
  [ "$QUIET" -eq 0 ] && echo '{"status":"SKIP","detail":"no starterkit-context.yaml"}'
  exit 0
fi

RESULT=$(CWD="$CWD" SK_FILE="$SK_FILE" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
sk_file = os.environ["SK_FILE"]

violations = []
skipped_locations = {}  # pattern -> prose location skipped by the F3 guard
checks = []

# Parse starterkit-context.yaml (simple key:value extraction — no yaml lib dependency)
try:
    sk_content = open(sk_file).read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": f"cannot read {sk_file}: {e}"}))
    raise SystemExit(0)

# Extract patterns block. S5 GU-SKC-INDENT: the parser was locked to EXACTLY
# 4-space categories / 6-space fields under a 2-space-indented `patterns:` — any
# other valid-YAML indentation (the schema doc example itself uses patterns: at
# col 0) parsed to ZERO patterns and silently SKIPped every conformance check.
# Now indentation-RELATIVE: `patterns:` at any indent; categories = first deeper
# indent level; fields = deeper than the category. And "patterns:" present but
# zero parsed => ERROR (fail-loud), never a silent SKIP.
# Round-2 (S5R-1/S5R-5): the parser locked onto the FIRST patterns:-shaped line
# anywhere in the file — a nested `patterns:` sub-key in an earlier slice
# shadowed the canonical block. Now EVERY patterns: line is a candidate; the
# first candidate that yields >=1 category with fields wins. Fields lock to the
# FIRST field indent (deeper sub-blocks like extras: children no longer clobber
# the category's real location/naming).
lines = sk_content.split("\n")
cand_idx = [i for i, ln in enumerate(lines) if re.match(r"^[ \t]*patterns:\s*$", ln)]
saw_patterns_key = bool(cand_idx)
patterns = {}
for ci in cand_idx:
    trial = {}
    pat_indent = len(lines[ci]) - len(lines[ci].lstrip(" \t"))
    cat_indent = None
    field_indent = None
    current_pattern = None
    for line in lines[ci + 1:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        if indent <= pat_indent:
            break  # end of the patterns block (sibling/parent key)
        m = re.match(r"^[ \t]*(\w+):\s*$", line)
        if m and (cat_indent is None or indent == cat_indent):
            cat_indent = indent if cat_indent is None else cat_indent
            current_pattern = m.group(1)
            trial[current_pattern] = {}
            field_indent = None
            continue
        fm = re.match(r"^[ \t]*(\w+):\s*(.+)$", line)
        if fm and current_pattern and cat_indent is not None and indent > cat_indent:
            if field_indent is None:
                field_indent = indent
            if indent != field_indent:
                continue  # deeper sub-block (extras: children) — never a category field
            key = fm.group(1)
            val = fm.group(2).strip().strip('"').strip("'")
            trial[current_pattern][key] = val
    if any(v for v in trial.values()):
        patterns = trial
        break

if not patterns:
    if saw_patterns_key:
        # fail-loud: the block exists but nothing parsed — writer drift must be
        # visible on the analyze surface, not silently disable conformance.
        print(json.dumps({
            "status": "ERROR",
            "detail": "starterkit-context.yaml HAS a patterns: block but zero patterns parsed — indentation/shape drift; conformance checks cannot run",
            "violations": [], "checks": [],
        }))
        raise SystemExit(0)
    print(json.dumps({
        "status": "SKIP",
        "detail": "starterkit-context.yaml has no patterns: block",
        "violations": [], "checks": [],
    }))
    raise SystemExit(0)

# Find unit files (widened *-bound → * — canonical <vault>/units AND legacy <vault>-bound/units;
# also handle the U-*/unit.md sub-layout).
unit_files = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "units", "U-*", "unit.md"))
)
if not unit_files:
    print(json.dumps({
        "status": "SKIP",
        "detail": "no unit files found",
        "violations": [], "checks": [],
    }))
    raise SystemExit(0)

# Extract target_files from each unit's frontmatter
for uf in unit_files:
    if "/.archived/" in uf:
        continue
    try:
        content = open(uf).read()
    except Exception:
        continue

    # Parse frontmatter
    fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not fm_match:
        continue

    fm = fm_match.group(1)
    unit_id_m = re.search(r"^(?:id|unit_id):\s*(\S+)", fm, re.MULTILINE)
    unit_id = unit_id_m.group(1) if unit_id_m else os.path.basename(uf).replace(".md", "")

    # Extract target_files paths
    in_tf = False
    target_paths = []
    for fline in fm.split("\n"):
        if fline.strip().startswith("target_files:"):
            in_tf = True
            continue
        if in_tf:
            if fline and fline[0] not in " \t":
                break
            pm = re.search(r"path:\s*(.+)", fline)
            if pm:
                target_paths.append(pm.group(1).strip().strip('"').strip("'"))

    # Check each target path against patterns
    # Strategy: classify file by its DIRECTORY (not substring match) to avoid
    # false positives like "tests/models/user.test.ts" matching model pattern.
    #
    # 6.0.1 F3 (field-test hardening spec): a pack `location` may carry PROSE
    # ("colocated — a module with a test lives ...") or a multi-root
    # alternation ("apps/web/... (Next proxy) | apps/api/... (NestJS)").
    # startswith(prose) can never match, so EVERY file used to be flagged —
    # including files that satisfy the convention. A location participates in
    # the path check ONLY when it is path-shaped (no spaces / em-dash); `|`
    # alternations split and pass on ANY matching root. Non-path-shaped →
    # SKIP with an honest note, never a violation, never silent.
    def _path_shaped(v):
        return bool(v) and not re.search(r"[ —|]", v)

    def _loc_ok(tp, loc, pattern_name, substr=True):
        """True = conforms OR check inapplicable (prose location -> skip+note).
        substr=False keeps a check startswith-only (round fold: the shared
        helper silently ADDED substring tolerance to the data_model check,
        flipping a previously-correct violation — each site keeps its
        pre-guard matching semantics)."""
        alts = [a.strip() for a in loc.split("|")] if "|" in loc else [loc]
        if not alts or not all(_path_shaped(a) for a in alts):
            skipped_locations.setdefault(pattern_name, loc)
            return True
        if substr:
            return any(tp.startswith(a) or a in tp for a in alts)
        return any(tp.startswith(a) for a in alts)

    for tp in target_paths:
        tp_dir = os.path.dirname(tp) + "/"
        tp_base = os.path.basename(tp)
        is_test = "/test" in tp.lower() or tp_base.endswith(".test.ts") or tp_base.endswith("Test.php")

        # Skip test files for non-test pattern checks (test files have their own pattern)
        if not is_test:
            # Controller: file is in a controller-like dir AND name suggests controller
            # (semantic role universal across frameworks; pack provides the location value)
            if "controller" in patterns:
                ctrl = patterns["controller"]
                ctrl_loc = ctrl.get("location", "")
                # null location → category absent in this framework → skip checks
                if ctrl_loc and ctrl_loc != "null":
                    is_ctrl = ("controller" in tp_dir.lower() or "handler" in tp_dir.lower()
                               or "Controller" in tp_base or "controller" in tp_base.lower())
                    if is_ctrl and not _loc_ok(tp, ctrl_loc, "controller.location"):
                        violations.append({
                            "unit": unit_id, "file": tp,
                            "pattern": "controller.location", "expected": ctrl_loc,
                            "detail": f"Controller/handler file not in starterkit location {ctrl_loc}",
                        })

            # Data model: file is directly in model/entity dir
            # (generic name "data_model"; legacy alias "model" supported for v2.x consumers)
            mdl_key = "data_model" if "data_model" in patterns else ("model" if "model" in patterns else None)
            if mdl_key:
                mdl = patterns[mdl_key]
                mdl_loc = mdl.get("location", "")
                if mdl_loc and mdl_loc != "null":
                    # Only flag if the file IS in a models/entities dir but the WRONG one
                    in_models_dir = (tp_dir.rstrip("/").endswith("/models")
                                     or tp_dir.rstrip("/").endswith("/entities"))
                    if in_models_dir and not _loc_ok(tp, mdl_loc, f"{mdl_key}.location", substr=False):
                        violations.append({
                            "unit": unit_id, "file": tp,
                            "pattern": f"{mdl_key}.location", "expected": mdl_loc,
                            "detail": f"Data-model file not in starterkit location {mdl_loc}",
                        })

            # Request validator: file is in validator/request dir
            # (generic name "request_validator"; legacy alias "request" supported for v2.x consumers)
            req_key = "request_validator" if "request_validator" in patterns else ("request" if "request" in patterns else None)
            if req_key:
                req = patterns[req_key]
                req_loc = req.get("location", "")
                if req_loc and req_loc != "null":
                    is_req = ("request" in tp_dir.lower() or "validator" in tp_dir.lower()
                              or "schema" in tp_dir.lower()
                              or "Request" in tp_base or "Validator" in tp_base
                              or ".schema." in tp_base)
                    if is_req and not _loc_ok(tp, req_loc, f"{req_key}.location"):
                        violations.append({
                            "unit": unit_id, "file": tp,
                            "pattern": f"{req_key}.location", "expected": req_loc,
                            "detail": f"Request-validator file not in starterkit location {req_loc}",
                        })

        # Test files: check test pattern
        if is_test and "test" in patterns:
            tst = patterns["test"]
            tst_loc = tst.get("location", "")
            if tst_loc and tst_loc != "null" and not _loc_ok(tp, tst_loc, "test.location"):
                violations.append({
                    "unit": unit_id, "file": tp,
                    "pattern": "test.location", "expected": tst_loc,
                    "detail": f"Test file not in starterkit location {tst_loc}",
                })

checks.append({
    "check": "target_files_vs_patterns",
    "units_checked": len(unit_files),
    "target_files_checked": sum(1 for _ in unit_files),
    "violations": len(violations),
})

status = "FAIL" if violations else "PASS"
result = {
    "status": status,
    "patterns_loaded": list(patterns.keys()),
    "units_checked": len(unit_files),
    "violations_count": len(violations),
    "violations": violations[:10],
    "location_checks_skipped": skipped_locations,
    "checks": checks,
    "summary": (
        f"{len(violations)} conformance violations across {len(unit_files)} units"
        if violations else
        f"all target_files conform to starterkit patterns ({len(patterns)} patterns checked)"
    ),
}
print(json.dumps(result))
PYEOF
)

echo "$RESULT" | python3 -c "
import json, os, sys
data = json.loads(sys.stdin.read())
_tmp = '$STATE_FILE' + '.tmp.%d' % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace)
with open(_tmp, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(_tmp, '$STATE_FILE')
" 2>/dev/null

if [ "$QUIET" -eq 0 ]; then echo "$RESULT"; fi

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  ERROR) exit 2 ;;
  *) exit 2 ;;
esac
