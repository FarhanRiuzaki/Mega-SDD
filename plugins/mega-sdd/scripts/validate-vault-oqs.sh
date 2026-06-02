#!/usr/bin/env bash
# validate-vault-oqs.sh — Phase B slice B.4 [PostToolUse-validate]
#   + Task G (code-delivery sharpening): operator-workflow-UX capture rails.
#
# Per-OQ scope (B.4):
#   - oq_recommend_citation_invalid (recommendation cites nonexistent KB section)
#   - oq_tech_missing_mode / oq_recommend_underspecified / oq_scan_missing_query
#
# Vault-WIDE rails (Task G — docs/superpowers/specs/2026-06-01-sharpen-code-delivery-uiux-design.md
# §3 Slice G; plan §Task G). Operate on the WHOLE active vault, not just the
# written file:
#   - operator_surface_missing — 04-flows declares a multi-stage approval
#     (maker-checker) workflow but the vault models NO operator-facing surface
#     (worklist/inbox, decision affordance, human state labels, audit timeline)
#     AND carries NO Design-Source OQ.
#   - design_source_oq_missing — HAS_UI_COMPONENTS true but HAS_TOKENS/HAS_A11Y/
#     HAS_VOICE_BRAND all false AND no Design-Source OQ (anti-hallucination: the
#     fix is an OQ, never a defaulted WCAG/Material/token value).
#
# TECH-AGNOSTIC: the Task G rails are a PRE-stack capture-stage check (vault has
# no stack bound yet) operating on mega-sdd VAULT-FORMAT conventions (workflow
# ceremony nouns + the design_system_flags block generate-intent emits for EVERY
# vault). NO framework pack is needed by design — a new stack does not change
# these vault conventions. Documented in generate-intent/references/vault-contract.md.
#
# Per attestation risk-flag #2: KB cross-check gracefully SKIPS when KB absent
# (not all projects have KB). NEVER halt on missing KB.
#
# Inputs: --cwd, --file-path (the vault doc written)
# Outputs: writes .mega-sdd/.vault-oqs-state.json (OVERWRITE-not-append, current truth)
# Exit: 0=PASS or no-op, 1=FAIL.

set -uo pipefail

CWD=""
FILE_PATH=""
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --file-path=*) FILE_PATH="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg" >&2; exit 2 ;;
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

[ -z "$CWD" ] && { echo "ERROR: --cwd" >&2; exit 2; }
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# Only validate vault doc files
case "$FILE_PATH" in
  *.mega-sdd/vaults/*/0[1-6]-*.md|*.mega-sdd/vaults/*/vault.json) ;;
  *) exit 0 ;;
esac

STATE_FILE="${CWD}/.mega-sdd/.vault-oqs-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || exit 2

CWD="$CWD" FILE_PATH="$FILE_PATH" STATE_FILE="$STATE_FILE" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, glob, sys
from datetime import datetime, timezone

cwd = os.environ["CWD"]
file_path = os.environ["FILE_PATH"]
state_file = os.environ["STATE_FILE"]
quiet = os.environ.get("QUIET", "0") == "1"
ts = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
rel = os.path.relpath(file_path, cwd)

try:
    body = open(file_path, errors="replace").read()
except Exception:
    sys.exit(0)

# Build KB inventory (graceful skip if KB absent — risk-flag #2)
kb_dir = os.path.join(cwd, ".mega-sdd", "knowledge-base")
kb_sections = set()
kb_present = os.path.isdir(kb_dir)
if kb_present:
    for kb_file in glob.glob(os.path.join(kb_dir, "**", "*.md"), recursive=True):
        # Section reference format: <kb-file>.md§<section-anchor> OR <kb-file>.md#<section>
        rel_kb = os.path.relpath(kb_file, cwd)
        kb_sections.add(rel_kb)
        # Extract headers from file for section-level matching
        try:
            for line in open(kb_file, errors="replace"):
                m = re.match(r"^#{1,6}\s+(.+?)$", line.rstrip())
                if m:
                    section_id = m.group(1).strip().lower().replace(" ", "-")
                    kb_sections.add(f"{rel_kb}§{section_id}")
                    kb_sections.add(f"{rel_kb}#{section_id}")
        except Exception:
            pass

issues = []

