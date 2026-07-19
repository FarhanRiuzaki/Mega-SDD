#!/usr/bin/env bash
# derive-state.sh — the ONE CWD state digest (P1, spec 2026-07-19-v5-execution-spec.md
# decision 8; research/2026-07-19-v5-architecture-research.md §3).
#
# Replaces the 10-probe PROSE inspection routing-rules.md used to prescribe: every
# probe now runs in scripts/_lib/state_probes.py (shared with validate-preflight.sh
# and the session-start staleness notice) and lands in ONE artifact —
# <root>/.mega-sdd/state.json — so the probe sets consumed by routing, auto,
# --resume, session-start, and preflight can never re-diverge again (the P0
# has_vault fork was exactly this failure class).
#
# state.json shape (script-lane artifact; envelope + two objects):
#   schema / generated_at / generator / root
#   probes  — plain data: prd, vaults[] (per-dir: vault.json/docs, bound, binding
#             incl. conflict counts, units, bolts, OQ P0/P1 open-vs-deferred,
#             squads, interfaces, drift-report, pending-sync), git, manifests,
#             code, codebase_map (+ last_scanned_commit vs HEAD), knowledge_base,
#             dirty_journal_rows, preflight_predicates
#   derived — position enum + proposed_next chain per the routing decision table
#             (+ mode_inferred, starterkit, change_signal, notes)
#
# Output: ONE human line on stdout (quiet-gates); --json-only prints the full JSON
# instead. The file is written atomically, and ONLY when <root>/.mega-sdd/ already
# exists — derive-state never creates .mega-sdd/ (that would mint an SDD signal in
# an unrelated directory); pre-init consumers read stdout via --json-only.
#
# Usage: derive-state.sh --cwd=<root> [--json-only]
# Exit:  0 = digest produced; 2 = internal error (never blocks — this is a
#        read-only inspection surface, not a gate).

set -uo pipefail

CWD=""
JSON_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --json-only) JSON_ONLY=1 ;;
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

export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" JSON_ONLY="$JSON_ONLY" python3 <<'PYEOF'
import json, os, sys, tempfile
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import state_probes

cwd = os.path.abspath(os.environ["CWD"])
json_only = os.environ.get("JSON_ONLY", "0") == "1"

try:
    state = state_probes.collect_state(cwd)
except Exception as e:  # never block — inspection surface, not a gate
    print("derive-state: ERROR %s" % e, file=sys.stderr)
    sys.exit(2)

payload = {
    "schema": 1,
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "generator": "derive-state.sh",
    "root": cwd,
    "probes": state["probes"],
    "derived": state["derived"],
}

# Atomic write — ONLY when .mega-sdd/ already exists (never mint an SDD signal).
state_dir = os.path.join(cwd, ".mega-sdd")
state_file = None
if os.path.isdir(state_dir):
    state_file = os.path.join(state_dir, "state.json")
    try:
        fd, tmp = tempfile.mkstemp(prefix=".state-", suffix=".json", dir=state_dir)
        with os.fdopen(fd, "w") as f:
            json.dump(payload, f, indent=2)
            f.write("\n")
        os.replace(tmp, state_file)
    except Exception:
        state_file = None  # digest still valid on stdout

if json_only:
    print(json.dumps(payload, indent=2))
    sys.exit(0)

d = payload["derived"]
p = payload["probes"]
vault = d["vault"] or "-"
nxt = " -> ".join(d["proposed_next"]) if d["proposed_next"] else "(none)"
vrow = p["vaults"][0] if p["vaults"] else None
units = vrow["units_count"] if vrow else 0
bolts = vrow["bolts_count"] if vrow else 0
oq = vrow["oq"]["pending_p0_p1"] if vrow else 0
cs = d["change_signal"]
print(
    "mega-sdd state: position=%s vault=%s units=%d bolts=%d oq_p0p1_open=%d "
    "map=%s dirty=%d next: %s%s"
    % (
        d["position"], vault, units, bolts, oq,
        cs["map_stamp_matches_head"], cs["dirty_journal_rows"], nxt,
        "" if state_file else "  [state.json not written: no .mega-sdd/]",
    )
)
PYEOF
