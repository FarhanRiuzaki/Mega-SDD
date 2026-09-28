#!/usr/bin/env bash
# validate-handoff-binding-units.sh — [HOOK-VALIDATE] walking-skeleton slice 1.
#
# Per the enforcement doctrine in plugins/mega-sdd/CLAUDE.md (a blocking gate is a
# deterministic validator wired to a hook; prose enforces nothing).
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
UNITS=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --units=*) UNITS="${arg#*=}" ;;   # v8 P1.c: unit-scoped JIT verdicts (bolts/U-*/binding.json)
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
# MEGA_SDD_LIB_DIR sys.path pattern (derive-binding-json.sh precedent).
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
CWD="$CWD" BLOCKER_FILE="$BLOCKER_FILE" QUIET="$QUIET" UNITS="$UNITS" python3 <<'PYEOF'
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
# the legacy binding.md fresh-OQ form (OQ-001 / OQ-12; grammar:
# scripts/_lib/binding_md.py) — the numeric form used to pass the gate silently.
OQ_RE = re.compile(r"\bOQ-(?:[A-Z]+(?:-[A-Z0-9]+)*-)?\d+\b")
# CONFLICT-ID regex (slice 2 v3.58.0+): only canonical `CONFLICT-NNN` form.
# C-NNN short-form is ambiguous (version refs, code IDs, etc.) — false-positive risk too high.
# Per canonical TF Import binding format: `CONFLICT-1: vault says X ↔ code says Y`
CONFLICT_RE = re.compile(r"\bCONFLICT-(?:[A-Z][A-Z0-9-]*-)?\d+\b")

# --- Pass 1: collect OQ-IDs AND CONFLICT-IDs declared in any binding doc ---
# S4 BC-HANDOFF-2 + round-2 BC-HANDOFF-1-FRESH-OQ: OQ harvesting is SECTION-AWARE.
#  - RESOLVED sections (Tech-OQ Auto-Resolved / Auto-Resolved Deferred OQs /
#    AI Technical Decisions — and its pre-rename heading Tech-OQ
#    Recommendations, kept so an older binding.md classes the same): NO propagation obligation — a resolved OQ
#    influenced the bind, not necessarily any single unit. Advisory extras.
#  - PENDING section (## Open Questions): fresh/deferred OQs with NO resolution
#    yet — per the unit contract (plan/references/unit-procedure.md Step 12.5.g,
#    halt unit_oq_trace_missing) an OQ is cited
#    only when its RESOLUTION is implemented in a unit, so an unresolved OQ has
#    nothing to cite and MUST NOT hard-block execute-bolts (requiring a citation
#    deterministically false-blocked every bind that surfaced one fresh OQ).
#    Advisory extras (oq_id_pending_uncited) — resolve via resolve-oq.
#  - LIVE (everything else — an OQ-ID woven into claims / State Map / Suggested
#    Hard Rules means its resolution shaped binding evidence): keeps the
#    blocking drop.
RESOLVED_OQ_SECTIONS = ("tech-oq auto-resolved", "auto-resolved deferred", "tech-oq recommendations", "ai technical decisions")
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
# (The S4 BC-BINDING-DELETE backstop — binding_missing — runs right after Pass 3b,
# where the structural resolution markers it reuses are defined.)
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
# A DEFER-resolved conflict downgrades to an OQ (resolve-oq/references/binding-mode.md,
# per-action table row "D — DEFER") and has NO citing unit by design (plan/references/task-typing.md, row "Mix of
# CONFIRMED + unresolved CONFLICT": "DEFER became an OQ"); the DEFER-only path
# proceeds to execute-bolts with NO re-bind. So an uncited DEFER'd CONFLICT-N is advisory, NOT a blocking
# drop. Collect the uncited candidates here; the DEFER verdict is read per-ID in the
# Pass 3b walk below (from the resolved heading OR the `- **Resolution**:` line), and
# the candidates are classified after that walk. KEEP_VAULT keeps its un-droppable
# citation obligation (plan/references/task-typing.md, row "Claim carries a
# resolved-KEEP_VAULT CONFLICT"); any other/unknown resolution is fail-closed.
conflict_drop_candidates = [
    cid for cid in sorted(binding_conflicts.keys())
    if not unit_conflict_citations.get(cid, [])
]

