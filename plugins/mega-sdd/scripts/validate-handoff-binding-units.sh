#!/usr/bin/env bash
# validate-handoff-binding-units.sh — Iter 67.6 [HOOK-VALIDATE] walking-skeleton slice 1.
#
# Per plugins/mega-sdd/CLAUDE.md §Fork A scope. Audit response 2026-05-27 §F.
#
# Validates the binding → units handoff boundary on two axes:
#   1. OQ-ID + CONFLICT-ID *propagation* — every LIVE ID declared in the binding doc must
#      be cited in some unit's frontmatter binding_refs (uncited => a "drop"). S4: OQ
#      harvesting is section-aware — IDs only in the resolved sections (Tech-OQ
#      Auto-Resolved / Auto-Resolved Deferred / Recommendations) or the PENDING
#      section (## Open Questions — no resolution exists yet, so there is nothing
#      to cite) are advisory extras, never blocking drops. LIVE = an OQ-ID woven
#      into claims/State Map/Suggested Hard Rules (its resolution shaped evidence).
#   2. CONFLICT *resolution* (the moat's invariant #2) — every ACTIVE conflict block
#      (`### CONFLICT-<id>` heading, or a `### C-NNN …` claim heading whose block carries
#      `CONFLICT (BLOCKING)`) must be resolved before units/bolts proceed. Resolution
#      markers are STRUCTURAL: ✅/RESOLVED in the heading line or on a dedicated
#      Resolution/Status line — prose containing the word "resolved" does NOT count.
#      An unresolved block is a drop even if its ID is cited. Deleting the binding doc
#      while units cite CONFLICT-IDs is itself a drop (binding_missing, fail-closed).
# Drops are reported as structured blockers; the result file is OVERWRITE-NOT-APPEND
# (current truth) and is read by the execute-bolts PreToolUse gate (status==FAIL blocks).
#
# Scope notes:
#   - Boundary: binding → units (vault→binding and units→bolts validated elsewhere)
#   - Frontmatter citation = canonical trace for propagation (body mentions don't count)
#   - Resolution scan reads structured `### CONFLICT-<id>` headings (not every mention),
#     fail-closed: a heading with no resolution marker is treated as ACTIVE/blocking
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
    _tmp = blocker_file + ".tmp.%d" % os.getpid()  # AUDIT L4: atomic write (tmp + os.replace) — no torn read under concurrent bolts
    with open(_tmp, "w") as f:
        json.dump(report, f, indent=2)
    os.replace(_tmp, blocker_file)
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

# OQ-ID regex (S4 BC-HANDOFF-1): lettered vault forms (OQ-AR-1, OQ-DM-P2-1) AND
# bind's own numeric fresh-OQ form (OQ-001 / OQ-12 per binding-md-template.md
# §Open Questions) — the numeric form used to pass the gate silently.
OQ_RE = re.compile(r"\bOQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\b")
# CONFLICT-ID regex (slice 2 v3.58.0+): only canonical `CONFLICT-NNN` form.
# C-NNN short-form is ambiguous (version refs, code IDs, etc.) — false-positive risk too high.
# Per canonical TF Import binding format: `CONFLICT-1: vault says X ↔ code says Y`
CONFLICT_RE = re.compile(r"\bCONFLICT-(?:[A-Z][A-Z0-9-]*-)?\d+\b")

# --- Pass 1: collect OQ-IDs AND CONFLICT-IDs declared in any binding doc ---
# S4 BC-HANDOFF-2 + round-2 BC-HANDOFF-1-FRESH-OQ: OQ harvesting is SECTION-AWARE.
#  - RESOLVED sections (Tech-OQ Auto-Resolved / Auto-Resolved Deferred OQs /
#    Tech-OQ Recommendations): NO propagation obligation — a resolved OQ
#    influenced the bind, not necessarily any single unit. Advisory extras.
#  - PENDING section (## Open Questions): fresh/deferred OQs with NO resolution
#    yet — per the generate-units contract (SKILL.md Step 12.5.g) an OQ is cited
#    only when its RESOLUTION is implemented in a unit, so an unresolved OQ has
#    nothing to cite and MUST NOT hard-block execute-bolts (requiring a citation
#    deterministically false-blocked every bind that surfaced one fresh OQ).
#    Advisory extras (oq_id_pending_uncited) — resolve via resolve-oq.
#  - LIVE (everything else — an OQ-ID woven into claims / State Map / Suggested
#    Hard Rules means its resolution shaped binding evidence): keeps the
#    blocking drop.
RESOLVED_OQ_SECTIONS = ("tech-oq auto-resolved", "auto-resolved deferred", "tech-oq recommendations")
PENDING_OQ_SECTIONS = ("open questions",)