# Walk OQ entries with recommendations → check citations
# Pattern: in markdown OQ blocks, look for "citations:" or "Citation:" lines
# Format: "Citation: knowledge-base/10-domains/foo.md §section-name"
# Or: "citations: - knowledge-base/10-domains/foo.md§section"

# Conservative scope: only check citations that point to knowledge-base/ paths
citation_pattern = re.compile(
    r"(?:Citation|citation|cite|cites)s?:\s*(?:-\s*)?[\"']?(knowledge-base/[^\s\"'\]\,]+)[\"']?",
    re.IGNORECASE,
)
oq_pattern = re.compile(r"\bOQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b")

# Walk the body. Build per-OQ blocks: text from OQ mention up to (but excluding)
# the next OQ mention. This avoids the bug where OQ-A's metadata window catches
# OQ-B's `mode:` line (15-line proximity false-positives).
lines = body.split("\n")

# First pass: find all OQ-line indices
oq_anchors = []  # list of (line_idx, [oq_ids_in_line])
for i, line in enumerate(lines):
    found = oq_pattern.findall(line)
    if found:
        oq_anchors.append((i, found))

# Build per-OQ blocks
oq_blocks = []  # list of (oq_id, block_text)
for idx, (line_i, oqs) in enumerate(oq_anchors):
    # Block ends at next OQ anchor OR 30 lines later (whichever first)
    if idx + 1 < len(oq_anchors):
        block_end = min(oq_anchors[idx + 1][0], line_i + 30)
    else:
        block_end = min(line_i + 30, len(lines))
    block = "\n".join(lines[line_i:block_end])
    for oq in oqs:
        oq_blocks.append((oq, block))

processed_oqs = set()
for oq, window in oq_blocks:
        # ─── Check oq_recommend_citation_invalid (original) ─────────────────
        citations = citation_pattern.findall(window)
        for cit in citations:
            cit_clean = cit.strip().rstrip(",;)")
            if not kb_present:
                continue  # graceful skip (risk-flag #2)
            full_cit = os.path.join(cwd, ".mega-sdd", cit_clean.split("§")[0].split("#")[0])
            if not os.path.exists(full_cit):
                issues.append({
                    "halt_type": "oq_recommend_citation_invalid",
                    "detail": f"OQ {oq} cites KB path that does not exist: {cit_clean}",
                    "oq_id": oq,
                    "citation": cit_clean,
                    "resolved_to": full_cit,
                })

        # Skip schema checks if we already processed this OQ
        if oq in processed_oqs:
            continue
        processed_oqs.add(oq)

        # ─── B.4-followup: detect OQ category + mode for schema checks ───────
        # Category indicator: `[tech]` or `[business]` in OQ line, OR `category: tech` field
        has_tech_category = bool(re.search(r"\[tech\]|category:\s*tech", window, re.IGNORECASE))
        has_business_category = bool(re.search(r"\[business\]|category:\s*business", window, re.IGNORECASE))

        # mode: line in window
        mode_match = re.search(r"^\s*[-*]?\s*mode:\s*(\w+)", window, re.MULTILINE)
        mode_value = mode_match.group(1).lower() if mode_match else None

        # ─── Check oq_tech_missing_mode ──────────────────────────────────────
        # Tech-categorized OQ without mode: field
        if has_tech_category and not mode_value:
            issues.append({
                "halt_type": "oq_tech_missing_mode",
                "detail": f"OQ {oq} categorized [tech] but missing `mode:` field (expected `mode: scan` or `mode: recommend`)",
                "oq_id": oq,
                "category": "tech",
            })

        # ─── Check oq_scan_missing_query ─────────────────────────────────────
        # mode=scan OQ requires `scan_target:` field within window
        if mode_value == "scan":
            scan_target_match = re.search(r"^\s*[-*]?\s*scan_target:\s*\S+", window, re.MULTILINE)
            if not scan_target_match:
                issues.append({
                    "halt_type": "oq_scan_missing_query",
                    "detail": f"OQ {oq} has `mode: scan` but missing `scan_target:` field",
                    "oq_id": oq,
                    "mode": "scan",
                })

        # ─── Check oq_recommend_underspecified ───────────────────────────────
        # mode=recommend OQ requires recommendation, rationale, citations fields
        if mode_value == "recommend":
            required_fields = ["recommendation", "rationale"]
            # Citations are loose — accept either Citation: or citations: or cites:
            has_citation = bool(re.search(r"^\s*[-*]?\s*(?:Citation|citation|cite|cites|citations):", window, re.MULTILINE))
            missing_fields = []
            for f in required_fields:
                if not re.search(rf"^\s*[-*]?\s*{f}:", window, re.MULTILINE | re.IGNORECASE):
                    missing_fields.append(f)
            if not has_citation:
                missing_fields.append("citation|citations")
            if missing_fields:
                issues.append({
                    "halt_type": "oq_recommend_underspecified",
                    "detail": f"OQ {oq} has `mode: recommend` but missing required field(s): {missing_fields}",
                    "oq_id": oq,
                    "mode": "recommend",
                    "missing_fields": missing_fields,
                })

