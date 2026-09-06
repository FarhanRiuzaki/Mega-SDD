#!/usr/bin/env bash
# validate-kb.sh — the ONE knowledge-base/flows validator (v7 Fase 2 merge
# group 8: validate-kb-output.sh + validate-kb-citations.sh +
# validate-kb-flows.sh + validate-kb-markers.sh + validate-vault-flows.sh
# folded verbatim as --surface arms; every arm keeps its own state file,
# JSON shape, and exit semantics UNCHANGED).
#
# Usage: validate-kb.sh --surface=<output|citations|flows|markers|vault-flows> <the surface's own flags>
#   output       → .kb-output-state.json       (marker counts + 11-section schema + depends_on)
#   citations    → .kb-citations-state.json    (§11 source resolution; --legacy-root supported)
#   flows        → .kb-flows-state.json        (KB §3/§8 Mermaid heuristics; shared _lib/mermaid_syntax.py)
#   markers      → .kb-markers-state.json      (per-[VERIFIED] same-line citation)
#   vault-flows  → .vault-flows-state.json     (vault 04-flows.md Mermaid mandate)
# Exit: per surface (0 PASS/SKIP · 1 FAIL · 2 error); unknown --surface → 2.
set -uo pipefail

SURFACE=""
_STRIPPED=()
for arg in "$@"; do
  case "$arg" in
    --surface=*) SURFACE="${arg#*=}" ;;
    *) _STRIPPED+=("$arg") ;;
  esac
done
if [ "${#_STRIPPED[@]}" -gt 0 ]; then set -- "${_STRIPPED[@]}"; else set --; fi

case "$SURFACE" in
  output)
# ═══ surface: output (merged verbatim from validate-kb-output.sh) ═══

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
# Grammar detection (7.24.0, spec 2026-09-05-kb-verify-lane-design.md Fase 1):
# census-contracted module PRDs (extract revamp 7.6.0) live at
# knowledge-base/modules/<domain>.prd.md — 6-section body, implicit-verified
# confidence (a cited claim with NO marker is verified, [INTENT] is the
# mutability default) — so verified_count/intent_count are NOT recomputable
# from the body; only the explicit markers are exact-checkable, and
# open_count is checked against the §6 OQ entry count.
IS_MODULE_GRAMMAR = bool(re.search(r"[\\/]modules[\\/][^\\/]+\.prd\.md$", file_path))

if IS_MODULE_GRAMMAR:
    marker_checks = [
        ("inferred_count", "[INFERRED]"),
        ("locked_count", "[LOCKED]"),
        ("intent_count", "[INTENT]"),
        ("artifact_count", "[ARTIFACT]"),
    ]
else:
    marker_checks = [
        ("verified_count", "[VERIFIED]"),
        ("inferred_count", "[INFERRED]"),
        ("open_count", "[OPEN]"),
        ("locked_count", "[LOCKED]"),
    ]

for fm_field, marker in marker_checks:
    if fm_field not in fm:
        # Field absent — not a fail for optional fields (locked_count is v1.4+;
        # artifact_count only exists in the 7.6+ module grammar)
        if fm_field in ("locked_count", "artifact_count"):
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

if IS_MODULE_GRAMMAR:
    # --- module grammar: implicit-default field + open_count vs §6 OQ entries ---
    # (intent_count moved to exact-check in 7.26.0 — the field is defined as
    # EXPLICIT [INTENT] markers and script-derived by derive-prd-counts.sh;
    # verified_count stays underivable → informational only, retired from the
    # 7.26+ frontmatter contract.)
    for impl_field in ("verified_count",):
        checks.append({"check": f"{impl_field}_match", "status": "SKIP",
                       "detail": "implicit-default field (7.6+ module grammar) — not recomputable from body"})
    sec6_m = re.search(r"^## 6\.", content, re.MULTILINE)
    oq_entries = 0
    if sec6_m:
        oq_entries = len(re.findall(r"^\s*-\s*(?:\[[ xX]\]\s*)?OQ-", content[sec6_m.start():], re.MULTILINE))
    expected_open = fm.get("open_count")
    if isinstance(expected_open, int):
        if oq_entries != expected_open:
            issues.append({
                "halt_type": "kb_marker_count_mismatch",
                "detail": f"frontmatter open_count={expected_open} but §6 lists {oq_entries} OQ entries (delta={oq_entries - expected_open})",
                "field": "open_count", "expected": expected_open, "actual": oq_entries,
            })
            checks.append({"check": "open_count_match", "status": "FAIL",
                           "detail": f"fm={expected_open}, sec6={oq_entries}"})
        else:
            checks.append({"check": "open_count_match", "status": "PASS",
                           "detail": f"fm={expected_open}, sec6={oq_entries}"})
    else:
        issues.append({"halt_type": "kb_frontmatter_field_missing",
                       "detail": "required frontmatter field 'open_count' absent"})
        checks.append({"check": "open_count_match", "status": "FAIL"})

