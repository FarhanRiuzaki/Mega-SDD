#!/usr/bin/env bash
# validate-kb-markers.sh — Track 1: enforced grounding gate for KB markers.
#
# Validates that [VERIFIED] claims in KB domain files have citation evidence.
# Evidence = either (a) inline file:line citation on same line/paragraph, OR
# (b) matching entry in §11 Source References section.
#
# [VERIFIED] without citation evidence → flagged for review (suggest downgrade
# to [INFERRED]). This is the grounding gate that makes deeper extraction
# trustworthy: every confidence claim is citation-backed.
#
# Usage: validate-kb-markers.sh --cwd=<project> --file-path=<kb-file.md> [--quiet]
# Output:
#   stdout: JSON {status, uncited_verified, checks}
#   side-effect: <cwd>/.mega-sdd/.kb-markers-state.json
#   exit 0=PASS, 1=FAIL (uncited found), 2=error

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

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.kb-markers-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

RESULT=$(CWD="$CWD" FILE_PATH="$FILE_PATH" python3 <<'PYEOF'
import json
import os
import re

file_path = os.environ["FILE_PATH"]
cwd = os.environ["CWD"]

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    raise SystemExit(0)

# Split into body (before §11) and §11 Source References
sec11_match = re.search(r"^## 11\.\s", content, re.MULTILINE)
if sec11_match:
    body = content[:sec11_match.start()]
    sec11 = content[sec11_match.start():]
else:
    body = content
    sec11 = ""

# Extract all file references from §11 (patterns: filename.ext:line or filename.ext:line-line)
sec11_files = set()
for m in re.finditer(r"[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue|blade\.php)(?::\d+[-–]?\d*)?", sec11):
    sec11_files.add(m.group(0).split(":")[0])  # just the filename part

# Find all [VERIFIED] claims in body
verified_claims = []
lines = body.split("\n")
for i, line in enumerate(lines, 1):
    if "[VERIFIED]" not in line:
        continue

    # Check for inline citation: file.ext:line on same line
    has_inline = bool(re.search(
        r"[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue|blade\.php):\d+",
        line
    ))

    # Check for nearby citation (within 2 lines before/after, e.g., table rows or source blocks)
    context_start = max(0, i - 3)
    context_end = min(len(lines), i + 2)
    context_block = "\n".join(lines[context_start:context_end])
    has_nearby = bool(re.search(
        r"[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue|blade\.php):\d+",
        context_block
    )) if not has_inline else True

    # Check for §11 cross-reference: does §11 have a citation for any file mentioned
    # in the context around this [VERIFIED]?
    context_files = set()
    for m in re.finditer(r"[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue|blade\.php)", context_block):
        context_files.add(m.group(0))

    has_sec11_ref = bool(context_files & sec11_files) if context_files else False

    # Extract a short context snippet for the claim
    claim_text = line.strip()
    if len(claim_text) > 120:
        claim_text = claim_text[:117] + "..."

    cited = has_inline or has_nearby or has_sec11_ref
    verified_claims.append({
        "line": i,
        "claim_text": claim_text,
        "has_inline_citation": has_inline,
        "has_nearby_citation": has_nearby,
        "has_sec11_ref": has_sec11_ref,
        "cited": cited,
    })

# Separate cited vs uncited
uncited = [v for v in verified_claims if not v["cited"]]
cited = [v for v in verified_claims if v["cited"]]

# Also check [INFERRED] claims — these SHOULD NOT have strong citations
# (if they do, they should be upgraded to [VERIFIED])
inferred_with_citation = 0
for i, line in enumerate(lines, 1):
    if "[INFERRED]" not in line:
        continue
    has_file_ref = bool(re.search(
        r"[\w/.-]+\.(?:php|js|ts|py|rb|java|go|rs|sql|yaml|json|md|vue|blade\.php):\d+",
        line
    ))
    if has_file_ref:
        inferred_with_citation += 1

status = "FAIL" if uncited else "PASS"
result = {
    "status": status,
    "checked_file": os.path.relpath(file_path, cwd),
    "verified_total": len(verified_claims),
    "verified_cited": len(cited),
    "verified_uncited": len(uncited),
    "inferred_with_strong_citation": inferred_with_citation,
    "sec11_entries": len(sec11_files),
    "uncited_claims": [
        {"line": u["line"], "claim": u["claim_text"][:80]}
        for u in uncited[:10]  # cap at 10 for readability
    ],
    "summary": (
        f"{len(cited)}/{len(verified_claims)} [VERIFIED] claims have citation evidence; "
        f"{len(uncited)} uncited (suggest downgrade to [INFERRED])"
        if uncited else
        f"all {len(verified_claims)} [VERIFIED] claims have citation evidence"
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
  PASS) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