# ═══════════════════════════════════════════════════════════════════════════
# Task G — Operator-workflow-UX capture + Design-Source OQ (two vault-WIDE rails)
#
# These rails operate on the WHOLE vault (04-flows + 02-architecture + vault.json),
# not just the single written file — a workflow flow lives in 04-flows while its
# operator-surface requirement lives in 02-architecture and its Design-Source OQ
# lives in vault.json. We locate the active vault from --cwd and read all three.
#
# TECH-AGNOSTIC: this is a PRE-stack capture-stage check (the vault has no stack
# bound yet), so there is NO framework pack here by design. The vocabulary below
# is mega-sdd VAULT-FORMAT convention (the workflow ceremony nouns + the
# `design_system_flags` block that generate-intent emits for EVERY vault
# regardless of target stack) — exactly like the F-U-/F-S- flow taxonomy that
# flow-coverage hardcodes. A NEW STACK does not change these vault conventions, so
# no pack section is needed. Documented in generate-intent/references/vault-contract.md.
#
# ANTI-HALLUCINATION: both rails demand an Open Question (operator surface req OR a
# Design-Source OQ), NEVER a defaulted WCAG/Material/token value. The rails only
# assert that the maker-checker miss was CAPTURED, not that a value was invented.
# ═══════════════════════════════════════════════════════════════════════════

# Closed VAULT-FORMAT flow taxonomy (generate-intent/references/vault-contract.md
# §Flow ID prefixes): F-U- user-facing; F-S- system; F-C- cross-cutting; F-X-
# custom. A multi-stage approval (maker-checker) surface is user-facing, so we
# scope to F-U-/prefix-less flows and EXCLUDE the internal classes.
SYSTEM_FLOW_RE = re.compile(r"\bF-[SCX]-?\d+\b", re.IGNORECASE)

# A workflow / maker-checker / multi-stage-approval flow signal (closed vocabulary
# of stack-neutral ceremony nouns). A flow qualifies when EITHER its actor/title
# line shows a maker->checker hand-off chain OR its step body carries >= 2 distinct
# decision (approve/reject/review/confirm) transition steps. One decision step alone
# is a simple submit; two or more is a multi-stage approval needing an operator surface.
DECISION_STEP_RE = re.compile(
    r"\b(approve|approval|reject|rejection|review|confirm|countersign|"
    r"second\s*approval|dual[\s-]?key|four[\s-]?eyes)\b",
    re.IGNORECASE,
)
MAKER_CHECKER_CHAIN_RE = re.compile(
    r"\b(maker)\b.*?\b(checker|approver|confirm|reviewer)\b",
    re.IGNORECASE,
)
STAGE_ARROW_RE = re.compile(r"(->|→|=>|»)")  # actor-chain hand-off arrows


def _split_flow_steps(body):
    """Split a flow body into per-step blocks (numbered `N.` line + indented
    continuation), mirroring flow-coverage's step-block parser."""
    blocks, cur = [], None
    for line in body.splitlines():
        if re.match(r"^\s*\d+\.\s", line):
            if cur is not None:
                blocks.append("\n".join(cur))
            cur = [line]
        elif cur is not None:
            if line.strip() == "" or re.match(r"^\s+\S", line):
                cur.append(line)
            elif line.strip().startswith("**"):
                blocks.append("\n".join(cur))
                cur = None
            else:
                cur.append(line)
    if cur is not None:
        blocks.append("\n".join(cur))
    return blocks