# --- Check 6: required sections (module grammar: 6; legacy: 11) ---
if IS_MODULE_GRAMMAR:
    required_sections = [
        "## 1. Purpose",
        "## 2. Business Rules",
        "## 3. Flow",
        "## 4. Data In/Out",
        "## 5. Edge Cases & Gotchas",
        "## 6. Open Questions",
    ]
    sections_check_name = "six_sections_present"
else:
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
    sections_check_name = "eleven_sections_present"

missing_sections = []
for sec in required_sections:
    # Flexible match: section header may have slightly different wording
    sec_num = sec.split(".")[0] + "."  # e.g., "## 1."
    if sec_num not in content:
        missing_sections.append(sec)

if missing_sections:
    issues.append({
        "halt_type": "kb_sections_incomplete",
        "detail": f"missing {len(missing_sections)} of {len(required_sections)} required sections: {', '.join(missing_sections[:3])}{'...' if len(missing_sections) > 3 else ''}",
        "missing_sections": missing_sections,
    })
    checks.append({"check": sections_check_name, "status": "FAIL",
                   "detail": f"missing {len(missing_sections)} sections"})
else:
    checks.append({"check": sections_check_name, "status": "PASS",
                   "detail": f"all {len(required_sections)} sections present"})

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
  ;;
  citations)
# ═══ surface: citations (merged verbatim from validate-kb-citations.sh) ═══

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

# Auto-detect legacy root (M4 — inside the validator; the generic dispatchers
# (analyze, certify) don't thread --legacy-root). Probe common seed locations for
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

