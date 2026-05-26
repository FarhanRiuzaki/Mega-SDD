#!/usr/bin/env bash
# validate-handoff-binding-units.sh — Iter 67.6 [HOOK-VALIDATE] walking-skeleton slice 1.
#
# Per plugins/mega-sdd/CLAUDE.md §Fork A scope. Audit response 2026-05-27 §F.
#
# Validates the binding → units handoff boundary for OQ-ID propagation discipline.
# Walks <vault-root>/<phase>-bound/units/*.md frontmatter binding_refs against the
# OQ-IDs declared in the corresponding binding doc. Drops are reported as
# structured blockers; the result file is OVERWRITE-NOT-APPEND (current truth).
#
# Honest scope (slice 1 — expanded later if this proves):
#   - OQ-IDs only (CONFLICT-IDs and Hard Rules deferred to slice 2/3)
#   - One boundary only: binding → units (vault→binding and units→bolts later)
#   - Frontmatter citation = canonical trace (body mentions don't count — body is
#     semantic context, frontmatter is structured traceability)
#
# Usage:
#   validate-handoff-binding-units.sh --cwd=<project-root> [--quiet]
#
# Where <project-root> contains:
#   .mega-sdd/vaults/binding*.md                              (one or more binding docs)
#   .mega-sdd/vaults/*-bound/units/U-*.md                     (units to validate)
#
# Output:
#   stdout: JSON {status: PASS|FAIL, drops: [...], summary: {...}}
#   side-effect: writes <cwd>/.mega-sdd/.validation-blockers.json (CURRENT state)
#   exit 0 = PASS (no drops); exit 1 = FAIL (drops detected); exit 2 = error

set -uo pipefail

CWD=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [ -z "$CWD" ] || [ ! -d "$CWD" ]; then
  echo "ERROR: --cwd=<project-root> required and must exist" >&2
  exit 2
fi

# Validator state file path
BLOCKER_FILE="${CWD}/.mega-sdd/.validation-blockers.json"
mkdir -p "$(dirname "$BLOCKER_FILE")" 2>/dev/null || {
  echo "ERROR: cannot create $(dirname "$BLOCKER_FILE")" >&2; exit 2;
}

# Run the validator (python3 — robust YAML parsing + regex).
# Stdout: JSON report. Side-effect: writes BLOCKER_FILE.
CWD="$CWD" BLOCKER_FILE="$BLOCKER_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json
import os
import re
import sys
import glob
from datetime import datetime, timezone

cwd = os.environ["CWD"]
blocker_file = os.environ["BLOCKER_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"

# --- Locate artifacts ---
vault_dir = os.path.join(cwd, ".mega-sdd", "vaults")
if not os.path.isdir(vault_dir):
    report = {
        "status": "PASS",
        "reason": "no_vault",
        "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    with open(blocker_file, "w") as f:
        json.dump(report, f, indent=2)
    if not quiet:
        print(json.dumps(report))
    sys.exit(0)

# Binding docs: binding.md, binding-phase-*.md at vault root
binding_paths = sorted(
    glob.glob(os.path.join(vault_dir, "binding.md")) +
    glob.glob(os.path.join(vault_dir, "binding-*.md"))
)

# Units: <vault>/*-bound/units/U-*.md (multi-phase: each bound vault has its own units)
units_paths = sorted(glob.glob(os.path.join(vault_dir, "*-bound", "units", "U-*.md")))

# OQ-ID regex: starts with OQ-, alphanumerics+hyphens, ends with -digit
OQ_RE = re.compile(r"\bOQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b")

# --- Pass 1: collect all OQ-IDs declared in any binding doc ---
binding_oqs = {}  # oq_id → binding_file_path
for bp in binding_paths:
    try:
        with open(bp) as f:
            content = f.read()
    except Exception as e:
        if not quiet:
            print(f"WARN: cannot read {bp}: {e}", file=sys.stderr)
        continue
    for o in OQ_RE.findall(content):
        # First binding doc declaring this OQ wins (defensive — they should be unique)
        binding_oqs.setdefault(o, bp)

# --- Pass 2: for each unit, parse FRONTMATTER ONLY and collect binding_refs ---
unit_citations = {}  # oq_id → [unit_file_paths]
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
for up in units_paths:
    try:
        with open(up) as f:
            body = f.read()
    except Exception as e:
        if not quiet:
            print(f"WARN: cannot read {up}: {e}", file=sys.stderr)
        continue
    m = FRONTMATTER_RE.match(body)
    if not m:
        continue  # no frontmatter — can't validate
    fm = m.group(1)
    # binding_refs may be inline list `binding_refs: [...]` or YAML list under `binding_refs:`
    # Both → grep all OQ-IDs in the frontmatter block. Frontmatter is small + structured;
    # any OQ-ID here is a deliberate trace citation.
    for o in OQ_RE.findall(fm):
        unit_citations.setdefault(o, []).append(up)

# --- Pass 3: compute drops (in binding but no unit cites them in frontmatter) ---
drops = []
for oq_id in sorted(binding_oqs.keys()):
    cites = unit_citations.get(oq_id, [])
    if not cites:
        drops.append({
            "type": "oq_id_dropped",
            "oq_id": oq_id,
            "source_binding": os.path.relpath(binding_oqs[oq_id], cwd),
            "expected_in": "any unit's frontmatter binding_refs (or any field within `---...---`)",
            "found_in_units": [],
        })

# --- Pass 4: extras (OQ-IDs cited by units but not in any binding — usually a typo / stale ref) ---
extras = []
for oq_id, cites in sorted(unit_citations.items()):
    if oq_id not in binding_oqs:
        extras.append({
            "type": "oq_id_extra",
            "oq_id": oq_id,
            "cited_in": [os.path.relpath(p, cwd) for p in cites],
            "warning": "OQ-ID cited in unit frontmatter but not declared in any binding doc",
        })

# --- Report ---
status = "PASS" if not drops else "FAIL"
report = {
    "status": status,
    "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "validator": "validate-handoff-binding-units.sh",
    "slice": "binding-to-units / OQ-IDs / frontmatter",
    "summary": {
        "binding_docs_checked": len(binding_paths),
        "units_checked": len(units_paths),
        "oq_ids_in_binding": len(binding_oqs),
        "oq_ids_cited_by_some_unit": len(unit_citations),
        "drops": len(drops),
        "extras": len(extras),
    },
    "drops": drops,
    "extras": extras,
    "next_action": (
        "Append the listed OQ-IDs to the relevant unit's frontmatter `binding_refs:` "
        "list, then re-run validator (or save the unit — PostToolUse will auto-re-validate)."
    ) if drops else "No action needed — handoff trace is clean.",
}

# Write CURRENT-truth blocker file (overwrite, not append)
with open(blocker_file, "w") as f:
    json.dump(report, f, indent=2)

# Emit to stdout (consumed by hook + slash command)
if not quiet:
    print(json.dumps(report, indent=2))

# Exit code reflects status
sys.exit(0 if status == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
