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
# Resolve project root (Iter 71 — class-bug fix: if invoked from a sub-folder
# like .mega-sdd/knowledge-base/, walk UP to the outermost .mega-sdd/ parent
# so state files land in the canonical location, not nested .mega-sdd/.mega-sdd/).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

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

# Walk the body. Build per-OQ blocks: text from OQ mention up to (but excluding)
# the next OQ mention. This avoids the bug where OQ-A's metadata window catches
# OQ-B's `mode:` line (15-line proximity false-positives).
lines = body.split("\n")

# First pass: find all OQ-line indices
oq_anchors = []  # list of (line_idx, [oq_ids_in_line])
for i, line in enumerate(lines):
    found = oq_pattern.findall(line)
    if found:
        oq_anchors.append((i, found))

# Build per-OQ blocks
oq_blocks = []  # list of (oq_id, block_text)
for idx, (line_i, oqs) in enumerate(oq_anchors):
    # Block ends at next OQ anchor OR 30 lines later (whichever first)
    if idx + 1 < len(oq_anchors):
        block_end = min(oq_anchors[idx + 1][0], line_i + 30)
    else:
        block_end = min(line_i + 30, len(lines))
    block = "\n".join(lines[line_i:block_end])
    for oq in oqs:
        oq_blocks.append((oq, block))

processed_oqs = set()
for oq, window in oq_blocks:
        # ─── Check oq_recommend_citation_invalid (original) ─────────────────
        citations = citation_pattern.findall(window)
        for cit in citations:
            cit_clean = cit.strip().rstrip(",;)")
            if not kb_present:
                continue  # graceful skip (risk-flag #2)
            full_cit = os.path.join(cwd, ".mega-sdd", cit_clean.split("§")[0].split("#")[0])
            if not os.path.exists(full_cit):
                issues.append({
                    "halt_type": "oq_recommend_citation_invalid",
                    "detail": f"OQ {oq} cites KB path that does not exist: {cit_clean}",
                    "oq_id": oq,
                    "citation": cit_clean,
                    "resolved_to": full_cit,
                })

        # Skip schema checks if we already processed this OQ
        if oq in processed_oqs:
            continue
        processed_oqs.add(oq)

        # ─── B.4-followup: detect OQ category + mode for schema checks ───────
        # Category indicator: `[tech]` or `[business]` in OQ line, OR `category: tech` field
        has_tech_category = bool(re.search(r"\[tech\]|category:\s*tech", window, re.IGNORECASE))
        has_business_category = bool(re.search(r"\[business\]|category:\s*business", window, re.IGNORECASE))

        # mode: line in window
        mode_match = re.search(r"^\s*[-*]?\s*mode:\s*(\w+)", window, re.MULTILINE)
        mode_value = mode_match.group(1).lower() if mode_match else None

        # ─── Check oq_tech_missing_mode ──────────────────────────────────────
        # Tech-categorized OQ without mode: field
        if has_tech_category and not mode_value:
            issues.append({
                "halt_type": "oq_tech_missing_mode",
                "detail": f"OQ {oq} categorized [tech] but missing `mode:` field (expected `mode: scan` or `mode: recommend`)",
                "oq_id": oq,
                "category": "tech",
            })

        # ─── Check oq_scan_missing_query ─────────────────────────────────────
        # mode=scan OQ requires `scan_target:` field within window
        if mode_value == "scan":
            scan_target_match = re.search(r"^\s*[-*]?\s*scan_target:\s*\S+", window, re.MULTILINE)
            if not scan_target_match:
                issues.append({
                    "halt_type": "oq_scan_missing_query",
                    "detail": f"OQ {oq} has `mode: scan` but missing `scan_target:` field",
                    "oq_id": oq,
                    "mode": "scan",
                })

        # ─── Check oq_recommend_underspecified ───────────────────────────────
        # mode=recommend OQ requires recommendation, rationale, citations fields
        if mode_value == "recommend":
            required_fields = ["recommendation", "rationale"]
            # Citations are loose — accept either Citation: or citations: or cites:
            has_citation = bool(re.search(r"^\s*[-*]?\s*(?:Citation|citation|cite|cites|citations):", window, re.MULTILINE))
            missing_fields = []
            for f in required_fields:
                if not re.search(rf"^\s*[-*]?\s*{f}:", window, re.MULTILINE | re.IGNORECASE):
                    missing_fields.append(f)
            if not has_citation:
                missing_fields.append("citation|citations")
            if missing_fields:
                issues.append({
                    "halt_type": "oq_recommend_underspecified",
                    "detail": f"OQ {oq} has `mode: recommend` but missing required field(s): {missing_fields}",
                    "oq_id": oq,
                    "mode": "recommend",
                    "missing_fields": missing_fields,
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