def sec_class(heading):
    if any(k in heading for k in RESOLVED_OQ_SECTIONS):
        return "resolved"
    if any(k in heading for k in PENDING_OQ_SECTIONS):
        return "pending"
    return "live"

def split_h2_sections(content):
    """Yield (h2_heading_lowercased, section_text). Preamble has heading ''."""
    parts = re.split(r"(?m)^(##\s+.*)$", content)
    yield ("", parts[0])
    for i in range(1, len(parts) - 1, 2):
        yield (parts[i].lower(), parts[i + 1])
    if len(parts) > 1 and len(parts) % 2 == 0:
        yield (parts[-1].lower(), "")

binding_oqs = {}           # live oq_id → binding_file_path (propagation required)
binding_oqs_pending = {}   # pending-section oq_id → binding_file_path (advisory)
binding_oqs_resolved = {}  # resolved-section oq_id → binding_file_path (advisory)
_BUCKET = {"live": binding_oqs, "pending": binding_oqs_pending, "resolved": binding_oqs_resolved}
binding_conflicts = {}     # conflict_id → binding_file_path
for bp in binding_paths:
    try:
        with open(bp) as f:
            content = f.read()
    except Exception as e:
        if not quiet:
            print(f"WARN: cannot read {bp}: {e}", file=sys.stderr)
        continue
    for heading, text in split_h2_sections(content):
        bucket = _BUCKET[sec_class(heading)]
        for o in OQ_RE.findall(text):
            bucket.setdefault(o, bp)
    # Canonical CONFLICT-NNN form is unambiguous — no scoping needed
    for c in CONFLICT_RE.findall(content):
        binding_conflicts.setdefault(c, bp)
# Precedence: LIVE > PENDING > RESOLVED (an ID in a live section is fail-closed
# blocking regardless of where else it appears; pending beats resolved).
for o in list(binding_oqs_pending):
    if o in binding_oqs:
        del binding_oqs_pending[o]
for o in list(binding_oqs_resolved):
    if o in binding_oqs or o in binding_oqs_pending:
        del binding_oqs_resolved[o]

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
# S4 BC-BINDING-DELETE (fail-closed backstop): units citing CONFLICT-IDs while
# ZERO binding docs exist means the binding surface was deleted out from under
# the units — the old behavior demoted the orphan citations to warnings and
# re-validated to PASS, erasing active CONFLICTs without resolution.
if units_paths and unit_conflict_citations and not binding_paths:
    drops.append({
        "type": "binding_missing",
        "conflict_ids_cited": sorted(unit_conflict_citations.keys()),
        "expected": (
            "units cite CONFLICT-IDs but no binding doc exists under .mega-sdd/vaults/ — "
            "deleting/moving binding.md erases active CONFLICTs without resolution "
            "(invariant #2) and breaks unit citation resolution (invariant #3). "
            "Restore the binding doc or re-run /mega-sdd:bind-codebase."
        ),
    })
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

