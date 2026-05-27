#!/usr/bin/env bash
# validate-starterkit-metrics.sh — B.5-fu remainder [PostToolUse Skill cross-check].
#
# Detects quality_gate_failed:starterkit_metrics_inconsistent: when
# generate-units's handoff reports units_with_starterkit_rules > 0 BUT
# starterkit-context.yaml has `partial: true` (rules drawn from incomplete
# framework slice).
#
# Trigger: PostToolUse Skill matcher mega-sdd:generate-units (read transcript
# for last assistant message → parse handoff → check starterkit_rules field;
# also read starterkit-context.yaml for partial flag; cross-check).
#
# Inputs: --cwd, --transcript-path
# Outputs: writes .mega-sdd/.starterkit-metrics-state.json
# Exit: 0=PASS (consistent or skip), 1=FAIL (inconsistent).

set -uo pipefail

CWD=""
TRANSCRIPT_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --transcript-path=*) TRANSCRIPT_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
  esac
done
[ -z "$CWD" ] && exit 2

STATE_FILE="${CWD}/.mega-sdd/.starterkit-metrics-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" TRANSCRIPT_PATH="$TRANSCRIPT_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
state_file = os.environ["STATE_FILE"]
transcript_path = os.environ.get("TRANSCRIPT_PATH", "")
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# Read starterkit-context.yaml
sk_path = os.path.join(cwd, ".mega-sdd", "codebase", "starterkit-context.yaml")
if not os.path.isfile(sk_path):
    state = {"ts": ts, "status": "PASS", "reason": "no starterkit-context.yaml; no cross-check needed"}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    sys.exit(0)

try:
    sk_content = open(sk_path).read()
except Exception:
    sys.exit(0)

# Look for partial: true
partial_match = re.search(r"^partial:\s*(true|false)", sk_content, re.MULTILINE | re.IGNORECASE)
is_partial = bool(partial_match and partial_match.group(1).lower() == "true")

if not is_partial:
    state = {"ts": ts, "status": "PASS", "reason": "starterkit-context.yaml not partial; consistent by default"}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    sys.exit(0)

# starterkit is partial. Check if generate-units output had units_with_starterkit_rules > 0.
# Read transcript for last assistant message containing handoff
units_with_starterkit_rules = 0
if transcript_path and os.path.isfile(transcript_path):
    last_assistant_text = None
    try:
        with open(transcript_path) as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                msg = rec.get("message") if isinstance(rec.get("message"), dict) else None
                if not msg or msg.get("role") != "assistant":
                    continue
                content = msg.get("content")
                if isinstance(content, str):
                    last_assistant_text = content
                elif isinstance(content, list):
                    parts = [b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"]
                    if parts:
                        last_assistant_text = "\n".join(parts)
    except Exception:
        pass

    if last_assistant_text:
        # Look for units_with_starterkit_rules field in handoff
        m = re.search(r"units_with_starterkit_rules:\s*(\d+)", last_assistant_text)
        if m:
            units_with_starterkit_rules = int(m.group(1))

if units_with_starterkit_rules > 0:
    state = {
        "ts": ts,
        "status": "FAIL",
        "halt_type": "starterkit_metrics_inconsistent",
        "quality_gate_subtype": "starterkit_metrics_inconsistent",
        "detail": f"generate-units handoff reports units_with_starterkit_rules={units_with_starterkit_rules} but starterkit-context.yaml has partial: true",
        "units_with_starterkit_rules": units_with_starterkit_rules,
        "starterkit_partial": True,
        "next_action": "Run /mega-sdd:scan-codebase --force-deep then regenerate units (units may cite incomplete framework slice).",
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state, indent=2))
    sys.exit(1)

state = {"ts": ts, "status": "PASS", "reason": "no units cite starterkit rules; consistent"}
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
sys.exit(0)
PYEOF

exit $?
