#!/usr/bin/env bash
# validate-bolt-artifacts.sh — Phase B slice B.2 [PostToolUse-validate].
#
# Validates 3 bolt-related artifact integrity halts in one pass:
#   - provenance_missing       (modified file lacks provenance trailer)
#   - self_assessment_missing  (bolt-report.md lacks bolt_self_report YAML block)
#   - pbt_citation_invalid     (unit PBT property cites nonexistent ADR)
#
# Per attestation: all 3 are C1 detection-only at hook layer (auto-fix needs
# bolt context which only skill body has). Hook detects + emits warning
# telemetry + chat notice. Skill body / human resolves.
#
# Inputs: --cwd=<project> --file-path=<written-file>
# Outputs: JSON report to stdout; writes .mega-sdd/.bolt-artifacts-state.json
# Exit codes: 0=PASS, 1=FAIL (one or more issues detected), 2=error.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
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


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required" >&2
  exit 2
fi

# FILE_PATH is the written file. May or may not exist (Edit happens, then validator
# reads it). If missing → skip (write must have failed).
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  # No file to validate; emit a no-op state.
  exit 0
fi

STATE_FILE="${CWD}/.mega-sdd/.bolt-artifacts-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: cannot create state dir" >&2; exit 2; }

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel_path = os.path.relpath(file_path, cwd)

# Determine which checks apply based on path
checks_to_run = []  # list of (check_name, callable)
issues = []  # list of {check, halt_type, detail}

def is_bolt_report(p):
    """Match: <vault>/bolts/U-*/bolt-report.md (under .mega-sdd/vaults or just vaults)"""
    return bool(re.search(r"(?:^|/)bolts/U-[^/]+/bolt-report\.md$", p))

def is_unit_path(p):
    """Match unit file (both layouts: U-*.md OR U-*/unit.md) under *-bound/units/"""
    if re.search(r"-bound/units/U-[^/]+\.md$", p):
        return True
    if re.search(r"-bound/units/U-[^/]+/unit\.md$", p):
        return True
    return False

def find_unit_for_target(target_path):
    """
    Find any unit file whose target_files list contains target_path.
    Returns (unit_file_path, unit_id) or (None, None).
    Walks both unit layouts.
    """
    abs_target = os.path.abspath(target_path)
    # Make target_path relative variants (units may declare relative paths)
    rel_target_from_cwd = os.path.relpath(abs_target, cwd) if abs_target.startswith(cwd) else None

    unit_paths = sorted(
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*.md")) +
        glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "units", "U-*", "unit.md"))
    )
    for up in unit_paths:
        try:
            body = open(up).read()
        except Exception:
            continue
        m = re.match(r"^---\n(.*?)\n---", body, re.DOTALL)
        if not m:
            continue
        fm = m.group(1)
        # Walk target_files block — line-based extraction (same pattern as session-start verify_unit_writable)
        fm_lines = fm.split("\n")
        in_block = False
        for ln in fm_lines:
            if ln.startswith("target_files:"):
                in_block = True
                continue
            if in_block:
                if ln and ln[0] not in " \t":
                    break
                # Look for `- path: X` or `path: X` lines
                pm = re.search(r"path:\s*(\S+)", ln)
                if pm:
                    candidate = pm.group(1).strip().strip("'\"")
                    # Compare against relative target
                    if rel_target_from_cwd and (
                        candidate == rel_target_from_cwd
                        or rel_target_from_cwd.endswith("/" + candidate)
                        or candidate.endswith("/" + rel_target_from_cwd)
                    ):
                        # Extract unit_id from frontmatter
                        uid_match = re.search(r"^(?:unit_id|id):\s*(\S+)", fm, re.MULTILINE)
                        uid = uid_match.group(1) if uid_match else os.path.basename(up).replace(".md", "")
                        return (up, uid)
    return (None, None)