# --- Pass 3b: unresolved-CONFLICT block (the moat's literal invariant #2) ---
# Invariant #2 promises "unresolved CONFLICTs block downstream unit/bolt generation."
# The propagation passes above only check that CONFLICT-IDs are *cited*, not that they
# are *resolved* — so an unresolved-but-cited CONFLICT would slip the gate. Per
# binding-contract.md, each ACTIVE conflict is a `### CONFLICT-<id>` detail heading
# carrying `Verdict: CONFLICT (BLOCKING)`; a resolved one is "marked ✅ / RESOLVED" and
# is exempt. We scan the structured detail headings (not every CONFLICT-ID mention) and
# fail-closed: a heading with no resolution marker is treated as ACTIVE → blocking.
HEADING_RE = re.compile(r"^#{1,3}\s")
CONFLICT_HEADING_RE = re.compile(r"^#{2,3}\s+(?:[✅❌⚠️]\s*)*CONFLICT-", re.IGNORECASE)
# S4 BC-VAL-6: historical/phase-lane bindings record active conflicts under a
# CLAIM-ID heading (`### C-004 … — CONFLICT (BLOCKING)`) — the same signal the
# advisory classification validator counts. A C-NNN heading is an active
# conflict ONLY when its block carries the BLOCKING verdict text (bare C-NNN
# headings are claim details, not conflicts — matching them unconditionally
# would false-positive on every State Map claim ID).
CLAIMID_HEADING_RE = re.compile(r"^#{2,3}\s+(?:[✅❌⚠️]\s*)*C-\d+\b")
# S4 round-2 (BC-S4-3): a claim-ID heading is an active conflict only on a
# STRUCTURAL blocking signal — the heading's own trailing `— CONFLICT (BLOCKING)`
# or a dedicated Verdict line — never a mid-prose mention of the phrase
# ("…superseded the earlier CONFLICT (BLOCKING) once code aligned" is history,
# not a verdict).
HEAD_BLOCKING_RE = re.compile(r"[—–-]\s*CONFLICT\s*\(\s*BLOCKING\s*\)\s*$", re.IGNORECASE)
VERDICT_BLOCKING_LINE_RE = re.compile(
    r"(?mi)^\s*(?:[-*>]\s*)?(?:\*\*)?Verdict(?:\*\*)?\s*:\s*[^\n]*CONFLICT\s*\(\s*BLOCKING\s*\)"
)
# S4 BC-GATE-2 (+ round-2 BC-S4-1/BC-S4-2): resolution markers are STRUCTURAL,
# not substring. A block is resolved ONLY when:
#  - the HEADING carries ✅, or the word RESOLVED immediately AFTER the conflict
#    ID (`### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — …`) — a domain word inside the
#    TITLE ("vault says tickets are auto-resolved") must not count; or
#  - a dedicated Resolution/Status line whose VALUE STARTS with ✅/RESOLVED —
#    `- **Status**: NOT RESOLVED` must not count.
HEAD_RESOLVED_RE = re.compile(
    r"✅|(?:\b(?:CONFLICT-(?:[A-Z][A-Z0-9-]*-)?\d+|C-\d+)\s+RESOLVED\b)", re.IGNORECASE
)
RESOLUTION_LINE_RE = re.compile(
    r"(?mi)^\s*(?:[-*>]\s*)?(?:\*\*)?(?:Resolution|Status)(?:\*\*)?\s*:\s*(?:\*\*)?\s*(?:✅\s*)*(?:RESOLVED\b|✅)"
)
for bp in binding_paths:
    try:
        with open(bp) as f:
            blines = f.read().splitlines()
    except Exception:
        continue
    i = 0
    n_lines = len(blines)
    while i < n_lines:
        is_conflict_head = bool(CONFLICT_HEADING_RE.match(blines[i]))
        is_claimid_head = (not is_conflict_head) and bool(CLAIMID_HEADING_RE.match(blines[i]))
        if is_conflict_head or is_claimid_head:
            head = blines[i]
            j = i + 1
            # Block spans from the heading to the next h1–h3 heading (exclusive) or EOF.
            while j < n_lines and not HEADING_RE.match(blines[j]):
                j += 1
            block = "\n".join(blines[i:j])
            # Canonical CONFLICT-N headings are active fail-closed; C-NNN claim
            # headings are active only with a STRUCTURAL blocking verdict signal
            # (heading-trailing or a Verdict line — never mid-prose mentions).
            active = is_conflict_head or bool(
                HEAD_BLOCKING_RE.search(head) or VERDICT_BLOCKING_LINE_RE.search(block)
            )
            cm = CONFLICT_RE.search(head)
            if not cm and is_claimid_head:
                cm = re.search(r"\bC-\d+\b", head)
            cid = cm.group(0) if cm else "CONFLICT-?"
            resolved = bool(HEAD_RESOLVED_RE.search(head) or RESOLUTION_LINE_RE.search(block))
            if active and not resolved:
                drops.append({
                    "type": "conflict_unresolved",
                    "conflict_id": cid,
                    "source_binding": os.path.relpath(bp, cwd),
                    "heading": head.lstrip("# ").strip(),
                    "expected": (
                        "resolve the CONFLICT via /mega-sdd:resolve-oq --binding (writes the "
                        "✅/RESOLVED marker into the heading or a `- **Resolution**:` line — "
                        "prose mentions of the word elsewhere in the block do NOT count), "
                        "or re-run /mega-sdd:bind-codebase until conflicts=0, before "
                        "generating units or running bolts"
                    ),
                })
            i = j
        else:
            i += 1

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
# S4 BC-HANDOFF-2: resolved-section OQs carry no propagation obligation — an
# uncited one is surfaced as advisory context, never a blocking drop.
for oq_id in sorted(binding_oqs_resolved.keys()):
    if oq_id not in unit_oq_citations:
        extras.append({
            "type": "oq_id_resolved_uncited",
            "oq_id": oq_id,
            "source_binding": os.path.relpath(binding_oqs_resolved[oq_id], cwd),
            "warning": (
                "auto-resolved/recommendation OQ not cited by any unit — advisory only "
                "(resolved OQs influenced the bind, not necessarily any single unit)"
            ),
        })