# --- Pass 3b: unresolved-CONFLICT block (the moat's literal invariant #2) ---
# Invariant #2 promises "unresolved CONFLICTs block downstream unit/bolt generation."
# The propagation passes above only check that CONFLICT-IDs are *cited*, not that they
# are *resolved* — so an unresolved-but-cited CONFLICT would slip the gate. Per the
# legacy binding.md grammar (scripts/_lib/binding_md.py CONFLICT_HEADING_RE), each
# ACTIVE conflict is a `### CONFLICT-<id>` detail heading
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
# (resolve-oq/references/binding-mode.md, paragraph "Layout-2 leg — Resolution write-back
# grammar"). Read it from the whole block so a DEFER
# recorded only on the line (heading carries a bare ✅) is still recognized — mirroring
# the two surfaces RESOLUTION marker detection already reads. A bare menu like
# `Suggested action: KEEP_VAULT | DEFER | …` does NOT match (no `RESOLVED (` prefix).
RESOLVED_ACTION_RE = re.compile(
    r"RESOLVED\s*\(\s*(KEEP_VAULT|KEEP_CODE|DEFER|SPLIT)\b", re.IGNORECASE
)
def _conflict_blocks(blines):
    """Yield every structured conflict block of a legacy binding.md as a dict
    {cid, head, block, active, resolved, action}. ONE grammar for the live binding
    docs (Pass 3b) and a migrated vault's archived binding.md (the migrated leg)."""
    i = 0
    n_lines = len(blines)
    while i < n_lines:
        is_conflict_head = bool(CONFLICT_HEADING_RE.match(blines[i]))
        is_claimid_head = (not is_conflict_head) and bool(CLAIMID_HEADING_RE.match(blines[i]))
        if not (is_conflict_head or is_claimid_head):
            i += 1
            continue
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
        _action = None
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
                for _ln in block.splitlines():
                    if RESOLUTION_LINE_RE.search(_ln):
                        _lm = RESOLVED_ACTION_RE.search(_ln)
                        _action = _lm.group(1).upper() if _lm else None
                        break
        yield {"cid": cid, "head": head, "block": block, "active": active,
               "resolved": resolved, "action": _action}
        i = j


# Per-conflict-ID resolution action (None = resolved but no recognized action → fail-closed).
conflict_resolution_action = {}
for bp in binding_paths:
    try:
        with open(bp) as f:
            blines = f.read().splitlines()
    except Exception:
        continue
    for _b in _conflict_blocks(blines):
        cid = _b["cid"]
        if _b["resolved"]:
            _action = _b["action"]
            # Multi-block / multi-file fail-closed: a DEFER elsewhere must never override a
            # non-DEFER (or unknown) resolution already recorded for the same conflict-ID.
            if cid not in conflict_resolution_action:
                conflict_resolution_action[cid] = _action
            elif conflict_resolution_action[cid] == "DEFER" and _action != "DEFER":
                conflict_resolution_action[cid] = _action
        if _b["active"] and not _b["resolved"]:
            drops.append({
                "type": "conflict_unresolved",
                "conflict_id": cid,
                "source_binding": os.path.relpath(bp, cwd),
                "heading": _b["head"].lstrip("# ").strip(),
                "expected": (
                    "resolve the CONFLICT via resolve-oq --binding (writes the "
                    "✅/RESOLVED marker into the heading or a `- **Resolution**:` line — "
                    "prose mentions of the word elsewhere in the block do NOT count) "
                    "before running bolts"
                ),
            })

