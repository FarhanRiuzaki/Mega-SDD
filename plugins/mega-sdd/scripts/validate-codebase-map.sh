#!/usr/bin/env bash
# validate-codebase-map.sh — R6: codebase-map schema validation.
#
# Checks codebase-map.md has all 7 required sections and valid frontmatter.
#
# Inputs: --cwd=<project> [--quiet]
# Outputs: <cwd>/.mega-sdd/.codebase-map-state.json
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

STATE_FILE="${CWD}/.mega-sdd/.codebase-map-state.json"
MAP_PATH="${CWD}/.mega-sdd/codebase/codebase-map.md"

if [ ! -f "$MAP_PATH" ]; then
  echo '{"status":"SKIP","detail":"no codebase-map.md found"}' > "$STATE_FILE" 2>/dev/null
  [ "$QUIET" -eq 0 ] && echo '{"status":"SKIP","detail":"no codebase-map.md found"}'
  exit 0
fi

RESULT=$(MAP_PATH="$MAP_PATH" CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re

map_path = os.environ["MAP_PATH"]
cwd = os.environ["CWD"]
checks = []
issues = []

try:
    content = open(map_path).read()
except Exception as e:
    print(json.dumps({"status": "FAIL", "checks": [], "issues": [{"halt_type": "codebase_map_unreadable", "detail": str(e)}]}))
    raise SystemExit(0)

# Check 1: frontmatter present
fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
if not fm_match:
    issues.append({"halt_type": "codebase_map_no_frontmatter", "detail": "missing YAML frontmatter"})
    checks.append({"check": "frontmatter_present", "status": "FAIL"})
else:
    checks.append({"check": "frontmatter_present", "status": "PASS"})
    fm = fm_match.group(1)
    required_fm = ["generated_by", "generated_at", "repo_root", "languages_detected"]
    for field in required_fm:
        if field + ":" not in fm:
            issues.append({"halt_type": "codebase_map_fm_missing", "detail": f"frontmatter missing: {field}"})
            checks.append({"check": f"fm_{field}", "status": "FAIL"})
        else:
            checks.append({"check": f"fm_{field}", "status": "PASS"})

# Check 2: 7 required sections present
required_sections = [
    ("## 1", "Top-level structure"),
    ("## 2", "Public interfaces"),
    ("## 3", "Routes / Endpoints"),
    ("## 4", "Data models"),
    ("## 5", "Naming conventions"),
    ("## 6", "Pattern signatures"),
    ("## 7", "Framework"),
]
missing_sections = []
for prefix, name in required_sections:
    if prefix + "." not in content and prefix + " " not in content:
        missing_sections.append(f"{prefix}. {name}")

if missing_sections:
    issues.append({
        "halt_type": "codebase_map_sections_incomplete",
        "detail": f"missing {len(missing_sections)} sections: {', '.join(missing_sections[:3])}",
        "missing": missing_sections,
    })
    checks.append({"check": "sections_complete", "status": "FAIL",
                   "detail": f"missing {len(missing_sections)} of 7"})
else:
    checks.append({"check": "sections_complete", "status": "PASS",
                   "detail": "all 7 sections present"})

# Check 3: §2 has at least 1 row (non-empty public interfaces)
sec2_match = re.search(r"## 2[.\s].*?\n(.*?)(?=\n## 3|\Z)", content, re.DOTALL)
if sec2_match:
    sec2 = sec2_match.group(1)
    pipe_rows = len(re.findall(r"^\|[^|]+\|", sec2, re.MULTILINE))
    header_rows = 2  # table header + separator
    data_rows = max(0, pipe_rows - header_rows)
    if data_rows == 0:
        checks.append({"check": "interfaces_populated", "status": "WARN",
                       "detail": "§2 Public interfaces has 0 data rows"})
    else:
        checks.append({"check": "interfaces_populated", "status": "PASS",
                       "detail": f"§2 has {data_rows} interface rows"})

has_fail = any(c["status"] == "FAIL" for c in checks)
has_warn = any(c["status"] == "WARN" for c in checks)
status = "FAIL" if has_fail else ("WARN" if has_warn else "PASS")

result = {"status": status, "checked_file": os.path.relpath(map_path, cwd), "checks": checks, "issues": issues}
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
