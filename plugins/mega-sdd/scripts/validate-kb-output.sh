#!/usr/bin/env bash
# validate-kb-output.sh — R2: knowledge-base output validation [HOOK-VALIDATE].
#
# Validates KB domain files against knowledge-base-schema.md contract:
#   1. frontmatter_present     — YAML frontmatter exists
#   2. verified_count_match    — frontmatter verified_count == body [VERIFIED] count
#   3. inferred_count_match    — frontmatter inferred_count == body [INFERRED] count
#   4. open_count_match        — frontmatter open_count == body [OPEN] count
#   5. locked_count_match      — frontmatter locked_count == body [LOCKED] count
#   6. eleven_sections_present — all 11 required section headers (§1-§11)
#   7. depends_on_valid        — depends_on entries resolve to sibling KB files
#
# Inputs: --cwd=<project> --file-path=<kb-domain-file.md> [--quiet]
# Outputs: JSON stdout; writes <cwd>/.mega-sdd/.kb-output-state.json
# Exit: 0=PASS, 1=FAIL, 2=error.

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
if [ -z "$FILE_PATH" ]; then
  echo '{"status":"ERROR","detail":"--file-path required"}' >&2
  exit 2
fi
if [ ! -f "$FILE_PATH" ]; then
  echo '{"status":"ERROR","detail":"file not found: '"$FILE_PATH"'"}' >&2
  exit 2
fi

STATE_FILE="${CWD}/.mega-sdd/.kb-output-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