# S4 BC-BINDING-DELETE (fail-closed backstop): units citing CONFLICT-IDs while
# ZERO binding docs exist means the binding surface was deleted out from under
# the units — the old behavior demoted the orphan citations to warnings and
# re-validated to PASS, erasing active CONFLICTs without resolution.
# Migrated vault (design §7 #9, invariant #2 — "still blocks until the mandatory JIT
# re-bind RE-VERDICTS it"): `migrate-paths --vault-layout=3` archives binding.md under
# <vault>/_meta/archive/layout2/ and copies each block a unit cites into that unit's
# bolts/U-XXX/binding-migrated.json. Migrated conflicts = OWNED (a unit's
# binding-migrated.json `conflicts[]`, cited or not) ∪ ARCHIVED (an open block of the
# archived binding.md no unit owns — Pass 3b's grammar). One is covered ONLY when its
# block AND its archived original record a human resolution (Pass 3b's markers) or it is RE-VERDICTED:
# the owning unit's own unit-binding/2 binding.json (sole, hook-guarded writer) carries
# a claim that NAMES it (the CONFLICT-ID or the block's `**Claim**: C-NNN`, a token in
# the claim id/text) with a fresh CONFIRMED or CONFLICT verdict (a CONFLICT then gates
# the unit via the --units= leg below; OQ = no verdict yet). An archived unowned one may
# be re-verdicted by any unit of its vault. The re-bind ALONE never covers it — it
# verdicts only the claims a unit states (9.0 verifier V4: the advisory downgrade
# `conflict_migrated_rebound` let an un-re-verdicted CONFLICT pass). Uncovered →
# binding_missing (as in 8.8.1); re-verdicted → advisory conflict_migrated_reverdicted.
def _unit_bolt_dir(up):
    if os.path.basename(up) == "unit.md":            # <vault>/units/U-XXX/unit.md
        return os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(up))),
                            "bolts", os.path.basename(os.path.dirname(up)))
    return os.path.join(os.path.dirname(os.path.dirname(up)),   # <vault>/units/U-XXX.md
                        "bolts", os.path.basename(up)[:-3])

def _read_json_obj(path):
    try:
        with open(path, encoding="utf-8") as f:
            _d = json.load(f)
    except Exception:
        return None                                  # absent / unreadable
    return _d if isinstance(_d, dict) else None

MIG_CLAIM_LINE_RE = re.compile(r"(?m)^\s*[-*]\s*\*\*Claim\*\*\s*:\s*(C-[A-Za-z0-9_-]+)")  # = _lib/binding_md.py
MIG_LINK_RE = re.compile(r"\bCONFLICT-(?:[A-Z][A-Z0-9-]*-)?\d+\b|\bC-\d+\b")

def _block_resolved(blk):
    return bool(isinstance(blk, str) and blk.strip() and (
        HEAD_RESOLVED_RE.search(blk.strip().splitlines()[0]) or RESOLUTION_LINE_RE.search(blk)))

def _link_keys(cid, blk):
    return {cid} | set(MIG_CLAIM_LINE_RE.findall(blk if isinstance(blk, str) else ""))

def _reverdict(bdir, keys):
    """(status, fresh claim rows): reverdicted | reverdict_pending | not_reverdicted | no_rebind."""
    _bj = _read_json_obj(os.path.join(bdir, "binding.json"))
    if not _bj or _bj.get("schema") != "unit-binding/2" or _bj.get("unit") != os.path.basename(bdir):
        return "no_rebind", []
    _linked = [c for c in (_bj.get("claims") or []) if isinstance(c, dict) and keys & set(
        MIG_LINK_RE.findall("%s %s" % (c.get("id") or "", c.get("text") or "")))]
    _rows = [{"unit_id": os.path.basename(bdir), "claim_id": c.get("id"), "verdict": c.get("verdict"),
              "resolution": c.get("resolution")} for c in _linked if c.get("verdict") in ("CONFIRMED", "CONFLICT")]
    return ("reverdicted" if _rows else "reverdict_pending" if _linked else "not_reverdicted"), _rows