# ── 7.6+ module grammar (7.24.0, spec 2026-09-05-kb-verify-lane-design.md) ──
# knowledge-base/modules/<domain>.prd.md carries NO §11 — its grounding contract
# is the frontmatter source_files list: every entry must be cited ≥1x in the
# body (the census gate recomputes this at extract time; this is the analyze-
# time re-derivation) and must resolve against census.json (fallback: legacy
# root / cwd on disk). Without this branch a module PRD silently SKIP-greens.
if re.search(r"[\\/]modules[\\/][^\\/]+\.prd\.md$", file_path):
    fm_m = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    fm_text = fm_m.group(1) if fm_m else ""
    body = content[fm_m.end():] if fm_m else content

    src_files = []
    in_sf = False
    for ln in fm_text.split("\n"):
        if re.match(r"^source_files:\s*$", ln):
            in_sf = True
            continue
        if in_sf:
            mm = re.match(r"^\s+-\s+(.+?)\s*$", ln)
            if mm:
                src_files.append(mm.group(1).strip().strip("'\""))
                continue
            if re.match(r"^\S", ln):
                in_sf = False
    if not src_files:
        mm = re.search(r"^source_files:\s*\[(.*?)\]", fm_text, re.MULTILINE | re.DOTALL)
        if mm:
            src_files = [x.strip().strip("'\"") for x in mm.group(1).split(",") if x.strip()]

    if not src_files:
        print(json.dumps({
            "status": "FAIL",
            "checked_file": os.path.relpath(file_path, cwd),
            "issues": [{"halt_type": "kb_source_files_missing",
                        "detail": "module PRD frontmatter has no source_files list — grounding contract absent"}],
            "total_citations": 0, "broken_citations": [],
            "summary": "no source_files in frontmatter",
        }))
        raise SystemExit(0)

    # census.json lives at the KB root (parent of modules/)
    census_paths = set()
    census_basenames = set()
    census_loaded = False
    census_path = os.path.join(os.path.dirname(os.path.dirname(file_path)), "census.json")
    try:
        with open(census_path, encoding="utf-8") as cf:
            census = json.load(cf)
        for entry in census.get("files", []):
            p = entry.get("path", "") if isinstance(entry, dict) else str(entry)
            if p:
                census_paths.add(p)
                census_basenames.add(os.path.basename(p))
        census_loaded = True
    except Exception:
        pass

    uncited = [e for e in src_files if e not in body]

    unresolved = []
    resolution = "census.json" if census_loaded else ""
    for e in src_files:
        base = os.path.basename(e)
        if census_loaded and (e in census_paths or base in census_basenames):
            continue
        if legacy_root and os.path.isfile(os.path.join(legacy_root, e)):
            resolution = resolution or "legacy_root"
            continue
        if os.path.isfile(os.path.join(cwd, e)):
            resolution = resolution or "cwd"
            continue
        if not census_loaded and not legacy_root:
            resolution = "skipped (no census.json, no legacy root)"
            unresolved = []
            break
        unresolved.append(e)

    issues = []
    for e in uncited[:15]:
        issues.append({"halt_type": "kb_source_file_uncited",
                       "detail": f"source_files entry '{e}' is never cited in the body (census contract: every entry cited >=1x)"})
    for e in unresolved[:15]:
        issues.append({"halt_type": "kb_source_file_unresolved",
                       "detail": f"source_files entry '{e}' resolves to nothing (not in census.json, legacy root, or cwd)"})

    status = "FAIL" if (uncited or unresolved) else "PASS"
    print(json.dumps({
        "status": status,
        "checked_file": os.path.relpath(file_path, cwd),
        "grammar": "module",
        "source_files_total": len(src_files),
        "uncited": len(uncited),
        "unresolved": len(unresolved),
        "resolution_via": resolution or "(none)",
        "issues": issues,
        "total_citations": len(src_files),
        "broken_citations": [{"file_ref": e, "raw": e} for e in (uncited + unresolved)[:10]],
        "summary": (f"{len(src_files) - len(uncited)}/{len(src_files)} source_files cited; "
                    f"{len(uncited)} uncited, {len(unresolved)} unresolved"
                    if (uncited or unresolved) else
                    f"all {len(src_files)} source_files cited in body and resolved ({resolution or 'no resolution source'})"),
    }))
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
    cliff on every analyze/certify run (formerly every KB write). Depth + file caps + a broad
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
  ;;
  flows)
# ═══ surface: flows (merged verbatim from validate-kb-flows.sh) ═══

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

# Run validator as a standalone Python script to avoid heredoc backtick issues.
# The Mermaid Rule 1-3 syntax tokenizer lives in _lib/mermaid_syntax.py — the
# single source of truth shared with validate-vault-flows.sh (never fork it).
_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" "$_LIB_DIR" <<'PYEOF'
import json, os, re, sys

cwd = sys.argv[1]
file_path = sys.argv[2]
sys.path.insert(0, sys.argv[3])
try:
    from mermaid_syntax import (FENCE, extract_mermaid_blocks,
                                check_mermaid_syntax, check_diagram_type)
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": "cannot load mermaid_syntax lib: " + str(e)}))
    sys.exit(0)

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    sys.exit(0)

checks = []
issues = []
advisories = []   # v3.71.0+ semantic-depth: non-blocking signals (never flip status)
lines = content.split("\n")