# ─── Check 1: provenance_missing ────────────────────────────────────────────
# Triggers when written file is bolt-modified (i.e., listed in some unit's target_files).
# Provenance trailer format (per execute-bolts/references/bolt-dispatch-prompt.md):
#   Generated by mega-sdd execute-bolts <version>
#   Unit: U-XXX (vault sha256: <hash>)
#   Implements claim: C-NNN "..."
#   Anchors consulted: ...
#   Hard Rules active: ...
# We detect by looking for the marker line "Generated by mega-sdd execute-bolts" in
# the first 30 lines (top-of-file, comment-block-tolerant).
unit_file, unit_id = find_unit_for_target(file_path)
if unit_file is not None:
    try:
        with open(file_path) as f:
            head = "".join(f.readline() for _ in range(30))
    except Exception:
        head = ""
    if "Generated by mega-sdd execute-bolts" not in head:
        issues.append({
            "halt_type": "provenance_missing",
            "detail": f"bolt-modified file {rel_path} (unit {unit_id}) lacks provenance trailer in first 30 lines",
            "unit_id": unit_id,
            "unit_path": os.path.relpath(unit_file, cwd),
            "expected_marker": "Generated by mega-sdd execute-bolts",
        })

# ─── Check 2: self_assessment_missing ───────────────────────────────────────
# Triggers when written file is bolt-report.md. Looks for `bolt_self_report:` YAML key.
if is_bolt_report(file_path):
    try:
        content = open(file_path).read()
    except Exception:
        content = ""
    if "bolt_self_report:" not in content:
        # Extract unit_id from path
        m = re.search(r"bolts/(U-[^/]+)/bolt-report\.md", file_path)
        uid = m.group(1) if m else "unknown"
        issues.append({
            "halt_type": "self_assessment_missing",
            "detail": f"bolt-report.md for {uid} lacks bolt_self_report YAML block",
            "unit_id": uid,
            "bolt_report_path": rel_path,
            "expected_key": "bolt_self_report:",
        })

# ─── Check 3: pbt_citation_invalid ──────────────────────────────────────────
# Triggers when written file is a unit (PBT properties live in unit body).
# Format: `Cites: §Decision-D-NNN` or `Cites: §D-NNN`.
# Validates each cited D-NNN exists in <cwd>/.mega-sdd/vaults/*/decisions/<D-NNN>.md
# OR <cwd>/.mega-sdd/vaults/*-bound/decisions/<D-NNN>.md.
if is_unit_path(file_path):
    try:
        body = open(file_path).read()
    except Exception:
        body = ""
    # Find Cites references — match Cites: §Decision-D-NNN, Cites: §D-NNN, Cites: D-NNN
    cite_pattern = re.compile(r"Cites:\s*§?(?:Decision-)?(D-[A-Z0-9-]*\d+)", re.IGNORECASE)
    cited = set(cite_pattern.findall(body))
    if cited:
        # Build inventory of available decision IDs from vault decisions/
        available = set()
        for dec_dir in glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "decisions")) + \
                       glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*-bound", "decisions")):
            for f in glob.glob(os.path.join(dec_dir, "*.md")):
                # Filename pattern: D-NNN.md or D-P2-NNN.md etc.
                fname = os.path.basename(f).replace(".md", "")
                if fname.startswith("D-"):
                    available.add(fname)
        # Cross-check
        missing = sorted([c for c in cited if c not in available])
        if missing:
            uid_match = re.search(r"unit_id:\s*(\S+)|id:\s*(\S+)", body)
            uid = uid_match.group(1) or uid_match.group(2) if uid_match else "unknown"
            issues.append({
                "halt_type": "pbt_citation_invalid",
                "detail": f"unit {uid} PBT property cites ADR(s) not found in vault decisions/",
                "unit_id": uid,
                "unit_path": rel_path,
                "missing_decisions": missing,
                "available_decisions_count": len(available),
            })

# ─── Build state file ───────────────────────────────────────────────────────
status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel_path,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "next_action": (
        "Bolt artifacts pass integrity checks." if status == "PASS"
        else f"{len(issues)} integrity issue(s) detected. Each is detection-only (no auto-fix at hook layer); review listed issues and amend unit/bolt-report manually OR re-run execute-bolts with --strict-provenance flag."
    ),
}

# Read prior state to track retry/persistence (current-truth overwrite)
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"ERROR: cannot write state file: {e}", file=sys.stderr)
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
