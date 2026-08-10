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
#   3. Binding freshness RECERTIFY (P0 v4.92.0) — binding_metadata.head (the git HEAD
#      the binding attests to, parsed via the shared _lib/binding_md.py grammar) is
#      recertified against the commits in <head>..HEAD intersected with the
#      binding.json claims[] anchor paths — EXCLUDING unit-attributed commits (the
#      shared B1 engine's unit_of() grammar): pipeline bolt commits touch anchored
#      files by design and are governed by B1/B3; recertify guards the
#      OUT-OF-PIPELINE lane. An anchored file changed by a non-unit commit →
#      blocking drop (binding_stale_recertify, keterangan in Indonesian). Migration-safe:
#      legacy head-less bindings, missing binding.json, HEAD-moved-but-no-anchor-hit,
#      non-git projects, and git failures are advisory/skip — never REJECTED.
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
_SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
# P0 v4.92.0 (binding RECERTIFY): the freshness check reuses the ONE binding.md
# frontmatter grammar — _lib/binding_md.py parse_frontmatter_metadata — via the
# MEGA_SDD_LIB_DIR sys.path pattern (validate-binding-json.sh precedent).
export MEGA_SDD_LIB_DIR="${_SCRIPT_DIR}/_lib"
_RPR_HELPER="${_SCRIPT_DIR}/_lib/resolve-project-root.sh"
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
import subprocess
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

# Vault-declared OQ ids (6.1.1): on an express-born vault the OQ authority is
# vault.json — a unit citing a vault-declared OQ is NOT an "extra" even when no
# binding doc mentions it (the field run emitted 25 false oq_id_extra warnings
# with binding_docs_checked=0). Entries carry `tag` or `id` (both shapes, per
# the 6.0.1 F5 precedent). Unreadable/absent vault.json contributes NOTHING
# (fail-closed: behavior degrades to the binding-only universe, never wider).
# CONFLICT ids stay binding-only — conflicts exist nowhere else.
vault_oq_ids = set()
for vj in sorted(
    glob.glob(os.path.join(vault_dir, "vault.json")) +
    glob.glob(os.path.join(vault_dir, "*", "vault.json"))
):
    try:
        with open(vj) as f:
            vdata = json.load(f)
        for entry in (vdata.get("open_questions") or []):
            if isinstance(entry, dict):
                oid = entry.get("tag") or entry.get("id")
                if isinstance(oid, str) and oid.strip():
                    vault_oq_ids.add(oid.strip())
    except Exception as e:
        if not quiet:
            print(f"WARN: cannot read {vj}: {e}", file=sys.stderr)

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
            "Restore the binding doc or re-run bind-codebase."
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
# Slice 2: CONFLICT-ID drops — DEFER-resolution-aware (round-2 Batch A1).
# A DEFER-resolved conflict downgrades to an OQ (resolve-oq/references/binding-mode.md:45)
# and has NO citing unit by design (task-typing.md:31 "DEFER became an OQ"); the
# documented DEFER-only path proceeds to generate-units with NO re-bind
# (binding-mode.md:58). So an uncited DEFER'd CONFLICT-N is advisory, NOT a blocking
# drop. Collect the uncited candidates here; the DEFER verdict is read per-ID in the
# Pass 3b walk below (from the resolved heading OR the `- **Resolution**:` line), and
# the candidates are classified after that walk. KEEP_VAULT keeps its un-droppable
# citation obligation (task-typing.md:30); any other/unknown resolution is fail-closed.
conflict_drop_candidates = [
    cid for cid in sorted(binding_conflicts.keys())
    if not unit_conflict_citations.get(cid, [])
]

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
# Resolution ACTION extraction (round-2 Batch A1): the write-back grammar records the
# action as `RESOLVED (<ACTION>)` in BOTH the heading and the `- **Resolution**:` line
# (resolve-oq/references/binding-mode.md:29-31). Read it from the whole block so a DEFER
# recorded only on the line (heading carries a bare ✅) is still recognized — mirroring
# the two surfaces RESOLUTION marker detection already reads. A bare menu like
# `Suggested action: KEEP_VAULT | DEFER | …` does NOT match (no `RESOLVED (` prefix).
RESOLVED_ACTION_RE = re.compile(
    r"RESOLVED\s*\(\s*(KEEP_VAULT|KEEP_CODE|DEFER|SPLIT)\b", re.IGNORECASE
)
# Per-conflict-ID resolution action (None = resolved but no recognized action → fail-closed).
conflict_resolution_action = {}
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
            if resolved:
                # Anchor the resolution ACTION to the SAME surface that established `resolved`
                # — the heading, else the dedicated `- **Resolution**:`/`- **Status**:` line —
                # NEVER a free block scan: a stray "RESOLVED (DEFER)" in a rationale bullet or a
                # sibling-conflict cross-reference must not demote a KEEP_VAULT conflict's
                # un-droppable citation obligation (invariant #2).
                _hm = RESOLVED_ACTION_RE.search(head)
                if _hm:
                    _action = _hm.group(1).upper()
                else:
                    _action = None
                    for _ln in block.splitlines():
                        if RESOLUTION_LINE_RE.search(_ln):
                            _lm = RESOLVED_ACTION_RE.search(_ln)
                            _action = _lm.group(1).upper() if _lm else None
                            break
                # Multi-block / multi-file fail-closed: a DEFER elsewhere must never override a
                # non-DEFER (or unknown) resolution already recorded for the same conflict-ID.
                if cid not in conflict_resolution_action:
                    conflict_resolution_action[cid] = _action
                elif conflict_resolution_action[cid] == "DEFER" and _action != "DEFER":
                    conflict_resolution_action[cid] = _action
            if active and not resolved:
                drops.append({
                    "type": "conflict_unresolved",
                    "conflict_id": cid,
                    "source_binding": os.path.relpath(bp, cwd),
                    "heading": head.lstrip("# ").strip(),
                    "expected": (
                        "resolve the CONFLICT via resolve-oq --binding (writes the "
                        "✅/RESOLVED marker into the heading or a `- **Resolution**:` line — "
                        "prose mentions of the word elsewhere in the block do NOT count), "
                        "or re-run bind-codebase until conflicts=0, before "
                        "generating units or running bolts"
                    ),
                })
            i = j
        else:
            i += 1

