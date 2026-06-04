#!/usr/bin/env bash
# validate-extraction-scorecard.sh — [HOOK-VALIDATE] Extraction Completeness Contract checker.
#
# Validates the `.extraction-scorecard.json` emitted by extract-intelligence Wave 5
# (per skills/extract-intelligence/SKILL.md §Extraction Completeness Contract) against
# the five extraction principles (P1 state provenance, P2 rule enumeration, P3
# behaviour-as-executed, P4 structural classification, P5 staged inputs).
#
# Verdicts:
#   SKIP  — no scorecard present (pre-v3.72.0 KB, or extraction didn't emit one).
#           Back-compat: absence NEVER fails (advisory contract, not retroactive).
#   PASS  — scorecard present + internally consistent + no hidden gap.
#   FAIL  — scorecard is INTERNALLY INCONSISTENT (claims PASS but a principle is not
#           COVERED) OR hides a gap (a PARTIAL/MISSING principle with ZERO `[OPEN]`
#           markers anywhere in the KB — the silent-drift failure mode this contract
#           exists to catch).
#
# Wiring stance (v3.72.0): ADVISORY — consumed by bind-codebase as a preflight consult.
# NOT wired to a blocking PreToolUse hook branch this iter (keystone B1 is real as a
# runnable verdict; hard-blocking is a separable follow-up to protect the existing
# hook invariants — Iter-78.1 / Iter-79 / semantic-depth #6/#7).
#
# Usage: validate-extraction-scorecard.sh --cwd=<project> [--kb-dir=<path>] [--quiet]
# Output: <cwd>/.mega-sdd/.extraction-scorecard-state.json
# Exit: 0=PASS/SKIP, 1=FAIL, 2=error

set -uo pipefail

CWD=""
KB_DIR=""
QUIET=0

for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#--cwd=}" ;;
    --kb-dir=*) KB_DIR="${arg#--kb-dir=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

# Resolve project root (Iter 71 class-bug fix — walk UP to outermost .mega-sdd/ parent).
_RPR_HELPER="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi

if [ -z "$CWD" ]; then CWD="$(pwd)"; fi

# Resolve KB dir: explicit flag wins; else probe canonical then legacy locations.
if [ -z "$KB_DIR" ]; then
  for cand in \
    "${CWD}/.mega-sdd/knowledge-base" \
    "${CWD}/docs/knowledge-base" \
    "${CWD}/docs/mega-sdd/knowledge-base" \
    "${CWD}/old-reference/knowledge-base"; do
    if [ -d "$cand" ]; then KB_DIR="$cand"; break; fi
  done
fi

STATE_FILE="${CWD}/.mega-sdd/.extraction-scorecard-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true

