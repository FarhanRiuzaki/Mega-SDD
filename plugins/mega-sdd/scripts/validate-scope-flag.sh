#!/usr/bin/env bash
# validate-scope-flag.sh — Phase B slice B.6 PATTERN-PROVE [PreToolUse-Skill-tool_input].
#
# WALKING-SKELETON for the NEW PreToolUse-Skill-tool_input surface. Per reviewer
# 2026-05-27 refinement R1: this slice's purpose is to PROVE the surface works
# in production for ONE halt (scope_not_declared_in_prd) BEFORE assuming it
# covers other halts. If empirical surface fails → halt moves to edge-case track.
#
# The challenge: PreToolUse stdin for Skill tool gives only {tool_name: "Skill",
# tool_input: {skill: "mega-sdd:..."}}. CLI args (--scope=X) are NOT in
# tool_input. They're in the user's prompt text. So this script reads
# transcript_path (also in PreToolUse stdin) to find the most recent user
# message + extract --scope=X.
#
# Inputs: --cwd, --user-message-file=<path-or-stdin>
# Outputs: writes .mega-sdd/.scope-flag-state.json
# Exit: 0=PASS (no flag or valid scope), 1=FAIL (invalid scope), 2=error
# Note: emits BLOCK directive on stdout when FAIL (for hook to relay).

set -uo pipefail

CWD=""
USER_MSG_FILE=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --user-message-file=*) USER_MSG_FILE="${arg#*=}" ;;
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

[ -z "$CWD" ] && { echo "ERROR: --cwd required" >&2; exit 2; }

# Read user message
if [ -n "$USER_MSG_FILE" ] && [ -f "$USER_MSG_FILE" ]; then
  USER_MSG=$(cat "$USER_MSG_FILE")
else
  USER_MSG=$(cat)
fi

STATE_FILE="${CWD}/.mega-sdd/.scope-flag-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" USER_MSG="$USER_MSG" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, glob, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
msg = os.environ["USER_MSG"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

# Extract --scope=X from user message (also accept --scope X variant)
flag_match = re.search(r"--scope[=\s]+(\S+)", msg)
if not flag_match:
    # No flag → pass through (no action)
    state = {"ts": ts, "status": "PASS", "reason": "no --scope flag in user message", "scope_requested": None}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state))
    sys.exit(0)

scope_requested = flag_match.group(1).strip().strip("'\"").rstrip(",;)")

# Special value: --scope=all (legacy) → always valid
if scope_requested.lower() == "all":
    state = {"ts": ts, "status": "PASS", "reason": "--scope=all legacy fallback (always valid)", "scope_requested": "all"}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state))
    sys.exit(0)

# Find PRD file in CWD
prd_candidates = []
for pattern in ["prd.md", "seed-PRD.md", "*PRD*.md", "*prd*.md"]:
    prd_candidates.extend(glob.glob(os.path.join(cwd, pattern)))
# Also check .mega-sdd/ subdirs
prd_candidates.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "seed-prd.md")))
prd_candidates.extend(glob.glob(os.path.join(cwd, ".mega-sdd", "prd.md")))
# Dedupe + filter to real files
prd_candidates = sorted(set(p for p in prd_candidates if os.path.isfile(p)))

if not prd_candidates:
    # No PRD found — graceful skip (NOT a block; we can't validate without PRD)
    state = {
        "ts": ts, "status": "PASS",
        "reason": "no PRD file found in cwd; cannot validate scope (graceful skip)",
        "scope_requested": scope_requested,
        "searched_patterns": ["prd.md", "seed-PRD.md", "*PRD*.md", ".mega-sdd/{seed-,}prd.md"],
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state))
    sys.exit(0)

# Parse scopes from PRD frontmatter
declared_scopes = []
prd_path = prd_candidates[0]
try:
    with open(prd_path) as f:
        prd_content = f.read()
except Exception:
    state = {"ts": ts, "status": "PASS", "reason": f"cannot read PRD {prd_path}; graceful skip"}
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    sys.exit(0)

# Look for `scopes:` in YAML frontmatter
fm_match = re.match(r"^---\n(.*?)\n---", prd_content, re.DOTALL)
if fm_match:
    fm = fm_match.group(1)
    # Three shapes accepted:
    #   a) scopes: [BE, MW, FE]  (inline list)
    #   b) scopes:\n  - BE\n  - MW (block list of scalars)
    #   c) scopes:\n  - id: BE\n    name: Backend (block list of dicts)
    inline_match = re.search(r"^scopes:\s*\[([^\]]+)\]", fm, re.MULTILINE)
    if inline_match:
        declared_scopes = [s.strip().strip("'\"") for s in inline_match.group(1).split(",") if s.strip()]
    else:
        # Block list — find `scopes:` line, walk indented children
        block_match = re.search(r"^scopes:\s*\n((?:\s+.+\n?)+)", fm, re.MULTILINE)
        if block_match:
            block_text = block_match.group(1)
            # Look for `- id: X` (dict shape) or `- X` (scalar shape)
            for ln in block_text.split("\n"):
                m_dict = re.match(r"^\s+-\s+id:\s*(\S+)", ln)
                if m_dict:
                    declared_scopes.append(m_dict.group(1).strip().strip("'\""))
                    continue
                m_scalar = re.match(r"^\s+-\s+(\S+)\s*$", ln)
                if m_scalar:
                    declared_scopes.append(m_scalar.group(1).strip().strip("'\""))

if not declared_scopes:
    # PRD has no scopes: block — legacy single-scope vault
    state = {
        "ts": ts, "status": "PASS",
        "reason": "PRD has no `scopes:` frontmatter block; legacy single-scope vault (any --scope value OK or ignored)",
        "scope_requested": scope_requested,
        "prd_path": os.path.relpath(prd_path, cwd),
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state))
    sys.exit(0)

# Validate
if scope_requested in declared_scopes:
    state = {
        "ts": ts, "status": "PASS",
        "reason": f"scope '{scope_requested}' is declared in PRD",
        "scope_requested": scope_requested,
        "declared_scopes": declared_scopes,
        "prd_path": os.path.relpath(prd_path, cwd),
    }
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
    if not quiet:
        print(json.dumps(state))
    sys.exit(0)

# FAIL — scope not in PRD
state = {
    "ts": ts,
    "status": "FAIL",
    "halt_type": "scope_not_declared_in_prd",
    "reason": f"--scope={scope_requested} not in PRD's declared scopes",
    "scope_requested": scope_requested,
    "declared_scopes": declared_scopes,
    "prd_path": os.path.relpath(prd_path, cwd),
    "stopReason": (
        f"--scope={scope_requested} is not declared in {os.path.relpath(prd_path, cwd)}'s "
        f"`scopes:` frontmatter. Valid scopes: {declared_scopes}. "
        f"Re-invoke with --scope=<one of {declared_scopes}> OR --scope=all (legacy single-vault fallback). "
        f"Cancel and update PRD if the scope SHOULD be added."
    ),
}
with open(state_file, "w") as f:
    json.dump(state, f, indent=2)
if not quiet:
    print(json.dumps(state))
sys.exit(1)
PYEOF

exit $?