migrated_extras = []   # advisory rows, merged into `extras` at Pass 4
migrated_ids = set()   # CONFLICT-IDs a migration record declares (no conflict_id_extra noise)
_mig_uncovered, _mig_reverdicted, _plain_uncovered, _handled = [], {}, set(), set()
_units_by_vault = {}   # vault dir -> [bolt dir]
for up in units_paths:
    _bd = _unit_bolt_dir(up)
    _units_by_vault.setdefault(os.path.dirname(os.path.dirname(_bd)), []).append(_bd)
_archived = {}         # vault dir -> {cid: {"open": bool, "keys": set}} (a live binding doc → Pass 3b)
for _vd in sorted(_units_by_vault):
    _ap = os.path.join(_vd, "_meta", "archive", "layout2", "binding.md")
    if not os.path.isfile(_ap) or any(os.path.dirname(bp) == _vd for bp in binding_paths):
        continue
    try:
        _alines = open(_ap, encoding="utf-8", errors="replace").read().splitlines()
    except Exception:
        continue
    for _b in _conflict_blocks(_alines):
        if _b["active"] or _b["resolved"]:           # else a claim-detail heading, not a conflict
            _r = _archived.setdefault(_vd, {}).setdefault(_b["cid"], {"open": False, "keys": set()})
            _r["keys"] |= _link_keys(_b["cid"], _b["block"])
            _r["open"] = _r["open"] or (_b["active"] and not _b["resolved"])

for up in units_paths:   # OWNED + CITED, per unit
    _bd = _unit_bolt_dir(up)
    _vd = os.path.dirname(os.path.dirname(_bd))
    _owned = {e["id"].strip(): e.get("block") for e in reversed(
        (_read_json_obj(os.path.join(_bd, "binding-migrated.json")) or {}).get("conflicts") or [])
        if isinstance(e, dict) and isinstance(e.get("id"), str) and e["id"].strip()}
    _cited = {c for c, ups in unit_conflict_citations.items() if up in ups} if not binding_paths else set()
    for cid in sorted(set(_owned) | _cited):
        _arec = _archived.get(_vd, {}).get(cid)
        if cid in _owned:
            _src, _open = os.path.join(_bd, "binding-migrated.json"), not _block_resolved(_owned[cid]) or bool(_arec and _arec["open"])
            _keys = _link_keys(cid, _owned[cid]) | (_arec["keys"] if _arec else set())
        elif _arec is not None:
            _src, _open, _keys = os.path.join(_vd, "_meta", "archive", "layout2", "binding.md"), _arec["open"], _arec["keys"]
        else:
            _plain_uncovered.add(cid)                 # cited, no binding doc, no migration record
            continue
        migrated_ids.add(cid); _handled.add((_vd, cid))
        _st, _rows = _reverdict(_bd, _keys) if _open else ("resolved", [])
        if _rows:
            _mig_reverdicted.setdefault(cid, []).extend(_rows)
        elif _open:
            _mig_uncovered.append({"conflict_id": cid, "unit_id": os.path.basename(_bd),
                                   "source": os.path.relpath(_src, cwd), "reason": _st})

for _vd, _recs in sorted(_archived.items()):   # ARCHIVED, owned by no unit
    for cid, _r in sorted(_recs.items()):
        migrated_ids.add(cid)
        if not _r["open"] or (_vd, cid) in _handled:
            continue
        _res = [_reverdict(_bd, _r["keys"]) for _bd in sorted(_units_by_vault[_vd])]
        _rows = [row for _, rw in _res for row in rw]
        if _rows:
            _mig_reverdicted.setdefault(cid, []).extend(_rows)
        else:
            _mig_uncovered.append({"conflict_id": cid, "unit_id": None,
                                   "source": os.path.relpath(os.path.join(_vd, "_meta", "archive", "layout2", "binding.md"), cwd),
                                   "reason": "reverdict_pending" if any(s == "reverdict_pending" for s, _ in _res) else "uncited_unresolved"})