# ──────────────────────────────────────────────────────────────────────────
# §3 Flow section
# ──────────────────────────────────────────────────────────────────────────
sec3_match = re.search(r"^## 3\.\s", content, re.MULTILINE)
if sec3_match:
    sec3_end_m = re.search(r"^## [4-9]\.", content[sec3_match.end():], re.MULTILINE)
    sec3_text = content[sec3_match.start():sec3_match.end() + sec3_end_m.start()] if sec3_end_m else content[sec3_match.start():]
    # Compute line offset (1-based) of sec3 within full content
    sec3_line_offset = content[:sec3_match.start()].count("\n")  # 0-based offset of sec3 start

    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec3_text.lower()
    has_none = bool(re.search(r"_None detected|N/A", sec3_text))

    if has_mermaid:
        checks.append({"check": "sec3_flow_mermaid_fence", "status": "PASS", "detail": "has Mermaid fence"})
        # Now run v2 syntax check on the section
        sec3_blocks_local = extract_mermaid_blocks(sec3_text)
        # Adjust line numbers to be relative to whole file
        sec3_blocks = []
        for bs, be, body in sec3_blocks_local:
            adj_body = [(ln + sec3_line_offset, line) for ln, line in body]
            sec3_blocks.append((bs + sec3_line_offset, be + sec3_line_offset, adj_body))
        sec3_syntax_issues = (check_diagram_type(sec3_blocks, "3")
                              + check_mermaid_syntax(sec3_blocks, "3"))
        if sec3_syntax_issues:
            checks.append({"check": "sec3_mermaid_syntax", "status": "FAIL",
                          "detail": f"{len(sec3_syntax_issues)} heuristic syntax issue(s) per mermaid-emission-rules.md"})
            issues.extend(sec3_syntax_issues)
        else:
            checks.append({"check": "sec3_mermaid_syntax", "status": "PASS",
                          "detail": "no heuristic syntax issues detected"})
    elif has_none:
        checks.append({"check": "sec3_flow_mermaid_fence", "status": "SKIP", "detail": "marked N/A"})
    else:
        has_ascii = bool(re.search(r"-->|->|flowchart|graph\s", sec3_text))
        if has_ascii:
            issues.append({"halt_type": "kb_flow_not_mermaid", "section": "3",
                          "detail": "flow content not in " + FENCE + "mermaid fence"})
            checks.append({"check": "sec3_flow_mermaid_fence", "status": "FAIL",
                          "detail": "has flow arrows but not in mermaid fence"})
        else:
            issues.append({"halt_type": "kb_flow_missing", "section": "3",
                          "detail": "no diagram found"})
            checks.append({"check": "sec3_flow_mermaid_fence", "status": "FAIL", "detail": "no flow diagram"})
else:
    checks.append({"check": "sec3_flow_mermaid_fence", "status": "SKIP", "detail": "no section 3"})

# ──────────────────────────────────────────────────────────────────────────
# §8 State Machine section
# ──────────────────────────────────────────────────────────────────────────
sec8_match = re.search(r"^## 8\.\s", content, re.MULTILINE)
if sec8_match:
    sec8_end_m = re.search(r"^## 9\.", content[sec8_match.end():], re.MULTILINE)
    sec8_text = content[sec8_match.start():sec8_match.end() + sec8_end_m.start()] if sec8_end_m else content[sec8_match.start():]
    sec8_line_offset = content[:sec8_match.start()].count("\n")

    has_na = bool(re.search(r"N/A|not a workflow|_N/A", sec8_text, re.IGNORECASE))
    mermaid_fence = FENCE + "mermaid"
    has_mermaid = mermaid_fence.lower() in sec8_text.lower()
    has_transitions = bool(re.search(r"--.*-->|--.*->", sec8_text))

    # Check has_mermaid FIRST (mirror §3): a valid mermaid stateDiagram whose node
    # text happens to contain an "N/A" / "not a workflow" token must be syntax-checked,
    # not SKIP'd. Only fall to the N/A SKIP when there is no fence.
    if has_mermaid:
        checks.append({"check": "sec8_state_machine_fence", "status": "PASS", "detail": "has Mermaid state diagram"})
        sec8_blocks_local = extract_mermaid_blocks(sec8_text)
        sec8_blocks = []
        for bs, be, body in sec8_blocks_local:
            adj_body = [(ln + sec8_line_offset, line) for ln, line in body]
            sec8_blocks.append((bs + sec8_line_offset, be + sec8_line_offset, adj_body))
        sec8_syntax_issues = (check_diagram_type(sec8_blocks, "8")
                              + check_mermaid_syntax(sec8_blocks, "8"))
        if sec8_syntax_issues:
            checks.append({"check": "sec8_mermaid_syntax", "status": "FAIL",
                          "detail": f"{len(sec8_syntax_issues)} heuristic syntax issue(s) per mermaid-emission-rules.md"})
            issues.extend(sec8_syntax_issues)
        else:
            checks.append({"check": "sec8_mermaid_syntax", "status": "PASS",
                          "detail": "no heuristic syntax issues detected"})
    elif has_na:
        checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "N/A"})
    elif has_transitions:
        # Mermaid-flows hard rule (2026-07-01 spec; subsumes god-review L7):
        # a non-N/A §8 with transition arrows but no ```mermaid fence is a
        # prose/ASCII flow — FAIL like §3, not the old silent "consider a fence" PASS.
        issues.append({"halt_type": "kb_flow_not_mermaid", "section": "8",
                       "detail": "state transitions not in " + FENCE + "mermaid fence"})
        checks.append({"check": "sec8_state_machine_fence", "status": "FAIL",
                       "detail": "has state transitions but not in mermaid fence"})
    else:
        issues.append({"halt_type": "kb_state_machine_missing", "section": "8",
                       "detail": "non-N/A but no state diagram"})
        checks.append({"check": "sec8_state_machine_fence", "status": "FAIL", "detail": "no state diagram"})
