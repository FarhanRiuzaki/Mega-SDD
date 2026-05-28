#!/usr/bin/env bash
# validate-kb-flows.sh — [HOOK-VALIDATE] Mermaid-consistency for KB flow sections.
#
# Checks §3 Flow and §8 State Machine use Mermaid diagram syntax.
#
# Usage: validate-kb-flows.sh --cwd=<project> --file-path=<kb-file.md> [--quiet]
# Output: <cwd>/.mega-sdd/.kb-flows-state.json
# Exit: 0=PASS/SKIP, 1=FAIL, 2=error

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --file-path=*) FILE_PATH="${arg#--file-path=}" ;;
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
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.kb-flows-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

# Run validator as a standalone Python script to avoid heredoc backtick issues
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" <<'PYEOF'
import json, os, re, sys

cwd = sys.argv[1]
file_path = sys.argv[2]
FENCE = chr(96) * 3  # triple backtick — avoid literal in bash $() heredoc

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    sys.exit(0)

checks = []
issues = []

# §3 Flow section
sec3_match = re.search(r"^## 3\.\s", content, re.MULTILINE)
if sec3_match:
    sec3_end = re.search(r"^## [4-9]\.", content[sec3_match.end():], re.MULTILINE)
    sec3_text = content[sec3_match.start():sec3_match.end() + sec3_end.start()] if sec3_end else content[sec3_match.start():]

    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec3_text.lower()
    has_none = bool(re.search(r"_None detected|N/A", sec3_text))

    if has_mermaid:
        checks.append({"check": "sec3_flow_mermaid", "status": "PASS", "detail": "has Mermaid diagram"})
    elif has_none:
        checks.append({"check": "sec3_flow_mermaid", "status": "SKIP", "detail": "marked N/A"})
    else:
        has_ascii = bool(re.search(r"-->|->|flowchart|graph\s", sec3_text))
        if has_ascii:
            issues.append({"halt_type": "kb_flow_not_mermaid", "section": "3",
                          "detail": "flow content not in " + FENCE + "mermaid fence"})
            checks.append({"check": "sec3_flow_mermaid", "status": "FAIL",
                          "detail": "has flow arrows but not in mermaid fence"})
        else:
            issues.append({"halt_type": "kb_flow_missing", "section": "3",
                          "detail": "no diagram found"})
            checks.append({"check": "sec3_flow_mermaid", "status": "FAIL", "detail": "no flow diagram"})
else:
    checks.append({"check": "sec3_flow_mermaid", "status": "SKIP", "detail": "no section 3"})

# §8 State Machine section
sec8_match = re.search(r"^## 8\.\s", content, re.MULTILINE)
if sec8_match:
    sec8_end = re.search(r"^## 9\.", content[sec8_match.end():], re.MULTILINE)
    sec8_text = content[sec8_match.start():sec8_match.end() + sec8_end.start()] if sec8_end else content[sec8_match.start():]

    has_na = bool(re.search(r"N/A|not a workflow|_N/A", sec8_text, re.IGNORECASE))
    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec8_text.lower()
    has_transitions = bool(re.search(r"--.*-->|--.*->", sec8_text))

    if has_na:
        checks.append({"check": "sec8_state_machine", "status": "SKIP", "detail": "N/A"})
    elif has_mermaid:
        checks.append({"check": "sec8_state_machine", "status": "PASS", "detail": "has Mermaid state diagram"})
    elif has_transitions:
        checks.append({"check": "sec8_state_machine", "status": "PASS",
                       "detail": "has state transitions (consider mermaid fence for consistency)"})
    else:
        issues.append({"halt_type": "kb_state_machine_missing", "section": "8",
                       "detail": "non-N/A but no state diagram"})
        checks.append({"check": "sec8_state_machine", "status": "FAIL", "detail": "no state diagram"})
else:
    checks.append({"check": "sec8_state_machine", "status": "SKIP", "detail": "no section 8"})

has_fail = any(c["status"] == "FAIL" for c in checks)
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "summary": f"{len(issues)} flow format issues" if issues else "all flows use Mermaid or acceptable notation",
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
