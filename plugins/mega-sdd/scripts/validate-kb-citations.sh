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

# Auto-detect legacy root (M4 — inside the validator; PostToolUse can't thread
# --legacy-root through the generic hook helper). Probe common seed locations for
# ANY §8.5-ecosystem manifest, not just PHP/Node/Ruby.
_has_manifest() {
  local d="$1"
  [ -d "$d" ] || return 1
  for m in index.php composer.json package.json Gemfile go.mod Cargo.toml \
           pom.xml build.gradle build.gradle.kts settings.gradle \
           pyproject.toml requirements.txt setup.py Pipfile mix.exs; do
    [ -f "$d/$m" ] && return 0
  done
  # .NET (C#/F#/VB) has no fixed filename — glob for a project OR solution file
  # (check each separately: `ls a.csproj b.sln` exits non-zero if EITHER is empty).
  ls "$d"/*.csproj >/dev/null 2>&1 && return 0
  ls "$d"/*.fsproj >/dev/null 2>&1 && return 0
  ls "$d"/*.vbproj >/dev/null 2>&1 && return 0
  ls "$d"/*.sln    >/dev/null 2>&1 && return 0
  return 1
}
if [ -z "$LEGACY_ROOT" ]; then
  for candidate in \
    "${CWD}/_source" \
    "${CWD}/.mega-sdd/knowledge-base/_source" \
    "${CWD}/.mega-sdd/_source" \
    "${CWD}/legacy" \
    "${CWD}" \
    "$(dirname "$CWD")/$(basename "$CWD" | sed 's/-import$//' | sed 's/-rebuild$//')"; do
    if _has_manifest "$candidate"; then
      LEGACY_ROOT="$candidate"
      break
    fi
  done
fi

STATE_FILE="${CWD}/.mega-sdd/.kb-citations-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(CWD="$CWD" FILE_PATH="$FILE_PATH" LEGACY_ROOT="${LEGACY_ROOT:-}" _LIB_DIR="$_LIB_DIR" python3 -W ignore::DeprecationWarning <<'PYEOF'
import json
import os
import re
import sys

sys.path.insert(0, os.environ["_LIB_DIR"])
try:
    from citation_pattern import SRC_EXT, PATH_REF_RE
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": "cannot load citation_pattern lib: " + str(e)}))
    raise SystemExit(0)

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

# Extract file paths from §11: pull each backtick-wrapped span, then extract the
# actual path with the SHARED grammar (PATH_REF_RE). This (a) uses the generic
# letter-led ext + extensionless (Gemfile/Dockerfile/dotfile) support — H1 fix, was
# a hardcoded php/js/py/… allow-list so a C#/.NET/Kotlin/TSX §11 matched nothing →
# 0 citations → silent SKIP-green; and (b) extracts the path from prose-wrapped
# spans like `see config.yaml` instead of a naive whitespace split (which yielded
# file_ref='see' → false broken).
BT = chr(96)  # backtick — avoid literal backtick in $() heredoc (bash interprets it)
citations = []
for bm in re.finditer(BT + r"([^" + BT + r"]+)" + BT, sec11):
    span = bm.group(1)
    pm = PATH_REF_RE.search(span)
    if not pm:
        continue
    file_ref = pm.group(0).split(":")[0].strip()
    citations.append({"raw": span, "file_ref": file_ref})

if not citations:
    # A grounded KB (carries [VERIFIED] claims) whose §11 yields ZERO file citations
    # is itself a defect, not a clean SKIP — the grounding evidence is missing or
    # malformed. Advisory WARN (exit 0). EXEMPT a §11 explicitly marked N/A /
    # _None detected_ (nothing to ground), same lesson as the vault N/A-escape.
    sec11_is_na = bool(re.search(r"_None\s+(?:detected|found|identified)_?|N/A|not applicable|no source", sec11, re.IGNORECASE))
    # Strip fenced code blocks before the [VERIFIED] test — a marker legend / example
    # page mentioning `[VERIFIED]` inside a ``` fence must not trip the WARN.
    _defenced = re.sub(BT * 3 + r".*?" + BT * 3, "", content, flags=re.DOTALL)
    has_verified = "[VERIFIED]" in _defenced
    if has_verified and not sec11_is_na:
        print(json.dumps({
            "status": "WARN",
            "detail": "§11 present and the KB has [VERIFIED] claims, but 0 file citations were extracted — grounding evidence missing or malformed",
            "broken_citations": [], "total_citations": 0,
        }))
        raise SystemExit(0)
    print(json.dumps({
        "status": "SKIP",
        "detail": "§11 exists but no file citations found" + (" (marked N/A)" if sec11_is_na else ""),
        "broken_citations": [], "total_citations": 0,
    }))
    raise SystemExit(0)

_SKIP_DIRS = {".git", "node_modules", "vendor", "bin", "obj", "target",
              "build", "dist", ".mega-sdd", "__pycache__", ".idea", ".vscode",
              ".venv", "venv", "env", ".gradle", "Pods", "packages", ".next",
              ".nuxt", ".svelte-kit", "coverage", ".tox", ".pytest_cache",
              ".mypy_cache", "bower_components", ".terraform"}

def _build_basename_index(root, max_depth=6, max_files=20000):
    """Walk the legacy tree ONCE and map basename → [paths] (capped at 2 per name —
    enough to detect ambiguity). Built once per invocation so N citations resolve
    O(1); the old code re-walked the whole tree per unresolved citation, a perf
    cliff on every KB write via the PostToolUse hook. Depth + file caps + a broad
    dep-dir skip set keep it bounded on a big tree."""
    index = {}
    if not root or not os.path.isdir(root):
        return index
    root = os.path.abspath(root)
    base = root.rstrip(os.sep).count(os.sep)
    seen = 0
    for dp, dn, fns in os.walk(root):
        if dp.rstrip(os.sep).count(os.sep) - base >= max_depth:
            dn[:] = []
        dn[:] = [d for d in dn if d not in _SKIP_DIRS]
        for fn in fns:
            seen += 1
            if seen > max_files:
                return index
            lst = index.setdefault(fn, [])
            if len(lst) < 2:
                lst.append(os.path.join(dp, fn))
    return index

_basename_index = _build_basename_index(legacy_root or cwd)

# Resolve citations against legacy codebase
broken = []
resolved = []
ambiguous = 0
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
    # Bounded recursive basename search (replaces the project-specific hardcoded
    # subdir list `input/report/generate/approval`). A basename resolving to a
    # UNIQUE file is grounded; 0 hits = broken; ≥2 hits = ambiguous, NOT proof.
    else:
        matches = _basename_index.get(os.path.basename(fref), [])
        if len(matches) == 1:
            found = True
        elif len(matches) >= 2:
            cite = dict(cite, ambiguous=True)
            ambiguous += 1

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
    "ambiguous": ambiguous,
    "legacy_root": legacy_root or "(not detected)",
    "broken_citations": [
        {"file_ref": b["file_ref"], "raw": b["raw"][:80],
         **({"ambiguous": True} if b.get("ambiguous") else {})}
        for b in broken[:10]
    ],
    "summary": (
        f"{len(resolved)}/{len(citations)} §11 citations resolve to existing files; "
        f"{len(broken)} broken" + (f" ({ambiguous} ambiguous — basename matched >1 file)" if ambiguous else "")
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
  PASS|SKIP|WARN) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
