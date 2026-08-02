#!/usr/bin/env bash
# validate-preflight.sh — pipeline-intelligence, Iter-79 O-1 (orchestrator, F2 closure).
#
# Per docs/superpowers/audits/2026-06-02-intelligence-e2e/01-orchestrator-baseline.md §O-1
# and the predictive-checks.md catalog (which was prose-only — the model could skip it).
#
# Predictive PRE-flight: detect a KNOWN, knowable-in-advance input precondition for the
# skill about to run, BEFORE it burns minutes and halts mid-way. Fork-A enforcement of the
# F2 "predictive halt" theme: a deterministic runner the PreToolUse hook invokes, instead
# of SKILL.md Step 3.5 prose. Conservative — only GENUINELY-FATAL preconditions block
# (a skill that cannot do anything useful without the missing input); softer signals are
# advisory warnings. This avoids the false-stop risk the audit flagged for over-eager gates.
#
# Checks (highest-signal subset of the catalog):
#   bind-codebase   : needs a vault AND a codebase-map.md         → FATAL if absent
#   generate-units  : needs a (bound) vault                        → FATAL if absent
#   execute-bolts   : needs units/U-*.md                           → FATAL if absent
#   scan-codebase   : tree-sitter present (else regex fallback)    → WARN
#
# Usage: validate-preflight.sh --cwd=<root> --skill=<mega-sdd:NAME> [--quiet]
# Output: stdout JSON (suppressed by --quiet); OVERWRITE <cwd>/.mega-sdd/.preflight-state.json
# Exit: 0 = PASS / WARN / not-applicable; 1 = FATAL precondition unmet; 2 = error

set -uo pipefail

CWD=""
SKILL=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --skill=*) SKILL="${arg#*=}" ;;
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
if [ ! -d "${CWD}/.mega-sdd" ]; then
  # no project — nothing to preflight; never block
  [ "$QUIET" -eq 0 ] && echo '{"status":"PASS","reason":"no .mega-sdd/ project"}'
  exit 0
fi

# Probe AST-engine availability for the scan warn-check (cheap; no file scan).
# D2 ladder: auto = ast-grep -> regex (tree-sitter is an explicit opt-in lane);
# the warn fires only when NO AST engine is present at all.
TS_PRESENT=0
if command -v tree-sitter >/dev/null 2>&1 || command -v tree-sitter-cli >/dev/null 2>&1; then
  TS_PRESENT=1
fi
AG_PRESENT=0
command -v ast-grep >/dev/null 2>&1 && AG_PRESENT=1

# P1 (v4.93.0, decision 8): the probe predicates live in the SHARED library
# scripts/_lib/state_probes.py — one probe set for preflight AND the routing
# digest (derive-state.sh), so the two surfaces can never re-diverge again.
# Semantics are IDENTICAL to the inline functions this script carried pre-P1
# (incl. S4 BC-PREFLIGHT-LEGACY: the map probe accepts the legacy repo-root
# location; probing only the canonical path FATAL-blocked every bind on a
# pre-migration project whose map bind would happily consume).
export MEGA_SDD_LIB_DIR="${SCRIPT_DIR}/_lib"

CWD="$CWD" SKILL="$SKILL" TS_PRESENT="$TS_PRESENT" AG_PRESENT="$AG_PRESENT" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone

sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
from state_probes import (
    has_vault as _has_vault,
    has_bound_or_vault as _has_bound_or_vault,
    has_units as _has_units,
    has_codebase_map as _has_codebase_map,
)

cwd = os.environ["CWD"]
skill = os.environ.get("SKILL", "")
ts_present = os.environ.get("TS_PRESENT", "0") == "1"
ag_present = os.environ.get("AG_PRESENT", "0") == "1"
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def has_vault():
    return _has_vault(cwd)


def has_bound_or_vault():
    return _has_bound_or_vault(cwd)


def has_units():
    return _has_units(cwd)


def has_codebase_map():
    return _has_codebase_map(cwd)


fatal = None          # {check_id, on_fail}
warnings = []
checks = []

name = skill.split(":")[-1] if skill else ""

if name == "bind-codebase":
    if not has_vault():
        fatal = {"check_id": "binding_input_vault_missing",
                 "on_fail": "bind-codebase needs a vault (.mega-sdd/vaults/<vault>/) — run generate-intent first."}
    elif not has_codebase_map():
        fatal = {"check_id": "binding_input_map_missing",
                 "on_fail": "bind-codebase needs a codebase-map.md (.mega-sdd/codebase/codebase-map.md) — run scan-codebase first."}
    checks.append({"check": "binding_input_complete", "status": "FAIL" if fatal else "PASS"})

elif name == "generate-units":
    if not has_bound_or_vault():
        fatal = {"check_id": "units_input_vault_missing",
                 "on_fail": "generate-units needs a (bound-)vault — run generate-intent (and bind-codebase) first."}
    checks.append({"check": "units_input_complete", "status": "FAIL" if fatal else "PASS"})

elif name == "execute-bolts":
    if not has_units():
        fatal = {"check_id": "bolts_units_missing",
                 "on_fail": "execute-bolts needs units (.mega-sdd/vaults/<vault>/units/U-*.md) — run generate-units first."}
    checks.append({"check": "units_directory_present", "status": "FAIL" if fatal else "PASS"})

elif name == "scan-codebase":
    if not ts_present and not ag_present:
        warnings.append({"check_id": "ast_engine_present",
                         "detail": "no AST engine installed (tree-sitter AND ast-grep both absent); "
                                   "scan-codebase falls back to the regex engine (lower precision; "
                                   "bind-codebase field-level diff will degrade). Install via "
                                   "/mega-sdd:install-deps or `brew install ast-grep` (zero-compilation "
                                   "tier) / `brew install tree-sitter-cli`."})
    # tree-sitter absence is the NORMAL D2 happy path (auto = ast-grep -> regex;
    # tree-sitter is an explicit opt-in lane) — not warn-worthy.
    checks.append({"check": "ast_engine_present", "status": "WARN" if warnings else "PASS"})

status = "FATAL" if fatal else ("WARN" if warnings else "PASS")
report = {
    "status": status,
    "validator": "preflight",
    "ts": ts,
    "skill": skill,
    "fatal_check_id": fatal["check_id"] if fatal else None,
    "fatal_on_fail": fatal["on_fail"] if fatal else None,
    "warnings": warnings,
    "checks": checks,
    "summary": (
        f"FATAL precondition unmet for {skill}: {fatal['on_fail']}" if fatal
        else (f"{len(warnings)} preflight warning(s) for {skill}" if warnings
              else f"preflight clean for {skill or '(no skill)'}")
    ),
}

state_file = os.path.join(cwd, ".mega-sdd", ".preflight-state.json")
try:
    with open(state_file, "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")
except Exception:
    pass

if not quiet:
    print(json.dumps(report))
sys.exit(1 if status == "FATAL" else 0)
PYEOF
