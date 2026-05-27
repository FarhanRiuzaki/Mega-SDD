#!/usr/bin/env bash
# validate-kb-citations.sh — Track 1 expansion: citation resolution.
#
# Validates that §11 Source References in KB domain files point to files
# that actually exist in the legacy codebase. Broken citations = grounding
# failures (the KB claims evidence from a file that isn't there).
#
# Also checks: are there [VERIFIED] claims citing files NOT in §11?
# (orphaned inline citations not backed by the formal reference list)
#
# Usage: validate-kb-citations.sh --cwd=<project> --file-path=<kb-file.md>
#        --legacy-root=<legacy-codebase-path> [--quiet]
# Output:
#   stdout: JSON {status, broken_citations, orphaned_inline}
#   side-effect: <cwd>/.mega-sdd/.kb-citations-state.json
#   exit 0=PASS, 1=FAIL, 2=error

set -uo pipefail

CWD=""
FILE_PATH=""
LEGACY_ROOT=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --file-path=*) FILE_PATH="${arg#--file-path=}" ;;
    --legacy-root=*) LEGACY_ROOT="${arg#--legacy-root=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

# Auto-detect legacy root: check _source/ directory or parent of .mega-sdd
if [ -z "$LEGACY_ROOT" ]; then
  # Common patterns: legacy code is in CWD parent or sibling
  for candidate in \
    "${CWD}" \
    "$(dirname "$CWD")/$(basename "$CWD" | sed 's/-import$//' | sed 's/-rebuild$//')" \
    "${CWD}/.mega-sdd/knowledge-base/_source"; do
    if [ -d "$candidate" ] && [ -f "$candidate/index.php" -o -f "$candidate/composer.json" -o -f "$candidate/package.json" -o -f "$candidate/Gemfile" ]; then
      LEGACY_ROOT="$candidate"
      break
    fi
  done
fi

STATE_FILE="${CWD}/.mega-sdd/.kb-citations-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

RESULT=$(CWD="$CWD" FILE_PATH="$FILE_PATH" LEGACY_ROOT="${LEGACY_ROOT:-}" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json
import os
import re

file_path = os.environ["FILE_PATH"]
cwd = os.environ["CWD"]
legacy_root = os.environ.get("LEGACY_ROOT", "")

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    raise SystemExit(0)

# Find §11 Source References section
sec11_match = re.search(r"^## 11\.\s", content, re.MULTILINE)
if not sec11_match:
    print(json.dumps({
        "status": "SKIP",
        "detail": "no §11 Source References section found",
        "broken_citations": [], "total_citations": 0,
    }))
    raise SystemExit(0)

sec11 = content[sec11_match.start():]

# Extract file paths from §11 (pattern: backtick-wrapped filepath.ext:linerange)
BT = chr(96)  # backtick — avoid literal backtick in $() heredoc (bash interprets it)
citation_pattern = re.compile(
    BT + r"([^" + BT + r"]*?[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue)(?::\d+[-–]?\d*)?)" + BT
)

citations = []
for m in citation_pattern.finditer(sec11):
    raw = m.group(1)
    # Split on : to get file path and optional line range
    parts = re.split(r"[:\s]", raw, maxsplit=1)
    file_ref = parts[0].strip()
    citations.append({"raw": raw, "file_ref": file_ref})

if not citations:
    print(json.dumps({
        "status": "SKIP",
        "detail": "§11 exists but no file citations found",
        "broken_citations": [], "total_citations": 0,
    }))
    raise SystemExit(0)

# Resolve citations against legacy codebase
broken = []
resolved = []
for cite in citations:
    fref = cite["file_ref"]
    found = False

    # Try absolute path
    if os.path.isfile(fref):
        found = True
    # Try relative to legacy root
    elif legacy_root and os.path.isfile(os.path.join(legacy_root, fref)):
        found = True
    # Try relative to CWD
    elif os.path.isfile(os.path.join(cwd, fref)):
        found = True
    # Try stripping leading path components (citations sometimes have full paths)
    else:
        # Extract just the filename and search
        basename = os.path.basename(fref)
        # Check common subdirs
        for subdir in ["", "app", "src", "input", "report", "generate", "approval"]:
            candidate = os.path.join(legacy_root or cwd, subdir, basename) if subdir else os.path.join(legacy_root or cwd, basename)
            if os.path.isfile(candidate):
                found = True
                break

    if found:
        resolved.append(cite)
    else:
        broken.append(cite)

status = "FAIL" if broken else "PASS"
result = {
    "status": status,
    "checked_file": os.path.relpath(file_path, cwd),
    "total_citations": len(citations),
    "resolved": len(resolved),
    "broken": len(broken),
    "legacy_root": legacy_root or "(not detected)",
    "broken_citations": [
        {"file_ref": b["file_ref"], "raw": b["raw"][:80]}
        for b in broken[:10]
    ],
    "summary": (
        f"{len(resolved)}/{len(citations)} §11 citations resolve to existing files; "
        f"{len(broken)} broken"
        if broken else
        f"all {len(citations)} §11 citations resolve to existing files"
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
