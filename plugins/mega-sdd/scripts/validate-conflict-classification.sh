#!/usr/bin/env bash
# validate-conflict-classification.sh — R3: conflict classification enrichment validator.
#
# Scans binding docs for CONFLICT YAML blocks. Checks whether each has
# conflict_class and resolution_complexity fields (R3 enrichment).
# Missing fields → WARN (backward-compatible, not FAIL).
#
# Inputs: --cwd=<project> [--quiet]
# Outputs: <cwd>/.mega-sdd/.conflict-classification-state.json
# Exit: 0=PASS/WARN, 1=FAIL (structural parse error), 2=error

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

STATE_FILE="${CWD}/.mega-sdd/.conflict-classification-state.json"

RESULT=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
issues = []
conflicts_total = 0
conflicts_classified = 0
conflicts_unclassified = 0

binding_files = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "binding.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "binding*.md"))
)

for bf in binding_files:
    if "/.archived/" in bf:
        continue
    try:
        content = open(bf).read()
    except Exception:
        continue

    # Find CONFLICT YAML blocks: ```yaml ... binding_conflict: ... ```
    yaml_blocks = re.findall(
        r"```yaml\s*\n(.*?)```",
        content, re.DOTALL
    )

    for block in yaml_blocks:
        if "binding_conflict:" not in block and "id: CONFLICT-" not in block:
            continue

        conflicts_total += 1
        conflict_id_m = re.search(r"id:\s*(CONFLICT-\d+)", block)
        conflict_id = conflict_id_m.group(1) if conflict_id_m else f"CONFLICT-?-{conflicts_total}"

        has_class = bool(re.search(r"^\s*conflict_class:\s*\S", block, re.MULTILINE))
        has_complexity = bool(re.search(r"^\s*resolution_complexity:\s*\S", block, re.MULTILINE))

        if has_class and has_complexity:
            conflicts_classified += 1
        else:
            conflicts_unclassified += 1
            missing = []
            if not has_class:
                missing.append("conflict_class")
            if not has_complexity:
                missing.append("resolution_complexity")
            issues.append({
                "halt_type": "conflict_classification_missing",
                "conflict_id": conflict_id,
                "binding_file": os.path.relpath(bf, cwd),
                "missing_fields": missing,
                "detail": f"{conflict_id} in {os.path.basename(bf)}: missing {', '.join(missing)}",
            })

if conflicts_total == 0:
    status = "SKIP"
    detail = "no CONFLICT YAML blocks found in any binding doc"
elif conflicts_unclassified > 0:
    status = "WARN"
    detail = f"{conflicts_classified}/{conflicts_total} classified; {conflicts_unclassified} missing conflict_class/resolution_complexity"
else:
    status = "PASS"
    detail = f"all {conflicts_total} CONFLICTs have conflict_class + resolution_complexity"

result = {
    "status": status,
    "conflicts_total": conflicts_total,
    "conflicts_classified": conflicts_classified,
    "conflicts_unclassified": conflicts_unclassified,
    "issues": issues,
    "summary": detail,
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
  PASS|SKIP|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