else:
    checks.append({"check": "sec8_state_machine_fence", "status": "SKIP", "detail": "no section 8"})

# ──────────────────────────────────────────────────────────────────────────
# Staged-input advisory (v3.71.0+, semantic-depth) — ADVISORY ONLY.
# Flags a workflow KB file that looks multi-step (workflow flow signal OR
# >5 inputs) but carries no `## 3a` stages: block. NEVER flips status (rides a
# separate advisories[] channel per the Iter-78.1 invariant). Pairs with the
# extract-intelligence §3a staged-input detection guidance; points the user to
# a scoped extract-intelligence re-run. See prd-kontrak-template.md §Staged inputs.
# ──────────────────────────────────────────────────────────────────────────
def _frontmatter(text):
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    return m.group(1) if m else ""

_fm = _frontmatter(content)
_classification = ""
_mfm = re.search(r"^classification:\s*([A-Za-z_-]+)", _fm, re.MULTILINE)
if _mfm:
    _classification = _mfm.group(1).strip().lower()

# §8 present and non-N/A is itself a workflow signal when frontmatter is silent
_sec8_is_workflow = False
if sec8_match:
    _sec8_head = content[sec8_match.start():sec8_match.start() + 400]
    _sec8_is_workflow = not bool(re.search(r"N/A|not a workflow", _sec8_head, re.IGNORECASE))
_is_workflow = (_classification == "workflow") or _sec8_is_workflow

# stages: block present? require BOTH the `stages:` line AND a `stage_id:` token
# (robust vs prose that merely mentions the word "stages").
_has_stages_block = bool(re.search(r"^\s*stages:\s*$", content, re.MULTILINE)) and ("stage_id:" in content)

# multi-step signal — reuse the operator-surface closed grammar (decision verbs)
_decision_re = re.compile(r"\b(approve|reject|review|confirm|verify|authorize|endorse)\b", re.IGNORECASE)
_transition_lines = [ln for ln in lines if ("-->" in ln or "->" in ln)]
_decision_transitions = sum(1 for ln in _transition_lines if _decision_re.search(ln))
_maker_checker = bool(re.search(r"\bmaker\b.{0,80}\b(checker|approver|reviewer|confirmer)\b",
                                content, re.IGNORECASE | re.DOTALL))

# §4 Inputs list-item count
_input_field_count = 0
_sec4_m = re.search(r"^## 4\.\s", content, re.MULTILINE)
if _sec4_m:
    _sec4_end = re.search(r"^## 5\.", content[_sec4_m.end():], re.MULTILINE)
    _sec4_text = (content[_sec4_m.start(): _sec4_m.end() + _sec4_end.start()]
                  if _sec4_end else content[_sec4_m.start():])
    _input_field_count = (len(re.findall(r"^\s*[-*]\s+\S", _sec4_text, re.MULTILINE))
                          + len(re.findall(r"^\s*\d+\.\s+\S", _sec4_text, re.MULTILINE)))

