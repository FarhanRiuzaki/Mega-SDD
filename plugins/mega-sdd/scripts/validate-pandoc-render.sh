#!/usr/bin/env bash
# validate-pandoc-render.sh — Phase B B.5 follow-up [PostToolUse Bash matcher].
#
# Detects quality_gate_failed:pdf_render_failed when a Bash command invoking
# pandoc returns non-zero exit. Per attestation: hook detects + auto-attempts
# install of tectonic via /mega-sdd:install-deps (if available); else escalate
# to user_review.
#
# Inputs: --cwd, --bash-command (base64-encoded for safety), --exit-code
# Outputs: writes .mega-sdd/.pandoc-render-state.json
# Exit: 0=PASS, 1=FAIL.

set -uo pipefail

CWD=""
CMD_B64=""
EXIT_CODE_IN=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --bash-command-b64=*) CMD_B64="${arg#*=}" ;;
    --exit-code=*) EXIT_CODE_IN="${arg#*=}" ;;
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
[ -z "$CMD_B64" ] && exit 0
[ -z "$EXIT_CODE_IN" ] && exit 0

STATE_FILE="${CWD}/.mega-sdd/.pandoc-render-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" CMD_B64="$CMD_B64" EXIT_CODE_IN="$EXIT_CODE_IN" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, sys, base64
from datetime import datetime, timezone

cwd = os.environ["CWD"]
cmd = base64.b64decode(os.environ["CMD_B64"]).decode("utf-8", errors="replace")
exit_code = int(os.environ["EXIT_CODE_IN"]) if os.environ["EXIT_CODE_IN"].lstrip("-").isdigit() else 0
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# Only act on pandoc commands
if "pandoc" not in cmd.lower():
    sys.exit(0)

# Only act on non-zero exit
if exit_code == 0:
    state = {"ts": ts, "status": "PASS", "reason": "pandoc command succeeded"}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    sys.exit(0)

state = {
    "ts": ts,
    "status": "FAIL",
    "halt_type": "pdf_render_failed",
    "quality_gate_subtype": "pdf_render_failed",
    "exit_code": exit_code,
    "command_snippet": cmd[:200],
    "detail": f"pandoc exited with code {exit_code}",
    "next_action": "Run /mega-sdd:install-deps --tools=tectonic to install PDF LaTeX engine, then re-run emit-fsd. If install fails (sudo/network), manual install required.",
}
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
if not quiet:
    print(json.dumps(state, indent=2))
sys.exit(1)
PYEOF

exit $?
