#!/usr/bin/env bash
# validate-conflict-classification.sh — R3: conflict classification enrichment validator.
#
# Scans binding docs for CONFLICT entries in the form bind-codebase ACTUALLY
# emits — markdown detail headings `### CONFLICT-N —` / `### C-NNN …` (per
# binding-contract.md §4 template) — as well as forward-compat ```yaml
# binding_conflict:``` blocks. For each UNRESOLVED conflict, checks whether it
# carries `conflict_class` + `resolution_complexity` enrichment.
# Missing fields → WARN (backward-compatible, not FAIL). Resolved conflicts
# (✅ / "RESOLVED" marker) are exempt — classification is moot once resolved.
#
# Iter-79 X-1: prior version greped ONLY for ```yaml binding_conflict:``` blocks
# that the producer template never emits, so it SKIPped on every real binding
# (vacuous gate) and was wired to no hook. This version detects the real
# markdown structure AND is dispatched PostToolUse on binding.md write (advisory).
#
# Inputs: --cwd=<project> [--file-path=<path>] [--quiet]
# Outputs: <cwd>/.mega-sdd/.conflict-classification-state.json
# Exit: 0=PASS/SKIP/WARN, 1=FAIL (structural parse error), 2=error

set -uo pipefail

CWD=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --file-path=*) : ;;  # accepted for dispatch-helper compatibility; not used
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
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.conflict-classification-state.json"

RESULT=$(CWD="$CWD" python3 <<'PYEOF'
import json
import os
import re
import glob

cwd = os.environ["CWD"]
issues = []
conflicts_total = 0
conflicts_classified = 0
conflicts_unclassified = 0
conflicts_resolved = 0

binding_files = sorted(
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "binding.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "*", "*-bound", "binding*.md")) +
    glob.glob(os.path.join(cwd, ".mega-sdd", "vaults", "binding*.md"))
)

# A conflict ID, normalized (CONFLICT-1, C-004). Detail headings look like:
#   ### CONFLICT-1 — App\Models\Product name collision
#   ### ✅ CONFLICT-1 RESOLVED — 2026-05-29...
#   ### C-004 (Phase 1 surface): ConsumptionReason enum cases — CONFLICT (NON-BLOCKING)
HEADING_RE = re.compile(
    r"^#{2,4}\s+(?:[✅❌⚠️]\s*)*((?:CONFLICT-\d+)|(?:C-\d{2,}))\b(.*)$",
    re.MULTILINE,
)
# Forward-compat: structured ```yaml ... binding_conflict: ... id: CONFLICT-N``` blocks.
YAML_BLOCK_RE = re.compile(r"```ya?ml\s*\n(.*?)```", re.DOTALL)
CLASS_RE = re.compile(r"(?:^|\n)\s*[-*]?\s*\*{0,2}conflict_class\*{0,2}\s*[:=]\s*\S", re.IGNORECASE)
COMPLEXITY_RE = re.compile(r"(?:^|\n)\s*[-*]?\s*\*{0,2}resolution_complexity\*{0,2}\s*[:=]\s*\S", re.IGNORECASE)
RESOLVED_RE = re.compile(r"✅|\bRESOLVED\b", re.IGNORECASE)


def section_block(content, start_idx):
    """Body from the heading at start_idx up to the next heading of any level.
    Search begins AFTER the heading's own line so the heading's leftover `##`
    can't re-match (which would truncate the block to a single char)."""
    nl = content.find("\n", start_idx)
    scan_from = nl + 1 if nl != -1 else len(content)
    nxt = re.search(r"^#{1,6}\s", content[scan_from:], re.MULTILINE)
    end = scan_from + nxt.start() if nxt else len(content)
    return content[start_idx:end]


for bf in binding_files:
    if "/.archived/" in bf:
        continue
    try:
        content = open(bf, errors="replace").read()
    except Exception:
        continue

    # Per-conflict-ID aggregation across all of its sections/blocks in this file.
    # state: {"classified": bool(any section had both fields), "resolved": bool}
    per_id = {}

    # (a) markdown detail-heading sections (the form bind-codebase actually emits)
    for m in HEADING_RE.finditer(content):
        cid = m.group(1)
        block = section_block(content, m.start())
        st = per_id.setdefault(cid, {"classified": False, "resolved": False})
        if RESOLVED_RE.search(m.group(0)) or RESOLVED_RE.search(block):
            st["resolved"] = True
        if CLASS_RE.search(block) and COMPLEXITY_RE.search(block):
            st["classified"] = True

    # (b) forward-compat structured yaml blocks
    for block in YAML_BLOCK_RE.findall(content):
        if "binding_conflict:" not in block and "id: CONFLICT-" not in block:
            continue
        idm = re.search(r"id:\s*((?:CONFLICT-\d+)|(?:C-\d{2,}))", block)
        cid = idm.group(1) if idm else f"CONFLICT-?-{len(per_id) + 1}"
        st = per_id.setdefault(cid, {"classified": False, "resolved": False})
        if RESOLVED_RE.search(block):
            st["resolved"] = True
        if CLASS_RE.search(block) and COMPLEXITY_RE.search(block):
            st["classified"] = True

    for cid, st in per_id.items():
        conflicts_total += 1
        if st["resolved"]:
            conflicts_resolved += 1
            continue  # resolved conflicts are exempt from classification
        if st["classified"]:
            conflicts_classified += 1
        else:
            conflicts_unclassified += 1
            issues.append({
                "halt_type": "conflict_classification_missing",
                "conflict_id": cid,
                "binding_file": os.path.relpath(bf, cwd),
                "missing_fields": ["conflict_class", "resolution_complexity"],
                "detail": (
                    f"{cid} in {os.path.basename(bf)}: active conflict missing "
                    f"conflict_class/resolution_complexity enrichment"
                ),
            })

active = conflicts_total - conflicts_resolved
if conflicts_total == 0:
    status = "SKIP"
    detail = "no CONFLICT entries found in any binding doc"
elif active == 0:
    status = "PASS"
    detail = f"all {conflicts_total} CONFLICTs resolved; no active conflicts to classify"
elif conflicts_unclassified > 0:
    status = "WARN"
    detail = (
        f"{conflicts_classified}/{active} active CONFLICTs classified; "
        f"{conflicts_unclassified} missing conflict_class/resolution_complexity "
        f"({conflicts_resolved} resolved, exempt)"
    )
else:
    status = "PASS"
    detail = f"all {active} active CONFLICTs have conflict_class + resolution_complexity ({conflicts_resolved} resolved)"

result = {
    "status": status,
    "conflicts_total": conflicts_total,
    "conflicts_resolved": conflicts_resolved,
    "conflicts_classified": conflicts_classified,
    "conflicts_unclassified": conflicts_unclassified,
    "issues": issues,
    "summary": detail,
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