def vault_has_workflow_flow(flows_text):
    """True iff 04-flows declares >= 1 user-facing multi-stage approval flow."""
    parts = re.split(r"^(###\s+.*)$", flows_text, flags=re.MULTILINE)
    i = 1
    while i < len(parts):
        header = parts[i].strip()
        fbody = parts[i + 1] if i + 1 < len(parts) else ""
        i += 2
        if SYSTEM_FLOW_RE.search(header):
            continue  # system / cross-cutting / custom — no operator boundary
        hdr_line = header.splitlines()[0] if header else ""
        # Signal 1: maker->checker hand-off chain in the header/first lines.
        head_window = hdr_line + "\n" + "\n".join(fbody.splitlines()[:6])
        if MAKER_CHECKER_CHAIN_RE.search(head_window) and STAGE_ARROW_RE.search(head_window):
            return True
        # Signal 2: >= 2 distinct decision transition steps in the body.
        decision_steps = sum(1 for blk in _split_flow_steps(fbody) if DECISION_STEP_RE.search(blk))
        if decision_steps >= 2:
            return True
    return False


# Operator-facing surface vocabulary (stack-neutral VAULT-FORMAT tells). Presence
# of ANY in the vault's prose docs (02-architecture, 01-overview, 04-flows) OR
# vault.json counts the operator surface as MODELED. These are the four surfaces
# generate-intent must capture: worklist/inbox, decision affordance, human state
# labels, audit timeline.
OPERATOR_SURFACE_RE = re.compile(
    r"\b(work[\s-]?list|inbox|task[\s-]?list|pending[\s-]?(?:queue|items|approvals?)|"
    r"availableactions|decision[\s-]?(?:affordance|card|panel)|approve\s*/\s*reject|"
    r"state[\s-]?label|status[\s-]?label|human[\s-]?readable[\s-]?(?:state|status)|"
    r"audit[\s-]?(?:timeline|trail|history)|workflow[\s-]?transitions?[\s-]?(?:audit|history|timeline))\b",
    re.IGNORECASE,
)

# Design-Source OQ shape: an Open Question that captures the missing design source
# (tokens / a11y / voice-brand). Matches a tag like OQ-DESIGN... OR OQ text that
# names a design-system source concern. Mirrors the grep used to confirm TF state:
#   OQ-.*(DESIGN|UI|UX|TOKEN|A11Y|VOICE|BRAND) | design-source
DESIGN_SOURCE_OQ_RE = re.compile(
    r"(OQ-[A-Z0-9-]*(?:DESIGN|TOKEN|A11Y|VOICE|BRAND)[A-Z0-9-]*)|"
    r"design[\s-]?source|design[\s-]?system\s+source|"
    r"(?:design\s+tokens?|accessibility|voice\s*/?\s*brand)\b[^\n]{0,80}\b(?:source|provide|missing|absent|open\s+question)\b",
    re.IGNORECASE,
)


def _read(path):
    try:
        return open(path, errors="replace").read()
    except Exception:
        return ""


# Locate the active vault under --cwd that holds 04-flows.md (the workflow source).
vault_root = os.path.join(cwd, ".mega-sdd", "vaults")
active_vault_dir = None
if os.path.isdir(vault_root):
    cands = []
    for d in sorted(glob.glob(os.path.join(vault_root, "*"))):
        if os.path.isdir(d) and os.path.isfile(os.path.join(d, "04-flows.md")):
            # prefer the vault the written file belongs to; else most-recent flows
            cands.append(d)
    if cands:
        # Prefer the vault dir that contains the written file_path, if any.
        active_vault_dir = next(
            (d for d in cands if os.path.abspath(file_path).startswith(os.path.abspath(d) + os.sep)),
            None,
        )
        if active_vault_dir is None:
            # Fallback: the vault with the largest 04-flows (the phase under work).
            active_vault_dir = max(
                cands, key=lambda d: os.path.getsize(os.path.join(d, "04-flows.md"))
            )

