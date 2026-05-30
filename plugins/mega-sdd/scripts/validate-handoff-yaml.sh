#!/usr/bin/env bash
# validate-handoff-yaml.sh — Phase B slice B.1 [PostToolUse-validate].
#
# Validates handoff YAML emitted in skill chat output against handoff-contract.md
# schema. Covers four C1 halts that historically required orchestrate-flow body
# prose to detect (= 4× audit-failure pattern; this script eliminates prose path):
#   - handoff_missing       (no `handoff:` block found)
#   - invalid_handoff       (required field missing OR YAML parse error)
#   - handoff_type_mismatch (field type doesn't match annotation)
#   - artifact_missing      (artifacts: paths don't exist on disk)
#
# Per attestation reclassification (Iter 67.7): C1 self-resolve on first attempt
# (treat as "warn + suggest re-invoke producer with --strict-handoff"); 2nd
# attempt escalates to C2. retry_count tracked in state file.
#
# Inputs: handoff text via --response-file (path) OR stdin.
# Outputs: JSON report to stdout; writes .mega-sdd/.handoff-validation-state.json
# Exit codes: 0=PASS, 1=FAIL (at least one halt detected), 2=error.

set -uo pipefail

CWD=""
RESPONSE_FILE=""
SKILL_NAME=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --response-file=*) RESPONSE_FILE="${arg#*=}" ;;
    --skill-name=*) SKILL_NAME="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
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


if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required" >&2
  exit 2
fi

# Get response text — from file or stdin
if [ -n "$RESPONSE_FILE" ]; then
  if [ ! -f "$RESPONSE_FILE" ]; then
    echo "ERROR: --response-file does not exist: $RESPONSE_FILE" >&2
    exit 2
  fi
  RESPONSE_TEXT=$(cat "$RESPONSE_FILE")
else
  RESPONSE_TEXT=$(cat)
fi

STATE_FILE="${CWD}/.mega-sdd/.handoff-validation-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2; }

# Run validator via python3 (yaml parsing + schema check)
CWD="$CWD" SKILL_NAME="$SKILL_NAME" STATE_FILE="$STATE_FILE" QUIET="$QUIET" RESPONSE_TEXT="$RESPONSE_TEXT" python3 <<'PYEOF'
import json
import os
import re
import sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
skill_name = os.environ.get("SKILL_NAME", "unknown")
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
response = os.environ["RESPONSE_TEXT"]
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# No-deps YAML-subset parser. Handles the handoff schema shapes we need:
#   key: scalar
#   key: [a, b, c]  (inline list)
#   key:            (block-style; value comes from children OR list items)
#     - item        (block list)
#     - item
#   key:            (block-style nested dict)
#     subkey: val
#     subkey: val
def parse_handoff_yaml(text):
    """Parse handoff YAML block; returns dict with 'handoff' root key."""
    lines = text.split("\n")
    # Find the line containing 'handoff:'
    base_idx = None
    base_col = 0
    for i, line in enumerate(lines):
        s = line.lstrip()
        if s.startswith("handoff:") and (len(s) == len("handoff:") or s[len("handoff:")] in (" ", "\t", "")):
            base_idx = i
            base_col = len(line) - len(s)
            break
    if base_idx is None:
        return None
    children_col = base_col + 2  # YAML children indent
    handoff = {}
    current_top_key = None
    # Walk subsequent lines belonging to handoff: block
    j = base_idx + 1
    while j < len(lines):
        line = lines[j]
        if not line.strip():
            j += 1
            continue
        col = len(line) - len(line.lstrip())
        if col <= base_col:
            break  # back at base or shallower — block ended
        if col == children_col:
            # Top-level key under handoff:
            content = line[children_col:]
            m = re.match(r"^([\w_-]+):\s*(.*?)\s*$", content)
            if m:
                key, val = m.group(1), m.group(2)
                current_top_key = key
                if val == "":
                    handoff[key] = None  # block-style; will populate from children
                elif val.startswith("[") and val.endswith("]"):
                    items = [x.strip().strip("'\"") for x in val[1:-1].split(",") if x.strip()]
                    handoff[key] = items
                else:
                    handoff[key] = val.strip("'\"")
        elif col > children_col and current_top_key:
            # Nested under current_top_key — block list item OR nested dict key
            content = line[children_col:].lstrip()
            if content.startswith("- "):
                # Block list item
                item_val = content[2:].strip().strip("'\"")
                if not isinstance(handoff.get(current_top_key), list):
                    handoff[current_top_key] = []
                handoff[current_top_key].append(item_val)
            else:
                # Nested dict key
                m = re.match(r"^([\w_-]+):\s*(.*?)\s*$", content)
                if m:
                    sub_key, sub_val = m.group(1), m.group(2)
                    if not isinstance(handoff.get(current_top_key), dict):
                        handoff[current_top_key] = {}
                    handoff[current_top_key][sub_key] = sub_val.strip("'\"") if sub_val else None
        j += 1
    return {"handoff": handoff}