_multistep = _is_workflow and (_decision_transitions >= 2 or _maker_checker or _input_field_count > 5)

if _multistep and not _has_stages_block:
    _reasons = []
    if _decision_transitions >= 2:
        _reasons.append(f"{_decision_transitions} decision transitions")
    if _maker_checker:
        _reasons.append("maker->checker hand-off")
    if _input_field_count > 5:
        _reasons.append(f"{_input_field_count} input fields")
    advisories.append({
        "halt_type": "kb_flow_staging_missing",
        "severity": "advisory",
        "section": "3a",
        "detail": ("workflow looks multi-step (" + "; ".join(_reasons) +
                   ") but carries no `## 3a` stages: block — staging may be lost downstream "
                   "(single-form bolt instead of multi-step wizard)"),
        "suggested_fix": ("author the staged-inputs stages: block (prd-kontrak-template.md §Staged inputs), "
                          "or retro-fit via `enrich-semantics --vault=<vault> "
                          "--legacy-root=<legacy> --semantic=staged-input`"),
    })

has_fail = any(c["status"] == "FAIL" for c in checks)
_summary = (
    f"{len(issues)} flow format/syntax issue(s) — see issues[] for line numbers + suggested fixes"
    if issues else "all flows use Mermaid; heuristic syntax checks pass"
)
if advisories:
    _summary += f" | {len(advisories)} staging advisory(ies) — run enrich-semantics"
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "advisories": advisories,   # v3.71.0+ semantic-depth — non-blocking
    "summary": _summary,
    "next_action": (
        "Advisory: workflow looks multi-step but has no stages: block. Run enrich-semantics to retro-fit staging."
        if advisories else None
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
  ;;
  markers)
# ═══ surface: markers (merged verbatim from validate-kb-markers.sh) ═══

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

# ── 7.6+ module grammar (7.24.0, spec 2026-09-05-kb-verify-lane-design.md) ──
# Implicit-verified: writing a literal [VERIFIED] tag is a grammar violation
# ("do not write [VERIFIED] tags" — domain-extractor contract), and every
# [INFERRED] must say what it is inferred from — a same-line basis
# parenthetical ("(dasar:" / "(basis" / "(based on") or a same-line file ref.
if re.search(r"[\\/]modules[\\/][^\\/]+\.prd\.md$", file_path):
    BT = chr(96)  # backtick — avoid literal backtick inside $() heredoc
    _defenced = re.sub(BT * 3 + r".*?" + BT * 3, "", content, flags=re.DOTALL)
    issues = []

    verified_tag_lines = [i for i, ln in enumerate(_defenced.split("\n"), 1)
                          if "[VERIFIED]" in ln]
    for ln_no in verified_tag_lines[:10]:
        issues.append({"halt_type": "kb_verified_tag_in_module_grammar", "line": ln_no,
                       "detail": "literal [VERIFIED] tag in a 7.6+ module PRD — the grammar is implicit-verified (a cited claim with no marker); remove the tag"})

    _basis_re = re.compile(r"\((?:dasar|basis|based on)", re.IGNORECASE)
    inferred_total = 0
    inferred_unbased = []
    for i, ln in enumerate(_defenced.split("\n"), 1):
        if "[INFERRED]" not in ln:
            continue
        inferred_total += 1
        if _basis_re.search(ln) or PATH_REF_RE.search(ln):
            continue
        claim_text = ln.strip()
        if len(claim_text) > 120:
            claim_text = claim_text[:117] + "..."
        inferred_unbased.append({"line": i, "claim": claim_text[:80]})
    for u in inferred_unbased[:15]:
        issues.append({"halt_type": "kb_inferred_without_basis", "line": u["line"],
                       "detail": f"[INFERRED] with no same-line basis or file ref: {u['claim']}"})

    status = "FAIL" if issues else "PASS"
    print(json.dumps({
        "status": status,
        "checked_file": os.path.relpath(file_path, cwd),
        "grammar": "module",
        "inferred_total": inferred_total,
        "inferred_without_basis": len(inferred_unbased),
        "verified_tag_violations": len(verified_tag_lines),
        "issues": issues,
        "uncited_claims": inferred_unbased[:15],
        "summary": (f"{len(verified_tag_lines)} [VERIFIED]-tag violation(s); "
                    f"{len(inferred_unbased)}/{inferred_total} [INFERRED] without a basis"
                    if issues else
                    f"module grammar clean: 0 [VERIFIED] tags, all {inferred_total} [INFERRED] carry a basis"),
    }))
    raise SystemExit(0)

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
  ;;
  vault-flows)