# --- Pass 4: extras (cited by units but not in binding) ---
extras = []
for oq_id, cites in sorted(unit_oq_citations.items()):
    if oq_id not in binding_oqs and oq_id not in vault_oq_ids:
        extras.append({
            "type": "oq_id_extra",
            "oq_id": oq_id,
            "cited_in": [os.path.relpath(p, cwd) for p in cites],
            "warning": "OQ-ID cited in unit frontmatter but not declared in any binding doc or vault.json",
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
                "resolve-oq, after which affected units must cite it)"
            ),
        })

# --- Classify the CONFLICT-ID drop candidates now that per-ID resolution actions are
# known (round-2 Batch A1). DEFER → advisory extra (downgraded to an OQ; no citing unit
# expected). KEEP_VAULT / unknown / absent action → blocking drop (fail-closed). ---
for cid in conflict_drop_candidates:
    if conflict_resolution_action.get(cid) == "DEFER":
        extras.append({
            "type": "conflict_id_deferred_uncited",
            "conflict_id": cid,
            "source_binding": os.path.relpath(binding_conflicts[cid], cwd),
            "warning": (
                "CONFLICT resolved via DEFER (downgraded to an OQ) and not cited by any "
                "unit — advisory only. The DEFER-only path proceeds to generate-units with "
                "no re-bind (resolve-oq/references/binding-mode.md:58); the deferred OQ "
                "carries traceability via the standard OQ machinery."
            ),
        })
    else:
        drops.append({
            "type": "conflict_id_dropped",
            "conflict_id": cid,
            "source_binding": os.path.relpath(binding_conflicts[cid], cwd),
            "expected_in": "any unit's frontmatter binding_refs (or decisions: frontmatter when CONFLICT was resolved with option A/B)",
            "found_in_units": [],
        })

