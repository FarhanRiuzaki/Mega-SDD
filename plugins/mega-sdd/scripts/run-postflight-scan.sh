#!/usr/bin/env bash
# run-postflight-scan.sh — deterministic writer for <vault>/bolts/U-XXX/postflight.json (B1).
#
# S6 EB-GATE-4: the postflight evidence artifact used to be agent-written on
# trust — the gate's own remediation text coached "or write the postflight.json
# evidence". This wrapper is now the ONLY sanctioned write path (the artifact is
# Write/Edit-guarded by the PreToolUse hook): it EXECUTES the unit's Hard rules
# against real git/filesystem state and records per-rule verdicts itself.
#
# The rule engine lives in scripts/_lib/postflight_rules.py (scan_unit) and is
# SHARED with validate-bolt-artifacts.sh --postflight-scan --recompute (the gate
# recomputes each committed Hard-rule bolt from ground truth at gate time, reusing
# ONE walk). Factoring the engine into one module is a hard requirement: if the
# gate's recompute diverged from this writer's logic, an honest artifact would
# false-block on engine drift. This wrapper's output is byte-identical to the
# pre-refactor inline engine.
#
# Rule execution (see postflight_rules.py / hard-rule-scan.md §directive rules):
#   v1 strict productions (machine-checked): DO NOT modify <path>; DO NOT add new
#     <manifest> dependencies; <glob> MUST follow <case> naming; function <name>
#     MUST preserve signature: <sig>; file <path> MUST exist after bolt.
#   v2 ast-grep YAML fenced blocks → `ast-grep scan` (match = VIOLATED; absent → tool_missing).
#   generic directives (MUST/DO NOT prose) → verdict `attested` ONLY with
#     --attest-directives="<who/why>"; otherwise `directive_unverified`.
#
# Usage:
#   run-postflight-scan.sh --cwd=<project-root> --unit=U-XXX \
#       [--attest-directives="<reason>"] [--quiet]
# Exit: 0 = all verdicts pass/attested (artifact written, gate state refreshed)
#       1 = ≥1 non-pass verdict (artifact written — B1 stays closed until the code is fixed)
#       2 = cannot run (unit not found / not a git repo)
set -uo pipefail

CWD=""
UNIT=""
ATTEST=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --unit=*) UNIT="${arg#*=}" ;;
    --attest-directives=*) ATTEST="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then echo "ERROR: --cwd=<project-root> required" >&2; exit 2; fi
if [ -z "$UNIT" ]; then echo "ERROR: --unit=U-XXX required" >&2; exit 2; fi
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" UNIT="$UNIT" ATTEST="$ATTEST" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, subprocess, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
import vault_layouts
import postflight_rules

cwd = os.environ["CWD"]
unit_id = os.environ["UNIT"]
attest = os.environ.get("ATTEST", "")
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def git(*a):
    return subprocess.run(["git", "-C", cwd, *a], capture_output=True, text=True)

PREFIX = git("rev-parse", "--show-prefix").stdout.strip()

uf = vault_layouts.find_unit_file(cwd, unit_id)
if not uf:
    print("ERROR: unit %s not found under any vault layout" % unit_id, file=sys.stderr)
    sys.exit(2)
# vault root: <vault>/units/U-X.md → up 2; <vault>/units/U-X/unit.md → up 3
d = os.path.dirname(uf)
vault_root = os.path.dirname(d) if os.path.basename(d) == "units" else os.path.dirname(os.path.dirname(d))
bolt_dir = os.path.join(vault_root, "bolts", unit_id)

text = open(uf).read()

# The unit's bolt commits via the SHARED walk (same identity grammar + pathspec as
# the gate's recompute). walk_unit_commits returns {uid: newest-first [(sha,[(st,p)])]}.
unit_commits = postflight_rules.walk_unit_commits(git, PREFIX, 300).get(unit_id, [])

# preflight snapshot (written by the skill's pre-flight step, when present)
preflight = {}
pf_path = os.path.join(bolt_dir, "preflight.json")
if os.path.isfile(pf_path):
    try:
        preflight = json.load(open(pf_path))
    except (OSError, ValueError):
        preflight = {}

# WRITER path: prior_artifact=None keeps directive handling byte-identical to the
# pre-refactor engine (attest ? attested : directive_unverified). Attestation
# carry-forward is a GATE-only behaviour (the gate recomputes without an attest reason).
results, ok_all = postflight_rules.scan_unit(
    cwd, git, unit_id, text, unit_commits, preflight, attest, prior_artifact=None)

head_sha = git("rev-parse", "HEAD").stdout.strip()
artifact = {
    "unit_id": unit_id,
    "scanned_at": ts,
    "status": "pass" if ok_all else "fail",
    "head_sha": head_sha,
    "written_by": "run-postflight-scan.sh",
    "rules": results,
}
os.makedirs(bolt_dir, exist_ok=True)
target = os.path.join(bolt_dir, "postflight.json")
tmp = target + ".tmp.%d" % os.getpid()
with open(tmp, "w") as f:
    json.dump(artifact, f, indent=1)
os.replace(tmp, target)
if not quiet:
    # M-05: the B1 gate reads the ARTIFACT file, never stdout — dumping the full
    # rules[] (verbatim rule text + evidence, ~350 tok/unit) on every passing
    # per-unit run was pure chat cost. One line on pass; full artifact on fail.
    if ok_all:
        n_att = len([r for r in results if r.get("verdict") == "attested"])
        print("postflight %s: pass (%d rules, %d attested) -> %s" % (unit_id, len(results), n_att, target))
    else:
        print(json.dumps(artifact, indent=1))
sys.exit(0 if ok_all else 1)
PYEOF
PF_EXIT=$?

# Refresh the B1 gate state immediately so the fix is visible without waiting
# for the next Stop / gate-time re-derivation. This is a READ-only refresh (no
# --recompute): the artifact was just written above, so reading it back is correct
# and cheap; the gate's own recompute path is separate (--postflight-scan --recompute).
bash "${SCRIPT_DIR}/validate-bolt-artifacts.sh" --cwd="$CWD" --postflight-scan --quiet >/dev/null 2>&1 || true
exit $PF_EXIT
