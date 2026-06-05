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

# Binding docs: binding.md / binding-phase-*.md — at the vaults container (legacy)
# AND per-vault root (canonical: <vault>/binding.md, v3.4+).
binding_paths = sorted(
    glob.glob(os.path.join(vault_dir, "binding.md")) +
    glob.glob(os.path.join(vault_dir, "binding-*.md")) +
    glob.glob(os.path.join(vault_dir, "*", "binding.md")) +
    glob.glob(os.path.join(vault_dir, "*", "binding-*.md"))
)

# Units: file layouts (U-*.md OR U-*/unit.md) under any .../units/.
# Widened from *-bound to * — covers canonical <slug>/units/ (v3.4+) AND legacy
# <slug>-bound/units/. Both <slug> and <slug>-bound are children of vaults/.
units_paths = sorted(
    glob.glob(os.path.join(vault_dir, "*", "units", "U-*.md")) +
    glob.glob(os.path.join(vault_dir, "*", "units", "U-*", "unit.md"))
)

# OQ-ID regex: starts with OQ-, alphanumerics+hyphens, ends with -digit
OQ_RE = re.compile(r"\bOQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b")
# CONFLICT-ID regex (slice 2 v3.58.0+): only canonical `CONFLICT-NNN` form.
# C-NNN short-form is ambiguous (version refs, code IDs, etc.) — false-positive risk too high.
# Per canonical TF Import binding format: `CONFLICT-1: vault says X ↔ code says Y`
CONFLICT_RE = re.compile(r"\bCONFLICT-(?:[A-Z][A-Z0-9-]*-)?\d+\b")

# --- Pass 1: collect all OQ-IDs AND CONFLICT-IDs declared in any binding doc ---
binding_oqs = {}  # oq_id → binding_file_path
binding_conflicts = {}  # conflict_id → binding_file_path
for bp in binding_paths:
    try:
        with open(bp) as f:
            content = f.read()
    except Exception as e:
        if not quiet:
            print(f"WARN: cannot read {bp}: {e}", file=sys.stderr)
        continue
    for o in OQ_RE.findall(content):
        binding_oqs.setdefault(o, bp)
    # Canonical CONFLICT-NNN form is unambiguous — no scoping needed
    for c in CONFLICT_RE.findall(content):
        binding_conflicts.setdefault(c, bp)

# --- Pass 2: for each unit, parse FRONTMATTER ONLY and collect citations ---
unit_oq_citations = {}      # oq_id → [unit_file_paths]
unit_conflict_citations = {}  # conflict_id → [unit_file_paths]
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
        continue
    fm = m.group(1)
    for o in OQ_RE.findall(fm):
        unit_oq_citations.setdefault(o, []).append(up)
    # CONFLICT-IDs in frontmatter
    for c in CONFLICT_RE.findall(fm):
        unit_conflict_citations.setdefault(c, []).append(up)

# --- Pass 3: compute drops (OQs + CONFLICTs in binding but no unit cites them) ---
drops = []
for oq_id in sorted(binding_oqs.keys()):
    cites = unit_oq_citations.get(oq_id, [])
    if not cites:
        drops.append({
            "type": "oq_id_dropped",
            "oq_id": oq_id,
            "source_binding": os.path.relpath(binding_oqs[oq_id], cwd),
            "expected_in": "any unit's frontmatter binding_refs (or any field within `---...---`)",
            "found_in_units": [],
        })
# Slice 2: CONFLICT-ID drops
for conflict_id in sorted(binding_conflicts.keys()):
    cites = unit_conflict_citations.get(conflict_id, [])
    if not cites:
        drops.append({
            "type": "conflict_id_dropped",
            "conflict_id": conflict_id,
            "source_binding": os.path.relpath(binding_conflicts[conflict_id], cwd),
            "expected_in": "any unit's frontmatter binding_refs (or decisions: frontmatter when CONFLICT was resolved with option A/B)",
            "found_in_units": [],
        })

# --- Pass 4: extras (cited by units but not in binding) ---
extras = []
for oq_id, cites in sorted(unit_oq_citations.items()):
    if oq_id not in binding_oqs:
        extras.append({
            "type": "oq_id_extra",
            "oq_id": oq_id,
            "cited_in": [os.path.relpath(p, cwd) for p in cites],
            "warning": "OQ-ID cited in unit frontmatter but not declared in any binding doc",
        })
for conflict_id, cites in sorted(unit_conflict_citations.items()):
    if conflict_id not in binding_conflicts:
        extras.append({
            "type": "conflict_id_extra",
            "conflict_id": conflict_id,
            "cited_in": [os.path.relpath(p, cwd) for p in cites],
            "warning": "CONFLICT-ID cited in unit frontmatter but not declared in any binding doc",
        })

# --- Report ---
status = "PASS" if not drops else "FAIL"
report = {
    "status": status,
    "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "validator": "validate-handoff-binding-units.sh",
    "slice": "binding-to-units / OQ-IDs + CONFLICT-IDs / frontmatter",
    "summary": {
        "binding_docs_checked": len(binding_paths),
        "units_checked": len(units_paths),
        "oq_ids_in_binding": len(binding_oqs),
        "conflict_ids_in_binding": len(binding_conflicts),
        "oq_ids_cited_by_some_unit": len(unit_oq_citations),
        "conflict_ids_cited_by_some_unit": len(unit_conflict_citations),
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