for cid, _rows in sorted(_mig_reverdicted.items()):
    migrated_extras.append({
        "type": "conflict_migrated_reverdicted", "conflict_id": cid,
        "unit_ids": sorted({r["unit_id"] for r in _rows}), "claims": _rows,
        "warning": ("migrated CONFLICT re-verdicted by a fresh claim verdict in bolts/U-XXX/binding.json — "
                    "that verdict now gates the unit (an open CONFLICT blocks its dispatch). Advisory: check "
                    "the claim states the contradiction the migrated block records."),
    })
if _plain_uncovered or _mig_uncovered:
    drops.append({
        "type": "binding_missing",
        "conflict_ids_cited": sorted(_plain_uncovered | {m["conflict_id"] for m in _mig_uncovered}),
        "migrated_unverdicted": _mig_uncovered,
        "expected": (
            "an unresolved CONFLICT has no verdict gating it (invariant #2). Cited CONFLICT-IDs "
            "with no binding doc and no migration record: deleting/moving binding.md erases active "
            "CONFLICTs — restore it. A migrated vault's unresolved CONFLICT (migrated_unverdicted: "
            "bolts/U-XXX/binding-migrated.json or _meta/archive/layout2/binding.md): the full JIT "
            "re-bind (scripts/rebind-units.sh --units=all) verdicts only the claims a unit states, so "
            "give the owning unit a `## Claims` line that NAMES it — e.g. `- C-U001-R1 \"<what the "
            "vault expects> (CONFLICT-1)\" — expect: <path> — must-exist` — and re-bind that unit "
            "(rebind-units.sh --units=<U>): a fresh CONFIRMED opens the gate, a CONFLICT gates the "
            "unit until a human resolves it via resolve-oq --binding, an OQ (text claim) needs the "
            "ladder E3 verdict first. A decision taken before the migration counts only when the "
            "migrated block carries the ✅/RESOLVED marker."
        ),
    })

# --- Pass 4: extras (cited by units but not in binding) ---
extras = list(migrated_extras)
for oq_id, cites in sorted(unit_oq_citations.items()):
    if oq_id not in binding_oqs and oq_id not in vault_oq_ids:
        extras.append({
            "type": "oq_id_extra",
            "oq_id": oq_id,
            "cited_in": [os.path.relpath(p, cwd) for p in cites],
            "warning": "OQ-ID cited in unit frontmatter but not declared in any binding doc or vault.json",
        })
for conflict_id, cites in sorted(unit_conflict_citations.items()):
    # a migration record (binding-migrated.json / archived binding.md) declares it —
    # the migrated leg above owns its verdict
    if conflict_id not in binding_conflicts and conflict_id not in migrated_ids:
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
                "unit — advisory only. The DEFER-only path proceeds to execute-bolts with "
                "no re-bind; the deferred OQ carries traceability via the standard OQ "
                "machinery."
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
                    + ", ".join(_hits) + ". Jalankan /mega-sdd:migrate-paths "
                    "--vault-layout=3 lalu re-bind per unit (/mega-sdd:sync atau "
                    "scripts/rebind-units.sh --units=all) sebelum execute-bolts — "
                    "verdict lama tidak lagi menggambarkan kode saat ini."
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
            "conflict/binding drops: resolve via resolve-oq --binding <bolts/U-XXX/binding.json> "
            "(human-in-the-loop), then re-bind the unit (rebind-units.sh --units=<U>) "
            "until conflicts=0; layout-2 binding.md: /mega-sdd:migrate-paths --vault-layout=3 "
            "first, then the mandatory full JIT re-bind (rebind-units.sh --units=all) — a "
            "migrated CONFLICT-ID clears only when a claim that names it gets a fresh verdict "
            "in its unit's binding.json, or its migrated block records a human resolution; "
            "the re-bind alone never clears it (see the drop's `expected`)"
        )
    if types & {"oq_id_dropped", "conflict_id_dropped"}:
        parts.append(
            "propagation drops: append the listed OQ-/CONFLICT-IDs to the relevant unit's "
            "frontmatter `binding_refs:` list"
        )
    if types & {"binding_stale_recertify"}:
        parts.append(
            "binding basi (stale): file yang di-anchor binding berubah sejak "
            "binding_metadata.head oleh commit di luar pipeline unit — jalankan "
            "/mega-sdd:migrate-paths --vault-layout=3 lalu /mega-sdd:sync (re-bind per unit) "
            "(daftar file ada di field `expected` pada drop-nya)"
        )
    parts.append("then re-run validator (the execute-bolts gate re-derives it too)")
    return "; ".join(parts) + "."