if active_vault_dir:
    flows_text = _read(os.path.join(active_vault_dir, "04-flows.md"))
    if flows_text and vault_has_workflow_flow(flows_text):
        # Gather the surfaces-evidence corpus: prose docs + vault.json.
        prose_corpus = flows_text
        for fn in ("02-architecture.md", "01-overview.md", "03-data-model.md"):
            prose_corpus += "\n" + _read(os.path.join(active_vault_dir, fn))
        vault_json_text = _read(os.path.join(active_vault_dir, "vault.json"))
        full_corpus = prose_corpus + "\n" + vault_json_text

        has_operator_surface = bool(OPERATOR_SURFACE_RE.search(prose_corpus))
        has_design_source_oq = bool(DESIGN_SOURCE_OQ_RE.search(full_corpus))

        # ── Rail 1: operator_surface_missing ────────────────────────────────
        # Workflow flow present AND no operator-surface requirement AND no
        # Design-Source OQ (an OQ is the accepted "captured the miss" escape hatch).
        if not has_operator_surface and not has_design_source_oq:
            issues.append({
                "halt_type": "operator_surface_missing",
                "detail": (
                    "04-flows declares a multi-stage approval (maker-checker) "
                    "workflow but the vault models NO operator-facing surface "
                    "(worklist/inbox, decision affordance, human-readable state "
                    "labels, audit timeline) and carries NO Design-Source OQ. The "
                    "operators have nowhere to act on items awaiting their decision."
                ),
                "vault": os.path.basename(active_vault_dir),
                "remedy": (
                    "In generate-intent, model the operator surface as FIRST-CLASS "
                    "requirements GROUNDED in the flows (never invented), OR emit a "
                    "high-priority Design-Source Open Question if the surface design "
                    "is genuinely undecided."
                ),
            })

        # ── Rail 2: design_source_oq_missing ────────────────────────────────
        # UI components exist (HAS_UI_COMPONENTS true / a component surface present)
        # but HAS_TOKENS & HAS_A11Y & HAS_VOICE_BRAND are ALL false AND there is no
        # Design-Source OQ. Anti-hallucination: the fix is an OQ, never a defaulted
        # WCAG/Material/token value. (This is the real captured tradefinance miss.)
        dsf = {}
        m_dsf = re.search(r'"design_system_flags"\s*:\s*\{(.*?)\}', vault_json_text, re.DOTALL)
        if m_dsf:
            for fm in re.finditer(r'"(HAS_[A-Z0-9_]+)"\s*:\s*(true|false)', m_dsf.group(1)):
                dsf[fm.group(1)] = (fm.group(2) == "true")
        has_ui_components = dsf.get("HAS_UI_COMPONENTS", False)
        all_design_false = (
            dsf.get("HAS_TOKENS") is False
            and dsf.get("HAS_A11Y") is False
            and dsf.get("HAS_VOICE_BRAND") is False
            and ("HAS_TOKENS" in dsf)  # the block exists & declares them
        )
        if has_ui_components and all_design_false and not has_design_source_oq:
            issues.append({
                "halt_type": "design_source_oq_missing",
                "detail": (
                    "design_system_flags shows HAS_UI_COMPONENTS=true but "
                    "HAS_TOKENS / HAS_A11Y / HAS_VOICE_BRAND are ALL false, and no "
                    "Design-Source Open Question was emitted. UI exists with no "
                    "design-system source captured."
                ),
                "vault": os.path.basename(active_vault_dir),
                "remedy": (
                    "Emit a high-priority Design-Source OQ requesting the design "
                    "tokens / accessibility target / voice-brand source. DO NOT "
                    "default WCAG/Material values — capture the gap as an OQ only."
                ),
            })

status = "PASS" if not issues else "FAIL"
state = {
    "ts": ts,
    "checked_file": rel,
    "status": status,
    "issues_count": len(issues),
    "issues": issues,
    "kb_present": kb_present,
    "next_action": (
        "Vault OQ citations valid, operator surface captured (or N/A), Design-Source OQ present where needed (or N/A)."
        if status == "PASS"
        else (
            f"{len(issues)} vault-OQ issue(s) detected (OQ-citation integrity and/or "
            "operator_surface_missing / design_source_oq_missing). Re-run "
            "/mega-sdd:generate-intent to model the operator surface grounded in the "
            "flows, emit a Design-Source OQ where UI exists but design source is "
            "missing (never default WCAG/Material values), or fix OQ citations via "
            "/mega-sdd:resolve-oq."
        )
    ),
}
try:
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)
except Exception:
    sys.exit(2)

if not quiet:
    print(json.dumps(state, indent=2))

sys.exit(0 if status == "PASS" else 1)
PYEOF

exit $?
