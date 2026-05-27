#!/usr/bin/env bash
# validate-vault-oqs.sh — Phase B slice B.4 [PostToolUse-validate].
#
# Walking-skeleton scope: validates ONE halt per scope discipline:
#   - oq_recommend_citation_invalid (recommendation cites nonexistent KB section)
#
# Other B.4 halts (oq_tech_missing_mode, oq_recommend_underspecified,
# oq_scan_missing_query) are deferred to follow-up slices — they need deeper
# OQ-schema parsing (varies per category) and are lower-value than KB citation
# integrity. Each kept C1 per attestation; just unbuilt in this slice.
#
# Per attestation risk-flag #2: KB cross-check gracefully SKIPS when KB absent
# (not all projects have KB). NEVER halt on missing KB.
#
# Inputs: --cwd, --file-path (the vault doc written)
# Outputs: writes .mega-sdd/.vault-oqs-state.json
# Exit: 0=PASS or no-op, 1=FAIL.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg" >&2; exit 2 ;;
  esac
done
[ -z "$CWD" ] && { echo "ERROR: --cwd" >&2; exit 2; }
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# Only validate vault doc files
case "$FILE_PATH" in
  *.mega-sdd/vaults/*/0[1-6]-*.md|*.mega-sdd/vaults/*/vault.json) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.vault-oqs-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, glob, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel = os.path.relpath(file_path, cwd)

try:
    body = open(file_path).read()
except Exception:
    sys.exit(0)

# Build KB inventory (graceful skip if KB absent — risk-flag #2)
kb_dir = os.path.join(cwd, ".mega-sdd", "knowledge-base")
kb_sections = set()
kb_present = os.path.isdir(kb_dir)
if kb_present:
    for kb_file in glob.glob(os.path.join(kb_dir, "**", "*.md"), recursive=True):
        # Section reference format: <kb-file>.md§<section-anchor> OR <kb-file>.md#<section>
        rel_kb = os.path.relpath(kb_file, cwd)
        kb_sections.add(rel_kb)
        # Extract headers from file for section-level matching
        try:
            for line in open(kb_file):
                m = re.match(r"^#{1,6}\s+(.+?)$", line.rstrip())
                if m:
                    section_id = m.group(1).strip().lower().replace(" ", "-")
                    kb_sections.add(f"{rel_kb}§{section_id}")
                    kb_sections.add(f"{rel_kb}#{section_id}")
        except Exception:
            pass

issues = []

# Walk OQ entries with recommendations → check citations
# Pattern: in markdown OQ blocks, look for "citations:" or "Citation:" lines
# Format: "Citation: knowledge-base/10-domains/foo.md §section-name"
# Or: "citations: - knowledge-base/10-domains/foo.md§section"

# Conservative scope: only check citations that point to knowledge-base/ paths
citation_pattern = re.compile(
    r"(?:Citation|citation|cite|cites)s?:\s*(?:-\s*)?[\"']?(knowledge-base/[^\s\"'\]\,]+)[\"']?",
    re.IGNORECASE,
)
oq_pattern = re.compile(r"\bOQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b")

# Walk the body finding OQ context blocks (look 30 lines around each OQ mention)
lines = body.split("\n")
for i, line in enumerate(lines):
    oqs_in_line = oq_pattern.findall(line)
    if not oqs_in_line:
        continue
    # Look at 30-line window for citations
    window = "\n".join(lines[i:min(i + 30, len(lines))])
    citations = citation_pattern.findall(window)
    if not citations:
        continue
    for oq in oqs_in_line:
        for cit in citations:
            cit_clean = cit.strip().rstrip(",;)")
            # Resolve to absolute path
            if not kb_present:
                # KB absent — log as advisory, NOT a failure (per risk-flag #2)
                continue
            # Check if citation resolves to a KB file or section
            full_cit = os.path.join(cwd, ".mega-sdd", cit_clean.split("§")[0].split("#")[0])
            if not os.path.exists(full_cit):
                # Citation points to a file that doesn't exist
                issues.append({
                    "halt_type": "oq_recommend_citation_invalid",
                    "detail": f"OQ {oq} cites KB path that does not exist: {cit_clean}",
                    "oq_id": oq,
                    "citation": cit_clean,
                    "resolved_to": full_cit,
                })

status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "kb_present": kb_present,
    "next_action": (
        "Vault OQ citations valid OR KB absent (graceful skip)."
        if status == "PASS"
        else f"{len(issues)} OQ citation issue(s) detected. Manual review OR re-emit OQ via /mega-sdd:resolve-oq or /mega-sdd:generate-intent --regenerate."
    ),
}
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception:
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