# ─── v8 P1.c — unit-scoped JIT verdicts (spec 2026-09-10 Appendix F4) ──────────
# the execute-bolts JIT bind writes bolts/U-XXX/binding.json (sole writer
# write-unit-binding.sh, hook-guarded). With --units=U-001,… every CONFLICT claim
# without a `resolution` in a LISTED unit is a BLOCKING drop (same
# conflict_unresolved type the hook already denies on). Without --units= the
# per-unit files are reported as ADVISORY extras only — a CONFLICT on U-005 must
# not freeze U-001's dispatch (dependents are blocked via depends_on instead).
_jit_units = []
_want = [u.strip() for u in os.environ.get("UNITS", "").split(",") if u.strip()]
if _want == ["all"]:  # sync --full-bind (7.34.0): every unit of every vault is LISTED → any open CONFLICT blocks
    _want = sorted({os.path.basename(p)[:-3] for p in glob.glob(os.path.join(vault_dir, "*", "units", "U-*.md"))}
                   | {os.path.basename(os.path.dirname(p)) for p in glob.glob(os.path.join(vault_dir, "*", "units", "U-*", "unit.md"))})
for _bp in sorted(glob.glob(os.path.join(vault_dir, "*", "bolts", "U-*", "binding.json"))):
    _uid = os.path.basename(os.path.dirname(_bp))
    try:
        _doc = json.load(open(_bp, encoding="utf-8"))
    except Exception as _e:
        if _uid in _want:
            drops.append({"type": "conflict_unresolved", "conflict_id": "%s:binding.json" % _uid, "unit_id": _uid,
                          "source_binding": os.path.relpath(_bp, cwd), "heading": "unparseable per-unit binding",
                          "expected": "re-run write-unit-binding.sh for %s (file unparseable: %s)" % (_uid, type(_e).__name__)})
        continue
    _open = [c for c in _doc.get("claims", []) if c.get("verdict") == "CONFLICT" and not c.get("resolution")]
    _jit_units.append({"unit_id": _uid, "listed": _uid in _want, "conflicts_open": len(_open)})
    for c in _open:
        row = {"type": "conflict_unresolved" if _uid in _want else "conflict_unit_unresolved",
               "conflict_id": c.get("id"), "unit_id": _uid, "source_binding": os.path.relpath(_bp, cwd),
               "heading": "%s — expect: %s" % (c.get("text") or c.get("kind"), c.get("expect")),
               "expected": "resolve via resolve-oq --binding (write-unit-binding.sh --resolve %s=KEEP_VAULT|KEEP_CODE|SPLIT --by=user) or fix the code/unit and re-bind it: the per-unit re-bind (rebind-units.sh --units=)" % c.get("id")}
        (drops if _uid in _want else extras).append(row)

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
        "jit_units_checked": len(_jit_units),
        "bindings_stale_recertify": _recertify_stale,
        "drops": len(drops),
        "extras": len(extras),
    },
    "drops": drops,
    "extras": extras,
    "jit_units": _jit_units,
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