RESULT=$(CWD="$CWD" FILE_PATH="$FILE_PATH" python3 <<'PYEOF'
import json
import os
import re
import sys
import glob

file_path = os.environ["FILE_PATH"]
cwd = os.environ["CWD"]

issues = []
checks = []

try:
    with open(file_path, encoding="utf-8") as f:
        content = f.read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": f"cannot read file: {e}", "issues": [], "checks": []}))
    sys.exit(0)

# --- Check 1: frontmatter_present ---
fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
if not fm_match:
    issues.append({"halt_type": "kb_frontmatter_missing", "detail": "no YAML frontmatter (--- delimited) found"})
    checks.append({"check": "frontmatter_present", "status": "FAIL"})
    # Can't do further checks without frontmatter
    result = {
        "status": "FAIL",
        "checked_file": os.path.relpath(file_path, cwd),
        "issues": issues,
        "checks": checks,
    }
    print(json.dumps(result))
    sys.exit(0)
else:
    checks.append({"check": "frontmatter_present", "status": "PASS"})

fm_text = fm_match.group(1)
body = content[fm_match.end():]

# Parse frontmatter key-value pairs (simple YAML — no nested structures)
fm = {}
for line in fm_text.split("\n"):
    m = re.match(r"^(\w[\w_]*):\s*(.+)", line)
    if m:
        key = m.group(1)
        val = m.group(2).strip()
        # Try to parse as int
        try:
            fm[key] = int(val)
        except ValueError:
            fm[key] = val

# --- Checks 2-5: confidence marker count consistency ---
marker_checks = [
    ("verified_count", "[VERIFIED]"),
    ("inferred_count", "[INFERRED]"),
    ("open_count", "[OPEN]"),
    ("locked_count", "[LOCKED]"),
]

for fm_field, marker in marker_checks:
    if fm_field not in fm:
        # Field absent — not a fail for optional fields (locked_count is v1.4+)
        if fm_field in ("locked_count",):
            checks.append({"check": f"{fm_field}_match", "status": "SKIP",
                          "detail": f"frontmatter field '{fm_field}' absent (v1.4+ field, may be pre-v1.4 KB)"})
        else:
            issues.append({"halt_type": "kb_frontmatter_field_missing",
                          "detail": f"required frontmatter field '{fm_field}' absent"})
            checks.append({"check": f"{fm_field}_match", "status": "FAIL"})
        continue

    expected = fm[fm_field]
    if not isinstance(expected, int):
        issues.append({"halt_type": "kb_frontmatter_field_invalid",
                       "detail": f"frontmatter '{fm_field}' is not an integer: {expected}"})
        checks.append({"check": f"{fm_field}_match", "status": "FAIL"})
        continue

    # Count occurrences in body (escaped bracket match)
    escaped_marker = re.escape(marker)
    actual = len(re.findall(escaped_marker, body))

    if actual != expected:
        issues.append({
            "halt_type": "kb_marker_count_mismatch",
            "detail": f"frontmatter {fm_field}={expected} but body has {actual} '{marker}' occurrences (delta={actual - expected})",
            "field": fm_field,
            "expected": expected,
            "actual": actual,
        })
        checks.append({"check": f"{fm_field}_match", "status": "FAIL",
                       "detail": f"fm={expected}, body={actual}"})
    else:
        checks.append({"check": f"{fm_field}_match", "status": "PASS",
                       "detail": f"fm={expected}, body={actual}"})

# --- Check 6: eleven_sections_present ---
required_sections = [
    "## 1. Purpose",
    "## 2. Actors",
    "## 3. Flow",
    "## 4. Entities",
    "## 5. Fields & Validation",
    "## 6. Business Rules",
    "## 7. Integrations",
    "## 8. Edge Cases",
    "## 9. Rebuild Recommendations",
    "## 10. Open Questions",
    "## 11. Source Files",
]

missing_sections = []
for sec in required_sections:
    # Flexible match: section header may have slightly different wording
    sec_num = sec.split(".")[0] + "."  # e.g., "## 1."
    if sec_num not in content:
        missing_sections.append(sec)

if missing_sections:
    issues.append({
        "halt_type": "kb_sections_incomplete",
        "detail": f"missing {len(missing_sections)} of 11 required sections: {', '.join(missing_sections[:3])}{'...' if len(missing_sections) > 3 else ''}",
        "missing_sections": missing_sections,
    })
    checks.append({"check": "eleven_sections_present", "status": "FAIL",
                   "detail": f"missing {len(missing_sections)} sections"})
else:
    checks.append({"check": "eleven_sections_present", "status": "PASS",
                   "detail": "all 11 sections present"})

# --- Check 7: depends_on_valid ---
depends_on_raw = fm.get("depends_on", "[]")
if isinstance(depends_on_raw, str):
    # Parse YAML list: [a, b, c] or empty []
    depends_on_raw = depends_on_raw.strip("[] ")
    depends_on = [d.strip().strip("'\"") for d in depends_on_raw.split(",") if d.strip()] if depends_on_raw else []
elif isinstance(depends_on_raw, list):
    depends_on = depends_on_raw
else:
    depends_on = []

if depends_on:
    kb_dir = os.path.dirname(file_path)
    # deps might be domain IDs (e.g., "customer-master") or filenames
    existing_files = {os.path.basename(f).replace(".md", ""): f
                      for f in glob.glob(os.path.join(kb_dir, "*.md"))}
    existing_domains = set()
    for fn, fp in existing_files.items():
        # Extract domain from frontmatter if possible
        try:
            fc = open(fp).read(500)
            dm = re.search(r"^domain:\s*(\S+)", fc, re.MULTILINE)
            if dm:
                existing_domains.add(dm.group(1))
        except Exception:
            pass
        # Also accept filename-based match (strip numeric prefix)
        existing_domains.add(re.sub(r"^\d+-", "", fn))

    invalid_deps = [d for d in depends_on if d not in existing_domains and d not in existing_files]
    if invalid_deps:
        issues.append({
            "halt_type": "kb_depends_on_invalid",
            "detail": f"depends_on references {len(invalid_deps)} non-existent domain(s): {', '.join(invalid_deps)}",
        })
        checks.append({"check": "depends_on_valid", "status": "FAIL",
                       "detail": f"{len(invalid_deps)} invalid refs"})
    else:
        checks.append({"check": "depends_on_valid", "status": "PASS",
                       "detail": f"{len(depends_on)} deps, all resolved"})
else:
    checks.append({"check": "depends_on_valid", "status": "PASS",
                   "detail": "no dependencies declared"})

# --- Result ---
has_fail = any(c["status"] == "FAIL" for c in checks)
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "issues": issues,
    "checks": checks,
}

print(json.dumps(result))
PYEOF
)

# Write state file
echo "$RESULT" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print(data.get('status', 'ERROR'))
" 2>/dev/null

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)

if [ "$QUIET" -eq 0 ]; then
  echo "$RESULT"
fi

case "$STATUS" in
  PASS) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
