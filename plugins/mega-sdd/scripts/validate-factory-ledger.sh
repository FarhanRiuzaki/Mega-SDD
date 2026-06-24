#!/usr/bin/env bash
# validate-factory-ledger.sh — Factory Line.
# Validates <cwd>/.mega-sdd/factory-ledger.json:
#   - schema: required fields (phase, attempt, status, emitted_at); status enum;
#             every unresolved[].id anchored (CONFLICT-N | OQ-N | file:line)
#   - anti-spin cap: a phase's max attempt >= CAP and latest status != completed -> phase_stuck
#   - idempotency: identical unresolved id-set across two consecutive attempts -> anti_spin
# Also computes convergence_status (done|in_progress).
# Writes <cwd>/.mega-sdd/.factory-ledger-state.json
# Exit: 0=PASS or SKIP(no ledger), 1=FAIL, 2=error.
set -uo pipefail

CWD=""; QUIET=0; CAP=3
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --cap=*) CAP="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
# resolve_project_root returns the NEAREST ancestor containing .mega-sdd/; callers/tests must pass a --cwd whose own .mega-sdd/ exists (the validator's mkdir creates the state-file dir AFTER this).
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
[ -n "$CWD" ] || { echo "ERROR: --cwd required" >&2; exit 2; }

LEDGER="${CWD}/.mega-sdd/factory-ledger.json"
STATE_FILE="${CWD}/.mega-sdd/.factory-ledger-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2; }

LEDGER="$LEDGER" STATE_FILE="$STATE_FILE" CAP="$CAP" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from collections import defaultdict

ledger_path = os.environ["LEDGER"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET") == "1"

ANCHOR = re.compile(r'^(CONFLICT-\d+|OQ-\d+|.+:\d+)$')
STATUSES = {"completed", "unresolved", "halted"}

def write_and_exit(report, code):
    try:
        with open(state_file, "w") as f:
            json.dump(report, f, indent=2)
    except Exception as e:
        sys.stderr.write("ERROR: cannot write state: %s\n" % e); sys.exit(2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)

try:
    cap = int(os.environ.get("CAP", "3"))

    # SKIP when feature not in use (no ledger yet) — never blocks.
    if not os.path.exists(ledger_path):
        write_and_exit({"status": "SKIP", "reason": "no factory-ledger.json", "halt_type": None,
                        "convergence_status": None, "cap": None}, 0)

    try:
        records = json.load(open(ledger_path))
    except Exception as e:
        write_and_exit({"status": "FAIL", "halt_type": "ledger_unparseable",
                        "convergence_status": "in_progress",
                        "details": {"message": "factory-ledger.json present but unparseable: %s" % type(e).__name__}}, 1)

    if not isinstance(records, list):
        write_and_exit({"status": "FAIL", "halt_type": "ledger_schema",
                        "convergence_status": "in_progress",
                        "details": {"errors": ["ledger must be a JSON array"]}}, 1)

    schema_errors = []
    for i, r in enumerate(records):
        if not isinstance(r, dict):
            schema_errors.append("record %d is not an object" % i); continue
        for fld in ("phase", "attempt", "status", "emitted_at"):
            if fld not in r:
                schema_errors.append("record %d missing required field '%s'" % (i, fld))
        if r.get("status") not in STATUSES:
            schema_errors.append("record %d status '%s' not in %s" % (i, r.get("status"), sorted(STATUSES)))
        for u in (r.get("unresolved") or []):
            uid = u.get("id") if isinstance(u, dict) else None
            if not uid or not ANCHOR.match(str(uid)):
                schema_errors.append("record %d unresolved id '%s' not anchored (need CONFLICT-N / OQ-N / file:line)" % (i, uid))

    if schema_errors:
        write_and_exit({"status": "FAIL", "halt_type": "ledger_schema",
                        "convergence_status": "in_progress",
                        "details": {"errors": schema_errors}}, 1)

    by_phase = defaultdict(list)
    for r in records:
        by_phase[r["phase"]].append(r)
    for p in by_phase:
        by_phase[p].sort(key=lambda r: r.get("attempt", 0))

    def idset(a):
        return tuple(sorted(str(u.get("id")) for u in (a.get("unresolved") or []) if isinstance(u, dict)))

    cap_breaches, spin_breaches = [], []
    for phase, attempts in by_phase.items():
        latest = attempts[-1]
        max_attempt = max(a.get("attempt", 0) for a in attempts)
        if max_attempt >= cap and latest.get("status") != "completed":
            cap_breaches.append({"phase": phase, "attempts": max_attempt, "status": latest.get("status")})
        for j in range(1, len(attempts)):
            cur = idset(attempts[j])
            if cur and cur == idset(attempts[j-1]):
                spin_breaches.append({"phase": phase, "attempt": attempts[j].get("attempt"), "unresolved": list(cur)})
                break

    all_green = all(
        atts[-1].get("status") == "completed" and not (atts[-1].get("unresolved") or [])
        for atts in by_phase.values()
    )
    convergence_status = "done" if all_green else "in_progress"

    if cap_breaches or spin_breaches:
        halt_type = "phase_stuck" if cap_breaches else "anti_spin"
        msg = ("%d phase(s) exceeded retry cap %d" % (len(cap_breaches), cap)) if cap_breaches \
              else ("%d phase(s) re-ran with no progress (identical unresolved)" % len(spin_breaches))
        write_and_exit({"status": "FAIL", "halt_type": halt_type,
                        "convergence_status": convergence_status, "cap": cap,
                        "cap_breaches": cap_breaches, "spin_breaches": spin_breaches,
                        "details": {"message": msg}}, 1)

    write_and_exit({"status": "PASS", "halt_type": None,
                    "convergence_status": convergence_status, "cap": cap,
                    "cap_breaches": [], "spin_breaches": [],
                    "phases": {p: {"attempts": max(a.get("attempt", 0) for a in atts), "status": atts[-1].get("status")}
                               for p, atts in by_phase.items()}}, 0)

except SystemExit:
    raise
except Exception as e:
    sys.stderr.write("ERROR: %s\n" % e); sys.exit(2)
PYEOF
exit $?
