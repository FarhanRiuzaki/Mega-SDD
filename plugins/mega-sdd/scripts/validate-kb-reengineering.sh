#!/usr/bin/env bash
# validate-kb-reengineering.sh — pipeline-intelligence, Iter-79 U-EI (extract-intelligence).
#
# Per docs/superpowers/audits/2026-06-02-intelligence-e2e/03-upstream-phases.md §extract-intelligence.
#
# The 4 wired KB validators (kb-output/markers/citations/flows) all check TRANSCRIPTION
# discipline — marker COUNT match, per-claim citations, mermaid validity, section presence.
# The phase's actual REASONING output — the Wave-5 reengineering synthesis under
# `99-rebuild-architecture/` (data-mutation-policy / suggested-erd / suggested-phasing) — has
# ZERO validator. A KB could ship rich [VERIFIED] transcription with a stub/absent mutation
# policy and pass every wired check. This validator asserts the reengineering reasoning
# artifacts exist and are non-trivial. Advisory (WARN/detect): a producer telemetry signal,
# never a blocking gate (extract-intelligence is read-only legacy analysis).
#
# Checks (all advisory):
#   - kb_reengineering_missing       — 99-rebuild-architecture/ absent while the KB carries
#                                       mutability markers ([LOCKED]/[INTENT]/[ARTIFACT]).
#   - kb_mutation_policy_thin         — data-mutation-policy.md absent or carries no tier row.
#   - kb_erd_departures_missing       — suggested-erd.md absent or notes no departure
#                                       (depart/normalize/discard/merge/split/rename…).
#   - kb_phasing_missing              — suggested-phasing.md absent or names no phase.
#
# Usage: validate-kb-reengineering.sh --cwd=<project-root> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.kb-reengineering-state.json
# Exit: 0 = PASS / SKIP / WARN; 2 = error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) : ;;
    --quiet) QUIET=1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR_HELPER="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR_HELPER" ] && [ -n "${CWD:-}" ]; then
  # shellcheck disable=SC1090
  . "$_RPR_HELPER"
  CWD=$(resolve_project_root "$CWD")
fi
if [ -z "$CWD" ]; then CWD="$(pwd)"; fi
if [ ! -d "${CWD}/.mega-sdd" ]; then exit 2; fi

STATE_FILE="${CWD}/.mega-sdd/.kb-reengineering-state.json"

CWD="$CWD" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def write_and_exit(report, code):
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
    if not quiet:
        print(json.dumps(report))
    sys.exit(code)


def skip(reason):
    write_and_exit({
        "status": "SKIP", "validator": "kb-reengineering", "ts": ts, "reason": reason,
        "issues": [], "summary": f"SKIP — {reason}",
    }, 0)


kb_dir = os.path.join(cwd, ".mega-sdd", "knowledge-base")
if not os.path.isdir(kb_dir):
    skip("no knowledge-base/ (extract-intelligence has not run)")


def read(p):
    try:
        return open(p, errors="replace").read()
    except Exception:
        return ""


# Does the KB carry mutability markers at all? (If not, it predates the dual-axis tier
# convention — don't demand reengineering artifacts; SKIP to avoid false positives.)
domain_blob = ""
for f in glob.glob(os.path.join(kb_dir, "**", "*.md"), recursive=True):
    if "/99-rebuild-architecture/" in f:
        continue
    domain_blob += read(f)
has_markers = bool(re.search(r"\[(LOCKED|INTENT|ARTIFACT)\]", domain_blob))
if not has_markers:
    skip("KB carries no mutability markers ([LOCKED]/[INTENT]/[ARTIFACT]); reengineering synthesis not expected")

issues = []
reeng_dir = os.path.join(kb_dir, "99-rebuild-architecture")
if not os.path.isdir(reeng_dir):
    issues.append({
        "halt_type": "kb_reengineering_missing",
        "detail": "knowledge-base/99-rebuild-architecture/ is absent though the KB carries "
                  "mutability markers — the Wave-5 reengineering synthesis was not produced.",
    })
else:
    def find(name):
        hits = glob.glob(os.path.join(reeng_dir, name)) + glob.glob(os.path.join(reeng_dir, "**", name), recursive=True)
        return hits[0] if hits else None

    mut = find("data-mutation-policy.md")
    if not mut or not re.search(r"\[(LOCKED|INTENT|ARTIFACT)\]|\b(LOCKED|INTENT|ARTIFACT)\b", read(mut)):
        issues.append({
            "halt_type": "kb_mutation_policy_thin",
            "detail": "99-rebuild-architecture/data-mutation-policy.md is absent or carries no "
                      "tier assignment (LOCKED/INTENT/ARTIFACT) — the per-entity mutation policy "
                      "downstream generate-intent --kb consumes is missing.",
        })
    erd = find("suggested-erd.md")
    if not erd or not re.search(r"\b(depart|normaliz|denormaliz|discard|merge|split|renam|consolidat|drop)\w*\b", read(erd), re.IGNORECASE):
        issues.append({
            "halt_type": "kb_erd_departures_missing",
            "detail": "99-rebuild-architecture/suggested-erd.md is absent or notes no departure "
                      "from the legacy schema (depart/normalize/discard/merge/split/rename) — "
                      "the ERD reads as a 1:1 mirror, not a reengineering proposal.",
        })
    phasing = find("suggested-phasing.md")
    if not phasing or not re.search(r"\bphase\b", read(phasing), re.IGNORECASE):
        issues.append({
            "halt_type": "kb_phasing_missing",
            "detail": "99-rebuild-architecture/suggested-phasing.md is absent or names no phase "
                      "— the rebuild sequencing reasoning is missing.",
        })

status = "WARN" if issues else "PASS"
report = {
    "status": status, "validator": "kb-reengineering", "ts": ts,
    "summary": (
        f"{len(issues)} reengineering-synthesis gap(s) — the KB's reasoning output "
        f"(99-rebuild-architecture/) is incomplete while transcription discipline may pass."
        if issues else "reengineering synthesis present (mutation-policy + erd departures + phasing)."
    ),
    "issues": issues,
    "next_action": (
        "Complete the Wave-5 reengineering synthesis: a per-entity data-mutation-policy with "
        "LOCKED/INTENT/ARTIFACT tiers, a suggested-erd that documents departures from the legacy "
        "schema, and a suggested-phasing. These are the analysis outputs generate-intent --kb consumes."
        if issues else "No action — reengineering synthesis is present and non-trivial."
    ),
}
write_and_exit(report, 0)
PYEOF
