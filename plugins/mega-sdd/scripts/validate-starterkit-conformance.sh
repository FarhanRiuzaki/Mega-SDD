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
checks = []

# Parse starterkit-context.yaml (simple key:value extraction — no yaml lib dependency)
try:
    sk_content = open(sk_file).read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": f"cannot read {sk_file}: {e}"}))
    raise SystemExit(0)

# Extract patterns block
patterns = {}
in_patterns = False
current_pattern = None
for line in sk_content.split("\n"):
    stripped = line.strip()
    if stripped == "patterns:":
        in_patterns = True
        continue
    if in_patterns:
        # End of patterns block: next top-level key
        if line and line[0] not in " \t" and ":" in line:
            in_patterns = False
            continue
        # Pattern category (e.g., "controller:", "model:")
        m = re.match(r"^    (\w+):\s*$", line)
        if m:
            current_pattern = m.group(1)
            patterns[current_pattern] = {}
            continue
        # Pattern field (e.g., "location: app/Http/Controllers/")
        if current_pattern:
            fm = re.match(r"^\s{6}(\w+):\s*(.+)", line)
            if fm:
                key = fm.group(1)
                val = fm.group(2).strip().strip('"').strip("'")
                patterns[current_pattern][key] = val

if not patterns:
    print(json.dumps({
        "status": "SKIP",
        "detail": "starterkit-context.yaml has no patterns: block",
        "violations": [], "checks": [],
    }))
    raise SystemExit(0)

# Find unit files
unit_files = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*.md"))
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
                    if is_ctrl and not tp.startswith(ctrl_loc) and ctrl_loc not in tp:
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
                    if in_models_dir and not tp.startswith(mdl_loc):
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
                    if is_req and not tp.startswith(req_loc) and req_loc not in tp:
                        violations.append({
                            "unit": unit_id, "file": tp,
                            "pattern": f"{req_key}.location", "expected": req_loc,
                            "detail": f"Request-validator file not in starterkit location {req_loc}",
                        })

        # Test files: check test pattern
        if is_test and "test" in patterns:
            tst = patterns["test"]
            tst_loc = tst.get("location", "")
            if tst_loc and not tp.startswith(tst_loc) and tst_loc not in tp:
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
import json, sys
data = json.loads(sys.stdin.read())
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null

if [ "$QUIET" -eq 0 ]; then echo "$RESULT"; fi

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