RESULT=$(python3 -W ignore::DeprecationWarning - "$CWD" "$KB_DIR" <<'PYEOF'
import json, os, re, sys

cwd = sys.argv[1]
kb_dir = sys.argv[2]

REQUIRED_PRINCIPLES = [
    "P1_state_provenance",
    "P2_rule_enumeration",
    "P3_behavior_executed",
    "P4_structural_classification",
    "P5_staged_inputs",
]
VALID_PRINCIPLE_STATUS = {"COVERED", "PARTIAL", "MISSING"}
VALID_OVERALL = {"PASS", "PARTIAL", "FAIL"}

def emit(d):
    print(json.dumps(d))
    sys.exit(0)

# --- SKIP: no KB dir or no scorecard (back-compat, never fails) ---
if not kb_dir or not os.path.isdir(kb_dir):
    emit({"status": "SKIP", "summary": "no knowledge-base dir resolved — nothing to score",
          "scorecard_path": None, "issues": [], "advisories": []})

scorecard_path = os.path.join(kb_dir, ".extraction-scorecard.json")
if not os.path.isfile(scorecard_path):
    emit({"status": "SKIP",
          "summary": "no .extraction-scorecard.json (pre-v3.72.0 KB or not emitted by Wave 5)",
          "scorecard_path": None, "issues": [],
          "advisories": ["extract-intelligence Wave 5 should emit .extraction-scorecard.json (see SKILL.md §Extraction Completeness Contract)"]})

rel = os.path.relpath(scorecard_path, cwd)

try:
    with open(scorecard_path, "r", errors="replace") as f:
        sc = json.load(f)
except Exception as e:
    emit({"status": "FAIL", "scorecard_path": rel,
          "summary": f"scorecard present but unparseable JSON: {e}",
          "issues": [{"type": "scorecard_unparseable", "detail": str(e)}], "advisories": []})

issues = []
principles = sc.get("principles", {})
if not isinstance(principles, dict):
    issues.append({"type": "principles_missing", "detail": "no `principles` object"})
    principles = {}

# Structure: all 5 principles present with a valid status.
present_status = {}
for key in REQUIRED_PRINCIPLES:
    p = principles.get(key)
    if not isinstance(p, dict) or "status" not in p:
        issues.append({"type": "principle_absent", "principle": key,
                       "detail": f"{key} missing or has no status"})
        continue
    st = p.get("status")
    if st not in VALID_PRINCIPLE_STATUS:
        issues.append({"type": "principle_status_invalid", "principle": key, "detail": f"status={st!r}"})
        continue
    present_status[key] = st

overall = sc.get("overall_status")
if overall not in VALID_OVERALL:
    issues.append({"type": "overall_status_invalid", "detail": f"overall_status={overall!r}"})

# Count [OPEN] markers across KB markdown (the silent-gap detector).
open_marker_count = 0
md_files = 0
for root, _dirs, files in os.walk(kb_dir):
    for fn in files:
        if fn.endswith(".md"):
            md_files += 1
            try:
                with open(os.path.join(root, fn), "r", errors="replace") as fh:
                    open_marker_count += len(re.findall(r"\[OPEN", fh.read()))
            except Exception:
                pass

not_covered = [k for k, v in present_status.items() if v in ("PARTIAL", "MISSING")]

# Consistency rule 1: overall PASS requires ALL principles COVERED.
if overall == "PASS" and not_covered:
    issues.append({"type": "overall_inconsistent",
                   "detail": f"overall_status=PASS but not-COVERED principles: {not_covered}"})

# Consistency rule 2 (the silent-gap catch): a PARTIAL/MISSING principle with ZERO
# [OPEN] markers in the KB is an undeclared gap — the exact drift this contract guards.
if not_covered and open_marker_count == 0:
    issues.append({"type": "hidden_gap",
                   "detail": f"principles {not_covered} are PARTIAL/MISSING but the KB carries ZERO [OPEN] markers — "
                             f"gaps must be surfaced as [OPEN] in the KB, not hidden"})

advisories = []
# overall=FAIL is the scorecard honestly self-reporting a gap — that's an advisory to
# re-run the failing principle, NOT a validator FAIL (the scorecard did its job).
if overall == "FAIL" and not issues:
    advisories.append("scorecard self-reports overall_status=FAIL — re-run extract-intelligence for the failing principle(s) before downstream stages")
if overall == "PARTIAL" and not issues:
    advisories.append("scorecard self-reports overall_status=PARTIAL with [OPEN] markers present — downstream may proceed carrying [OPEN]s")

status = "FAIL" if issues else "PASS"
summary = (
    f"{len(issues)} scorecard-integrity issue(s) — see issues[]"
    if issues else
    f"scorecard consistent (overall={overall}; {open_marker_count} [OPEN] marker(s) across {md_files} KB file(s))"
)
emit({
    "status": status,
    "scorecard_path": rel,
    "overall_status_reported": overall,
    "principle_status": present_status,
    "open_marker_count": open_marker_count,
    "kb_md_files": md_files,
    "issues": issues,
    "advisories": advisories,
    "summary": summary,
})
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