# ═══ surface: vault-flows (merged verbatim from validate-vault-flows.sh) ═══

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

_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ -z "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"--file-path required"}' >&2; exit 2; fi
if [ ! -f "$FILE_PATH" ]; then echo '{"status":"ERROR","detail":"file not found"}' >&2; exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.vault-flows-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

_LIB_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib"
RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$FILE_PATH" "$_LIB_DIR" <<'PYEOF'
import json, os, re, sys
cwd, file_path = sys.argv[1], sys.argv[2]
sys.path.insert(0, sys.argv[3])
try:
    from mermaid_syntax import (FENCE, extract_mermaid_blocks,
                                check_mermaid_syntax, check_diagram_type)
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": "cannot load mermaid_syntax lib: " + str(e)}))
    sys.exit(0)

try:
    content = open(file_path, encoding="utf-8").read()
except Exception as e:
    print(json.dumps({"status": "ERROR", "detail": str(e)}))
    sys.exit(0)

lines = content.split("\n")
checks = []
issues = []

# Locate each flow entry. Canonical headings are `### F-<prefix>-NNN`, but a flow
# heading that OMITS the F-prefix (`### User Login`) must NOT escape the Mermaid
# mandate — the pre-fix F-prefix-only regex silently skipped it, and a 04-flows.md
# whose headings ALL lack the prefix SKIP-PASSed wholesale (every flow escaped). In a
# 04-flows.md, EVERY level-3 `###` heading is a flow entry (structural sections are
# level-2 `##`), minus a small denylist. Non-flows files keep the strict F-prefix rule
# (defensive — callers only ever pass 04-flows.md).
_NON_FLOW_HEAD = re.compile(
    r"^(sources?|out[\s-]of[\s-]scope|open\s+questions?|notes?|legend|glossary|"
    r"definition\s+of\s+done|dod|changelog|references?|see\s+also|assumptions?|"
    r"non[\s-]goals?)\b", re.IGNORECASE)
if (os.path.basename(file_path).endswith("04-flows.md")
        or os.path.basename(file_path) == "flows.md"):   # v7 Fase 3 layout-2
    _HEAD_RE = re.compile(r"^###\s+(.+?)\s*$", re.MULTILINE)
    heads = []
    for m in _HEAD_RE.finditer(content):
        label = m.group(1).strip()
        if _NON_FLOW_HEAD.match(label):
            continue
        fm = re.match(r"(F-[A-Za-z]+-\d+)\b", label)
        heads.append((fm.group(1) if fm else label[:48],
                      m.start(), content[:m.start()].count("\n") + 1))
else:
    FLOW_HEAD = re.compile(r"^###\s+(F-[A-Za-z]+-\d+)\b", re.MULTILINE)
    heads = [(m.group(1), m.start(), content[:m.start()].count("\n") + 1)
             for m in FLOW_HEAD.finditer(content)]

if not heads:
    checks.append({"check": "vault_flow_entries", "status": "SKIP",
                   "detail": "no flow entries found"})
    result = {"status": "PASS", "checked_file": os.path.relpath(file_path, cwd),
              "checks": checks, "issues": issues,
              "summary": "no vault flow entries to check"}
    print(json.dumps(result))
    sys.exit(0)

