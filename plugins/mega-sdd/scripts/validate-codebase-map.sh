#!/usr/bin/env bash
# validate-codebase-map.sh — R6: codebase-map schema validation.
#
# Checks codebase-map.md has all 7 required sections and valid frontmatter.
# Probes the same locations bind-codebase binds against (canonical
# .mega-sdd/codebase/codebase-map.md, then legacy <root>/codebase-map.md),
# or validates an explicit --file-path.
#
# Inputs: --cwd=<project> [--file-path=<map>] [--quiet]
# Outputs: <cwd>/.mega-sdd/.codebase-map-state.json
# Exit: 0=PASS/SKIP/WARN, 1=FAIL, 2=error

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

STATE_FILE="${CWD}/.mega-sdd/.codebase-map-state.json"
# A true legacy-layout project (<root>/codebase-map.md, no .mega-sdd/ yet) has no
# state dir — without this the state write fails silently and the DEGENERATE gate
# reads nothing (fail-open on the exact layout the legacy probe exists for).
mkdir -p "${CWD}/.mega-sdd" 2>/dev/null
# S3 V7: probe order mirrors bind-codebase SKILL.md (canonical → legacy root) so
# the map the binder actually binds against is the map that gets validated.
# An EXPLICIT --file-path that doesn't exist is a usage error (exit 2, state
# untouched) — never silently substitute a probed map for the asked-for file.
MAP_PATH=""
if [ -n "$FILE_PATH" ] && [ ! -f "$FILE_PATH" ]; then
  echo "validate-codebase-map: --file-path not found: $FILE_PATH" >&2
  exit 2
fi
if [ -n "$FILE_PATH" ]; then
  MAP_PATH="$FILE_PATH"
elif [ -f "${CWD}/.mega-sdd/codebase/codebase-map.md" ]; then
  MAP_PATH="${CWD}/.mega-sdd/codebase/codebase-map.md"
elif [ -f "${CWD}/codebase-map.md" ]; then
  MAP_PATH="${CWD}/codebase-map.md"
fi

if [ -z "$MAP_PATH" ]; then
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

# S3 V5: a heading (or frontmatter field) quoted inside a fenced code block is
# NOT a section — a degenerate map echoing the schema's own fenced skeleton must
# not satisfy the presence checks. Strip fenced blocks before structural checks.
BACKTICK_FENCE = "\x60\x60\x60"  # three backticks, \x60-escaped: a literal odd-count backtick run breaks bash-3.2 $() heredoc parsing


def strip_fenced(text):
    out, in_fence, fence_tok = [], False, ""
    for line in text.split("\n"):
        stripped = line.lstrip()
        if not in_fence and (stripped.startswith(BACKTICK_FENCE) or stripped.startswith("~~~")):
            in_fence, fence_tok = True, stripped[:3]
            continue
        if in_fence and stripped.startswith(fence_tok):
            in_fence = False
            continue
        if not in_fence:
            out.append(line)
    return "\n".join(out)

body = strip_fenced(content)

# Check 1: frontmatter present (must open the file; fields are line-anchored keys)
fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
if not fm_match:
    issues.append({"halt_type": "codebase_map_no_frontmatter", "detail": "missing YAML frontmatter"})
    checks.append({"check": "frontmatter_present", "status": "FAIL"})
else:
    checks.append({"check": "frontmatter_present", "status": "PASS"})
    fm = fm_match.group(1)
    # S3 V6: `engine` is schema-required (bind-codebase keys precision behavior
    # off it); a map without it predates the precision contract → re-scan.
    required_fm = ["generated_by", "generated_at", "repo_root", "languages_detected", "engine"]
    for field in required_fm:
        if not re.search(r"^\s*" + re.escape(field) + r"\s*:", fm, re.MULTILINE):
            issues.append({"halt_type": "codebase_map_fm_missing", "detail": f"frontmatter missing: {field}"})
            checks.append({"check": f"fm_{field}", "status": "FAIL"})
        else:
            checks.append({"check": f"fm_{field}", "status": "PASS"})
    # S3 V6: staleness stamp — the whole incremental/sync lane keys off
    # last_scanned_commit; in a git repo its absence silently disables that lane.
    # WARN (advisory): non-git repos legitimately omit it (schema: OPTIONAL), and a
    # zero-commit repo (no resolvable HEAD) legitimately omits it too. A stamp whose
    # VALUE is the literal string "HEAD" is the zero-commit-era poison shape the
    # procedure defines as missing (scan-procedure §Step 10) — WARN, not PASS.
    if os.path.exists(os.path.join(cwd, ".git")):
        import subprocess
        try:
            _head_ok = subprocess.run(
                ["git", "-C", cwd, "rev-parse", "--verify", "HEAD^{commit}"],
                capture_output=True, timeout=10).returncode == 0
        except Exception:
            _head_ok = True  # can't probe → keep the check active
        stamp_m = re.search(r"^\s*last_scanned_commit\s*:\s*(\S+)", fm, re.MULTILINE)
        stamp_val = stamp_m.group(1).strip("'\"") if stamp_m else None
        if stamp_val == "HEAD":
            issues.append({"halt_type": "codebase_map_staleness_stamp_missing",
                           "detail": "last_scanned_commit is the literal string 'HEAD' (zero-commit-era "
                                     "poisoned stamp) — consumers treat it as missing; a re-scan restamps."})
            checks.append({"check": "fm_last_scanned_commit", "status": "WARN"})
        elif stamp_val is None and _head_ok:
            issues.append({"halt_type": "codebase_map_staleness_stamp_missing",
                           "detail": "repo has .git but frontmatter lacks last_scanned_commit — "
                                     "incremental sync (--changed-only) and drift staleness checks "
                                     "degrade to full comparison until the next full scan restamps."})
            checks.append({"check": "fm_last_scanned_commit", "status": "WARN"})
        else:
            checks.append({"check": "fm_last_scanned_commit", "status": "PASS"})

