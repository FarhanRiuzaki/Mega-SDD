#!/usr/bin/env bash
# validate-fsd-slots.sh — Phase B slice B.5 [PostToolUse-validate].
#
# Walking-skeleton scope: ONE of 3 quality_gate subtype halts:
#   - quality_gate_failed:template_slot_unfilled
#     (FSD.md output contains unfilled `{{slot_name}}` placeholder)
#
# Other B.5 subtypes deferred to follow-up slices:
#   - pdf_render_failed: needs PostToolUse Bash matcher with pandoc detection
#   - starterkit_metrics_inconsistent: in-skill prose recomputation (orchestrate-flow / generate-units; the old Skill-matcher validator was deleted v7.5.0 №C)
#
# Per attestation: this is detection-only at hook layer; auto-fix is emit-fsd's
# template-mapping responsibility.
#
# Inputs: --cwd, --file-path (the FSD.md or similar template output)
# Outputs: writes .mega-sdd/.fsd-slots-state.json
# Exit: 0=PASS, 1=FAIL.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
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

[ -z "$CWD" ] && exit 2
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# Only check FSD *output* files. emit-fsd writes <vault>/fsd/FSD.md, so match
# either a file named *FSD.md or any .md inside an fsd/ directory. The old
# `*fsd*.md` arm matched the plugin's OWN authoring files (skills/emit-fsd/SKILL.md,
# emit-fsd/references/*.md) whose `{{slot}}` examples are documentation, not unfilled
# output — a false FAIL. Those are excluded now (R3-12).
case "$FILE_PATH" in
  *FSD.md|*/fsd/*.md) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.fsd-slots-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel = os.path.relpath(file_path, cwd)

try:
    content = open(file_path).read()
except Exception:
    sys.exit(0)

# Find unfilled template slots: pattern `{{slot_name}}` (mustache-style).
# Strip fenced code blocks first (``` or ~~~): a generated FSD may legitimately
# document the template syntax inside a fence, and those `{{slot}}` examples are
# not unfilled output (R3-12 — implements the exclusion the comment long promised).
scan = re.sub(r"```.*?```", "", content, flags=re.DOTALL)
scan = re.sub(r"~~~.*?~~~", "", scan, flags=re.DOTALL)
slot_pattern = re.compile(r"\{\{\s*([\w_-]+)\s*\}\}")
matches = slot_pattern.findall(scan)
unique_slots = sorted(set(matches))

issues = []
if unique_slots:
    issues.append({
        "halt_type": "template_slot_unfilled",
        "detail": f"FSD output {rel} contains {len(unique_slots)} unfilled template slot(s)",
        "fsd_path": rel,
        "unfilled_slots": unique_slots,
        "total_occurrences": len(matches),
        "quality_gate_subtype": "template_slot_unfilled",
    })

status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "next_action": (
        "FSD template slots all filled."
        if status == "PASS"
        else f"Unfilled slot(s) detected: {unique_slots}. Skill-author bug in section-mapping.md OR template emission. Re-run /mega-sdd:emit fsd with --sections=<subset> to skip affected sections OR file plugin bug."
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