# Load prior state if exists (for retry_count tracking)
prior_state = {}
try:
    with open(state_file) as f:
        prior_state = json.load(f)
except Exception:
    prior_state = {}

# ─── Step 1: Extract handoff: block from response text ──────────────────────
# Two patterns:
#   (a) fenced code block:  ```yaml\nhandoff:\n  ...\n```
#   (b) inline:             handoff:\n  ...\n<blank line or end>
def extract_handoff_block(text):
    # Try fenced code block first
    m = re.search(r"```(?:yaml|yml)?\s*\n(\s*handoff:.*?)\n```", text, re.DOTALL)
    if m:
        return m.group(1)
    # Try inline — handoff: line followed by indented block
    m = re.search(r"(?:^|\n)(\s*handoff:\s*\n(?:[ \t]+\S.*\n)+)", text, re.DOTALL)
    if m:
        return m.group(1)
    return None

handoff_text = extract_handoff_block(response)

if handoff_text is None:
    # handoff_missing
    result = {
        "status": "FAIL",
        "halt_type": "handoff_missing",
        "details": {
            "reason": "no `handoff:` block found in chat response",
            "response_length": len(response),
            "response_tail": response[-300:] if len(response) > 300 else response,
        },
    }
else:
    # ─── Step 2: Parse YAML (no-deps subset parser) ─────────────────────────
    parsed = parse_handoff_yaml(handoff_text)
    parse_error = None
    if parsed is None or not isinstance(parsed, dict) or "handoff" not in parsed:
        parse_error = "could not extract handoff: block structure"

    if parse_error:
        result = {
            "status": "FAIL",
            "halt_type": "invalid_handoff",
            "details": {
                "reason": parse_error,
                "handoff_text_excerpt": handoff_text[:300],
            },
        }
    else:
        h = parsed.get("handoff", {}) if isinstance(parsed, dict) else {}

        # ─── Step 3: Required fields check ──────────────────────────────────
        # "Present" means: key exists AND value is non-None AND not empty-string.
        # Empty list [] or empty dict {} for next_action treated as missing (needs structure).
        required_fields = ["emitted_by", "emitted_at", "status", "next_action"]
        def is_missing(v):
            if v is None: return True
            if isinstance(v, str) and v.strip() == "": return True
            if isinstance(v, dict) and len(v) == 0: return True
            return False
        missing_fields = [f for f in required_fields if f not in h or is_missing(h.get(f))]

        if missing_fields:
            result = {
                "status": "FAIL",
                "halt_type": "invalid_handoff",
                "details": {
                    "reason": "required field(s) missing",
                    "missing_fields": missing_fields,
                    "present_fields": sorted(list(h.keys())) if isinstance(h, dict) else [],
                },
            }
        else:
            # ─── Step 4: Type checks ────────────────────────────────────────
            type_errors = []
            # status: must be enum string
            valid_statuses = {"completed", "paused", "halted"}
            if h["status"] not in valid_statuses:
                type_errors.append(f"status={h['status']!r} not in {sorted(valid_statuses)}")
            # emitted_by: must be string
            if not isinstance(h["emitted_by"], str):
                type_errors.append(f"emitted_by must be string, got {type(h['emitted_by']).__name__}")
            # emitted_at: must look like ISO8601
            if not isinstance(h["emitted_at"], str) or not re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}", str(h["emitted_at"])):
                type_errors.append(f"emitted_at must be ISO8601 string, got {h['emitted_at']!r}")
            # artifacts: optional but if present must be list
            if "artifacts" in h and h["artifacts"] is not None and not isinstance(h["artifacts"], list):
                type_errors.append(f"artifacts must be list, got {type(h['artifacts']).__name__}")
            # next_action: string (legacy) OR dict with type+hint (canonical)
            na = h["next_action"]
            if not (isinstance(na, str) or isinstance(na, dict)):
                type_errors.append(f"next_action must be string OR dict, got {type(na).__name__}")

            if type_errors:
                result = {
                    "status": "FAIL",
                    "halt_type": "handoff_type_mismatch",
                    "details": {
                        "reason": "field type(s) mismatch handoff-contract.md annotations",
                        "type_errors": type_errors,
                    },
                }
            else:
                # ─── Step 5: Artifact existence check ───────────────────────
                # Iter 73 hardening: defensively strip trailing producer-added
                # annotations like " (18 files)", " (latest)", " - generated 2026-..."
                # before exists check.
                # Iter 74 hardening: defensively expand " ... " ellipsis ranges
                # like "/path/bolts/U-001/ ... U-016/" → 16 explicit paths. The
                # `# ... one per unit executed` comment in execute-bolts handoff
                # template gave the model a cue to use ellipsis shorthand in the
                # output; this expansion recovers the intended enumeration.
                #
                # Producer-side fix is to NOT use shorthand (see execute-bolts and
                # generate-units handoff template comments); these strips/expansions
                # are defense-in-depth.

                # Iter 77: generalize beyond '...' — model invents new range
                # shorthand variants ('through', 'to', 'thru', Unicode ellipsis '…').
                # Pattern: <prefix>U-<start>/ <SEP> U-<end>/ (trailing slashes optional)
                # SEP ∈ {..., …, through, to, thru} (case-insensitive for words)
                RANGE_SEP_REGEX = re.compile(
                    r"^(.+?)U-(\d+)/?\s+(?:\.\.\.|…|through|thru|to)\s+U-(\d+)/?$",
                    re.IGNORECASE,
                )
                # Quick detector — has any known separator present?
                RANGE_SEP_PROBE = re.compile(
                    r"U-\d+/?\s+(?:\.\.\.|…|through|thru|to)\s+U-\d+/?",
                    re.IGNORECASE,
                )

                def expand_range_shorthand(p):
                    """If path has ' <sep> ' shorthand for a U-NNN range, expand to explicit list.

                    Supported separators (Iter 75+77): '...', '…', 'through', 'to', 'thru'.
                    All case-insensitive for word separators. Range cap: 1000 entries.

                    Returns:
                      list of explicit paths if expansion succeeded
                      [p] if no shorthand detected (path is literal — no transformation needed)
                      [left_side_of_shorthand] if shorthand detected but couldn't parse
                          (defensive fallback — at least verify the producer's start path)
                    """
                    if not RANGE_SEP_PROBE.search(p):
                        return [p]
                    m = RANGE_SEP_REGEX.match(p.strip())
                    if m:
                        prefix, start_str, end_str = m.groups()
                        try:
                            start = int(start_str)
                            end = int(end_str)
                            width = len(start_str)
                            # Sanity cap: max 1000 entries to avoid pathological inputs
                            if start <= end and (end - start) <= 1000:
                                return [
                                    f"{prefix}U-{i:0{width}d}"
                                    for i in range(start, end + 1)
                                ]
                        except ValueError:
                            pass
                    # Couldn't parse — fall back: split on first detected separator
                    # and use LEFT side as a literal path. Better than failing on a
                    # shorthand we couldn't expand.
                    for sep in (" ... ", " … ", " through ", " THROUGH ", " thru ", " THRU ", " to ", " TO "):
                        if sep in p:
                            return [p.split(sep)[0].rstrip()]
                    return [p]

                # Backward-compat alias (Iter 75 name preserved for any external caller)
                expand_ellipsis_range = expand_range_shorthand

                missing_artifacts = []
                artifacts = h.get("artifacts") or []
                if isinstance(artifacts, list):
                    for ap in artifacts:
                        if not isinstance(ap, str):
                            continue
                        # Strip trailing whitespace + annotations
                        cleaned = ap.strip()
                        # Pattern 1: trailing " (anything)"  e.g., "/path/ (18 files)"
                        cleaned = re.sub(r"\s+\([^)]*\)\s*$", "", cleaned)
                        # Pattern 2: trailing " - comment"  e.g., "/path/ - latest"
                        cleaned = re.sub(r"\s+-\s+.*$", "", cleaned)
                        # Pattern 3: trailing " # comment"  e.g., "/path/ # note"
                        cleaned = re.sub(r"\s+#\s+.*$", "", cleaned)
                        # Iter 75: expand " ... " ellipsis range (do BEFORE rstrip("/")
                        # because the ellipsis match needs trailing slashes)
                        # Iter 77: generalized to '...', '…', 'through', 'to', 'thru'
                        expanded_paths = expand_range_shorthand(cleaned)
                        # Each expanded path checked for existence; ALL must exist
                        for ep in expanded_paths:
                            ep_clean = ep.rstrip("/")  # tolerate trailing slash
                            full = ep_clean if os.path.isabs(ep_clean) else os.path.join(cwd, ep_clean)
                            if not os.path.exists(full):
                                # Report the ORIGINAL path (so producer sees what they emitted)
                                missing_artifacts.append(ap)
                                break  # one expanded miss → whole artifact entry FAIL

                if missing_artifacts:
                    result = {
                        "status": "FAIL",
                        "halt_type": "artifact_missing",
                        "details": {
                            "reason": "handoff declares artifacts that don't exist on disk",
                            "missing_artifacts": missing_artifacts,
                            "total_artifacts": len(artifacts),
                        },
                    }
                else:
                    # All checks passed
                    result = {
                        "status": "PASS",
                        "halt_type": None,
                        "details": {
                            "emitted_by": h.get("emitted_by"),
                            "skill_status": h.get("status"),
                            "artifacts_count": len(artifacts),
                        },
                    }