# Each flow body ends at the NEXT heading of level <= 3 (another `### F-`, a `###`
# subsection, a `## Section`, or a `# Title`) — NOT at EOF. Bounding only on the
# next `### F-` head let the LAST flow swallow the template's trailing
# `## Out of Scope` / `## Sources` sections (and any mermaid or N/A token in them).
HEADING = re.compile(r"^#{1,3}[ \t]", re.MULTILINE)

# N/A escape: a STANDALONE marker line (optionally prefixed `**Flow**:` / `Diagram:`)
# that explicitly declares no diagram — never a body-wide substring (which matched
# a prose sentence or a bled-in `## Out of Scope` heading). "out of scope" alone is
# NOT an escape: an out-of-scope flow must still say so on its own line.
NA_LINE = re.compile(
    r"^\s*(?:\*{0,2}(?:flow|diagram)\*{0,2}\s*:\s*)?"
    r"_?(?:n/?a|none(?:\s+detected)?|no\s+(?:flow\s+)?diagram(?:\s+for\s+this\s+flow)?)_?\s*$",
    re.IGNORECASE)

bounds = []
for fid, start, line_no in heads:
    head_line_end = content.find("\n", start)
    if head_line_end < 0:
        head_line_end = len(content)
    nxt = HEADING.search(content, head_line_end + 1)
    end = nxt.start() if nxt else len(content)
    bounds.append((fid, start, end, line_no))

flow_count = 0
mermaid_count = 0
for fid, start, end, line_no in bounds:
    flow_count += 1
    body = content[start:end]
    body_line_offset = content[:start].count("\n")
    # has_mermaid is derived from ACTUAL extracted blocks, not a substring — an
    # info-string / unterminated fence yields 0 blocks and must NOT count as a diagram.
    blocks_local = extract_mermaid_blocks(body)
    if blocks_local:
        mermaid_count += 1
        blocks = []
        for bs, be, blk in blocks_local:
            adj = [(ln + body_line_offset, l) for ln, l in blk]
            blocks.append((bs + body_line_offset, be + body_line_offset, adj))
        flow_issues = check_diagram_type(blocks, fid) + check_mermaid_syntax(blocks, fid)
        for it in flow_issues:
            it.setdefault("flow_id", fid)
        issues.extend(flow_issues)
    elif any(NA_LINE.match(ln) for ln in body.splitlines()):
        # explicit non-diagram flow — allowed
        continue
    else:
        issues.append({
            "halt_type": "vault_flow_not_mermaid",
            "flow_id": fid,
            "line_number": line_no,
            "detail": (f"flow {fid} has no {FENCE}mermaid diagram — the flow body must be a "
                       "Mermaid diagram, not a prose Steps list (Mermaid-flows hard rule)"),
            "suggested_fix": (f"replace {fid}'s numbered Steps with a {FENCE}mermaid flowchart "
                              "(keep Actor/DoD/Source); see references/mermaid-emission-rules.md"),
        })

has_fail = bool(issues)
checks.append({
    "check": "vault_flow_mermaid_mandate",
    "status": "FAIL" if has_fail else "PASS",
    "detail": f"{mermaid_count}/{flow_count} flow entries carry a Mermaid diagram",
})
result = {
    "status": "FAIL" if has_fail else "PASS",
    "checked_file": os.path.relpath(file_path, cwd),
    "checks": checks,
    "issues": issues,
    "summary": (f"{len(issues)} vault-flow issue(s) — see issues[] for flow_id + line + fix"
                if issues else f"all {flow_count} vault flow(s) are Mermaid; syntax checks pass"),
}
print(json.dumps(result))
PYEOF
)

echo "$RESULT" > "$STATE_FILE" 2>/dev/null || true
[ "$QUIET" -eq 0 ] && echo "$RESULT"

STATUS=$(echo "$RESULT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('status','ERROR'))" 2>/dev/null)
case "$STATUS" in
  PASS|SKIP) exit 0 ;;
  FAIL) exit 1 ;;
  *) exit 2 ;;
esac
  ;;
  *)
    echo "usage: validate-kb.sh --surface=output|citations|flows|markers|vault-flows <flags>" >&2
    exit 2
    ;;
esac