# --- Pass 5: binding freshness RECERTIFY (P0 v4.92.0 — git provenance at the
# moat gate). The gate used to read binding.md STRUCTURE only: a hand-authored
# or stale binding.md with no active CONFLICT heading yielded PASS and opened
# execute-bolts. Now the binding's own attestation (binding_metadata.head,
# written once at bind Step 4) is recertified against git ground truth: when
# any file the binding ANCHORS (binding.json claims[].anchor — script-derived,
# trustworthy) was changed between that head and current HEAD by a commit NOT
# attributed to a unit (unit_of() — unit-attributed bolt commits are the
# pipeline's own lane, governed by B1/B3), the binding is provably stale for
# exactly the files it binds → blocking drop (binding_stale_recertify).
# Migration-safe verdict ladder (a v4 artifact is never REJECTED):
#   - not a git repo / git failure                → skip silently (tolerant)
#   - head absent (legacy v4 binding)             → advisory extra only
#   - sibling binding.json absent                 → advisory extra only
#   - head == HEAD                                → fresh, nothing recorded
#   - HEAD moved, no OUT-OF-PIPELINE anchor hit   → advisory extra only (notice)
#   - non-unit commit changed an anchored file    → FAIL (blocks the moat)
def _git(args):
    try:
        r = subprocess.run(["git", "-C", cwd] + args,
                           capture_output=True, text=True, timeout=15)
    except Exception:
        return None
    return r.stdout if r.returncode == 0 else None


def _anchor_paths(bj):
    """Project-relative file-path prefixes from binding.json claims[] anchor
    cells: split multi-anchor cells on ' + ', strip any trailing [reason:]
    token, take the prefix before ':<line>', drop prose cells (spaces)."""
    paths = set()
    for c in bj.get("claims", []):
        if not isinstance(c, dict):
            continue
        cell = str(c.get("anchor") or "")
        cell = re.sub(r"\[reason:\s*[a-z_]+\]\s*$", "", cell).strip()
        for part in re.split(r"\s\+\s", cell):
            cand = part.strip().split(":", 1)[0].strip()
            if cand.startswith("./"):
                cand = cand[2:]
            # a path token, not prose ("dynamic route detected…", "—", "n/a")
            if not cand or " " in cand or ("/" not in cand and "." not in cand):
                continue
            if cand in ("n/a", "—", "-"):
                continue
            paths.add(cand)
    return paths