# Check 2: 7 required sections present — line-anchored headings on fence-stripped body
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
    num = prefix.split()[1]
    if not re.search(r"^##\s*" + re.escape(num) + r"[.\s]", body, re.MULTILINE):
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
# S3 V5: sliced from the fence-stripped body, heading line-anchored.
sec2_match = re.search(r"^## 2[.\s].*?\n(.*?)(?=\n## 3|\Z)", body, re.DOTALL | re.MULTILINE)


SEC2_HEADER_TOKENS = {"file", "type", "symbol", "signature", "kind", "last_scanned_sha256"}


def parse_sec2(sec2_body):
    """Parsed §2 table → (header_cells_or_None, data_rows). Header-aware: real
    maps vary column order, so the Signature column is located by name."""
    all_rows = []
    for line in sec2_body.split("\n"):
        line = line.strip()
        if not (line.startswith("|") and line.endswith("|") and line.count("|") >= 3):
            continue
        cells = [c.strip() for c in line.split("|")[1:-1]]
        if all(re.fullmatch(r":?-{2,}:?", c or "--") for c in cells):
            continue  # separator row
        all_rows.append(cells)
    header = None
    if all_rows and any(c.lower() in SEC2_HEADER_TOKENS for c in all_rows[0]):
        header = all_rows[0]
        all_rows = all_rows[1:]
    return header, all_rows


if sec2_match:
    sec2 = sec2_match.group(1)
    _, rows = parse_sec2(sec2)
    data_rows = len(rows)
    if data_rows == 0:
        checks.append({"check": "interfaces_populated", "status": "WARN",
                       "detail": "§2 Public interfaces has 0 data rows"})
    else:
        checks.append({"check": "interfaces_populated", "status": "PASS",
                       "detail": f"§2 has {data_rows} interface rows"})

# Check 4 (Iter-79 U-SC): DEPTH — the map's only consumer (bind-codebase field-level
# diff) REQUIRES `precision_tier: ast` + signature-bearing §2 rows; on regex it degrades
# to binary classification. Prior validator checked §2 ROW COUNT only, never row DEPTH —
# a map of bare symbol names passed while silently degrading binding. Advisory (WARN):
#   - precision_tier: ast  but no §2 row carries a signature token (param/field list) →
#     codebase_map_depth_claim_unmet (claims ast precision; binding will get bare names).
#   - precision_tier: regex (or absent)  → note that binding field-diff degrades to binary.
precision_tier = None
if fm_match:
    pt = re.search(r"^\s*precision_tier\s*:\s*([A-Za-z_]+)", fm_match.group(1), re.MULTILINE)
    precision_tier = pt.group(1).lower() if pt else None

if sec2_match:
    # S3 V1: heuristics run on the Signature CELL only — scanning the whole row
    # let the `:42` in the mandated File-column `path.ts:42` citation satisfy
    # the typed-field pattern, making every conformant map count as
    # signature-bearing (dead detection). The cell is located by header name
    # (schema position 4 when the table has no header); a table with NO
    # Signature column carries no signatures by construction.
    sec2_header, sec2_rows = parse_sec2(sec2_match.group(1))
    if sec2_header is not None:
        sig_idx = next((i for i, c in enumerate(sec2_header) if c.lower() == "signature"), None)
    else:
        sig_idx = 3
    sig_rows = 0
    if sig_idx is not None:
        for cells in sec2_rows:
            sig_cell = cells[sig_idx] if len(cells) > sig_idx else ""
            if re.search(r"\([^)]*\)", sig_cell) or re.search(r"\w+\s*:\s*\w+", sig_cell):
                sig_rows += 1
    if precision_tier == "ast":
        if sig_rows == 0:
            issues.append({
                "halt_type": "codebase_map_depth_claim_unmet",
                "detail": "frontmatter declares precision_tier: ast but no §2 Public-interfaces "
                          "row carries a signature (param/field list) — bind-codebase field-level "
                          "diff will silently degrade to binary classification.",
            })
            checks.append({"check": "interface_depth", "status": "WARN",
                           "detail": "precision_tier: ast but §2 rows carry no signatures"})
        else:
            checks.append({"check": "interface_depth", "status": "PASS",
                           "detail": f"precision_tier: ast with {sig_rows} signature-bearing §2 row(s)"})
    elif precision_tier == "regex":
        checks.append({"check": "interface_depth", "status": "WARN",
                       "detail": "precision_tier: regex — bind-codebase field-level diff degrades "
                                 "to binary classification (no per-field ADD/KEEP/REMOVE)."})
    else:
        checks.append({"check": "interface_depth", "status": "WARN",
                       "detail": "frontmatter declares no precision_tier — binding cannot tell "
                                 "whether field-level diff is available; add precision_tier: ast|regex."})

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
