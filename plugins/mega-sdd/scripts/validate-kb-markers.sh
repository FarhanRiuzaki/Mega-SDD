#!/usr/bin/env bash
# validate-kb-markers.sh — Track 1: enforced grounding gate for KB markers.
#
# Per-claim attribution: each [VERIFIED] claim must have its OWN citation
# evidence on the SAME LINE (inline) or in §11 with a matching file ref
# that also appears on the claim's own line. NO proximity window — borrowing
# a neighbor's citation is the same class of bug as the OQ-ID drop.
#
# Citation detection: generic path:line pattern (not hardcoded extensions).
# Matches: foo/bar.ext:123, src/models/user.ts:5-20, path/file.any:99
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

STATE_FILE="${CWD}/.mega-sdd/.kb-markers-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(CWD="$CWD" FILE_PATH="$FILE_PATH" _LIB_DIR="$_LIB_DIR" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json
import os
import re
import sys

sys.path.insert(0, os.environ["_LIB_DIR"])
try:
    from citation_pattern import PATH_LINE_RE, PATH_REF_RE
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": "cannot load citation_pattern lib: " + str(e)}))
    raise SystemExit(0)

file_path = os.environ["FILE_PATH"]
cwd = os.environ["CWD"]

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    raise SystemExit(0)

# Source-citation grammar (PATH_LINE_RE for path.ext:line, PATH_REF_RE for a
# file ref with optional line) is shared with validate-kb-citations.sh via
# _lib/citation_pattern.py so the two grounding validators cannot drift. The ext
# is LETTER-led (M7): a [VERIFIED] line citing ONLY a regulation/version/time token
# (23.2:2021, 1.5:1, 09.30:00) no longer counts as an inline anchor.
FILE_REF_RE = PATH_REF_RE   # path.ext[:line] — line not required

# Split into body (before §11) and §11 Source References
sec11_match = re.search(r"^## 11\.\s", content, re.MULTILINE)
if sec11_match:
    body = content[:sec11_match.start()]
    sec11 = content[sec11_match.start():]
else:
    body = content
    sec11 = ""

# Extract file basenames from §11 for cross-reference
sec11_basenames = set()
for m in PATH_LINE_RE.finditer(sec11):
    path_part = m.group(0).split(":")[0]
    sec11_basenames.add(os.path.basename(path_part))
# Also grab refs without line numbers
for m in FILE_REF_RE.finditer(sec11):
    ref = m.group(0)
    if "/" in ref or "." in ref:
        sec11_basenames.add(os.path.basename(ref.split(":")[0]))

# Find all [VERIFIED] claims — PER-CLAIM attribution (same line only)
verified_claims = []
lines = body.split("\n")
for i, line in enumerate(lines, 1):
    if "[VERIFIED]" not in line:
        continue

    # Check 1: inline path:line citation ON THIS LINE
    has_inline = bool(PATH_LINE_RE.search(line))

    # Check 2: inline file reference (no line number) that matches a §11 entry
    # This catches patterns like "per constitution A-001" or "(src/models/user.ts)"
    # where the file is mentioned but without :line, AND §11 has the detailed ref.
    has_sec11_match = False
    if not has_inline and sec11_basenames:
        line_files = set()
        for m in FILE_REF_RE.finditer(line):
            ref = m.group(0)
            if "/" in ref or "." in ref:
                line_files.add(os.path.basename(ref.split(":")[0]))
        has_sec11_match = bool(line_files & sec11_basenames)

    # (Removed the old hand-rolled backtick check — its digit-permissive `\w+:\d+`
    # re-admitted the exact reg/version/time tokens M7 rejects, and on the DOMINANT
    # backtick-wrapped path. It added zero true positives: PATH_LINE_RE (Check 1)
    # already matches a real citation whether or not it is backtick-wrapped, since
    # the backticks sit outside the path token.)
    cited = has_inline or has_sec11_match

    claim_text = line.strip()
    if len(claim_text) > 120:
        claim_text = claim_text[:117] + "..."

    verified_claims.append({
        "line": i,
        "claim_text": claim_text,
        "has_inline_citation": has_inline,
        "has_sec11_match": has_sec11_match,
        "cited": cited,
    })

uncited = [v for v in verified_claims if not v["cited"]]
cited_list = [v for v in verified_claims if v["cited"]]

# Check [INFERRED] with strong citations (upgrade candidates)
inferred_with_citation = 0
for line in lines:
    if "[INFERRED]" not in line:
        continue
    if PATH_LINE_RE.search(line):
        inferred_with_citation += 1

status = "FAIL" if uncited else "PASS"
result = {
    "status": status,
    "checked_file": os.path.relpath(file_path, cwd),
    "verified_total": len(verified_claims),
    "verified_cited": len(cited_list),
    "verified_uncited": len(uncited),
    "inferred_with_strong_citation": inferred_with_citation,
    "sec11_entries": len(sec11_basenames),
    "uncited_claims": [
        {"line": u["line"], "claim": u["claim_text"][:80]}
        for u in uncited[:15]
    ],
    "summary": (
        f"{len(cited_list)}/{len(verified_claims)} [VERIFIED] cited (per-claim, same-line); "
        f"{len(uncited)} uncited (lower bound)"
        if uncited else
        f"all {len(verified_claims)} [VERIFIED] cited (per-claim, same-line)"
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