# S4 round-2 (BC-HANDOFF-1-FRESH-OQ): pending Open-Questions OQs have no
# resolution to implement — nothing to cite. Advisory, never a blocking drop.
for oq_id in sorted(binding_oqs_pending.keys()):
    if oq_id not in unit_oq_citations:
        extras.append({
            "type": "oq_id_pending_uncited",
            "oq_id": oq_id,
            "source_binding": os.path.relpath(binding_oqs_pending[oq_id], cwd),
            "warning": (
                "pending Open-Questions OQ not cited by any unit — advisory only "
                "(an unresolved OQ has no resolution to trace; resolve it via "
                "/mega-sdd:resolve-oq, after which affected units must cite it)"
            ),
        })

# --- Report ---
def _next_action(drops):
    if not drops:
        return "No action needed — handoff trace is clean."
    types = {d.get("type", "?") for d in drops}
    parts = []
    if types & {"conflict_unresolved", "binding_missing"}:
        parts.append(
            "conflict/binding drops: resolve via /mega-sdd:resolve-oq --binding <binding.md> "
            "(human-in-the-loop) or re-run /mega-sdd:bind-codebase until conflicts=0"
        )
    if types & {"oq_id_dropped", "conflict_id_dropped"}:
        parts.append(
            "propagation drops: append the listed OQ-/CONFLICT-IDs to the relevant unit's "
            "frontmatter `binding_refs:` list"
        )
    parts.append("then re-run validator (or save the unit — PostToolUse auto-re-validates)")
    return "; ".join(parts) + "."

status = "PASS" if not drops else "FAIL"
report = {
    "status": status,
    "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "validator": "validate-handoff-binding-units.sh",
    "slice": "binding-to-units / OQ-IDs + CONFLICT-IDs propagation + CONFLICT resolution",
    "summary": {
        "binding_docs_checked": len(binding_paths),
        "units_checked": len(units_paths),
        "oq_ids_in_binding": len(binding_oqs),
        "conflict_ids_in_binding": len(binding_conflicts),
        "oq_ids_cited_by_some_unit": len(unit_oq_citations),
        "conflict_ids_cited_by_some_unit": len(unit_conflict_citations),
        "conflicts_unresolved": len([d for d in drops if d.get("type") == "conflict_unresolved"]),
        "drops": len(drops),
        "extras": len(extras),
    },
    "drops": drops,
    "extras": extras,
    # S4 BC-MSG-1: remediation is drop-type aware — the OQ-frontmatter fix can
    # never clear a conflict_unresolved / binding_missing drop.
    "next_action": _next_action(drops),
}

# Write CURRENT-truth blocker file (overwrite, not append).
# AUDIT L4: atomic write (tmp + os.replace) — a concurrent gate read (the PreToolUse
# aggregator) must never see a torn .validation-blockers.json (the moat state file).
_tmp = blocker_file + ".tmp.%d" % os.getpid()
with open(_tmp, "w") as f:
    json.dump(report, f, indent=2)
os.replace(_tmp, blocker_file)

# Emit to stdout (consumed by hook + slash command)
if not quiet:
    print(json.dumps(report, indent=2))

# Exit code reflects status
sys.exit(0 if status == "PASS" else 1)
PYEOF

EXIT_CODE=$?
exit $EXIT_CODE