_recertify_stale = 0
_inside_git = _git(["rev-parse", "--is-inside-work-tree"])
if _inside_git is not None and _inside_git.strip() == "true":
    _cur_head = (_git(["rev-parse", "HEAD"]) or "").strip() or None
    try:
        sys.path.insert(0, os.environ["MEGA_SDD_LIB_DIR"])
        from binding_md import parse_frontmatter_metadata
        from postflight_rules import unit_of  # the ONE commit-attribution grammar (B1 engine)
    except Exception:
        parse_frontmatter_metadata = None
    for bp in binding_paths:
        if _cur_head is None or parse_frontmatter_metadata is None:
            break
        try:
            _bmd = open(bp).read()
        except Exception:
            continue
        _bhead = parse_frontmatter_metadata(_bmd).get("head")
        if not _bhead:
            extras.append({
                "type": "binding_head_absent",
                "source_binding": os.path.relpath(bp, cwd),
                "warning": (
                    "binding.md carries no binding_metadata.head (legacy pre-v4.92 "
                    "binding) — freshness recertify skipped; the next bind/re-bind "
                    "stamps it. Advisory only."
                ),
            })
            continue
        if _bhead == _cur_head:
            continue  # fresh — bound at the current HEAD
        _bj_path = os.path.join(os.path.dirname(bp), "binding.json")
        if not os.path.isfile(_bj_path):
            extras.append({
                "type": "binding_json_absent",
                "source_binding": os.path.relpath(bp, cwd),
                "warning": (
                    "binding_metadata.head present but no sibling binding.json — "
                    "the anchor set is unavailable, freshness recertify skipped. "
                    "Run scripts/derive-binding-json.sh --vault <vault>. Advisory only."
                ),
            })
            continue
        try:
            _bj = json.load(open(_bj_path))
        except Exception:
            continue  # unparseable sidecar — parity validator owns that failure
        # ONE git call: every commit in <head>..HEAD with subject + Unit
        # trailers + touched paths. Unit-ATTRIBUTED commits (feat(U-XXX):,
        # `(bolt): U-XXX`, `Unit:` trailer — the exact grammar of the shared
        # B1 engine's unit_of(), imported above, never re-implemented) are
        # EXCLUDED from the staleness intersection: pipeline bolt commits touch
        # anchored files BY DESIGN (extend units anchor existing code) and are
        # already governed by the B1 hard-rule + B3 whitelist gates — recertify
        # guards the OUT-OF-PIPELINE lane (manual hotfixes, git pull, foreign
        # tools). A violation smuggled under a feat(U-XXX) subject is caught by
        # B1/B3, not this check. A path counts toward the intersection only
        # when at least one NON-unit-attributed commit touched it.
        # --relative: project-relative paths (the repo root may be above cwd).
        _fmt = "%x01%H%x02%s%x02%(trailers:key=Unit,valueonly,separator=%x2C)"
        _log = _git(["log", "--format=" + _fmt, "--name-only", "--relative",
                     _bhead + "..HEAD", "--", "."])
        if _log is None:
            continue  # unknown/foreign sha or git failure — skip (tolerant)
        _changed = set()
        for _chunk in _log.split("\x01"):
            if not _chunk.strip():
                continue
            _hline, _, _tail = _chunk.partition("\n")
            _parts = _hline.split("\x02")
            _subj = _parts[1] if len(_parts) > 1 else ""
            _trail = _parts[2] if len(_parts) > 2 else ""
            if unit_of(_subj, _trail):
                continue  # pipeline-attributed — B1/B3 govern this commit
            for _p in _tail.splitlines():
                _p = _p.strip()
                if _p:
                    _changed.add(_p)
        _anchors = _anchor_paths(_bj)
        _hits = sorted({
            c for c in _changed
            if c in _anchors or any(c.endswith("/" + a) for a in _anchors)
        })
        if _hits:
            _recertify_stale += 1
            drops.append({
                "type": "binding_stale_recertify",
                "source_binding": os.path.relpath(bp, cwd),
                "binding_head": _bhead,
                "current_head": _cur_head,
                "changed_anchored_files": _hits,
                "expected": (
                    "binding sudah basi terhadap file yang di-bind — file ter-anchor "
                    "berikut berubah sejak binding_metadata.head (" + _bhead[:12] + ") "
                    "oleh commit DI LUAR pipeline unit (commit non-unit; commit bolt "
                    "ber-atribusi unit sudah dijaga gate B1/B3 dan tidak dihitung): "
                    + ", ".join(_hits) + ". Jalankan /mega-sdd:sync (incremental) atau "
                    "re-bind via bind-codebase sebelum generate-units/"
                    "execute-bolts — verdict lama tidak lagi menggambarkan kode saat ini."
                ),
            })
        else:
            extras.append({
                "type": "binding_head_mismatch",
                "source_binding": os.path.relpath(bp, cwd),
                "binding_head": _bhead,
                "current_head": _cur_head,
                "warning": (
                    "HEAD moved since bind (%s..%s) but no anchored file was changed "
                    "by an out-of-pipeline commit (unit-attributed bolt commits are "
                    "governed by B1/B3 and excluded) — the binding is still current "
                    "for everything it binds. Advisory only."
                    % (_bhead[:12], _cur_head[:12])
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
            "conflict/binding drops: resolve via resolve-oq --binding <binding.md> "
            "(human-in-the-loop) or re-run bind-codebase until conflicts=0"
        )
    if types & {"oq_id_dropped", "conflict_id_dropped"}:
        parts.append(
            "propagation drops: append the listed OQ-/CONFLICT-IDs to the relevant unit's "
            "frontmatter `binding_refs:` list"
        )
    if types & {"binding_stale_recertify"}:
        parts.append(
            "binding basi (stale): jalankan /mega-sdd:sync atau bind-codebase "
            "ulang — file yang di-anchor binding berubah sejak binding_metadata.head "
            "oleh commit di luar pipeline unit (daftar file ada di field `expected` "
            "pada drop-nya)"
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
        "oq_ids_in_vault": len(vault_oq_ids),
        "conflict_ids_in_binding": len(binding_conflicts),
        "oq_ids_cited_by_some_unit": len(unit_oq_citations),
        "conflict_ids_cited_by_some_unit": len(unit_conflict_citations),
        "conflicts_unresolved": len([d for d in drops if d.get("type") == "conflict_unresolved"]),
        "bindings_stale_recertify": _recertify_stale,
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