# ─── Step 6: Increment retry_count if same skill+halt repeated within session ─
prior_skill = prior_state.get("skill_name")
prior_halt = prior_state.get("halt_type")
if (
    result["status"] == "FAIL"
    and prior_state.get("status") == "FAIL"
    and prior_skill == skill_name
    and prior_halt == result["halt_type"]
):
    retry_count = (prior_state.get("retry_count", 0) or 0) + 1
else:
    retry_count = 0 if result["status"] == "PASS" else 1  # First failure = attempt 1

# ─── Step 7: Build final state + emit ───────────────────────────────────────
state = {
    "ts": ts,
    "skill_name": skill_name,
    "status": result["status"],
    "halt_type": result["halt_type"],
    "retry_count": retry_count,
    "details": result["details"],
    "escalate_to_c2": retry_count >= 2 and result["status"] == "FAIL",
    "next_action": {
        "type": "re_run_producer" if (result["status"] == "FAIL" and retry_count < 2) else "user_review" if result["status"] == "FAIL" else "chain_complete",
        "hint": (
            f"Re-invoke {skill_name} with --strict-handoff flag (attempt {retry_count + 1} of 2)"
            if result["status"] == "FAIL" and retry_count < 2
            else f"Producer {skill_name} failed handoff 2x (halt_type={result['halt_type']}). Manual review needed."
            if result["status"] == "FAIL"
            else "Handoff valid; chain may proceed."
        ),
    },
}

# Write state file (overwrite — current truth)
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"ERROR: cannot write state file: {e}", file=sys.stderr)
    sys.exit(2)

# Emit to stdout if not quiet
if not quiet:
    print(json.dumps(state, indent=2))

# Exit code reflects status
sys.exit(0 if result["status"] == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
